> Organização atual: as bibliotecas ficam em `../lib`. Extraia o pacote conjunto e preserve a pasta `scripts` completa.

# dev-tools — LMDE 7 Gigi / Debian 13

Revisão aplicada em 14/10/2026. Alvo inicial: Steady Rock, Debian 13/Trixie, Bash, amd64. Outros sistemas não foram certificados. A maioria admite arm64, mas a preparação fnm é somente amd64 e os serviços seguem o desenho real do Steady.

**Leve a pasta `scripts` completa, mantendo `dev-tools`, `user-tools` e a biblioteca irmã `lib`.** Os auxiliares concentram validação APT, assinaturas, preservação e interpretação dos catálogos. Não execute `../lib/*.sh` diretamente. O script mise é independente desses auxiliares.

## 1. Preparação e uso

1. Entre na conta normal do LMDE instalado. Tenha Bash, acesso à internet para instalar e permissão para usar `sudo` quando solicitado. Não use `sudo bash` para iniciar os scripts. Os auxiliares Python precisam do Python 3 do sistema; dependências adicionais são apresentadas por cada receita.
2. No terminal, acesse a pasta real do projeto. Substitua `/caminho/linux-bootstrap` pelo local onde você o extraiu ou clonou:

   ```bash
   cd "/caminho/linux-bootstrap/lmde/scripts/dev-tools"
   pwd
   ls "01 - Git.sh" ../lib/common.sh
   ```

   Esse caminho corresponde ao repositório completo. No ZIP conjunto, a pasta extraída começa em `scripts`: use o caminho real até `scripts/dev-tools`, sem o segmento `lmde`. Se `cd` ou `ls` falhar, corrija o caminho antes de continuar. Não copie somente um instalador para outra pasta.
3. Consulte ajuda e diagnóstico da ferramenta escolhida, por exemplo:

   ```bash
   bash "01 - Git.sh" --help
   bash "01 - Git.sh" --check
   echo $?
   ```

   `--check` não baixa pacotes nem modifica configuração. Falta de ferramenta ou requisito retorna código diferente de zero. Diagnósticos Docker/PostgreSQL podem usar sudo para consultas ao serviço; Podman evita comandos que inicializem armazenamento.

4. Leia os requisitos específicos abaixo e execute apenas a ferramenta desejada, sem `--check`, para instalar:

   ```bash
   bash "01 - Git.sh"
   echo $?
   ```

   Execute `echo $?` imediatamente após o script: outro comando sobrescreve esse resultado. Zero indica que o fluxo encerrou sem erro; algumas recusas de confirmação também encerram com zero, portanto leia o resumo para distinguir cancelamento, manutenção e instalação. Se já existe, a execução interativa permite manter/atualizar/reinstalar; sem terminal, mantém por padrão, a menos que uma ação ou versão tenha sido indicada explicitamente.
5. Abra um novo terminal e confirme o programa, por exemplo `command -v git` e `git --version`. Para aplicações gráficas, abra pelo menu sem `sudo`; confira versão e atualização na interface. Volte a esta pasta para repetir `--check`. Erros diferentes de zero, assinatura inválida, serviço inativo ou versão inesperada exigem revisão antes de continuar. Uma preparação de pacote não comprova abertura gráfica, novo terminal ou persistência após reiniciar.

**A numeração organiza os arquivos; não é um instalador em lote.** Docker, Podman e PostgreSQL têm pré-condições próprias. Consulte a seção de serviços antes de executá-los e escolha apenas uma alternativa por linguagem.

Opções comuns (cada script aceita apenas as aplicáveis): `--check`, `--update`, `--reinstall`, `--version SELETOR`, `--source debian|backports|vendor`, `--scope none|user|project`, `--project DIRETORIO`, `--vendor FORNECEDOR`, `--yes`. O mise tem interface própria: consulte [MISE.md](MISE.md).

`--yes` aceita transações propostas; primeiro examine seus resultados. Não habilita automaticamente migração, remoção de conflitos, criação de partições ou atualização de bancos sem requisitos adicionais.

## 2. Ferramentas e responsabilidades

