#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# BIBLIOTECAS DE INSTALAÇÃO — APLICATIVOS NATIVOS DO PERFIL
# ══════════════════════════════════════════════════════════════════════
# Sistema-alvo: LMDE 7 Gigi / Debian 13; amd64/arm64 conforme fornecedor.
# Finalidade: Downloads oficiais, extração protegida, menu e retorno.
# Uso: carregar depois de common.sh; não executar diretamente.
# Dependências locais: common.sh e desktop.py.
# Atualização: arquivos pertencem ao usuário; não executar GUI com sudo.
# ══════════════════════════════════════════════════════════════════════

LB_DESKTOP_LIB=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# ──────────────────────────────────────────────────────────────────────
# Opções e propriedade dos destinos
# ──────────────────────────────────────────────────────────────────────
desktop_options() {
    lb_assert_no_extra
    [[ -z $LB_SOURCE || $LB_SOURCE == vendor ]] || lb_die 'Use somente --source vendor: download oficial.'
    [[ $LB_SCOPE == none || $LB_SCOPE == user ]] && [[ -z $LB_PROJECT ]] || lb_die 'Instalação pessoal; escopo project não se aplica.'
    [[ $LB_VENDOR == temurin ]] || lb_die '--vendor não se aplica a estes aplicativos.'
    case ${LB_VERSION:-stable} in
        stable|latest) ;;
        lts) lb_die 'O projeto não oferece canal LTS nesta receita.' ;;
        *) [[ $LB_VERSION =~ ^[0-9]+(\.[0-9]+){1,3}$ ]] || lb_die 'Use stable, latest ou versão numérica exata.' ;;
    esac
    if [[ $LB_APP == discord || $LB_APP == blanc ]]; then
        [[ $LB_ARCH == amd64 ]] || lb_die 'Esta distribuição oficial Linux é somente amd64.'
    fi
    LB_DEST="$HOME/.local/share/$LB_APP"
    [[ $LB_APP != zed ]] || LB_DEST="$HOME/.local/zed.app"
    LB_LAUNCHER="$HOME/.local/bin/$LB_APP"
    LB_DESKTOP="$HOME/.local/share/applications/$LB_APP.desktop"
    [[ $LB_APP != zed ]] || LB_DESKTOP="$HOME/.local/share/applications/dev.zed.Zed.desktop"
    LB_RECORD="$HOME/.local/state/linux-bootstrap/desktop/$LB_APP.json"
    LB_URL_DESKTOP=''
    [[ $LB_APP != antigravity-ide ]] || LB_URL_DESKTOP="$HOME/.local/share/applications/antigravity-ide-url-handler.desktop"
}

desktop_guard_paths() {
    local path parent
    # Checar pais existentes antes de mkdir/cópia; não seguir links para fora do perfil.
    for path in "$LB_DEST" "$LB_LAUNCHER" "$LB_DESKTOP" "$LB_RECORD" "$HOME/.local/state/linux-bootstrap/retorno/.guard"; do
        parent=$(dirname -- "$path")
        while [[ $parent != "$HOME" && $parent != / ]]; do
            [[ ! -L $parent ]] || lb_die "Diretório é link simbólico: $parent; revise manualmente."
            [[ ! -e $parent || ( -d $parent && -O $parent && -w $parent ) ]] || lb_die "Diretório não pertence ao usuário ou não é gravável: $parent."
            parent=$(dirname -- "$parent")
        done
    done
    [[ ! -L $LB_DEST && ! -L $LB_RECORD && ! -L $LB_DESKTOP ]] || lb_die 'Destino/menu/registro é link; revise antes de instalar.'
    [[ ! -e $LB_DEST || ( -d $LB_DEST && -O $LB_DEST && -w $LB_DEST ) ]] || lb_die 'Diretório do aplicativo tem propriedade/tipo inadequado.'
    [[ ! -e $LB_RECORD || ( -f $LB_RECORD && -O $LB_RECORD ) ]] || lb_die 'Registro inválido.'
    [[ ! -e $LB_DESKTOP || ( -f $LB_DESKTOP && -O $LB_DESKTOP ) ]] || lb_die 'Menu inválido.'
    if [[ -n $LB_URL_DESKTOP ]]; then
        [[ ! -L $LB_URL_DESKTOP && ( ! -e $LB_URL_DESKTOP || ( -f $LB_URL_DESKTOP && -O $LB_URL_DESKTOP ) ) ]] || lb_die 'Atalho de protocolo IDE inválido.'
    fi
}

