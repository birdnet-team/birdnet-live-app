# Dateianalyse

Die Dateianalyse verarbeitet eine vorhandene Aufnahme über dieselbe BirdNET-Pipeline, die auch die Live-Workflows antreibt.

## So öffnen Sie sie

Tippen Sie auf der Startseite auf die Karte **Dateianalyse** mit dem Symbol :material-file-music:.

## App-Leiste

- :material-tune: — Dateianalyse-Einstellungen öffnen
- :material-close: — einen laufenden Analyselauf abbrechen

## Unterstützte Eingaben

Die aktuelle Dateiauswahl akzeptiert:

- WAV / WAVE
- FLAC
- MP3
- OGG / OGA / Opus
- M4A / AAC / MP4
- WMA / AMR

## Vierstufiger Assistent

### 1. Datei auswählen

Wählen Sie eine Datei und prüfen Sie ihre Metadatenkarte:

- Dateiname
- Format
- Dauer
- Dateigröße
- Abtastrate

### 2. Standort und Datum

Sie können:

- aktuelles GPS verwenden
- Koordinaten manuell eingeben
- den Standort überspringen
- einen Punkt auf der Karte wählen
- ein optionales Aufnahmedatum festlegen

### 3. Parameter

Der Assistent zeigt:

- Fensterdauer
- Überlappung
- Empfindlichkeit
- Konfidenzschwelle
- Modus des Artenfilters

Die Überlappung bestimmt, um wie viel jedes Analysefenster vorrückt, und ist
spezifisch für die Dateianalyse: Die gesamte Datei wird immer untersucht, mehr
Überlappung untersucht sie lediglich feiner. Die Live-Modi verwenden
stattdessen eine Inferenzrate, weil sie entscheiden müssen, wie oft sie auf
eingehendes Audio laufen, und nicht, wie fein sie eine feststehende Aufnahme
abdecken.

Wie die Dateianalyse auch immer zu ihren Fenstern kommt: Sie macht daraus
Detektionen nach denselben Regeln wie Live-Modus, Point Count und Survey. Eine
Detektion beginnt bei ihrem frühesten stützenden Fenster, trägt den stärksten
gestützten Score und endet am Ende des letzten stützenden Fensters.

### 4. Analysieren

Der Fortschrittsbildschirm zeigt:

- verarbeitete Fenster
- gefundene Detektionen
- gefundene Arten
- Abbrechen-Schaltfläche

## Ergebnis

Wenn die Analyse abgeschlossen ist, wandelt BirdNET Live die Ausgabe in eine gespeicherte Session um und öffnet die [Session-Übersicht](session-review.md).
