#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# BIBLIOTECAS DE INSTALAÇÃO — BIBLIOTECA COMUM
# ══════════════════════════════════════════════════════════════════════
# Sistema-alvo: LMDE 7 Gigi / Debian 13 (Bash).
# Finalidade: Compartilhar diagnóstico, apresentação, confirmações, backups, APT e assinaturas.
# Uso: Biblioteca de funções; carregar com source, não executar diretamente.
# Dependências locais: nenhuma biblioteca local.
# Organização: títulos sem número; etapas executadas com numeração sequencial.
# Notas específicas:
# Auxiliares compartilhados — LMDE 7 / Debian 13. Não executar diretamente.
# ══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
export LC_ALL=C
LB_TMP=''
LB_BACKUP_DIR=''
LB_MODE=install
LB_VERSION=''
LB_VERSION_EXPLICIT=0
LB_SCOPE=none
LB_SCOPE_EXPLICIT=0
LB_PROJECT=''
LB_VENDOR=temurin
LB_SOURCE=''
LB_YES=0
LB_ACTION=install
LB_EXTRA=()
LB_STEP_NUMBER=0


# ──────────────────────────────────────────────────────────────────────
# Mensagens informativas (lb_msg)
# ──────────────────────────────────────────────────────────────────────
lb_msg() { printf '%s\n' "$*"; }

# ──────────────────────────────────────────────────────────────────────
# Avisos (lb_warn)
# ──────────────────────────────────────────────────────────────────────
lb_warn() { printf '⚠ %s\n' "$*" >&2; }

# ──────────────────────────────────────────────────────────────────────
# Interrupção por falha (lb_die)
# ──────────────────────────────────────────────────────────────────────
lb_die() { printf '✗ %s\n' "$*" >&2; exit 1; }

# ──────────────────────────────────────────────────────────────────────
# Apresentação dos títulos (lb_title)
# ──────────────────────────────────────────────────────────────────────
lb_title() { printf '\n═════════════════════════════════════════════════════════\n%s\n═════════════════════════════════════════════════════════\n' "$*"; }

# ──────────────────────────────────────────────────────────────────────
# Apresentação e numeração das etapas (lb_step)
# ──────────────────────────────────────────────────────────────────────
lb_step() {
    LB_STEP_NUMBER=$((LB_STEP_NUMBER + 1))
    printf '\n─────────────────────────────────────────────────────────\nETAPA %s — %s\n─────────────────────────────────────────────────────────\n' "$LB_STEP_NUMBER" "$*"
}

# ──────────────────────────────────────────────────────────────────────
# Ajuda de uso (lb_usage)
# ──────────────────────────────────────────────────────────────────────
lb_usage() {
    cat <<'EOF'
Uso: bash "SCRIPT.sh" [opções]
  --check                 Somente leitura; não baixa nem configura arquivos.
  --update | --reinstall  Atualizar ou reinstalar explicitamente.
  --version SELETOR      Versão exata, latest, stable ou lts quando aplicável.
  --source ORIGEM        debian, backports ou vendor, conforme a ferramenta.
  --scope ESCOPO         none, user ou project (linguagens; padrão none).
                        Flatpak usa --system fixo; não aceita --scope.
  --project DIRETORIO    Projeto para seleção local de linguagem.
  --vendor FORNECEDOR    Java; Temurin é apenas o padrão inicial.
  --yes                   Aceitar as transações propostas; use após revisão.
  --help                  Mostrar ajuda, sem alterações.
Execute como usuário normal, sem sudo bash. Leve a pasta scripts/ completa, incluindo lib/, dev-tools/ e user-tools/.
Consulte README.md para opções específicas e limites de cada script.
EOF
}

# ──────────────────────────────────────────────────────────────────────
# Finalização dos arquivos temporários (lb_cleanup)
# ──────────────────────────────────────────────────────────────────────
lb_cleanup() { if [[ -n "$LB_TMP" && -d "$LB_TMP" ]]; then rm -rf -- "$LB_TMP"; fi; }

# ──────────────────────────────────────────────────────────────────────
# Relato de falha e retorno (lb_error)
# ──────────────────────────────────────────────────────────────────────
lb_error() {
    local status=$1 line=$2
    printf '\n✗ Etapa interrompida (linha %s, código %s).\n' "$line" "$status" >&2
    [[ -z "$LB_BACKUP_DIR" ]] || printf 'Retorno preservado: %s\n' "$LB_BACKUP_DIR" >&2
    return "$status"
}