desktop_detect() {
    desktop_guard_paths
    LB_INSTALLED=0
    [[ -z $LB_URL_DESKTOP || ! -e $LB_URL_DESKTOP || -f $LB_RECORD ]] || lb_die 'Atalho de protocolo IDE externo existente; revise antes de substituir.'
    if [[ -e $LB_DEST || -e $LB_RECORD || -e $LB_LAUNCHER || -L $LB_LAUNCHER ]]; then
        [[ -d $LB_DEST && -f $LB_RECORD ]] || lb_die 'Instalação existente não gerenciada ou incompleta; revise antes de substituir.'
        local expected
        expected=$(python3 - "$LB_RECORD" "$LB_APP" "$LB_DEST" <<'PY'
import json,pathlib,sys
r=json.load(open(sys.argv[1]))
root=pathlib.Path(sys.argv[3]).resolve()
p=pathlib.Path(r['executable'])
if r.get('app')!=sys.argv[2] or not p.resolve().is_relative_to(root):
    raise SystemExit('Registro/caminho incompatível')
print(p)
PY
        ) || lb_die 'Registro da instalação inválido.'
        [[ -x $expected ]] || lb_die 'Executável da instalação ausente.'
        if [[ $LB_APP == discord && ! -L $LB_LAUNCHER ]]; then
            [[ -f $LB_LAUNCHER && -O $LB_LAUNCHER && -x $LB_LAUNCHER ]] || lb_die 'Wrapper Discord inválido.'
            python3 - "$LB_LAUNCHER" "$expected" <<'PY'
import pathlib,shlex,sys
expected='#!/usr/bin/env sh\n# Inicializador pessoal linux-bootstrap; preserva o caminho real do fornecedor.\nexec '+shlex.quote(sys.argv[2])+' "$@"\n'
if pathlib.Path(sys.argv[1]).read_text()!=expected: raise SystemExit('Wrapper Discord diverge do registro')
PY
        else
            [[ -L $LB_LAUNCHER && $(readlink -f -- "$LB_LAUNCHER") == "$(readlink -f -- "$expected")" ]] || lb_die 'Inicializador divergente; revise a instalação.'
        fi
        [[ -f $LB_DESKTOP ]] || lb_die 'Menu da instalação ausente.'
        LB_INSTALLED=1
        LB_EXECUTABLE=$expected
    fi
    local found
    found=$(type -P "$LB_APP" || :)
    if [[ -n $found ]]; then
        [[ $LB_INSTALLED == 1 && $(readlink -f -- "$found") == "$(readlink -f -- "$LB_LAUNCHER")" ]] || lb_die "Outra instalação no PATH: $found; nenhuma migração automática."
    fi
    # Não duplicar silenciosamente pacotes de sistema e instalações Flatpak.
    local package
    for package in "$LB_APP"; do
        if lb_check_package "$package"; then lb_die "Pacote APT $package existente; revise o método antes de instalar outra cópia."; fi
    done
    if command -v flatpak >/dev/null; then
        local id=''
        case $LB_APP in discord) id=com.discordapp.Discord;; zed) id=dev.zed.Zed;; esac
        if [[ -n $id ]] && { flatpak info --user "$id" >/dev/null 2>&1 || flatpak info --system "$id" >/dev/null 2>&1; }; then
            lb_die "Flatpak $id existente; escolha conscientemente antes de duplicar a instalação."
        fi
    fi
}

