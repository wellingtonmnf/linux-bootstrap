#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# BIBLIOTECAS DE INSTALAÇÃO — BIBLIOTECA DE APLICATIVOS
# ══════════════════════════════════════════════════════════════════════
# Sistema-alvo: LMDE 7 Gigi / Debian 13 (Bash).
# Finalidade: Compartilhar instalação Debian/fornecedor e validação em dev-tools e user-tools.
# Uso: Biblioteca de funções; carregar com source, não executar diretamente.
# Dependências locais: lib/common.sh (carregar antes desta biblioteca).
# Organização: títulos sem número; etapas executadas com numeração sequencial.
# Notas específicas:
# Auxiliares de aplicativos; requer common.sh. Não iniciar GUI para validar pacote.
# ══════════════════════════════════════════════════════════════════════


# ──────────────────────────────────────────────────────────────────────
# Validação de aplicativo instalado (lb_app_validate)
# ──────────────────────────────────────────────────────────────────────
lb_app_validate() {
    local package=$1 executable=$2 path
    lb_check_package "$package" || lb_die "Pacote $package ausente ou incompleto."
    path=$(command -v "$executable") || lb_die "Executável $executable não encontrado."
    [[ -x $path ]] || lb_die "Executável não funcional: $path"
    dpkg-query -W -f='${Package} ${Version} ${Architecture}\n' "$package"
    lb_msg "Executável: $path. A abertura gráfica ainda deve ser testada na sessão LMDE."
}


# ──────────────────────────────────────────────────────────────────────
# Fluxo de instalação de aplicativo via APT (lb_app_apt)
# ──────────────────────────────────────────────────────────────────────
lb_app_apt() {
    local package=$1 executable=$2 name=$3 key=$4 uri=$5 suite=$6 components=$7 fingerprints=$8 format=${9:-inrelease}
    lb_assert_no_extra
    [[ -z ${LB_SOURCE:-} || $LB_SOURCE == vendor ]] || lb_die "$name usa o repositório oficial do fornecedor (--source vendor)."
    [[ ${LB_SCOPE:-none} == none ]] || lb_die 'Pacotes APT têm escopo de sistema; não usar --scope para estes aplicativos.'
    # ──────────────────────────────────────────────────────────────────────
    # ETAPA 1 — Detectar instalação e escolher ação
    # ──────────────────────────────────────────────────────────────────────
    lb_step 'Detectar instalação e escolher ação'
    local installed=0
    if lb_check_package "$package"; then installed=1; fi
    if [[ $LB_MODE == check ]]; then
        lb_app_validate "$package" "$executable"
        lb_finish 'Diagnóstico local; origem e abertura gráfica não certificadas.'
        return
    fi
    lb_select_action "$installed"
    if [[ $LB_ACTION == keep ]]; then
        lb_app_validate "$package" "$executable"
        lb_finish 'Instalação mantida; nenhuma fonte/configuração alterada.'
        return
    fi
    case ${LB_VERSION:-stable} in
        latest|stable|'') ;;
        lts) lb_die "$name não publica canal LTS; escolha stable ou uma versão explícita.";;
    esac
    # ──────────────────────────────────────────────────────────────────────
    # ETAPA 2 — Preparar origem oficial e validar assinatura
    # ──────────────────────────────────────────────────────────────────────
    lb_step 'Preparar origem oficial e validar assinatura'
    lb_apt_update
    lb_apt_install ca-certificates curl gnupg
    lb_repo "$name" "$key" "$uri" "$suite" "$components" "$fingerprints" "$format"
    lb_apt_update
    local candidate target
    candidate=$(lb_apt_candidate "$package")
    [[ -n $candidate && $candidate != '(none)' ]] || lb_die 'Nenhuma versão candidata autenticada disponível.'
    target=$candidate
    case ${LB_VERSION:-stable} in
        latest|stable|'') ;;
        *) target=$LB_VERSION
           apt-cache madison "$package" | awk '{print $3}' | grep -Fx -- "$target" >/dev/null || lb_die "Versão $target não disponível na origem configurada.";;
    esac
    apt-cache madison "$package" | awk -v v="$target" -v u="${uri%/}" '$3==v && ($5==u || $5==u"/") {found=1} END {exit !found}' || lb_die 'Versão selecionada não confirmada no repositório do fornecedor.'
    lb_msg "Versão selecionada: $target. Atualizações futuras: APT; stable/latest representam o candidato disponível."
    # ──────────────────────────────────────────────────────────────────────
    # ETAPA 3 — Instalar e validar pacote
    # ──────────────────────────────────────────────────────────────────────
    lb_step 'Instalar e validar pacote'
    if declare -F lb_app_before_install >/dev/null; then lb_app_before_install; fi
    if [[ $LB_ACTION == reinstall ]]; then
        lb_apt_install --reinstall "$package=$target"
    else
        lb_apt_install "$package=$target"
    fi
    if declare -F lb_app_after_install >/dev/null; then lb_app_after_install; fi
    lb_app_validate "$package" "$executable"
    [[ $(dpkg-query -W -f='${Version}' "$package") == "$target" ]] || lb_die 'A versão instalada diverge da selecionada.'
    lb_finish 'Pacote validado; abra o aplicativo no menu e confirme funcionamento.'
}

