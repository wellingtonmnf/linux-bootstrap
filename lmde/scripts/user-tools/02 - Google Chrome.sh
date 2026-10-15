#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# FERRAMENTAS DE USO GERAL — GOOGLE CHROME
# ══════════════════════════════════════════════════════════════════════
# Sistema-alvo: LMDE 7 Gigi / Debian 13 (Bash).
# Finalidade: Instalar, atualizar ou diagnosticar GOOGLE CHROME.
# Uso: Executar como usuário normal, sem sudo bash.
# Dependências locais: ../lib/common.sh, ../lib/apps.sh.
# Origem e atualização: APT; repositório oficial Google por HTTPS, chave primária ativa e Release.gpg verificado.
# Fluxo compartilhado em apps.sh:
#   1. Detectar instalação e escolher ação.
#   2. Resolver origem e versão; conferir assinaturas quando houver fornecedor.
#   3. Instalar e validar pacote; testar interface manualmente.
# ══════════════════════════════════════════════════════════════════════
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/apps.sh"
lb_init 'GOOGLE CHROME' "$@"
[[ $LB_ARCH == amd64 ]] || lb_die 'Google Chrome nesta receita requer amd64.'
# ──────────────────────────────────────────────────────────────────────
# Preparação específica — impedir que o postinst recrie a origem APT.
# ──────────────────────────────────────────────────────────────────────
lb_app_before_install() {
    lb_step 'Preservar configuração e controlar criação automática da fonte Google'
    local defaults=/etc/default/google-chrome
    lb_temp
    [[ ! -L $defaults ]] || lb_die 'Configuração Google é link simbólico; revisão manual necessária.'
    if [[ -e $defaults ]]; then
        [[ -f $defaults && -r $defaults ]] || lb_die 'Configuração Google não é arquivo regular legível.'
        awk '!/^[[:space:]]*(repo_add_once|repo_reenable_on_distupgrade)[[:space:]]*=/' "$defaults" > "$LB_TMP/google.defaults"
    else
        : > "$LB_TMP/google.defaults"
    fi
    printf '\nrepo_add_once="false"\nrepo_reenable_on_distupgrade="false"\n' >> "$LB_TMP/google.defaults"
    lb_msg 'Fonte assinada gerenciada por esta receita; atualizações de pacotes continuam por APT.'
    lb_confirm 'Aplicar controles do auxiliar Google com cópia de retorno?' || lb_die 'Preparação cancelada.'
    lb_write_file "$LB_TMP/google.defaults" "$defaults" 644 system
}
# ──────────────────────────────────────────────────────────────────────
# Validação específica — conferir se o pacote preservou a origem preparada.
# ──────────────────────────────────────────────────────────────────────
lb_app_after_install() {
    local source_file=/etc/apt/sources.list.d/google-chrome.sources f matches
    cmp -s -- "$LB_TMP/google-chrome.sources" "$source_file" || lb_die 'Pacote Google alterou a fonte preparada; revise as fontes APT antes de atualizar.'
    for f in /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
        [[ -f $f && $f != "$source_file" ]] || continue
        matches=$(grep -F 'dl.google.com/linux/chrome/deb' "$f" || :)
        if grep -Eq '^[[:space:]]*[^#[:space:]]' <<< "$matches"; then
            lb_die "Fonte Google adicional em $f; configuração preservada para revisão manual."
        fi
    done
    lb_msg 'Fonte Google preparada permanece íntegra; nenhuma duplicação ativa encontrada nesta consulta.'
}
lb_app_apt google-chrome-stable google-chrome google-chrome https://dl.google.com/linux/linux_signing_key.pub https://dl.google.com/linux/chrome/deb/ stable main EB4C1BFD4F042F6DDDCCEC917721F63BD38B4796 detached
# ──────────────────────────────────────────────────────────────────────
# ETAPA 4 — Confirmar executável sem abrir a interface gráfica.
# ──────────────────────────────────────────────────────────────────────
lb_step 'Confirmar executável do navegador'
path=$(command -v google-chrome) || lb_die 'Executável ausente.'
[[ $(readlink -f -- "$path") == $(readlink -f -- /usr/bin/google-chrome) ]] || lb_die 'Outra instalação tem precedência no PATH; revisão necessária.'
/usr/bin/google-chrome --version || lb_die 'Navegador não respondeu à consulta de versão.'
lb_msg 'Abra o navegador pelo menu sem sudo e confirme navegação; configurações pessoais continuam individuais.'
