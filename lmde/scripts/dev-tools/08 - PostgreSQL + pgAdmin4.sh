#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# FERRAMENTAS DE DESENVOLVIMENTO — POSTGRESQL E PGADMIN4 DESKTOP
# ══════════════════════════════════════════════════════════════════════
# Sistema-alvo: LMDE 7 Gigi / Debian 13 (Bash).
# Finalidade: Tratar servidor e interface separadamente; manutenção requer backup validado.
# Uso: Receita de instalação; executar como usuário normal, sem sudo bash.
# Dependências locais: ../lib/common.sh, ../lib/services.sh
# Organização: títulos sem número; etapas executadas com numeração sequencial.
# Notas específicas:
# PostgreSQL e pgAdmin independentes. LMDE 7 / Debian 13 amd64.
# Não remove bancos nem migra versões principais. Atualizar exige backup próprio.
# ══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/services.sh"
lb_init 'PostgreSQL e pgAdmin4 Desktop' "$@"
svc_no_language_scope
NO_PGADMIN=0
DATABASE_BACKUP=''
BACKUP_VALIDATED=0
for ((arg_index=0; arg_index<${#LB_EXTRA[@]}; arg_index++)); do
    arg=${LB_EXTRA[arg_index]}
    case $arg in
        --no-pgadmin) NO_PGADMIN=1;;
        --backup-validated) BACKUP_VALIDATED=1;;
        --database-backup)
            arg_index=$((arg_index+1))
            DATABASE_BACKUP=${LB_EXTRA[arg_index]:-}
            [[ -n $DATABASE_BACKUP && $DATABASE_BACKUP != --* ]] || lb_die 'Informe --database-backup ARQUIVO.';;
        *) lb_die "Opção desconhecida: $arg";;
    esac
done
LB_SOURCE=${LB_SOURCE:-debian}
case $LB_SOURCE in debian) origin='https?://(deb\.debian\.org|security\.debian\.org)/(debian|debian-security) trixie(-security|-updates)?/';; vendor) origin='https?://apt\.postgresql\.org/pub/repos/apt trixie-pgdg/';; *) lb_die 'Use --source debian ou --source vendor (PGDG).';; esac
[[ ${LB_VERSION:-stable} != lts ]] || lb_die 'PostgreSQL não tem canal LTS; cada versão principal tem cinco anos de suporte. Use stable/latest ou versão explícita.'
# ──────────────────────────────────────────────────────────────────────
# ETAPA 1 — Detectar servidor e clusters existentes
# ──────────────────────────────────────────────────────────────────────
lb_step 'Detectar servidor e clusters existentes'
existing=$(dpkg-query -W -f='${Package} ${Status}\n' 'postgresql-[0-9]*' 2>/dev/null | awk '$2=="install" && $3=="ok" && $4=="installed" && $1 ~ /^postgresql-[0-9]+$/ {sub(/^postgresql-/, "", $1); print $1}' || :)
installed=0
[[ -z $existing ]] || installed=1
if [[ $LB_MODE == check ]]; then
    svc_pg_validate
    if (( ! NO_PGADMIN )); then lb_check_package pgadmin4-desktop || lb_die 'pgAdmin Desktop não instalado.'; fi
    lb_msg 'Validação gráfica do pgAdmin depende de abertura manual.'
    lb_finish
    exit 0
