# BirdNET Live

**Professionelle Bioakustik in der Hosentasche.**

BirdNET Live ist eine Flutter-App für Feldforschende, im Naturschutz Tätige und Vogelbegeisterte, die im Feld auf verlässliche akustische Nachweise angewiesen sind. Der BirdNET+ Audio-Klassifikator und das Geo-Modell laufen direkt auf Ihrem Gerät, sodass die Artbestimmung nach der Installation vollständig offline funktioniert.

<p align="center">
  <img src="https://img.shields.io/badge/latest-v0.19.5-orange.svg" alt="Latest release: v0.19.5">
  <img src="https://img.shields.io/badge/species-9%2C789-brightgreen.svg" alt="Species: 9,789">
  <img src="https://img.shields.io/badge/platforms-Android%20%7C%20iOS%20%7C%20Windows-green.svg" alt="Platforms">
</p>

## Features

- **Live-Modus** - Echtzeit-Spektrogramm mit fortlaufendem Bildlauf und Artbestimmung
- **Point-Count-Modus** - Zeitlich begrenzte Sessions mit Countdown-Timer und Stationsmetadaten
- **Survey-Modus** - Langlaufende Transekt-Surveys mit GPS-Tracking, Hintergrundüberwachung und Detektions-Sampling
- **Dateianalyse** - Offline-Analyse vorhandener Aufnahmen (WAV, FLAC, MP3, OGG und mehr)
- **Erkunden** - Durchsuchen Sie die für Ihren Standort erwarteten Arten mithilfe des BirdNET-Geo-Modells
- **Session-Bibliothek** - Vergangene Sessions ansehen, bearbeiten und mit Audiowiedergabe exportieren
- **Export** - Formate Raven Pro, CSV, JSON, GPX und ZIP-Bundle mit Herkunftsmetadaten
- **On-Device-Inferenz** - BirdNET+ Modellabdeckung für 5.250 Arten, kein Internet erforderlich
- **FLAC-Aufnahme** - Komprimierte Audioaufnahme mit kleineren Dateien für lange Surveys
- **Barrierefreiheit** - Screenreader-Beschriftungen, Tooltips und optionale gesprochene Ansagen von Detektionen
- **Responsive Layouts** - Anpassbare Oberflächen für Smartphone, Tablet, Hoch- und Querformat

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

## Schnellstart

Im [Benutzerhandbuch](user/index.md) finden Sie einen Überblick. Öffnen Sie anschließend [Erste Schritte](user/getting-started.md), um BirdNET Live zu installieren und auszuführen.

## Unter Android installieren

BirdNET Live ist als signiertes APK zum Sideloading verfügbar. Laden Sie die neueste Version von der [GitHub-Releases-Seite](https://github.com/birdnet-team/birdnet-live-app/releases/latest) herunter, übertragen Sie die `.apk`-Datei auf Ihr Smartphone und öffnen Sie sie zur Installation. Möglicherweise müssen Sie in den Geräteeinstellungen zunächst die Installation aus unbekannten Quellen erlauben.

> **Hinweis:** Das APK ist etwa 253 MB groß, da es die BirdNET+ Modelldaten für die Offline-Inferenz enthält.

## Für Entwicklerinnen und Entwickler

Im [Entwicklerhandbuch](developer/index.md) finden Sie Informationen zu Architektur, Build und Mitwirkung.

## Lizenz

Der Quellcode von BirdNET Live ist Open Source unter der [MIT-Lizenz](https://github.com/birdnet-team/birdnet-live-app/blob/main/LICENSE). Die gebündelten BirdNET-Modellgewichte sind unter der [Apache License 2.0](https://github.com/birdnet-team/birdnet-live-app/blob/main/MODEL_LICENSE) lizenziert.
