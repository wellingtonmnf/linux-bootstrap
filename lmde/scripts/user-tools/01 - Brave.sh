#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# FERRAMENTAS DE USO GERAL — BRAVE BROWSER
# ══════════════════════════════════════════════════════════════════════
# Sistema-alvo: LMDE 7 Gigi / Debian 13 (Bash).
# Finalidade: Instalar, atualizar ou diagnosticar BRAVE BROWSER.
# Uso: Executar como usuário normal, sem sudo bash.
# Dependências locais: ../lib/common.sh, ../lib/apps.sh.
# Origem e atualização: APT; repositório oficial Brave, chaves primárias restritas e InRelease verificado.
# Fluxo compartilhado em apps.sh:
#   1. Detectar instalação e escolher ação.
#   2. Resolver origem e versão; conferir assinaturas quando houver fornecedor.
#   3. Instalar e validar pacote; testar interface manualmente.
# ══════════════════════════════════════════════════════════════════════
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/apps.sh"
lb_init 'BRAVE BROWSER' "$@"
lb_app_apt brave-browser brave-browser brave https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/ stable main 'DBF1A116C220B8C7164F98230686B78420038257 47D32A74E9A9E013A4B4926C68D513D36A73CD96 B2A3DCA350E67256740DF904DE4EC67BE4B0DCA0'
# ──────────────────────────────────────────────────────────────────────
# ETAPA 4 — Confirmar executável sem abrir a interface gráfica.
# ──────────────────────────────────────────────────────────────────────
lb_step 'Confirmar executável do navegador'
path=$(command -v brave-browser) || lb_die 'Executável ausente.'
[[ $(readlink -f -- "$path") == $(readlink -f -- /usr/bin/brave-browser) ]] || lb_die 'Outra instalação tem precedência no PATH; revisão necessária.'
/usr/bin/brave-browser --version || lb_die 'Navegador não respondeu à consulta de versão.'
lb_msg 'Abra o navegador pelo menu sem sudo e confirme navegação; configurações pessoais continuam individuais.'
