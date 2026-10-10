# Modo Point Count

O Modo Point Count é o fluxo de trabalho estacionário e cronometrado do BirdNET Live.

## Como abrir

Na tela de Início, toque no cartão **Modo Point Count** com o ícone :app-locationOnRounded:.

## Fluxo de configuração

A configuração do Point Count usa quatro etapas.

### 1. Duração e localização

Escolha:

- uma das durações disponíveis: 3, 5, 10, 15, 20, 25 ou 30 minutos
- se a contagem continua com a tela apagada (ativado por padrão)
- GPS atual com :app-myLocation:
- coordenadas manuais com :app-editLocationAlt:
- nenhuma localização com :app-locationOff:
- seletor de mapa com :app-mapSheet:

A tela de configuração atualiza o GPS quando você volta da caixa de diálogo de permissões do sistema ou das configurações do aplicativo, de modo que uma permissão de localização recém-concedida deve atualizar as coordenadas sem reiniciar o assistente. Essa mesma seção também inclui um cartão de clima. Se o acesso ao clima estiver desativado, o cartão solicita o consentimento de **Permitir consulta de clima**; uma vez ativado, ele apresenta uma prévia do local apenas com um ícone de clima, a temperatura e o vento. O mesmo instantâneo em cache do Open-Meteo é reutilizado quando o Point Count é salvo.

### 2. Parâmetros de inferência

Escolha as configurações de análise por Session, como taxa de inferência, limiar de confiança e o modo do filtro de espécies. Elas partem das suas configurações globais, mas podem ser ajustadas para esta contagem sem alterar seus padrões.

| Controle de configuração | Ícone |
|---|---|
| Microfone | :app-micRounded: |
| Modo de gravação | :app-fiberManualRecordRounded: |
| Contexto do clipe | :app-timerOutlined: |
| Taxa de inferência | :app-speedRounded: |
| Limiar de confiança | :app-verifiedRounded: |
| Sensibilidade | :app-hearing: |
| Filtro de espécies | :app-filterAltRounded: |

O botão :app-helpOutline: ao lado de cada controle explica seu efeito. O controle de duração :app-timerRounded: e o seletor de localização têm o mesmo botão de ajuda na primeira etapa.

Escolha **Completa** para salvar áudio contínuo (padrão), **Apenas clipes** para salvar um trecho de cada vocalização detectada ou **Desativada** para não salvar áudio. Essa escolha é independente da gravação do Live Mode e é lembrada para o próximo Point Count. Os trechos usam a mesma seleção da janela com maior pontuação e o mesmo contexto do Live Mode, sem redução baseada na localização. Com **Apenas clipes**, o controle **Contexto do clipe** define os segundos preservados antes e depois de cada janela analisada; também atualiza o contexto do Live Mode.

### 3. Dicas de campo

Esta tela apresenta uma breve lista de verificação no aplicativo para percorrer antes de começar.

### 4. Pronto

A tela de pronto resume a duração, a opção de gravação e o comportamento com a tela apagada. Inicie com :app-playArrowRounded:.

## Tela do Point Count ao vivo

A tela do Point Count ao vivo concentra-se em um painel cronometrado.

### Barra superior

- :app-stopRounded: — encerra o Point Count antecipadamente
- :app-timerRounded: — mostra o tempo restante
- :app-helpOutlineRounded: — abre a ajuda do Point Count
- :app-tuneRounded: — abre as configurações do Point Count

### Indicadores principais

- barra de progresso da contagem regressiva
- barra de informações compacta com as detecções atuais, a contagem de espécies únicas e o total de detecções
- visualização do espectrograma
- lista de detecções

## Após a contagem

Com **Continuar com a tela desligada** ativado na configuração de Point Count, a contagem continua ao bloquear a tela ou mudar para outro aplicativo, mesmo com a tela acesa. Termina após a duração escolhida; o cronômetro usa o tempo realmente decorrido, então uma tela suspensa não prolonga a contagem. Android mostra uma notificação persistente com Abrir e Parar. Desative o controle para que essas ações encerrem a contagem antes. Point Count não pausa e retoma porque isso interromperia a contagem cronometrada. Se sair durante a inicialização, ela será cancelada com uma mensagem; configure-a novamente. No Windows, minimizar a janela não encerra a contagem.

Ao terminar o Point Count, o BirdNET Live abre [Resumo da Session](session-review.md). Com o salvamento automático ativado, salva a Session automaticamente; caso contrário, salve-a pelo resumo se quiser mantê-la.

Com o salvamento automático ativado, uma contagem não concluída também é salva no início, a cada 30 segundos e quando o aplicativo sai do primeiro plano. Após uma falha ou queda de energia, a última contagem parcial fica disponível na Biblioteca de Sessions.
