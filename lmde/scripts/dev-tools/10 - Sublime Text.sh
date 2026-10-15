#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# FERRAMENTAS DE DESENVOLVIMENTO — SUBLIME TEXT
# ══════════════════════════════════════════════════════════════════════
# Sistema-alvo: LMDE 7 Gigi / Debian 13 (Bash).
# Finalidade: Instalar pelo repositório oficial do fornecedor e validar o pacote.
# Uso: Receita de instalação; executar como usuário normal, sem sudo bash.
# Dependências locais: ../lib/common.sh, ../lib/apps.sh
# Organização: títulos sem número; etapas executadas com numeração sequencial.
# Notas específicas:
# LMDE 7 Gigi / Debian 13; Sublime é escolha, não filtro de licença.
# ══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/apps.sh"
lb_init 'Sublime Text' "$@"
lb_app_apt sublime-text subl sublime \
    https://download.sublimetext.com/sublimehq-pub.gpg \
    https://download.sublimetext.com/ apt/stable/ '' \
    '1EDDE2CDFC025D17F6DA9EC0ADAE6AD28A8F901A 1B64279675A4299DCFC70858CA464A9A222D23D0 EBC733B78AAB352DC773BF857FE2FA12CF6E38F2'
