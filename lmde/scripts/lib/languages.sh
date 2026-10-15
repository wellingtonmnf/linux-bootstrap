#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# BIBLIOTECAS DE INSTALAÇÃO — BIBLIOTECA DE LINGUAGENS
# ══════════════════════════════════════════════════════════════════════
# Sistema-alvo: LMDE 7 Gigi / Debian 13 (Bash).
# Finalidade: Compartilhar catálogos, validação, configuração e fluxo das receitas Mise.
# Uso: Biblioteca de funções; carregar com source, não executar diretamente.
# Dependências locais: lib/common.sh (carregar antes desta biblioteca).
# Organização: títulos sem número; etapas executadas com numeração sequencial.
# Notas específicas:
# Auxiliares das seis receitas de linguagens. Requer common.sh e Python 3 do Debian.
# ══════════════════════════════════════════════════════════════════════


# ──────────────────────────────────────────────────────────────────────
# Escolha de versão e escopo (lang_choose)
# ──────────────────────────────────────────────────────────────────────
lang_choose() {
    local default=$1 answer
    if [[ -z $LB_VERSION ]]; then
        lb_msg "Seletores: latest, stable, versão/série explícita; LTS apenas Node.js/Java."
        if [[ $LB_YES == 1 ]]; then LB_VERSION=$default
        else
            read -r -p "Versão [$default]: " answer || lb_die 'Entrada encerrada; nada selecionado.'
            LB_VERSION=${answer:-$default}
        fi
    fi
    [[ $LB_VERSION =~ ^[a-zA-Z0-9.+_-]+$ ]] || lb_die 'Seletor de versão inválido.'
    [[ ${LANG_TOOL:-} != python || $LB_VERSION != lts ]] || lb_die 'Python não possui canal LTS oficial; escolha stable ou versão explícita.'
    if [[ ${LANG_TOOL:-} == java && $LB_VERSION == lts && $LB_VENDOR != temurin ]]; then
        lb_die 'LTS automática validada apenas para Temurin; para outro fornecedor escolha versão explícita e confira sua política de suporte.'
    fi
    if [[ ${LB_SCOPE_EXPLICIT:-0} == 0 && $LB_YES == 0 ]]; then
        read -r -p 'Seleção persistente: none, user ou project [none]: ' answer || lb_die 'Entrada encerrada.'
        LB_SCOPE=${answer:-none}
    fi
    case $LB_SCOPE in none|user) ;; project) [[ -n $LB_PROJECT && -d $LB_PROJECT ]] || lb_die 'Informe --project com um diretório existente.' ;; *) lb_die 'Escopo inválido.' ;; esac
}


