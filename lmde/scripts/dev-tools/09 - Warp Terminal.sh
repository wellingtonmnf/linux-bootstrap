#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# FERRAMENTAS DE DESENVOLVIMENTO — WARP TERMINAL
# ══════════════════════════════════════════════════════════════════════
# Sistema-alvo: LMDE 7 Gigi / Debian 13 (Bash).
# Finalidade: Instalar pelo repositório oficial do fornecedor e validar o pacote.
# Uso: Receita de instalação; executar como usuário normal, sem sudo bash.
# Dependências locais: ../lib/common.sh, ../lib/apps.sh
# Organização: títulos sem número; etapas executadas com numeração sequencial.
# Notas específicas:
# LMDE 7 Gigi / Debian 13; origem oficial, caminhos e atualizações APT.
# ══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/apps.sh"
lb_init 'Warp Terminal' "$@"
lb_app_apt warp-terminal warp-terminal warp \
    https://releases.warp.dev/linux/keys/warp.asc \
    https://releases.warp.dev/linux/deb stable main \
    0913165C78D5B7A41B42AC657FF7AB39D60F803F detached
