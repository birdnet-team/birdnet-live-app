# Primeiros passos

## Instalação

O BirdNET Live está disponível para Android, iOS e Windows.

### Requisitos

- **Android**: 8.0 (API 26) ou posterior
- **iOS**: 15.0 ou posterior
- **Windows**: 10 ou posterior (experimental)
- ~300 MB de armazenamento para o aplicativo e os modelos

### Download

- **Android**: [Google Play](https://play.google.com/store/apps/details?id=de.tu_chemnitz.mi.kahst.birdnet_live), ou instale manualmente o APK assinado na [página de releases do GitHub](https://github.com/birdnet-team/birdnet-live-app/releases/latest).
- **iOS**: [App Store](https://apps.apple.com/us/app/birdnet-live/id6776168518).
- **Windows**: compile a partir do código-fonte; consulte o [Guia do desenvolvedor](../developer/building.md).

## Fluxo na primeira utilização

Ao abrir o BirdNET Live pela primeira vez, o aplicativo apresenta um breve fluxo de introdução e configuração de permissões.

1. Leia as telas de introdução.
2. Revise a Política de uso aceitável e a Política de Privacidade.
3. Conceda a permissão de microfone para que o BirdNET Live possa processar o áudio.
4. Opcionalmente, conceda a permissão de localização para georreferenciamento, Explorar, Point Count e Survey.
5. Opcionalmente, permita notificações para Surveys de longa duração.

## Primeira inicialização

1. **Introdução** — Apresentação rápida dos recursos e das permissões
2. **Uso aceitável e Privacidade** — revise a Política de uso aceitável e a Política de Privacidade
3. **Permissões** — Conceda acesso ao microfone (obrigatório para todos os modos)
4. **Pronto** — Comece a identificar aves!

## Visão geral da tela de Início

A tela de Início é o hub principal.

### Cartões dos modos principais

- :material-microphone: **Modo Live**
- :material-map-marker: **Modo Point Count**
- :material-routes: **Modo Survey**
- :material-file-music: **Análise de arquivos**

### Botões do rodapé

- :material-tune: **Configurações**
- :material-magnify: **Explorar**
- :material-music-box-multiple-outline: **Sessões**
- :material-help-circle-outline: **Ajuda**
- :material-information-outline: **Sobre**

## O que é salvo

O BirdNET Live salva automaticamente cada Session concluída e a abre no Resumo da Session assim que o processamento termina.

- As Live Sessions salvam as detecções e, dependendo das suas configurações, gravações ou clipes.
- As Sessions de Point Count são salvas como Sessions de Point Count cronometradas.
- As Sessions de Survey salvam o percurso, as detecções e os metadados relacionados.
- Os resultados da Análise de arquivos são convertidos em uma Session que pode ser revisada.

## Próximas páginas recomendadas

- Leia [Ícones e controles](icons-and-controls.md) se quiser uma explicação rápida dos símbolos recorrentes da interface.
- Leia [Configurações](settings.md) antes de alterar limiares, filtros, comportamento de gravação ou exibição do espectrograma.
- Abra o guia do fluxo de trabalho que você usa com mais frequência: [Modo Live](live-mode.md), [Modo Point Count](point-count-mode.md), [Modo Survey](survey-mode.md) ou [Análise de arquivos](file-analysis.md).

## Permissões

| Permissão | Necessária para | Opcional? |
|------------|-------------|-----------|
| Microfone | Todos os modos de gravação | Obrigatória |
| Localização | Marcação GPS, Survey/Point Count | Opcional no Live |
| Armazenamento | Salvar gravações e exportações | Necessária para gravação |
| Notificações | Alertas de Survey em segundo plano | Opcional |
