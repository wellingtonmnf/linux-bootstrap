#!/usr/bin/env python3
# ══════════════════════════════════════════════════════════════════════
# BIBLIOTECAS DE INSTALAÇÃO — VALIDAÇÃO DE ARQUIVOS E MENUS NATIVOS
# ══════════════════════════════════════════════════════════════════════
# Sistema-alvo: Python 3.11+ / LMDE 7 Gigi / Debian 13.
# Finalidade: validar catálogos oficiais, tar.gz, hashes e atalhos.
# Uso: auxiliar chamado por desktop.sh; não instala nem abre aplicativos.
# Dependências: biblioteca padrão Python; nenhuma biblioteca externa.
# Organização: títulos explicativos; etapas do fluxo numeradas.
# ══════════════════════════════════════════════════════════════════════
"""Valida metadados, arquivos e atalhos das instalações desktop oficiais."""

import argparse
import json
import os
from pathlib import Path, PurePosixPath
import posixpath
import re
import sys
import tarfile
from urllib.parse import urlsplit, unquote

# ============================================================================
# Etapa 1 — Validação de formatos e origens oficiais
# ============================================================================
VERSION = re.compile(r"[0-9]+(?:\.[0-9]+){1,3}")
BLANC_REPO = "bnfy/blanc"


def fail(message):
    raise ValueError(message)


def version_selector(version, selector):
    if not VERSION.fullmatch(version):
        fail("Versão inválida")
    if selector not in ("latest", "stable") and selector.removeprefix("v") != version:
        fail("Versão publicada não corresponde à seleção")


def https_url(url):
    parsed = urlsplit(url)
    if (parsed.scheme != "https" or parsed.username or parsed.password
            or parsed.port not in (None, 443) or parsed.query or parsed.fragment
            or "\\" in url or any(ord(c) < 32 for c in url)):
        fail("URL HTTPS inválida")
    return parsed


def blanc_select(data, arch, selector):
    if arch not in ("amd64", "x86_64", "x64"):
        fail("Blanc oficial oferece Linux x64")
    if not isinstance(data, dict) or data.get("draft") is not False or data.get("prerelease") is not False:
        fail("Release deve ser pública e estável")
    tag = data.get("tag_name", "")
    version = tag.removeprefix("v")
    version_selector(version, selector)
    assets = data.get("assets")
    if not isinstance(assets, list):
        fail("Lista de assets inválida")

    def choose(predicate):
        found = [a for a in assets if isinstance(a, dict) and predicate(a.get("name", ""))]
        if len(found) != 1:
            fail("Asset oficial ausente ou ambíguo")
        asset = found[0]
        name = asset["name"]
        url = asset.get("browser_download_url", "")
        p = https_url(url)
        if p.hostname != "github.com" or unquote(p.path) != f"/{BLANC_REPO}/releases/download/{tag}/{name}":
            fail("Asset fora do repositório oficial")
        if "/" in name or "\\" in name or ".." in name:
            fail("Nome de asset inválido")
        return asset

    app = choose(lambda n: bool(re.fullmatch(r"Blanc-" + re.escape(version) + r"(?:[-.]?(?:x64|x86_64|amd64))?\.AppImage", n)))
    manifest = choose(lambda n: n == "SHA256SUMS")
    bundle = choose(lambda n: n == "SHA256SUMS.sigstore.json")
    result = dict(version=version, url=app["browser_download_url"], name=app["name"],
                  manifest_url=manifest["browser_download_url"], bundle_url=bundle["browser_download_url"])
    digest = app.get("digest")
    if digest is not None:
        if not re.fullmatch(r"sha256:[a-fA-F0-9]{64}", digest):
            fail("Digest GitHub inválido")
        result["sha256"] = digest[7:].lower()
    return result


def manifest_hash(text, asset):
    if "/" in asset or "\\" in asset or "\n" in asset:
        fail("Nome de asset inválido")
    matches = []
    for line in text.splitlines():
        match = re.fullmatch(r"(\S+) [ *](.+)", line)
        if match and match[2] == asset:
            if not re.fullmatch(r"[a-fA-F0-9]{64}", match[1]):
                fail("Hash inválido no manifesto")
            matches.append(match[1].lower())
    if len(matches) != 1:
        fail("Manifesto não contém exatamente uma entrada válida para o asset")
    return matches[0]


def discord_select(url, arch, selector):
    if arch not in ("amd64", "x86_64", "x64"):
        fail("Discord tar.gz oficial Linux é x64")
    p = https_url(url)
    if p.hostname not in ("download.discordapp.net", "cdn.discordapp.com", "dl.discordapp.net", "stable.dl2.discordapp.net"):
        fail("Origem Discord não autorizada")
    match = re.fullmatch(r"/apps/linux/([0-9]+(?:\.[0-9]+){1,3})/discord-([0-9]+(?:\.[0-9]+){1,3})\.tar\.gz", p.path)
    if not match or match[1] != match[2]:
        fail("Caminho Discord estável inválido")
    version_selector(match[1], selector)
    return dict(version=match[1], url=url, name=posixpath.basename(p.path))

