# Configurações

O BirdNET Live reutiliza uma única tela de Configurações em vários fluxos de trabalho. O botão :material-tune: abre as seções relevantes para a tela de onde você veio.

## Como funciona o escopo das configurações

- Abrir as Configurações pela tela inicial mostra a tela completa.
- Abrir as Configurações pelo Live, Survey, Point Count ou Análise de arquivos restringe a tela às seções relevantes.

## Geral

### Tema

Escolha **Escuro**, **Claro** ou **Sistema**.

Se **Cor dinâmica** estiver ativada, o BirdNET Live também tenta adotar a paleta do sistema do seu dispositivo Android. Isso só tem efeito em dispositivos Android compatíveis; no iPhone e no iPad o aplicativo continua usando o tema padrão do BirdNET Live, então ativar o botão ali não muda nada.

Ative **Tema de alto contraste** para usar uma paleta de interface em preto e branco, clara ou escura, com texto mais pesado e superfícies com borda em vez de cartões coloridos. Ele segue a escolha **Escuro**, **Claro** ou **Sistema**, tem prioridade sobre a cor dinâmica enquanto estiver ativo e preserva as cores de perigo, aviso, validação, modo, pontuação e espectrograma.

### Idioma do aplicativo

Define o idioma da interface.

### Nomes das espécies

Controla o idioma usado nos nomes das espécies. **Sistema** usa o idioma preferido do telefone quando esse nome está disponível, mesmo que a interface recorra ao inglês. **Seguir o aplicativo** usa o idioma da interface.

### Mostrar nomes científicos

Mostra os nomes científicos abaixo dos nomes comuns em todo o aplicativo.

### Mostrar todas as espécies detectadas

Somente nos modos Live e Point Count. Desativado por padrão, então essas telas continuam mostrando apenas as espécies detectadas no último ciclo de inferência: na prática, as que estão vocalizando agora. Ative para que cada espécie detectada durante a Session em andamento permaneça visível na lista, mesmo depois de parar de vocalizar ou de cair abaixo do limite de confiança.

Quando isso está ativado, aparece **Ordenação da lista de espécies**. **Mais recentes primeiro** mostra no topo as espécies que estão vocalizando, ordenadas pela confiança atual, e depois as espécies retidas pela detecção mais recente. **Confiança** ordena pela maior confiança que cada espécie alcançou durante a Session, **Alfabética** pelo nome comum localizado e **Ocorrências** pelo número de detecções. Em qualquer modo de ordenação, a porcentagem e a barra de confiança só aparecem enquanto a espécie está vocalizando (as linhas retidas de espécies que silenciaram ficam esmaecidas), e detecções repetidas mostram um contador ao final da linha do nome comum.

### Nome do observador

A configuração de Survey, Point Count e ARU guarda o último nome de observador não vazio informado em qualquer desses modos e o preenche na próxima vez que você preparar uma Session de campo. Assim o uso repetido em um celular de campo pessoal continua rápido, e ainda é possível editar ou limpar o observador antes de iniciar uma Session.

### ID de ARU/estação

A configuração de ARU guarda o último ID de ARU/estação não vazio e o preenche para a próxima implantação. Quando presente, o ID entra no nome da Session ARU e nos nomes de arquivo de exportação, de modo que implantações repetidas em pontos fixos continuam identificáveis fora do aplicativo.

### Exibição de carimbos de data/hora

Controla como os horários de cada detecção aparecem no resumo da Session.

- **Relativo** mostra o deslocamento desde o início da gravação, por exemplo `00:12:34`. Ideal para revisar uma única Session e casar com o cursor de reprodução do espectrograma.
- **Absoluto** mostra a hora local em que a detecção foi captada, por exemplo `08:42:17`. Ideal para cruzar com anotações de campo, registros meteorológicos ou gravações simultâneas.

Se uma detecção cair em um dia de calendário diferente do início da Session (por exemplo, em um levantamento noturno), a hora absoluta recebe o sufixo `+1d`, para que ninguém confunda o coro do amanhecer de amanhã com o de hoje.

Quando **Absoluto** está selecionado, aparece o botão adicional **Mostrar segundos nos carimbos de data/hora**. Desative-o se preferir o mais compacto `08:42` em vez de `08:42:17` — útil ao percorrer listas longas de detecções. Os deslocamentos relativos sempre mostram segundos, porque na revisão é preciso precisão abaixo de um minuto para alinhar com o cursor do espectrograma.

O armazenamento e as exportações sempre usam instantes em UTC, independentemente desta configuração, então a escolha nunca afeta os dados — apenas como são exibidos.

