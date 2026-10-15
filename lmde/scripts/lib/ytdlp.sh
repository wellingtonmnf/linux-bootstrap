#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# BIBLIOTECAS DE INSTALAÇÃO — YT-DLP
# ══════════════════════════════════════════════════════════════════════
# Sistema-alvo: LMDE 7 / Debian 13; Bash.
# Finalidade: Seleção de releases, GPG/SHA, instalação atômica e retorno.
# Uso: source após common.sh; user-tools/07 - yt-dlp.sh é o consumidor.
# Dependências locais: common.sh; curl/GPG/Python/APT/executor JavaScript global.
# Organização: títulos sem números; etapas numeradas no instalador.
# Segurança: apenas 404/artefato ausente permite fallback, com confirmação.
# ══════════════════════════════════════════════════════════════════════
YT_LAUNCHER=/usr/local/bin/yt-dlp
YT_ROOT=/usr/local/lib/linux-bootstrap/yt-dlp
YT_KEY=AC0CBBE6848D6A873464AF4E57CF65933B5A7581
YT_CHANNEL=auto YT_CHANNEL_EXPLICIT=0 YT_RUNTIME_OPTION=auto YT_TEST_URL=''
YT_SOURCE='' YT_VERSION='' YT_RUNTIME='' YT_INSTALLED=0 YT_CONFLICT=0
YT_OLD_SOURCE='' YT_OLD_CHANNEL='' YT_OLD_VERSION=''

# ──────────────────────────────────────────────────────────────────────
# Ajuda e diagnóstico funcional sem rede ou modificações
# ──────────────────────────────────────────────────────────────────────
yt_usage() {
    cat <<'EOF'
yt-dlp: --channel auto|nightly|stable; --source vendor|backports|debian.
        --version latest|stable|AAAA.MM.DD[.BUILD]; não existe LTS.
        --js-runtime auto|CAMINHO_ABSOLUTO; instalação compartilhada.
        --test-url https://... consulta explícita, sem download de mídia.
Preferência de novas instalações: nightly > stable > Backports > Debian.
Fallback exige disponibilidade ausente e confirmação; falhas de segurança param.
Atualização preserva origem/canal. --check é somente local, retorno 1 em falha.
EOF
}
yt_check() {
    local status=0 p got
    if ((YT_INSTALLED==0 || YT_CONFLICT)); then status=1; fi
    if ! yt_runtime_detect; then lb_warn 'Executor JavaScript global compatível ausente.'; status=1; fi
    for p in /usr/bin/ffmpeg /usr/bin/ffprobe; do
        if [[ ! -x "$p" ]] || ! "$p" -version >/dev/null 2>&1; then lb_warn "Dependência ausente ou quebrada: $p."; status=1; fi
    done
    if ((YT_INSTALLED && YT_CONFLICT==0)); then
        p=/usr/bin/yt-dlp; [[ "$YT_OLD_SOURCE" != vendor ]] || p=$YT_LAUNCHER
        if got=$("$p" --ignore-config --no-plugin-dirs --no-update --version 2>/dev/null); then
            lb_msg "Executável efetivo: $p; versão: $got."
            [[ "$got" == "$YT_OLD_VERSION" ]] || { lb_warn 'Versão difere dos marcadores/pacote.'; status=1; }
        else lb_warn "Executável quebrado: $p."; status=1; fi
    fi
    lb_msg 'Diagnóstico local concluído; nenhum download ou alteração.'
    return "$status"
}

