# Sitzungsrückblick

Bei der Sitzungsüberprüfung wandelt BirdNET Live Detektionen in einen bearbeitbaren Datensatz um.

## Wie Sie es erreichen

BirdNET Live öffnet die Sitzungsüberprüfung automatisch, nachdem Folgendes abgeschlossen wurde:

- eine Live-Sitzung
- eine Punktezählung
- eine Umfrage
- ein Dateianalyselauf

Sie können jede gespeicherte Sitzung auch über die [Sitzungsbibliothek] (session-library.md) erneut öffnen.

## Hauptbereiche

### Zusammenfassung und Wiedergabe

Session Review kombiniert Wiedergabe, Spektrogrammnavigation und eine Artenliste. Für Umfragesitzungen kann auch der zugeordnete Kontext angezeigt werden.

Der Zusammenfassungs-Header oben trägt das Datum, einen Standort-Chip (Lat/Lon plus optionaler aufgelöster Ortsname, wenn **Einstellungen → Datenschutz → Ortsnamen-Suche erlauben** aktiv ist) und – wenn **Einstellungen → Datenschutz → Wetterabfrage erlauben** zum Aufnahmezeitpunkt aktiv war – eine **Wetterzeile** unter dem Standort, die die am Sitzungsende erfassten Bedingungen zeigt: ein Einzeiler wie *„20,1 °C · Leichter Regen · 3,2 m/s SW“* mit vorangestelltem Wettersymbol. Tippe die Zeile an, um ein kleines Sheet mit Temperatur, Wind, Niederschlag und Bewölkung sowie der Open-Meteo-Quellenangabe einzublenden. Derselbe Snapshot wandert in den JSON-Export, den Metadaten-Block und den HTML-Bericht.

### Artenliste

Arten werden in erweiterbaren Reihen gruppiert. Sie können Detektionen nach Arten untersuchen und sich durch die Aufzeichnung bewegen, während Sie sie überprüfen.

### Vermessungs-Streckenkarte

Bei Umfragesitzungen wird eine kleine Inline-Karte des GPS-Tracks und der Detektionsmarkierungen angezeigt. Tippen Sie auf der Inline-Karte auf eine Markierung, um eine Detektion zu fokussieren – die Karte zentriert sich darauf. Tippen Sie auf die :material-fullscreen: **Vergrößern**-Schaltfläche (oben rechts auf der Inline-Karte), um die **Vollbildkarte** zu öffnen; wenn eine Detektion fokussiert war, öffnet sich die Vollbildkarte zentriert und herangezoomt auf diese Detektion, sodass Sie Ihren Platz behalten.

#### Markierungs-Kodierung

- **Konfidenz wird farbcodiert** mit einer farbenblindheitssicheren (CVD) Skala: Niedrige bis hohe Konfidenz verläuft von Lila-Blau über Türkis/Gelb bis Rot. Die Helligkeit der Skala ändert sich monoton, sodass sie auch in Schwarzweiß und für Nutzer mit Rot-Grün-Sehschwäche lesbar bleibt.
- **Detektionen mit Audio** zeigen einen farbigen Ring um das Artenfoto plus ein Wiedergabe-Abzeichen in der Ecke – tippen Sie darauf, um den aufgezeichneten Clip in einem Blatt abzuspielen.
- **Stille Detektionen** (kein Clip auf der Festplatte) werden kleiner, ausgeblichen und mit einem neutral-grauen Ring dargestellt, damit Audio-Detektionen immer als Hauptinhalt erkennbar sind.
- **Überlappende Markierungen am gleichen Ort** werden nach Wichtigkeit z-geordnet: hervorgehoben > mit Audio > höhere Konfidenz, sodass eine stille Markierung mit niedriger Konfidenz nie eine starke Audio-Detektion verdecken kann.
- **Unterhalb von Zoomstufe 14,5** werden Silhouetten zu farbigen, nach Konfidenz dimensionierten Punkten reduziert, und dichte Cluster werden zu einer Zählblase zusammengefasst (Clustering wird ab Zoomstufe 15 deaktiviert).

#### Filterung

Die Vollbildkarte hat einen permanenten **Filter-Chip**, oben rechts auf der Karte verankert. Tippen Sie darauf, um das Filterblatt zu öffnen; das Label des Chips zeigt immer an, was aktuell aktiv ist (*„Alle Arten“*, *„Mit Audio“*, *„≥ 80 %“* oder ein einzelner Artname). Verfügbare Filter:

- **Alle Detektionen** (Standard).
- **Mit Audioclip** – nur Detektionen, deren Clip noch auf der Festplatte vorhanden und abspielbar ist.
- **Manuelle Hinzufügungen** – nur Detektionen, die Sie in der Sitzungsüberprüfung hinzugefügt haben (automatisch erkannte ausgenommen).

Sie können Detektionen außerdem nach Konfidenzniveau einschränken. Der Schieberegler stellt die Mindestkonfidenz ein (beginnt bei 10 %).

Unterhalb des Konfidenz-Schiebereglers befindet sich die Option **Auf Arten beschränken**, mit der Sie die Karte auf eine einzelne Art reduzieren können – nützlich, wenn Sie fragen möchten: „Wo genau auf der Route habe ich die Walddrossel gehört?“. Durch den Eintrag *Alle Arten* wird die Artenbeschränkung aufgehoben. Die Filter kombinieren: z. B. *Mit Audioclip* + *Wood Thrush* + *> 80 %* zeigt nur die spielbaren Wood-Thrush-Markierungen, die über 80 % erreicht haben.

Wenn ein Filter aktiv ist, erhält der Titel der App-Leiste einen Untertitel mit Übereinstimmungsanzahl (z. B. *„7 Detektionen“*). *Zurücksetzen* im Blatt stellt den Standardwert wieder her.

## Symbolleistensymbole

Die Symbolleiste verwendet dieselben Symbolbedeutungen, die in [Symbole und Steuerelemente] (icons-and-controls.md) beschrieben sind:

- :material-plus-circle-outline: — Inhalt hinzufügen
- :material-undo-variant: / :material-redo-variant: – Schritt für Schritt durch die Bearbeitungen
- :material-content-cut: – Trimmmodus
- :material-content-save: – Änderungen speichern
- :material-share-variant: – exportieren oder teilen
- :material-delete-outline: – Sitzung verwerfen
- :material-play: – Setzen Sie eine Umfrage fort, wenn diese Aktion verfügbar ist
- :material-help-circle-outline: – Öffnen Sie das Hilfeblatt zur Sitzungsüberprüfung
- :material-tune: — Einstellungen öffnen

## Typische Überprüfungsaufgaben

- Überprüfen Sie die Detektionen anhand des Wiedergabe- und Spektrogrammkontexts
- Fügen Sie eine Art oder Anmerkung hinzu
- Schneiden Sie die Aufnahme auf das sinnvolle Intervall
- Exportieren Sie den überprüften Ergebnissatz

## Exportieren

Das Exportverhalten hängt von den in [Einstellungen] (settings.md) ausgewählten Optionen ab. Die App kann Detektionen und optional Audio in das gewählte Exportformat packen. Jeder Export wird jetzt mit vollständigen Herkunftsmetadaten ausgeliefert – App-Version, Modellname und -version, Gebietsschema der Art, Exportzeitstempel und eine Momentaufnahme aller Einstellungen zum Zeitpunkt des Exports – geschrieben in eine „<prefix>.metadata.json“-Seitendatei (ZIP) oder einen „Meta“-Block der obersten Ebene (JSON), sodass Exporte selbstbeschreibend und reproduzierbar sind.