# ──────────────────────────────────────────────────────────────────────
# Inicialização e diagnóstico do ambiente (lb_init)
# ──────────────────────────────────────────────────────────────────────
lb_init() {
    local title=$1 option
    shift
    while (($#)); do
        option=$1; shift
        case "$option" in
            --help|-h) lb_usage; exit 0 ;;
            --check|--update|--reinstall)
                [[ "$LB_MODE" == install ]] || lb_die 'Use uma única ação.'
                LB_MODE=${option#--} ;;
            --yes) LB_YES=1 ;;
            --version|--scope|--project|--vendor|--source)
                (($#)) && [[ -n "$1" && "$1" != --* ]] || lb_die "Falta valor para $option."
                case "$option" in
                    --version) LB_VERSION=$1; LB_VERSION_EXPLICIT=1 ;;
                    --scope) LB_SCOPE=$1; LB_SCOPE_EXPLICIT=1 ;;
                    --project) LB_PROJECT=$1 ;;
                    --vendor) LB_VENDOR=$1 ;;
                    --source) LB_SOURCE=$1 ;;
                esac
                shift ;;
            *) LB_EXTRA+=("$option") ;;
        esac
    done
    [[ "$LB_SCOPE" =~ ^(none|user|project)$ ]] || lb_die 'Escopo inválido.'
    [[ -z "$LB_SOURCE" || "$LB_SOURCE" =~ ^(debian|backports|vendor)$ ]] || lb_die 'Origem inválida.'
    [[ -z "$LB_VERSION" || "$LB_VERSION" =~ ^[[:alnum:]][[:alnum:].+:~_-]*$ ]] || lb_die 'Seletor de versão inválido.'
    [[ "$LB_VENDOR" =~ ^[[:alnum:]][[:alnum:]_-]*$ ]] || lb_die 'Fornecedor inválido.'
    [[ $(uname -s) == Linux ]] || lb_die 'Alvo: Linux LMDE 7 / Debian 13.'
    [[ $EUID -ne 0 ]] || lb_die 'Execute na sua conta normal, sem sudo bash.'
    [[ -n ${HOME:-} && -d "$HOME" ]] || lb_die 'Perfil pessoal indisponível.'
    [[ -r /etc/os-release && -r /etc/debian_version ]] || lb_die 'Base Debian não identificada.'
    source /etc/os-release
    local debian_version
    debian_version=$(cat /etc/debian_version)
    [[ ${ID:-} == debian || " ${ID_LIKE:-} " == *' debian '* || ${ID:-} == linuxmint ]] || lb_die 'Distribuição fora do escopo Debian.'
    [[ ${DEBIAN_CODENAME:-${VERSION_CODENAME:-}} == trixie || "$debian_version" == 13* || "$debian_version" == trixie* ]] || lb_die 'Base diferente de Debian 13/Trixie; não testada por estes scripts.'
    LB_ARCH=$(dpkg --print-architecture)
    [[ "$LB_ARCH" == amd64 || "$LB_ARCH" == arm64 ]] || lb_die 'Arquitetura fora do escopo amd64/arm64.'
    [[ "$LB_SCOPE" != project || -n "$LB_PROJECT" ]] || lb_die 'Use --project DIRETORIO com --scope project.'
    if [[ -n "$LB_PROJECT" ]]; then
        [[ -d "$LB_PROJECT" ]] || lb_die 'Projeto não existe; não será criado automaticamente.'
        LB_PROJECT=$(cd -- "$LB_PROJECT" && pwd -P)
    fi
    trap lb_cleanup EXIT
    trap 'lb_error "$?" "$LINENO"' ERR
    LB_STEP_NUMBER=0
    lb_title "$title"
    lb_msg "Sistema: ${PRETTY_NAME:-Linux}; base trixie; arquitetura $LB_ARCH; ação $LB_MODE."
    if [[ "$LB_MODE" != check ]]; then
        [[ -w "$HOME" ]] || lb_die 'Perfil não permite escrita.'
    fi
}

