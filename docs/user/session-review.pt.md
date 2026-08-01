# Resumo da Session

O Resumo da Session é onde o BirdNET Live transforma as detecções em um registro editável.

## Como chegar até ele

O BirdNET Live abre o Resumo da Session automaticamente após concluir:

- uma Live Session
- um Point Count
- um Survey
- uma execução de Análise de arquivos

Você também pode reabrir qualquer Session salva nas [Sessões](session-library.md).

## Áreas principais

### Resumo e reprodução

O Resumo da Session combina reprodução, navegação pelo espectrograma e uma lista de espécies. Para Sessions de Survey, ele também pode mostrar o contexto mapeado.

O cabeçalho de resumo no topo da tela traz a data, o chip de localização (latitude/longitude mais um nome de local resolvido opcional quando **Configurações → Privacidade → Permitir busca de nome do local** está ativado) e — quando **Configurações → Privacidade → Permitir consulta de clima** estava ativado no momento da gravação — uma **linha de clima** abaixo da localização mostrando as condições registradas ao final da Session: uma frase curta como *"20,1 °C · Chuva leve · 3,2 m/s SO"* precedida por um ícone de clima. Toque na linha para expandir um pequeno painel listando temperatura, vento, precipitação e nebulosidade com a atribuição ao Open-Meteo. O mesmo instantâneo é refletido na exportação JSON, no bloco de metadados da Session e no relatório HTML.

A faixa do espectrograma acima do reprodutor é interativa: toque para posicionar, arraste com um dedo para percorrer a linha do tempo e **pince com dois dedos para ampliar** uma janela de tempo estreita — útil para inspecionar o tempo de chamados sobrepostos ou separar um trinado rápido. Afaste os dedos novamente para voltar à visão geral padrão de 10 segundos. O botão de reprodução no cabeçalho de uma espécie sempre escolhe o primeiro agrupamento que realmente tem um clipe gravado, de modo que o botão está disponível sempre que alguma das detecções dessa espécie puder ser reproduzida.

### Lista de espécies

As espécies são agrupadas em linhas expansíveis. Você pode inspecionar as detecções por espécie e percorrer a gravação enquanto as revisa. As linhas de agrupamento sob uma espécie expandida ficam recuadas para que o cartão da espécie pai permaneça visualmente distinto de seus filhos.

Um campo de pesquisa acima da lista filtra as espécies por nome comum ou científico, de modo que encontrar uma ave específica em uma Session com 100 espécies é uma questão de algumas teclas em vez de uma longa rolagem. O botão :material-sort: ao lado dele altera a ordem das espécies:

- **Maior confiança** (padrão) — espécies com a maior confiança em uma única detecção primeiro. Bom para triar as identificações mais certas. Ao expandir uma espécie neste modo, as detecções com clipes de áudio reproduzíveis aparecem antes das detecções sem clipe e, em seguida, por confiança.
- **Mais detecções** — espécies com a maior contagem de detecções primeiro. Bom para identificar os cantores dominantes.
- **A → Z** — em ordem alfabética por nome comum. Previsível, sensível ao idioma e fácil de percorrer quando uma Session tem muitas espécies.
- **Detetadas primeiro** — em ordem cronológica pelo horário da primeira detecção. O padrão histórico; útil ao revisar junto com a linha do tempo do espectrograma.

A ordenação escolhida persiste entre as Sessions.

### Adicionar uma espécie manualmente

O botão :material-plus-circle-outline: da barra de ferramentas abre o seletor de espécies para aves que o BirdNET não detectou. Tocar em um resultado não o insere de imediato: primeiro sobe uma folha de confirmação com a espécie escolhida e duas caixas de seleção:

- :material-ear-hearing: **Ouvida** — você ouviu a ave.
- :material-eye: **Vista** — você viu a ave.

Marque uma, ambas ou nenhuma e toque em **Adicionar**. **Cancelar** — ou deslizar para baixo — devolve você à busca, então um toque errado não custa nada. **Ouvida** vem marcada, e sua escolha permanece para a próxima espécie: registrar uma sequência de aves que você só viu exige marcar **Vista** uma única vez. Deixando as duas em branco, o registro é salvo sem tipo de observação — não como "nenhuma das duas".

A escolha fica armazenada na detecção e aparece como um pequeno ícone de orelha e/ou olho ao lado do selo de entrada manual em todos os lugares onde a detecção é exibida: cabeçalhos de espécie, linhas de agrupamento, o reprodutor de clipes e a lista do survey ao vivo. Ela também vai para as exportações: uma coluna `Evidence` em CSV e nas tabelas do Raven, um campo `evidence` em JSON e uma etiqueta no relatório HTML. A mesma folha aparece ao usar **Substituir espécie**, pré-preenchida com o que o registro já tinha.

### Ações por detecção

