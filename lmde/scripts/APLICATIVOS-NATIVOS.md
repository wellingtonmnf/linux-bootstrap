# Aplicativos nativos com fontes oficiais

Decisão de 14/10/2026: Antigravity, Antigravity IDE e Discord usam tar.gz oficial; Zed usa o instalador oficial; Blanc usa AppImage oficial. Nenhum repositório de terceiros é adicionado. As receitas são preparadas para LMDE 7 / Debian 13, com instalação na conta normal.

| Receita | Categoria | Arquivos da instalação | Atualização pretendida |
|---|---|---|---|
| 12 - Antigravity.sh | dev-tools | ~/.local/share/antigravity | aplicativo |
| 13 - Antigravity IDE.sh | dev-tools | ~/.local/share/antigravity-ide | aplicativo; pendente teste |
| 15 - Zed.sh | dev-tools | ~/.local/zed.app, caminho do instalador oficial | aplicativo |
| 04 - Blanc Browser.sh | user-tools | ~/.local/share/blanc/Blanc.AppImage | aplicativo |
| 08 - Discord.sh | user-tools | ~/.local/share/discord (bootstrap); cliente atual pode usar ~/.config/discord | bootstrap oficial no formato novo; pendente teste |

Esta instalação é **por usuário**, inclusive para Blanc e Discord. O escopo system aprovado para o lote Flatpak continua próprio daquele lote. Arquivos pertencem à conta, permitindo escrita pelo atualizador. Não executar a interface com sudo, mudar a propriedade para root nem tornar uma instalação compartilhada gravável por todos. Não há sandbox Flatpak; a receita não desativa o sandbox do navegador/Electron e retira bits setuid/setgid dos arquivos extraídos. Se o sandbox nativo falhar, interrompa e traga o diagnóstico; não adicione `--no-sandbox`.

## Uso e etapas

1. Preserve a árvore completa de scripts, inclusive lib/desktop.sh e lib/desktop.py. Consulte `--help` e esta página.
2. Execute, por exemplo, `bash "dev-tools/15 - Zed.sh" --check`. Ausência, conflito ou configuração incompleta retorna erro. O diagnóstico é somente local, sem downloads ou transações APT.
3. Feche o aplicativo antes de instalar, atualizar ou reinstalar. Para instalar: `bash "user-tools/08 - Discord.sh"`. As etapas mostram diagnóstico, dependências, versão, download, validação, publicação e resultado, com confirmações.
4. Use `--version stable` ou `latest` para resolver a publicação estável disponível na execução. Não há LTS nestas receitas. Versões numéricas exatas são aceitas quando disponibilizadas pelo endpoint oficial; para Google, o catálogo atual só permite a release atual. Uma versão ausente gera erro, sem troca silenciosa por latest.
5. Se já instalado, a execução normal permite manter/atualizar/reinstalar; sem interação, mantém por padrão. `--update` e `--reinstall` substituem somente esta instalação gerenciada e preservam a anterior. `--yes` aceita as transações apresentadas; consulte antes sem essa opção.
6. Confira `echo $?`, execute `--check`, abra pelo menu e teste login, links e botão de atualização. No Zed, confira também `vulkaninfo --summary`. Dependências, driver e funcionamento gráfico precisam de teste real.

Os cinco usam inicializadores em ~/.local/bin e menus em ~/.local/share/applications. Antigravity IDE tem um atalho adicional oculto para seu protocolo, com --open-url; Discord usa os argumentos --url -- do atalho oficial. Não alteram associações padrão do navegador, perfis, tokens ou preferências do aplicativo. O atualizador pode alterar o conteúdo instalado e sua versão; o registro em ~/.local/state/linux-bootstrap/desktop contém versão/hash **do momento da instalação**, não uma afirmação da versão atual. O script não executa o binário baixado para conferir versão. Não instala atualizações agendadas.

Instalações externas no PATH, pacotes APT e Flatpaks conflitantes, destinos desconhecidos, links em diretórios pais e registros inconsistentes bloqueiam substituições. Não é uma varredura de todo o disco nem de outros perfis. O detector de processos não substitui fechar o aplicativo: uma AppImage pode executar através de montagem temporária, fora do caminho instalado.

## Fontes e validação