# ──────────────────────────────────────────────────────────────────────
# Leitura segura dos catálogos (lang_parse)
# ──────────────────────────────────────────────────────────────────────
lang_parse() {
    # Argumentos: modo seletor arquivo [calendário/vendor]. Catálogo nunca é código.
    python3 - "$@" <<'PY'
import datetime, json, re, sys
mode, selector, path, *extra = sys.argv[1:]
def fail(message): raise SystemExit(message)
def key(v): return tuple(int(n) for n in re.findall(r'\d+', v))
def pick(items, requested):
    if requested in ('latest', 'stable'): candidates = items
    else:
        candidates = [v for v in items if v == requested or v.startswith(requested + '.') or v.startswith(requested + '+')]
    if not candidates: fail('Nenhuma versão final corresponde ao seletor: ' + requested)
    return max(candidates, key=key)
text = open(path, encoding='utf-8').read()
if mode == 'node':
    data = json.loads(text)
    schedule = json.load(open(extra[0], encoding='utf-8'))
    today = datetime.date.today().isoformat()
    versions = []
    for row in data:
        v = row['version'].removeprefix('v')
        if not re.fullmatch(r'\d+\.\d+\.\d+', v): continue
        if selector == 'lts':
            s = schedule.get('v' + v.split('.')[0])
            if not s or not row.get('lts') or not s.get('lts') or not s.get('end'): continue
            if not (s['lts'] <= today < s['end']): continue
        versions.append(v)
    print(pick(versions, 'latest' if selector == 'lts' else selector.removeprefix('v')))
elif mode == 'python':
    if selector == 'lts': fail('Python não possui um canal LTS oficial. Use stable ou uma versão explícita.')
    versions = [v.strip() for v in text.splitlines() if re.fullmatch(r'\d+\.\d+\.\d+', v.strip())]
    print(pick(versions, selector))
elif mode in ('sdk', 'mise-java'):
    vendor = extra[0]
    if mode == 'sdk':
        suffix = {'temurin': 'tem', 'corretto': 'amzn', 'liberica': 'librca'}.get(vendor, vendor)
        identifiers = re.findall(r'\b(\d+(?:\.\d+)*(?:\.\d+|\+\d+)?-' + re.escape(suffix) + r')\b', text)
        values = {v.rsplit('-', 1)[0]: v for v in identifiers}
        requested = selector.rsplit('-', 1)[0] if selector.endswith('-' + suffix) else selector
    else:
        prefix = vendor + '-'
        values = {v[len(prefix):]: v for v in text.splitlines() if v.startswith(prefix) and re.fullmatch(r'\d+(?:\.\d+)*(?:\+\d+)?', v[len(prefix):])}
        requested = selector[len(prefix):] if selector.startswith(prefix) else selector
    if requested == 'lts': fail('LTS deve ser resolvida pelos metadados Adoptium antes do catálogo.')
    print(values[pick(list(values), requested)])
elif mode == 'adoptium':
    data = json.loads(text)
    field = 'most_recent_lts' if selector == 'lts' else 'most_recent_feature_release'
    major = data.get(field)
    if not isinstance(major, int) or major not in data.get('available_releases', []): fail('Metadados Adoptium incompletos.')
    print(major)
elif mode == 'release':
    data = json.loads(text)
    tag = data.get('tag_name', '')
    if data.get('prerelease') or data.get('draft') or not re.fullmatch(r'v?\d+(?:\.\d+)+', tag): fail('Release inválida ou não final.')
    print(tag)
elif mode == 'fnm-asset':
    data = json.loads(text)
    matches = [a for a in data.get('assets', []) if a.get('name') == 'fnm-linux.zip']
    if len(matches) != 1: fail('Asset fnm x86_64 ausente/ambíguo.')
    a = matches[0]
    digest = a.get('digest', '')
    if not re.fullmatch(r'sha256:[0-9a-f]{64}', digest): fail('Release fnm sem SHA-256 publicado pela API; não instalar sem validação.')
    url = a['browser_download_url']
    if not url.startswith('https://github.com/Schniz/fnm/releases/download/'): fail('Origem fnm inesperada.')
    print(url); print(digest.split(':')[1])
else: fail('Modo de catálogo desconhecido.')
PY
}


# ──────────────────────────────────────────────────────────────────────
# lang node version (lang_node_version)
# ──────────────────────────────────────────────────────────────────────
lang_node_version() {
    lb_download https://nodejs.org/dist/index.json "$LB_TMP/node-index.json"
    lb_download https://raw.githubusercontent.com/nodejs/Release/main/schedule.json "$LB_TMP/node-schedule.json"
    LANG_VERSION=$(lang_parse node "$LB_VERSION" "$LB_TMP/node-index.json" "$LB_TMP/node-schedule.json")
}


