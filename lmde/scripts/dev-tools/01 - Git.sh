#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# FERRAMENTAS DE DESENVOLVIMENTO — GIT
# ══════════════════════════════════════════════════════════════════════
# Sistema-alvo: LMDE 7 Gigi / Debian 13 (Bash).
# Finalidade: Instalar pela origem escolhida, configurar opcionalmente e validar o Git.
# Uso: Receita de instalação; executar como usuário normal, sem sudo bash.
# Dependências locais: ../lib/common.sh
# Organização: títulos sem número; etapas executadas com numeração sequencial.
# Notas específicas:
# Git — LMDE 7 Gigi / Debian 13. Origem Debian por padrão.
# ══════════════════════════════════════════════════════════════════════

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/../lib/common.sh"
lb_init 'GIT — instalação e configuração separadas' "$@"
configure=0
git_name=''
git_email=''
args=("${LB_EXTRA[@]}")
for ((i=0; i<${#args[@]}; i++)); do
    case "${args[i]}" in
        --configure) configure=1 ;;
        --git-name|--git-email)
            field=${args[i]}; ((i+=1))
            [[ $i -lt ${#args[@]} && -n ${args[i]} && ${args[i]} != --* ]] || lb_die "Falta valor para $field."
            if [[ "$field" == --git-name ]]; then git_name=${args[i]}; else git_email=${args[i]}; fi
            configure=1 ;;
        *) lb_die "Opção Git desconhecida: ${args[i]}." ;;
    esac
done
source_name=${LB_SOURCE:-debian}
[[ "$source_name" == debian || "$source_name" == backports ]] || lb_die 'Git: use Debian ou Backports. Origem externa não será adicionada automaticamente.'
[[ "$LB_VERSION" != lts ]] || lb_die 'Git não possui canal LTS oficial. Use stable/latest ou versão explícita.'
# ──────────────────────────────────────────────────────────────────────
# ETAPA 1 — Detectar instalação e escolher ação
# ──────────────────────────────────────────────────────────────────────
lb_step 'Detectar instalação e escolher ação'
installed=0
if lb_check_package git; then
    [[ -x /usr/bin/git ]] || lb_die 'Pacote instalado sem executável /usr/bin/git; use reparo explícito após diagnóstico.'
    /usr/bin/git --version
    installed=1
fi
if [[ "$LB_MODE" == check ]]; then
    apt-cache policy git
    if ((installed)); then
        executable=$(type -P git || :)
        [[ -n "$executable" && $(readlink -f -- "$executable") == /usr/bin/git ]] || lb_die 'Outra instalação de Git tem precedência no PATH.'
        lb_finish 'Git Debian encontrado; compare a versão exibida com a versão desejada nas outras máquinas.'
    else
        lb_die 'Git Debian não instalado.'
    fi
    exit 0
fi
lb_select_action "$installed"
if [[ "$LB_ACTION" != keep ]]; then
    # ──────────────────────────────────────────────────────────────────────
    # ETAPA 2 — Atualizar índices e resolver versão na origem escolhida
    # ──────────────────────────────────────────────────────────────────────
    lb_step 'Atualizar índices e resolver versão na origem escolhida'
    lb_apt_update
    if [[ "$source_name" == backports ]]; then suite=trixie-backports; else suite=trixie; fi
    selected=''
    while IFS='|' read -r package candidate origin; do
        candidate=${candidate//[[:space:]]/}
        [[ -n "$candidate" ]] || continue
        [[ "$origin" =~ https?://(deb\.debian\.org|security\.debian\.org)/(debian|debian-security)[[:space:]] ]] || continue
        if [[ "$source_name" == backports ]]; then
            [[ "$origin" == *' trixie-backports/'* ]] || continue
        else
            [[ "$origin" == *' trixie/'* || "$origin" == *' trixie-security/'* || "$origin" == *' trixie-updates/'* ]] || continue
        fi
        upstream=${candidate#*:}; upstream=${upstream%%-*}
        if [[ -n "$LB_VERSION" && "$LB_VERSION" != latest && "$LB_VERSION" != stable ]]; then
            [[ "$LB_VERSION" == "$candidate" || "$LB_VERSION" == "$upstream" ]] || continue
        fi
        if [[ -z "$selected" ]] || dpkg --compare-versions "$candidate" gt "$selected"; then selected=$candidate; fi
    done < <(apt-cache madison git)
    [[ -n "$selected" ]] || lb_die "Versão solicitada indisponível em $suite. Não houve troca de origem; confira Backports/pareamento."
    lb_msg "Versão concreta: $selected; origem $source_name."
    lb_msg 'latest/stable significam a versão final disponível na origem escolhida, sem promessa de igualdade com Git for Windows.'
    opts=()
    [[ "$LB_ACTION" != reinstall ]] || opts+=(--reinstall)
    lb_apt_install "${opts[@]}" "git=$selected"
    lb_check_package git || lb_die 'Pacote Git não instalado corretamente.'
    [[ $(dpkg-query -W -f='${Version}' git) == "$selected" ]] || lb_die 'Versão instalada diferente da seleção APT.'
fi
# ──────────────────────────────────────────────────────────────────────
# ETAPA 3 — Configuração pessoal (opcional)
# ──────────────────────────────────────────────────────────────────────
lb_step 'Configuração pessoal (opcional)'
if ((configure==0)) && [[ -t 0 ]]; then
    if lb_confirm 'Configurar nome e e-mail globais do Git?'; then configure=1; fi
fi
if ((configure)); then
    if [[ -z "$git_name" ]]; then
        [[ -t 0 ]] || lb_die 'Use --git-name e --git-email para configuração sem terminal.'
        read -r -p 'Nome para Git: ' git_name || lb_die 'Entrada encerrada.'
    fi
    if [[ -z "$git_email" ]]; then
        [[ -t 0 ]] || lb_die 'Informe --git-email.'
        read -r -p 'E-mail para Git: ' git_email || lb_die 'Entrada encerrada.'
    fi
    [[ "$git_name" == *[![:space:]]* && "$git_name" != *$'\n'* && "$git_name" != *$'\r'* ]] || lb_die 'Nome inválido.'
    [[ "$git_email" =~ ^[^[:space:]@]+@[^[:space:]@]+$ ]] || lb_die 'E-mail inválido.'
    [[ -z ${GIT_CONFIG_GLOBAL:-} ]] || lb_die 'GIT_CONFIG_GLOBAL definido; revise o destino antes de configurar automaticamente.'
    config_file="$HOME/.gitconfig"
    xdg_file="${XDG_CONFIG_HOME:-$HOME/.config}/git/config"
    if [[ ! -e "$config_file" && -f "$xdg_file" ]]; then config_file=$xdg_file; fi
    [[ ! -L "$config_file" ]] || lb_die 'Configuração Git é link; revisão manual necessária.'
    lb_backup "$config_file"
    /usr/bin/git config --global user.name "$git_name"
    /usr/bin/git config --global user.email "$git_email"
    [[ $(/usr/bin/git config --global user.name) == "$git_name" && $(/usr/bin/git config --global user.email) == "$git_email" ]] || lb_die 'Configuração não corresponde aos dados fornecidos.'
    lb_msg 'Configuração conferida; dados pessoais não reproduzidos no resumo.'
else
    lb_msg 'Configuração pessoal mantida.'
fi
# ──────────────────────────────────────────────────────────────────────
# ETAPA 4 — Validar Git
# ──────────────────────────────────────────────────────────────────────
lb_step 'Validar Git'
/usr/bin/git --version
if [[ -n ${selected:-} ]]; then
    upstream=${selected#*:}; upstream=${upstream%%-*}
    [[ $(/usr/bin/git --version) == "git version $upstream" ]] || lb_die 'Executável Git não reportou a versão do pacote selecionado.'
fi
executable=$(type -P git || :)
[[ -n "$executable" && $(readlink -f -- "$executable") == /usr/bin/git ]] || lb_die 'Git preparado, mas outro executável tem precedência no PATH.'
lb_temp
/usr/bin/git init --quiet "$LB_TMP/git-validation"
/usr/bin/git -C "$LB_TMP/git-validation" rev-parse --is-inside-work-tree | grep -qx true
lb_finish 'Git funcional. Atualizações pelo APT; configuração pessoal separada.'
