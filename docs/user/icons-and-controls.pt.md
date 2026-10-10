# Ícones e controles

Esta página explica os controles e símbolos recorrentes usados em todo o BirdNET Live. Os rótulos abaixo correspondem exatamente aos controles tal como aparecem no aplicativo.

## Ícones dos modos

Estes são os mesmos formatos de ícones usados no aplicativo. Aqui eles usam a cor do texto; as cores do aplicativo variam com tema, cor dinâmica e alto contraste.

- :app-micRounded: **Live**
- :app-locationOnRounded: **Point Count**
- :app-routeRounded: **Survey**
- :app-timerRounded: **Modo ARU**
- :app-audioFileRounded: **Análise de arquivos**
- :app-sdStorage: **Análise em lote** (Em breve)

## Controles de navegação compartilhados

| Controle | Onde aparece | O que faz |
|---|---|---|
| :app-tuneRounded: **Configurações** | Rodapé do Início, Live, Point Count, Survey, Análise de arquivos, Resumo da Session | Abre as Configurações. Nas telas de modo, abre as configurações mais relevantes para aquele fluxo de trabalho. |
| :app-searchRounded: **Explorar** | Rodapé do Início | Abre o Explorar. |
| :app-libraryMusic: **Sessões** | Rodapé do Início | Abre as Sessões. |
| :app-helpOutlineRounded: **Ajuda** | Rodapé do Início, cabeçalho do Explorar, painel do Survey, barra de ferramentas do Resumo da Session | Abre a Ajuda ou um painel de ajuda específico da tela. |
| :app-infoOutline: **Informações / Sobre** | Rodapé do Início, barras de informações, painéis de ajuda | Mostra informações gerais ou contexto resumido. |
| :app-arrowBackRounded: **Voltar** | Modo Live | Volta à tela anterior. |
| :app-openInNew: **Abrir externo** | Tela Sobre, links de documentação | Abre uma página externa, como o Guia do Usuário online. |
| :app-arrowUpwardRounded: **Voltar ao topo** | Tela de ajuda | Retorna à introdução e aos atalhos das seções. Aparece ao rolar para baixo. |
| :app-volunteerActivism: **Doar** | Tela Sobre | Abre a página de doações do BirdNET. |

## Símbolos de clima

| Símbolo | Significado |
|---|---|
| :app-wbSunny: **Limpo** | Céu limpo. |
| :app-partlyCloudyDay: **Parcialmente nublado** | Sol e nuvem para tempo predominantemente limpo ou parcialmente nublado. |
| :app-cloudy: **Encoberto** | Cobertura total de nuvens. |
| :app-foggy: **Nevoeiro** | Nevoeiro ou nevoeiro congelante. |
| :app-rainyLight: **Garoa** | Precipitação leve. |
| :app-rainy: **Chuva** | Chuva ou pancadas de chuva. |
| :app-weatherSnowy: **Neve** | Neve ou pancadas de neve. |
| :app-thunderstorm: **Trovoada** | Condições de trovoada. |

## Controles de início, parada e Session

| Controle | Significado |
|---|---|
| :app-micRounded: **Microfone** | Inicia a escuta ao vivo. |
| :app-stopRounded: **Parar** | Para uma gravação, Point Count ou Survey ativo. |
| :app-playArrowRounded: **Play** | Inicia um fluxo de configuração ou retoma a partir de um estado pausado e pronto. |
| :app-close: **Fechar** / :app-stop: **Cancelar** | Cancela uma Análise de arquivos ativa pelo cabeçalho ou pela tela de progresso. |
| :app-timerOutlined: **Cronômetro** | Duração ou tempo restante. |
| :app-errorOutline: **Erro** | Erro de modelo ou de processamento. |

## Controles de localização e tempo

| Controle | Significado |
|---|---|
| :app-myLocation: **Localização atual** | Usa a posição GPS atual do dispositivo. |
| :app-editLocationAlt: **Coordenadas manuais** | Insere as coordenadas manualmente. |
| :app-locationOff: **Sem localização** | Ignora a localização ou indica que ela não está disponível. |
| :app-locationOn: **Tem localização** | Confirma um local, mostra coordenadas ou rotula uma Session mapeada. |
| :app-refresh: **Atualizar** | Relê a localização atual ou atualiza uma lista de previsões. |
| :app-mapSheet: **Seletor de mapa** | Escolhe coordenadas no seletor de mapa. |
| :app-calendarToday: **Data** | Define ou exibe uma data. |
| :app-clear: **Limpar** | Remove uma data selecionada. |

