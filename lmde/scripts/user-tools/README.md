# Ferramentas de uso geral — LMDE 7

Esta categoria preserva a separação de dev-tools. As duas categorias usam as bibliotecas de ../lib e são entregues juntas; copie a árvore completa. Execute como usuário normal, sem sudo bash.

## Preparação e sequência de uso

1. Use sua conta normal no LMDE 7, com Bash, acesso à internet para instalar e permissão de `sudo` quando solicitado. Os auxiliares Python precisam do Python 3 do sistema; dependências adicionais são apresentadas por cada receita.
2. Abra o terminal e entre no local onde extraiu ou clonou o projeto. Substitua o caminho abaixo pelo seu:

   ```bash
   cd "/caminho/linux-bootstrap/lmde/scripts/user-tools"
   pwd
   ls "01 - Brave.sh" ../lib/common.sh
   ```

   Esse caminho corresponde ao repositório completo. No ZIP conjunto, a pasta extraída começa em `scripts`: use o caminho real até `scripts/user-tools`, sem o segmento `lmde`. Se `cd` ou `ls` falhar, corrija o caminho antes de continuar. Preserve a pasta irmã `lib`, inclusive seus arquivos `.py`.
3. Escolha apenas o aplicativo desejado. A numeração é organizacional; não é necessário executar todos. Consulte ajuda e diagnóstico, por exemplo:

   ```bash
   bash "01 - Brave.sh" --help
   bash "01 - Brave.sh" --check
   echo $?
   ```

   `--check` não instala e pode retornar falha se o aplicativo ainda estiver ausente. Leia a mensagem: conflito de origem, assinatura inválida ou requisito incompatível precisam de revisão antes de instalar.
4. Execute a receita escolhida, leia os impactos e confirme quando solicitado:

   ```bash
   bash "01 - Brave.sh"
   echo $?
   ```

   `echo $?` deve vir imediatamente depois do script; outro comando muda esse resultado. Código zero indica término sem erro, mas algumas recusas de confirmação também retornam zero: confira o resumo para saber o que foi realizado. Código diferente de zero exige leitura da falha e dos caminhos de retorno preservados.
5. Abra o aplicativo pelo menu, sem `sudo`, e confira seu funcionamento e versão. Se o atalho não aparecer, inicie uma nova sessão e confira novamente. Volte a esta pasta para repetir `--check`. Abertura gráfica e atualização pelos botões são confirmações manuais; não foram certificadas pelos testes de preparação no Windows.

| Arquivo | Método | Guia |
|---|---|---|
| `01 - Brave.sh` | Repositório APT oficial | Navegadores APT, abaixo |
| `02 - Google Chrome.sh` | Repositório APT oficial; amd64 | Navegadores APT, abaixo |
| `03 - Chromium.sh` | APT Debian | Navegadores APT, abaixo |
| `04 - Blanc Browser.sh` | AppImage oficial, por usuário | [Aplicativos nativos](../APLICATIVOS-NATIVOS.md) |
| `05 - Flatpak.sh` | APT Debian e configuração Flathub system | Flatpak e Flathub, abaixo |
| `06 - Apps Básicos (Flatpak).sh` | Flathub system | Flatpak e Flathub, abaixo |
| `07 - yt-dlp.sh` | Preferência específica nightly → stable → Backports → Debian | [yt-dlp](YTDLP.md) |
| `08 - Discord.sh` | `.tar.gz` oficial, por usuário | [Aplicativos nativos](../APLICATIVOS-NATIVOS.md) |

## Flatpak e Flathub

O escopo aprovado é **system**, a instalação padrão em /var/lib/flatpak, disponível a todos os usuários. Dados e preferências ficam separados em ~/.var/app/ID. Instalações existentes user não são migradas nem removidas; duplicações no perfil atual geram aviso. Outros perfis não são inspecionados.

1. Consulte `bash "05 - Flatpak.sh" --help`. Execute `bash "05 - Flatpak.sh" --check` para diagnóstico local e, após revisar o resultado, `bash "05 - Flatpak.sh"` para preparar o gerenciador Debian e Flathub system. Confira `echo $?` imediatamente após cada execução.
2. Execute `bash "06 - Apps Básicos (Flatpak).sh" --app org.gimp.GIMP` para uma escolha específica. Repita --app para outras escolhas; sem esse seletor, o lote contém Zen Browser, ONLYOFFICE, GIMP, Inkscape, Scribus, Steam, Heroic e Telegram.
3. Use --check, --update ou --reinstall para consultar, atualizar ou reinstalar. No modo normal, instalações existentes são mantidas. Atualizar/reinstalar exige instalação system existente.
4. Verifique o resumo e `echo $?` imediatamente após terminar: falhas ou cancelamentos retornam 1, e o lote continua examinando as demais escolhas.
5. Confira `flatpak list --system --app --columns=application,version,origin` e abra o aplicativo pelo menu em cada conta que o utilizará. A instalação compartilhada não testa automaticamente a sessão de outros usuários.

