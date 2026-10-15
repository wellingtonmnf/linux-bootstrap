#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# FERRAMENTAS DE USO GERAL — CHROMIUM
# ══════════════════════════════════════════════════════════════════════
# Sistema-alvo: LMDE 7 Gigi / Debian 13 (Bash).
# Finalidade: Instalar, atualizar ou diagnosticar CHROMIUM.
# Uso: Executar como usuário normal, sem sudo bash.
# Dependências locais: ../lib/common.sh, ../lib/apps.sh.
# Origem e atualização: APT; repositórios oficiais Debian, sem adicionar fontes externas.
# Fluxo compartilhado em apps.sh:
#   1. Detectar instalação e escolher ação.
#   2. Resolver origem e versão; conferir assinaturas quando houver fornecedor.
#   3. Instalar e validar pacote; testar interface manualmente.
# ══════════════════════════════════════════════════════════════════════
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/apps.sh"
lb_init 'CHROMIUM' "$@"
lb_app_debian chromium chromium
# ──────────────────────────────────────────────────────────────────────
# ETAPA 4 — Confirmar executável sem abrir a interface gráfica.
# ──────────────────────────────────────────────────────────────────────
lb_step 'Confirmar executável do navegador'
path=$(command -v chromium) || lb_die 'Executável ausente.'
[[ $(readlink -f -- "$path") == $(readlink -f -- /usr/bin/chromium) ]] || lb_die 'Outra instalação tem precedência no PATH; revisão necessária.'
/usr/bin/chromium --version || lb_die 'Navegador não respondeu à consulta de versão.'
lb_msg 'Abra o navegador pelo menu sem sudo e confirme navegação; configurações pessoais continuam individuais.'