## Símbolos do Explorar e de espécies

| Controle | Significado |
|---|---|
| Miniatura da espécie | Imagem incluída no app para a espécie, quando disponível. |
| Selo de porcentagem de confiança ou do geomodelo | Um resumo numérico rápido da saída do modelo. Números mais altos indicam um suporte mais forte no contexto daquela tela. |
| Rótulos mensais (`Jan`, `Abr`, `Jul`, `Out`, `Dez`) | Pontos de referência no gráfico semanal de frequência esperada na sobreposição de espécies. |

## Ações por detecção

Estes controles aparecem em todas as linhas de detecção do app — a lista de espécies do Resumo da Session, o painel do reprodutor de clipe, a lista de detecções do Survey ao vivo e os marcadores no mapa do Survey. Consulte [Resumo da Session → Ações por detecção](session-review.md#ações-por-detecção) para o comportamento completo.

| Controle | Significado |
|---|---|
| :app-checkCircleOutline: **Confirmar** | Marca de verificação com um toque que sinaliza uma detecção como verificada visual ou acusticamente. As detecções confirmadas recebem uma pequena marca verde nas linhas de agrupamento e nos marcadores do mapa. |
| :app-moreVert: **Mais** | Abre o menu adicional por detecção com **Compartilhar detecção**, **Substituir espécie**, **Excluir detecção** e **Excluir espécie**. |
| :app-share: **Compartilhar detecção** | Compartilha uma detecção pelo menu de compartilhamento da plataforma, anexando o clipe de áudio sempre que houver um disponível — incluindo um trecho da gravação em andamento durante um Survey ao vivo. |
| :app-swapHoriz: **Substituir espécie** | Escolhe outra espécie para esta detecção. Também abre ao deslizar uma linha de revisão para a esquerda. |
| :app-deleteOutline: **Excluir detecção** | Remove a linha imediatamente. Uma SnackBar de desfazer aparece por alguns segundos. Também acionada ao deslizar uma linha de revisão para a direita. |
| :app-deleteSweep: **Excluir espécie** | Remove de uma só vez todas as detecções dessa espécie da Session, com a mesma SnackBar de desfazer. |
| :app-hearing: **Ouvida** | Em uma detecção adicionada manualmente: você ouviu a ave. Definido pela caixa da folha de confirmação exibida após escolher a espécie. |
| :app-visibility: **Vista** | Em uma detecção adicionada manualmente: você viu a ave. Os dois ícones juntos significam ouvida *e* vista. |

## Barra de ferramentas do Resumo da Session

Estes controles são usados na tela de Resumo da Session.

| Controle | Significado |
|---|---|
| :app-addCircleOutline: **Adicionar** | Adiciona conteúdo, como uma espécie ou anotação. |
| :app-undo: **Desfazer** / :app-redo: **Refazer** | Retrocede ou avança nas edições da revisão. |
| :app-contentCut: **Recortar** | Entra no modo de recorte ou indica que ele está ativo. |
| :app-save: **Salvar** | Salva as alterações da revisão. |
| :app-share: **Compartilhar** | Exporta ou compartilha a Session. |
| :app-deleteOutline: **Excluir** | Descarta a Session. |
| :app-playArrowRounded: **Continuar** | Continua um Survey inacabado a partir do Resumo da Session, quando essa ação está disponível. |

## Barras de estado específicas da tela

### Modo Live

A barra de informações do Live usa :app-infoOutline: seguido de rótulos compactos como:

- `now` — detecções visíveis no momento na lista ao vivo
- `spp` — contagem de espécies únicas
- `det` — total de detecções
- duração e tamanho estimado da gravação quando a gravação está ativa

### Point Count

A barra do cronômetro do Point Count combina :app-stopRounded: **Parar**, :app-timerOutlined: **Cronômetro** e uma barra de progresso para mostrar quanto resta da Session cronometrada.

### Survey

O painel do Survey usa:

- :app-map: **Mapa** — aba do mapa ao vivo
- :app-graphicEq: **Espectrograma** — aba do espectrograma
- :app-summaryChart: **Resumo** — aba de resumo
- :app-summaryChart: rótulos de estatísticas na visualização de resumo do Survey

## Em caso de dúvida

Se não tiver certeza do que um controle faz, abra o painel de Ajuda mais próximo no aplicativo ou consulte a página de fluxo de trabalho dessa tela neste guia do usuário.
