# Pesquisa

A Pesquisa é o fluxo de trabalho baseado em rota para levantamentos móveis de longa duração.

## Como abri-lo

Na tela inicial, toque no cartão **Pesquisa** com o ícone :material-routes:.

## Fluxo de configuração

A configuração da pesquisa é um assistente de cinco etapas.

### 1. Detalhes

Você pode inserir:

- nome da pesquisa
- ID do transecto
- nome do observador
- GPS, coordenadas manuais ou nenhum local de partida

Esta etapa também expõe o seletor de mapa e o lembrete de permissão do GPS em segundo plano quando necessário.

### 2. Parâmetros

Esta etapa contém parâmetros específicos da pesquisa, como:

- seleção de microfone
- taxa de inferência
- limite de confiança
- Intervalo GPS
- duração máxima
- modo de gravação
- contexto de clipe para gravação somente de detecção
- modo de amostragem de detecção
- limite de N superiores por espécie quando a amostragem é limitada

#### Amostragem de detecção

Uma pesquisa longa pode produzir milhares de detecções, e salvar um clipe de áudio para cada uma delas ocupa rapidamente o armazenamento. A amostragem de detecção controla **quais clipes são mantidos no disco** — *os próprios registros de detecção são sempre mantidos*, para que o registro completo da sessão permaneça intacto, independentemente do modo. Os registros cujo áudio foi eliminado simplesmente não possuem nenhum clipe reproduzível na Revisão da Sessão.

Três modos estão disponíveis:

| Modo | O que faz |
| --- | --- |
| **Todos** | Guarde cada clipe. A maior parte do uso do disco. Recomendado para pesquisas curtas ou quando você deseja o áudio de cada detecção para análise posterior. |
| **Melhor negro** | Mantenha apenas os **N clipes de maior confiança por espécie**. Outros clipes são excluídos à medida que a pesquisa é executada. O N padrão é 10, configurável de 1 a 50. |
| **Inteligente** | O mesmo limite por espécie de N que Top N, **mais** distribuição espacial: se uma nova detecção pousar no mesmo "ponto" de um clipe já mantido (dentro de ~ 500 m e ~ 2 min um do outro), apenas o de maior confiança mantém seu clipe. Isso evita que um cantor estacionário monopolize todos os N slots e desvie os clipes mantidos para cobrir todo o transecto. |

O limite N é **por espécie, não global** — se você registrar 10 tordos e 10 tentilhões, você mantém 20 clipes. Não há limite geral para o número de clipes que uma pesquisa pode produzir.

No modo Inteligente, se o GPS estiver faltando em uma detecção, a verificação no mesmo local retornará para uma janela somente de tempo (~2 min). Com o GPS disponível, a distância e o tempo devem se sobrepor para que duas detecções contem como o mesmo local.

### 3. Alertas de espécies

Notificações push que são acionadas no meio da pesquisa quando algo digno de nota é detectado. Escolha um de:

- **Desligado** — sem alertas (padrão).
- **Primeiro na sessão** — um alerta na primeira vez que cada espécie é ouvida durante esta pesquisa.
- **Primeira vez** — alerta apenas quando o aplicativo encontra uma espécie pela primeira vez em todas as suas sessões (um alerta "lifer"). Apoiado por um histórico vitalício de espécies que é preenchido automaticamente a partir de suas sessões existentes no primeiro lançamento.
- **Raro para este local** — alerta quando a probabilidade do modelo geográfico para o local atual está abaixo de um limite configurável. Uma leitura ao vivo sob o controle deslizante explica exatamente em que o valor atual será acionado (por exemplo, *"Alertas sobre espécies com menos de 5% de probabilidade neste local."*).
- **Lista de observação** — alerta apenas sobre espécies que você adicionou a uma lista personalizada salva. A própria etapa do assistente permite criar novas listas de observação, editar as existentes em um editor de tela cheia dedicado com taxonomia pesquisável e *Importar do arquivo* (qualquer `.txt`/`.csv` simples de nomes científicos) e excluir listas que você não precisa mais.

Um controle deslizante de *Confiança mínima* fica abaixo do seletor de modo e é automaticamente direcionado ao limite de confiança da sua sessão (os alertas nunca são mais sensíveis do que as próprias detecções). Uma seção **Avançado** expõe controles de limitação — uma janela de carência de inicialização, um intervalo mínimo rígido entre quaisquer dois alertas e um limite móvel por minuto com fusão opcional de alertas de excesso de limite em uma única notificação de resumo — tudo com seletores de chip de um toque. Na primeira vez que você alterna para o modo não desligado, o assistente solicita permissão de notificação do Android para você.

### 4. Dicas de campo

Uma breve lista de verificação pré-início dentro do fluxo de configuração.

### 5. Pronto

A tela pronta resume a configuração da pesquisa ativa antes de você começar com :material-play:.

## Painel da pesquisa ao vivo

A tela da pesquisa ao vivo possui três guias principais, além de uma lista de detecções recentes.

### Barra superior

- :material-stop: — encerrar a pesquisa
- :material-timer: - tempo decorrido
- :material-help-circle-outline: — abre a folha de ajuda da pesquisa
- :material-tune: — abre as configurações da pesquisa

### Guias

- :material-map-outline: — mapa de rotas e detecções mapeadas
- :material-equalizer: - espectrograma
- ícone do gráfico — estatísticas resumidas e discriminação de espécies

### Estatísticas e detecções

Abaixo do conteúdo da guia, o painel da pesquisa mostra uma barra de estatísticas e uma lista de detecções recentes. Tocar em uma detecção abre a sobreposição de detalhes da espécie.

## Operação em segundo plano

O modo de pesquisa mantém uma notificação persistente em primeiro plano visível durante a gravação, para que o Android não suspenda o pipeline de áudio. A notificação se expande para mostrar:

- o tempo decorrido, contagem de detecção, contagem de espécies e distância percorrida, e
- as **três espécies únicas mais recentes** com sua confiança e um carimbo de data/hora relativo (`agora mesmo`, `42s atrás`, `5m atrás`, `2h atrás`).

A notificação – título, detecções recentes e rodapé de estatísticas – é totalmente traduzida para o idioma selecionado do aplicativo e usa a mesma localidade de espécie e preferências de *Mostrar nomes científicos* dos cartões no aplicativo.

Os alertas de espécies (quando ativados) aparecem em um canal de notificação separado do Android para que você possa silenciar os alertas independentemente da notificação silenciosa de gravação contínua. O ícone de alerta corresponde ao ícone de notificação em primeiro plano (um pássaro monocromático), e os corpos de alerta mostram apenas o *motivo* — *"Primeira detecção desta pesquisa"*, *"Na sua lista de observação"*, *"Detectado neste local com menos de 4% de probabilidade"* — deixando o nome da espécie no título de notificação em negrito, onde o Android o torna maior.

## Depois de parar

BirdNET Live salva a pesquisa concluída e abre [Session Review](session-review.md).
