#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# BIBLIOTECAS DE INSTALAÇÃO — BIBLIOTECA DE SERVIÇOS
# ══════════════════════════════════════════════════════════════════════
# Sistema-alvo: LMDE 7 Gigi / Debian 13 (Bash).
# Finalidade: Compartilhar proteção de montagens, testes de volumes e validação PostgreSQL.
# Uso: Biblioteca de funções; carregar com source, não executar diretamente.
# Dependências locais: lib/common.sh (carregar antes desta biblioteca).
# Organização: títulos sem número; etapas executadas com numeração sequencial.
# Notas específicas:
# Auxiliares específicos dos serviços. Requer common.sh.
# ══════════════════════════════════════════════════════════════════════


# ──────────────────────────────────────────────────────────────────────
# svc no language scope (svc_no_language_scope)
# ──────────────────────────────────────────────────────────────────────
svc_no_language_scope() {
    [[ $LB_SCOPE == none && -z $LB_PROJECT ]] || lb_die 'Serviços APT não aceitam escopo de usuário/projeto nem --project.'
}


# ──────────────────────────────────────────────────────────────────────
# svc container volume test (svc_container_volume_test)
# ──────────────────────────────────────────────────────────────────────
svc_container_volume_test() {
    local engine=$1 expected_root=$2 volume mounted actual existing
    volume="linux-bootstrap-validation-$(date +%s)-$RANDOM"
    existing=$(sudo "$engine" volume ls --format '{{.Name}}')
    if grep -Fx "$volume" <<< "$existing" >/dev/null; then
        lb_die "Nome de volume já existe: $volume. Nenhum dado será gravado nele. Execute novamente."
    fi
    lb_msg "Teste persistente: $engine; novo volume exclusivo $volume."
    actual=$(sudo "$engine" volume create --label linux-bootstrap.validation=storage "$volume")
    [[ $actual == "$volume" ]] || lb_die "Não foi possível confirmar o volume criado: $actual"
    mounted=$(sudo "$engine" volume inspect --format '{{.Mountpoint}}' "$volume")
    [[ $mounted == "$expected_root/"* ]] || lb_die "Volume de teste está fora do destino aprovado: $mounted"
    lb_msg "Amostra preservada em $mounted. Em caso de falha, confira este volume antes de removê-lo manualmente."
    sudo "$engine" run --rm --volume "$volume:/check" docker.io/library/busybox:stable sh -c 'printf "%s\\n" linux-bootstrap-storage-check > /check/amostra.txt'
    actual=$(sudo "$engine" run --rm --volume "$volume:/check:ro" docker.io/library/busybox:stable cat /check/amostra.txt)
    [[ $actual == linux-bootstrap-storage-check ]] || lb_die 'Amostra persistente não corresponde ao conteúdo gravado.'
    lb_msg "Persistência conferida entre dois containers. Volume $volume, amostra e imagem preservados; remoção somente manual."
}


