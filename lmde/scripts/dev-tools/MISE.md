> Organização atual: as bibliotecas ficam em `../lib`. Extraia o pacote conjunto e preserve a pasta `scripts` completa.

# Mise — Steady Rock / LMDE 7 Gigi

Script: [04 - Mise.sh](04%20-%20Mise.sh). Preparação exclusiva do gerenciador, com integração ao Bash. Python, Node.js e Java agora possuem scripts alternativos próprios, descritos no [README](README.md). As receitas com pyenv/fnm/SDKMAN são alternativas, não uma continuação automática do mise.

## Uso no computador Linux

1. Entre na conta normal do LMDE instalado e abra o Bash. Tenha acesso à internet e permissão de `sudo` para dependências ausentes. Preserve a árvore completa de `scripts`. Acesse a pasta real do projeto, substituindo o caminho do exemplo:

   ```bash
   cd "/caminho/linux-bootstrap/lmde/scripts/dev-tools"
   ls "04 - Mise.sh"
   ```

   Se o arquivo não for encontrado, corrija o caminho antes de continuar.
2. Consulte ajuda e estado, sem alterações:

   ```bash
   bash "04 - Mise.sh" --help
   bash "04 - Mise.sh" --check
   echo $?
   ```

   Código zero: executável pessoal e linha de ativação encontrados. Código 1: preparação incompleta ou problema apresentado na tela. Este diagnóstico não comprova a ativação de um novo terminal.

3. Prepare o mise:

   ```bash
   bash "04 - Mise.sh"
   echo $?
   ```

   Confira o código imediatamente: outro comando altera `$?`. Zero indica término sem erro; leia também o resumo para confirmar se houve instalação, manutenção ou cancelamento. Não use `sudo bash`. O script usa sudo apenas para instalar dependências ausentes pelo APT. Não é necessário tornar o arquivo executável para esses comandos.

4. Abra um **novo terminal Bash** e confira:

   ```bash
   command -v mise
   mise --version
   mise doctor
   ```

   O caminho deve corresponder a `~/.local/bin/mise`. O diagnóstico deve indicar `activated: yes`; resolva erros antes de instalar linguagens. O script valida o binário e a sintaxe da integração, mas não muda o terminal que o chamou. Para repetir `--check` nesse novo terminal, volte à pasta `dev-tools` e use o mesmo comando da etapa 2.

5. Quando quiser atualizar apenas o mise:

   ```bash
   bash "04 - Mise.sh" --update
   echo $?
   ```

   A execução normal mantém a versão existente. Com latest/stable, atualização explícita preserva versões iguais ou mais recentes que a release selecionada; uma versão exata permite escolher outra release conscientemente. `--reinstall` força substituição da versão selecionada com retorno preservado. Nenhuma dessas ações atualiza linguagens.

## Comportamento e impacto

- Alvo inicial: LMDE 7 Gigi, Debian 13/Trixie, Bash e arquitetura x86_64 do Steady. O código também admite arm64 e derivadas Debian 13, com suporte ainda não testado. Outras bases precisam de adaptação.
- Binário pessoal: `~/.local/bin/mise`; ativação acrescentada uma única vez ao `~/.bashrc`.
- Método: executável oficial da release estável selecionada no GitHub no momento de execução. Não fixa hoje a versão que será instalada futuramente.
- Antes de executar o binário baixado, autentica o manifesto com a chave pública oficial minisign e verifica SHA-256 do arquivo. Falha interrompe a instalação.
- Pode instalar `curl`, `ca-certificates` e `minisign` pelo APT se ausentes; só atualiza índices quando há dependências a instalar. Não adiciona repositórios.
- Não instala linguagens, não escreve `mise.toml`, não altera configurações de projetos, não remove pyenv/fnm/SDKMAN e não executa hooks de projeto na validação.
- Se encontra outro mise no PATH, outra linha de ativação ou destino ambíguo, interrompe com explicação. Essas situações precisam de revisão, sem migração automática.
- Falhas retornam código diferente de zero. Se ocorrerem depois da instalação do binário, pode haver preparação parcial: conferir mensagem e cópias preservadas. Retorno é manual.
- Execute uma instância por vez. Os scripts de linguagem reconhecem o mise previamente instalado e falham com orientação se a preparação estiver incompleta.

## Retorno

Antes de substituir um binário ou modificar o `.bashrc`, o script guarda os arquivos anteriores em um diretório exclusivo sob `~/.local/state/linux-bootstrap/mise/`. O caminho aparece na saída. Arquivos `*-ausente.txt` registram quando o destino não existia.

1. Identifique a cópia correspondente à execução que deseja desfazer. Examine-a e compare o `.bashrc` atual com o salvo; preserve mudanças feitas posteriormente.
2. Se há `mise` na cópia, restaure-o em `~/.local/bin/mise` e confira `--version`. Se há `mise-ausente.txt`, a instalação era nova: retire somente o executável criado depois de confirmar o alvo. Não remova o diretório de dados do mise ou linguagens por inferência.
3. Se há `bashrc`, restaure seu conteúdo apenas se não houver alterações posteriores a preservar. Para `.bashrc` que já era um link, mantenha o link e restaure o conteúdo do alvo. Alternativamente, remova apenas o comentário e a linha de ativação acrescentados por esta execução.
4. Se há `bashrc-ausente.txt`, retire apenas o bloco criado; só retire o arquivo inteiro se ele continuar contendo exclusivamente esse bloco.
5. Abra novo terminal e confira sintaxe/comportamento. Preserve a cópia até concluir a validação. Dependências APT permanecem instaladas; não há remoção automática.

## Validação realizada em 14/10/2026

Sintaxe e fluxos de instalação, diagnóstico, atualização, falha e preservação foram examinados por testes isolados em Git Bash/Windows. Os testes históricos não são requisito de uso e não integram este conjunto publicável. Os limites gerais estão no [README](README.md).

Os testes usam identificação Linux, downloads, verificação minisign e executável mise simulados; SHA-256 e controle de fluxo Bash são reais. Não certificam a assinatura de uma release real, acesso ao GitHub, instalação APT, compatibilidade binária no FX-8300 ou ativação no Cinnamon/LMDE. Nenhuma instalação real foi executada.

Pendentes no Steady: instalação inicial, novo terminal, diagnóstico, segunda execução e atualização real. Não há garantia de compatibilidade com todas as distribuições Debian.

Referências oficiais: [download e verificação](https://mise.jdx.dev/installing-mise.html), [ativação Bash](https://mise.jdx.dev/shell-setup.html), [minisign no Debian 13](https://packages.debian.org/trixie/minisign).
