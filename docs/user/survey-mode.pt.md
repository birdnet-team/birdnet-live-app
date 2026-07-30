# Modo Survey

O Modo Survey é o fluxo de trabalho baseado em percurso para Surveys móveis de longa duração.

## Como abrir

Na tela de Início, toque no cartão **Modo Survey** com o ícone :material-routes:.

## Fluxo de configuração

A configuração do Survey é um assistente de cinco etapas.

### 1. Detalhes

Você pode inserir:

- nome do Survey
- ID do transecto
- nome do observador
- GPS, coordenadas manuais ou nenhum local de partida

Esta etapa também disponibiliza o seletor de mapa, atualiza o GPS quando você volta das telas de permissão do sistema e mostra o lembrete de permissão de GPS em segundo plano quando necessário. Um cartão de clima está disponível na mesma área de localização. Se o acesso ao clima estiver desativado, ele solicita o consentimento de **Permitir consulta de clima**; uma vez ativado, ele apresenta uma prévia do local apenas com um ícone de clima, a temperatura e o vento. O mesmo instantâneo em cache do Open-Meteo é reutilizado quando o Survey é salvo.

### 2. Parâmetros

Esta etapa contém parâmetros específicos do Survey, como:

- seleção de microfone
- taxa de inferência
- limiar de confiança
- intervalo GPS
- duração máxima
- modo de gravação
- contexto do clipe para a gravação somente de detecções
- modo de amostragem de detecções
- limite Top N por espécie quando a amostragem é limitada

#### Amostragem de detecções

Um Survey longo pode produzir milhares de detecções, e salvar um clipe de áudio para cada uma delas ocupa rapidamente o armazenamento. A amostragem de detecções controla **quais clipes são mantidos no disco** — *os próprios registros de detecção são sempre mantidos*, de modo que o registro completo da Session permanece intacto, independentemente do modo. Os registros cujo áudio foi descartado simplesmente não têm clipe reproduzível no Resumo da Session.

Há três modos disponíveis:

| Modo | O que faz |
|---|---|
| **Todas** | Mantém todos os clipes. Maior uso de disco. Recomendado para Surveys curtos ou quando você quer o áudio de cada detecção para análise posterior. |
| **Top N** | Mantém apenas os **N clipes de maior confiança por espécie**. Os demais clipes são excluídos conforme o Survey avança. O N padrão é 10, configurável de 1 a 50. |
| **Smart** | O mesmo limite de N por espécie do Top N, **mais** a distribuição espacial: se uma nova detecção cair no mesmo "ponto" de um clipe já mantido (dentro de ~500 m e ~2 min um do outro), apenas a de maior confiança mantém seu clipe. Isso evita que um cantor estacionário monopolize todos os N espaços e direciona os clipes mantidos para cobrir todo o transecto. |

O limite N é **por espécie, não global** — se você registrar 10 sabiás e 10 tentilhões, mantém 20 clipes. Não há limite geral para o número de clipes que um Survey pode produzir.

No modo Smart, se faltar GPS em uma detecção, a verificação de mesmo ponto recorre a uma janela apenas de tempo (~2 min). Com GPS disponível, a distância e o tempo devem se sobrepor para que duas detecções contem como o mesmo ponto.

### 3. Alertas de espécies

Notificações no estilo push que disparam no meio do Survey quando algo digno de nota é detectado. Escolha um destes:

- **Desativado** — sem alertas (padrão).
- **Primeira na Session** — um alerta na primeira vez que cada espécie é ouvida durante este Survey.
- **Primeira vez** — alerta apenas quando o aplicativo encontra uma espécie pela primeiríssima vez em todas as suas Sessions (um alerta de "lifer"). Apoiado por um histórico vitalício de espécies preenchido automaticamente a partir das suas Sessions existentes na primeira inicialização.
- **Rara neste local** — alerta quando a probabilidade do geomodelo para o local atual está abaixo de um limiar configurável. Uma leitura ao vivo sob o controle deslizante explica exatamente o que o valor atual irá disparar (por exemplo, *"Alerta sobre espécies com menos de 5% de probabilidade neste local."*).
- **Lista de observação** — alerta apenas sobre espécies que você adicionou a uma lista personalizada salva. A própria etapa do assistente permite criar novas listas de observação, editar as existentes em um editor de tela cheia dedicado com taxonomia pesquisável e *Importar do arquivo* (qualquer `.txt`/`.csv` simples de nomes científicos), e excluir listas das quais você não precisa mais.

Um controle deslizante de *Confiança mínima* fica abaixo do seletor de modo e tem como piso automático o limiar de confiança da sua Session (os alertas nunca são mais sensíveis que as próprias detecções). Uma seção **Avançado** expõe controles de frequência — uma janela de carência inicial, um intervalo mínimo rígido entre quaisquer dois alertas e um limite móvel por minuto, com agrupamento opcional dos alertas excedentes em uma única notificação de resumo — tudo com seletores de chip de um toque. Na primeira vez que você muda para um modo diferente de Desativado, o assistente solicita a permissão de notificação do Android por você.

