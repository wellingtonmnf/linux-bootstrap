#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# FERRAMENTAS DE DESENVOLVIMENTO — JETBRAINS TOOLBOX
# ══════════════════════════════════════════════════════════════════════
# Sistema-alvo: LMDE 7 Gigi / Debian 13 (Bash).
# Finalidade: Preparar a Toolbox pessoal; primeira abertura conclui a configuração gráfica.
# Uso: Receita de instalação; executar como usuário normal, sem sudo bash.
# Dependências locais: ../lib/common.sh
# Organização: títulos sem número; etapas executadas com numeração sequencial.
# Notas específicas:
# LMDE 7 Gigi / Debian 13. Preparação pessoal; primeira abertura conclui instalação.
# Fonte: https://www.jetbrains.com/help/toolbox-app/installation.html
# ══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/../lib/common.sh"
lb_init 'JetBrains Toolbox' "$@"
lb_assert_no_extra
[[ -z ${LB_SOURCE:-} || $LB_SOURCE == vendor ]] || lb_die 'Toolbox usa o download oficial JetBrains (--source vendor).'
[[ ${LB_SCOPE:-none} == none || $LB_SCOPE == user ]] || lb_die 'Toolbox é preparado para o usuário; não usar sudo no script.'
# ──────────────────────────────────────────────────────────────────────
# ETAPA 1 — Detectar instalação e escolher ação
# ──────────────────────────────────────────────────────────────────────
lb_step 'Detectar instalação e escolher ação'
native="$HOME/.local/share/JetBrains/Toolbox/bin/jetbrains-toolbox"
launcher="$HOME/.local/bin/jetbrains-toolbox"
installed=0
if [[ -x $native || -x $launcher ]] || command -v jetbrains-toolbox >/dev/null; then installed=1; fi
if [[ $LB_MODE == check ]]; then
    [[ $installed == 1 ]] || lb_die 'Toolbox não encontrado no perfil/PATH.'
    lb_msg "Executável do perfil: $native; inicializador: $launcher."
    lb_finish 'Diagnóstico local; abrir a GUI é necessário para validar funcionamento e autoatualização.'
    exit 0
fi
lb_select_action "$installed"
if [[ $LB_ACTION == keep ]]; then lb_finish 'Toolbox mantido. Atualizações são feitas pela interface Toolbox.'; exit 0; fi
# Não substituir arquivos do próprio atualizador nem suas IDEs/configurações.
if [[ -x $native ]]; then
    lb_die 'Toolbox já inicializado no perfil. Atualize pela interface; este script não sobrescreve seu atualizador.'
fi
if command -v jetbrains-toolbox >/dev/null && [[ ! -x $launcher ]]; then
    lb_die 'Instalação externa encontrada. Migração exige análise; instalação existente foi preservada.'
fi
case ${LB_VERSION:-stable} in latest|stable|'') ;; lts) lb_die 'Toolbox não oferece canal LTS.';; *) [[ $LB_VERSION =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || lb_die 'Versão inválida.';; esac
lb_warn 'LMDE/Cinnamon não consta na lista atual de desktops/distribuições suportados pela JetBrains; teste gráfico pendente.'
# ──────────────────────────────────────────────────────────────────────
# ETAPA 2 — Preparar dependências oficiais Debian
# ──────────────────────────────────────────────────────────────────────
lb_step 'Preparar dependências oficiais Debian'
lb_apt_update
lb_apt_install ca-certificates curl python3 tar libxi6 libxrender1 libxtst6 mesa-utils libfontconfig1 libgtk-3-bin dbus-user-session libxcb-keysyms1
lb_temp
# ──────────────────────────────────────────────────────────────────────
# ETAPA 3 — Resolver versão e verificar o download oficial
# ──────────────────────────────────────────────────────────────────────
lb_step 'Resolver versão e verificar o download oficial'
selector='latest=true'
case ${LB_VERSION:-stable} in latest|stable|'') ;; *) selector="version=$LB_VERSION";; esac
lb_download "https://data.services.jetbrains.com/products/releases?code=TBA&type=release&$selector" "$LB_TMP/release.json"
python3 - "$LB_TMP/release.json" "${LB_VERSION:-stable}" "$LB_ARCH" > "$LB_TMP/selection" <<'PY'
import json,re,sys
from urllib.parse import urlparse
releases=json.load(open(sys.argv[1]))['TBA']
releases=[r for r in releases if r['type']=='release' and (sys.argv[2] in ('stable','latest','') or r['version']==sys.argv[2])]
if not releases: raise SystemExit('Versão final não encontrada')
r=releases[0]; d=r['downloads']['linuxARM64' if sys.argv[3]=='arm64' else 'linux']
if not re.fullmatch(r'[0-9.]+',r['build']): raise SystemExit('Build inválido')
for key in ('link','checksumLink'):
    u=urlparse(d[key])
    if u.scheme!='https' or u.hostname!='download.jetbrains.com' or not u.path.startswith('/toolbox/'): raise SystemExit('Origem inesperada')