# ──────────────────────────────────────────────────────────────────────
# lang node integrity (lang_node_integrity)
# ──────────────────────────────────────────────────────────────────────
lang_node_integrity() {
    # fnm não verifica o archive Node. Conferir também os arquivos efetivamente instalados.
    local root=$1 version=$2 arch=x64 filename base fingerprints fingerprint
    [[ ${LB_ARCH:-amd64} != arm64 ]] || arch=arm64
    filename="node-v$version-linux-$arch.tar.xz"
    base="https://nodejs.org/dist/v$version"
    lb_download "$base/SHASUMS256.txt" "$LB_TMP/node-SHASUMS256.txt" || return 1
    lb_download "$base/SHASUMS256.txt.sig" "$LB_TMP/node-SHASUMS256.txt.sig" || return 1
    lb_download https://raw.githubusercontent.com/nodejs/release-keys/main/gpg-only-active-keys/pubring.kbx "$LB_TMP/node-keys.kbx" || return 1
    mkdir -p "$LB_TMP/node-gpg" || return 1
    chmod 700 "$LB_TMP/node-gpg" || return 1
    gpg --batch --homedir "$LB_TMP/node-gpg" --no-default-keyring --keyring "$LB_TMP/node-keys.kbx" --with-colons --fingerprint --list-keys > "$LB_TMP/node-key-list" || return 1
    fingerprints=$(awk -F: '$1=="pub" {primary=1; next} $1=="fpr" && primary {print $10; primary=0}' "$LB_TMP/node-key-list")
    [[ -n $fingerprints ]] || return 1
    while IFS= read -r fingerprint; do
        case $fingerprint in
            5BE8A3F6C8A5C01D106C0AD820B1A390B168D356|DD792F5973C6DE52C432CBDAC77ABFA00DDBF2B7|CC68F5A3106FF448322E48ED27F5E38D5B0A215F|890C08DB8579162FEE0DF9DB8BEAB4DFCF555EF4|C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C|108F52B48DB57BB0CC439B2997B01419BD92F80A|655F3B5C1FB3FA8D1A0CA6BDE4A7D232B936D2FD|A363A499291CBBC940DD62E41F10027AF002F8B0) ;;
            *) lb_warn "Chave Node não reconhecida: $fingerprint; revisar rotação na fonte oficial."; return 1 ;;
        esac
    done <<< "$fingerprints"
    gpg --batch --homedir "$LB_TMP/node-gpg" --no-auto-key-retrieve --no-default-keyring --keyring "$LB_TMP/node-keys.kbx" --status-fd 1 --verify "$LB_TMP/node-SHASUMS256.txt.sig" "$LB_TMP/node-SHASUMS256.txt" > "$LB_TMP/node-gpg-status" || return 1
    grep -q '\[GNUPG:\] VALIDSIG ' "$LB_TMP/node-gpg-status" || return 1
    if grep -Eq '\[GNUPG:\] (EXPKEYSIG|EXPSIG|REVKEYSIG|BADSIG|ERRSIG)' "$LB_TMP/node-gpg-status"; then return 1; fi
    python3 - "$LB_TMP/node-SHASUMS256.txt" "$filename" "$LB_TMP/node-hash" <<'PY' || return 1
import pathlib, re, sys
manifest, name, output = sys.argv[1:]
matches = [m.group(1) for line in pathlib.Path(manifest).read_text().splitlines()
           if (m := re.fullmatch(r'([0-9a-f]{64})\s+\*?' + re.escape(name), line))]
if len(matches) != 1: raise SystemExit('Checksum Node ausente/ambíguo.')
pathlib.Path(output).write_text(matches[0])
PY
    lb_download "$base/$filename" "$LB_TMP/$filename" || return 1
    printf '%s  %s\n' "$(cat "$LB_TMP/node-hash")" "$LB_TMP/$filename" | sha256sum --check --status || return 1
    mkdir -p "$LB_TMP/node-official" || return 1
    tar -xJf "$LB_TMP/$filename" -C "$LB_TMP/node-official" || return 1
    cmp -- "$LB_TMP/node-official/node-v$version-linux-$arch/bin/node" "$root/bin/node" || return 1
    diff -qr -- "$LB_TMP/node-official/node-v$version-linux-$arch/lib/node_modules/npm" "$root/lib/node_modules/npm" || return 1
    lb_msg 'Node e árvore npm correspondem ao archive oficial com SHA-256 e assinatura GPG verificados.'
}


# ──────────────────────────────────────────────────────────────────────
# lang java selector (lang_java_selector)
# ──────────────────────────────────────────────────────────────────────
lang_java_selector() {
    LANG_SELECTOR=$LB_VERSION
    if [[ $LB_VERSION == lts ]]; then
        [[ $LB_VENDOR == temurin ]] || lb_die 'LTS automática validada apenas para Temurin; para outro fornecedor escolha versão explícita e confira sua política de suporte.'
    fi
    if [[ $LB_VENDOR == temurin && $LB_VERSION =~ ^(lts|latest|stable)$ ]]; then
        lb_download https://api.adoptium.net/v3/info/available_releases "$LB_TMP/adoptium.json"
        LANG_SELECTOR=$(lang_parse adoptium "$LB_VERSION" "$LB_TMP/adoptium.json")
    fi
}