# ──────────────────────────────────────────────────────────────────────
# Opções específicas e validação dos seletores
# ──────────────────────────────────────────────────────────────────────
yt_options() {
    local i=0 option
    while ((i<${#LB_EXTRA[@]})); do
        option=${LB_EXTRA[i]}; ((i+=1))
        case "$option" in
            --channel|--js-runtime|--test-url)
                ((i<${#LB_EXTRA[@]})) || lb_die "Falta valor para $option."
                case "$option" in
                    --channel) YT_CHANNEL=${LB_EXTRA[i]}; YT_CHANNEL_EXPLICIT=1 ;;
                    --js-runtime) YT_RUNTIME_OPTION=${LB_EXTRA[i]} ;;
                    --test-url) YT_TEST_URL=${LB_EXTRA[i]} ;;
                esac
                ((i+=1)) ;;
            *) lb_die "Opção não reconhecida: $option." ;;
        esac
    done
    [[ "$YT_CHANNEL" =~ ^(auto|nightly|stable)$ ]] || lb_die 'Canal inválido; yt-dlp não possui LTS.'
    [[ "$LB_VERSION" != lts ]] || lb_die 'yt-dlp não possui LTS.'
    [[ -z "$LB_VERSION" || "$LB_VERSION" == latest || "$LB_VERSION" == stable || "$LB_VERSION" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}(\.[0-9]+)?(-[0-9A-Za-z.+~]+)?$ ]] || lb_die 'Versão yt-dlp inválida.'
    if [[ "$LB_VERSION" == stable && ( -z "$LB_SOURCE" || "$LB_SOURCE" == vendor ) ]]; then
        [[ "$YT_CHANNEL_EXPLICIT" == 0 || "$YT_CHANNEL" == stable ]] || lb_die '--version stable exige canal stable.'
        YT_CHANNEL=stable; YT_CHANNEL_EXPLICIT=1
    fi
    [[ "$LB_SCOPE_EXPLICIT" == 0 && -z "$LB_PROJECT" ]] || lb_die 'yt-dlp é compartilhado; --scope não se aplica.'
    [[ "$YT_RUNTIME_OPTION" == auto || "$YT_RUNTIME_OPTION" =~ ^/[a-zA-Z0-9_./+-]+$ ]] || lb_die 'Executor exige caminho absoluto sem espaços.'
    [[ -z "$YT_TEST_URL" || "$YT_TEST_URL" == https://* ]] || lb_die 'Teste exige URL HTTPS.'
    [[ "$LB_MODE" != check || -z "$YT_TEST_URL" ]] || lb_die '--check não realiza teste de rede.'
    [[ "$LB_SOURCE" != debian && "$LB_SOURCE" != backports || "$YT_CHANNEL_EXPLICIT" == 0 ]] || lb_die 'Canal aplica-se somente às releases oficiais.'
}

# ──────────────────────────────────────────────────────────────────────
# Inventário somente leitura; executáveis externos não são executados
# ──────────────────────────────────────────────────────────────────────
yt_detect() {
    local p owner shell_type; local -A seen=()
    while IFS= read -r p; do
        [[ -n "$p" && ( -e "$p" || -L "$p" ) && -z ${seen[$p]:-} ]] || continue
        seen[$p]=1
        lb_msg "Encontrado: $p"
        if [[ "$p" == "$YT_LAUNCHER" && ! -L "$p" ]] && grep -qxF '# linux-bootstrap managed yt-dlp' "$p"; then
            yt_secure_parent "$(dirname "$p")"
            yt_secure_file "$p"
            YT_INSTALLED=1; YT_OLD_SOURCE=vendor
            YT_OLD_CHANNEL=$(sed -n 's/^# channel: //p' "$p")
            YT_OLD_VERSION=$(sed -n 's/^# version: //p' "$p")
            YT_OLD_NATIVE=$(sed -n 's/^# executable: //p' "$p")
            YT_OLD_CHECKSUM=$(sed -n 's/^# sha256: //p' "$p")
            [[ "$YT_OLD_CHANNEL" =~ ^(nightly|stable)$ && "$YT_OLD_VERSION" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}(\.[0-9]+)?$ ]] || lb_die 'Marcadores gerenciados inválidos.'
            [[ "$YT_OLD_NATIVE" == "$YT_ROOT/releases/"* && "$YT_OLD_NATIVE" != *'/../'* && "$YT_OLD_NATIVE" =~ ^/[a-zA-Z0-9_./+-]+$ && "$YT_OLD_CHECKSUM" =~ ^[a-fA-F0-9]{64}$ ]] || lb_die 'Marcadores de integridade inválidos.'
            yt_secure_parent "$(dirname "$YT_OLD_NATIVE")"; yt_secure_file "$YT_OLD_NATIVE"
            printf '%s  %s\n' "$YT_OLD_CHECKSUM" "$YT_OLD_NATIVE" | sha256sum -c - || lb_die 'Integridade da instalação existente falhou.'
            lb_msg "Gerenciado pelo script: $YT_OLD_CHANNEL $YT_OLD_VERSION."
        elif [[ "$p" == /usr/bin/yt-dlp ]] && lb_check_package yt-dlp; then
            YT_INSTALLED=1; owner=$(dpkg-query -W -f='${Version}' yt-dlp)
            YT_OLD_VERSION=${owner#*:}; YT_OLD_VERSION=${YT_OLD_VERSION%%-*}
            if [[ "$owner" == *~bpo13* ]]; then YT_OLD_SOURCE=backports; else YT_OLD_SOURCE=debian; fi
            lb_msg "Pacote APT: $owner; origem $YT_OLD_SOURCE será conferida no catálogo."
        else
            YT_CONFLICT=1; lb_warn "Instalação externa preservada: $p. Migração requer decisão separada."
        fi
    done < <( { type -aP yt-dlp || :; printf '%s\n' "$YT_LAUNCHER" /usr/bin/yt-dlp /opt/yt-dlp/yt-dlp "$HOME/.local/bin/yt-dlp" "$HOME/.local/pipx/venvs/yt-dlp/bin/yt-dlp"; } )
    for p in "$HOME/.bashrc" "$HOME/.bash_aliases"; do
        if [[ -f "$p" ]] && grep -Eq '^[[:space:]]*(alias[[:space:]]+yt-dlp=|function[[:space:]]+yt-dlp|yt-dlp[[:space:]]*\(\))' "$p"; then
            YT_CONFLICT=1; lb_warn "Alias/função yt-dlp em $p; arquivo preservado, revise antes da instalação."
        fi
    done
    shell_type=$(type -t yt-dlp || :)
    if [[ "$shell_type" == alias || "$shell_type" == function ]]; then YT_CONFLICT=1; lb_warn 'Alias/função ativo de yt-dlp detectado; conteúdo preservado.'; fi
    if lb_check_package yt-dlp; then
        if [[ -e "$YT_LAUNCHER" ]]; then YT_CONFLICT=1; lb_warn 'Instalação manual e pacote APT concorrentes.'
        elif [[ ! -e /usr/bin/yt-dlp ]]; then
            YT_INSTALLED=1; owner=$(dpkg-query -W -f='${Version}' yt-dlp); YT_OLD_VERSION=${owner#*:}; YT_OLD_VERSION=${YT_OLD_VERSION%%-*}
            if [[ "$owner" == *~bpo13* ]]; then YT_OLD_SOURCE=backports; else YT_OLD_SOURCE=debian; fi
            lb_warn 'Pacote yt-dlp instalado, mas executável ausente. Reinstalação deve preservar origem APT.'
        fi
    fi
    lb_msg "Instalação detectada: $YT_INSTALLED; conflito: $YT_CONFLICT."
}
yt_assert_conflicts() { ((YT_CONFLICT==0)) || lb_die 'Conflito; nenhum instalador ou migração automática será executado.'; }
yt_preserve_source() {
    ((YT_INSTALLED)) || return 0
    [[ -z "$LB_SOURCE" || "$LB_SOURCE" == "$YT_OLD_SOURCE" ]] || lb_die 'Troca de origem exige plano de migração separado.'
    LB_SOURCE=$YT_OLD_SOURCE
    if [[ "$YT_OLD_SOURCE" == vendor ]]; then
        if [[ "$YT_CHANNEL_EXPLICIT" == 1 && "$YT_CHANNEL" != auto && "$YT_CHANNEL" != "$YT_OLD_CHANNEL" ]]; then
            lb_msg "Mudança explícita de canal: $YT_OLD_CHANNEL → $YT_CHANNEL; pode reduzir a versão."
            lb_confirm 'Mudar canal mantendo release e launcher anteriores para retorno?' || lb_die 'Mudança de canal cancelada.'
        else YT_CHANNEL=$YT_OLD_CHANNEL; fi
    fi
}

# ──────────────────────────────────────────────────────────────────────
# Executores JavaScript globais; não depende do perfil/Mise pessoal
# ──────────────────────────────────────────────────────────────────────
yt_runtime_probe() {
    local p=$1 v name=${1##*/}
    [[ -x "$p" && ! -L "$p" ]] || return 1
    case "$p" in "$HOME"/*) return 1;; esac
    # Um launcher compartilhado nunca executa runtimes graváveis por usuários.
    if ! (yt_secure_parent "$(dirname "$p")"; yt_secure_file "$p"); then return 1; fi
    case "$name" in
        deno) v=$("$p" --version) || return 1; v=$(awk 'NR==1 {print $2}' <<< "$v"); dpkg --compare-versions "$v" ge 2.3.0 || return 1; YT_RUNTIME="deno:$p" ;;
        node|nodejs) v=$("$p" --version) || return 1; [[ "$v" =~ ^v([0-9]+)\. ]] && ((${BASH_REMATCH[1]}>=22)) || return 1; "$p" -e 'if(1+1!==2) process.exit(1)' || return 1; YT_RUNTIME="node:$p" ;;
        qjs) v=$("$p" --help 2>&1) || :; v=$(grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' <<< "$v" | head -1); [[ -n "$v" && "$v" > 2023-12-08 ]] || return 1; "$p" -e 'if(1+1!==2) throw Error("runtime")' || return 1; YT_RUNTIME="quickjs:$p" ;;
        *) return 1 ;;
    esac
    lb_msg "Executor JavaScript: $YT_RUNTIME."
}
yt_runtime_detect() {
    local p
    if [[ "$YT_RUNTIME_OPTION" != auto ]]; then yt_runtime_probe "$YT_RUNTIME_OPTION"; return $?; fi
    for p in /usr/bin/deno /usr/local/bin/deno /usr/bin/node /usr/bin/qjs; do if yt_runtime_probe "$p"; then return 0; fi; done
    return 1
}
yt_runtime_prepare() {
    if yt_runtime_detect; then return 0; fi
    [[ "$YT_RUNTIME_OPTION" == auto ]] || lb_die 'Executor explicitado indisponível ou incompatível.'
    yt_apt_version quickjs debian '' || lb_die 'QuickJS Debian indisponível; prepare executor global compatível.'
    lb_msg "Executor global ausente: instalar QuickJS Debian $YT_APT_VERSION."
    lb_apt_install "quickjs=$YT_APT_VERSION"
    yt_runtime_probe /usr/bin/qjs || lb_die 'QuickJS instalado não passou validação.'
}

# ──────────────────────────────────────────────────────────────────────
# APT: URI/suite exatas e maior versão; não adiciona Backports
# ──────────────────────────────────────────────────────────────────────
yt_apt_version() {
    local package=$1 source=$2 requested=$3 pkg candidate origin upstream
    YT_APT_VERSION=''
    while IFS='|' read -r pkg candidate origin; do
        candidate=${candidate//[[:space:]]/}
        [[ "$origin" =~ ^[[:space:]]*https?://(deb\.debian\.org|security\.debian\.org)/(debian|debian-security)[[:space:]] ]] || continue
        if [[ "$source" == backports ]]; then [[ "$origin" == *' trixie-backports/'* ]] || continue
        else [[ "$origin" == *' trixie/'* || "$origin" == *' trixie-security/'* || "$origin" == *' trixie-updates/'* ]] || continue; fi
        upstream=${candidate#*:}; upstream=${upstream%%-*}
        [[ -z "$requested" || "$requested" == latest || "$requested" == stable || "$requested" == "$candidate" || "$requested" == "$upstream" ]] || continue
        if [[ -z "$YT_APT_VERSION" ]] || dpkg --compare-versions "$candidate" gt "$YT_APT_VERSION"; then YT_APT_VERSION=$candidate; fi
    done < <(apt-cache madison "$package")
    [[ -n "$YT_APT_VERSION" ]]
}

# ──────────────────────────────────────────────────────────────────────
# Catálogo HTTPS: somente 404 significa indisponibilidade
# ──────────────────────────────────────────────────────────────────────
yt_catalog() {
    local url=$1 destination=$2 status
    status=$(curl --proto '=https' --proto-redir '=https' -sSL --retry 3 --connect-timeout 20 --max-time 120 -w '%{http_code}' "$url" -o "$destination") || lb_die 'Falha de rede no catálogo; fallback proibido.'
    [[ "$status" != 404 ]] || return 44
    [[ "$status" == 200 && -s "$destination" ]] || lb_die "Catálogo HTTP $status; fallback proibido."
}
yt_release() {
    local channel=$1 repo tag endpoint result
    repo=yt-dlp/yt-dlp; [[ "$channel" != nightly ]] || repo=yt-dlp/yt-dlp-nightly-builds
    tag=${LB_VERSION:-latest}; [[ "$tag" != stable ]] || tag=latest
    endpoint=latest; [[ "$tag" == latest ]] || endpoint="tags/$tag"
    if yt_catalog "https://api.github.com/repos/$repo/releases/$endpoint" "$LB_TMP/release.json"; then :; else result=$?; return "$result"; fi
    # Metadata orienta seleção; assinatura/hash autenticam o artefato.
    if /usr/bin/python3 -I - "$LB_TMP/release.json" "$LB_ARCH" "$repo" "$tag" > "$LB_TMP/selection" <<'PY'
import json,re,sys
with open(sys.argv[1]) as f: d=json.load(f)
repo=sys.argv[3]; tag=d.get('tag_name','')
if d.get('draft') or not re.fullmatch(r'\d{4}\.\d{2}\.\d{2}(\.\d+)?',tag): raise SystemExit('Metadata de release inválida')
if sys.argv[4]!='latest' and sys.argv[4]!=tag: raise SystemExit('Versão retornada difere da solicitada')
name='yt-dlp_linux' if sys.argv[2]=='amd64' else 'yt-dlp_linux_aarch64'
assets={a['name']:a for a in d.get('assets',[])}
names=[name,'SHA2-256SUMS','SHA2-256SUMS.sig']
if name not in assets: raise SystemExit(44)
if any(n not in assets for n in names[1:]): raise SystemExit('Manifesto/assinatura ausentes: falha de segurança')
print(tag); print(name)
for n in names:
 u=assets[n].get('browser_download_url','')
 if u!=f'https://github.com/{repo}/releases/download/{tag}/{n}': raise SystemExit('URL de artefato inesperada')
 print(u)
PY
    then :; else result=$?; [[ "$result" == 44 ]] && return 44; lb_die 'Metadados inválidos; fallback proibido.'; fi
    mapfile -t YT_SELECTION < "$LB_TMP/selection"
    YT_VERSION=${YT_SELECTION[0]}; YT_ASSET=${YT_SELECTION[1]}; YT_CHANNEL=$channel; YT_SOURCE=vendor
}
yt_select() {
    local source rc; local choices=()
    if [[ "$LB_SOURCE" == debian || "$LB_SOURCE" == backports ]]; then choices=("$LB_SOURCE")
    elif [[ "$YT_CHANNEL" != auto ]]; then choices=("$YT_CHANNEL")
    elif [[ "$LB_SOURCE" == vendor ]]; then choices=(nightly stable)
    else choices=(nightly stable backports debian); fi
    for source in "${choices[@]}"; do
        if [[ "$source" == nightly || "$source" == stable ]]; then
            if yt_release "$source"; then return 0; else rc=$?; [[ "$rc" == 44 ]] || lb_die 'Falha sem permissão de fallback.'; fi
        elif yt_apt_version yt-dlp "$source" "$LB_VERSION"; then
            YT_SOURCE=$source; YT_CHANNEL=apt; YT_VERSION=${YT_APT_VERSION#*:}; YT_VERSION=${YT_VERSION%%-*}; return 0
        fi
        lb_warn "Origem $source sem versão/artefato disponível."
        [[ "$source" == "${choices[-1]}" ]] || lb_confirm 'Consultar próxima origem na ordem aprovada?' || lb_die 'Fallback cancelado.'
    done
    lb_die 'Nenhuma versão disponível nas origens permitidas; fontes não foram adicionadas.'
}

# ──────────────────────────────────────────────────────────────────────
# GPG isolado, identidade primária fixada e SHA-256 exato
# ──────────────────────────────────────────────────────────────────────
yt_verify() {
    local fingerprints checksum count
    lb_download https://raw.githubusercontent.com/yt-dlp/yt-dlp/master/public.key "$LB_TMP/public.key"
    mkdir -m 700 "$LB_TMP/gnupg"
    gpg --no-options --homedir "$LB_TMP/gnupg" --batch --with-colons --show-keys "$LB_TMP/public.key" > "$LB_TMP/key.info" || lb_die 'Chave inválida.'
    fingerprints=$(awk -F: '$1=="pub" {if($2=="r" || $2=="e")exit 1;p=1;next} $1=="fpr"&&p {print $10;p=0}' "$LB_TMP/key.info") || lb_die 'Chave expirada/revogada.'
    [[ "$fingerprints" == "$YT_KEY" ]] || lb_die 'Identidade primária GPG inesperada; fallback proibido.'
    gpg --no-options --homedir "$LB_TMP/gnupg" --batch --yes --dearmor --output "$LB_TMP/key.gpg" "$LB_TMP/public.key" || lb_die 'Conversão GPG falhou.'
    gpgv --homedir "$LB_TMP/gnupg" --status-fd 1 --keyring "$LB_TMP/key.gpg" "$LB_TMP/SHA2-256SUMS.sig" "$LB_TMP/SHA2-256SUMS" > "$LB_TMP/signature.status" || lb_die 'Assinatura inválida; fallback proibido.'
    grep -q ' VALIDSIG ' "$LB_TMP/signature.status" || lb_die 'Assinatura válida ausente.'
    ! grep -Eq ' (EXPKEYSIG|EXPSIG|REVKEYSIG|BADSIG|ERRSIG|NO_PUBKEY) ' "$LB_TMP/signature.status" || lb_die 'Assinatura inválida/expirada.'
    count=$(awk -v n="$YT_ASSET" '$2==n || $2=="*"n {c++} END {print c+0}' "$LB_TMP/SHA2-256SUMS")
    [[ "$count" == 1 ]] || lb_die 'Manifesto sem entrada única do executável.'
    checksum=$(awk -v n="$YT_ASSET" '$2==n || $2=="*"n {print $1}' "$LB_TMP/SHA2-256SUMS")
    [[ "$checksum" =~ ^[a-fA-F0-9]{64}$ ]] || lb_die 'Hash inválido.'
    printf '%s  %s\n' "$checksum" "$LB_TMP/candidate" | sha256sum -c - || lb_die 'Integridade falhou; candidato não será executado.'
    YT_CHECKSUM=$checksum
}
yt_probe_version() {
    local got
    got=$("$1" --ignore-config --no-plugin-dirs --no-update --version) || return 1
    [[ "$got" == "$YT_VERSION" ]]
}

# ──────────────────────────────────────────────────────────────────────
# Diretórios administrativos e launcher com atualização restrita
# ──────────────────────────────────────────────────────────────────────
yt_secure_parent() {
    local p=$1 uid mode
    while [[ "$p" != / ]]; do
        [[ ! -L "$p" ]] || lb_die "Diretório simbólico recusado: $p."
        if [[ -e "$p" ]]; then
            [[ -d "$p" ]] || lb_die "Diretório esperado: $p."
            uid=$(stat -c '%u' "$p"); mode=$(stat -c '%a' "$p")
            [[ "$uid" == 0 ]] && (( (8#$mode & 0022)==0 )) || lb_die "Diretório sem proteção administrativa: $p."
        fi
        p=$(dirname "$p")
    done
}
yt_secure_file() {
    local p=$1 uid mode
    [[ -f "$p" && ! -L "$p" ]] || lb_die 'Arquivo gerenciado não regular.'
    uid=$(stat -c '%u' "$p"); mode=$(stat -c '%a' "$p")
    [[ "$uid" == 0 ]] && (( (8#$mode & 0022)==0 )) || lb_die 'Arquivo gerenciado sem proteção administrativa.'
}
yt_launcher() {
    cat > "$LB_TMP/launcher" <<EOF
#!/usr/bin/env bash
# linux-bootstrap managed yt-dlp
# channel: $YT_CHANNEL
# version: $YT_VERSION
# executable: $YT_NATIVE
# sha256: ${YT_CHECKSUM:-}
# Atualizador exclusivo: 07 - yt-dlp.sh --update. Não editar esta seleção.
set -euo pipefail
before=() after=() delimiter=0
for argument in "\$@"; do
    case "\$argument" in -[^-]*U*|-U|--update|--update-to|--update-to=*|--update=*) printf '%s\\n' 'Atualize pelo script de instalação (--update).' >&2; exit 2;; esac
    if ((delimiter)); then after+=("\$argument")
    elif [[ "\$argument" == -- ]]; then delimiter=1
    else before+=("\$argument"); fi
 done
if ((delimiter)); then
    exec '$YT_NATIVE' "\${before[@]}" --no-update --no-js-runtimes --js-runtimes '$YT_RUNTIME' -- "\${after[@]}"
else
    exec '$YT_NATIVE' "\${before[@]}" --no-update --no-js-runtimes --js-runtimes '$YT_RUNTIME'
fi
EOF
    bash -n "$LB_TMP/launcher" || lb_die 'Launcher inválido.'
}
yt_manual_install() {
    local i previous='' staged
    for i in 2 3 4; do
        case "$i" in 2) lb_download "${YT_SELECTION[i]}" "$LB_TMP/candidate";; 3) lb_download "${YT_SELECTION[i]}" "$LB_TMP/SHA2-256SUMS";; 4) lb_download "${YT_SELECTION[i]}" "$LB_TMP/SHA2-256SUMS.sig";; esac
    done
    yt_verify
    chmod 755 "$LB_TMP/candidate"
    yt_probe_version "$LB_TMP/candidate" || lb_die 'Candidato verificado não funciona ou versão não corresponde.'
    yt_secure_parent /usr/local/bin; yt_secure_parent "$YT_ROOT/releases"
    [[ ! -L "$YT_LAUNCHER" ]] || lb_die 'Launcher simbólico recusado.'
    # Cada release é novo caminho; launcher atômico é o único commit.
    sudo install -d -m 755 "$YT_ROOT/releases"
    staged=$(sudo mktemp -d "$YT_ROOT/releases/$YT_CHANNEL-$YT_VERSION-XXXXXX")
    sudo chmod 755 "$staged"
    YT_NATIVE="$staged/yt-dlp"
    sudo install -m 755 "$LB_TMP/candidate" "$YT_NATIVE" || lb_die 'Release não preparada; launcher anterior preservado.'
    yt_secure_file "$YT_NATIVE"
    printf '%s  %s\n' "$YT_CHECKSUM" "$YT_NATIVE" | sha256sum -c - || lb_die 'Cópia instalada falhou em integridade; launcher anterior preservado.'
    yt_launcher
    if [[ -f "$YT_LAUNCHER" ]]; then previous="$LB_TMP/previous"; cp -a "$YT_LAUNCHER" "$previous" || lb_die 'Não foi possível preservar launcher.'; fi
    lb_write_file "$LB_TMP/launcher" "$YT_LAUNCHER" 755 system
    if ! yt_probe_version "$YT_LAUNCHER"; then
        if [[ -n "$previous" ]]; then lb_write_file "$previous" "$YT_LAUNCHER" 755 system
        else sudo rm -f -- "$YT_LAUNCHER" || lb_die 'Falha na validação e retorno do launcher.'; fi
        lb_die 'Validação final falhou; launcher anterior restaurado. Releases anteriores preservadas.'
    fi
    YT_COMMAND=$YT_LAUNCHER
    lb_msg "Release: $YT_NATIVE; retorno via launcher preservado em indice.tsv."
}

# ──────────────────────────────────────────────────────────────────────
# APT: EJS e opções atuais devem funcionar, sem pressupor compatibilidade
# ──────────────────────────────────────────────────────────────────────
yt_apt_install() {
    local selected=$YT_APT_VERSION options=()
    /usr/bin/python3 -I -c 'import yt_dlp_ejs' 2>/dev/null || lb_die 'EJS ausente no Python do sistema; APT não atende pré-requisitos atuais. Selecione release oficial explicitamente.'
    [[ "$LB_ACTION" != reinstall ]] || options+=(--reinstall)
    lb_apt_install "${options[@]}" "yt-dlp=$selected"
    lb_check_package yt-dlp || lb_die 'Pacote não instalado.'
    [[ $(dpkg-query -W -f='${Version}' yt-dlp) == "$selected" ]] || lb_die 'Pacote difere da seleção.'
    yt_probe_version /usr/bin/yt-dlp || lb_die 'Versão/executável do pacote falhou.'
    /usr/bin/yt-dlp --ignore-config --no-plugin-dirs --no-update --no-js-runtimes --js-runtimes "$YT_RUNTIME" --version >/dev/null || lb_die 'Pacote não suporta configuração EJS exigida.'
    YT_COMMAND=/usr/bin/yt-dlp
    lb_msg "Uso EJS: yt-dlp --js-runtimes $YT_RUNTIME URL; configuração pessoal preservada."
}