print(r['build']); print(d['link']); print(d['checksumLink'])
PY
mapfile -t selection < "$LB_TMP/selection"
[[ ${#selection[@]} == 3 ]] || lb_die 'Catálogo incompleto.'
build=${selection[0]}
lb_msg "Versão resolvida: $build. Instalação pessoal; atualização pela própria Toolbox."
lb_download "${selection[1]}" "$LB_TMP/toolbox.tar.gz"
lb_download "${selection[2]}" "$LB_TMP/checksum"
hash=$(awk 'NR==1 {print $1}' "$LB_TMP/checksum")
[[ $hash =~ ^[0-9a-fA-F]{64}$ ]] || lb_die 'SHA-256 oficial inválido.'
printf '%s  %s\n' "$hash" "$LB_TMP/toolbox.tar.gz" | sha256sum --check --status || lb_die 'Download corrompido; anterior preservado.'
lb_msg 'SHA-256 conferido contra referência HTTPS JetBrains; não é assinatura independente.'
# O filtro data do Python rejeita dispositivos e links fora do destino.
# Links internos legítimos do fornecedor são preservados; nunca extrair como root.
# ──────────────────────────────────────────────────────────────────────
# ETAPA 4 — Extrair com segurança e preparar inicializador pessoal
# ──────────────────────────────────────────────────────────────────────
lb_step 'Extrair com segurança e preparar inicializador pessoal'
mkdir "$LB_TMP/extract"
python3 - "$LB_TMP/toolbox.tar.gz" "$LB_TMP/extract" <<'PY'
import tarfile,sys,pathlib
with tarfile.open(sys.argv[1]) as t:
    for m in t.getmembers():
        p=pathlib.PurePosixPath(m.name)
        if p.is_absolute() or '..' in p.parts or m.isdev(): raise SystemExit('Membro inseguro no arquivo')
        tarfile.data_filter(m,sys.argv[2])
    t.extractall(sys.argv[2],filter='data')
PY
mapfile -t bins < <(find "$LB_TMP/extract" -type f -path '*/bin/jetbrains-toolbox')
[[ ${#bins[@]} == 1 && -x ${bins[0]} ]] || lb_die 'Binário esperado ausente/ambíguo.'
release_dir=$(dirname -- "$(dirname -- "${bins[0]}")")
bootstrap="$HOME/.local/share/JetBrains/Toolbox-bootstrap/releases"
mkdir -p "$bootstrap" "$HOME/.local/bin"
# Cada preparação tem destino exclusivo. Builds anteriores permanecem para retorno.
destination=$(mktemp -d "$bootstrap/$build.XXXXXXXX")
cp -a "$release_dir/." "$destination/"
[[ -x $destination/bin/jetbrains-toolbox ]] || lb_die 'Cópia do binário falhou.'
lb_backup "$launcher"
link_tmp=$(mktemp -d "$HOME/.local/bin/.toolbox-link.XXXXXXXX")
ln -s "$destination/bin/jetbrains-toolbox" "$link_tmp/jetbrains-toolbox"
mv -Tf -- "$link_tmp/jetbrains-toolbox" "$launcher"
rmdir "$link_tmp"
[[ -x $launcher ]] || lb_die 'Inicializador inválido; restaure a cópia anterior.'
lb_finish "Preparação validada em $destination. Abra $launcher sem sudo para concluir, criar menu e testar atualização. IDEs são escolhidas na interface."