# ──────────────────────────────────────────────────────────────────────
# Downloads HTTPS com destino final limitado aos fornecedores
# ──────────────────────────────────────────────────────────────────────
desktop_download() {
    local url=$1 file=$2 final
    [[ $LB_MODE != check && $url == https://* ]] || lb_die 'Download indisponível no diagnóstico ou URL não HTTPS.'
    final=$(curl --proto '=https' --proto-redir '=https' -fsSL --retry 3 --connect-timeout 20 --max-time 600 -w '%{url_effective}' "$url" -o "$file") || lb_die 'Download falhou; instalação anterior preservada.'
    [[ -s $file ]] || lb_die 'Download vazio.'
    python3 - "$final" <<'PY'
from urllib.parse import urlsplit
import sys
u=urlsplit(sys.argv[1]); hosts={'antigravity.google','storage.googleapis.com','edgedl.me.gvt1.com',
'zed.dev','cloud.zed.dev','github.com','api.github.com','release-assets.githubusercontent.com',
'objects.githubusercontent.com','download.discordapp.net','stable.dl2.discordapp.net','dl.discordapp.net','cdn.discordapp.com','discord.com'}
if u.scheme!='https' or u.hostname not in hosts or u.username or u.password or u.port not in (None,443):
    raise SystemExit('Redirecionamento fora dos hosts oficiais permitidos')
PY
    LB_FINAL_URL=$final
}

desktop_dependencies() {
    local packages=(ca-certificates curl python3 desktop-file-utils)
    case $LB_APP in
        zed) packages+=(libvulkan1 vulkan-tools xdg-desktop-portal xdg-desktop-portal-gtk libsecret-1-0);;
        blanc) packages+=(libfuse2t64 python3-venv);;
        *) packages+=(libnss3 libnspr4 libatk1.0-0t64 libatk-bridge2.0-0t64 libdrm2 libgtk-3-0t64 libgbm1 libasound2t64 libsecret-1-0);;
    esac
    local missing=() package
    for package in "${packages[@]}"; do lb_check_package "$package" || missing+=("$package"); done
    if ((${#missing[@]})); then lb_apt_update; lb_apt_install "${missing[@]}"; fi
    command -v python3 >/dev/null && command -v curl >/dev/null || lb_die 'Python/curl indisponíveis.'
    python3 -c 'import sys,tarfile; assert sys.version_info >= (3,11) and hasattr(tarfile,"data_filter")' || lb_die 'Python com extração protegida indisponível.'
}

# ──────────────────────────────────────────────────────────────────────
# Catálogos oficiais e versões concretas
# ──────────────────────────────────────────────────────────────────────
desktop_google_select() {
    desktop_download 'https://antigravity.google/download?platform=linux' "$LB_TMP/catalog.html"
    python3 - "$LB_TMP/catalog.html" "$LB_APP" "$LB_ARCH" "${LB_VERSION:-stable}" > "$LB_TMP/selection.json" <<'PY'
from html.parser import HTMLParser
from urllib.parse import urlsplit,unquote
import json,re,sys
class Links(HTMLParser):
    def __init__(self): super().__init__(); self.urls=set()
    def handle_starttag(self,tag,attrs):
        if tag=='a':
            for k,v in attrs:
                if k=='href' and v: self.urls.add(v)
p=Links(); p.feed(open(sys.argv[1]).read())
arch='linux-x64' if sys.argv[3]=='amd64' else 'linux-arm'
out=[]
for link in p.urls:
    u=urlsplit(link); path=unquote(u.path)
    if u.scheme!='https' or u.username or u.password or u.port not in (None,443) or u.query or u.fragment: continue
    if sys.argv[2]=='antigravity':
        if u.hostname!='storage.googleapis.com': continue
        match=re.fullmatch(r'/antigravity-public/antigravity-hub/(\d+\.\d+\.\d+)-\d+/'+arch+r'/Antigravity.tar.gz',path)
    else:
        if u.hostname!='edgedl.me.gvt1.com': continue
        match=re.fullmatch(r'/edgedl/release2/[a-zA-Z0-9]+/antigravity/stable/(\d+\.\d+\.\d+)-\d+/'+arch+r'/Antigravity IDE.tar.gz',path)
    if match: out.append(dict(version=match[1],url=link,name=path.rsplit('/',1)[1]))
if len(out)!=1: raise SystemExit('Download oficial ausente/ambíguo; catálogo pode ter mudado')
if sys.argv[4] not in ('stable','latest',out[0]['version']):
    raise SystemExit('Versão exata não está no catálogo atual; nenhuma substituição por latest')
json.dump(out[0],sys.stdout)
PY
}

desktop_resolve() {
    case $LB_APP in
        antigravity|antigravity-ide) desktop_google_select;;
        discord)
            local selector=${LB_VERSION:-stable} url='https://discord.com/api/download?platform=linux&format=tar.gz'
            case $selector in stable|latest) ;; *) url="https://download.discordapp.net/apps/linux/$selector/discord-$selector.tar.gz";; esac
            desktop_download "$url" "$LB_TMP/app.tar.gz"
            python3 "$LB_DESKTOP_LIB/desktop.py" discord-select "$LB_FINAL_URL" "$LB_ARCH" "$selector" > "$LB_TMP/selection.json";;
        blanc)
            local selector=${LB_VERSION:-stable} url='https://api.github.com/repos/bnfy/blanc/releases/latest'
            case $selector in stable|latest) ;; *) url="https://api.github.com/repos/bnfy/blanc/releases/tags/v$selector";; esac
            desktop_download "$url" "$LB_TMP/release.json"
            python3 "$LB_DESKTOP_LIB/desktop.py" blanc-select "$LB_TMP/release.json" "$LB_ARCH" "$selector" > "$LB_TMP/selection.json";;
        zed)
            local selector=${LB_VERSION:-latest}
            case $selector in stable) selector=latest;; esac
            desktop_download 'https://zed.dev/install.sh' "$LB_TMP/zed-install.sh"
            sh -n "$LB_TMP/zed-install.sh" || lb_die 'Instalador oficial com sintaxe inválida.'
            grep -q 'ZED_BUNDLE_PATH' "$LB_TMP/zed-install.sh" || lb_die 'Instalador mudou: suporte ao bundle validado ausente.'
            local url='https://api.github.com/repos/zed-industries/zed/releases/latest'
            [[ $selector == latest ]] || url="https://api.github.com/repos/zed-industries/zed/releases/tags/v$selector"
            desktop_download "$url" "$LB_TMP/zed-release.json"
            python3 - "$LB_TMP/zed-release.json" "$selector" "$LB_ARCH" > "$LB_TMP/selection.json" <<'PY'
