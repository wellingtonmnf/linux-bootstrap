#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# FERRAMENTAS DE DESENVOLVIMENTO — FNM E NODE.JS
# ══════════════════════════════════════════════════════════════════════
# Sistema-alvo: LMDE 7 Gigi / Debian 13 (Bash).
# Finalidade: Preparar o fnm pessoal, escolher Node.js e validar Node e npm.
# Uso: Receita de instalação; executar como usuário normal, sem sudo bash.
# Dependências locais: ../lib/common.sh, ../lib/languages.sh
# Organização: títulos sem número; etapas executadas com numeração sequencial.
# Notas específicas:
# LMDE 7 Gigi / Debian 13. fnm pessoal, sem alterações implícitas no Bash.
# ══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/languages.sh"
lb_init 'fnm + Node.js — LMDE 7 / Debian 13' "$@"
lb_assert_no_extra
[[ $LB_ARCH == amd64 ]] || lb_die 'Bootstrap fnm validado nesta receita apenas para x86_64.'
LANG_TOOL=node
export FNM_DIR=${FNM_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/fnm}
FNM_BIN="$FNM_DIR/fnm"
if [[ ! -x $FNM_BIN ]] && command -v fnm >/dev/null; then FNM_BIN=$(command -v fnm); fi
# ──────────────────────────────────────────────────────────────────────
# ETAPA 1 — Detectar fnm e instalações pessoais
# ──────────────────────────────────────────────────────────────────────
lb_step 'Detectar fnm e instalações pessoais'
if [[ $LB_MODE == check ]]; then
    [[ -x $FNM_BIN ]] || lb_die 'fnm não encontrado; nenhuma instalação executada.'
    "$FNM_BIN" --version
    "$FNM_BIN" list
    lb_finish 'Diagnóstico local sem instalação, ativação ou consulta remota.'
    exit 0
fi
# ──────────────────────────────────────────────────────────────────────
# ETAPA 2 — Escolher versão e seleção persistente
# ──────────────────────────────────────────────────────────────────────
lb_step 'Escolher versão e seleção persistente'
lang_choose lts
lang_conflicts fnm
lb_confirm 'Preparar fnm e instalar/validar o Node.js escolhido?' || { lb_finish 'Operação recusada.'; exit 0; }
lb_apt_update
lb_apt_install python3 curl unzip ca-certificates gnupg xz-utils
lb_temp
# ──────────────────────────────────────────────────────────────────────
# ETAPA 3 — Preparar gerenciador sem modificar arquivos Bash
# ──────────────────────────────────────────────────────────────────────
lb_step 'Preparar gerenciador sem modificar arquivos Bash'
if [[ ! -x $FNM_BIN || $LB_MODE == update ]]; then
    [[ $FNM_BIN == "$FNM_DIR/fnm" ]] || lb_die 'fnm externo: atualize pelo método que o instalou; não sobrescrever.'
    lb_download https://api.github.com/repos/Schniz/fnm/releases/latest "$LB_TMP/fnm-release.json"
    tag=$(lang_parse release latest "$LB_TMP/fnm-release.json")
    lang_parse fnm-asset latest "$LB_TMP/fnm-release.json" > "$LB_TMP/fnm-asset"
    mapfile -t asset < "$LB_TMP/fnm-asset"
    lb_download "${asset[0]}" "$LB_TMP/fnm.zip"
    printf '%s  %s\n' "${asset[1]}" "$LB_TMP/fnm.zip" | sha256sum --check --status
    unzip -q "$LB_TMP/fnm.zip" fnm -d "$LB_TMP/fnm-bin"
    chmod 755 "$LB_TMP/fnm-bin/fnm"
    "$LB_TMP/fnm-bin/fnm" --version
    lb_write_file "$LB_TMP/fnm-bin/fnm" "$FNM_DIR/fnm" 755 user
    lb_msg "fnm $tag: SHA-256 da API oficial conferido; hash não é assinatura independente."
fi
"$FNM_BIN" --version
# ──────────────────────────────────────────────────────────────────────
# ETAPA 4 — Resolver versão e suporte pelo catálogo oficial Node.js
# ──────────────────────────────────────────────────────────────────────
lb_step 'Resolver versão e suporte pelo catálogo oficial Node.js'
lang_node_version
LANG_ROOT="$FNM_DIR/node-versions/v$LANG_VERSION/installation"
LANG_REPLACE_ROOT="$FNM_DIR/node-versions/v$LANG_VERSION"
lb_msg "Solicitada: $LB_VERSION; resolvida: $LANG_VERSION; instalação: $LANG_ROOT; escopo: $LB_SCOPE."
installed=0
[[ -x $LANG_ROOT/bin/node ]] && installed=1
lb_select_action "$installed"
# fnm cria default na primeira instalação; restaurar no escopo none/project.
old_default=''
[[ ! -L $FNM_DIR/aliases/default ]] || old_default=$(readlink "$FNM_DIR/aliases/default")
restore_default() {
    if [[ $LB_SCOPE != user ]]; then
        if [[ -n $old_default ]]; then ln -sfn -- "$old_default" "$FNM_DIR/aliases/default"
        elif [[ -L $FNM_DIR/aliases/default ]]; then rm -- "$FNM_DIR/aliases/default"; fi
    fi
}
if [[ $LB_ACTION == reinstall || ( ! -x $LANG_ROOT/bin/node && -e $LANG_REPLACE_ROOT ) ]]; then lang_replace_prepare; fi
# ──────────────────────────────────────────────────────────────────────
# ETAPA 5 — Instalar e validar Node e npm
# ──────────────────────────────────────────────────────────────────────
lb_step 'Instalar e validar Node e npm'
if [[ $LB_ACTION != keep && ! -x $LANG_ROOT/bin/node ]]; then
    if ! "$FNM_BIN" install "$LANG_VERSION"; then restore_default; lang_replace_failure; fi
fi
if [[ $LB_ACTION != keep ]]; then
    restore_default
    if ! lang_node_integrity "$LANG_ROOT" "$LANG_VERSION"; then lang_replace_failure; fi
fi
if ! (set -e; lang_validate "$LANG_ROOT" "$LANG_VERSION"); then lang_replace_failure; fi
# ──────────────────────────────────────────────────────────────────────
# ETAPA 6 — Configurar somente no escopo escolhido
# ──────────────────────────────────────────────────────────────────────
lb_step 'Configurar somente no escopo escolhido'
if [[ $LB_SCOPE != none ]]; then
    block=$(printf 'export FNM_DIR=%q\nexport PATH=%q:"$PATH"\neval "$(fnm env --use-on-cd --shell bash)"\n' "$FNM_DIR" "$(dirname -- "$FNM_BIN")")
    lb_bash_block fnm "$block"
    if [[ $LB_SCOPE == user ]]; then
        lb_backup "$FNM_DIR/aliases/default"
        "$FNM_BIN" default "$LANG_VERSION"
    else
        printf '%s\n' "$LANG_VERSION" > "$LB_TMP/node-version"
        lb_write_file "$LB_TMP/node-version" "$LB_PROJECT/.node-version" 644 user
    fi
fi
lb_finish "Node $LANG_VERSION e npm validados. Escopo $LB_SCOPE; fnm gerencia atualizações. Abra novo Bash para seleção persistente."
