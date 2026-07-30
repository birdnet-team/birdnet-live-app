# Configurações

O BirdNET Live reutiliza uma única tela de Configurações em vários fluxos de trabalho. O botão :material-tune: abre as seções relevantes para a tela de onde você veio.

## Como funciona o escopo das Configurações

- Abrir as Configurações pela tela de Início mostra a tela inteira.
- Abrir as Configurações pelo Live, Survey, Point Count ou Análise de arquivos filtra a tela para as seções relevantes.

## Geral

### Tema

Escolha **Escuro**, **Claro** ou **Sistema**.

Se as **Cores dinâmicas** estiverem ativadas, o BirdNET Live também tenta acompanhar a paleta do sistema do seu dispositivo Android. Isso só tem efeito em dispositivos Android compatíveis; no iPhone e no iPad o app continua usando o tema padrão do BirdNET Live, então ativar o interruptor lá não muda nada.

### Idioma do aplicativo

Define o idioma da interface.

### Nomes de espécies

Controla o idioma usado para os nomes das espécies. **Sistema** usa o idioma preferido do telefone quando esse nome estiver disponível, mesmo que a interface volte para inglês. **Seguir app** usa o idioma da interface.

### Mostrar nomes científicos

Mostra os nomes científicos abaixo dos nomes comuns em todo o aplicativo.

### Sobreposição de reprodução na revisão

Quando ativada (que é o padrão), revisar um clipe de áudio em um Resumo da Session somente com clipes (em que não há gravação/espectrograma de áudio completo disponível) dispara uma sobreposição de reprodutor modal dedicada com controles de transporte e uma prévia do espectrograma, em vez de reproduzir o clipe em segundo plano. Se uma Session tiver áudio completo, esta configuração é ignorada e a sobreposição de reprodução nunca é exibida.

### Nome do observador

A configuração de Survey, Point Count e ARU lembra o último nome de observador não vazio inserido em qualquer um desses modos e o preenche previamente na próxima vez que você configurar uma Session de campo. Isso mantém o uso repetido rápido em um telefone de campo pessoal, ao mesmo tempo que permite editar ou limpar o observador antes de iniciar uma Session.

### ID do ARU / estação

A configuração do ARU lembra o último ID de ARU/estação não vazio e o preenche previamente para a próxima implantação. Quando presente, o ID é incluído no nome da ARU Session e nos nomes dos arquivos de exportação, de modo que implantações repetidas em locais fixos permaneçam identificáveis fora do app.

### Exibição de carimbo de data/hora

Controla como os horários de cada detecção aparecem no Resumo da Session.

- **Relativo** mostra o deslocamento desde o início da gravação, por exemplo, `00:12:34`. Melhor para revisar uma única Session e alinhar com o indicador do espectrograma.
- **Absoluto** mostra a hora do relógio local em que a detecção foi capturada, por exemplo, `08:42:17`. Melhor para cruzar com notas de campo, registros meteorológicos ou gravações simultâneas.

Se uma detecção cair em um dia de calendário diferente do início da Session (por exemplo, um Survey noturno), o horário absoluto ganha o sufixo `+1d` para que quem revisa não confunda o coro da madrugada de amanhã com o de hoje.

Quando **Absoluto** está selecionado, aparece também o interruptor **Mostrar segundos nos carimbos de hora**. Desative-o se preferir o formato mais compacto `08:42` em vez de `08:42:17` — útil ao percorrer longas listas de detecções. Os deslocamentos relativos sempre mostram os segundos porque o alinhamento com o espectrograma exige precisão abaixo de um minuto.

O armazenamento e as exportações sempre usam instantes em UTC, independentemente desta configuração, então a escolha nunca afeta os dados — apenas a forma como são exibidos.

## Áudio

Estes controles aparecem nos fluxos de trabalho ao vivo baseados em áudio.

### Ganho

Amplificador linear aplicado ao áudio recebido antes de ele chegar ao espectrograma e ao classificador. Mantenha em **1.0×** a menos que sua entrada seja consistentemente muito baixa — por exemplo, um microfone de lapela de alta impedância em um telefone ou uma interface USB cujo pré-amplificador está ajustado muito baixo. Aumentar o ganho acima de 1.0 não revela magicamente cantos que o microfone nunca captou; apenas reescala o que o microfone entregou, então sons fortes e próximos podem saturar. Abaixo de 1.0 é útil no caso raro em que uma entrada forte está saturando o espectrograma.