import json,re,sys
from urllib.parse import urlsplit
r=json.load(open(sys.argv[1])); tag=r.get('tag_name',''); version=tag.removeprefix('v')
if r.get('draft') is not False or r.get('prerelease') is not False or not re.fullmatch(r'\d+\.\d+\.\d+',version):
    raise SystemExit('Release Zed não é estável')
if sys.argv[2] not in ('latest',version): raise SystemExit('Versão diferente da solicitada')
name='zed-linux-'+('x86_64' if sys.argv[3]=='amd64' else 'aarch64')+'.tar.gz'
assets=[a for a in r['assets'] if a['name']==name]
if len(assets)!=1: raise SystemExit('Asset Zed ausente/ambíguo')
a=assets[0]; u=urlsplit(a['browser_download_url'])
if u.scheme!='https' or u.netloc!='github.com' or u.path!=f'/zed-industries/zed/releases/download/{tag}/{name}' or u.query or u.fragment:
    raise SystemExit('Origem Zed inesperada')
digest=a.get('digest')
if digest is not None and not re.fullmatch(r'sha256:[a-fA-F0-9]{64}',digest): raise SystemExit('Digest inválido')
json.dump(dict(version=version,url=a['browser_download_url'],name=name,sha256=digest[7:] if digest else ''),sys.stdout)
PY
            ;;
    esac
    LB_RELEASE=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$LB_TMP/selection.json")
    LB_URL=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["url"])' "$LB_TMP/selection.json")
    lb_msg "Versão selecionada: $LB_RELEASE; origem: $LB_URL"
}