Em todo lugar onde uma detecção aparece — a lista de espécies, o painel do reprodutor de clipe, a lista do Survey ao vivo e os marcadores no mapa do Survey — usa-se o mesmo conjunto de ações:

- :material-check: **Confirmar** — uma marca de verificação com um toque que sinaliza uma detecção como verificada visual ou acusticamente. Os agrupamentos confirmados e os marcadores do mapa recebem uma pequena marca verde para se destacarem rapidamente, e o sinalizador acompanha todos os formatos de exportação.
- :material-dots-vertical: **Mais** — abre um menu adicional com:
    - :material-share-variant: **Compartilhar detecção** — veja *Compartilhamento* abaixo.
    - :material-swap-horizontal: **Substituir espécie** — escolhe outra espécie para esta detecção.
    - :material-delete-outline: **Excluir detecção** — remove a linha imediatamente. Uma SnackBar de desfazer aparece por alguns segundos, de modo que erros são reversíveis. Sem caixa de confirmação.
    - :material-delete-sweep-outline: **Excluir espécie** — remove de uma só vez todas as detecções dessa espécie da Session, com a mesma SnackBar de desfazer. Útil para varrer uma fonte de ruído identificada erroneamente sem precisar expandir a espécie e excluir os agrupamentos um a um.

#### Atalhos de deslize nas linhas de revisão

Na lista de espécies você também pode agir sobre uma detecção deslizando a linha na horizontal:

- deslize para a **direita** → excluir (com desfazer)
- deslize para a **esquerda** → abre a sobreposição de substituição de espécie

Os dois fundos têm cores distintas (vermelho de erro vs. azul primário), de modo que o efeito do gesto fica óbvio antes de você confirmar.

Deslizar uma linha de **cabeçalho de espécie** (para a esquerda ou para a direita) exclui de uma só vez todas as detecções dessa espécie, com a mesma SnackBar de desfazer. Útil ao triar uma Session cheia de ruído identificado erroneamente.

### Compartilhar uma única detecção

A opção :material-share-variant: **Compartilhar detecção** abre o menu de compartilhamento da plataforma com um conteúdo conciso e adequado a ferramentas de campo — nome comum e científico, confiança, carimbo de data/hora UTC em ISO 8601 e uma URI `geo:` quando a detecção tem GPS — e anexa o clipe de áudio sempre que houver um disponível. O arquivo compartilhado é nomeado `BirdNET_Live_<timestamp>_<species>.<ext>` para corresponder ao esquema da exportação ZIP.

O anexo de áudio é resolvido nesta ordem:

1. O clipe próprio da detecção armazenado no disco.
2. **Para Sessions que gravam um único arquivo contínuo**: a janela de áudio relevante é recortada da gravação em tempo real. Há suporte para gravações contínuas tanto em WAV quanto em FLAC, e o trecho é entregue no mesmo contêiner da fonte (WAV de entrada → WAV de saída, FLAC de entrada → FLAC de saída).
3. Se nenhum estiver disponível, o compartilhamento é apenas de texto — a localização e o carimbo de data/hora ainda fazem parte do conteúdo.

### Memos de voz

Você pode anexar comentários falados curtos a registros de detecção individuais:

- **Gravar**: toque no botão :material-dots-vertical: em um agrupamento de detecção e selecione **Gravar memo de voz** para abrir a caixa de diálogo de memo de voz. Toque no grande botão do microfone para iniciar a gravação. Uma forma de onda ao vivo reflete sua voz em tempo real. Toque no botão de parada ao terminar.
- **Revisar**: depois de gravado, você pode ouvir o memo usando o reprodutor embutido. Para substituí-lo, toque no botão **Gravar novamente**. Para salvá-lo, toque no botão **Salvar**.
- **Excluir**: se uma detecção já tiver um memo de voz anexado, você pode excluí-lo pelo menu adicional ou pela caixa de diálogo de memo de voz.
- **Formatos específicos da plataforma**: no Android e em outras plataformas, os memos de voz são gravados no formato AAC (`.m4a`) altamente compactado a 16 kHz. No iOS, eles usam automaticamente o formato WAV/PCM16 (`.wav`) para evitar problemas de compatibilidade do CoreAudio com as sessões de áudio ativas do aplicativo. Ambos os formatos têm suporte total no empacotamento ZIP de exportação.
- **Exportar**: ao exportar a Session como um ZIP, os memos de voz são agrupados dentro do diretório `memos/` e seus caminhos relativos são registrados nos metadados JSON e CSV.

### Mapa do percurso do Survey

As Sessions de Survey mostram um pequeno mapa embutido com o percurso GPS e os marcadores de detecção. Toque em um marcador no mapa embutido para focar uma detecção — o mapa embutido se centraliza nela. Toque no botão :material-fullscreen: **expandir** (canto superior direito do mapa embutido) para abrir o **mapa em tela cheia**; se uma detecção estava em foco, o mapa em tela cheia abre centralizado e ampliado nessa detecção para você não perder sua posição.