### Filtro passa-alta (Hz)

Corta o conteúdo de baixa frequência antes da inferência usando um filtro Butterworth de 24 dB/oitava — o valor do controle deslizante é o corte de −3 dB. **0 Hz o desativa.** Um corte de 100–200 Hz remove vento, ruído de tráfego e ruído de manuseio sem afetar a maioria das espécies; avançar para 500–1000 Hz começa a remover pios graves, corujas, tetrazes e os estrondos do socó-boi, então só vá tão alto se estiver deliberadamente ignorando essas espécies em troca de um espectrograma muito mais limpo em um ambiente urbano ruidoso. O corte escolhido deve ficar visível como uma linha horizontal nítida no espectrograma ao vivo.

### Fonte de áudio

Uma única folha com dois controlos independentes: **Microfone** — que entrada grava — e **Processamento** — quanto o telefone pode alterar o sinal à entrada. Combinam-se livremente, por isso gravar com um microfone USB *sem processamento* é uma configuração perfeitamente válida. A sua seleção é lembrada entre as inicializações do app, e o mesmo seletor aparece nas telas de configuração do Survey, do Point Count e do ARU. As mudanças têm efeito imediato: mesmo no meio de uma gravação, o app troca o microfone na sessão em curso em vez de esperar pela próxima.

**Microfone** lista pelo nome todas as entradas que o telefone expõe: microfones USB, com fio e Bluetooth e, em muitos telefones, também os microfones embutidos individualmente (por exemplo *inferior* e *traseiro*). Kits de microfone sem fios como o Rode Wireless GO ou o DJI Mic ligam-se por um recetor USB-C, pelo que aparecem aqui como dispositivos de áudio USB normais, com toda a qualidade.

**Processamento** é a parte que mais importa, e existe **apenas no Android**. Os telefones aplicam por padrão ao áudio do microfone um processamento pensado para a voz — redução de ruído, modelagem espectral e ganho automático — porque o microfone serve sobretudo para chamadas. Esse processamento trata o canto das aves como ruído a suprimir, e nenhum ajuste comum o desliga. A única saída é pedir ao Android uma *fonte de áudio* diferente:

| Opção | O que faz |
|---|---|
| **Padrão do telemóvel** | O que o seu telefone faz normalmente, processamento de voz incluído. O comportamento original e ainda o padrão, para que nada mude para quem já usa o app. |
| **Sem processamento** | O sinal bruto do microfone — sem redução de ruído nem ganho automático. Costuma ser a melhor escolha para aves. |
| **Reconhecimento de voz** | Também desliga a redução de ruído e o ganho automático, e funciona em quase todos os telefones. |

**Experimente e compare.** Qual delas vence depende mesmo do aparelho. *Sem processamento* é o ideal, mas o Android só a respeita em telefones cujo fabricante declara suporte; nos demais ele recorre silenciosamente a uma alternativa e soa igual a *Padrão do sistema*. É para isso que existe *Reconhecimento de voz*: as regras de compatibilidade do Android **exigem** que o ganho automático e a supressão de ruído estejam desligados para essa fonte, de modo que ela entrega áudio sem processamento mesmo em telefones que ignoram *Sem processamento*. Se mudar para *Sem processamento* não alterar nada, mude para *Reconhecimento de voz*.

Espere que as opções sem processamento soem **mais baixas** — é a ausência do ganho automático, não um defeito. Aumente o **Ganho** para compensar se o medidor de nível parecer baixo.

**No iOS**, o controlo Processamento fica oculto e a folha é apenas uma lista de microfones. O iOS já entrega ao app áudio praticamente sem processamento, portanto não há nada equivalente a escolher.

## Inferência

### Duração da janela

Controla o comprimento da janela de análise.

### Limiar de confiança