## Áudio

Estes controles aparecem nos fluxos de trabalho ao vivo baseados em áudio.

### Fonte de áudio

Um painel com dois controles independentes: **Microfone** — de qual entrada gravar — e **Processamento** — quanto o telefone pode alterar o sinal na entrada. Eles se combinam livremente, então um microfone USB gravado *sem processamento* é uma configuração perfeitamente válida. Sua escolha é mantida entre execuções do aplicativo, e o mesmo seletor aparece nas telas de configuração de Survey, Point Count e ARU. As mudanças têm efeito imediato: mesmo no meio de uma gravação, o aplicativo troca o microfone sob a Session em andamento em vez de esperar a próxima.

**Microfone** lista pelo nome cada entrada exposta pelo telefone: microfones USB, com fio e Bluetooth e, em muitos telefones, também os microfones embutidos individualmente (por exemplo, *inferior* e *traseiro*). Kits de microfone sem fio como o Rode Wireless GO ou o DJI Mic se conectam por um receptor USB-C, então aparecem aqui como dispositivos de áudio USB comuns, em qualidade plena.

**Processamento** é a parte que mais importa, e vale **somente para Android**. Por padrão, os telefones aplicam ao áudio do microfone um DSP ajustado para fala — redução de ruído, modelagem espectral e ganho automático — porque o microfone é usado sobretudo em chamadas. Esse processamento trata o canto das aves como ruído a ser suprimido, e nenhuma configuração comum o desliga. A única saída é pedir ao Android uma *fonte de áudio* diferente:

| Opção | O que faz |
|---|---|
| **Padrão do telefone** | O que o seu telefone faz normalmente, incluindo processamento de voz. O comportamento original e ainda o padrão, para que nada mude para quem já usa o aplicativo. |
| **Sem processamento** | O sinal bruto do microfone: sem redução de ruído, sem ganho automático. Costuma ser a melhor opção para aves. |
| **Reconhecimento de voz** | Também desliga a redução de ruído e o ganho automático, e funciona em praticamente qualquer telefone. |

**Experimente e compare.** Qual delas vence realmente depende do aparelho. *Sem processamento* é o ideal, mas o Android só o respeita em telefones cujo fabricante declara suporte — nos demais ele recorre silenciosamente ao padrão e soa igual a *Padrão do sistema*. É para isso que existe *Reconhecimento de voz*: as regras de compatibilidade do Android **exigem** que, nesse modo, o ganho automático e a supressão de ruído estejam desligados, então ele entrega áudio não processado de forma confiável mesmo em telefones que ignoram *Sem processamento*. Se mudar para *Sem processamento* não alterar nada, mude para *Reconhecimento de voz*.

Espere que as opções sem processamento soem **mais baixas**: é a ausência do ganho automático, não um defeito. Aumente o **Ganho** para compensar se o medidor de nível parecer baixo.

**No iOS** o controle de Processamento fica oculto e o painel é apenas uma lista de microfones. O iOS já entrega ao aplicativo um áudio essencialmente não processado, então não há nada equivalente a escolher.

### Ganho

Amplificador linear aplicado ao áudio recebido antes que ele chegue ao espectrograma e ao classificador. Deixe em **1,0×** a menos que sua entrada esteja consistentemente baixa demais — por exemplo, um microfone de lapela de alta impedância em um telefone, ou uma interface USB com o pré-amplificador ajustado baixo demais. Elevar o ganho acima de 1,0 não fará surgir por mágica cantos que o microfone nunca captou; apenas reescalona o que o microfone entregou, então sons altos e próximos podem saturar. Abaixo de 1,0 é útil no caso raro em que uma entrada forte demais satura o espectrograma.

### Filtro passa-alta (Hz)

Corta o conteúdo de baixa frequência antes da inferência usando um filtro Butterworth de 24 dB/oitava — o valor do controle deslizante é a frequência de corte de −3 dB. **0 Hz o desativa.** Um corte de 100–200 Hz elimina vento, ronco do trânsito e ruído de manuseio sem afetar a maioria das espécies; ao avançar para 500–1000 Hz começam a sumir os chamados graves, corujas, galiformes e o "ronco" do socó-boi, então só suba tanto se estiver deliberadamente ignorando essas espécies em troca de um espectrograma muito mais limpo em um ambiente urbano ruidoso. O corte escolhido deve aparecer como uma linha horizontal nítida no espectrograma ao vivo.

## Inferência

### Duração da janela

Controla o comprimento da janela de análise. Os valores disponíveis são **1**, **3**, **5**, **7**, **10** e **15** segundos.

