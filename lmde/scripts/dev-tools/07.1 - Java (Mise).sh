#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# FERRAMENTAS DE DESENVOLVIMENTO — JAVA VIA MISE
# ══════════════════════════════════════════════════════════════════════
# Sistema-alvo: LMDE 7 Gigi / Debian 13 (Bash).
# Finalidade: Instalar apenas Java; requer Mise previamente instalado e validado.
# Uso: Receita de instalação; executar como usuário normal, sem sudo bash.
# Dependências locais: ../lib/common.sh, ../lib/languages.sh
# Organização: títulos sem número; etapas executadas com numeração sequencial.
# Fluxo delegado a lang_mise em ../lib/languages.sh:
#   1. Detectar Mise previamente instalado.
#   2. Escolher versão e escopo.
#   3. Resolver versão concreta no catálogo.
#   4. Instalar e validar a linguagem.
#   5. Registrar seleção no escopo escolhido.
# Notas específicas:
# Alternativa ao SDKMAN: mise prévio. Temurin alterável por --vendor.
# ══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/languages.sh"
lang_mise java Java "$@"