# ──────────────────────────────────────────────────────────────────────
# Validação de opções adicionais (lb_assert_no_extra)
# ──────────────────────────────────────────────────────────────────────
lb_assert_no_extra() { ((${#LB_EXTRA[@]} == 0)) || lb_die "Opção não reconhecida: ${LB_EXTRA[*]}"; }

# ──────────────────────────────────────────────────────────────────────
# Confirmação de impacto (lb_confirm)
# ──────────────────────────────────────────────────────────────────────
lb_confirm() {
    local reply
    if ((LB_YES)); then return 0; fi
    [[ -t 0 ]] || lb_die 'Escolha exige terminal interativo; informe opções explícitas ou --yes.'
    read -r -p "$* [s/N]: " reply || lb_die 'Entrada encerrada.'
    [[ "$reply" =~ ^[sS]$ ]]
}

# ──────────────────────────────────────────────────────────────────────
# Escolha entre manter, instalar e atualizar (lb_select_action)
# ──────────────────────────────────────────────────────────────────────
lb_select_action() {
    local installed=$1 reply
    case "$LB_MODE" in
        check) LB_ACTION=keep ;;
        update|reinstall) LB_ACTION=$LB_MODE; [[ "$installed" == 1 ]] || LB_ACTION=install ;;
        install)
            LB_ACTION=install
            if [[ "$installed" == 1 ]]; then
                LB_ACTION=keep
                if ((LB_VERSION_EXPLICIT)); then
                    LB_ACTION=update
                elif [[ -t 0 && $LB_YES == 0 ]]; then
                    read -r -p 'Instalação existente: [m]anter, [a]tualizar ou [r]einstalar? [M]: ' reply || lb_die 'Entrada encerrada.'
                    case "${reply,,}" in ''|m) ;; a) LB_ACTION=update ;; r) LB_ACTION=reinstall ;; *) lb_die 'Escolha inválida.' ;; esac
                fi
            fi ;;
    esac
    lb_msg "Ação selecionada: $LB_ACTION."
}

# ──────────────────────────────────────────────────────────────────────
# Preparação de área temporária (lb_temp)
# ──────────────────────────────────────────────────────────────────────
lb_temp() {
    [[ "$LB_MODE" != check ]] || lb_die 'Download/escrita não permitido no diagnóstico.'
    [[ -n "$LB_TMP" ]] || LB_TMP=$(mktemp -d)
}

