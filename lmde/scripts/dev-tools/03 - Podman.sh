#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# FERRAMENTAS DE DESENVOLVIMENTO — PODMAN ADMINISTRATIVO
# ══════════════════════════════════════════════════════════════════════
# Sistema-alvo: LMDE 7 Gigi / Debian 13 (Bash).
# Finalidade: Conferir montagem, instalar pelo Debian e testar armazenamento rootful.
# Uso: Receita de instalação; executar como usuário normal, sem sudo bash.
# Dependências locais: ../lib/common.sh, ../lib/services.sh
# Organização: títulos sem número; etapas executadas com numeração sequencial.
# Notas específicas:
# Podman administrativo/rootful: LMDE 7 / Debian 13 amd64.
# ══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/services.sh"
lb_init 'Podman administrativo' "$@"
svc_no_language_scope
(( ${#LB_EXTRA[@]} == 0 )) || lb_die 'Opções desconhecidas para Podman.'
[[ -z ${LB_SOURCE:-} || $LB_SOURCE == debian ]] || lb_die 'Podman usa Debian oficial.'
[[ ${LB_VERSION:-stable} != lts ]] || lb_die 'Podman não possui canal LTS neste roteiro.'
# ──────────────────────────────────────────────────────────────────────
# ETAPA 1 — Conferir montagem dedicada (65 GiB)
# ──────────────────────────────────────────────────────────────────────
lb_step 'Conferir montagem dedicada (65 GiB)'
svc_mount /var/lib/containers/storage 65
installed=0
if lb_check_package podman; then installed=1; fi
validate_podman() {
    lb_check_package podman || lb_die 'Podman não instalado.'
    podman --version
    graph=$(sudo podman info --format '{{.Store.GraphRoot}}')
    [[ $graph == /var/lib/containers/storage ]] || lb_die "Podman usa $graph, diferente do destino aprovado. Não haverá migração."
    sudo podman ps >/dev/null
}
if [[ $LB_MODE == check ]]; then
    lb_check_package podman || lb_die 'Podman não instalado.'
    podman --version
    for config in /usr/share/containers/storage.conf /etc/containers/storage.conf; do
        if [[ -r $config ]]; then
            lb_msg "Configuração administrativa: $config"
            awk '/^[[:space:]]*(graphroot|runroot|driver)[[:space:]]*=/ {print}' "$config"
        fi
    done
    lb_msg 'Diagnóstico sem inicializar armazenamento. GraphRoot efetivo, containers e persistência serão conferidos na instalação/atualização; este diagnóstico não comprova funcionamento.'
    lb_finish
    exit 0
fi
# ──────────────────────────────────────────────────────────────────────
# ETAPA 2 — Escolher ação e resolver versão Debian
# ──────────────────────────────────────────────────────────────────────
lb_step 'Escolher ação e resolver versão Debian'
lb_select_action "$installed"
if [[ $LB_ACTION != keep ]]; then
    lb_confirm 'Instalar/atualizar Podman administrativo pelo Debian oficial?' || exit 0
    lb_apt_update
    version=$(svc_version podman 'https?://(deb\.debian\.org|security\.debian\.org)/(debian|debian-security) trixie(-security|-updates)?/' "${LB_VERSION:-stable}")
    lb_msg "Versão selecionada: $version; atualizações por APT. Execução: sudo podman."
    # Podman é daemonless; não ativar um serviço API sem necessidade.
    # ──────────────────────────────────────────────────────────────────────
    # ETAPA 3 — Proteger montagem e instalar o pacote
    # ──────────────────────────────────────────────────────────────────────
    lb_step 'Proteger montagem e instalar o pacote'
    svc_mount_guard podman.service '/var/lib/containers/storage'
    svc_mount_guard podman.socket '/var/lib/containers/storage'
    svc_install "podman=$version"
    svc_package_version podman "$version"
fi
# ──────────────────────────────────────────────────────────────────────
# ETAPA 4 — Validar destino, containers e persistência
# ──────────────────────────────────────────────────────────────────────
lb_step 'Validar destino, containers e persistência'
validate_podman
if [[ $LB_ACTION != keep ]]; then
    sudo podman run --rm docker.io/library/hello-world
    svc_container_volume_test podman /var/lib/containers/storage
    lb_msg 'Container administrativo de teste concluído. Imagem preservada.'
fi
lb_msg 'Para uso via linha de comando, conferir a montagem antes de sudo podman; os guards systemd protegem a API, caso usada.'
lb_finish