### Limite de confiança

Define quão conservadoras devem ser as detecções. O padrão é **35 %**, o que mantém a lista ao vivo focada em correspondências mais fortes e ainda deixa espaço para chamados distantes ou parcialmente mascarados. Reduza-o se estiver levantando espécies raras ou discretas e pretender revisar mais candidatos depois; aumente-o quando ruído de fundo ou falsos positivos frequentes estiverem lotando a Session.

### Sensibilidade

Um deslocamento no eixo x aplicado às pontuações de probabilidade brutas do modelo antes do agrupamento de pontuações, da filtragem geográfica e do limite de confiança. O modelo de áudio do BirdNET já inclui uma ativação sigmoide, então o BirdNET Live primeiro converte cada probabilidade de volta ao espaço de logits, soma o viés de sensibilidade e depois a converte novamente em probabilidade. Valores mais altos tornam o detector mais permissivo — chamados mais fracos ou ambíguos ultrapassam o limite, ao custo de mais falsos positivos. Valores mais baixos são mais rigorosos e só deixam passar detecções seguras. O padrão de **1,0** não aplica deslocamento e corresponde à referência do BirdNET. Experimente **1,25** se suspeitar que o modelo está perdendo chamados distantes; desça para **0,75** se estiver sendo inundado por detecções de baixa qualidade de espécies comuns. A sensibilidade é aplicada a quente: alterá-la no meio de uma Session tem efeito na próxima janela de inferência.

### Taxa de inferência

Controla com que frequência o BirdNET executa a inferência. O controle
deslizante usa os mesmos passos de **0,10–1,00 Hz** da configuração de Survey
e ARU. As janelas são ancoradas às amostras de áudio capturadas e não à
conclusão de um temporizador, de modo que salvar um trecho ou uma chamada ao
modelo temporariamente lenta não desloca as janelas seguintes. Com os mesmos
ajustes de inferência, o modo Live, o Point Count e o Survey analisam as
mesmas janelas e relatam as mesmas detecções. Taxas mais baixas reduzem o
trabalho do modelo e o consumo de bateria, mas deixam intervalos maiores entre
as janelas, por isso é mais fácil perder vocalizações muito breves. Novas
configurações de Survey usam **0,70 Hz** por padrão como meio-termo;
**0,30 Hz** continua sendo a opção explícita de máxima autonomia. A análise de
arquivos não tem taxa de inferência — ela usa uma configuração de
[sobreposição](file-analysis.md).

O BirdNET Live suaviza internamente as pontuações ao longo das janelas de
inferência recentes para reduzir falsos positivos isolados. Esse agrupamento
não é exposto como configuração de usuário; por padrão usa agrupamento
adaptativo Log-Mean-Exp com cinco janelas recentes e um limite de idade de 10
segundos em tempo real. As detecções aceitas exibem a maior confiança recente
respaldada pelo modelo, de modo que vocalizações evidentes ainda podem
apresentar confiança alta em vez de serem achatadas pela suavização. Todos os
modos agora transformam esse resultado em detecções da mesma forma: uma
detecção começa na sua janela de apoio mais antiga, carrega a maior pontuação
respaldada e termina no fim da última janela de apoio.

## Espectrograma

### Tamanho da FFT

Controla a resolução em frequência do espectrograma.

### Mapa de cores

Escolha **Viridis**, **Magma**, **Plasma**, **Cividis**, **Jet**, **Turbo**, **Escala de cinza** ou **BirdNET**. **Turbo** é a opção arco-íris moderna, semelhante ao Jet.

### Duração (velocidade de rolagem)

Controla quanto tempo fica visível na janela do espectrograma.

### Faixa de frequência

Define a frequência máxima exibida.

### Amplitude logarítmica

Aplica escala logarítmica ao espectrograma para facilitar a leitura.

### Qualidade

Controla com que suavidade a imagem do espectrograma é escalonada. **Média** é o equilíbrio padrão. Escolha **Baixa** em telefones mais antigos quando a rolagem engasgar ou o aparelho esquentar; escolha **Alta** quando preferir uma imagem mais suave e o dispositivo tiver folga de GPU. A intuição: isso muda apenas o custo de renderização, não a análise de áudio nem os resultados das detecções.

## Anúncios

