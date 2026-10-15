# yt-dlp — instalação, atualização e retorno

Receita para LMDE 7 Gigi / Debian 13, como aplicativo de uso geral. Execute como usuário normal, sem sudo bash. Instalações compartilhadas usam executáveis protegidos por permissões administrativas; vídeos e configurações continuam pertencendo a cada usuário.

## Política de origem aprovada

A preferência específica desta ferramenta é **nightly → stable → Backports → Debian principal**. Essa exceção preserva a preferência Debian para as dependências, onde versões compatíveis estiverem disponíveis.

A ordem atende novas instalações. Atualizações preservam a origem e o canal já administrados. Uma origem inferior deve ser identificada antes da transação; uma falha de assinatura, hash ou identidade não pode ser contornada por fallback. Falhas de rede, limite da API e erros de autenticação também devem interromper o diagnóstico remoto, sem representar ausência de release.

Backports só pode ser usado quando já configurado; a receita não mistura Debian testing/unstable nem cria repositórios por inferência. Instalações existentes por métodos diferentes devem ser diagnosticadas e preservadas, sem remoção automática.

## Integridade e executáveis oficiais

Os canais oficiais usam repositórios yt-dlp/yt-dlp-nightly-builds e yt-dlp/yt-dlp. A versão concreta é resolvida durante a execução, sem depender de uma data fixada no script. O arquivo Linux standalone é escolhido para amd64 ou arm64, inclui Python e EJS e evita depender de linguagens pessoais gerenciadas por Mise.

O download deve ocorrer em área temporária antes de validar o manifesto SHA2-256SUMS, sua assinatura GPG e o hash do executável. A identidade primária esperada é AC0CBBE6848D6A873464AF4E57CF65933B5A7581. A chave vem da fonte oficial HTTPS; isso não representa autenticação independente do fornecedor. Assinaturas da release são distintas do selo de assinatura de um commit GitHub.

Nenhum executável candidato deve ser testado antes da verificação. Consultas de validação ignoram configurações e plugins pessoais. Cópias anteriores e releases preparadas são preservadas; não há limpeza automática de versões nem exclusão de vídeos.

## Dependências e limites

FFmpeg e ffprobe são necessários para o fluxo completo de combinação e processamento de áudio/vídeo. O suporte atual ao YouTube também exige o componente EJS e um executor JavaScript compatível. As releases Linux oficiais incluem EJS; um pacote Debian precisa ser conferido de acordo com sua composição.

Deno compatível, Node.js compatível e QuickJS são alternativas. O Node.js principal do Debian 13 consultado nesta revisão é 20, anterior ao mínimo 22 do yt-dlp atual. QuickJS 2025.04.26 do Debian atende ao requisito documentado e permite preparar uma dependência de sistema sem acoplar esta ferramenta ao Mise. Os critérios precisam ser reavaliados caso mudem em releases futuras.

Testes locais de versão/dependências não provam que qualquer site funciona. Um teste com URL envolve rede e deve ser solicitado explicitamente; não baixar mídia nem ler cookies ou configurações pessoais no diagnóstico automático. Download e processamento normal devem ser executados sem sudo.

## Referências

