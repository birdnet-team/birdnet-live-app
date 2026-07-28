# BirdNET Live

**Bioacústica profesional en tu bolsillo.**

BirdNET Live es una app de Flutter creada para investigadores de campo, conservacionistas y observadores de aves que necesitan evidencia acústica fiable sobre el terreno. Ejecuta el clasificador de audio y el geomodelo de BirdNET+ directamente en tu dispositivo, de modo que la identificación de especies funciona completamente sin conexión una vez instalada.

<p align="center">
  <img src="https://img.shields.io/badge/latest-v0.19.2-orange.svg" alt="Latest release: v0.19.2">
  <img src="https://img.shields.io/badge/species-9%2C789-brightgreen.svg" alt="Species: 9,789">
  <img src="https://img.shields.io/badge/platforms-Android%20%7C%20iOS%20%7C%20Windows-green.svg" alt="Platforms">
</p>

## Funciones

- **Modo Live** - Espectrograma con desplazamiento en tiempo real e identificación de especies
- **Modo Point Count** - Sesiones cronometradas con temporizador de cuenta atrás y metadatos de la estación
- **Modo Survey** - Recorridos de transecto de larga duración con seguimiento GPS, monitorización en segundo plano y muestreo de detecciones
- **Modo Análisis de archivos** - Análisis sin conexión de grabaciones existentes (WAV, FLAC, MP3, OGG y más)
- **Explorar** - Consulta las especies esperadas en tu ubicación usando el geomodelo de BirdNET
- **Biblioteca de sesiones** - Revisa, edita y exporta sesiones anteriores con reproducción de audio
- **Exportación** - Formatos Raven Pro, CSV, JSON, GPX y paquetes ZIP con metadatos de procedencia
- **Inferencia en el dispositivo** - Cobertura del modelo BirdNET+ para 5.250 especies, sin necesidad de internet
- **Grabación FLAC** - Captura de audio comprimida con archivos más pequeños para recorridos largos
- **Accesibilidad** - Etiquetas para lectores de pantalla, descripciones emergentes y anuncios de detección hablados opcionales
- **Diseños adaptables** - Interfaces que se ajustan a teléfono, tableta, vertical y horizontal

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

## Inicio rápido

Consulta la [Guía del usuario](user/index.md) para tener una visión general y luego abre [Primeros pasos](user/getting-started.md) para instalar y ejecutar BirdNET Live.

## Instalación en Android

BirdNET Live está disponible como APK firmado para instalación manual. Descarga la última versión desde la [página de versiones de GitHub](https://github.com/birdnet-team/birdnet-live-app/releases/latest), transfiere el archivo `.apk` a tu teléfono y ábrelo para instalarlo. Es posible que primero tengas que permitir la instalación desde fuentes desconocidas en los ajustes de tu dispositivo.

> **Nota:** El APK ocupa unos 253 MB porque incluye los archivos del modelo BirdNET+ para la inferencia sin conexión.

## Para desarrolladores

Consulta la [Guía para desarrolladores](developer/index.md) para conocer la arquitectura, la compilación y cómo contribuir.

## Licencia

El código fuente de BirdNET Live es de código abierto bajo la [Licencia MIT](https://github.com/birdnet-team/birdnet-live-app/blob/main/LICENSE). Los pesos de los modelos BirdNET incluidos están licenciados bajo la [Apache License 2.0](https://github.com/birdnet-team/birdnet-live-app/blob/main/MODEL_LICENSE).