# ──────────────────────────────────────────────────────────────────────
# Download HTTPS (lb_download)
# ──────────────────────────────────────────────────────────────────────
lb_download() {
    [[ "$LB_MODE" != check ]] || lb_die 'Download não permitido no diagnóstico.'
    [[ "$1" == https://* ]] || lb_die 'Download exige HTTPS.'
    curl --proto '=https' --proto-redir '=https' -fsSL --retry 3 --connect-timeout 20 --max-time 300 "$1" -o "$2" || lb_die 'Download falhou; arquivo parcial não será utilizado.'
    [[ -s "$2" ]] || lb_die 'Download vazio.'
}

# ──────────────────────────────────────────────────────────────────────
# Cópias de retorno (lb_backup)
# ──────────────────────────────────────────────────────────────────────
lb_backup() {
    local target=$1 tag
    [[ "$LB_MODE" != check ]] || lb_die 'Backup não permitido no diagnóstico.'
    if [[ -z "$LB_BACKUP_DIR" ]]; then
        local base="$HOME/.local/state/linux-bootstrap/retorno"
        mkdir -p -- "$base"; chmod 700 -- "$base"
        LB_BACKUP_DIR=$(mktemp -d "$base/$(date +%Y%m%d-%H%M%S)-XXXXXX")
        lb_msg "Cópias de retorno: $LB_BACKUP_DIR"
    fi
    tag=$(printf '%s' "$target" | sha256sum); tag=${tag%% *}
    if [[ -e "$LB_BACKUP_DIR/$tag" || -e "$LB_BACKUP_DIR/$tag.ausente" ]]; then return 0; fi
    printf '%s\t%s\n' "$tag" "$target" >> "$LB_BACKUP_DIR/indice.tsv"
    if [[ -e "$target" || -L "$target" ]]; then
        cp -a -- "$target" "$LB_BACKUP_DIR/$tag" || lb_die "Não foi possível preservar $target; mudança interrompida."
    else
        printf 'Destino ausente antes da execução.\n' > "$LB_BACKUP_DIR/$tag.ausente"
    fi
}

# ──────────────────────────────────────────────────────────────────────
# Gravação protegida de arquivos (lb_write_file)
# ──────────────────────────────────────────────────────────────────────
lb_write_file() {
    local src=$1 dest=$2 mode=${3:-644} scope=${4:-user} staged parent
    [[ "$LB_MODE" != check ]] || lb_die 'Escrita não permitida no diagnóstico.'
    [[ -f "$src" ]] || lb_die 'Fonte de escrita ausente.'
    [[ ! -L "$dest" ]] || lb_die "Destino é link simbólico: $dest; revisão manual necessária."
    [[ ! -e "$dest" || -f "$dest" ]] || lb_die "Destino não é arquivo regular: $dest."
    parent=$(dirname -- "$dest")
    if [[ "$scope" == system ]]; then
        command -v sudo >/dev/null || lb_die 'sudo indisponível.'
        if [[ -f "$dest" ]] && sudo cmp -s -- "$src" "$dest"; then return 0; fi
        lb_backup "$dest"
        sudo install -d -m 755 -- "$parent"
        staged=$(sudo mktemp "$parent/.linux-bootstrap-XXXXXX")
        if ! sudo install -m "$mode" -- "$src" "$staged" || ! sudo mv -f -- "$staged" "$dest"; then
            sudo rm -f -- "$staged"; lb_die "Falha ao gravar $dest."
        fi
    else
        if [[ -f "$dest" ]] && cmp -s -- "$src" "$dest"; then return 0; fi
        lb_backup "$dest"
        mkdir -p -- "$parent"
        staged=$(mktemp "$parent/.linux-bootstrap-XXXXXX")
        if ! install -m "$mode" -- "$src" "$staged" || ! mv -f -- "$staged" "$dest"; then
            rm -f -- "$staged"; lb_die "Falha ao gravar $dest."
        fi
    fi
}

# ──────────────────────────────────────────────────────────────────────
# Integração no Bash (lb_bash_block)
# ──────────────────────────────────────────────────────────────────────
lb_bash_block() {
    local name=$1 content=$2 file="$HOME/.bashrc" start end
    start="# BEGIN linux-bootstrap $name"; end="# END linux-bootstrap $name"
    [[ ! -L "$file" ]] || lb_die '.bashrc é link; preserve sua organização antes de configurar automaticamente.'
    [[ ! -e "$file" || -f "$file" ]] || lb_die '.bashrc não é arquivo regular.'
    if [[ -e "$file" ]]; then
        bash --noprofile --norc -n "$file" || lb_die '.bashrc com erro de sintaxe.'
        awk -v start="$start" -v end="$end" '
          $0==start {if(open || seen) exit 1; open=1; seen=1; next}
          $0==end {if(!open) exit 1; open=0; next}
          END {if(open) exit 1}' "$file" || lb_die 'Marcadores Bash fora de ordem ou incompletos; arquivo preservado.'
    fi
    lb_temp
    if [[ -f "$file" ]]; then
        local expected actual
        expected=$(printf '%s\n%s\n%s' "$start" "$content" "$end")
        actual=$(awk -v start="$start" -v end="$end" '$0==start {keep=1} keep {print} $0==end {keep=0}' "$file")
        if [[ "$actual" == "$expected" ]]; then return 0; fi
    fi
    # Atualiza somente o bloco gerenciado, preservando linhas externas.
    if [[ -e "$file" ]]; then
        local begins ends
        begins=$(grep -cFx -- "$start" "$file" || :)
        ends=$(grep -cFx -- "$end" "$file" || :)
        [[ "$begins" == "$ends" && "$begins" -le 1 ]] || lb_die 'Marcadores Bash inconsistentes.'
        awk -v start="$start" -v end="$end" '$0==start {skip=1;next} $0==end {skip=0;next} !skip {print}' "$file" > "$LB_TMP/bashrc.base"
    else
        : > "$LB_TMP/bashrc.base"
    fi
    cp -- "$LB_TMP/bashrc.base" "$LB_TMP/bashrc.new"
    printf '\n%s\n%s\n%s\n' "$start" "$content" "$end" >> "$LB_TMP/bashrc.new"
    bash --noprofile --norc -n "$LB_TMP/bashrc.new"
    if [[ -e "$file" ]] && grep -qxF -- "$start" "$file" && cmp -s -- "$file" "$LB_TMP/bashrc.new"; then return 0; fi
    local file_mode=600
    [[ ! -e "$file" ]] || file_mode=$(stat -c '%a' "$file")
    lb_write_file "$LB_TMP/bashrc.new" "$file" "$file_mode" user
}

# ──────────────────────────────────────────────────────────────────────
# Verificação de pacote instalado (lb_check_package)
# ──────────────────────────────────────────────────────────────────────
lb_check_package() {
    local state
    state=$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null) || return 1
    [[ "$state" == 'install ok installed' ]]
}

# ──────────────────────────────────────────────────────────────────────
# Atualização dos índices APT (lb_apt_update)
# ──────────────────────────────────────────────────────────────────────
lb_apt_update() {
    [[ "$LB_MODE" != check ]] || lb_die 'Atualização APT não permitida no diagnóstico.'
    sudo apt-get -o APT::Update::Error-Mode=any update || lb_die 'Falha na atualização autenticada dos índices APT.'
}

# ──────────────────────────────────────────────────────────────────────
# Simulação e instalação APT (lb_apt_install)
# ──────────────────────────────────────────────────────────────────────
lb_apt_install() {
    (($#)) || lb_die 'Nenhum pacote solicitado.'
    [[ "$LB_MODE" != check ]] || lb_die 'Instalação APT não permitida no diagnóstico.'
    # ──────────────────────────────────────────────────────────────────────
    # ETAPA 1 — Transação APT — conferir impacto
    # ──────────────────────────────────────────────────────────────────────
    lb_step 'Transação APT — conferir impacto'
    sudo apt-get --simulate --no-remove install "$@" || lb_die 'Simulação APT falhou; instalação não será aplicada.'
    lb_confirm 'Aplicar esta instalação sem remover pacotes?' || lb_die 'Transação cancelada; etapas dependentes não executadas.'
    sudo apt-get --no-remove install -y "$@" || lb_die 'APT falhou; conferir preparação parcial e retorno.'
}

# ──────────────────────────────────────────────────────────────────────
# Consulta de versão candidata (lb_apt_candidate)
# ──────────────────────────────────────────────────────────────────────
lb_apt_candidate() {
    local value
    value=$(apt-cache policy "$1" | awk '$1=="Candidate:" {print $2}')
    [[ -n "$value" && "$value" != '(none)' ]] || lb_die "Sem candidato APT para $1."
    printf '%s\n' "$value"
}

# ──────────────────────────────────────────────────────────────────────
# Validação e configuração de repositório (lb_repo)
# ──────────────────────────────────────────────────────────────────────
lb_repo() {
    local name=$1 key_url=$2 uri=$3 suite=$4 components=$5 allowed=$6 format=${7:-inrelease}
    [[ "$name" =~ ^[a-z0-9-]+$ ]] || lb_die 'Nome de repositório inválido.'
    local source_file="/etc/apt/sources.list.d/$name.sources"
    local ring="/etc/apt/keyrings/linux-bootstrap-$name.gpg" f primary count=0
    lb_temp
    lb_download "$key_url" "$LB_TMP/$name.key"
    mkdir -m 700 -- "$LB_TMP/gnupg-$name"
    gpg --no-options --homedir "$LB_TMP/gnupg-$name" --batch --with-colons --show-keys "$LB_TMP/$name.key" > "$LB_TMP/$name.info" || lb_die "Chave GPG inválida em $name."
    # Examina somente fingerprints primários; subchaves são vinculadas pelo GPG.
    awk -F: '$1=="pub" {if($2=="r" || $2=="e") exit 1; primary=1;next} $1=="fpr" && primary {print $10;primary=0}' "$LB_TMP/$name.info" > "$LB_TMP/$name.fprs"
    while IFS= read -r primary; do
        [[ " $allowed " == *" $primary "* ]] || lb_die "Chave primária inesperada em $name: $primary."
        ((count+=1))
    done < "$LB_TMP/$name.fprs"
    ((count>0)) || lb_die "Nenhuma chave válida em $name."
    gpg --no-options --homedir "$LB_TMP/gnupg-$name" --batch --yes --dearmor --output "$LB_TMP/$name.gpg" "$LB_TMP/$name.key" || lb_die "Conversão de chave falhou em $name."
    local release_url
    if [[ "$suite" == */ ]]; then release_url="${uri%/}/$suite"; else release_url="${uri%/}/dists/$suite/"; fi
    if [[ "$format" == detached ]]; then
        lb_download "${release_url}Release" "$LB_TMP/$name.Release"
        lb_download "${release_url}Release.gpg" "$LB_TMP/$name.Release.gpg"
        gpgv --homedir "$LB_TMP/gnupg-$name" --status-fd 1 --keyring "$LB_TMP/$name.gpg" "$LB_TMP/$name.Release.gpg" "$LB_TMP/$name.Release" > "$LB_TMP/$name.status" || lb_die "Assinatura de metadados falhou em $name."
    else
        lb_download "${release_url}InRelease" "$LB_TMP/$name.InRelease"
        gpgv --homedir "$LB_TMP/gnupg-$name" --status-fd 1 --keyring "$LB_TMP/$name.gpg" "$LB_TMP/$name.InRelease" > "$LB_TMP/$name.status" || lb_die "Assinatura de metadados falhou em $name."
    fi
    grep -q ' VALIDSIG ' "$LB_TMP/$name.status" || lb_die "Metadados sem assinatura válida em $name."
    if grep -Eq ' (EXPKEYSIG|EXPSIG|REVKEYSIG|BADSIG|ERRSIG|NO_PUBKEY) ' "$LB_TMP/$name.status"; then lb_die "Assinatura inválida/expirada em $name."; fi
    # Não duplicar fontes de outro instalador nem sobrescrever fonte ambígua.
    local files=(/etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources)
    for f in "${files[@]}"; do
        [[ -f "$f" && "$f" != "$source_file" ]] || continue
        local matches
        local endpoint=${uri#*://}
        endpoint=${endpoint%/}
        matches=$(grep -F -- "$endpoint" "$f" || :)
        if grep -Eq '^[[:space:]]*[^#[:space:]]' <<< "$matches"; then
            lb_die "Fonte existente em $f; revise-a para evitar duplicação antes de usar este script."
        fi
    done
    {
        printf 'Types: deb\nURIs: %s\nSuites: %s\n' "$uri" "$suite"
        [[ -z "$components" ]] || printf 'Components: %s\n' "$components"
        printf 'Architectures: %s\nSigned-By: %s\n' "$LB_ARCH" "$ring"
    } > "$LB_TMP/$name.sources"
    if [[ -e "$source_file" ]] && ! cmp -s -- "$source_file" "$LB_TMP/$name.sources"; then
        lb_confirm "Atualizar a fonte $source_file conforme a configuração exibida?" || lb_die 'Fonte mantida; instalação interrompida.'
    fi
    lb_msg "Fonte: $uri; suite $suite; chave restrita a $name."
    lb_write_file "$LB_TMP/$name.gpg" "$ring" 644 system
    lb_write_file "$LB_TMP/$name.sources" "$source_file" 644 system
    lb_apt_update
}

# ──────────────────────────────────────────────────────────────────────
# Verificação de montagem (lb_require_mount)
# ──────────────────────────────────────────────────────────────────────
lb_require_mount() {
    local path=$1 line target source fs options
    line=$(findmnt -rn --mountpoint "$path" -o TARGET,SOURCE,FSTYPE,OPTIONS) || lb_die "Montagem obrigatória ausente: $path."
    read -r target source fs options <<< "$line"
    [[ "$target" == "$path" && "$fs" == ext4 && ",$options," == *,rw,* ]] || lb_die "Montagem não é ext4 gravável no destino exato: $path."
    [[ -b "$source" ]] || lb_die "Origem não é partição/dispositivo de bloco: $source."
    lb_msg "Montagem: $target ← $source ($fs). Confira a identidade física:"
    lsblk -b -o NAME,MODEL,SERIAL,SIZE,FSTYPE,MOUNTPOINTS "$source"
}

# ──────────────────────────────────────────────────────────────────────
# Detecção do Mise (lb_require_mise)
# ──────────────────────────────────────────────────────────────────────
lb_require_mise() {
    LB_MISE="$HOME/.local/bin/mise"
    if [[ ! -x "$LB_MISE" ]]; then LB_MISE=$(type -P mise || :); fi
    [[ -n "$LB_MISE" && -x "$LB_MISE" ]] || lb_die 'Mise não preparado. Execute primeiro 04 - Mise.sh e abra novo Bash.'
    "$LB_MISE" --version
}

# ──────────────────────────────────────────────────────────────────────
# Resumo e encerramento (lb_finish)
# ──────────────────────────────────────────────────────────────────────
lb_finish() {
    lb_title 'RESUMO'
    lb_msg "✓ $*"
    [[ -z "$LB_BACKUP_DIR" ]] || lb_msg "Retorno: $LB_BACKUP_DIR (consulte indice.tsv)."
    lb_msg 'Não foram removidas instalações ou dados anteriores automaticamente.'
}