Define o quão conservadoras as detecções devem ser. O padrão é **35%**, que mantém a lista ao vivo focada em correspondências mais fortes sem deixar de dar espaço a chamados distantes ou parcialmente mascarados. Reduza-o se estiver levantando espécies raras ou silenciosas e planejar revisar mais candidatos depois; aumente-o quando o ruído de fundo ou falsos positivos comuns estiverem sobrecarregando a Session.

### Sensibilidade

Um deslocamento no eixo x aplicado às pontuações de probabilidade brutas do modelo antes do Score Pooling, da filtragem geográfica e do limiar de confiança. O modelo de áudio BirdNET já inclui uma ativação sigmoide, por isso o BirdNET Live primeiro converte cada probabilidade de volta para o espaço logit, soma o viés de sensibilidade e depois a converte novamente em probabilidade. Valores mais altos tornam o detector mais permissivo — chamados mais fracos ou mais ambíguos cruzam o limiar, ao custo de mais falsos positivos. Valores mais baixos são mais rigorosos e só deixam passar detecções confiáveis. O padrão de **1.0** não aplica deslocamento e corresponde à referência do BirdNET. Experimente **1.25** se suspeitar que o modelo está perdendo chamados distantes; reduza para **0.75** se estiver inundado de detecções de baixa qualidade de espécies comuns. A sensibilidade é aplicada imediatamente: alterá-la no meio de uma Session entra em vigor na próxima janela de inferência.

### Taxa de inferência

Controla com que frequência o BirdNET executa a inferência.

### Score Pooling

Combina as pontuações entre as janelas de inferência recentes para que uma única janela ruidosa não domine o resultado. **Desativado** usa a probabilidade de cada janela — o mais reativo e o mais ruidoso. **Média** faz a média aritmética das janelas recentes para a saída mais suave. **Max** mantém o pico mais alto por espécie, que é o modo de suavização mais reativo e bom para chamados breves e nítidos. **LME** (log-mean-exp, o padrão) é o máximo suave de referência do BirdNET: comporta-se como *max* quando uma janela domina e como *média* quando várias janelas concordam. No modo LME, uma nova espécie também precisa de suporte repetido em janelas individuais antes de aparecer pela primeira vez, enquanto as detecções suportadas mantêm a maior parte da sua pontuação recente mais forte numa única janela, e as espécies já visíveis continuam até que sua pontuação combinada caia abaixo do limiar de confiança. Trocar de modo no meio de uma Session limpa o buffer móvel para que pontuações antigas não vazem para o novo modo.

### Número de janelas de pooling

Controla quantas janelas de inferência consecutivas participam do Score Pooling. Um valor maior suaviza a pontuação de cada espécie ao longo de um horizonte temporal mais longo, o que suprime detecções esporádicas — útil para chamados constantes e distantes, em que você prefere aguardar algumas janelas corroborantes antes de levantar uma detecção. Um valor menor reage mais rápido a vocalizações breves, mas deixa passar mais ruído. O padrão de **5** corresponde ao valor historicamente fixado no modelo e é um bom ponto de partida para uso ao vivo.

## Espectrograma

### Tamanho da FFT

Controla a resolução de frequência no espectrograma.

### Paleta de cores

Escolha **Viridis**, **Magma** ou **Escala de cinza**.

### Duração (velocidade de rolagem)

Controla quanto tempo fica visível na janela do espectrograma.

### Faixa de frequência

Define a frequência superior de exibição.

### Amplitude logarítmica

Aplica escala logarítmica ao espectrograma para facilitar a leitura visual.

### Qualidade

Controla a suavidade com que a imagem do espectrograma é escalada. **Média** é o equilíbrio padrão. Escolha **Baixa** em telefones mais antigos quando a rolagem engasga ou o dispositivo esquenta; escolha **Alta** se preferir uma imagem mais suave e o dispositivo tiver margem de GPU suficiente. A intuição: isto altera apenas o custo de renderização, não a análise de áudio nem os resultados de detecção.

## Anúncios

