# Começando

## Instalação

BirdNET Live está disponível para Android, iOS e Windows.

### Requisitos

- **Android**: 8.0 (API 26) ou posterior
- **iOS**: 15.0 ou posterior
- **Windows**: 10 ou posterior (experimental)
- ~300 MB de armazenamento para aplicativos + modelos

### Download

*Links de distribuição serão adicionados quando disponíveis.*

## Fluxo de aplicativos pela primeira vez

Quando você abre o BirdNET Live pela primeira vez, o aplicativo percorre um breve fluxo de integração e configuração de permissão.

1. Leia as telas de integração.
2. Aceite os Termos de Uso e a Política de Privacidade.
3. Conceda permissão de microfone para que o BirdNET Live possa processar o áudio.
4. Opcionalmente, conceda permissão de localização para marcação geográfica, exploração, contagem de pontos e pesquisa.
5. Opcionalmente, permita notificações para pesquisas de longa duração.

## Primeiro lançamento

1. **Onboarding** — Introdução rápida aos recursos e permissões
2. **Termos e Privacidade** — Aceite os Termos de Uso e a Política de Privacidade
3. **Permissões** — Conceda acesso ao microfone (obrigatório para todos os modos)
4. **Pronto** — Comece a identificar pássaros!

## Visão geral da tela inicial

A tela inicial é o hub principal.

### Cartões de modo principal

- :material-microfone: **Modo ao vivo**
- :material-map-marker: **Modo de contagem de pontos**
- :material-routes: **Modo de pesquisa**
- :material-file-music: **Análise de arquivo**

### Widgets do Android

No Android, você pode adicionar o widget **BirdNET Live shortcut** à tela inicial. Alguns dispositivos e hosts de widgets também permitem colocar o mesmo widget na tela de bloqueio.

- Ao tocar no widget, o app abre direto em **Live Mode** e inicia a gravação automaticamente assim que o modelo estiver pronto.
- Se o app ainda exigir onboarding ou a aceitação dos Terms, o BirdNET Live conclui esse fluxo primeiro e depois abre o Live Mode. A gravação começa automaticamente assim que o modelo estiver pronto.
- A disponibilidade na tela de bloqueio depende da versão do Android, do fabricante do dispositivo e do host de widgets; muitos telefones ainda oferecem apenas a colocação na tela inicial.
- O widget é exclusivo do Android; iOS e Windows não usam o mesmo sistema de widgets.

### Botões de rodapé

- :material-tune: **Configurações**
- :material-magnify: **Explorar**
- :material-music-box-multiple-outline: **Biblioteca de Sessões**
- :material-help-circle-outline: **Ajuda**
- :material-information-outline: **Sobre**

## O que é salvo

O BirdNET Live salva automaticamente as sessões concluídas e as abre na Revisão da Sessão após a interrupção do processamento.

- As sessões ao vivo salvam detecções e, dependendo de suas configurações, gravações ou clipes.
- As sessões de contagem de pontos são salvas como sessões cronometradas de contagem de pontos.
- As sessões de pesquisa salvam a rota, as detecções e os metadados relacionados.
- Os resultados da análise de arquivos são convertidos em uma sessão revisável.

## Próximas páginas recomendadas

- Leia [Ícones e controles](icons-and-controls.md) se quiser uma explicação rápida sobre os símbolos recorrentes da interface do usuário.
- Leia [Configurações](settings.md) antes de alterar limites, filtros, comportamento de gravação ou exibição do espectrograma.
- Abra o guia do fluxo de trabalho que você usa com mais frequência: [Modo ao vivo](live-mode.md), [Modo de contagem de pontos](point-count-mode.md), [Modo de pesquisa](survey-mode.md) ou [Análise de arquivo](file-analysis.md).

## Permissões

| Permissão | Obrigatório para | Opcional? |
|------------|-------------|-----------|
| Microfone | Todos os modos de gravação | Obrigatório |
| Localização | Marcação GPS, levantamento/contagem de pontos | Opcional para Live |
| Armazenamento | Salvando gravações, exportações | Necessário para gravação |
| Notificações | Alertas de pesquisa de antecedentes | Opcional |
