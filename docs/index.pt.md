# BirdNET Live

**Bioacústica profissional no seu bolso.**

O BirdNET Live é um aplicativo Flutter desenvolvido para pesquisadores de campo, profissionais de conservação e observadores de aves que precisam de evidências acústicas confiáveis em campo. Ele executa o classificador de áudio BirdNET+ e o geomodelo diretamente no seu dispositivo, de modo que a identificação de espécies funciona totalmente offline depois de instalado.

<p align="center">
  <img src="https://img.shields.io/badge/latest-v1.0.1-orange.svg" alt="Latest release: v1.0.1">
  <img src="https://img.shields.io/badge/species-9%2C789-brightgreen.svg" alt="Species: 9,789">
  <img src="https://img.shields.io/badge/platforms-Android%20%7C%20iOS%20%7C%20Windows-green.svg" alt="Platforms">
</p>

## Recursos

- **Modo Live** - Espectrograma com rolagem em tempo real e identificação de espécies
- **Modo Point Count** - Sessões cronometradas com contagem regressiva e metadados da estação
- **Modo Survey** - Surveys de transectos de longa duração com rastreamento GPS, monitoramento em segundo plano e amostragem de detecções
- **Modo Análise de arquivos** - Análise offline de gravações existentes (WAV, FLAC, MP3, OGG e mais)
- **Explorar** - Veja as espécies esperadas na sua localização usando o geomodelo do BirdNET
- **Sessões** - Revise, edite e exporte sessões anteriores com reprodução de áudio
- **Exportação** - Formatos Raven Pro, CSV, JSON, GPX e pacote ZIP com metadados de proveniência
- **Inferência no dispositivo** - Cobertura do modelo BirdNET+ para 5.250 espécies, sem necessidade de Internet
- **Gravação em FLAC** - Captura de áudio comprimido com arquivos menores para Surveys longos
- **Acessibilidade** - Rótulos para leitores de tela, dicas de ferramenta e anúncios falados opcionais das detecções
- **Layouts responsivos** - Interfaces adaptáveis para celular, tablet, retrato e paisagem

<p align="center">
  <img src="../assets/screenshots/live-mode.png" alt="Live Mode" width="150">
  <img src="../assets/screenshots/session-review.png" alt="Session Review" width="150">
  <img src="../assets/screenshots/explore.png" alt="Explore" width="150">
  <img src="../assets/screenshots/species.png" alt="Species Overlay" width="150">
  <img src="../assets/screenshots/file-analysis.png" alt="File Analysis" width="150">
</p>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=de.tu_chemnitz.mi.kahst.birdnet_live"><b>Google Play</b></a>
  &nbsp;·&nbsp;
  <a href="https://github.com/birdnet-team/birdnet-live-app/releases/latest"><b>Download APK</b></a>
  &nbsp;·&nbsp;
  <a href="https://github.com/birdnet-team/birdnet-live-app"><b>GitHub</b></a>
  &nbsp;·&nbsp;
  <a href="https://github.com/birdnet-team/birdnet-live-app/releases"><b>All Releases</b></a>
</p>

## Início rápido

Consulte o [Guia do Usuário](user/index.md) para uma visão geral e, em seguida, abra [Primeiros passos](user/getting-started.md) para instalar e executar o BirdNET Live.

## Instalação no Android

O BirdNET Live está disponível como um APK assinado para instalação manual. Baixe a versão mais recente na [página de releases do GitHub](https://github.com/birdnet-team/birdnet-live-app/releases/latest), transfira o arquivo `.apk` para o celular e abra-o para instalar. Talvez seja necessário permitir antes a instalação de fontes desconhecidas nas configurações do dispositivo.

> **Nota:** o APK tem cerca de 253 MB porque inclui os recursos do modelo BirdNET+ para inferência offline.

## Para desenvolvedores

Consulte o [Guia do Desenvolvedor](developer/index.md) para arquitetura, compilação e contribuição.

## Licença

O código-fonte do BirdNET Live é código aberto sob a [Licença MIT](https://github.com/birdnet-team/birdnet-live-app/blob/main/LICENSE). Os pesos dos modelos BirdNET incluídos são licenciados sob a [Apache License 2.0](https://github.com/birdnet-team/birdnet-live-app/blob/main/MODEL_LICENSE).