Esta seção controla se o BirdNET Live deve **ler as detecções em voz alta pelos fones de ouvido ou pelo alto-falante do telefone** enquanto uma Session está gravando. O recurso inteiro vem **desativado por padrão**, porque muda o ambiente acústico ao redor do microfone: ativá-lo é uma escolha consciente. Não há assistente de configuração: os seletores de nível de detalhe × frequência abaixo *são* toda a configuração, então você pode tocar em outro preset a qualquer momento e ouvir a diferença na hora. A intuição: em levantamentos longos você não consegue ficar olhando a tela; uma voz discreta no ouvido permite manter os olhos no habitat e ainda assim saber o que acabou de ser ouvido.

### Ler detecções em voz alta (botão principal)

Desativado por padrão. Quando ativado, o aplicativo fala cada detecção aceita usando a síntese de voz integrada do seu dispositivo. **Fones de ouvido são fortemente recomendados** — usar o alto-falante do telefone corre o risco de o anúncio ser captado pelo microfone e detectado de novo, por isso o aplicativo silencia brevemente a gravação em torno de cada fala para evitar esse laço (veja *Silenciar o microfone ao falar* abaixo).

### Preset de nível de detalhe

Quanto o aplicativo diz sobre cada detecção. **Mínimo** fala apenas o nome da espécie (ideal para levantamentos muito longos em que você só quer o aviso). **Equilibrado** é o padrão: frases curtas e variadas como *"Pisco-de-peito-ruivo"*, *"Ouvi um pisco"*, *"Pisco de novo"*. **Falante** acrescenta um pouco mais de contexto e se aproxima de ter alguém comentando ao seu lado. **Personalizado** aparece automaticamente se você ajustar à mão os valores numéricos em Avançado. A intuição: as mesmas configurações de limitação podem soar silenciosas demais ou tagarelas demais dependendo da redação — o nível de detalhe permite manter a cadência e ajustar só a quantidade de palavras.

### Preset de frequência

Com que frequência o aplicativo pode falar. Cinco níveis, do mais silencioso ao mais falante. **Raro** e **Econômico** esperam bastante entre anúncios e limitam o ritmo — bons para levantamentos de várias horas em que você quer perceber a atividade sem um comentário contínuo. **Normal** é a cadência conversacional padrão. **Frequente** encurta os intervalos e eleva o teto; adequado a Sessions curtas de Live ou quando você quer retorno mais próximo do tempo real. **Constante** remove por completo o atraso inicial e deixa o aplicativo falar em quase todos os ciclos de detecção — útil para demonstrações, acessibilidade, ou quando a espera até o primeiro anúncio em *Frequente* parecer longa demais. **Personalizado** aparece quando você altera os campos de tempo em Avançado. A intuição: este é o único botão que decide se o aplicativo fica em segundo plano ou se torna uma presença — toque em outro preset e você ouvirá a nova cadência já no próximo ciclo de detecção, sem botão de salvar.

### Voz

Toque na linha da voz para escolher entre as vozes de síntese instaladas para o idioma dos anúncios, ou deixe **Voz padrão** para que o dispositivo decida. A disponibilidade e a qualidade das vozes dependem do sistema operacional e dos pacotes de fala instalados; vozes adicionais podem ser instaladas nas configurações de síntese de voz do dispositivo.

**Velocidade** vai de 0,5× a 1,5×; o padrão de 1,0× é o ritmo "normal" da plataforma. **Tom** vai de 0,7× a 1,3×. Uma pequena redução no tom e uma leve desaceleração podem tornar os anúncios mais compreensíveis ao ar livre, com vento ou água corrente ao fundo. *Falar uma amostra* permite ouvir a voz escolhida, o estilo de redação atual, a velocidade e o tom sem sair das Configurações. As mudanças valem a partir do próximo anúncio.

### Avançado

Uma seção expansível que expõe alguns botões de roteamento de áudio mais o seletor de modo de disparo. Em geral você não precisa abri-la — os presets de nível de detalhe e frequência acima são os únicos botões que importam no dia a dia. Os valores numéricos de limitação (carência inicial, intervalo mínimo, máximo por minuto, silêncio em sequência, redefinição de recência) estão reunidos no controle **Frequência**, de modo que há um único lugar óbvio para acelerar ou desacelerar a cadência.