fi
# ──────────────────────────────────────────────────────────────────────
# ETAPA 2 — Escolher ação e conferir proteção dos bancos
# ──────────────────────────────────────────────────────────────────────
lb_step 'Escolher ação e conferir proteção dos bancos'
lb_select_action "$installed"
if [[ $LB_ACTION != keep ]]; then
    if (( installed )); then svc_pg_require_backup "$DATABASE_BACKUP" "$BACKUP_VALIDATED"; fi
    lb_msg "Origem: $LB_SOURCE; caminhos dos pacotes APT; bancos sob /var/lib/postgresql. Nenhuma migração automática."
    lb_warn 'Instalação/atualização pode iniciar ou reiniciar clusters. Preserve backup validado dos bancos existentes antes de atualizar.'
    lb_confirm 'Preparar catálogo e instalar/atualizar PostgreSQL?' || exit 0
    lb_apt_update
    lb_apt_install ca-certificates curl gnupg python3
    if [[ $LB_SOURCE == vendor ]]; then
        lb_repo pgdg https://www.postgresql.org/media/keys/ACCC4CF8.asc https://apt.postgresql.org/pub/repos/apt trixie-pgdg main B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8
        lb_apt_update
    fi
    # ──────────────────────────────────────────────────────────────────────
    # ETAPA 3 — Consultar suporte e selecionar versão do servidor
    # ──────────────────────────────────────────────────────────────────────
    lb_step 'Consultar suporte e selecionar versão do servidor'
    lb_temp
    lb_download https://www.postgresql.org/support/versioning/ "$LB_TMP/pg-support.html"
    support=$(svc_pg_supported "$LB_TMP/pg-support.html")
    catalog=''
    packages=$(apt-cache search --names-only '^postgresql-[0-9]+$')
    while read -r pkg description; do
        [[ $pkg =~ ^postgresql-([0-9]+)$ ]] || continue
        major=${BASH_REMATCH[1]}
        end=$(awk -F '|' -v major="$major" '$1==major {print $2}' <<< "$support")
        [[ -n $end ]] || continue
        versions=$(svc_versions "$pkg" "$origin")
        [[ -n $versions ]] || continue
        catalog+="$major"$'\n'
        lb_msg "PostgreSQL $major; suporte oficial até $end; versões na origem: $versions"
    done <<< "$packages"
    [[ -n $catalog ]] || lb_die 'Nenhuma versão final suportada disponível na origem selecionada.'
    selector=${LB_VERSION:-}
    if [[ -z $selector ]]; then
        if [[ $LB_YES == 1 ]]; then selector=stable
        else read -r -p 'Escolha stable/latest, série (ex.: 17) ou versão APT exata [stable]: ' selector || lb_die 'Entrada encerrada.'; selector=${selector:-stable}; fi
    fi
    package_selector=stable
    case $selector in
        latest|stable) major=$(sort -nr <<< "$catalog" | sed -n '1p');;
        lts) lb_die 'LTS não é uma classificação PostgreSQL.';;
        *)
            if [[ $selector =~ ^[0-9]+$ ]]; then major=$selector
            elif [[ $selector =~ ^([0-9]+)\.[0-9]+([-+~.0-9a-zA-Z]*)$ ]]; then major=${BASH_REMATCH[1]}; package_selector=$selector
            else lb_die 'Versão inválida; use série ou versão completa listada pelo APT.'; fi;;
    esac
    grep -Fx "$major" <<< "$catalog" >/dev/null || lb_die "Série $major não disponível ou sem suporte oficial."
    while IFS= read -r previous; do
        [[ -z $previous || $previous == "$major" ]] || lb_die "Já existe PostgreSQL $previous. Instalar $major é mudança de série: exige plano separado; bancos preservados."
    done <<< "$existing"
    version=$(svc_version "postgresql-$major" "$origin" "$package_selector")
    lb_msg "Seleção resolvida: PostgreSQL $major; pacote $version; origem $LB_SOURCE."
    if (( installed )); then svc_pg_confirm_maintenance "$major" "$version" "$DATABASE_BACKUP"; fi
    # ──────────────────────────────────────────────────────────────────────
    # ETAPA 4 — Instalar e validar servidor e clusters
    # ──────────────────────────────────────────────────────────────────────
    lb_step 'Instalar e validar servidor e clusters'
    svc_install "postgresql-$major=$version" "postgresql-client-$major=$version"
    svc_package_version "postgresql-$major" "$version"
    svc_package_version "postgresql-client-$major" "$version"
    svc_pg_validate "$major" "$version"
else
    svc_pg_validate
fi
# ──────────────────────────────────────────────────────────────────────
# ETAPA 5 — pgAdmin4 Desktop (escolha independente)
# ──────────────────────────────────────────────────────────────────────
lb_step 'pgAdmin4 Desktop (escolha independente)'
if (( NO_PGADMIN )); then
    lb_msg 'pgAdmin não solicitado (--no-pgadmin).'
else
    pgadmin_installed=0
    if lb_check_package pgadmin4-desktop; then pgadmin_installed=1; fi
    lb_select_action "$pgadmin_installed"
    if [[ $LB_ACTION != keep ]]; then
        if lb_confirm 'Instalar/atualizar pgAdmin Desktop pelo repositório oficial?'; then
            lb_apt_update
            lb_apt_install ca-certificates curl gnupg
            lb_repo pgadmin4 https://www.pgadmin.org/static/packages_pgadmin_org.pub https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/trixie pgadmin4 main E8697E2EEF76C02D3A6332778881B2A8210976F2
            lb_apt_update
            pgadmin_version=$(svc_version pgadmin4-desktop 'ftp\.postgresql\.org/pub/pgadmin/pgadmin4/apt/trixie' stable)
            svc_install "pgadmin4-desktop=$pgadmin_version"
            svc_package_version pgadmin4-desktop "$pgadmin_version"
            lb_msg 'Pacote pgAdmin conferido. Abra-o pelo menu e conecte ao cluster para validar interface e autenticação.'
        else lb_msg 'pgAdmin dispensado pelo usuário.'; fi
    else lb_msg 'pgAdmin mantido; validação gráfica requer abertura manual.'; fi
fi
lb_finish
