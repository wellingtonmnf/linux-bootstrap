#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# FERRAMENTAS DE DESENVOLVIMENTO — VISUAL STUDIO CODE
# ══════════════════════════════════════════════════════════════════════
# Sistema-alvo: LMDE 7 Gigi / Debian 13 (Bash).
# Finalidade: Instalar pelo repositório oficial do fornecedor e validar o pacote.
# Uso: Receita de instalação; executar como usuário normal, sem sudo bash.
# Dependências locais: ../lib/common.sh, ../lib/apps.sh
# Organização: títulos sem número; etapas executadas com numeração sequencial.
# Notas específicas:
# LMDE 7 Gigi / Debian 13; atualizações e caminhos do pacote APT.
# ══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/apps.sh"
lb_init 'Visual Studio Code' "$@"
lb_app_apt code code vscode \
    https://packages.microsoft.com/keys/microsoft.asc \
    https://packages.microsoft.com/repos/code stable main \
    BC528686B50D79E339D3721CEB3E94ADBE1229CF