Esta seção controla se o BirdNET Live **lê as detecções em voz alta pelos fones de ouvido ou pelo alto-falante do telefone** enquanto uma Session está gravando. Todo o recurso fica **desativado por padrão** porque altera o ambiente acústico ao redor do microfone — ativá-lo é uma decisão deliberada. Não há assistente de configuração: os seletores de verbosidade × frequência abaixo *são* toda a configuração, então você pode tocar em uma predefinição diferente a qualquer momento e ouvir imediatamente a diferença. A intuição: em Surveys longos, você não consegue ficar olhando para a tela; uma voz discreta no ouvido permite manter os olhos no habitat e ainda assim saber o que acabou de ser ouvido.

### Dizer detecções em voz alta (interruptor principal)

Desativado por padrão. Quando ativado, o app fala cada detecção aceita usando o texto-para-voz integrado do dispositivo. **Recomendam-se fortemente os fones de ouvido** — usar o alto-falante do telefone arrisca que o anúncio seja captado pelo microfone e detectado de novo, então o app silencia brevemente o gravador em torno de cada fala para evitar esse ciclo (veja *Silenciar mic durante o anúncio* abaixo).

### Predefinição de verbosidade

Quanto o app comenta sobre cada detecção. **Mínima** diz apenas o nome da espécie (melhor para Surveys muito longos, em que você só quer o sinal). **Equilibrada** é o padrão — frases curtas e variadas como *"Sabiá"*, *"Ouvi um sabiá"*, *"Sabiá de novo"*. **Conversadora** acrescenta um pouco mais de contexto e fica mais próxima de ter alguém narrando ao seu lado. **Personalizada** aparece automaticamente se você ajustar os valores avançados manualmente. A intuição: as mesmas configurações de frequência podem soar silenciosas ou ruidosas demais dependendo da redação — a verbosidade permite manter a cadência e apenas regular o quanto se fala.

### Predefinição de frequência

Com que frequência o app pode falar. Cinco níveis, do mais silencioso ao mais falador. **Raríssima** e **Esparsa** esperam muito entre os anúncios e limitam o ritmo — bem adequadas a Surveys de várias horas, em que você quer uma noção de atividade sem comentário contínuo. **Normal** é a cadência conversacional padrão. **Frequente** encurta os intervalos e eleva o limite; apropriada para Live Sessions curtas ou quando você quer um retorno mais próximo do tempo real. **Constante** remove completamente o atraso de início e deixa o app falar em quase todo ciclo de detecção — útil para demonstrações, acessibilidade ou sempre que o intervalo antes do primeiro anúncio no modo *Frequente* parecer longo demais. **Personalizada** aparece quando você altera os campos de tempo no Avançado. A intuição: este é o controle que decide se o app fica em segundo plano ou se torna uma presença — toque em uma predefinição diferente e você ouvirá a nova cadência no próximo ciclo de detecção, sem precisar de botão de salvar.

### Voz (velocidade e tom)

Dois controles deslizantes que ajustam a voz de TTS da plataforma. A **Velocidade** varia de 0,5× a 1,5×; o padrão de 1,0× é o ritmo "normal" da plataforma. O **Tom** varia de 0,7× a 1,3×. A intuição: uma pequena redução no tom e uma leve desaceleração podem tornar os anúncios muito mais fáceis de entender ao ar livre, com vento ou água corrente ao fundo; o botão *Ouvir exemplo* abaixo apresenta uma prévia de três nomes comuns de aves com as configurações atuais para você iterar sem sair da tela.

### Avançado

Uma seção expansível que expõe alguns interruptores de roteamento de áudio mais o seletor de modo de disparo. Em geral, você não precisa abri-la — as predefinições de verbosidade e frequência acima são os únicos controles que importam no dia a dia. Os valores de limitação de ritmo (carência inicial, intervalo mínimo, máximo por minuto, pausa de série, reposição de "recente") estão agrupados no controle deslizante de **Frequência**, de modo que há um lugar óbvio para aumentar ou diminuir a cadência.

