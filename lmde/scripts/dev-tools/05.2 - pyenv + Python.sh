#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# FERRAMENTAS DE DESENVOLVIMENTO — PYENV E PYTHON
# ══════════════════════════════════════════════════════════════════════
# Sistema-alvo: LMDE 7 Gigi / Debian 13 (Bash).
# Finalidade: Preparar o pyenv pessoal, escolher Python e validar no escopo solicitado.
# Uso: Receita de instalação; executar como usuário normal, sem sudo bash.
# Dependências locais: ../lib/common.sh, ../lib/languages.sh
# Organização: títulos sem número; etapas executadas com numeração sequencial.
# Notas específicas:
# LMDE 7 Gigi / Debian 13. Não altera /usr/bin/python3.
# ══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/languages.sh"
lb_init 'pyenv + Python — LMDE 7 / Debian 13' "$@"
lb_assert_no_extra
LANG_TOOL=python
export PYENV_ROOT=${PYENV_ROOT:-$HOME/.pyenv}
PYENV_BIN="$PYENV_ROOT/bin/pyenv"
# ──────────────────────────────────────────────────────────────────────
# ETAPA 1 — Detectar pyenv e instalações pessoais
# ──────────────────────────────────────────────────────────────────────
lb_step 'Detectar pyenv e instalações pessoais'
if [[ ! -x $PYENV_BIN ]] && command -v pyenv >/dev/null; then
    PYENV_BIN=$(command -v pyenv)
    PYENV_ROOT=$("$PYENV_BIN" root)
fi
if [[ $LB_MODE == check ]]; then
    [[ -x $PYENV_BIN ]] || lb_die 'pyenv não encontrado; nenhuma instalação executada.'
    "$PYENV_BIN" --version
    "$PYENV_BIN" versions --bare
    [[ ! -x /usr/bin/python3 ]] || /usr/bin/python3 --version
    lb_finish 'Diagnóstico local; nenhuma configuração alterada.'
    exit 0
fi
# ──────────────────────────────────────────────────────────────────────
# ETAPA 2 — Escolher versão e seleção persistente
# ──────────────────────────────────────────────────────────────────────
lb_step 'Escolher versão e seleção persistente'
lang_choose stable
lang_conflicts pyenv
lb_confirm 'Preparar pyenv e instalar/validar o Python escolhido?' || { lb_finish 'Operação recusada.'; exit 0; }
# ──────────────────────────────────────────────────────────────────────
# ETAPA 3 — Preparar gerenciador e dependências Debian
# ──────────────────────────────────────────────────────────────────────
lb_step 'Preparar gerenciador e dependências Debian'
lb_apt_update
lb_apt_install python3 build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev curl git libncurses-dev xz-utils tk-dev libffi-dev liblzma-dev libzstd-dev libgdbm-dev libgdbm-compat-dev libexpat1-dev uuid-dev ca-certificates
lb_temp
if [[ ! -x $PYENV_BIN ]]; then
    [[ ! -e $PYENV_ROOT ]] || lb_die "Diretório $PYENV_ROOT existente e incompleto; não sobrescrever."
    lb_download https://api.github.com/repos/pyenv/pyenv/releases/latest "$LB_TMP/pyenv-release.json"
    tag=$(lang_parse release latest "$LB_TMP/pyenv-release.json")
    lb_warn 'Bootstrap pyenv por Git/HTTPS oficial; não há assinatura independente validada nesta receita. python-build verifica checksums das definições.'
    git clone --depth 1 --branch "$tag" https://github.com/pyenv/pyenv.git "$PYENV_ROOT"
fi
"$PYENV_BIN" --version
if [[ $LB_MODE == update && -d $PYENV_ROOT/.git ]]; then
    [[ $(git -C "$PYENV_ROOT" remote get-url origin) == https://github.com/pyenv/pyenv.git ]] || lb_die 'Origem Git pyenv diferente; atualização manual necessária.'
    [[ -z $(git -C "$PYENV_ROOT" status --porcelain) ]] || lb_die 'pyenv possui alterações locais; não trocar código automaticamente.'
    lb_download https://api.github.com/repos/pyenv/pyenv/releases/latest "$LB_TMP/pyenv-release.json"
    tag=$(lang_parse release latest "$LB_TMP/pyenv-release.json")
    lb_backup "$PYENV_ROOT/.git"
    git -C "$PYENV_ROOT" fetch --depth 1 origin "refs/tags/$tag:refs/tags/$tag"
    git -C "$PYENV_ROOT" checkout --detach "$tag"
fi
# ──────────────────────────────────────────────────────────────────────
# ETAPA 4 — Resolver versão final disponível
# ──────────────────────────────────────────────────────────────────────
lb_step 'Resolver versão final disponível'
"$PYENV_BIN" install --list > "$LB_TMP/catalog"
LANG_VERSION=$(lang_parse python "$LB_VERSION" "$LB_TMP/catalog")
LANG_ROOT="$PYENV_ROOT/versions/$LANG_VERSION"
lb_msg "Solicitada: $LB_VERSION; resolvida: $LANG_VERSION; instalação: $LANG_ROOT; escopo: $LB_SCOPE."
installed=0
[[ -x $LANG_ROOT/bin/python3 ]] && installed=1
lb_select_action "$installed"
if [[ $LB_ACTION == reinstall || ( ! -x $LANG_ROOT/bin/python3 && -e $LANG_ROOT ) ]]; then lang_replace_prepare; fi
# ──────────────────────────────────────────────────────────────────────
# ETAPA 5 — Instalar e validar o executável escolhido
# ──────────────────────────────────────────────────────────────────────
lb_step 'Instalar e validar o executável escolhido'
if [[ $LB_ACTION != keep && ! -x $LANG_ROOT/bin/python3 ]]; then
    if ! "$PYENV_BIN" install "$LANG_VERSION"; then lang_replace_failure; fi
fi
if ! (set -e; lang_validate "$LANG_ROOT" "$LANG_VERSION"); then lang_replace_failure; fi
# ──────────────────────────────────────────────────────────────────────
# ETAPA 6 — Configurar somente no escopo escolhido
# ──────────────────────────────────────────────────────────────────────
lb_step 'Configurar somente no escopo escolhido'
if [[ $LB_SCOPE != none ]]; then
    block=$(printf 'export PYENV_ROOT=%q\nexport PATH="$PYENV_ROOT/bin:$PATH"\neval "$(pyenv init - bash)"\n' "$PYENV_ROOT")
    lb_bash_block pyenv "$block"
    if [[ $LB_SCOPE == user ]]; then
        lb_backup "$PYENV_ROOT/version"
        "$PYENV_BIN" global "$LANG_VERSION"
    else
        lb_backup "$LB_PROJECT/.python-version"
        (cd -- "$LB_PROJECT"; "$PYENV_BIN" local "$LANG_VERSION")
    fi
fi
lb_finish "Python $LANG_VERSION validado em $LANG_ROOT. Escopo $LB_SCOPE; pyenv gerencia atualizações. Abra novo Bash para seleção persistente."
