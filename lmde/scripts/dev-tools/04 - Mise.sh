#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# FERRAMENTAS DE DESENVOLVIMENTO — MISE
# ══════════════════════════════════════════════════════════════════════
# Sistema-alvo: LMDE 7 Gigi / Debian 13 (Bash).
# Finalidade: Instalar e validar o gerenciador no perfil pessoal; linguagens em receitas separadas.
# Uso: Receita de instalação; executar como usuário normal, sem sudo bash.
# Dependências locais: nenhuma biblioteca local.
# Organização: títulos sem número; etapas executadas com numeração sequencial.
# Notas específicas:
# Instalação do mise — Steady Rock, LMDE 7 Gigi (Debian 13), Bash.
# Outras derivadas Debian 13: ainda não testadas.
# Linguagens e migração de gerenciadores são responsabilidade de outros scripts.
# ══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail

usage() {
    cat <<'EOF'
Uso: bash "04 - Mise.sh" [--check | --update | --reinstall] [--version VERSAO]
  Sem opção: instala se ausente; mantém a versão existente; configura Bash.
  --check:   diagnóstico somente leitura, sem downloads ou alterações.
  --update:  busca a versão estável atual e substitui somente este mise pessoal.
  --reinstall: reinstala explicitamente a versão selecionada.
  --version: latest/stable ou versão exata; mise não possui canal LTS.
  --help:    mostra esta ajuda.
Execute como usuário normal, sem sudo. Sudo será usado apenas para dependências.
EOF
}

mode=install
requested=stable
while (($#)); do
    case "$1" in
        --check|--update|--reinstall)
            [[ "$mode" == install ]] || { usage >&2; exit 2; }
            mode=${1#--}; shift ;;
        --version)
            [[ $# -ge 2 ]] || { usage >&2; exit 2; }
            requested=${2#v}; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done
[[ "$requested" == stable || "$requested" == latest || "$requested" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf 'Versão inválida; não há canal LTS mise.\n' >&2; exit 2; }

fail() { printf '\n✗ %s\n' "$*" >&2; exit 1; }
title() { printf '\n═════════════════════════════════════════════════════════\n%s\n═════════════════════════════════════════════════════════\n' "$*"; }
step_number=0
step() {
    step_number=$((step_number + 1))
    printf '\n─────────────────────────────────────────────────────────\nETAPA %s — %s\n─────────────────────────────────────────────────────────\n' "$step_number" "$*"
}
work_dir=''
backup_dir=''
cleanup() { [[ -z "$work_dir" ]] || rm -rf -- "$work_dir"; }
trap cleanup EXIT
trap 'printf "\n✗ Falha na linha %s. A execução foi interrompida.\n" "$LINENO" >&2; [[ -z "$backup_dir" ]] || printf "Cópia de retorno: %s\n" "$backup_dir" >&2' ERR

title 'MISE — preparar o gerenciador de ferramentas'
# ──────────────────────────────────────────────────────────────────────
# ETAPA 1 — Identificar sistema e instalação existente
# ──────────────────────────────────────────────────────────────────────
step 'Identificar sistema e instalação existente'
[[ $(uname -s) == Linux ]] || fail 'Este script destina-se ao Linux.'
[[ $EUID -ne 0 ]] || fail 'Execute na sua conta normal, sem sudo bash.'
[[ -n ${HOME:-} && -d "$HOME" && -w "$HOME" ]] || fail 'Perfil pessoal indisponível para escrita.'
[[ -r /etc/os-release ]] || fail 'Não foi possível identificar a distribuição.'
# Arquivo de identificação fornecido pelo próprio sistema operacional.
source /etc/os-release
[[ -r /etc/debian_version ]] || fail 'Base Debian não identificada.'
debian_version=$(cat /etc/debian_version)
[[ ${DEBIAN_CODENAME:-${VERSION_CODENAME:-}} == trixie || "$debian_version" == 13* || "$debian_version" == trixie* ]] || fail 'Alvo inicial Debian 13/Trixie; outra base exige adaptação.'
case " ${ID:-} ${ID_LIKE:-} " in
    *' debian '*|*' linuxmint '*) ;;
    *) fail 'Distribuição fora do escopo inicial Debian 13/LMDE 7.' ;;
esac
case $(uname -m) in
    x86_64) platform=linux-x64 ;;
    aarch64|arm64) platform=linux-arm64 ;;
    *) fail 'Arquitetura fora do escopo inicial x86_64/arm64.' ;;
esac
printf 'Sistema: %s\nArquitetura do download: %s\n' "${PRETTY_NAME:-${ID:-Linux}}" "$platform"
printf 'Alvo de desenvolvimento: LMDE 7 Gigi; teste físico ainda pendente.\n'