- Google: [download oficial](https://antigravity.google/download?platform=linux) fornece os links atuais. Os scripts exigem domínios, caminhos, produto e arquitetura corretos, sem adivinhar versões. O site [declara atualização automática](https://antigravity.google/releases), mas a receita não garante o resultado no Linux. Na pesquisa de 14/10, metadados do IDE continham um endpoint de atualização placeholder; validar o botão é especialmente necessário.
- Discord: [endpoint oficial estável](https://discord.com/api/download?platform=linux&format=tar.gz), com conferência do destino CDN e versão concreta. O tar atual (1.0.162 observado em 14/10) traz launcher shell e updater_bootstrap: na primeira abertura, o bootstrap oficial obtém o cliente em XDG_CONFIG_HOME/discord, normalmente ~/.config/discord. Isso é o caminho do fornecedor, preservado pela receita. A versão selecionada identifica o tar/bootstrap e não fixa a versão do cliente baixado depois pelo atualizador. O inicializador pessoal é um wrapper que executa o caminho real, preservando a localização do bootstrap; postinst.sh não é executado, pois afeta processos/AppArmor/caches de outros usuários. A receita também admite o tar antigo com ELF Discord. A instalação nativa evita limitações adicionais do Flatpak, mas não garante todos os recursos em qualquer ambiente Linux. Se o cliente solicitar outro download, `--update` prepara o tar.gz oficial novamente.
- Zed: [instalador oficial](https://zed.dev/install.sh), baixado por HTTPS e conferido com `sh -n`. A receita obtém a release estável do repositório oficial zed-industries/zed, confere o digest GitHub quando publicado, pré-valida o bundle inteiro e o entrega ao instalador através de `ZED_BUNDLE_PATH`. O instalador oficial continua responsável pela instalação no caminho nativo. A árvore do bundle deve estar inteiramente sob zed.app, evitando escrever sobre outros aplicativos em ~/.local. A instalação anterior é preservada antes da operação que remove aquela pasta.
- Blanc: [download oficial](https://blanc.day/download) e releases bnfy/blanc. O manifesto SHA256SUMS precisa ter assinatura Sigstore válida, identidade `anthony@bnfy.me` e emissor `https://github.com/login/oauth`; depois o SHA-256 da AppImage precisa coincidir. Não há fallback sem assinatura. Usa Cosign existente ou prepara temporariamente o verificador oficial sigstore-python em ambiente virtual, a partir do PyPI oficial, sem instalar módulos no Python do sistema. A versão 4.x e suas dependências são resolvidas nessa execução; o ambiente é descartado ao finalizar. A verificação pode precisar de acesso aos serviços de confiança Sigstore. [Verificação do projeto](https://github.com/bnfy/blanc/blob/main/docs/release-verification.md).

Nos tar.gz Google e Discord e no instalador Zed, não foi identificado um manifesto assinado independente usado pela receita. A origem é protegida por HTTPS; o tar é pré-validado antes da extração, rejeitando travessia, arquivos especiais e links inseguros, e o ELF principal deve corresponder à arquitetura. SHA-256 local é um registro de integridade, **não assinatura do fornecedor**. Mudanças de catálogo, redirecionamento inesperado, assinatura/hash inválido, arquivo incompleto ou estrutura inesperada interrompem a instalação.

Google/Zed admitem amd64/arm64 quando a fonte fornece; Discord/Blanc são somente amd64 nesta preparação. Dependências são pacotes Debian administrados por APT. Isso não coloca os cinco aplicativos sob atualização APT. AppImage não funciona como isolamento Flatpak; FUSE é uma dependência de execução, não uma camada de segurança equivalente.

## Retorno e limites

Antes da publicação, menu, inicializador e registro são copiados para ~/.local/state/linux-bootstrap/retorno/EXECUÇÃO, com índice de caminhos. A pasta anterior do aplicativo é movida para APP-installation no mesmo retorno; não é apagada. Em falha do instalador Zed, a pasta anterior é restaurada, e um resultado parcial é preservado. Falhas posteriores podem exigir restauração manual dos arquivos do índice.

Feche o aplicativo, identifique a execução e compare os arquivos antes de restaurar. Preserve a nova instalação em outro nome antes de devolver a pasta anterior ao caminho exato; restaure menu, link e registro daquela execução. Não restaure o link sozinho sem a pasta correspondente. Uma execução atualizada posteriormente pelo aplicativo pode conter alterações adicionais. Cópias de retorno não são backup dos dados pessoais nem desfazem dependências APT ou migração de perfis feita pelo aplicativo.

Testes com fixtures no Windows conferem fluxo e arquivos, sem executar instaladores oficiais, APT, GUI ou AppImage reais. Permissões Unix, dependências, login, integração de menu e atualizadores ainda precisam ser testados pelo usuário no LMDE. As receitas podem precisar de ajustes conforme os resultados; não há promessa de compatibilidade universal.