- **Permitir alto-falante do telefone** — Quando desativado, os anúncios são pulados em silêncio se não houver fones nem alto-falante externo conectados. Quando ativado, o alto-falante do telefone é usado como alternativa. Ative para ouvir de forma casual em casa; deixe desativado no trabalho de campo para garantir que não haja realimentação acústica no microfone.
- **Silenciar o microfone ao falar** — Substitui o áudio recebido por silêncio enquanto o aplicativo fala, para que a saída do alto-falante não possa ser captada pelo microfone e detectada de novo. Altamente recomendado (e o padrão). Só desative se o seu microfone estiver isolado acusticamente do alto-falante do telefone — por exemplo, um microfone de lapela em outro cabo ou um fone Bluetooth.
- **Abaixar outros áudios** — Reduz brevemente o volume de músicas ou podcasts de outros aplicativos durante o anúncio e o restaura depois. Ativado por padrão. Desativado, a reprodução segue em volume cheio.
- **Tom antes de falar** — Reproduz um tom curto e discreto antes de cada fala, para que seu ouvido tenha um instante para passar da escuta passiva à atenção à voz. Ativado por padrão. Especialmente útil quando os anúncios são raros ou quando há música ao fundo.
- **O que anunciar** — Escolhe quais detecções são elegíveis a um anúncio. *Cada detecção* (padrão) deixa a limitação decidir. *Primeira vez por Session* anuncia uma espécie apenas na primeira vez que ela aparece na Session atual. *Somente lista de observação* limita os anúncios às espécies da sua lista (útil em trabalhos de levantamento direcionados, quando você quer ouvir apenas sobre os táxons prioritários).

## Gravação

### Modo

- **Completa** — salvar a gravação inteira
- **Somente detecções** — salvar trechos ao redor das detecções
- **Desativada** — sem gravação de áudio

### Contexto do trecho

Quando **Somente detecções** está ativo, o aplicativo mostra um único controle **Contexto do trecho** (0–5 s) que define quanto áudio é preservado em **ambos os lados** de cada detecção. Cada trecho dura `janela de análise + 2 × contexto do trecho`, então com uma janela de análise de 3 s e o contexto padrão de 1 s o trecho salvo tem 5 s. Definir o contexto em 2 s resulta em um trecho de 7 s (2 s antes + 3 s de áudio analisado + 2 s depois). Valores maiores dão mais margem para inspeção visual ou ferramentas externas de revisão ao custo de espaço em disco; 0 salva apenas a janela analisada.

### Formato

Escolha **WAV** ou **FLAC**. WAV ocupa mais espaço, mas é amplamente compatível e rápido de inspecionar. FLAC mantém a mesma qualidade de áudio sem perdas usando menos armazenamento, o que costuma ser melhor para Sessions longas.

Esta configuração se aplica ao áudio gravado pelo BirdNET Live. A **Análise de arquivos** mantém uma cópia gerenciada pelo aplicativo do arquivo importado em seu formato original, de modo que arquivos MP3, AAC, WAV e FLAC continuam revisáveis sem uma etapa extra de conversão.

### Iniciar gravação automaticamente (somente modo Live)

Quando ativado, o modo Live começa a gravar assim que a tela abre e o modelo termina de carregar — sem precisar tocar no botão do microfone. Útil para instalações tipo quiosque, uso sem as mãos (por exemplo, o dispositivo montado no campo) ou qualquer fluxo em que abrir o Live já signifique "começar agora". Desativado por padrão, para que um toque acidental no bloco do Live na tela inicial não inicie uma Session silenciosamente. O início automático ocorre apenas uma vez por visita à tela, então parar uma Session e tocar no microfone de novo continua funcionando como reinício manual.

Esta configuração vale para abrir o modo Live de dentro do aplicativo. O [widget Quick Listen](live-mode.md) começa a ouvir quando tocado, independentemente desta configuração, e não a altera. Se uma Session de Point Count, Survey, Análise de arquivos ou modo ARU já estiver em execução ou iniciando, essa Session é preservada e o aplicativo pede que você a interrompa primeiro.

### Salvar Sessions automaticamente (Live e Point Count)

Quando ativado (o padrão), uma Session de Live ou Point Count concluída é adicionada à sua biblioteca automaticamente no momento em que termina. Quando desativado, uma Session finalizada abre no resumo marcada como **não salva**: o ícone de salvar fica destacado e você precisa tocá-lo para manter a Session. Sair do resumo sem salvar descarta a Session e suas gravações. Isso combina com escutas rápidas em que você só quer guardar um resultado notável de vez em quando, em vez de acumular cada gravação curta. Implantações de Survey e ARU sempre salvam automaticamente — uma execução longa e sem supervisão é valiosa demais para se perder por esquecer de tocar em Salvar —, então esse botão não se aplica ali.

## Reprodução

### Sobreposição de reprodução no resumo