# ──────────────────────────────────────────────────────────────────────
# lang conflicts (lang_conflicts)
# ──────────────────────────────────────────────────────────────────────
lang_conflicts() {
    [[ $LB_SCOPE == none ]] && return 0
    local manager=$1 file patterns
    case $manager in mise) patterns='pyenv init|fnm env|sdkman-init' ;; pyenv) patterns='mise activate.*bash|mise.*shims' ;; fnm) patterns='mise activate.*bash|mise.*shims' ;; sdkman) patterns='mise activate.*bash|mise.*shims' ;; esac
    for file in "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile"; do
        if [[ -f $file ]] && grep -Eq "$patterns" "$file"; then
            lb_die "Outra alternativa está ativada em $file. Escolha --scope none ou ajuste a precedência conscientemente antes de configurar."
        fi
    done
    if [[ $LB_SCOPE == project ]]; then
        for file in mise.toml .mise.toml .tool-versions; do
            if [[ $manager != mise && -e $LB_PROJECT/$file ]]; then lb_die "Projeto já contém $file; não alternar gerenciadores automaticamente."; fi
        done
        if [[ $manager == mise ]]; then
            case $LANG_TOOL in python) file=.python-version ;; node) file=.node-version ;; java) file=.sdkmanrc ;; esac
            [[ ! -e $LB_PROJECT/$file ]] || lb_die "Projeto possui $file; reveja a configuração existente antes de selecionar mise."
        fi
    fi
}


# ──────────────────────────────────────────────────────────────────────
# lang validate (lang_validate)
# ──────────────────────────────────────────────────────────────────────
lang_validate() {
    local root=$1 expected=$2 actual
    case $LANG_TOOL in
        python)
            actual=$("$root/bin/python3" -c 'import sys; print(".".join(map(str,sys.version_info[:3])))') || return 1
            [[ $actual == "$expected" ]] || lb_die "Python retornou $actual; esperado $expected."
            "$root/bin/python3" -c 'import ssl, sqlite3, bz2, lzma, ctypes, venv, readline, tkinter; print("Python: módulos básicos disponíveis")' || return 1
            "$root/bin/python3" -c 'import sys; exec("import compression.zstd" if sys.version_info >= (3, 14) else "pass")' || return 1
            "$root/bin/python3" -m pip --version || return 1
            ;;
        node)
            actual=$("$root/bin/node" --version) || return 1
            [[ $actual == "v$expected" ]] || lb_die "Node retornou $actual; esperado v$expected."
            PATH="$root/bin:$PATH" "$root/bin/npm" --version || return 1
            "$root/bin/node" -e 'if (1+1 !== 2) process.exit(1); console.log("Node: execução confirmada")' || return 1
            ;;
        java)
            # Ler release como dados, sem source de arquivo de fornecedor.
            python3 - "$root/release" "$expected" "${LB_VENDOR:-temurin}" <<'PY' || return 1
import re, sys
path, requested, vendor = sys.argv[1:]
original_request = requested
text = open(path, encoding='utf-8').read()
match = re.search(r'^JAVA_VERSION="([^"]+)"', text, re.M)
if not match: raise SystemExit('JDK sem JAVA_VERSION no arquivo release.')
actual = tuple(map(int, re.findall(r'\d+', match[1].split('+')[0])))
if actual[:2] == (1, 8): actual = actual[1:]
requested = requested.removeprefix(vendor + '-').rsplit('-', 1)[0].split('+')[0]
wanted = tuple(map(int, re.findall(r'\d+', requested)))
if vendor not in ('temurin', 'corretto', 'amzn'): wanted = wanted[:1]
if actual[:len(wanted)] != wanted: raise SystemExit('JAVA_VERSION não corresponde ao identificador selecionado.')
build = re.search(r'\+(\d+)', original_request)
if build and vendor in ('temurin', 'corretto', 'amzn'):
    runtime = re.search(r'^JAVA_RUNTIME_VERSION="([^"]+)"', text, re.M)
    actual_build = re.search(r'(?:\+|-b)(\d+)', runtime[1]) if runtime else None
    if not actual_build or int(actual_build[1]) != int(build[1]):
        raise SystemExit('Build do JDK não corresponde ao identificador selecionado.')