# ──────────────────────────────────────────────────────────────────────
# Autenticidade disponível e preparação dos arquivos
# ──────────────────────────────────────────────────────────────────────
desktop_prepare() {
    if [[ $LB_APP == blanc ]]; then
        local manifest bundle asset hash
        mapfile -t _blanc < <(python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); print(r["manifest_url"]); print(r["bundle_url"]); print(r["name"])' "$LB_TMP/selection.json")
        [[ ${#_blanc[@]} == 3 ]] || lb_die 'Manifesto/bundle ausentes.'
        manifest=${_blanc[0]}; bundle=${_blanc[1]}; asset=${_blanc[2]}
        desktop_download "$manifest" "$LB_TMP/SHA256SUMS"
        desktop_download "$bundle" "$LB_TMP/SHA256SUMS.sigstore.json"
        # Verificador oficial Sigstore isolado; nunca instalar módulos no Python do sistema.
        if command -v cosign >/dev/null; then
            cosign verify-blob --bundle "$LB_TMP/SHA256SUMS.sigstore.json" --certificate-identity 'anthony@bnfy.me' --certificate-oidc-issuer 'https://github.com/login/oauth' "$LB_TMP/SHA256SUMS" || lb_die 'Assinatura Blanc inválida.'
        else
            python3 -m venv "$LB_TMP/verify-env"
            "$LB_TMP/verify-env/bin/python" -m pip --isolated install --disable-pip-version-check --no-cache-dir --only-binary=:all: --index-url https://pypi.org/simple 'sigstore>=4,<5' || lb_die 'Não foi possível preparar o verificador oficial Sigstore.'
            XDG_CACHE_HOME="$LB_TMP/sigstore-cache" XDG_DATA_HOME="$LB_TMP/sigstore-data" "$LB_TMP/verify-env/bin/python" -m sigstore verify identity --bundle "$LB_TMP/SHA256SUMS.sigstore.json" --cert-identity 'anthony@bnfy.me' --cert-oidc-issuer 'https://github.com/login/oauth' "$LB_TMP/SHA256SUMS" || lb_die 'Assinatura Blanc inválida.'
        fi
        hash=$(python3 "$LB_DESKTOP_LIB/desktop.py" manifest "$LB_TMP/SHA256SUMS" "$asset")
        desktop_download "$LB_URL" "$LB_TMP/Blanc.AppImage"
        printf '%s  %s\n' "$hash" "$LB_TMP/Blanc.AppImage" | sha256sum --check --status || lb_die 'SHA-256 Blanc divergente.'
        mkdir "$LB_TMP/ready"
        install -m 755 "$LB_TMP/Blanc.AppImage" "$LB_TMP/ready/Blanc.AppImage"
        LB_REL_EXEC=Blanc.AppImage
        LB_REL_ICON=''
        lb_msg 'Manifesto autenticado por Sigstore e SHA-256 da AppImage conferido.'
    else
        [[ -s $LB_TMP/app.tar.gz ]] || desktop_download "$LB_URL" "$LB_TMP/app.tar.gz"
        if [[ $LB_APP == zed ]]; then
            local digest
            digest=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("sha256",""))' "$LB_TMP/selection.json")
            if [[ -n $digest ]]; then
                printf '%s  %s\n' "$digest" "$LB_TMP/app.tar.gz" | sha256sum --check --status || lb_die 'Digest Zed publicado no GitHub divergente.'
                lb_msg 'SHA-256 publicado no catálogo oficial GitHub conferido; não é assinatura independente.'
            fi
        fi
        lb_warn 'Não há manifesto assinado conferido nesta fonte. HTTPS, estrutura do arquivo e hash local são verificados; hash local não autentica o fornecedor.'
        mkdir "$LB_TMP/extract"
        if [[ $LB_APP == zed ]]; then
            # O instalador oficial usa tar em ~/.local; limitar toda a árvore
            # impede o bundle de atingir outros aplicativos desse diretório.
            python3 - "$LB_TMP/app.tar.gz" <<'PY'
import pathlib,tarfile,sys
with tarfile.open(sys.argv[1]) as t:
    for m in t.getmembers():
        p=pathlib.PurePosixPath(m.name)
        if not p.parts or p.parts[0]!='zed.app' or (len(p.parts)==1 and not m.isdir()):
            raise SystemExit('Bundle Zed contém membro fora da raiz zed.app')
PY
        fi
        python3 "$LB_DESKTOP_LIB/desktop.py" extract "$LB_TMP/app.tar.gz" "$LB_TMP/extract"
        local bin_name=$LB_APP
        case $LB_APP in discord) bin_name=Discord;; zed) bin_name=zed;; esac
        mapfile -t bins < <(find "$LB_TMP/extract" -type f -name "$bin_name")
        if [[ $LB_APP == discord && ${#bins[@]} == 0 ]]; then
            bin_name=discord
            mapfile -t bins < <(find "$LB_TMP/extract" -type f -name "$bin_name")
        fi
        [[ ${#bins[@]} == 1 && -x ${bins[0]} ]] || lb_die 'Executável esperado ausente ou ambíguo.'
        local root
        root=$(dirname -- "${bins[0]}")
        [[ $LB_APP != zed ]] || root=$(dirname -- "$root")
        mv -- "$root" "$LB_TMP/ready"
        LB_REL_EXEC=$bin_name
        [[ $LB_APP != zed ]] || LB_REL_EXEC=bin/zed
        LB_REL_ICON=''
        case $LB_APP in
            discord) LB_REL_ICON=discord.png;;
            antigravity-ide) LB_REL_ICON=resources/app/resources/linux/code.png;;
            zed) LB_REL_ICON=share/icons/hicolor/512x512/apps/zed.png;;
        esac
        # Não transportar setuid/setgid para uma instalação pessoal.
        find "$LB_TMP/ready" -type f -exec chmod u-s,g-s {} +
    fi
    # Validação de arquitetura sem executar o binário baixado.
    local elf="$LB_TMP/ready/$LB_REL_EXEC"
    [[ $LB_APP != zed ]] || elf="$LB_TMP/ready/libexec/zed-editor"
    if [[ $LB_APP == discord && $LB_REL_EXEC == discord ]]; then
        sh -n "$LB_TMP/ready/discord" || lb_die 'Launcher Discord com sintaxe inválida.'
        [[ -x $LB_TMP/ready/updater_bootstrap ]] || lb_die 'Bootstrap oficial Discord ausente.'
        elf="$LB_TMP/ready/updater_bootstrap"
        lb_msg 'Discord: formato novo com launcher shell e bootstrap oficial; postinst.sh não é executado.'
    fi
    python3 - "$elf" "$LB_ARCH" "$LB_APP" <<'PY'
import pathlib,struct,sys
with open(sys.argv[1],'rb') as stream: b=stream.read(64)
if len(b)<20 or b[:4]!=b'\x7fELF' or b[4]!=2 or b[5] not in (1,2):
    raise SystemExit('Executável principal não é ELF 64-bit válido')
machine=struct.unpack(('<' if b[5]==1 else '>')+'H',b[18:20])[0]
if machine!=({'amd64':62,'arm64':183}[sys.argv[2]]): raise SystemExit('Arquitetura do ELF diverge do sistema')
if sys.argv[3]=='blanc' and b[8:11]!=b'AI\x02': raise SystemExit('AppImage tipo 2 inválida')
PY
    LB_HASH=$(sha256sum "$LB_TMP/"$([[ $LB_APP == blanc ]] && echo Blanc.AppImage || echo app.tar.gz)); LB_HASH=${LB_HASH%% *}
    LB_EXECUTABLE="$LB_DEST/$LB_REL_EXEC"
    local icon=applications-development
    case $LB_APP in blanc) icon=web-browser;; discord) icon=internet-chat;; esac
    [[ -z $LB_REL_ICON || ! -f $LB_TMP/ready/$LB_REL_ICON ]] || icon="$LB_DEST/$LB_REL_ICON"
    local mime=''
    case $LB_APP in
        zed) mime='x-scheme-handler/zed;';;
        discord) mime='x-scheme-handler/discord;';;
        blanc) mime='text/html;x-scheme-handler/http;x-scheme-handler/https;';;
    esac
    python3 "$LB_DESKTOP_LIB/desktop.py" desktop "$LB_NAME" "$LB_EXECUTABLE" "$icon" "$LB_TMP/menu.desktop" "$mime"
    desktop-file-validate "$LB_TMP/menu.desktop" || lb_die 'Atalho desktop inválido.'
    if [[ -n $LB_URL_DESKTOP ]]; then
        python3 "$LB_DESKTOP_LIB/desktop.py" desktop 'Antigravity IDE — URL' "$LB_EXECUTABLE" "$icon" "$LB_TMP/url.desktop" 'x-scheme-handler/antigravity-ide;'
        desktop-file-validate "$LB_TMP/url.desktop" || lb_die 'Atalho de protocolo IDE inválido.'
    fi
}