| Scripts | Origem e local | Atualização |
|---|---|---|
| Mise | Release oficial assinada; `~/.local/bin/mise` | Script explícito ou mecanismo do mise |
| Git | Debian por padrão; Backports apenas quando solicitado e já configurado; caminhos APT | APT |
| Docker + Compose | Docker oficial para trixie; componentes APT e volumes aprovados | APT |
| pyenv + Python | Gerenciador pessoal `~/.pyenv`, Python adicional em suas versões | pyenv; gerenciador atualizado explicitamente |
| fnm + Node.js | Perfil `~/.local/share/fnm` ou diretório já configurado | fnm; Node/npm confrontados com archive oficial assinado |
| SDKMAN + Java | Perfil `~/.sdkman` ou diretório já configurado | SDKMAN; fornecedor selecionável |
| Python/Node.js/Java (Mise) | Exigem mise instalado previamente; diretórios do gerenciador | Mise |
| PostgreSQL + pgAdmin | PostgreSQL Debian por padrão, PGDG opcional; pgAdmin oficial separado | APT; mudança de série/retorno dos bancos é procedimento separado |
| Warp/Sublime/VS Code | Repositórios oficiais, caminhos definidos pelos pacotes | APT |
| Toolbox | Preparação em `~/.local/share/JetBrains/Toolbox-bootstrap/releases`; primeira abertura inicializa `~/.local/share/JetBrains/Toolbox` | Próprio Toolbox; script não sobrescreve atualizador já inicializado |
| Insomnia | `.deb` de release oficial Kong, caminhos definidos pelo pacote | Nova execução/download; pacote isolado não adiciona repositório |
| Podman | Debian oficial, modo administrativo; componentes APT | APT |
| Antigravity/Antigravity IDE/Zed | Fontes oficiais; instalação pessoal e atalhos em `~/.local` | Mecanismo do aplicativo; resultado na interface ainda pendente de teste |

Temurin e IntelliJ via Toolbox são pontos de partida, não escolhas permanentes ou restrições. Código aberto orienta recomendações quando solicitadas. O script Toolbox não instala uma IDE automaticamente; ela é escolhida na interface. Nomes de diretórios do fornecedor são preservados.

## 3. Versões e linguagens

Seletores resolvidos na execução: `latest`, versão final mais recente; `stable`, canal estável da origem; `lts`, somente quando há classificação oficial vigente. Não há LTS oficial equivalente em Python/PostgreSQL/Git. Sem informação confiável, o script interrompe a resolução em vez de inventar um status.

Node consulta índice oficial e calendário de suporte; Java usa catálogo e metadados Adoptium para latest/LTS Temurin. Outros fornecedores Java continuam disponíveis por `--vendor` e versão explícita/stable/latest; LTS automática fora Temurin exige implementação de sua política, sem substituição silenciosa. Python usa catálogo de versões finais do gerenciador; não rotula uma versão como LTS. Catálogos Python/Java não certificam automaticamente o suporte de todas as versões explícitas antigas.

Escolha **um dos dois caminhos por linguagem**; não execute ambos como um roteiro obrigatório. Seleção ativa de gerenciadores pode competir no PATH, a lista de locais onde o shell procura comandos. Configuração persistente interrompe diante de alternativa já ativa para que a precedência seja resolvida conscientemente. `--scope none` instala/valida sem alterar seleção pessoal/projeto.

| Linguagem | Com Mise já instalado | Alternativa com gerenciador próprio |
|---|---|---|
| Python | `05.1 - Python (Mise).sh` | `05.2 - pyenv + Python.sh` |
| Node.js | `06.1 - Node.js (Mise).sh` | `06.2 - fnm + Node.js.sh` |
| Java | `07.1 - Java (Mise).sh` | `07.2 - SDKMAN + Java.sh` |

Exemplos a partir de `dev-tools`:

```bash
# Primeiro, preparar somente mise; depois abrir novo terminal.
bash "04 - Mise.sh"

# Alternativas mise. Estes comandos NÃO instalam o gerenciador.
bash "05.1 - Python (Mise).sh" --version stable --scope none
bash "06.1 - Node.js (Mise).sh" --version lts --scope user
bash "07.1 - Java (Mise).sh" --version lts --vendor temurin --scope user

# Alternativas tradicionais — escolher em vez das correspondentes acima.
bash "05.2 - pyenv + Python.sh" --version stable --scope none
bash "06.2 - fnm + Node.js.sh" --version lts --scope user
bash "07.2 - SDKMAN + Java.sh" --version lts --vendor temurin --scope user
```

Para um projeto, use `--scope project --project /caminho/existente`. As escolhas pessoais/projeto são preservadas antes de alteração. Os scripts não removem versões antigas e restauram uma versão substituída quando sua reinstalação falha. Diretórios incompletos são preservados para revisão.

Execute uma linha escolhida por vez e confira `echo $?` imediatamente. Depois abra novo terminal; consulte `python --version`, `node --version`/`npm --version` ou `java -version`/`javac -version`, conforme a linguagem. Em `--scope none`, a versão recém-instalada pode não ser a versão ativa do terminal; use o diagnóstico do script para conferir a instalação. Em escopo `project`, entre no projeto antes de conferir a seleção local. Os exemplos acima são alternativas, não uma sequência para copiar inteira.

