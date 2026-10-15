#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# FERRAMENTAS DE USO GERAL — YT-DLP
# ══════════════════════════════════════════════════════════════════════
# Sistema-alvo: LMDE 7 Gigi / Debian 13; amd64 ou arm64.
# Finalidade: Instalação compartilhada verificada, com retorno preservado.
# Uso: bash "07 - yt-dlp.sh" [--check|--update|--reinstall] [--yes]
# Opções: --channel auto|nightly|stable; --source vendor|backports|debian;
#         --version latest|stable|VERSÃO; --js-runtime CAMINHO_ABSOLUTO;
#         --test-url URL (teste de rede explícito, sem download de vídeo).
# Preferência inicial: nightly, stable, Backports configurado, Debian.
# Atualização preserva origem/canal; falhas de segurança nunca têm fallback.
# Dependências locais: ../lib/common.sh e ../lib/ytdlp.sh. Leve scripts/ completo.
# Instalação manual: /usr/local/bin/yt-dlp; versões em /usr/local/lib.
# Não migra instalações/aliases nem modifica arquivos pessoais.
# Títulos sem numeração; etapas numeradas durante a execução.
# ══════════════════════════════════════════════════════════════════════
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/ytdlp.sh"
for option in "$@"; do
    if [[ "$option" == --help || "$option" == -h ]]; then lb_usage; yt_usage; exit 0; fi
done

# ──────────────────────────────────────────────────────────────────────
# ETAPA 1 — Diagnóstico, opções e instalações existentes
# ──────────────────────────────────────────────────────────────────────
lb_init 'YT-DLP' "$@"
yt_options
lb_step 'Diagnóstico e instalações existentes'
yt_detect
if [[ "$LB_MODE" == check ]]; then
    yt_check
    exit $?
fi
yt_assert_conflicts
lb_select_action "$YT_INSTALLED"
if [[ "$LB_ACTION" == keep ]]; then lb_finish 'Instalação existente preservada.'; exit 0; fi
yt_preserve_source
if [[ -z "$LB_SOURCE" || "$LB_SOURCE" == vendor ]]; then
    yt_secure_parent /usr/local/bin
    yt_secure_parent "$YT_ROOT"
fi

# ──────────────────────────────────────────────────────────────────────
# ETAPA 2 — Dependências e catálogo autenticado
# ──────────────────────────────────────────────────────────────────────
lb_step 'Pré-requisitos e seleção da origem'
lb_apt_update
lb_apt_install ca-certificates curl gnupg gpgv python3 ffmpeg
for binary in ffmpeg ffprobe; do
    "/usr/bin/$binary" -version >/dev/null || lb_die "$binary não funciona."
done
yt_runtime_prepare
lb_temp
yt_select
lb_msg "Origem: $YT_SOURCE; canal: $YT_CHANNEL; versão: $YT_VERSION."
lb_confirm 'Aplicar a origem e versão exibidas?' || lb_die 'Instalação cancelada.'

# ──────────────────────────────────────────────────────────────────────
# ETAPA 3 — Instalação verificada e cópia de retorno
# ──────────────────────────────────────────────────────────────────────
lb_step 'Integridade, instalação e retorno'
if [[ "$YT_SOURCE" == vendor ]]; then yt_manual_install; else yt_apt_install; fi

# ──────────────────────────────────────────────────────────────────────
# ETAPA 4 — Validação final e resumo
# ──────────────────────────────────────────────────────────────────────
lb_step 'Validação e resumo'
if [[ -n "$YT_TEST_URL" ]]; then
    lb_confirm 'Executar consulta ao site informado, sem baixar mídia?' || lb_die 'Teste de rede cancelado.'
    "$YT_COMMAND" --ignore-config --no-plugin-dirs --no-js-runtimes --js-runtimes "$YT_RUNTIME" --simulate --no-playlist --quiet -- "$YT_TEST_URL" || lb_die 'Consulta funcional falhou; confira dependências e disponibilidade do site.'
fi
lb_finish "yt-dlp $YT_VERSION; $YT_COMMAND; executor $YT_RUNTIME."
lb_msg "Atualizador: $([[ "$YT_SOURCE" == vendor ]] && printf 'este script (--update); não utilizar -U' || printf 'APT / este script')."
lb_msg 'Teste local concluído. Compatibilidade com sites exige consulta funcional explícita.'
