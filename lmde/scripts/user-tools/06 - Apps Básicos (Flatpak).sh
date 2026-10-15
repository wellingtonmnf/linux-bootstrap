#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# FERRAMENTAS DE USO GERAL — APLICATIVOS BÁSICOS FLATPAK
# ══════════════════════════════════════════════════════════════════════
# Finalidade: instalar o lote original, revisando permissões e suporte.
# Sistema-alvo: LMDE 7 Gigi / Debian 13; apps para todos os usuários.
# Uso: bash "06 - Apps Básicos (Flatpak).sh" [--app ID ...] [--check | --update | --reinstall] [--yes]
# Dependências locais: ../lib/common.sh e ../lib/flatpak.sh.
# Pré-requisito: executar 05 - Flatpak.sh para preparar Flathub system.
# Fluxo: 1 diagnóstico; 2 revisão; 3 transação; 4 validação; 5 resumo.
# Organização: títulos sem número; etapas numeradas por lb_step.
# Notas: sem --app, selecionar oito apps; dados por usuário separados.
# ══════════════════════════════════════════════════════════════════════
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/flatpak.sh"

# ──────────────────────────────────────────────────────────────────────
# ETAPA 1 — Inicialização e opções
# ──────────────────────────────────────────────────────────────────────
lb_init 'Aplicativos básicos — Flathub para todos os usuários' "$@"

# ──────────────────────────────────────────────────────────────────────
# ETAPAS 1–5 — Lote compartilhado com resultado completo ou parcial
# ──────────────────────────────────────────────────────────────────────
fp_batch
