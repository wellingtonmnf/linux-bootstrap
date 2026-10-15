#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# FERRAMENTAS DE DESENVOLVIMENTO — INSOMNIA
# ══════════════════════════════════════════════════════════════════════
# Sistema-alvo: LMDE 7 Gigi / Debian 13 (Bash).
# Finalidade: Selecionar o pacote oficial, verificar integridade e instalar pelo APT.
# Uso: Receita de instalação; executar como usuário normal, sem sudo bash.
# Dependências locais: ../lib/common.sh, ../lib/apps.sh
# Organização: títulos sem número; etapas executadas com numeração sequencial.
# Notas específicas:
# LMDE 7 Gigi / Debian 13. .deb oficial Kong, validado antes do APT.
# Não confundir DEBIAN_FRONTEND com bloqueio de scripts de manutenção.
# ══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/apps.sh"
lb_init 'Insomnia' "$@"
lb_assert_no_extra
[[ ${LB_SCOPE:-none} == none ]] || lb_die 'Pacote Insomnia usa escopo de sistema; não usar --scope.'
[[ -z ${LB_SOURCE:-} || $LB_SOURCE == vendor ]] || lb_die 'Insomnia usa release oficial Kong (--source vendor).'
# ──────────────────────────────────────────────────────────────────────
# ETAPA 1 — Detectar instalação e escolher ação
# ──────────────────────────────────────────────────────────────────────
lb_step 'Detectar instalação e escolher ação'
installed=0
if lb_check_package insomnia; then installed=1; fi
if [[ $LB_MODE == check ]]; then lb_app_validate insomnia insomnia; lb_finish 'Diagnóstico local; teste gráfico pendente.'; exit 0; fi
lb_select_action "$installed"
if [[ $LB_ACTION == keep ]]; then lb_app_validate insomnia insomnia; lb_finish 'Instalação mantida.'; exit 0; fi
case ${LB_VERSION:-stable} in latest|stable|'') endpoint=latest;; lts) lb_die 'Insomnia não publica canal LTS.';; *) [[ $LB_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || lb_die 'Versão inválida.'; endpoint="tags/core%40$LB_VERSION";; esac
# ──────────────────────────────────────────────────────────────────────
# ETAPA 2 — Preparar download oficial
# ──────────────────────────────────────────────────────────────────────
lb_step 'Preparar download oficial'
lb_apt_update
lb_apt_install ca-certificates curl python3
lb_temp
lb_download "https://api.github.com/repos/Kong/insomnia/releases/$endpoint" "$LB_TMP/release.json"
python3 - "$LB_TMP/release.json" > "$LB_TMP/selection" <<'PY'
import json,re,sys
from urllib.parse import urlparse
r=json.load(open(sys.argv[1]))
if r.get('draft') or r.get('prerelease'): raise SystemExit('Release não final')
m=re.fullmatch(r'core@(\d+\.\d+\.\d+)',r.get('tag_name',''))
if not m: raise SystemExit('Tag inválida')
v=m[1]
a=[a for a in r['assets'] if re.fullmatch(r'Insomnia.Core-'+re.escape(v)+r'\.deb',a['name'],re.I)]
if len(a)!=1: raise SystemExit('Artefato Debian ausente ou ambíguo')
a=a[0]; u=urlparse(a['browser_download_url'])
if u.scheme!='https' or u.hostname!='github.com' or not u.path.startswith('/Kong/insomnia/releases/download/'): raise SystemExit('Origem inesperada')
digest=a.get('digest','')
if not re.fullmatch(r'sha256:[0-9a-f]{64}',digest): raise SystemExit('Release sem SHA-256 publicado; revisão manual necessária')
print(v);print(a['browser_download_url']);print(digest[7:])
PY
mapfile -t selection < "$LB_TMP/selection"
[[ ${#selection[@]} == 3 ]] || lb_die 'Metadados incompletos.'
version=${selection[0]}
lb_msg "Versão final selecionada: $version. Atualizações por nova execução deste script/download .deb."
lb_download "${selection[1]}" "$LB_TMP/insomnia.deb"
printf '%s  %s\n' "${selection[2]}" "$LB_TMP/insomnia.deb" | sha256sum --check --status || lb_die 'Integridade SHA-256 falhou.'
lb_msg 'Hash comparado ao digest HTTPS da release oficial; não é assinatura independente do fornecedor.'
[[ $(dpkg-deb -f "$LB_TMP/insomnia.deb" Package) == insomnia ]] || lb_die 'Nome do pacote inesperado.'
[[ $(dpkg-deb -f "$LB_TMP/insomnia.deb" Architecture) == "$(dpkg --print-architecture)" ]] || lb_die 'Arquitetura incompatível.'
[[ $(dpkg-deb -f "$LB_TMP/insomnia.deb" Version) == "$version" ]] || lb_die 'Versão do pacote diverge da release.'
# Copiar em cache de usuário legível pelo _apt; temp privado fica inacessível a _apt.
cache="$HOME/.cache/linux-bootstrap/insomnia"
mkdir -p "$cache"
artifact="$cache/insomnia-$version-$(dpkg --print-architecture).deb"
lb_write_file "$LB_TMP/insomnia.deb" "$artifact" 0644 user
# ──────────────────────────────────────────────────────────────────────
# ETAPA 3 — Instalar e validar
# ──────────────────────────────────────────────────────────────────────
lb_step 'Instalar e validar'
if [[ $LB_ACTION == reinstall ]]; then lb_apt_install --reinstall "$artifact"; else lb_apt_install "$artifact"; fi
lb_app_validate insomnia insomnia
[[ $(dpkg-query -W -f='${Version}' insomnia) == "$version" ]] || lb_die 'Versão instalada divergente.'
lb_finish "Pacote validado. Artefato preservado: $artifact. Abra a GUI; este .deb isolado não adiciona atualização via repositório APT."