mise_bin="$HOME/.local/bin/mise"
bashrc="$HOME/.bashrc"
activation='eval "$("$HOME/.local/bin/mise" activate bash)"'
[[ ! -L "$bashrc" || -e "$bashrc" ]] || fail '.bashrc é um link simbólico quebrado; revisão manual necessária.'
[[ ! -L "$mise_bin" ]] || fail 'Destino mise é um link simbólico; confira a instalação existente antes de continuar.'
[[ ! -e "$mise_bin" || -f "$mise_bin" ]] || fail 'Destino mise não é um arquivo regular.'
if [[ -e "$mise_bin" && ! -x "$mise_bin" ]]; then
    fail 'Existe um arquivo mise sem permissão de execução; revisão manual necessária.'
fi
# Não sobrepor uma instalação APT ou feita por outro método.
found=$(type -P mise || true)
if [[ -n "$found" && $(readlink -f -- "$found") != "$mise_bin" ]]; then
    fail "Outro mise está no PATH: $found. Este script não fará migração automática."
fi

need_activation=true
if [[ -e "$bashrc" ]]; then
    [[ -f "$bashrc" && -r "$bashrc" ]] || fail '.bashrc não é um arquivo legível.'
    bash --noprofile --norc -n "$bashrc"
    if grep -qxF -- "$activation" "$bashrc"; then
        need_activation=false
    elif grep -Eq '^[[:space:]]*[^#[:space:]].*mise.*activate.*bash' "$bashrc"; then
        fail 'Já existe outra ativação mise no .bashrc. Revise essa linha para evitar ativação duplicada.'
    fi
fi

installed=false
if [[ -x "$mise_bin" ]]; then
    current_output=$("$mise_bin" --version)
    printf '\nMise existente: %s\n' "$current_output"
    installed=true
else
    printf '\nMise pessoal ainda não instalado.\n'
fi
printf 'Executável: %s\nAtivação Bash já registrada: %s\n' "$mise_bin" "$([[ "$need_activation" == false ]] && printf sim || printf não)"

if [[ "$mode" == check ]]; then
    if [[ "$installed" == true && "$need_activation" == false ]]; then
        printf '\n✓ Executável e linha de ativação encontrados; confirme em um novo terminal com mise doctor.\n'
        exit 0
    fi
    printf '\n⚠ Preparação incompleta. Execute sem --check para instalar/configurar.\n'
    exit 1
fi

printf '\nImpacto: mise no perfil pessoal e ativação no .bashrc.\n'
printf 'Dependências ausentes poderão ser instaladas pelo APT. Nenhuma linguagem será instalada.\n'
[[ ! -e "$bashrc" || -w "$bashrc" ]] || fail '.bashrc não permite escrita.'

make_backup_dir() {
    if [[ -z "$backup_dir" ]]; then
        mkdir -p -- "$HOME/.local/state/linux-bootstrap/mise"
        backup_dir=$(mktemp -d "$HOME/.local/state/linux-bootstrap/mise/$(date +%Y%m%d-%H%M%S)-XXXXXX")
        printf '\nCópia de retorno: %s\n' "$backup_dir"
    fi
}

if [[ "$installed" == true && "$requested" != stable && "$requested" != latest && "$mode" == install && "${current_output%% *}" != "$requested" ]]; then
    fail 'Versão existente diferente da solicitada. Use --update ou --reinstall para uma mudança explícita.'