Quando ativado (o padrão), ouvir um trecho de áudio em um resumo de Session composto apenas por trechos (onde não há gravação completa nem espectrograma disponíveis) abre uma sobreposição modal de reprodução dedicada, com controles de transporte e prévia do espectrograma, em vez de reproduzir o trecho em segundo plano. Se uma Session tiver áudio completo, esta configuração é ignorada e a sobreposição de reprodução nunca aparece.

### Reproduzir memorandos de voz automaticamente

Desativado por padrão. Quando ativado, um memorando de voz anexado a uma anotação com marcação de tempo é reproduzido automaticamente durante o Resumo da Session, no momento em que o cursor de reprodução cruza a posição registrada. O memorando é mixado sobre a gravação em vez de pausá-la, então você ouve seu comentário no contexto junto com o áudio original. Deixe desativado se preferir acionar os memorandos manualmente tocando na etiqueta da anotação.

### Atenuação em memorandos de voz

Mostrado apenas quando **Reproduzir memorandos de voz automaticamente** está ativado. Controla quanto a gravação principal é abaixada enquanto um memorando de voz automático toca. Valores mais altos deixam os memorandos mais fáceis de entender; valores mais baixos mantêm mais da gravação original audível sob o memorando.

## Localização

### Usar GPS

Usar o GPS do dispositivo em vez de coordenadas manuais. No Android, as
posições vêm do provedor de localização da plataforma, e não dos serviços do
Google Play, então o aplicativo não dispara a caixa de diálogo do Google sobre
precisão de localização. Com isso desativado, o aplicativo nunca lê o GPS por
conta própria nem pede permissão de localização: os assistentes de configuração
de Survey, Point Count e ARU abrem na entrada manual com suas coordenadas
salvas, o rastreamento GPS do levantamento não é executado e a preparação de
mapas offline também se centra nessas coordenadas.

### Coordenadas manuais

As coordenadas usadas quando **Usar GPS** está desativado. Latitude e longitude são campos de texto editáveis, então você pode **digitar** um valor exato ou **colar** um valor copiado de outro aplicativo — muito mais preciso do que arrastar um controle deslizante em uma tela sensível ao toque. Informe graus decimais (por exemplo, `52.5200` e `13.4050`). Você também pode colar uma cadeia combinada `latitude, longitude` (separada por vírgula, ponto e vírgula ou espaço) em *qualquer* um dos campos, e ambos são preenchidos de uma vez, o que corresponde ao que a maioria dos mapas e sites coloca na área de transferência. Valores fora do intervalo ou não numéricos são sinalizados na hora e não são salvos; valores válidos permanecem enquanto você digita. A intuição: o motivo mais comum para definir uma localização manual é identificar um som gravado em outro lugar que não onde você está agora, e essa localização costuma chegar como texto de outra fonte — digitar e colar transformam isso em um único passo preciso. Se preferir apontar um ponto em vez de digitar números, **Escolher no mapa** abre o mesmo seletor de mapa em tela cheia usado nas telas de configuração, iniciado nas coordenadas atuais, e preenche ambos os campos com o local que você tocar.

### Atualizar GPS agora

Força uma nova localização em vez de reutilizar o último valor em cache do aplicativo. A intuição: as consultas de GPS ficam em cache por tela, para que uma tela de configuração não trave esperando um sinal de satélite a cada abertura, mas esse cache pode estar desatualizado em quilômetros se você dirigiu até um novo ponto desde a última Session. Toque nisso quando tiver se deslocado e quiser que o geofiltro use *aqui*, e não o lugar onde sua manhã começou. As coordenadas atuais em cache aparecem no subtítulo, para você conferir onde o aplicativo acha que você está. Se o GPS não conseguir localizar em cerca de 10 segundos, o aplicativo recorre à última localização conhecida fornecida pelo sistema operacional e avisa você com um SnackBar, para que saiba que o valor está desatualizado.

### Downloads de mapas offline

Os downloads de mapas offline estão ocultos por enquanto, enquanto o BirdNET Live usa o serviço público de blocos do OpenStreetMap. O OpenStreetMap permite a navegação interativa normal do mapa com atribuição, um user agent claro e cache local, mas não permite pré-carregamento em massa nem recursos de download de mapas offline a partir de `tile.openstreetmap.org`. A implementação do downloader é mantida para uma futura fonte de blocos que permita explicitamente pacotes offline.

### Filtro de espécies

- **Desativado** — sem filtragem geográfica
- **Filtro por localização** — excluir espécies abaixo do limite geográfico
- **Ponderação por localização** — usar o geomodelo como sinal de ponderação adicional

### Limite do geofiltro

Aparece quando um modo de filtro baseado em localização está ativo.

## Exportação e sincronização

### Formatos