Cada transação recebe confirmação; --yes aceita os impactos apresentados. --check usa somente informações locais, sem rede nem mudanças.

## Confiança, permissões e suporte

A definição HTTPS oficial exige a identidade primária Flathub 6E5C05D979C76DAF93C081354184DD4D907A7CAE. O remote existente precisa ter URL oficial, GPG ativo e política summary/collection válida. Divergências bloqueiam o fluxo sem sobrescrever configurações. O leitor da biblioteca identifica a chave; o Flatpak verifica criptograficamente os commits.

Antes da transação, apresentam-se versão quando publicada, commit, metadados completos, permissões e runtime. Marcações End-of-life do aplicativo/runtime bloqueiam a escolha. Consultas malsucedidas ou runtime indisponível no Flathub também bloqueiam. Ausência da marca não garante manutenção contínua. Acessos amplos home/host recebem aviso. Nenhum override é concedido.

Após instalar, origem, commit e metadados devem coincidir com a revisão. Publicação concorrente pode causar divergência e falha: examine antes de abrir o app. Dependências/extensões são resolvidas pelo Flatpak; não há auditoria completa de cada extensão nem teste funcional de interface. Não são iniciados apps nem executados rebase ou limpeza de runtimes.

Escopo system não garante sandbox forte: permissões do pacote e overrides globais/por usuário determinam o acesso efetivo. Confira:

```bash
flatpak info --system --show-permissions org.gimp.GIMP
flatpak override --system --show org.gimp.GIMP
flatpak override --user --show org.gimp.GIMP
flatpak list --system --app --columns=application,version,origin
```

As atualizações pertencem ao Flatpak/Gerenciador de aplicativos. Não existe classificação LTS universal: estas receitas usam a branch stable de cada publicação. Nova sessão pode ser necessária para integrar menus.

## Retorno e pendências

Instalação/reinstalação não faz backup dos dados pessoais. Preserve e valide os dados de cada perfil antes de mudanças relevantes. Remover aplicativo não restaura uma versão anterior; retorno de commits e restauração exigem procedimento específico.

07 - yt-dlp.sh agora usa instalação verificada e preferência nightly → stable → Backports → Debian. Consulte [YTDLP.md](YTDLP.md) para comandos, dependências e procedimento de retorno. Testes com fixtures não substituem validação real no LMDE 7 em sessões de usuários diferentes.

Referências: [CLI oficial](https://docs.flatpak.org/en/latest/flatpak-command-reference.html), [permissões](https://docs.flatpak.org/en/latest/sandbox-permissions.html), [definição Flathub](https://dl.flathub.org/repo/flathub.flatpakrepo).


## Navegadores APT

| Receita | Origem | Atualizações |
|---|---|---|
| Brave | Repositório oficial Brave; três chaves primárias permitidas, InRelease validado | APT |
| Google Chrome | Repositório oficial Google HTTPS; chave primária ativa e Release.gpg validado; amd64 | APT |
| Chromium | Debian Trixie oficial, incluindo updates/security | APT |

Use `--check` para consulta local; `--update`/`--reinstall` para ação explícita; `--version stable`, `latest` ou versão APT exata. Chromium também aceita a versão upstream quando disponível. Não há canal LTS nestas receitas. Instalação é de sistema; perfis e configurações do navegador são individuais. Não se alteram associações de navegador preferido por escolha própria do script; scripts de manutenção dos pacotes podem registrar alternativas.

Brave/Chrome baixam chaves e metadados para uma área temporária, conferem identidade e assinatura antes de gravar Signed-By e fonte. Fontes anteriores/duplicadas exigem revisão manual; não são apagadas. Chaves inesperadas, assinatura inválida, pacote de outra origem ou versão divergente bloqueiam a receita. Não execute o navegador com sudo.

Antes de instalar Chrome, a receita preserva `/etc/default/google-chrome` e define `repo_add_once=false` e `repo_reenable_on_distupgrade=false`. Isso controla o auxiliar do fornecedor para conservar a fonte assinada preparada. A origem é conferida novamente após instalar. Esses controles não desativam atualizações APT de pacotes. A validação real do comportamento do pacote no LMDE continua pendente.

Referências oficiais: [Brave Linux](https://brave.com/linux/), [chaves Google](https://www.google.com/linuxrepositories/), [postinst Chromium/Chrome](https://chromium.googlesource.com/chromium/chromium/+/HEAD/chrome/installer/linux/debian/postinst).

GeoGebra não integra o lote. Isso não desinstala cópias eventualmente existentes.

## Novos aplicativos com atualização própria

04 - Blanc Browser.sh e 08 - Discord.sh usam fontes oficiais e instalação no perfil. Consulte [Aplicativos nativos](../APLICATIVOS-NATIVOS.md) para métodos, dependências, assinatura disponível, uso, atualização e retorno. O resultado do botão de atualização será confirmado nos testes do usuário; não há atualização APT destes aplicativos.
