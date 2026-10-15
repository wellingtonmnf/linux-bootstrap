#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# FERRAMENTAS DE USO GERAL — FLATPAK E FLATHUB
# ══════════════════════════════════════════════════════════════════════
# Finalidade: preparar Flatpak Debian e Flathub com confiança validada.
# Sistema-alvo: LMDE 7 Gigi / Debian 13; instalação system padrão.
# Uso: bash "05 - Flatpak.sh" [--check | --update | --reinstall] [--yes]
# Dependências locais: ../lib/common.sh e ../lib/flatpak.sh.
# Fluxo: 1 diagnóstico; 2 gerenciador APT; 3 Flathub e validação final.
# Organização: títulos sem número; etapas numeradas por lb_step.
# Notas: executar sem sudo bash; system disponibiliza apps a todos.
# ══════════════════════════════════════════════════════════════════════
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/flatpak.sh"

# ──────────────────────────────────────────────────────────────────────
# ETAPA 1 — Inicialização e opções
# ──────────────────────────────────────────────────────────────────────
lb_init 'Flatpak e Flathub — ferramentas de uso geral' "$@"

# ──────────────────────────────────────────────────────────────────────
# ETAPAS 1–3 — Fluxo compartilhado, incluindo validação final
# ──────────────────────────────────────────────────────────────────────
fp_setup