# ──────────────────────────────────────────────────────────────────────
# Publicação com cópia de retorno e validação sem abrir a interface
# ──────────────────────────────────────────────────────────────────────
desktop_publish() {
    desktop_guard_paths
    # Detectar processos pelo caminho real, sem encerrar nenhum aplicativo.
    python3 - "$LB_DEST" <<'PY'
import pathlib,sys,os
root=pathlib.Path(sys.argv[1]).resolve()
for entry in pathlib.Path('/proc').glob('[0-9]*/exe'):
    try:
        p=entry.resolve(strict=True)
        if p.is_relative_to(root): raise SystemExit('Feche o aplicativo antes de atualizar/reinstalar')
    except (OSError,RuntimeError): pass
PY
    mkdir -p -- "$(dirname -- "$LB_DEST")" "$(dirname -- "$LB_LAUNCHER")"
    lb_backup "$LB_LAUNCHER"; lb_backup "$LB_DESKTOP"; lb_backup "$LB_RECORD"
    [[ -z $LB_URL_DESKTOP ]] || lb_backup "$LB_URL_DESKTOP"
    local stage saved=''
    if [[ $LB_APP != zed ]]; then
        stage=$(mktemp -d "$(dirname -- "$LB_DEST")/.${LB_APP}-stage.XXXXXXXX")
        cp -a -- "$LB_TMP/ready/." "$stage/"
    fi
    if [[ -d $LB_DEST ]]; then
        saved="$LB_BACKUP_DIR/$LB_APP-installation"
        mv -- "$LB_DEST" "$saved"
        lb_msg "Instalação anterior preservada em $saved"
    fi
    if [[ $LB_APP == zed ]]; then
        # O instalador recebe o mesmo bundle que foi previamente validado.
        if ! env -u ZED_CHANNEL -u ZED_VERSION -u ZED_BUNDLE_PATH SHELL="${SHELL:-/bin/bash}" TMPDIR="$LB_TMP" ZED_CHANNEL=stable ZED_VERSION="$LB_RELEASE" ZED_BUNDLE_PATH="$LB_TMP/app.tar.gz" sh "$LB_TMP/zed-install.sh"; then
            # Preserve também o resultado parcial; não apague dados em uma falha.
            [[ ! -e $LB_DEST ]] || mv -- "$LB_DEST" "$LB_BACKUP_DIR/$LB_APP-partial"
            [[ -z $saved ]] || mv -- "$saved" "$LB_DEST"
            lb_die 'Instalador oficial Zed falhou. Pasta anterior restaurada; confira menu/link no índice de retorno.'
        fi
    else
        if ! mv -- "$stage" "$LB_DEST"; then
            [[ -z $saved ]] || mv -- "$saved" "$LB_DEST"
            lb_die 'Falha ao publicar; instalação anterior restaurada.'
        fi
    fi
    find "$LB_DEST" -type f -exec chmod u-s,g-s {} +
    [[ -x $LB_EXECUTABLE && -O $LB_EXECUTABLE && -w $LB_EXECUTABLE ]] || lb_die 'Executável instalado inválido ou não gravável pelo usuário.'
    local link_dir
    link_dir=$(mktemp -d "$(dirname -- "$LB_LAUNCHER")/.${LB_APP}-link.XXXXXXXX")
    if [[ $LB_APP == discord ]]; then
        python3 - "$LB_EXECUTABLE" "$link_dir/$LB_APP" <<'PY'
import pathlib,shlex,sys
pathlib.Path(sys.argv[2]).write_text('#!/usr/bin/env sh\n# Inicializador pessoal linux-bootstrap; preserva o caminho real do fornecedor.\nexec '+shlex.quote(sys.argv[1])+' "$@"\n')
PY
        chmod 755 "$link_dir/$LB_APP"
    else
        ln -s -- "$LB_EXECUTABLE" "$link_dir/$LB_APP"
    fi
    mv -Tf -- "$link_dir/$LB_APP" "$LB_LAUNCHER"; rmdir "$link_dir"
    lb_write_file "$LB_TMP/menu.desktop" "$LB_DESKTOP" 644 user
    [[ -z $LB_URL_DESKTOP ]] || lb_write_file "$LB_TMP/url.desktop" "$LB_URL_DESKTOP" 644 user
    python3 - "$LB_APP" "$LB_RELEASE" "$LB_URL" "$LB_HASH" "$LB_EXECUTABLE" > "$LB_TMP/record.json" <<'PY'
import json,sys,datetime
json.dump(dict(app=sys.argv[1],version_at_install=sys.argv[2],source=sys.argv[3],sha256_at_install=sys.argv[4],
executable=sys.argv[5],date=datetime.datetime.now(datetime.timezone.utc).isoformat()),sys.stdout,indent=2)
PY
    lb_write_file "$LB_TMP/record.json" "$LB_RECORD" 600 user
    desktop-file-validate "$LB_DESKTOP"
    update-desktop-database "$(dirname -- "$LB_DESKTOP")"
    [[ -x $LB_LAUNCHER && -w $LB_DEST ]] || lb_die 'Inicializador/diretório inválido.'
}

