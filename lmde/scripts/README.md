# Instaladores LMDE 7 — pacote conjunto

O pacote conserva as categorias `dev-tools` (desenvolvimento) e `user-tools` (uso geral). Ambas usam a biblioteca irmã `lib`. Extraia tudo junto; o pacote não executa instaladores automaticamente. Os auxiliares são carregados por `source` e não devem ser executados diretamente.

1. Na cópia do repositório, entre em `lmde/scripts`. Se usar o ZIP conjunto, extraia tudo e entre em `scripts`. Preserve os subdiretórios nas duas formas de uso.
2. Leia [uso geral](user-tools/README.md) ou [desenvolvimento](dev-tools/README.md).
3. Consulte `--help` e execute `--check` no instalador escolhido. Diagnóstico não instala nem baixa arquivos.
4. Execute a mesma receita sem `--check` para instalar, ou use as ações explícitas descritas. Execute na conta normal; o próprio script chama sudo quando necessário.
5. Confira o código de saída e o resumo. Abra os aplicativos e teste uma nova sessão; para Flatpak system, confira também em outra conta.

Exemplos, a partir desta pasta:

```bash
bash "user-tools/05 - Flatpak.sh" --check
bash "user-tools/05 - Flatpak.sh"
bash "user-tools/06 - Apps Básicos (Flatpak).sh" --app org.gimp.GIMP
bash "user-tools/03 - Chromium.sh" --check
bash "dev-tools/04 - Mise.sh" --check
```

Flatpak usa instalação `--system` padrão em `/var/lib/flatpak`, disponível às contas do sistema. Dados, preferências e permissões adicionais por usuário continuam individuais. Flathub existente no perfil pessoal não é migrado/removido. Caminhos nativos e responsáveis por atualização permanecem próprios de cada método.

## Organização e dependências

| Biblioteca | Responsabilidade | Consumidores |
|---|---|---|
| common.sh | apresentação, opções, diagnóstico, confirmações, downloads, backups, APT e assinaturas | receitas revisadas, exceto Mise independente |
| apps.sh | aplicativos Debian e repositórios de fornecedores | aplicativos APT das duas categorias |
| desktop.sh + desktop.py | downloads oficiais, extração protegida, aplicativos no perfil e menu | Antigravity, Antigravity IDE, Zed, Blanc e Discord |
| flatpak.sh | Flathub system, seleção, permissões e suporte | gerenciador Flatpak e lote de aplicativos |
| languages.sh | catálogos, linguagens e seleção de escopo | seis receitas de linguagens |
| services.sh | montagens, containers e PostgreSQL | Docker, Podman e PostgreSQL |
| ytdlp.sh | canais, assinatura, runtime e instalação com retorno | yt-dlp |

Títulos possuem separadores e não recebem números. Etapas no código descrevem o fluxo de referência; na execução recebem numeração sequencial conforme o caminho efetivamente percorrido.

## Limites e receitas pendentes

`user-tools/07 - yt-dlp.sh` foi revisado com preferência nightly → stable → Backports → Debian. Consulte [o guia yt-dlp](user-tools/YTDLP.md) para opções, dependências, atualização e retorno. GeoGebra foi retirado do lote; seu log histórico permanece no relatório de retirada, fora do pacote.

`remove-tools` não faz parte do conjunto revisado, do pacote ou do conteúdo publicável. Nenhum instalador foi executado no LMDE durante esta preparação. Testes isolados de Bash no Windows não certificam APT/sqv, interfaces gráficas, serviços, permissões Unix ou integração de usuários no Linux real. Não há compatibilidade universal com outras distribuições.

Cada guia documenta as cópias de retorno criadas pela receita durante uma instalação. Restaurar arquivos não desfaz transações APT/Flatpak nem restaura dados pessoais. Os relatórios históricos de preparação são locais e não são pré-requisito de execução. Na cópia completa do repositório, o README.md da raiz traz o roteiro inicial; no ZIP, use este índice e os guias internos.

## Novos aplicativos nativos

Antigravity, Antigravity IDE e Zed ficam em dev-tools; Blanc Browser e Discord em user-tools. Fontes oficiais e instalação por usuário para preservar atualização própria. Consulte [APLICATIVOS-NATIVOS.md](APLICATIVOS-NATIVOS.md) para comandos, validações e retorno.