Marque qualquer combinação de formatos de exportação — cada gravação/compartilhamento reunirá todos os formatos selecionados dentro de um único ZIP. Se escolher um único formato sem trechos de áudio e sem relatório HTML, você obterá um arquivo simples (por exemplo, `session.csv`) em vez de um ZIP, por compatibilidade retroativa:

- Raven Selection Table — para uso no Cornell Raven Pro.
- CSV — abre em qualquer planilha.
- JSON — o mais prático para processamento programático; contém todos os metadados da Session.
- GPX — trilha e pontos para uso em ferramentas de mapa (só faz sentido se o GPS estava ligado).

A intuição: muitos fluxos de trabalho precisam de mais de um formato ao mesmo tempo — um CSV para a planilha, uma tabela Raven para quem revisa no computador e um JSON para o script de análise. Resolver isso com um seletor de formato único significava, antes, exportar a mesma Session três vezes. Agora você marca os três de uma vez e eles viajam juntos no ZIP.

### Incluir arquivos de áudio

Incluir o áudio salvo junto às tabelas ou metadados exportados quando o fluxo de exportação der suporte a isso. O compartilhamento de uma única detecção também segue esta configuração: uma gravação completa da Session é recortada nos carimbos exatos de início e fim dessa detecção, enquanto uma Session somente com detecções usa seu clipe retido.

### Sempre compartilhar áudio como WAV

Mostrado apenas quando **Incluir arquivos de áudio** está ativado. Quando ativado, gravações FLAC são convertidas em WAV antes do compartilhamento ou da exportação. WAV é universalmente compatível, mas bem maior que FLAC, então deixe desativado a menos que a ferramenta do lado receptor não consiga ler FLAC — alguns softwares de análise de desktop mais antigos e alguns formulários de envio ainda não conseguem.

### Incluir metadados do aplicativo

Quando ativado, o ZIP de exportação leva um arquivo auxiliar `*.metadata.json` que descreve como a Session foi produzida: versão do BirdNET Live, identidade do modelo, o instantâneo de clima capturado no início da Session e quaisquer avisos de integridade de áudio detectados durante a gravação. A intuição: é essa procedência que permite a você (ou a quem revisar) reproduzir ou auditar uma Session meses depois. Desative quando quiser compartilhar de forma limpa apenas o áudio e os formatos escolhidos — por exemplo, enviar um único WAV ao iNaturalist ou eBird sem arquivos específicos do aplicativo junto.

### Incluir relatório HTML

Quando ativado, cada ZIP de exportação também contém um arquivo `<session>_report.html` ao lado da tabela, dos trechos de áudio e do GPX. Abra-o em qualquer navegador e você terá um resumo da Session pronto para impressão: cartão de cabeçalho com data, local, observador e totais; um mapa interativo da trilha GPS e dos marcadores de detecção; um cartão por detecção com a miniatura da taxonomia da Cornell, os nomes, a etiqueta de pontuação, sua confirmação, qualquer nota que você tenha escrito e o trecho de áudio original em um player embutido; além das configurações de análise usadas. A intuição: um CSV é ótimo para pipelines de análise, mas inútil para compartilhar com um colaborador não técnico ou imprimir um resumo rápido de campo — o relatório HTML preenche essa lacuna com um toque. As miniaturas de espécies e os blocos de mapa precisam de conexão na primeira vez que o arquivo é aberto (são buscados ao vivo na API de taxonomia do BirdNET e no OpenStreetMap), mas todo o resto — texto, layout, reprodução de áudio, links — funciona totalmente offline. Desative se você só precisa dos dados brutos e quer manter o ZIP alguns KB menor.

### Compartilhamento só de áudio

Desmarque todos os formatos **e** o relatório HTML **e** a caixa de metadados do aplicativo, deixando apenas **Incluir arquivos de áudio**, e Compartilhar entregará ao painel do sistema a gravação bruta (por exemplo, `BirdNET_Live_…flac`) em vez de um ZIP. Esse é o caminho mais direto para enviar uma Session ao iNaturalist, eBird ou qualquer outro aplicativo que espere um arquivo de áudio sem empacotamento. Sessions com vários trechos de detecção ainda produzem um ZIP; ao compartilhar uma única detecção, aquele único clipe bruto é entregue.

## Privacidade

Esta seção controla **quais serviços de terceiros o BirdNET Live pode contatar em seu nome**. A inferência em si é executada inteiramente no seu dispositivo — estes botões governam apenas recursos de rede opcionais que enriquecem a experiência. Em uma instalação nova, os três botões vêm **desativados por padrão**; nada sai enquanto você não autorizar. A intuição: cada botão está limitado a um serviço concreto e a um benefício concreto, então você pode ativar exatamente o que é útil no seu trabalho e nada além disso.