- **Permitir alto-falante do telefone** — Quando desativado, os anúncios são ignorados em silêncio se nenhum fone de ouvido ou alto-falante externo estiver conectado. Quando ativado, o alto-falante do telefone é usado como recurso. Ative para escuta casual em casa; deixe desativado em trabalho de campo para garantir que não haja realimentação acústica para o microfone.
- **Silenciar mic durante o anúncio** — Substitui o áudio recebido por silêncio enquanto o app fala, para que a saída do alto-falante não seja captada pelo microfone e detectada de novo. Muito recomendado (e o padrão). Só desative se o seu microfone estiver acusticamente isolado do alto-falante do telefone — por exemplo, um microfone de lapela em um cabo diferente ou um fone Bluetooth.
- **Baixar outros sons** — Reduz brevemente o volume de música ou podcasts de outros apps durante o anúncio e o restaura depois. Ativado por padrão. Desativado, toca no volume normal.
- **Som antes do anúncio** — Toca um som breve e baixo antes de cada fala para que o ouvido tenha um momento de passar da escuta passiva para a atenção à voz. Ativado por padrão. Especialmente útil quando os anúncios são pouco frequentes ou quando há música ao fundo.
- **O que anunciar** — Escolhe quais detecções são elegíveis para um anúncio. *Cada detecção* (padrão) deixa a limitação decidir. *Primeira vez por Session* anuncia uma espécie apenas na primeira vez que ela aparece na Session atual. *Apenas lista de observação* limita os anúncios às espécies da sua lista de observação (útil em trabalho de Survey direcionado, em que você quer ouvir sobre seus táxons prioritários e mais nada).

## Gravação

### Modo

- **Completo** — salva toda a gravação
- **Apenas detecções** — salva clipes em torno das detecções
- **Desativado** — sem gravação de áudio

### Contexto do clipe

Quando **Apenas detecções** está ativo, o app mostra um único controle deslizante **Contexto do clipe** (0–5 s) que define quanto áudio é preservado em **ambos os lados** de cada detecção. Cada clipe tem `janela de análise + 2 × contexto do clipe` de duração, então, com uma janela de análise de 3 s e o contexto padrão de 1 s, o clipe salvo é de 5 s. Definir o contexto para 2 s gera um clipe de 7 s (2 s de pré-rolagem + 3 s de áudio analisado + 2 s de pós-rolagem). Valores maiores dão mais margem para inspeção visual ou ferramentas de revisão externas, ao custo de espaço em disco; 0 salva apenas a própria janela analisada.

### Formato

Escolha **WAV** ou **FLAC**. O WAV é maior, mas amplamente compatível e rápido de inspecionar. O FLAC mantém a mesma qualidade de áudio sem perdas usando menos armazenamento, o que costuma ser melhor para Sessions longas.

Esta configuração se aplica ao áudio gravado pelo BirdNET Live. A **Análise de arquivos** mantém uma cópia gerenciada pelo app do arquivo importado em seu formato original, então uploads em MP3, AAC, WAV e FLAC continuam revisáveis sem uma etapa extra de conversão.

### Iniciar gravação automaticamente (apenas no Modo Live)

Quando ativado, o Modo Live começa a gravar assim que a tela abre e o modelo termina de carregar — sem precisar tocar no botão do microfone. Útil para instalações tipo quiosque, uso viva-voz (por exemplo, ao montar o dispositivo em campo) ou qualquer fluxo de trabalho em que já se sabe que abrir o Live significa sempre "começar agora". Desativado por padrão para que um toque acidental no cartão do Live, na tela de Início, não inicie uma Session silenciosamente. O início automático ocorre apenas uma vez por visita à tela, então parar uma Session e tocar no microfone novamente ainda funciona como reinício manual.

Esta configuração vale para abrir o Modo Live de dentro do app. O [widget «Escuta rápida»](live-mode.md) sempre começa a escutar ao ser tocado, qualquer que seja esta configuração, e não a altera.

## Localização

### Usar GPS

Usa o GPS do dispositivo em vez de coordenadas manuais.

### Latitude / Longitude

Coordenadas manuais usadas quando o GPS está desativado.

### Atualizar GPS agora

Força uma nova obtenção de localização em vez de reutilizar o último valor em cache do app. A intuição: as consultas de GPS são armazenadas em cache por tela para que uma tela de configuração não fique bloqueada esperando uma correção por satélite a cada abertura, mas esse cache pode estar muito desatualizado se você dirigiu até um novo local desde a última Session. Toque aqui quando tiver se deslocado e quiser que o filtro geográfico use *aqui*, e não onde você começou a manhã. As coordenadas em cache atuais são mostradas no subtítulo para você verificar onde o app pensa que está sua localização. Se o GPS não conseguir uma correção em cerca de 10 segundos, o app recorre à última localização conhecida fornecida pelo sistema e avisa com uma snackbar para você saber que o valor está desatualizado.

