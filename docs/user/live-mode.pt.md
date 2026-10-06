# Modo Live

O Modo Live é a forma mais rápida de escutar pelo microfone do telefone e revisar as detecções à medida que aparecem em tempo real.

## Como abrir

Na tela de Início, toque no cartão **Modo Live** com o ícone :app-micRounded:.

## Widget «Escuta rápida»

**Apenas Android.** Um widget na tela de início começa a escutar com um único toque, sem precisar abrir o app e navegar até o modo — útil quando você ouve algo que quer identificar antes que pare de cantar.

Adicione-o como qualquer outro widget: mantenha pressionado um espaço vazio da tela de início, toque em **Widgets**, procure **BirdNET Live** e arraste um dos dois blocos.

- **Escuta rápida** (2×1) — ícone com o rótulo **Iniciar escuta**
- **Escuta rápida (compacta)** (1×1) — somente o ícone

Os dois fazem a mesma coisa. Tocar em qualquer um deles abre o Modo Live e começa a escutar imediatamente, qualquer que seja o valor da configuração **Iniciar gravação automaticamente**. O widget não altera essa configuração.

Se o Modo Live já estiver aberto, o widget volta para essa mesma tela em vez de recriá-la. Uma Session em andamento ou pausada continua sem alterações; se estiver parada, a escuta começa na tela existente.

A Escuta rápida nunca substitui outro modo em execução. Se uma Session de Point Count, Survey, File Analysis ou [Modo ARU](aru-mode.md) estiver em andamento ou iniciando, o app vem para o primeiro plano e pede que você encerre primeiro essa Session. A tela e o trabalho continuam acessíveis e não são interrompidos.

## Barra superior

A barra superior contém três elementos:

- :app-arrowBackRounded: — sai do Modo Live
- texto de estado central — `Inicializando`, `Carregando modelo`, `Pronto`, `Identificando espécies`, `Pausado` ou `Erro`
- :app-tuneRounded: — abre a visualização de Configurações específica do Live

## Botão de ação principal

O grande botão circular na parte inferior central muda de estado:

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

Ao parar o Modo Live, o BirdNET Live salva a Session e abre o [Resumo da Session](session-review.md).

Quando o salvamento automático de Sessions está ativado, o Modo Live também salva uma Session parcial no início, a cada 30 segundos e quando o aplicativo vai para segundo plano. Após uma falha ou queda de energia, o último salvamento fica disponível na Biblioteca de Sessions. Alterações posteriores a esse salvamento podem ser perdidas. Desativar o salvamento automático também desativa esses salvamentos intermediários.

## Escuta com a tela apagada

Live Mode normalmente pausa ao bloquear a tela ou sair do aplicativo e retoma a mesma Session quando você volta. Na primeira vez, um diálogo oferece escuta limitada em segundo plano. Nas [configurações de gravação](settings.md), ative **Continuar com a tela desligada** e escolha um máximo de 15, 30, 60 ou 120 minutos (30 por padrão). O limite vale para cada período fora do aplicativo; atingi-lo encerra a Session. Android mostra uma notificação persistente com Abrir e Parar. No Windows, Live Mode continua escutando com a janela minimizada.