# ──────────────────────────────────────────────────────────────────────
# svc mount (svc_mount)
# ──────────────────────────────────────────────────────────────────────
svc_mount() {
    local path=$1 gib=$2 source bytes expected
    lb_require_mount "$path"
    source=$(findmnt -n -o SOURCE --mountpoint "$path")
    [[ $source == /dev/* && $source != *'['* ]] || lb_die "Origem não é uma partição simples: $source"
    bytes=$(lsblk -bdno SIZE "$source")
    [[ $bytes =~ ^[0-9]+$ ]] || lb_die "Não foi possível ler a capacidade de $source."
    expected=$((gib * 1024 * 1024 * 1024))
    (( bytes >= expected - 16777216 && bytes <= expected + 16777216 )) ||
        lb_die "$path: esperado ${gib} GiB; origem tem $bytes bytes. Confira o plano e a identidade do volume."
    lsblk -o NAME,SIZE,FSTYPE,LABEL,UUID,MODEL,SERIAL "$source"
}


# ──────────────────────────────────────────────────────────────────────
# svc mount guard (svc_mount_guard)
# ──────────────────────────────────────────────────────────────────────
svc_mount_guard() {
    local unit=$1 paths=$2 file
    lb_temp
    file="$LB_TMP/$unit-mounts.conf"
    printf '[Unit]\nRequiresMountsFor=%s\n' "$paths" > "$file"
    local path
    for path in $paths; do printf 'AssertPathIsMountPoint=%s\n' "$path" >> "$file"; done
    lb_write_file "$file" "/etc/systemd/system/$unit.d/20-linux-bootstrap-mounts.conf" 0644 system
    sudo systemctl daemon-reload
}

# Cada versão deve existir na origem pedida; não confiar no candidato global.

# ──────────────────────────────────────────────────────────────────────
# svc versions (svc_versions)
# ──────────────────────────────────────────────────────────────────────
svc_versions() {
    local package=$1 origin=$2
    apt-cache madison "$package" | LB_ORIGIN="$origin" awk -F '|' '
      BEGIN {origin=ENVIRON["LB_ORIGIN"]}
      $3 ~ origin {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}' | sort -Vu
}


# ──────────────────────────────────────────────────────────────────────
# svc version (svc_version)
# ──────────────────────────────────────────────────────────────────────
svc_version() {
    local package=$1 origin=$2 selector=$3 versions version chosen=''
    versions=$(svc_versions "$package" "$origin")
    [[ -n $versions ]] || lb_die "Nenhuma versão de $package na origem selecionada."
    while IFS= read -r version; do
        if [[ $selector == latest || $selector == stable || $selector == "$version" ]]; then
            if [[ -z $chosen ]] || dpkg --compare-versions "$version" gt "$chosen"; then chosen=$version; fi
        fi
    done <<< "$versions"
    [[ -n $chosen ]] || lb_die "Versão $selector indisponível de $package. Disponíveis: $versions"
    printf '%s\n' "$chosen"
}


# ──────────────────────────────────────────────────────────────────────
# svc install (svc_install)
# ──────────────────────────────────────────────────────────────────────
svc_install() {
    if [[ $LB_ACTION == reinstall ]]; then
        lb_apt_install --reinstall "$@"
    else
        lb_apt_install "$@"
    fi
}


# ──────────────────────────────────────────────────────────────────────
# svc package version (svc_package_version)
# ──────────────────────────────────────────────────────────────────────
svc_package_version() {
    local package=$1 wanted=$2 actual
    lb_check_package "$package" || lb_die "Pacote ausente: $package"
    actual=$(dpkg-query -W -f='${Version}' "$package")
    [[ $actual == "$wanted" ]] || lb_die "$package instalado em $actual; esperado $wanted."
}


# ──────────────────────────────────────────────────────────────────────
# svc pg require backup (svc_pg_require_backup)
# ──────────────────────────────────────────────────────────────────────
svc_pg_require_backup() {
    local file=$1 validated=$2
    [[ -n $file && $validated == 1 ]] || lb_die 'Manutenção de PostgreSQL existente exige --database-backup ARQUIVO e --backup-validated. Faça backup, teste a restauração e prepare retorno em procedimento separado antes de executar.'
    [[ -f $file && -r $file && -s $file ]] || lb_die 'Backup indicado deve ser um arquivo existente, legível e não vazio. Nenhum banco será alterado.'
    lb_msg "Backup declarado validado pelo usuário: $file. Esta checagem não substitui teste de restauração."
}


# ──────────────────────────────────────────────────────────────────────
# svc pg confirm maintenance (svc_pg_confirm_maintenance)
# ──────────────────────────────────────────────────────────────────────
svc_pg_confirm_maintenance() {
    local major=$1 version=$2 file=$3 rows row_major cluster port state owner data log canonical_file canonical_data
    svc_pg_require_backup "$file" "$BACKUP_VALIDATED"
    command -v pg_lsclusters >/dev/null || lb_die 'Não é possível identificar clusters existentes: pg_lsclusters ausente.'
    rows=$(pg_lsclusters --no-header)
    canonical_file=$(realpath -e -- "$file")
    # ──────────────────────────────────────────────────────────────────────
    # ETAPA 1 — Clusters afetados pela manutenção PostgreSQL $major
    # ──────────────────────────────────────────────────────────────────────
    lb_step "Clusters afetados pela manutenção PostgreSQL $major"
    while read -r row_major cluster port state owner data log; do
        [[ -n $row_major && $row_major == "$major" ]] || continue
        canonical_data=$(realpath -e -- "$data")
        [[ $canonical_file != "$canonical_data" && $canonical_file != "$canonical_data/"* ]] || lb_die 'Backup não pode estar dentro do diretório do cluster que será atualizado.'
        lb_msg "$row_major/$cluster: estado $state; porta $port; proprietário $owner; dados $data."
    done <<< "$rows"
    lb_warn 'Pacotes podem reiniciar clusters. Restauração, verificação do conteúdo do backup e plano de retorno permanecem procedimentos próprios; o script não os executa.'
    lb_confirm "Confirmar $LB_ACTION do PostgreSQL $major para o pacote $version, com backup validado e retorno preparado?" || lb_die 'Manutenção cancelada; bancos preservados.'
}


# ──────────────────────────────────────────────────────────────────────
# svc pg validate (svc_pg_validate)
# ──────────────────────────────────────────────────────────────────────
svc_pg_validate() {
    local wanted=${1:-} expected=${2:-} rows version cluster port state owner data log count=0 actual upstream
    command -v pg_lsclusters >/dev/null || lb_die 'pg_lsclusters ausente; servidor PostgreSQL não validado.'
    rows=$(pg_lsclusters --no-header)
    while read -r version cluster port state owner data log; do
        [[ -n $version ]] || continue
        [[ -z $wanted || $version == "$wanted" ]] || continue
        count=$((count + 1))
        [[ $owner == postgres ]] || lb_die "Cluster $version/$cluster tem proprietário inesperado: $owner."
        [[ $state == online ]] || lb_die "Cluster $version/$cluster está $state. Não será iniciado automaticamente."
        actual=$(sudo -u postgres /usr/bin/psql --cluster "$version/$cluster" -X -A -t -v ON_ERROR_STOP=1 -d postgres -c 'SHOW server_version;')
        [[ $actual == "$version".* ]] || lb_die "Servidor inesperado no cluster $version/$cluster: $actual"
        if [[ -n $expected ]]; then
            upstream=${expected#*:}; upstream=${upstream%%-*}
            [[ $actual == "$upstream" || $actual == "$upstream "* ]] || lb_die "Servidor respondeu $actual; pacote selecionado requer $upstream."
        fi
        lb_msg "Cluster $version/$cluster respondeu SQL: versão $actual; dados $data; porta $port."
    done <<< "$rows"
    (( count > 0 )) || lb_die 'Nenhum cluster correspondente. Configure-o separadamente; bancos não serão criados ou migrados pelo script.'
}


# ──────────────────────────────────────────────────────────────────────
# svc pg supported (svc_pg_supported)
# ──────────────────────────────────────────────────────────────────────
svc_pg_supported() {
    python3 - "$1" <<'PY'
from html.parser import HTMLParser
from pathlib import Path
import sys
class Releases(HTMLParser):
    def __init__(self):
        super().__init__(); self.rows=[]; self.row=[]; self.cell=None
    def handle_starttag(self, tag, attrs):
        if tag=='tr': self.row=[]
        if tag in ('td','th'): self.cell=[]
    def handle_data(self, data):
        if self.cell is not None: self.cell.append(data)
    def handle_endtag(self, tag):
        if tag in ('td','th') and self.cell is not None:
            self.row.append(''.join(self.cell).strip()); self.cell=None
        if tag=='tr' and len(self.row)>=5 and self.row[0].isdigit() and self.row[2]=='Yes':
            self.rows.append(self.row)
p=Releases(); p.feed(Path(sys.argv[1]).read_text())
if not p.rows: sys.exit('Não foi possível reconhecer a política oficial de suporte PostgreSQL.')
for row in p.rows: print(row[0]+'|'+row[4])
PY
}
