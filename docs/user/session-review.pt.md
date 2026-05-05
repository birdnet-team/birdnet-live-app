# Revisão da sessão

A revisão da sessão é onde o BirdNET Live transforma as detecções em um registro editável.

## Como você alcança isso

BirdNET Live abre a Revisão da Sessão automaticamente após concluir:

- uma sessão ao vivo
- uma contagem por pontos
- uma pesquisa
- uma execução de análise de arquivo

Você também pode reabrir qualquer sessão salva na [Biblioteca de Sessões](session-library.md).

## Áreas Principais

### Resumo e reprodução

Session Review combina reprodução, navegação por espectrograma e uma lista de espécies. Para sessões de pesquisa também pode mostrar o contexto mapeado.

### Lista de espécies

As espécies são agrupadas em linhas expansíveis. Você pode inspecionar as detecções por espécie e percorrer a gravação enquanto as revisa.

### Mapa de rastreamento de pesquisa

As sessões de pesquisa mostram um pequeno mapa embutido da trilha GPS e marcadores de detecção. Toque nele para abrir um **mapa em tela cheia** com os mesmos dados.

A barra de aplicativos do mapa em tela cheia tem um botão :material-filter-list-outlined: **filter** que abre uma planilha para restringir quais marcadores são mostrados. Filtros disponíveis:

- **Todas as detecções** (padrão).
- **Com clipe de áudio** — apenas detecções cujo clipe ainda está no disco e pode ser reproduzido.
- **Alta confiança** — apenas detecções com confiança igual ou superior a 80%.
- **Adições manuais** — apenas as detecções que você adicionou na Revisão da Sessão (excluindo as detectadas automaticamente).

Abaixo do seletor de modo há um seletor **Limite às espécies** que permite reduzir o mapa para uma única espécie - útil para perguntar "onde exatamente ao longo da rota eu ouvi o tordo?". Uma entrada *Todas as espécies* elimina a restrição de espécies. Os dois filtros combinam: por ex. *Com clipe de áudio* + *Wood Thrush* mostra apenas os marcadores Wood Thrush reproduzíveis.

Quando um filtro está ativo, o título da barra de aplicativos ganha uma legenda de contagem de correspondências (por exemplo, *"7 detecções"*) e o botão de filtro mostra um pequeno ponto. *Reset* na planilha retorna ao padrão.

## Ícones da barra de ferramentas

A barra de ferramentas usa os mesmos significados dos ícones descritos em [Ícones e controles](icons-and-controls.md):

- :material-plus-circle-outline: - adicionar conteúdo
- :material-undo-variant: / :material-redo-variant: — percorrer as edições
- :material-content-cut: - modo de corte
- :material-content-save: — salvar edições
- :material-share-variant: — exportar ou compartilhar
- :material-delete-outline: — sessão de descarte
- :material-play: — continue uma pesquisa quando essa ação estiver disponível
- :material-help-circle-outline: — abra a folha de ajuda da Revisão da Sessão
- :material-tune: - abra Configurações

## Tarefas típicas de revisão

- verificar as detecções em relação ao contexto de reprodução e espectrograma
- adicione uma espécie ou anotação
- cortar a gravação para o intervalo útil
- exportar o conjunto de resultados revisado

## Exportar

O comportamento da exportação depende das opções selecionadas em [Configurações](settings.md). O aplicativo pode empacotar detecções e, opcionalmente, áudio no formato de exportação escolhido. Cada exportação agora vem com metadados completos de proveniência - a versão do aplicativo, nome e versão do modelo, localidade da espécie, carimbo de data / hora da exportação e um instantâneo de todas as configurações no momento da exportação - gravados em um arquivo lateral `<prefix>.metadata.json` (ZIP) ou em um bloco `meta` de nível superior (JSON) para que as exportações sejam autodescritivas e reproduzíveis.
