# Live Mode

O Live Mode é a forma mais rápida de escutar pelo microfone do telefone e revisar as detecções à medida que aparecem em tempo real.

## Como abrir

Na tela de Início, toque no cartão **Live Mode** com o ícone :app-micRounded:.

## Escuta rápida

A Escuta rápida começa a escutar com um único toque, sem precisar abrir o app e navegar até o modo — útil quando você ouve algo que quer identificar antes que pare de cantar. Todos os pontos de entrada abaixo abrem o Live Mode e começam a escutar imediatamente, qualquer que seja o valor da configuração **Iniciar gravação automaticamente**, e nenhum deles altera essa configuração.

### Android: widget na tela de início

Adicione-o como qualquer outro widget: mantenha pressionado um espaço vazio da tela de início, toque em **Widgets**, procure **BirdNET Live** e arraste um dos dois blocos.

- **Escuta rápida** (2×1) — ícone com o rótulo **Iniciar escuta**
- **Escuta rápida (compacta)** (1×1) — somente o ícone

Os dois fazem a mesma coisa.

### iOS: Atalhos, Siri, botão de Ação e ícone do app

O BirdNET Live oferece ao sistema a ação **Iniciar escuta**, então não há nada para montar à mão:

- **Botão de Ação** (iPhone 15 Pro e posteriores) — abra **Ajustes → Botão de Ação**, escolha **Atalho** e selecione **Iniciar escuta** em BirdNET Live. Depois disso, manter o botão pressionado começa a escutar.
- **Siri** — diga "Começar a ouvir com BirdNET Live", "Ouvir aves com BirdNET Live" ou "Identificar uma ave com BirdNET Live".
- **App Atalhos** — a ação **Iniciar escuta** aparece em BirdNET Live. Use-a em um atalho seu, adicione esse atalho à tela de início ou execute-o com Toque Atrás, um Foco ou uma etiqueta NFC.
- **Ícone do app** — mantenha pressionado o ícone do BirdNET Live na tela de início e toque em **Iniciar escuta**.
- **URL** — automações que abrem uma URL podem usar `birdnetlive://listen`.

As frases da Siri e a entrada no seletor do botão de Ação exigem o iOS 17. A ação dos Atalhos, o menu do ícone e a URL também funcionam no iOS 16.

### O que acontece em seguida

Se o Live Mode já estiver aberto, a Escuta rápida volta para essa mesma tela em vez de recriá-la. Uma Session em andamento ou pausada continua sem alterações; se estiver parada, a escuta começa na tela existente.

A Escuta rápida nunca substitui outro modo em execução. Se uma Session de Point Count, Survey, Análise de arquivos ou [Modo ARU](aru-mode.md) estiver em andamento ou iniciando, o app vem para o primeiro plano e pede que você encerre primeiro essa Session. A tela e o trabalho continuam acessíveis e não são interrompidos.

## Barra superior

A barra superior contém três elementos:

- :app-arrowBackRounded: — sai do Live Mode
- texto de estado central — `Inicializando`, `Carregando modelo`, `Pronto`, `Identificando espécies`, `Pausado` ou `Erro`
- :app-tuneRounded: — abre a visualização de Configurações específica do Live

## Botão de ação principal

O botão circular grande na parte inferior central muda de estado:

- :app-mic: — inicia a escuta
- :app-stopRounded: — para a Session ativa
- :app-playArrowRounded: — retoma a partir de um estado pausado e pronto

## O que você vê durante a escuta

### Espectrograma

O espectrograma rola continuamente enquanto a captura está ativa. Ele mostra o conteúdo de frequência ao longo do tempo, usando a paleta de cores, o tamanho da FFT, a faixa de frequência e a duração configurados nas Configurações.

### Lista de detecções

As detecções recentes aparecem abaixo do espectrograma. Cada linha pode mostrar:

- imagem da espécie
- nome comum
- nome científico opcional
- valor de confiança

Toque em uma linha de espécie para abrir a sobreposição de detalhes da espécie.

### Barra de informações da Session

A linha de informação compacta abaixo do espectrograma resume a Session atual, por exemplo:

- detecções visíveis no momento
- contagem de espécies únicas (`spp`)
- total de detecções (`det`)
- duração decorrida
- tamanho estimado da gravação quando a gravação está ativada

## Comportamento de gravação

A gravação é controlada nas [Configurações](settings.md).

- **Completo** grava toda a Session.
- **Apenas detecções** grava clipes em torno das detecções.
- **Desativado** desativa a gravação.

Ao parar o Live Mode, o BirdNET Live salva a Session e abre o [Resumo da Session](session-review.md).

O Live Mode também salva uma Session parcial no início, a cada 30 segundos e quando o aplicativo vai para segundo plano, e grava a Session concluída no disco antes de liberar o microfone. Após uma falha, uma queda de energia ou o encerramento do aplicativo pelo sistema em segundo plano, o último salvamento fica disponível na biblioteca de sessões, marcado como interrompido se o aplicativo terminou no meio da Session. Alterações posteriores a esse salvamento podem ser perdidas. Esses salvamentos intermediários são mantidos mesmo com o salvamento automático desativado; uma Session concluída então ainda abre no resumo como não salva e é descartada se você sair sem salvar.

## Escuta com a tela desligada

O Live Mode normalmente pausa ao bloquear a tela ou sair do aplicativo e retoma a mesma Session quando você volta. Na primeira vez, um diálogo oferece escuta limitada em segundo plano. Em [Configurações → Áudio e gravação](settings.md#continuar-com-a-tela-desligada), ative **Continuar com a tela desligada** e escolha um máximo de 15, 30, 60 ou 120 minutos (30 por padrão). O limite vale para cada período fora do aplicativo; atingi-lo encerra a Session. O Android mostra uma notificação persistente com Abrir e Parar. No Windows, o Live Mode continua escutando com a janela minimizada.