# ──────────────────────────────────────────────────────────────────────
# Fluxo compartilhado das cinco receitas
# ──────────────────────────────────────────────────────────────────────
desktop_install() {
    LB_APP=$1; LB_NAME=$2
    desktop_options
    # ETAPA 1 — Diagnosticar perfil, conflitos e instalação.
    lb_step 'Diagnosticar perfil, conflitos e instalação'
    command -v python3 >/dev/null || lb_die 'Python 3 é necessário para o diagnóstico; instale python3 pelo Debian.'
    desktop_detect
    if [[ $LB_MODE == check ]]; then
        [[ $LB_INSTALLED == 1 ]] || lb_die 'Aplicativo ainda não instalado por esta receita.'
        [[ -w $LB_DEST && -w $LB_EXECUTABLE ]] || lb_die 'Arquivos não permitem atualização pelo usuário.'
        command -v desktop-file-validate >/dev/null && desktop-file-validate "$LB_DESKTOP" || lb_die 'Validação do menu indisponível/falhou.'
        if [[ -n $LB_URL_DESKTOP ]]; then
            [[ -f $LB_URL_DESKTOP ]] && desktop-file-validate "$LB_URL_DESKTOP" || lb_die 'Atalho de protocolo IDE ausente/inválido.'
        fi
        lb_msg "Executável: $LB_EXECUTABLE; registro: $LB_RECORD"
        lb_finish 'Diagnóstico local concluído. Versão do registro é histórica; teste GUI e botão de atualização.'
        return
    fi
    lb_select_action "$LB_INSTALLED"
    if [[ $LB_ACTION == keep ]]; then lb_finish 'Instalação mantida; atualize pelo aplicativo quando suportado.'; return; fi
    lb_msg "Destino pessoal: $LB_DEST; menu: $LB_DESKTOP. Dependências Debian podem exigir sudo."
    lb_msg 'Feche o aplicativo antes de continuar, inclusive AppImage aberta por montagem temporária.'
    lb_confirm 'Preparar o download oficial e instalar no perfil, preservando eventual instalação anterior?' || lb_die 'Operação cancelada.'
    # ETAPA 2 — Preparar dependências Debian e área temporária.
    lb_step 'Preparar dependências Debian e área temporária'
    desktop_dependencies; lb_temp
    # ETAPA 3 — Resolver fonte oficial e mostrar versão.
    lb_step 'Resolver fonte oficial e mostrar versão'
    desktop_resolve
    lb_confirm "Instalar $LB_NAME $LB_RELEASE no destino apresentado?" || lb_die 'Operação cancelada.'
    # ETAPA 4 — Verificar assinatura disponível e conteúdo do download.
    lb_step 'Verificar download e preparar conteúdo protegido'
    desktop_prepare
    # ETAPA 5 — Preservar instalação anterior e integrar menu.
    lb_step 'Preservar instalação anterior e integrar menu'
    desktop_publish
    # ETAPA 6 — Apresentar resultado e testes funcionais pendentes.
    lb_step 'Conferir resultado e orientar teste da interface'
    lb_msg 'Não é instalação APT nem Flatpak; atualização pelo app depende do suporte do fornecedor.'
    [[ $LB_APP != discord ]] || lb_warn 'Discord pode pedir outro download em vez de substituir o cliente; --update permite reinstalar o tar.gz oficial.'
    [[ $LB_APP != zed ]] || lb_msg 'Confirme Vulkan com vulkaninfo --summary e depois abra Zed na sessão gráfica.'
    lb_finish "$LB_NAME $LB_RELEASE preparado. Abra pelo menu sem sudo, teste login e atualização. Para conferir: execute esta receita com --check."
}
