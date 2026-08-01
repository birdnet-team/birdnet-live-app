# Erste Schritte

## Installation

BirdNET Live ist für Android, iOS und Windows verfügbar.

### Anforderungen

- **Android**: 8.0 (API 26) oder höher
- **iOS**: 15.0 oder höher
- **Windows**: 10 oder höher (experimentell)
- ~300 MB Speicher für App + Modelle

### Herunterladen

- **Android** – [Google Play Store](https://play.google.com/store/apps/details?id=de.tu_chemnitz.mi.kahst.birdnet_live), oder laden Sie das signierte APK von der [GitHub-Releases-Seite](https://github.com/birdnet-team/birdnet-live-app/releases/latest) herunter.
- **iOS** – [App Store](https://apps.apple.com/us/app/birdnet-live/id6776168518).
- **Windows** – aus dem Quellcode bauen; siehe [Entwicklerhandbuch](../developer/building.md).

## Ablauf beim ersten Öffnen

Wenn Sie BirdNET Live zum ersten Mal öffnen, führt die App Sie durch einen kurzen Onboarding-Ablauf und die Einrichtung der Berechtigungen.

1. Lesen Sie die Onboarding-Bildschirme.
2. Lesen Sie die Richtlinie zur akzeptablen Nutzung und die Datenschutzerklärung.
3. Erteilen Sie die Mikrofonberechtigung, damit BirdNET Live Audio verarbeiten kann.
4. Erlauben Sie optional die Standortberechtigung für Geotagging, Erkunden, Point Count und Survey.
5. Erlauben Sie optional Benachrichtigungen für langlaufende Surveys.

## Erster Start

1. **Onboarding** – Kurze Einführung in Funktionen und Berechtigungen
2. **Akzeptable Nutzung und Datenschutz** – Richtlinie zur akzeptablen Nutzung und Datenschutzerklärung lesen
3. **Berechtigungen** – Mikrofonzugriff gewähren (für alle Modi erforderlich)
4. **Fertig** – Los geht's mit der Vogelbestimmung!

## Überblick über den Startbildschirm

Der Startbildschirm ist die zentrale Anlaufstelle.

### Karten der Hauptmodi

- :material-microphone: **Live-Modus**
- :material-map-marker: **Point-Count-Modus**
- :material-routes: **Survey-Modus**
- :material-file-music: **Dateianalyse**

### Schaltflächen in der Fußzeile

- :material-tune: **Einstellungen**
- :material-magnify: **Erkunden**
- :material-music-box-multiple-outline: **Session-Bibliothek**
- :material-help-circle-outline: **Hilfe**
- :material-information-outline: **Über**

## Was gespeichert wird

BirdNET Live speichert jede abgeschlossene Session automatisch und öffnet sie in der Session-Übersicht, sobald die Verarbeitung stoppt.

- Live-Sessions speichern Detektionen und – je nach Ihren Einstellungen – Aufnahmen oder Clips.
- Point-Count-Sessions werden als zeitgesteuerte Point-Count-Sessions gespeichert.
- Survey-Sessions speichern die Route, die Detektionen und zugehörige Metadaten.
- Die Ergebnisse der Dateianalyse werden in eine prüfbare Session umgewandelt.

## Empfohlene nächste Seiten

- Lesen Sie [Symbole und Steuerelemente](icons-and-controls.md), wenn Sie eine kurze Erklärung der wiederkehrenden UI-Symbole möchten.
- Lesen Sie [Einstellungen](settings.md), bevor Sie Schwellenwerte, Filter, Aufnahmeverhalten oder die Spektrogrammanzeige ändern.
- Öffnen Sie die Anleitung für den Arbeitsablauf, den Sie am häufigsten verwenden: [Live-Modus](live-mode.md), [Point-Count-Modus](point-count-mode.md), [Survey-Modus](survey-mode.md) oder [Dateianalyse](file-analysis.md).

## Berechtigungen

| Berechtigung | Erforderlich für | Optional? |
|------------|-------------|-----------|
| Mikrofon | Alle Aufnahmemodi | Erforderlich |
| Standort | GPS-Tagging, Survey/Point Count | Optional für Live |
| Speicher | Aufnahmen speichern, Exporte | Für die Aufnahme erforderlich |
| Benachrichtigungen | Warnungen bei Surveys im Hintergrund | Optional |