### Permitir blocos de mapa

Necessário para qualquer mapa interativo do aplicativo (o seletor de localização, o mapa ao vivo do Survey e o mapa da Session). Quando ativado, os componentes de mapa buscam blocos raster nos servidores públicos do **OpenStreetMap**; as requisições de coordenadas de blocos revelam qual área do mundo você está vendo. Os blocos ficam em cache local por até seis meses, com teto de 6000 blocos, para que visualizações repetidas continuem eficientes sem crescer sem limite. Ativar isso também habilita **Permitir busca de nomes de lugares**, porque a maioria de quem carrega mapas também espera que as Sessions mostrem nomes de lugares legíveis. Depois você pode desativar a busca de nomes de lugares separadamente. Com os blocos de mapa desativados, cada tela de mapa recorre a um cartão de espaço reservado, então o restante do aplicativo continua funcionando sem vazamento para a rede.

### Permitir busca de nomes de lugares

Quando ativado, o aplicativo envia suas coordenadas registradas ao serviço **Nominatim do OpenStreetMap** para obter um nome de lugar curto (por exemplo, *"Berlim, Alemanha"*), exibido ao lado da Session na Biblioteca de Sessions e no Resumo da Session. A intuição: coordenadas numéricas são precisas, mas difíceis de percorrer com o olho em uma lista longa de Sessions — um nome de lugar torna a lista legível de imediato. Quando desativado, as Sessions mostram apenas a latitude e a longitude brutas, e o Nominatim nunca é contatado.

### Permitir consulta de clima

Quando ativado, cada Session salva captura, via **Open-Meteo**, um instantâneo único das condições locais (temperatura, precipitação, vento, nebulosidade) nas coordenadas de gravação e no horário de término. O instantâneo aparece no Resumo da Session abaixo da linha de localização e é replicado na exportação JSON, no bloco de metadados da Session e no relatório HTML. A intuição: o clima é um dos preditores mais fortes da atividade das aves, e capturá-lo automaticamente — sem que você precise lembrar de consultar outro aplicativo — torna cada Session um registro mais completo. O Open-Meteo é um serviço gratuito e não exige conta nem chave de API. Quando desativado, nenhum dado de clima é buscado ou armazenado. A configuração de Point Count e Survey também mostra um cartão de clima compacto perto dos controles de localização: ele pede esse consentimento apenas quando necessário, mostra o resultado como ícone + temperatura + vento depois de habilitado, e reutiliza o mesmo instantâneo em cache quando a Session é salva.

## Sobre

A linha **Sobre** abre a tela de informações dentro do aplicativo.

## Zona de perigo

### Redefinir a introdução

Mostra a sequência de introdução novamente na próxima vez que o aplicativo for iniciado.

### Redefinir todas as configurações

Restaura cada preferência desta tela ao valor padrão. Sessions, gravações, memorandos de voz, exportações e blocos de mapa em cache permanecem intactos — apenas as preferências salvas (controles deslizantes, botões, escolhas de seletores) são apagadas. O aplicativo fecha após a confirmação, para que os novos padrões tenham efeito na próxima inicialização.

Útil quando você não tem certeza de qual controle mexeu e quebrou algo, ou quando entrega o dispositivo a outra pessoa e quer uma configuração limpa sem perder os dados coletados.

### Apagar todos os dados

Exclui permanentemente Sessions, detecções, gravações, memorandos de voz, listas de espécies personalizadas, preferências salvas e os dados em cache de mapas, nomes de lugares, clima, reprodução, resumo e compartilhamento. A caixa de confirmação exige digitar `DELETE` e depois fecha o aplicativo, para que a próxima inicialização comece de um estado local limpo.

Use isso antes de entregar um dispositivo a outro observador, aposentar um celular de campo ou remover do aplicativo o histórico vinculado a localizações. Exporte antes tudo o que precisar; esta ação não pode ser desfeita.

## Parâmetros específicos de fluxo fora das Configurações

Alguns parâmetros são configurados nas próprias telas de configuração, e não na tela de Configurações compartilhada.

- [Modo Point Count](point-count-mode.md) tem sua própria configuração de duração e localização.
- [Modo Survey](survey-mode.md) tem sua própria tela de parâmetros do levantamento.
- [Análise de arquivos](file-analysis.md) tem sua própria etapa de parâmetros de análise.