Git mostra a versão concreta disponível na origem escolhida. Para pareamento, use `--version X.Y.Z`; se essa versão não existir, interrompe sem trocar origem. `--source backports` requer Backports configurado e autenticado previamente. A filtragem inicial aceita os servidores Debian padrão `deb.debian.org` e `security.debian.org`; outros espelhos exigem adaptação explícita. A igualdade entre máquinas não é mantida automaticamente sob atualizações independentes.

Git separa configuração pessoal: `--configure`, opcionalmente `--git-name`/`--git-email` para execução sem terminal. Dados não são reproduzidos no resumo; configuração anterior é preservada.

## 4. Assinaturas, downloads e erros

- APT externo: fingerprints primários permitidos, validação GPG dos metadados, `Signed-By` restrito e atualização APT com erro estrito. Não usa `trusted=yes`, `apt-key` ou ignora assinatura. Fonte externa duplicada exige revisão antes de continuar.
- Warp usa `Release` e `Release.gpg`; os demais repositórios usam `InRelease`. Sublime permite o conjunto de chaves observado em transição. Fingerprint inesperado, revogação/expiração ou assinatura inválida interrompe a instalação; não atualizar a lista de confiança automaticamente.
- APT simula a transação, apresenta impacto e usa `--no-remove`. Conflitos são informados; pacotes não são removidos silenciosamente.
- Mise: manifesto minisign assinado e SHA-256.
- Node: manifesto GPG assinado, fingerprints oficiais permitidos, hash do archive e comparação do binário e árvore npm efetivamente instalados. Há um download extra do archive para a validação.
- fnm, Toolbox e Insomnia: hash publicado pela API/site oficial HTTPS, arquitetura/artefato e versão conferidos. Esse hash demonstra integridade contra a referência recebida; não é assinatura independente. Ausência de hash/artefato adequado interrompe a receita.
- pyenv: Git/HTTPS oficial e checksums do python-build. SDKMAN: bootstrap HTTPS e verificação de checksum habilitada, dependente dos metadados do fornecedor. Não declarar assinatura independente desses instaladores/JDKs como validada.
- Temporários exclusivos e backups antes de escrita/substituição. Falhas não recebem resumo de sucesso; pode haver preparação parcial, indicada na saída. Nenhum procedimento instala todos os programas automaticamente.

## 5. Serviços e dados

Os scripts não criam, formatam ou montam volumes. Antes de instalar, Docker/Podman exigem montagem exata ext4 gravável, origem de bloco e capacidade alinhada ao planejamento (tolerância de 16 MiB). Exibem identidade do dispositivo para conferência.

1. Prepare e valide as montagens pelo procedimento de armazenamento da máquina antes de usar essas duas receitas. Não tente resolver falhas de montagem formatando ou alterando o disco por inferência.
2. Execute `bash "02 - Docker + Docker Compose.sh" --check` ou `bash "03 - Podman.sh" --check` e leia o diagnóstico. Em instalação nova, pacote ausente é esperado; montagem incorreta precisa ser corrigida antes da instalação. Confira `echo $?` após cada comando separadamente.
3. Só então execute a receita escolhida sem `--check`. Docker e Podman não dependem de Mise nem exigem instalar o outro. As reservas abaixo são específicas do planejamento do Steady; outros layouts exigem adaptação explícita.

| Dados pesados | Caminho padrão considerado | Destino aprovado Steady |
|---|---|---|
| Docker | `/var/lib/docker` | Mesmo caminho, volume 30 GiB |
| Containerd | `/var/lib/containerd` | Mesmo caminho, volume 35 GiB |
| Podman administrativo | `/var/lib/containers/storage` | Mesmo caminho, volume 65 GiB |

Drop-ins systemd associam os serviços às montagens, antes de instalar pacotes que podem iniciar automaticamente. Docker valida destinos reais e serviços; Podman valida o graphRoot administrativo. Os testes funcionais criam volume exclusivo, escrevem uma amostra e leem em um segundo container. Volume, amostra e imagens ficam preservados, com nome/caminho apresentados. Containers de teste são efêmeros. Não há limpeza automática de dados anteriores.

O grupo Docker só é alterado mediante `--add-user-to-docker-group` e confirmação de seu poder administrativo. Podman é usado com sudo; a API não é ativada sem necessidade. Os guards systemd protegem a API Podman; para uso da CLI, conferir a montagem antes de executar.

PostgreSQL permite `--source debian` (padrão) ou `--source vendor` (PGDG); `--no-pgadmin` mantém a instalação do banco separada da interface. Um servidor existente não muda de série automaticamente.