### 4. Dicas de campo

Uma breve lista de verificação antes do início, dentro do fluxo de configuração.

### 5. Pronto

A tela de pronto resume a configuração do Survey ativo antes de você começar com :material-play:.

## Painel do Survey ao vivo

A tela do Survey ao vivo tem três abas principais, além de uma lista de detecções recentes.

### Barra superior

- :material-stop: — encerra o Survey
- :material-timer: — tempo decorrido
- :material-help-circle-outline: — abre o painel de ajuda do Survey
- :material-tune: — abre as configurações do Survey

### Abas

- :material-map-outline: — mapa do percurso e detecções mapeadas
- :material-equalizer: — espectrograma
- ícone de gráfico — estatísticas de resumo e detalhamento por espécie

### Estatísticas e detecções

Abaixo do conteúdo da aba, o painel do Survey mostra uma barra de estatísticas e uma lista de detecções recentes. Tocar em uma detecção abre a sobreposição de detalhes da espécie.

Cada linha de detecção também expõe as mesmas ações por detecção usadas no [Resumo da Session](session-review.md): uma marca de verificação :material-check: **Confirmar** com um toque e um menu adicional :material-dots-vertical: **Mais** com **Compartilhar detecção** e **Excluir detecção** (com SnackBar de desfazer) — para que você possa validar, compartilhar ou remover um acerto ruidoso durante a captura, em vez de esperar a revisão pós-Session.

As mesmas ações estão disponíveis no **mapa do percurso ao vivo**: toque em um marcador de detecção para abrir o painel do reprodutor de clipe com confirmar, compartilhar e excluir. O compartilhamento durante um Survey funciona mesmo quando você optou por uma única gravação WAV contínua em vez de clipes por detecção — a janela de áudio relevante é recortada do arquivo em andamento em tempo real. Consulte [Resumo da Session → Compartilhar uma única detecção](session-review.md#compartilhar-uma-unica-deteccao) para detalhes.

### Registrar uma observação

O botão :material-plus-circle-outline: do survey ao vivo abre um pequeno menu com **Adicionar espécie** e **Adicionar nota**. **Adicionar espécie** abre o mesmo seletor usado em [Session Review](session-review.md#adicionar-uma-especie-manualmente), escolha uma espécie, depois marque :material-ear-hearing: **Ouvida** e/ou :material-eye: **Vista** na folha de confirmação e toque em **Adicionar**. O registro recebe o carimbo de tempo daquele momento e a posição GPS atual, e aparece imediatamente na lista de detecções e no mapa da rota, com o selo manual e os ícones de orelha / olho correspondentes.

Memos de voz estão ausentes aqui de propósito: o microfone está ocupado com a gravação do próprio survey. Anexe-os em Session Review depois que o survey terminar.

## Operação em segundo plano

O Modo Survey mantém uma notificação persistente em primeiro plano visível durante a gravação, para que o Android não suspenda o pipeline de áudio. A notificação se expande para mostrar:

- o tempo decorrido, a contagem de detecções, a contagem de espécies e a distância percorrida, e
- as **três espécies únicas mais recentes** com sua confiança e um carimbo de data/hora relativo (`agora mesmo`, `há 42 s`, `há 5 min`, `há 2 h`).

A notificação — título, detecções recentes e rodapé de estatísticas — é totalmente traduzida para o idioma selecionado do aplicativo e usa o mesmo idioma das espécies e as mesmas preferências de *Mostrar nomes científicos* dos cartões no aplicativo.

Os alertas de espécies (quando ativados) aparecem em um canal de notificação separado do Android para que você possa silenciar os alertas de forma independente da notificação silenciosa de gravação contínua. O ícone de alerta corresponde ao ícone da notificação em primeiro plano (uma ave monocromática), e o corpo dos alertas mostra apenas o *motivo* — *"Primeira detecção deste Survey"*, *"Na sua lista de observação"*, *"Detectado neste local com menos de 4% de probabilidade"* — deixando o nome da espécie no título da notificação em negrito, onde o Android o exibe maior.

Quando você **retoma** um Survey inacabado a partir das Sessões, o pipeline de alertas é rearmado com as suas preferências de notificação *atuais* — não as que estavam configuradas no dia em que você iniciou o Survey. Desative os alertas (ou altere o modo, a lista de observação ou a frequência) antes de tocar em Retomar, e o Survey retomado respeitará as novas configurações imediatamente.

## Revisão no mapa

A visualização do mapa do Survey em tela cheia (o botão :material-fullscreen: no Resumo da Session) abre um reprodutor de clipe quando você toca em um marcador. A linha de transporte tem botões de retroceder e avançar ao lado do controle de reprodução — eles percorrem as detecções em ordem cronológica, mas **apenas as visíveis no momento no mapa**, de modo que qualquer filtro ativo de espécie, confiança ou chip de modo restringe a lista de reprodução correspondente. Os botões ficam esmaecidos na primeira/última detecção da lista filtrada.

## Após parar

O BirdNET Live salva o Survey concluído e abre o [Resumo da Session](session-review.md).
