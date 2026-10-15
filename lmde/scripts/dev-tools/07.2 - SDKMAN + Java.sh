#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# FERRAMENTAS DE DESENVOLVIMENTO — SDKMAN E JAVA
# ══════════════════════════════════════════════════════════════════════
# Sistema-alvo: LMDE 7 Gigi / Debian 13 (Bash).
# Finalidade: Preparar SDKMAN, selecionar distribuição Java e testar compilação e execução.
# Uso: Receita de instalação; executar como usuário normal, sem sudo bash.
# Dependências locais: ../lib/common.sh, ../lib/languages.sh
# Organização: títulos sem número; etapas executadas com numeração sequencial.
# Notas específicas:
# LMDE 7 Gigi / Debian 13. SDKMAN + JDK. Temurin padrão inicial, não restrição.
# ══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/languages.sh"
lb_init 'SDKMAN + Java — LMDE 7 / Debian 13' "$@"
lb_assert_no_extra
LANG_TOOL=java
export SDKMAN_DIR=${SDKMAN_DIR:-$HOME/.sdkman}
# ──────────────────────────────────────────────────────────────────────
# ETAPA 1 — Detectar SDKMAN sem executar inicialização no diagnóstico
# ──────────────────────────────────────────────────────────────────────
lb_step 'Detectar SDKMAN sem executar inicialização no diagnóstico'
if [[ $LB_MODE == check ]]; then
    [[ -s $SDKMAN_DIR/bin/sdkman-init.sh ]] || lb_die 'SDKMAN não encontrado ou incompleto.'
    lb_msg "SDKMAN: $SDKMAN_DIR (inicialização não executada para preservar diagnóstico somente leitura)."
    if [[ -d $SDKMAN_DIR/candidates/java ]]; then
        find "$SDKMAN_DIR/candidates/java" -mindepth 1 -maxdepth 1 -type d -printf '%f\n'
    else lb_die 'Nenhum JDK instalado pelo SDKMAN.'; fi
    lb_finish 'Diagnóstico local; não atesta a função sdk sem carregá-la.'
    exit 0
fi
# ──────────────────────────────────────────────────────────────────────
# ETAPA 2 — Escolher versão, fornecedor e escopo
# ──────────────────────────────────────────────────────────────────────
lb_step 'Escolher versão, fornecedor e escopo'
lang_choose lts
lang_conflicts sdkman
lb_msg "Fornecedor escolhido: $LB_VENDOR. Use --vendor para alterá-lo."
lb_confirm 'Preparar SDKMAN e instalar/validar o Java escolhido?' || { lb_finish 'Operação recusada.'; exit 0; }
lb_apt_update
lb_apt_install python3 curl zip unzip ca-certificates perl
lb_temp
# ──────────────────────────────────────────────────────────────────────
# ETAPA 3 — Preparar e carregar o gerenciador
# ──────────────────────────────────────────────────────────────────────
lb_step 'Preparar e carregar o gerenciador'
if [[ ! -s $SDKMAN_DIR/bin/sdkman-init.sh ]]; then
    [[ ! -e $SDKMAN_DIR ]] || lb_die 'SDKMAN existente e incompleto; não sobrescrever.'
    lb_download 'https://get.sdkman.io?ci=true&rcupdate=false' "$LB_TMP/sdkman-install.sh"
    bash -n "$LB_TMP/sdkman-install.sh"
    lb_warn 'Bootstrap oficial SDKMAN por HTTPS, sem assinatura independente publicada validada. Não modifica arquivos de inicialização Bash.'
    bash "$LB_TMP/sdkman-install.sh"
fi
# SDKMAN não garante compatibilidade com nounset. Isolar apenas suas chamadas.
sdk_call() { (set +u; sdk "$@"); }
set +u
source "$SDKMAN_DIR/bin/sdkman-init.sh"
set -u
sdkman_auto_answer=true
sdkman_selfupdate_feature=false
sdkman_insecure_ssl=false
sdkman_checksum_enable=true
sdkman_colour_enable=false
sdk_call version
if [[ $LB_MODE == update ]]; then
    lb_backup "$SDKMAN_DIR/bin"
    lb_backup "$SDKMAN_DIR/src"
    sdk_call selfupdate
    set +u
    source "$SDKMAN_DIR/bin/sdkman-init.sh"
    set -u
    sdkman_auto_answer=true
    sdkman_insecure_ssl=false
    sdkman_checksum_enable=true
    sdkman_colour_enable=false
