#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# FERRAMENTAS DE DESENVOLVIMENTO — DOCKER ENGINE E DOCKER COMPOSE
# ══════════════════════════════════════════════════════════════════════
# Sistema-alvo: LMDE 7 Gigi / Debian 13 (Bash).
# Finalidade: Conferir montagens, instalar pela origem oficial e testar containers e persistência.
# Uso: Receita de instalação; executar como usuário normal, sem sudo bash.
# Dependências locais: ../lib/common.sh, ../lib/services.sh
# Organização: títulos sem número; etapas executadas com numeração sequencial.
# Notas específicas:
# LMDE 7 / Debian 13 amd64. Não monta, migra ou remove dados/pacotes.
# ══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/services.sh"
lb_init 'Docker Engine e Docker Compose' "$@"
svc_no_language_scope
ADD_GROUP=0
for arg in "${LB_EXTRA[@]}"; do
    case $arg in --add-user-to-docker-group) ADD_GROUP=1;; *) lb_die "Opção desconhecida: $arg";; esac
done
[[ ${LB_SOURCE:-vendor} == vendor || -z ${LB_SOURCE:-} ]] || lb_die 'Docker usa o repositório oficial do fornecedor neste roteiro.'
[[ ${LB_VERSION:-stable} != lts ]] || lb_die 'Docker não possui seletor LTS neste script. Use stable/latest ou versão APT exata.'
# ──────────────────────────────────────────────────────────────────────
# ETAPA 1 — Conferir montagens e instalação existente
# ──────────────────────────────────────────────────────────────────────
lb_step 'Conferir montagens e instalação existente'
svc_mount /var/lib/docker 30
svc_mount /var/lib/containerd 35
installed=0
if lb_check_package docker-ce; then installed=1; fi
for conflict in docker.io docker-compose docker-doc docker-buildx podman-docker containerd runc; do
    if lb_check_package "$conflict"; then lb_die "Pacote conflitante: $conflict. Resolva separadamente; nenhuma remoção automática."; fi
done
validate_docker() {
    lb_check_package docker-ce || lb_die 'docker-ce não instalado.'
    lb_check_package docker-compose-plugin || lb_die 'Plugin Compose não instalado.'
    docker --version
    docker compose version
    sudo systemctl is-active --quiet docker || lb_die 'Serviço Docker inativo.'
    sudo systemctl is-active --quiet containerd || lb_die 'Serviço containerd inativo.'
    root=$(sudo docker info --format '{{.DockerRootDir}}')
    [[ $root == /var/lib/docker ]] || lb_die "Docker usa $root; destino esperado /var/lib/docker. Não haverá migração automática."
    # Ler os argumentos do processo real evita validar apenas o config padrão.
    pid=$(systemctl show containerd -p MainPID --value)
    [[ $pid =~ ^[1-9][0-9]*$ ]] || lb_die 'PID containerd inválido.'
    mapfile -d '' -t process_args < "/proc/$pid/cmdline"
    config_path=/etc/containerd/config.toml
    root_override=''
    for ((i=1; i<${#process_args[@]}; i++)); do
        case ${process_args[i]} in
            --config|-c) i=$((i+1)); config_path=${process_args[i]:-};;
            --config=*) config_path=${process_args[i]#*=};;
            --root) i=$((i+1)); root_override=${process_args[i]:-};;
            --root=*) root_override=${process_args[i]#*=};;
        esac
    done
    [[ -n $config_path ]] || lb_die 'Caminho config containerd inválido.'
    [[ -z $root_override || $root_override == /var/lib/containerd ]] || lb_die "Containerd possui --root $root_override."
    config=$(sudo containerd --config "$config_path" config dump)
    grep -Eq "^root = [\"']/var/lib/containerd[\"']$" <<< "$config" || lb_die 'Containerd possui root diferente do destino aprovado.'
    sudo docker ps >/dev/null
    lb_msg 'Daemon, Compose e destinos conferidos. Teste de container é explícito na instalação.'
}
if [[ $LB_MODE == check ]]; then validate_docker; lb_finish; exit 0; fi
# ──────────────────────────────────────────────────────────────────────
# ETAPA 2 — Escolher ação e preparar origem oficial
# ──────────────────────────────────────────────────────────────────────
lb_step 'Escolher ação e preparar origem oficial'
lb_select_action "$installed"
if [[ $LB_ACTION != keep ]]; then
    lb_msg 'Origem: Docker oficial; atualizações: APT. Dados: montagens 30 + 35 GiB.'
    lb_confirm 'Preparar repositório e instalar/atualizar Docker e Compose?' || exit 0
    lb_apt_update
    lb_apt_install ca-certificates curl gnupg
    lb_repo docker https://download.docker.com/linux/debian/gpg https://download.docker.com/linux/debian trixie stable 9DC858229FC7DD38854AE2D88D81803C0EBFCD88
    lb_apt_update
    version=$(svc_version docker-ce 'download\.docker\.com/linux/debian.*trixie' "${LB_VERSION:-stable}")
    svc_version docker-ce-cli 'download\.docker\.com/linux/debian.*trixie' "$version" >/dev/null
    lb_msg "Versão selecionada: $version"
    # ──────────────────────────────────────────────────────────────────────
    # ETAPA 3 — Proteger montagens e instalar os pacotes
    # ──────────────────────────────────────────────────────────────────────
    lb_step 'Proteger montagens e instalar os pacotes'
    svc_mount_guard docker.service '/var/lib/docker /var/lib/containerd'
    svc_mount_guard containerd.service '/var/lib/containerd'
    svc_install "docker-ce=$version" "docker-ce-cli=$version" containerd.io docker-buildx-plugin docker-compose-plugin
    svc_package_version docker-ce "$version"
    svc_package_version docker-ce-cli "$version"
    sudo systemctl start containerd docker
fi
# ──────────────────────────────────────────────────────────────────────
# ETAPA 4 — Validar serviços, caminhos e persistência
# ──────────────────────────────────────────────────────────────────────
lb_step 'Validar serviços, caminhos e persistência'
validate_docker
if [[ $LB_ACTION != keep ]]; then
    sudo docker run --rm hello-world
    svc_container_volume_test docker /var/lib/docker
    lb_msg 'hello-world concluído. A imagem de teste permanece; nenhum dado anterior foi excluído.'
fi
if (( ADD_GROUP )); then
    # ──────────────────────────────────────────────────────────────────────
    # ETAPA 5 — Configurar acesso administrativo opcional
    # ──────────────────────────────────────────────────────────────────────
    lb_step 'Configurar acesso administrativo opcional'
    lb_warn 'O grupo docker permite controle administrativo do computador.'
    lb_confirm 'Adicionar a conta atual ao grupo docker (exigirá novo login)?' || exit 0
    sudo usermod -aG docker "$(id -un)"
    lb_msg 'Faça logout/login; até lá, continue usando sudo docker.'
fi
lb_finish