# ============================================================================
# Etapa 2 — Extração segura sem permissões administrativas
# ============================================================================
def safe_extract(archive, destination):
    if hasattr(os, "geteuid") and os.geteuid() == 0:
        fail("Extração deve ocorrer como usuário comum")
    out = Path(destination)
    if out.is_symlink() or (out.exists() and (not out.is_dir() or any(out.iterdir()))):
        fail("Destino deve ser diretório vazio, sem link simbólico")
    with tarfile.open(archive, "r:*") as tar:
        members = tar.getmembers()
        names = set()
        links = {}
        for member in members:
            parts = PurePosixPath(member.name).parts
            if (not parts or member.name.startswith("/") or ".." in parts
                    or "\\" in member.name or any(ord(c) < 32 for c in member.name)):
                fail("Caminho inseguro no arquivo tar")
            name = str(PurePosixPath(member.name))
            if name in names:
                fail("Caminho duplicado no arquivo tar")
            names.add(name)
            if not (member.isfile() or member.isdir() or member.issym() or member.islnk()):
                fail("Tipo de membro tar não permitido")
            if member.issym() or member.islnk():
                target = member.linkname
                if not target or target.startswith("/") or "\\" in target:
                    fail("Destino de link inseguro")
                resolved = posixpath.normpath(posixpath.join(posixpath.dirname(name), target) if member.issym() else target)
                if resolved == ".." or resolved.startswith("../"):
                    fail("Link sai do destino de extração")
                links[name] = resolved
        # Recusa cadeias cíclicas e arquivos colocados sob um link do arquivo.
        # A checagem precede qualquer escrita, além da proteção data_filter.
        for name in names:
            parents = PurePosixPath(name).parents
            if any(str(parent) in links for parent in parents):
                fail("Membro tar localizado sob um link")
        for start in links:
            seen = set()
            target = start
            while target in links:
                if target in seen:
                    fail("Ciclo de links no arquivo tar")
                seen.add(target)
                target = links[target]
            if any(str(parent) in links for parent in PurePosixPath(target).parents):
                fail("Destino de link atravessa outro link")
        for member in members:
            tarfile.data_filter(member, str(out))
        # data_filter também resolve cadeias de links e remove bits setuid/setgid.
        out.mkdir(parents=True, exist_ok=True)
        tar.extractall(out, members=members, filter="data")

# ============================================================================
# Etapa 3 — Integração ao menu sem execução por shell
# ============================================================================
def desktop_string(value):
    if any(ord(c) < 32 for c in value):
        fail("Controle inválido no atalho")
    return value.replace("\\", "\\\\")


def desktop_entry(name, executable, icon, output, mimetypes=""):
    if not Path(executable).is_absolute():
        fail("Executável deve ter caminho absoluto")
    if not Path(icon).is_absolute() and not re.fullmatch(r"[A-Za-z0-9._-]+", icon):
        fail("Ícone deve ser caminho absoluto ou nome de tema válido")
    # Exec tem duas camadas: escaping da string desktop e do argumento citado.
    argument = executable.replace("%", "%%")
    argument = argument.replace("\\", "\\\\").replace('"', '\\"').replace("$", "\\$").replace("`", "\\`")
    command = desktop_string('"' + argument + '"')
    arguments = " --url -- %u" if name == "Discord" else " %U"
    if name == "Antigravity IDE — URL":
        arguments = " --open-url %U"
    category = "Development;IDE;" if name in ("Antigravity", "Antigravity IDE", "Antigravity IDE — URL", "Zed") else "Utility;"
    lines = ["[Desktop Entry]", "Type=Application", "Version=1.0",
             "Name=" + desktop_string(name), "Exec=" + command + arguments,
             "Icon=" + desktop_string(icon), "Terminal=false", "Categories=" + category]
    if name == "Antigravity IDE — URL":
        lines.append("NoDisplay=true")
    if mimetypes:
        if not re.fullmatch(r"(?:[A-Za-z0-9.+_-]+/[A-Za-z0-9.+_-]+;)+", mimetypes):
            fail("MimeType inválido")
        lines.append("MimeType=" + mimetypes)
    target = Path(output)
    if target.is_symlink():
        fail("Atalho de destino é um link simbólico")
    target.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("extract", "blanc-select", "manifest", "discord-select", "desktop"))
    parser.add_argument("args", nargs="+")
    ns = parser.parse_args()
    args = ns.args
    sizes = {"extract": (2,), "blanc-select": (3,), "manifest": (2,), "discord-select": (3,), "desktop": (4, 5)}
    if len(args) not in sizes[ns.command]:
        parser.error("Número incorreto de argumentos")
    try:
        if ns.command == "extract":
            safe_extract(*args)
        elif ns.command == "blanc-select":
            print(json.dumps(blanc_select(json.loads(Path(args[0]).read_text(encoding="utf-8")), *args[1:])))
        elif ns.command == "manifest":
            print(manifest_hash(Path(args[0]).read_text(encoding="utf-8"), args[1]))
        elif ns.command == "discord-select":
            print(json.dumps(discord_select(*args)))
        else:
            desktop_entry(*args)
    except (ValueError, OSError, tarfile.TarError) as error:
        print(f"desktop.py: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
