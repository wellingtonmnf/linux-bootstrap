#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# FERRAMENTAS DE DESENVOLVIMENTO — Antigravity
# ══════════════════════════════════════════════════════════════════════
# Sistema-alvo: LMDE 7 Gigi / Debian 13 (Bash).
# Finalidade: instalar o aplicativo oficial no perfil, com menu e retorno.
# Uso: bash "12 - Antigravity.sh" [--check|--update|--reinstall] [--version stable|latest|VERSÃO] [--yes]
# Dependências locais: ../lib/common.sh, ../lib/desktop.sh e ../lib/desktop.py.
# Organização: títulos sem número; etapas executadas com numeração sequencial.
# Fonte e formato: consultar ../APLICATIVOS-NATIVOS.md.
# Atualização: interface do aplicativo quando suportada; requer teste real.
# ══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/desktop.sh"
lb_init 'Antigravity — instalação oficial no perfil' "$@"
# ──────────────────────────────────────────────────────────────────────
# ETAPAS 1–6 — Diagnóstico, dependências, versão, validação, instalação e teste
# ──────────────────────────────────────────────────────────────────────
# O fluxo completo e os cabeçalhos de cada etapa estão em desktop_install.
desktop_install 'antigravity' 'Antigravity'