### Transferências de mapas offline

As transferências de mapas offline estão atualmente ocultas enquanto o BirdNET Live usa o serviço público de tiles do OpenStreetMap. O OpenStreetMap permite a navegação interativa normal do mapa com atribuição, um user agent claro e cache local, mas não permite o pré-carregamento em massa nem recursos de transferência de mapas offline a partir de `tile.openstreetmap.org`. A implementação do transferidor é mantida para uma futura fonte de tiles que permita explicitamente pacotes offline.

### Filtro de espécies

- **Desativado** — sem filtragem geográfica
- **Filtro geográfico** — exclui espécies que ficam abaixo do limiar geográfico
- **Ponderação geográfica** — usa o geomodelo como um sinal de ponderação adicional

### Limiar do filtro geográfico

Aparece quando um modo de filtro baseado em localização está ativo.

## Exportação e sincronização

### Formatos

Marque qualquer combinação de formatos de exportação — cada salvar / compartilhar agrupará todos os formatos selecionados em um único ZIP. Se escolher um único formato sem clipes de áudio e sem relatório HTML, você receberá um arquivo bruto (por exemplo, `session.csv`) em vez de um ZIP, para compatibilidade retroativa:

- Tabela de Seleção Raven — para uso no Cornell Raven Pro.
- CSV — abre em qualquer planilha.
- JSON — o mais fácil para processamento programático; carrega os metadados completos da Session.
- GPX — percurso e pontos de passagem para uso em ferramentas de mapas (só faz sentido quando o GPS estava ativado).

A intuição: muitos fluxos precisam de mais de um formato ao mesmo tempo — um CSV para a planilha, uma tabela Raven para o revisor no computador e um JSON para o script de análise. Antes era preciso exportar a mesma Session três vezes com um interruptor de formato único. Agora você marca os três de uma vez e eles viajam juntos no ZIP.

### Incluir arquivos de áudio

Inclui o áudio salvo junto com as tabelas ou metadados exportados, quando suportado pelo fluxo de exportação.

### Incluir relatório HTML

Quando ativado, cada ZIP de exportação também contém um arquivo `report.html` ao lado da tabela, dos clipes de áudio e do GPX. Abra-o em qualquer navegador e você terá um resumo pronto para impressão da Session: cartão de cabeçalho com data, localização, observador e totais; um mapa interativo do percurso GPS e dos marcadores de detecção; um cartão por detecção com a miniatura da taxonomia da Cornell, os nomes, a pílula de pontuação, sua confirmação, qualquer nota digitada e o clipe de áudio original embutido como reprodutor; e as configurações de análise usadas. A intuição: um CSV é ótimo para pipelines de análise, mas inútil para compartilhar com um colaborador não técnico ou imprimir um resumo de campo rápido — o relatório HTML preenche essa lacuna com um toque. As miniaturas das espécies e os tiles de mapa precisam de conexão na primeira vez que o arquivo é aberto (são buscados ao vivo da API de taxonomia do BirdNET e do OpenStreetMap), mas todo o resto — texto, layout, reprodução de áudio, links — funciona totalmente offline. Desative isto se você só precisa dos dados brutos e quer manter o ZIP alguns KB menor.

## Privacidade

Esta seção controla **quais serviços de terceiros o BirdNET Live pode contatar em seu nome**. A inferência em si roda inteiramente no seu dispositivo — estes interruptores comandam apenas recursos de rede opcionais que enriquecem a experiência. Todos os três estão **desativados por padrão** em uma instalação nova; nada é enviado até você autorizar. A intuição: cada interruptor cobre um serviço concreto e um benefício concreto, então você adere exatamente ao que é útil para o seu fluxo de trabalho e nada mais.

### Permitir blocos de mapa