if vendor == 'temurin' and not re.search(r'^IMPLEMENTOR="Eclipse Adoptium"', text, re.M):
    raise SystemExit('Fornecedor do JDK não corresponde ao Temurin escolhido.')
PY
            JAVA_HOME="$root" "$root/bin/java" -version || return 1
            JAVA_HOME="$root" "$root/bin/javac" -version || return 1
            printf 'class BootstrapCheck { public static void main(String[] a) { System.out.println("Java: execução confirmada"); } }\n' > "$LB_TMP/BootstrapCheck.java"
            "$root/bin/javac" -d "$LB_TMP" "$LB_TMP/BootstrapCheck.java" || return 1
            "$root/bin/java" -cp "$LB_TMP" BootstrapCheck || return 1
            ;;
    esac
    lb_msg "Executável validado em $root/bin; atualização sob responsabilidade do gerenciador escolhido."
}


# ──────────────────────────────────────────────────────────────────────
# lang replace prepare (lang_replace_prepare)
# ──────────────────────────────────────────────────────────────────────
lang_replace_prepare() {
    LANG_PREVIOUS=''
    LANG_REPLACE_TARGET=${LANG_REPLACE_ROOT:-$LANG_ROOT}
    if [[ -e $LANG_REPLACE_TARGET || -L $LANG_REPLACE_TARGET ]]; then
        [[ ! -L $LANG_REPLACE_TARGET ]] || lb_die 'Instalação é um link; não reinstalar automaticamente.'
        local previous_base="$HOME/.local/state/linux-bootstrap/retorno-instalacoes/$LANG_TOOL"
        mkdir -p -- "$previous_base"
        chmod 700 -- "$previous_base"
        LANG_PREVIOUS="$previous_base/$(basename -- "$LANG_REPLACE_TARGET").$(date +%Y%m%d%H%M%S).$$"
        mv -- "$LANG_REPLACE_TARGET" "$LANG_PREVIOUS"
        lb_msg "Retorno preservado: $LANG_PREVIOUS"
    fi
}


# ──────────────────────────────────────────────────────────────────────
# lang replace failure (lang_replace_failure)
# ──────────────────────────────────────────────────────────────────────
lang_replace_failure() {
    if [[ -n ${LANG_PREVIOUS:-} ]]; then
        if [[ -e $LANG_REPLACE_TARGET ]]; then mv -- "$LANG_REPLACE_TARGET" "$LANG_PREVIOUS.failed"; fi
        mv -- "$LANG_PREVIOUS" "$LANG_REPLACE_TARGET"
    fi
    lb_die 'Instalação/validação falhou; versão anterior restaurada quando existente.'
}


