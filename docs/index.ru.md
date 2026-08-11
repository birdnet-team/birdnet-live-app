# BirdNET Live

**Профессиональная биоакустика в вашем кармане.**

BirdNET Live — приложение на Flutter для полевых исследователей, специалистов по охране природы и орнитологов, которым нужны надёжные акустические свидетельства в поле. Аудиоклассификатор BirdNET+ и геомодель работают прямо на вашем устройстве, поэтому после установки определение видов работает полностью офлайн.

<p align="center">
  <img src="https://img.shields.io/badge/latest-v1.1.2-orange.svg" alt="Latest release: v1.1.2">
  <img src="https://img.shields.io/badge/species-9%2C789-brightgreen.svg" alt="Species: 9,789">
  <img src="https://img.shields.io/badge/platforms-Android%20%7C%20iOS%20%7C%20Windows-green.svg" alt="Platforms">
</p>

## Возможности

- **Режим Live** - прокручивающаяся спектрограмма в реальном времени с определением видов
- **Режим Point Count** - Sessions по таймеру с обратным отсчётом и метаданными точки
- **Режим Survey** - продолжительные трансектные учёты с GPS-треком, фоновым мониторингом и выборкой обнаружений
- **Анализ файлов** - офлайн-анализ имеющихся записей (WAV, FLAC, MP3, OGG и другие)
- **Режим ARU** - превратите устройство в автономный регистратор звука для многодневных развёртываний
- **Обзор** - просмотр видов, ожидаемых в вашей местности, по геомодели BirdNET
- **Библиотека Sessions** - просмотр, редактирование и экспорт прошлых Sessions с воспроизведением звука
- **Экспорт** - форматы Raven Pro, CSV, JSON, GPX и ZIP-архивы с метаданными происхождения
- **Вычисления на устройстве** - модель BirdNET+ охватывает 9789 видов, интернет не нужен
- **Запись в FLAC** - сжатый звук и файлы меньшего размера для длительных учётов
- **Доступность** - подписи для программ чтения с экрана, подсказки и необязательные голосовые объявления об обнаружениях
- **Адаптивная вёрстка** - интерфейс подстраивается под телефон, планшет, книжную и альбомную ориентацию
- **Локализация** - интерфейс и голосовые объявления на 11 языках

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
  <a href="https://apps.apple.com/us/app/birdnet-live/id6776168518"><b>App Store</b></a>
  &nbsp;·&nbsp;
  <a href="https://github.com/birdnet-team/birdnet-live-app/releases/latest"><b>Download APK</b></a>
  &nbsp;·&nbsp;
  <a href="https://github.com/birdnet-team/birdnet-live-app"><b>GitHub</b></a>
  &nbsp;·&nbsp;
  <a href="https://github.com/birdnet-team/birdnet-live-app/releases"><b>All Releases</b></a>
</p>

## Быстрый старт

Загляните в [Руководство пользователя](user/index.md) за обзором, а затем откройте [Начало работы](user/getting-started.md), чтобы установить и запустить BirdNET Live.

## Установка

BirdNET Live доступно в [Google Play](https://play.google.com/store/apps/details?id=de.tu_chemnitz.mi.kahst.birdnet_live) и в [App Store](https://apps.apple.com/us/app/birdnet-live/id6776168518).

На Android приложение можно установить и вручную из подписанного APK: скачайте последний выпуск со [страницы релизов на GitHub](https://github.com/birdnet-team/birdnet-live-app/releases/latest), перенесите файл `.apk` на телефон и откройте его для установки. Возможно, сначала потребуется разрешить в настройках устройства установку из неизвестных источников.

> **Примечание:** APK занимает около 260 МБ, поскольку включает файлы модели BirdNET+ и все изображения видов для работы офлайн.

## Разработчикам

Смотрите [Developer Guide](developer/index.md) — архитектура, сборка и участие в разработке. Документация для разработчиков доступна только на английском языке.

## Лицензия

Исходный код BirdNET Live распространяется по [лицензии MIT](https://github.com/birdnet-team/birdnet-live-app/blob/main/LICENSE). Входящие в комплект веса модели BirdNET распространяются по [лицензии Apache 2.0](https://github.com/birdnet-team/birdnet-live-app/blob/main/MODEL_LICENSE).
