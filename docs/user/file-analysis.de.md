# Dateianalyse

Die Dateianalyse verarbeitet eine vorhandene Aufnahme über dieselbe BirdNET-Pipeline, die auch die Live-Workflows antreibt.

## So öffnen Sie sie

Tippen Sie auf der Startseite auf die Karte **Dateianalyse** mit dem Symbol :app-audioFileRounded:.

### Aus einer anderen App

Sie können eine Aufnahme auch aus einer anderen App übergeben. Unter Android öffnet das Teilen einer Audiodatei mit **BirdNET Live** oder **Öffnen mit** sofort die Dateianalyse. Unter iOS funktioniert **Öffnen mit** ebenfalls sofort; öffnen Sie BirdNET Live nach dem Teilen-Menü oder kehren Sie dorthin zurück, damit die wartende Aufnahme automatisch ausgewählt wird. Vor der Analyse kopiert die App die Aufnahme in ihren eigenen temporären Speicher.

## App-Leiste

- :app-tuneRounded: — Dateianalyse-Einstellungen öffnen
- :app-helpOutlineRounded: — Dateianalyse-Hilfe öffnen
- :app-close: — einen laufenden Analyselauf abbrechen

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

- aktuelles GPS verwenden :app-myLocation:
- Koordinaten manuell eingeben :app-editLocationAlt:
- den Standort überspringen :app-locationOff:
- einen Punkt auf der Karte wählen :app-mapSheet:
- ein optionales Aufnahmedatum festlegen :app-calendarTodayRounded:

### 3. Parameter

Der Assistent zeigt:

- Fensterdauer
- Überlappung
- Empfindlichkeit
- Konfidenzschwelle
- Modus des Artenfilters

| Einrichtungselement | Symbol |
|---|---|
| Fensterdauer | :app-timerOutlined: |
| Überlappung | :app-swapHoriz: |
| Empfindlichkeit | :app-hearing: |
| Konfidenzschwelle | :app-verifiedRounded: |
| Artenfilter | :app-filterAltRounded: |

Tippen Sie auf die Schaltfläche :app-helpOutline: neben einem Einrichtungselement, um eine Erklärung zu erhalten. Auch die Schritte für Datei, Standort und Aufnahmedatum haben Hilfeschaltflächen.

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