# ──────────────────────────────────────────────────────────────────────
# Fluxo de instalação de linguagem via Mise (lang_mise)
# ──────────────────────────────────────────────────────────────────────
lang_mise() {
    LANG_TOOL=$1
    lb_init "$2 via mise — LMDE 7 / Debian 13" "${@:3}"
    lb_assert_no_extra
    # ──────────────────────────────────────────────────────────────────────
    # ETAPA 1 — Detectar o gerenciador previamente instalado
    # ──────────────────────────────────────────────────────────────────────
    lb_step 'Detectar o gerenciador previamente instalado'
    lb_require_mise
    "$LB_MISE" --version
    if [[ $LB_MODE == check ]]; then
        local data=${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}
        lb_msg "Instalações locais: $data/installs/$LANG_TOOL"
        [[ -d $data/installs/$LANG_TOOL ]] || lb_die 'Linguagem não encontrada nesse diretório; diagnóstico não instala nem consulta a rede.'
        find "$data/installs/$LANG_TOOL" -mindepth 1 -maxdepth 1 -type d -printf '%f\n'
        lb_finish 'Diagnóstico local concluído; seleção ativa não modificada.'
        return
    fi
    command -v python3 >/dev/null || lb_die 'Python 3 do Debian é necessário para interpretar os catálogos.'
    lb_temp
    local default=stable
    [[ $LANG_TOOL == python ]] || default=lts
    # ──────────────────────────────────────────────────────────────────────
    # ETAPA 2 — Escolher versão e escopo
    # ──────────────────────────────────────────────────────────────────────
    lb_step 'Escolher versão e escopo'
    lang_choose "$default"
    lang_conflicts mise
    # ──────────────────────────────────────────────────────────────────────
    # ETAPA 3 — Resolver catálogo oficial e mostrar a versão concreta
    # ──────────────────────────────────────────────────────────────────────
    lb_step 'Resolver catálogo oficial e mostrar a versão concreta'
    case $LANG_TOOL in
        node) lang_node_version ;;
        python)
            "$LB_MISE" ls-remote python > "$LB_TMP/catalog"
            LANG_VERSION=$(lang_parse python "$LB_VERSION" "$LB_TMP/catalog") ;;
        java)
            lang_java_selector
            "$LB_MISE" ls-remote java "$LB_VENDOR-" > "$LB_TMP/catalog"
            LANG_VERSION=$(lang_parse mise-java "$LANG_SELECTOR" "$LB_TMP/catalog" "$LB_VENDOR") ;;
    esac
    LANG_ROOT=$("$LB_MISE" where "$LANG_TOOL@$LANG_VERSION" 2>/dev/null) || LANG_ROOT=''
    local installed=0
    [[ -n $LANG_ROOT && -d $LANG_ROOT ]] && installed=1
    lb_msg "Solicitada: $LB_VERSION; resolvida: $LANG_TOOL@$LANG_VERSION; escopo: $LB_SCOPE."
    lb_select_action "$installed"
    if [[ $LB_ACTION != keep || $LB_SCOPE != none ]]; then
        lb_confirm "Aplicar $LB_ACTION de $LANG_TOOL@$LANG_VERSION pelo mise?" || { lb_finish 'Operação recusada.'; return; }
    fi
    # ──────────────────────────────────────────────────────────────────────
    # ETAPA 4 — Instalar e validar sem ativar outros gerenciadores
    # ──────────────────────────────────────────────────────────────────────
    lb_step 'Instalar e validar sem ativar outros gerenciadores'
    local flags=()
    if [[ $LB_ACTION == reinstall && -n $LANG_ROOT ]]; then
        lang_replace_prepare
        flags=(--force)
    fi
    if [[ $LB_ACTION != keep ]]; then
        if [[ $LANG_TOOL == node ]]; then
            lb_apt_update
            lb_apt_install gnupg xz-utils
        fi
        if ! "$LB_MISE" install "${flags[@]}" "$LANG_TOOL@$LANG_VERSION"; then lang_replace_failure; fi
        LANG_ROOT=$("$LB_MISE" where "$LANG_TOOL@$LANG_VERSION")
        if [[ $LANG_TOOL == node ]] && ! lang_node_integrity "$LANG_ROOT" "$LANG_VERSION"; then lang_replace_failure; fi
    fi
    if ! (set -e; lang_validate "$LANG_ROOT" "$LANG_VERSION"); then lang_replace_failure; fi
    # ──────────────────────────────────────────────────────────────────────
    # ETAPA 5 — Registrar seleção somente no escopo escolhido
    # ──────────────────────────────────────────────────────────────────────
    lb_step 'Registrar seleção somente no escopo escolhido'
    if [[ $LB_SCOPE == user ]]; then
        lb_backup "${MISE_GLOBAL_CONFIG_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/mise/config.toml}"
        "$LB_MISE" use --global "$LANG_TOOL@$LANG_VERSION"
    elif [[ $LB_SCOPE == project ]]; then
        lb_backup "$LB_PROJECT/mise.toml"
        lb_backup "$LB_PROJECT/.mise.toml"
        (cd -- "$LB_PROJECT"; "$LB_MISE" use "$LANG_TOOL@$LANG_VERSION")
    fi
    lb_finish "$LANG_TOOL@$LANG_VERSION validado. Escopo $LB_SCOPE. A ativação Bash pertence ao script do mise; nenhuma foi adicionada aqui."
}