Necessário para qualquer mapa interativo no app (o seletor de localização, o mapa ao vivo do Survey e o mapa da Session). Quando ativado, os widgets de mapa buscam tiles raster nos servidores públicos do **OpenStreetMap**; as requisições de coordenadas de tile revelam que área do mundo você está visualizando. Os tiles são armazenados em cache localmente por até seis meses, limitados a 6000 tiles para que visualizações repetidas continuem eficientes sem crescer sem limite. Ativar isto também ativa **Permitir busca de nome do local**, porque a maioria de quem carrega mapas espera que as Sessions também mostrem nomes de lugares legíveis. Você pode desativar a busca de nome do local novamente em separado. Quando os blocos de mapa estão desativados, toda tela de mapa recorre a um cartão de espaço reservado para que o restante do app continue funcionando sem vazamento de rede.

### Permitir busca de nome do local

Quando ativado, o app envia as coordenadas gravadas ao serviço **Nominatim** do OpenStreetMap para resolver um nome curto de local (por exemplo, *"Lisboa, Portugal"*) exibido ao lado da Session nas Sessões e no Resumo da Session. A intuição: coordenadas numéricas são precisas, mas difíceis de ler ao percorrer uma longa lista de Sessions — um nome de local torna a lista legível num relance. Quando desativado, as Sessions mostram apenas a latitude/longitude bruta e o Nominatim nunca é contatado.

### Permitir consulta de clima

Quando ativado, cada Session salva captura um instantâneo único das condições locais (temperatura, precipitação, vento, nebulosidade) nas coordenadas de gravação e no horário de término via **Open-Meteo**. O instantâneo aparece no Resumo da Session abaixo da linha de localização e é espelhado na exportação JSON, no bloco de metadados da Session e no relatório HTML. A intuição: o clima é um dos preditores mais fortes da atividade das aves, e capturá-lo automaticamente — sem você precisar lembrar de consultar um app à parte — torna cada Session um registro mais completo. O Open-Meteo é um serviço gratuito e não exige conta nem chave de API. Quando desativado, nenhum dado meteorológico é buscado ou armazenado. A configuração de Point Count e Survey também mostra um cartão de clima compacto perto de seus controles de localização: ele solicita este consentimento apenas quando necessário, apresenta o resultado como ícone + temperatura + vento uma vez ativado, e reutiliza o mesmo instantâneo em cache quando a Session é salva.

## Sobre

A linha **Sobre** abre a tela Sobre dentro do aplicativo.

## Zona de perigo

### Redefinir introdução

Mostra a sequência de introdução novamente na próxima vez que o app for iniciado.

### Repor todas as definições

Restaura todas as preferências desta tela para o valor padrão. Sessions, gravações, memos de voz, exportações e tiles de mapa em cache permanecem intactos — apenas as preferências salvas (controles deslizantes, interruptores, escolhas de seletor) são apagadas. O app fecha após a confirmação para que os novos padrões entrem em vigor na próxima inicialização.

Útil quando você não tem certeza de qual controle deslizante mexeu que quebrou algo, ou ao entregar o dispositivo a outra pessoa e querer uma configuração limpa sem perder os dados coletados.

### Excluir todos os dados

Exclui permanentemente Sessions, detecções, gravações, memos de voz, listas de espécies personalizadas, preferências salvas e dados em cache de mapas, nomes de lugares, clima, reprodução, revisão e compartilhamento. A caixa de confirmação exige digitar `DELETE` e depois fecha o app para que a próxima inicialização comece de um estado local limpo.

Use isto antes de entregar um dispositivo a outra pessoa observadora, aposentar um telefone de campo ou remover do app o histórico vinculado à localização. Exporte primeiro tudo o que precisar; esta ação não pode ser desfeita.

## Parâmetros específicos do fluxo de trabalho fora das Configurações

Alguns parâmetros são configurados em suas próprias telas de configuração, e não na tela compartilhada de Configurações.

- O [Modo Point Count](point-count-mode.md) tem sua própria configuração de duração e localização.
- O [Modo Survey](survey-mode.md) tem sua própria tela de parâmetros do Survey.
- A [Análise de arquivos](file-analysis.md) tem sua própria etapa de parâmetros de análise.
