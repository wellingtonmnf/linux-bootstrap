#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# BIBLIOTECAS DE INSTALAÇÃO — BIBLIOTECA FLATPAK
# ══════════════════════════════════════════════════════════════════════
# Finalidade: validar Flathub e instalar aplicativos para todos os usuários.
# Sistema-alvo: LMDE 7 Gigi / Debian 13; instalação system padrão.
# Uso: carregar com source após common.sh; não executar diretamente.
# Dependências locais: common.sh; Flatpak, Python 3; APT para preparar o gerenciador.
# Organização: títulos sem número; etapas executadas numeradas por lb_step.
# Segurança: sem overrides, migração de escopo ou remoção automática de dados.
# ══════════════════════════════════════════════════════════════════════

FP_IDS=(app.zen_browser.zen org.onlyoffice.desktopeditors org.gimp.GIMP org.inkscape.Inkscape net.scribus.Scribus com.valvesoftware.Steam com.heroicgameslauncher.hgl org.telegram.desktop)
FP_NAMES=('Zen Browser' ONLYOFFICE GIMP Inkscape Scribus Steam 'Heroic Games Launcher' Telegram)
FP_SELECTED=()
FP_FINGERPRINT=6E5C05D979C76DAF93C081354184DD4D907A7CAE

# ──────────────────────────────────────────────────────────────────────
# Seleção dos aplicativos e validação das opções (fp_options)
# ──────────────────────────────────────────────────────────────────────
fp_options() {
    local i id found
    [[ -z "$LB_SOURCE" && -z "$LB_VERSION" && "$LB_SCOPE" == none && -z "$LB_PROJECT" ]] || lb_die 'Flatpak usa Flathub stable e escopo system fixo; seletores de linguagem/APT não se aplicam.'
    for ((i=0; i<${#LB_EXTRA[@]}; i++)); do
        [[ ${LB_EXTRA[i]} == --app ]] || lb_die "Opção não reconhecida: ${LB_EXTRA[i]}"
        i=$((i+1)); ((i<${#LB_EXTRA[@]})) || lb_die 'Falta ID para --app.'
        id=${LB_EXTRA[i]}; found=0
        local candidate
        for candidate in "${FP_IDS[@]}"; do [[ $candidate != "$id" ]] || found=1; done
        ((found)) || lb_die "Aplicativo fora do lote: $id"
        [[ " ${FP_SELECTED[*]} " == *" $id "* ]] || FP_SELECTED+=("$id")
    done
    ((${#FP_SELECTED[@]})) || FP_SELECTED=("${FP_IDS[@]}")
}

# ──────────────────────────────────────────────────────────────────────
# Leitura da chave pública: fingerprint OpenPGP v4 sem criar arquivos
# Não verifica assinaturas: essa responsabilidade pertence ao Flatpak.
# ──────────────────────────────────────────────────────────────────────
fp_validate_config() {
    local mode=$1 path=$2
    python3 - "$mode" "$path" "$FP_FINGERPRINT" <<'PY'
import base64, configparser, hashlib, pathlib, sys
mode, path, expected = sys.argv[1:]
try:
    config = configparser.ConfigParser(interpolation=None, strict=True)
    config.read_string(pathlib.Path(path).read_text())
    section = config['Flatpak Repo' if mode == 'definition' else 'remote "flathub"']
    url = section.get('Url' if mode == 'definition' else 'url', '')
    if url not in ('https://dl.flathub.org/repo/', 'https://flathub.org/repo/'):
        raise ValueError('URL do Flathub divergente')
    if mode == 'definition':
        data = base64.b64decode(section['GPGKey'], validate=True)
    else:
        if not section.getboolean('gpg-verify', fallback=False):
            raise ValueError('verificação GPG desativada')
        if section.getboolean('xa.disable', fallback=False):
            raise ValueError('remote desativado')
        if not section.getboolean('gpg-verify-summary', fallback=False) and section.get('collection-id') != 'org.flathub.Stable':
            raise ValueError('summary sem assinatura nem collection-id oficial')
        data = pathlib.Path(path).with_name('flathub.trustedkeys.gpg').read_bytes()
    # Packet headers RFC 4880; recusa tamanhos parciais/indeterminados.
    fingerprints = []
    p = 0
    while p < len(data):
        header = data[p]; p += 1
        if not header & 128: raise ValueError('packet inválido')
        if header & 64:
            tag = header & 63; size = data[p]; p += 1
            if size < 192: length = size
            elif size < 224:
                length = (size-192)*256 + data[p] + 192; p += 1
            elif size == 255:
                length = int.from_bytes(data[p:p+4], 'big'); p += 4
            else: raise ValueError('packet parcial não suportado')
        else:
            tag = (header >> 2) & 15; kind = header & 3
            if kind == 3: raise ValueError('packet sem tamanho')
            width = (1,2,4)[kind]
            length = int.from_bytes(data[p:p+width], 'big'); p += width
        body = data[p:p+length]; p += length
        if len(body) != length: raise ValueError('packet truncado')
        if tag == 6:
            if not body or body[0] != 4 or length > 65535:
                raise ValueError('chave primária não suportada')
            fingerprints.append(hashlib.sha1(b'\x99'+length.to_bytes(2,'big')+body).hexdigest().upper())
    if fingerprints != [expected]: raise ValueError('identidade da chave Flathub divergente')
    print('Flathub: URL oficial, chave primária ' + expected + '; escopo system.')
except (OSError, ValueError, KeyError, IndexError, configparser.Error) as exc:
    print('Configuração Flathub recusada: ' + str(exc), file=sys.stderr)
    sys.exit(1)
PY
}

# ──────────────────────────────────────────────────────────────────────
# ETAPA 1 — Diagnóstico local de Flathub (fp_remote_check)
# ──────────────────────────────────────────────────────────────────────
fp_remote_check() {
    command -v flatpak >/dev/null || { lb_warn 'Flatpak não instalado.'; return 1; }
    command -v python3 >/dev/null || { lb_warn 'Python 3 necessário para validar a configuração.'; return 1; }
    flatpak remotes --system --show-disabled --columns=name,url,options || return 1
    fp_validate_config installed /var/lib/flatpak/repo/config || return 1
}

# ──────────────────────────────────────────────────────────────────────
# ETAPAS 1–3 — Gerenciador Debian, definição oficial e diagnóstico final
# ──────────────────────────────────────────────────────────────────────
fp_setup() {
    lb_assert_no_extra
    [[ -z "$LB_SOURCE" && -z "$LB_VERSION" && "$LB_SCOPE" == none && -z "$LB_PROJECT" ]] || lb_die 'Flatpak usa Debian e escopo system fixo.'
    lb_step 'Diagnóstico local — gerenciador e Flathub system'
    if [[ $LB_MODE == check ]]; then fp_remote_check; return; fi
    local installed=0
    lb_check_package flatpak && installed=1
    lb_select_action "$installed"
    if [[ $LB_ACTION != keep ]] || ! command -v python3 >/dev/null || ! command -v curl >/dev/null; then
        lb_step 'Preparar Flatpak e Python 3 pelo Debian'
        lb_apt_update
        local version row candidate=''
        version=$(lb_apt_candidate flatpak)
        while IFS= read -r row; do
            [[ "$row" == *"| $version |"* && "$row" =~ https?://(deb\.debian\.org|security\.debian\.org)/(debian|debian-security)[[:space:]]trixie(-security|-updates)?/ ]] && candidate=$version
        done < <(apt-cache madison flatpak)
        [[ -n $candidate ]] || lb_die 'Candidato Flatpak não identificado no Debian Trixie oficial.'
        if [[ $LB_ACTION == reinstall ]]; then lb_apt_install --reinstall "flatpak=$version" python3 curl ca-certificates;
        else lb_apt_install "flatpak=$version" python3 curl ca-certificates; fi
        lb_check_package flatpak && flatpak --version || lb_die 'Flatpak não validado após APT.'
    fi
    lb_step 'Configuração oficial — Flathub para todos os usuários'
    local remotes
    remotes=$(flatpak remotes --system --show-disabled --columns=name) || lb_die 'Não foi possível consultar remotes system.'
    if grep -qxF flathub <<< "$remotes"; then
        fp_remote_check || lb_die 'Flathub existente diverge do padrão seguro; revise manualmente, sem sobrescrever.'
    else
        lb_temp
        lb_download https://dl.flathub.org/repo/flathub.flatpakrepo "$LB_TMP/flathub.flatpakrepo"
        fp_validate_config definition "$LB_TMP/flathub.flatpakrepo" || lb_die 'Definição Flathub inválida.'
        lb_confirm 'Adicionar Flathub à instalação system (/var/lib/flatpak), disponível a todos os usuários?' || lb_die 'Cancelado.'
        sudo flatpak remote-add --system --no-follow-redirect flathub "$LB_TMP/flathub.flatpakrepo" || lb_die 'Falha ao configurar Flathub.'
        fp_remote_check || lb_die 'Configuração final Flathub não validada.'
    fi
    lb_title 'Resultado — Flatpak e Flathub system validados'
    lb_msg 'Nova sessão pode ser necessária para integração do menu. Instalações user foram preservadas.'
}

# ──────────────────────────────────────────────────────────────────────
# ETAPA 2 — Origem, commit, permissões e suporte do aplicativo e runtime
# ──────────────────────────────────────────────────────────────────────
fp_review() {
    local id=$1 info runtime runtime_info
    info=$(flatpak remote-info --system flathub "$id//stable") || return 1
    lb_msg "$info"
    if grep -Eq '^[[:space:]]*End-of-life(-rebase)?:' <<< "$info"; then lb_warn "$id: aplicativo sem suporte; transação bloqueada."; return 1; fi
    FP_COMMIT=$(flatpak remote-info --system --show-commit flathub "$id//stable") || return 1
    [[ $FP_COMMIT =~ ^[[:xdigit:]]{64}$ ]] || { lb_warn 'Commit não identificado.'; return 1; }
    FP_METADATA=$(flatpak remote-info --system --commit="$FP_COMMIT" --show-metadata flathub "$id//stable") || return 1
    [[ "$FP_METADATA" == *'[Application]'* && "$FP_METADATA" == *'[Context]'* ]] || { lb_warn 'Metadados de permissões ausentes; transação bloqueada.'; return 1; }
    lb_msg 'Permissões declaradas no pacote (sem concessões adicionais pelo script):'
    lb_msg "$FP_METADATA"
    fp_overrides "$id" || return 1
    if grep -Eq '^filesystems=.*(home|host)(;|:|$)' <<< "$FP_METADATA"; then lb_warn 'Acesso amplo a arquivos (home/host): confira a necessidade antes de confirmar.'; fi
    runtime=$(awk '/^\[Application\]$/ {inside=1;next} /^\[/ {inside=0} inside && /^runtime=/ {sub(/^runtime=/, ""); print}' <<< "$FP_METADATA")
    [[ $runtime =~ ^[[:alnum:]_.-]+/(x86_64|aarch64)/[[:alnum:]_.-]+$ ]] || { lb_warn 'Runtime não identificado.'; return 1; }
    runtime_info=$(flatpak remote-info --system --runtime flathub "$runtime") || { lb_warn 'Suporte do runtime indisponível no Flathub; transação bloqueada.'; return 1; }
    lb_msg "Runtime: $runtime"
    lb_msg "$runtime_info"
    if grep -Eq '^[[:space:]]*End-of-life(-rebase)?:' <<< "$runtime_info"; then lb_warn 'Runtime sem suporte; transação bloqueada.'; return 1; fi
    lb_msg 'Suporte: app/runtime sem marca End-of-life nos metadados consultados; não é garantia de manutenção.'
}

# ──────────────────────────────────────────────────────────────────────
# Permissões adicionais existentes: globais e específicas, sem modificar
# ──────────────────────────────────────────────────────────────────────
fp_overrides() {
    local id=$1 scope output
    for scope in system user; do
        lb_msg "Overrides existentes $scope — globais:"
        output=$(flatpak override --"$scope" --show) || { lb_warn 'Falha ao consultar overrides globais.'; return 1; }
        lb_msg "${output:-(nenhum)}"
        lb_msg "Overrides existentes $scope — $id:"
        output=$(flatpak override --"$scope" --show "$id") || { lb_warn 'Falha ao consultar overrides do aplicativo.'; return 1; }
        lb_msg "${output:-(nenhum)}"
        [[ -z $output ]] || lb_warn 'Overrides podem ampliar ou limitar as permissões apresentadas; configuração preservada.'
    done
    lb_msg 'Overrides user exibidos pertencem apenas ao perfil atual; outros perfis possuem configurações próprias.'
}

# ──────────────────────────────────────────────────────────────────────
# ETAPAS 2–4 — Receita individual e validação da instalação efetiva
# ──────────────────────────────────────────────────────────────────────
fp_app() {
    local id=$1 installed=0 origin action actual metadata
    if flatpak info --system "$id//stable" >/dev/null 2>&1; then installed=1; fi
    if flatpak info --user "$id" >/dev/null 2>&1; then lb_warn "$id também existe no perfil atual; instalação user preservada, possível duplicação no menu."; fi
    if [[ $LB_MODE == check ]]; then
        ((installed)) || { lb_warn "$id ausente no system."; return 1; }
        flatpak info --system "$id//stable" && flatpak info --system --show-permissions "$id//stable" || return 1
        fp_overrides "$id" || return 1
        lb_msg 'Diagnóstico local: suporte remoto não consultado; permissões user podem diferir por overrides.'
        return 0
    fi
    action=$LB_MODE
    [[ $action != install || $installed == 0 ]] || { lb_msg "$id: instalação system mantida; use --update ou --reinstall."; return 0; }
    if ((installed)); then
        origin=$(flatpak info --system --show-origin "$id//stable") || return 1
        [[ $origin == flathub ]] || { lb_warn "$id tem origem $origin; não será migrado."; return 1; }
    elif [[ $action == update || $action == reinstall ]]; then
        lb_warn "$id não está instalado no system; use instalação normal."; return 1
    fi
    lb_step "Revisar origem, permissões e suporte — $id"
    fp_review "$id" || return 1
    lb_step "Confirmar e aplicar $action — $id"
    lb_confirm "Aplicar $action system de $id com as permissões exibidas?" || { lb_warn 'Aplicativo cancelado.'; return 1; }
    case $action in
        install) sudo flatpak install --system --noninteractive -y flathub "$id//stable" || return 1 ;;
        update) sudo flatpak update --system --noninteractive --no-related -y "$id//stable" || return 1 ;;
        reinstall) sudo flatpak install --system --noninteractive --reinstall -y flathub "$id//stable" || return 1 ;;
    esac
    lb_step "Validar origem, commit e permissões — $id"
    origin=$(flatpak info --system --show-origin "$id//stable") || return 1
    actual=$(flatpak info --system --show-commit "$id//stable") || return 1
    metadata=$(flatpak info --system --show-metadata "$id//stable") || return 1
    [[ $origin == flathub && $actual == "$FP_COMMIT" && $metadata == "$FP_METADATA" ]] || { lb_warn 'Instalação difere da revisão (possível publicação concorrente); verifique antes de abrir o aplicativo.'; return 1; }
    flatpak info --system "$id//stable" || return 1
    lb_msg "$id: instalação system validada; dados pessoais permanecem individuais."
}

# ──────────────────────────────────────────────────────────────────────
# ETAPAS 1–5 — Diagnóstico, lote e resumo com código de falha correto
# ──────────────────────────────────────────────────────────────────────
fp_batch() {
    fp_options
    lb_step 'Diagnóstico — gerenciador e confiança do Flathub system'
    fp_remote_check || lb_die 'Execute primeiro 05 - Flatpak.sh ou revise a configuração existente.'
    lb_msg 'Dados de aplicativos: ~/.var/app/ID por usuário. Nenhum override, remoção ou rebase automático.'
    local id ok=0 errors=0
    for id in "${FP_SELECTED[@]}"; do
        lb_title "Aplicativo — $id"
        if fp_app "$id"; then ok=$((ok+1)); else errors=$((errors+1)); lb_warn "$id falhou; demais escolhas serão examinadas."; fi
    done
    lb_step 'Resumo final — aplicativos selecionados'
    lb_msg "Sucesso/mantidos: $ok; falhas/cancelados: $errors; total: ${#FP_SELECTED[@]}."
    ((errors==0)) || { lb_warn 'Lote parcial ou malsucedido; código de saída 1. Reexecute apenas os aplicativos necessários.'; return 1; }
}