# ──────────────────────────────────────────────────────────────────────
# Aplicativo disponível nos repositórios oficiais Debian (lb_app_debian)
# ──────────────────────────────────────────────────────────────────────
lb_app_debian() {
    local package=$1 executable=$2 installed=0 selected='' candidate origin upstream
    lb_assert_no_extra
    [[ -z $LB_SOURCE || $LB_SOURCE == debian ]] || lb_die 'Esta receita usa Debian oficial; não adiciona outras origens.'
    [[ $LB_SCOPE == none && -z $LB_PROJECT ]] || lb_die 'Aplicativos APT têm escopo de sistema.'
    [[ $LB_VERSION != lts ]] || lb_die 'Esta ferramenta não possui canal LTS nesta receita.'
    # ETAPA 1 — Diagnosticar pacote e instalação existente.
    lb_step 'Detectar pacote Debian e escolher ação'
    if lb_check_package "$package"; then installed=1; fi
    if [[ $LB_MODE == check ]]; then
        apt-cache policy "$package"
        lb_app_validate "$package" "$executable"
        lb_finish 'Diagnóstico local; abertura gráfica e origem efetiva precisam de conferência.'
        return
    fi
    lb_select_action "$installed"
    if [[ $LB_ACTION == keep ]]; then
        lb_app_validate "$package" "$executable"
        lb_finish 'Instalação mantida.'
        return
    fi
    # ETAPA 2 — Resolver versão disponível na origem Debian.
    lb_step 'Atualizar índices e resolver versão Debian'
    lb_apt_update
    while IFS='|' read -r _ candidate origin; do
        candidate=${candidate//[[:space:]]/}
        [[ -n $candidate ]] || continue
        [[ $origin =~ https?://(deb\.debian\.org|security\.debian\.org)/(debian|debian-security)[[:space:]] ]] || continue
        [[ $origin == *' trixie/'* || $origin == *' trixie-security/'* || $origin == *' trixie-updates/'* ]] || continue
        upstream=${candidate#*:}; upstream=${upstream%%-*}
        if [[ -n $LB_VERSION && $LB_VERSION != latest && $LB_VERSION != stable ]]; then
            [[ $candidate == "$LB_VERSION" || $upstream == "$LB_VERSION" ]] || continue
        fi
        if [[ -z $selected ]] || dpkg --compare-versions "$candidate" gt "$selected"; then selected=$candidate; fi
    done < <(apt-cache madison "$package")
    [[ -n $selected ]] || lb_die 'Versão solicitada indisponível no Debian oficial; origem preservada.'
    lb_msg "Versão concreta: $selected; origem Debian; atualizações por APT."
    # ETAPA 3 — Instalar pacote e confirmar versão exata.
    lb_step 'Instalar e validar o pacote Debian'
    local opts=()
    [[ $LB_ACTION != reinstall ]] || opts+=(--reinstall)
    lb_apt_install "${opts[@]}" "$package=$selected"
    lb_app_validate "$package" "$executable"
    [[ $(dpkg-query -W -f='${Version}' "$package") == "$selected" ]] || lb_die 'Versão instalada diverge da selecionada.'
    lb_finish 'Pacote validado; abertura gráfica pendente.'
}