fi
# ──────────────────────────────────────────────────────────────────────
# ETAPA 4 — Consultar catálogo e resolver identificador concreto
# ──────────────────────────────────────────────────────────────────────
lb_step 'Consultar catálogo e resolver identificador concreto'
lang_java_selector
sdk_call list java > "$LB_TMP/catalog"
LANG_VERSION=$(lang_parse sdk "$LANG_SELECTOR" "$LB_TMP/catalog" "$LB_VENDOR")
LANG_ROOT="$SDKMAN_DIR/candidates/java/$LANG_VERSION"
lb_msg "Solicitada: $LB_VERSION; resolvida: $LANG_VERSION; instalação: $LANG_ROOT; escopo: $LB_SCOPE."
installed=0
[[ -x $LANG_ROOT/bin/java && -x $LANG_ROOT/bin/javac ]] && installed=1
lb_select_action "$installed"
old_default=''
[[ ! -L $SDKMAN_DIR/candidates/java/current ]] || old_default=$(readlink "$SDKMAN_DIR/candidates/java/current")
restore_default() {
    if [[ -n $old_default ]]; then ln -sfn -- "$old_default" "$SDKMAN_DIR/candidates/java/current"
    elif [[ -L $SDKMAN_DIR/candidates/java/current ]]; then rm -- "$SDKMAN_DIR/candidates/java/current"; fi
}
if [[ $LB_ACTION == reinstall || ( $installed == 0 && -e $LANG_ROOT ) ]]; then lang_replace_prepare; fi
# ──────────────────────────────────────────────────────────────────────
# ETAPA 5 — Instalar e testar compilador e execução
# ──────────────────────────────────────────────────────────────────────
lb_step 'Instalar e testar compilador e execução'
if [[ $LB_ACTION != keep && ( ! -x $LANG_ROOT/bin/java || ! -x $LANG_ROOT/bin/javac ) ]]; then
    if ! sdk_call install java "$LANG_VERSION"; then restore_default; lang_replace_failure; fi
fi
# SDKMAN pode selecionar automaticamente o primeiro JDK; preservar antes de configurar.
[[ $LB_ACTION == keep ]] || restore_default
lb_warn 'Verificação de checksum SDKMAN habilitada; depende de metadados publicados pelo fornecedor. HTTPS e teste funcional não equivalem a assinatura independente.'
if ! (set -e; lang_validate "$LANG_ROOT" "$LANG_VERSION"); then lang_replace_failure; fi
# ──────────────────────────────────────────────────────────────────────
# ETAPA 6 — Configurar somente no escopo escolhido
# ──────────────────────────────────────────────────────────────────────
lb_step 'Configurar somente no escopo escolhido'
if [[ $LB_SCOPE != none ]]; then
    block=$(printf 'export SDKMAN_DIR=%q\n[[ ! -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] || source "$SDKMAN_DIR/bin/sdkman-init.sh"\n' "$SDKMAN_DIR")
    lb_bash_block sdkman "$block"
    if [[ $LB_SCOPE == user ]]; then
        lb_backup "$SDKMAN_DIR/candidates/java/current"
        sdk_call default java "$LANG_VERSION"
    else
        # Preservar outras ferramentas declaradas na configuração do projeto.
        python3 - "$LB_PROJECT/.sdkmanrc" "$LANG_VERSION" "$LB_TMP/sdkmanrc" <<'PY'
import pathlib, re, sys
source, version, output = sys.argv[1:]
p = pathlib.Path(source)
lines = p.read_text().splitlines() if p.exists() else []
lines = [line for line in lines if not re.match(r'^\s*java\s*=', line)]
pathlib.Path(output).write_text('\n'.join(lines + ['java=' + version]) + '\n')
PY
        lb_write_file "$LB_TMP/sdkmanrc" "$LB_PROJECT/.sdkmanrc" 644 user
        lb_msg 'No projeto, execute sdk env para ativar .sdkmanrc; auto-env não foi habilitado.'
    fi
fi
lb_finish "Java $LANG_VERSION validado; escopo $LB_SCOPE. SDKMAN gerencia atualizações; JAVA_HOME da instalação: $LANG_ROOT."