fi
if [[ "$installed" == false || "$mode" == update || "$mode" == reinstall ]]; then
    # ──────────────────────────────────────────────────────────────────────
    # ETAPA 2 — Preparar dependências e obter a versão estável
    # ──────────────────────────────────────────────────────────────────────
    step 'Preparar dependências e obter a versão estável'
    command -v apt-get >/dev/null || fail 'APT não disponível.'
    missing=()
    command -v curl >/dev/null || missing+=(curl)
    command -v minisign >/dev/null || missing+=(minisign)
    if ! dpkg-query -W -f='${Status}' ca-certificates 2>/dev/null | grep -qx 'install ok installed'; then
        missing+=(ca-certificates)
    fi
    if [[ ${#missing[@]} -gt 0 ]]; then
        printf 'Pacotes necessários: %s\n' "${missing[*]}"
        command -v sudo >/dev/null || fail 'sudo não disponível para instalar dependências.'
        sudo apt-get -o APT::Update::Error-Mode=any update
        sudo apt-get install -y "${missing[@]}"
    fi
    work_dir=$(mktemp -d)
    if [[ "$requested" == stable || "$requested" == latest ]]; then
        release_url=$(curl --proto '=https' --proto-redir '=https' -fsSL --retry 3 --connect-timeout 20 --max-time 120 \
            -o /dev/null -w '%{url_effective}' https://github.com/jdx/mise/releases/latest)
        release=${release_url##*/}
    else
        release="v$requested"
    fi
    [[ "$release" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail 'Resposta inesperada ao consultar a versão estável.'
    version=${release#v}
    asset="mise-${release}-${platform}"
    base="https://github.com/jdx/mise/releases/download/$release"
    printf 'Versão selecionada: %s\n' "$version"

    # ──────────────────────────────────────────────────────────────────────
    # ETAPA 3 — Baixar e verificar assinatura e integridade
    # ──────────────────────────────────────────────────────────────────────
    step 'Baixar e verificar assinatura e integridade'
    curl --proto '=https' --proto-redir '=https' -fsSL --retry 3 "$base/$asset" -o "$work_dir/$asset"
    curl --proto '=https' --proto-redir '=https' -fsSL --retry 3 "$base/SHASUMS256.txt" -o "$work_dir/SHASUMS256.txt"
    curl --proto '=https' --proto-redir '=https' -fsSL --retry 3 "$base/SHASUMS256.txt.minisig" -o "$work_dir/SHASUMS256.txt.minisig"
    # Chave pública oficial: https://github.com/jdx/mise/blob/main/minisign.pub
    minisign -Vm "$work_dir/SHASUMS256.txt" \
        -P 'RWTC3g8W3z4RZK3V3qv7fa1QY4JEWyBtqIHW+85QlJpZc5yG+uNYNBSZ'
    checksum=$(awk -v name="./$asset" '$2 == name {print $1}' "$work_dir/SHASUMS256.txt")
    [[ "$checksum" =~ ^[[:xdigit:]]{64}$ ]] || fail 'Hash do executável ausente ou ambíguo no manifesto assinado.'
    (cd "$work_dir"; printf '%s  %s\n' "$checksum" "$asset" | sha256sum --check --strict -)
    chmod 755 -- "$work_dir/$asset"
    candidate_output=$("$work_dir/$asset" --version)
    [[ "$candidate_output" == "$version "* || "$candidate_output" == "$version" ]] || fail 'Executável não reportou a versão selecionada.'

    # ──────────────────────────────────────────────────────────────────────
    # ETAPA 4 — Instalar o mise pessoal
    # ──────────────────────────────────────────────────────────────────────
    step 'Instalar o mise pessoal'
    current_version=${current_output:-}
    current_version=${current_version%% *}
    if [[ "$mode" != reinstall && ( "$requested" == stable || "$requested" == latest ) && "$installed" == true && "$current_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && \
          $(printf '%s\n%s\n' "$current_version" "$version" | sort -V | tail -n 1) == "$current_version" ]]; then
        printf 'A versão instalada é igual ou mais recente. Executável mantido.\n'
    else
        mkdir -p -- "$HOME/.local/bin"
        make_backup_dir
        if [[ "$installed" == true ]]; then
            cp -p -- "$mise_bin" "$backup_dir/mise"
        else
            printf 'Executável mise não existia antes desta execução.\n' > "$backup_dir/mise-ausente.txt"
        fi
        # Preparar no mesmo filesystem e substituir por renomeação.
        staged=$(mktemp "$HOME/.local/bin/.mise-XXXXXX")
        if ! install -m 755 -- "$work_dir/$asset" "$staged" || ! mv -f -- "$staged" "$mise_bin"; then
            rm -f -- "$staged"
            fail "Não foi possível instalar. Confira a cópia de retorno em $backup_dir."
        fi
    fi
else
    printf '\nInstalação existente mantida. Use --update quando desejar atualizar o mise.\n'
fi

# ──────────────────────────────────────────────────────────────────────
# ETAPA 5 — Configurar a ativação no Bash
# ──────────────────────────────────────────────────────────────────────
step 'Configurar a ativação no Bash'
if [[ "$need_activation" == true ]]; then
    make_backup_dir
    if [[ -e "$bashrc" ]]; then
        cp -pL -- "$bashrc" "$backup_dir/bashrc"
    else
        printf '.bashrc não existia antes desta execução.\n' > "$backup_dir/bashrc-ausente.txt"
    fi
    printf '\n# mise — linux-bootstrap\n%s\n' "$activation" >> "$bashrc"
    bash --noprofile --norc -n "$bashrc"
else
    printf 'Ativação já registrada. Nenhuma linha duplicada.\n'
fi

# ──────────────────────────────────────────────────────────────────────
# ETAPA 6 — Validar e apresentar o resultado
# ──────────────────────────────────────────────────────────────────────
step 'Validar e apresentar o resultado'
"$mise_bin" --version
# Gerar a integração sem executar hooks nem configurações de projetos.
"$mise_bin" activate bash | bash --noprofile --norc -n
grep -qxF -- "$activation" "$bashrc" || fail 'Ativação não encontrada após a configuração.'
printf '\n✓ Mise preparado em %s\n' "$mise_bin"
printf 'Abra um NOVO terminal Bash e confira:\n  command -v mise\n  mise --version\n  mise doctor\n'
printf 'O caminho deve ser ~/.local/bin/mise; o doctor deve informar activated: yes.\n'
[[ -z "$backup_dir" ]] || printf '\nCópia de retorno preservada: %s\n' "$backup_dir"
printf '\nPython, Node.js e Java serão tratados em scripts separados.\n'