#### Codificação dos marcadores

- **A confiança é codificada por cores** com uma rampa segura para daltonismo: da confiança baixa → alta, vai do azul-arroxeado, passando por verde-azulado/amarelo, até o vermelho. A luminosidade da rampa muda de forma monotônica, então ela continua legível em tons de cinza e para pessoas com daltonismo vermelho-verde.
- **Detecções com áudio** mostram um anel colorido em torno da foto da espécie e um selo de reprodução no canto — toque nelas para abrir o mesmo painel de reprodutor de clipe usado nas demais telas, com confirmar, compartilhar, substituir e excluir disponíveis.
- **Detecções silenciosas** (sem clipe no disco) são renderizadas menores, esmaecidas e com um anel cinza neutro, de modo que as detecções com áudio sempre se destacam como o conteúdo principal.
- **Marcadores sobrepostos no mesmo ponto** são ordenados em profundidade por importância: destacado > com áudio > maior confiança, então um marcador silencioso de baixa confiança nunca pode encobrir uma detecção forte com áudio.
- **Abaixo do zoom 14,5**, as silhuetas reduzem-se a pontos coloridos dimensionados pela confiança, e os agrupamentos densos colapsam em uma bolha de contagem (o agrupamento é desativado no zoom 15).

#### Filtragem

O mapa em tela cheia tem um **chip de filtro** persistente fixado no canto superior direito. Toque nele para abrir o painel de filtros; o rótulo do chip sempre mostra o que está em vigor (*"Todas as espécies"*, *"Com áudio"*, *"≥ 80%"* ou o nome de uma única espécie). Filtros disponíveis:

- **Todas as detecções** (padrão).
- **Com clipe de áudio** — apenas detecções cujo clipe ainda está no disco e pode ser reproduzido.
- **Adições manuais** — apenas detecções que você adicionou no Resumo da Session (exclui as detectadas automaticamente).

Você também pode restringir as detecções por nível de confiança. O controle deslizante define o piso de confiança (começa em 10%).

Abaixo do controle deslizante de confiança há um seletor **Limitar a uma espécie** que permite reduzir o mapa a uma única espécie — útil para perguntar "onde exatamente ao longo do percurso eu ouvi o sabiá-da-mata?". Uma entrada *Todas as espécies* remove a restrição. Os filtros se combinam: por exemplo, *Com clipe de áudio* + *Sabiá-da-mata* + *> 80%* mostra apenas os marcadores reproduzíveis de sabiá-da-mata que pontuaram acima de 80%.

Quando um filtro está ativo, o título da barra de aplicativo ganha um subtítulo com a contagem de correspondências (por exemplo, *"7 detecções"*). *Repor* no painel volta ao padrão.

## Ícones da barra de ferramentas

A barra de ferramentas usa os mesmos significados de ícone descritos em [Ícones e controles](icons-and-controls.md):

- :material-plus-circle-outline: — adicionar conteúdo
- :material-undo-variant: / :material-redo-variant: — percorrer as edições
- :material-content-cut: — modo de recorte
- :material-content-save: — salvar edições
- :material-share-variant: — exportar ou compartilhar
- :material-delete-outline: — descartar a Session
- :material-play: — continuar um Survey quando essa ação estiver disponível
- :material-help-circle-outline: — abrir o painel de ajuda do Resumo da Session
- :material-tune: — abrir as Configurações

## Tarefas típicas de revisão

- conferir as detecções com a reprodução e o contexto do espectrograma
- adicionar uma espécie ou anotação
- recortar a gravação para o intervalo útil
- exportar o conjunto de resultados revisado

## Exportação

O comportamento de exportação depende das opções selecionadas nas [Configurações](settings.md). O app pode empacotar as detecções e, opcionalmente, o áudio no formato de exportação escolhido. Cada exportação inclui metadados de proveniência — a versão do app, o nome e a versão do modelo, o idioma das espécies, o carimbo de data/hora da exportação, as configurações mantidas com a Session e as opções de exportação relevantes — gravados em um arquivo lateral `<prefix>.metadata.json` (ZIP) ou em um bloco `meta` de nível superior (JSON), para que as exportações sejam autodescritivas e reproduzíveis.

O bloco `settings` da exportação JSON registra os valores que foram *efetivamente aplicados a esta Session* — sensibilidade, modo de Score Pooling e número de janelas, ganho do microfone e o corte do filtro passa-alta — e não o que estiver definido nas Configurações agora. Isso significa que você pode reproduzir um resultado meses depois, ou comparar dois Surveys, sem precisar lembrar em que posição estavam os controles quando você os executou.

Todos os carimbos de data/hora nos nomes de arquivo exportados (`BirdNET_Live_<date>_<time>_…`) e dentro dos conteúdos CSV / JSON são formatados no horário local *atual* do telefone. Os registros subjacentes são armazenados em UTC e convertidos na saída.