Para uma instalação nova, consulte `bash "08 - PostgreSQL + pgAdmin4.sh" --help` e depois `--check`. Se houver clusters ou dados existentes, interrompa o roteiro de instalação nova e siga as exigências de manutenção abaixo. Para instalar somente o servidor, use `bash "08 - PostgreSQL + pgAdmin4.sh" --source debian --no-pgadmin`, seguido imediatamente de `echo $?`. Ao terminar, repita o diagnóstico com as mesmas escolhas e consulte `pg_lsclusters`; se escolheu pgAdmin, abra-o pelo menu e teste a conexão. Serviço instalado não comprova conexão, autenticação ou restauração de backup.

**Atualização/reinstalação de bancos existentes:** somente após backup com restauração validada e plano de retorno. Exige `--database-backup ARQUIVO --backup-validated`; a declaração é do usuário, não comprovação automática. O script verifica arquivo existente/legível/não vazio, identifica clusters e recusa backup dentro do próprio diretório de dados. Indique a série já instalada por `--version N` para manutenção nessa série. Pacotes podem reiniciar serviços. Restore/downgrade não são automatizados.

## 6. Retorno

As receitas comuns guardam arquivos em `~/.local/state/linux-bootstrap/retorno/<execução>/`, com `indice.tsv` relacionando cópia e caminho original. Diretório privado (modo 700), cópias mantidas e marcadores `.ausente` identificam destinos novos. Mise usa seu diretório de retorno próprio. Linguagens preservam instalações substituídas em `retorno-instalacoes`; Toolbox mantém preparações anteriores.

1. Leia o índice/mensagens e identifique a execução exata. Compare arquivos atuais e anteriores, preservando alterações posteriores.
2. Restaure somente arquivos dessa execução e seus modos/propriedade originais. Links devem ser restaurados como links. Para um destino antes ausente, retirar apenas o arquivo criado, após confirmar identidade e conteúdo.
3. Depois de restaurar fontes/chaves, valide atualização autenticada APT; depois de restaurar drop-ins systemd, recarregue a configuração. Para Bash, confira sintaxe e abra novo terminal.
4. Restauração de arquivos não desfaz uma transação de pacotes. Versões antigas podem deixar de estar disponíveis; downgrade de bancos requer procedimento próprio. Dependências e dados persistentes não são removidos automaticamente.
5. Preserve todas as cópias até a validação técnica e funcional. Se faltar evidência de retorno seguro, interrompa a manutenção e trate a recuperação separadamente.

## 7. Validação e limites

As receitas passaram por verificação de sintaxe Bash e testes isolados no Windows/Git Bash durante a preparação em 14/10/2026. Foram examinados controle de fluxo, versões, alternativas, erros, verificações criptográficas e preservação. Simulações no Windows não comprovam permissões Unix nem implantação Linux. Esses testes e seus relatórios históricos não fazem parte deste conjunto de uso.

Não foram executados instaladores no Steady, pacotes APT, containers ou bancos reais. GUI, dependências Linux, APT/sqv, persistência após boot e restauração real são pendentes. Testes não provam compatibilidade com outras distribuições. ShellCheck não disponível no ambiente desta revisão; análise estática realizada por leitura e `bash -n`.

Para validar sua instalação, use os diagnósticos e as confirmações manuais deste guia. Não é necessário obter relatórios do trabalho de preparação para executar as receitas.

## Cabeçalhos e apresentação das etapas

Todos os instaladores e as bibliotecas têm cabeçalhos explicativos com título, finalidade, sistema-alvo, uso e dependências. Títulos usam separadores duplos e não recebem números; etapas usam separadores simples e numeração. Nos arquivos, os números identificam a sequência de referência do fluxo (nas bibliotecas, por função); na execução, o contador acompanha somente as etapas efetivamente percorridas, incluindo auxiliares APT. Etapas condicionais podem ser dispensadas sem deixar lacunas na saída.

As três receitas de linguagens via Mise descrevem o fluxo no próprio cabeçalho e apontam para `lang_mise` em `../lib/languages.sh`. Conserve `dev-tools`, `user-tools` e a biblioteca irmã `lib` dentro de `scripts`. Bibliotecas possuem cabeçalhos de funções e não são instaladores independentes.

## Novos aplicativos com atualização própria

12 - Antigravity.sh, 13 - Antigravity IDE.sh e 15 - Zed.sh usam fontes oficiais e instalação no perfil. Consulte [Aplicativos nativos](../APLICATIVOS-NATIVOS.md) para métodos, dependências, assinatura disponível, uso, atualização e retorno. O resultado do botão de atualização será confirmado nos testes do usuário; não há atualização APT destes aplicativos.