- [Artefatos, assinaturas e canais oficiais](https://github.com/yt-dlp/yt-dlp#installation).
- [Atualizações](https://github.com/yt-dlp/yt-dlp#update).
- [Executores JavaScript e EJS](https://github.com/yt-dlp/yt-dlp/wiki/EJS).
- [QuickJS Debian Trixie](https://packages.debian.org/trixie/quickjs).

## Como executar

1. Preserve a pasta completa de scripts. Use sua conta normal, com Bash, Python 3 do sistema, acesso à internet para instalar e permissão de `sudo` quando solicitado. Acesse o local real do projeto, substituindo o caminho do exemplo:

```bash
cd "/caminho/linux-bootstrap/lmde/scripts/user-tools"
ls "07 - yt-dlp.sh" ../lib/ytdlp.sh
```

Se o arquivo não for encontrado, corrija o caminho antes de continuar.

2. Consulte ajuda e diagnóstico local:

```bash
bash "07 - yt-dlp.sh" --help
bash "07 - yt-dlp.sh" --check
echo $?
```

Um diagnóstico de aplicativo ausente é esperado antes da primeira instalação; conflitos ou dependências incompatíveis exigem revisão. Não confunda ausência com falha de assinatura ou conflito de outra instalação.

3. Para uma instalação nova:

```bash
bash "07 - yt-dlp.sh"
echo $?
```

Confira o código imediatamente, antes de executar outro comando. Leia também o resumo: zero informa encerramento sem erro, mas uma confirmação recusada pode encerrar o fluxo sem instalar. A preferência automática começa em nightly. Fallback consulta a próxima origem apenas quando release/executável não está disponível e recebe confirmação. Ausência de manifesto/assinatura ou falha de verificação interrompe o fluxo.

4. Abra novo terminal e confirme:

```bash
command -v yt-dlp
yt-dlp --version
ffmpeg -version
ffprobe -version
```

Na instalação oficial administrada, o primeiro comando deve localizar `/usr/local/bin/yt-dlp`; em instalação APT, o caminho será o fornecido pelo pacote. Volte a `user-tools` e repita `--check`. Um alias antigo ou outro executável com precedência exige revisão. Teste seu download habitual sem `sudo` e confirme reprodução do arquivo; diagnóstico local não comprova suporte a todos os sites.

Exemplos de escolhas explícitas:

```bash
bash "07 - yt-dlp.sh" --source vendor --channel nightly
bash "07 - yt-dlp.sh" --source vendor --channel stable
bash "07 - yt-dlp.sh" --source backports --version latest
bash "07 - yt-dlp.sh" --source debian --version latest
bash "07 - yt-dlp.sh" --update
bash "07 - yt-dlp.sh" --reinstall
```

`--version AAAA.MM.DD[.BUILD]` seleciona uma tag oficial exata. Para APT, informe uma versão disponível na origem. `--version stable` representa stable oficial quando não se escolhe APT; para origem APT explícita, representa o candidato final daquela origem. Não há LTS. Uma versão exata inexistente não pode ser substituída por outra versão arbitrária.

A atualização comum preserva canal e origem. Troca explícita entre nightly e stable, dentro da instalação oficial administrada, exige revisão de impacto/possível downgrade e confirmação. Para uma instalação existente, combine `--update --channel stable` ou `--update --channel nightly`; a seleção do canal sozinha não substitui a escolha da ação. Troca entre APT e instalação manual ou migração de uma instalação externa exige procedimento separado. O script não remove aliases antigos; se os detectar, bloqueia a instalação para evitar ambiguidade.

`--js-runtime auto` procura executores globais compatíveis. Um caminho absoluto para `deno`, `node` ou `qjs` pode ser fornecido explicitamente. Se nenhum executor compatível existir, a receita pode propor QuickJS Debian, com simulação APT e confirmação. Instalações pessoais Mise não são escolhidas automaticamente para uma ferramenta compartilhada.

`--test-url https://...` solicita consulta funcional sem download de mídia. A consulta exige confirmação e ignora configurações/plugins pessoais. Não pode ser combinada com `--check`. Uma consulta de site pode falhar por mudanças do serviço, autenticação ou restrições de rede, mesmo com o executável instalado corretamente.

Após terminar, confira `echo $?`, `command -v yt-dlp` e `yt-dlp --version`; teste o uso normal sem sudo em uma nova sessão. Diagnóstico incompleto/falha retorna código diferente de zero. `--yes` aceita as transações apresentadas; não ignora conflitos nem falhas de segurança.

## Caminhos, atualização e retorno

As releases oficiais ficam em diretórios exclusivos sob `/usr/local/lib/linux-bootstrap/yt-dlp/releases`. O inicializador `/usr/local/bin/yt-dlp` aponta para a release validada e registra seu canal e versão. Ele dispensa alias e passa o executor JavaScript escolhido para o programa. Dados baixados e configurações pessoais não são movidos.

As atualizações oficiais pertencem a esta receita (`--update`); o inicializador recusa opções diretas de atualização como `-U`. Arquivos de sistema não se tornam graváveis por usuários comuns. Em instalação APT, a atualização pertence ao APT/receita; o script não instala outra cópia por cima dela.

Antes de trocar o inicializador, existe uma cópia em `~/.local/state/linux-bootstrap/retorno`, cujo `indice.tsv` relaciona o destino à cópia preservada. Releases anteriores permanecem no sistema. Se a validação imediatamente após a troca falhar, o inicializador anterior é restaurado; em primeira instalação, o inicializador recém-criado é retirado, preservando a preparação da release para inspeção.

Para retorno manual posterior, use o índice para localizar a cópia do inicializador anterior, confira sua origem e restaure-a administrativamente no destino registrado. Conserve a release para a qual ele aponta. Restaurar o inicializador não reverte dependências APT, pacote Debian ou dados pessoais. O script não limpa releases antigas automaticamente.

## Validação e pendências Linux

A preparação consultou metadados oficiais, verificou as assinaturas GPG reais dos manifestos nightly e stable e conferiu o hash de um arquivo Linux nightly. O arquivo baixado não foi executado no Windows. Testes isolados e revisão de código não substituem execução no LMDE real.

Diretórios e executores compartilhados devem pertencer ao administrador e não ser graváveis pelo grupo ou por outros usuários. Diretórios locais configurados para escrita pelo grupo `staff`, links simbólicos e executores temporários são recusados para revisão manual; a receita não muda essas permissões automaticamente.

Os caminhos, permissões administrativas, composição EJS do pacote APT, funcionamento do executor JavaScript, FFmpeg, integração em contas diferentes e download/processamento real permanecem sujeitos à validação Linux. Em APT, ausência de EJS compatível deve ser tratada como pré-requisito pendente, sem instalar componentes remotos silenciosamente nem anunciar suporte completo ao YouTube.


Testes desta implementação cobrem GPG/SHA reais e adulteração sem executar o binário Linux. A assinatura, o hash e a versão do candidato são conferidos antes da ativação; o inventário também confere o hash local registrado no inicializador. APT só prossegue com o módulo EJS disponível no Python isolado do sistema; não instala esse módulo via PyPI global nem habilita download remoto de componentes.
