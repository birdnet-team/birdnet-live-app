# Sitzungsrückblick

Bei der Sitzungsüberprüfung wandelt BirdNET Live Erkennungen in einen bearbeitbaren Datensatz um.

## Wie Sie es erreichen

BirdNET Live öffnet die Sitzungsüberprüfung automatisch, nachdem Folgendes abgeschlossen wurde:

- eine Live-Sitzung
- eine Punktezählung
- eine Umfrage
- ein Dateianalyselauf

Sie können jede gespeicherte Sitzung auch über die [Sitzungsbibliothek](session-library.md) erneut öffnen.

## Hauptbereiche

### Zusammenfassung und Wiedergabe

Session Review kombiniert Wiedergabe, Spektrogrammnavigation und eine Artenliste. Für Umfragesitzungen kann auch der zugeordnete Kontext angezeigt werden.

### Artenliste

Arten werden in erweiterbaren Reihen gruppiert. Sie können Erkennungen nach Arten untersuchen und sich durch die Aufzeichnung bewegen, während Sie sie überprüfen.

### Vermessungs-Streckenkarte

Bei Umfragesitzungen wird eine kleine Inline-Karte des GPS-Tracks und der Erkennungsmarkierungen angezeigt. Tippen Sie darauf, um eine **Vollbildkarte** mit denselben Daten zu öffnen.

Die App-Leiste der Vollbildkarte verfügt über eine :material-filter-list-outlined: **Filter**-Schaltfläche, die ein Blatt zum Einschränken der angezeigten Markierungen öffnet. Verfügbare Filter:

- **Alle Erkennungen** (Standard).
- **Mit Audioclip** – nur Erkennungen, deren Clip noch auf der Festplatte vorhanden und abspielbar ist.
- **Hohe Konfidenz** – nur Erkennungen mit einer Konfidenz von oder über 80 %.
- **Manuelle Hinzufügungen** – nur Erkennungen, die Sie in der Sitzungsüberprüfung hinzugefügt haben (automatisch erkannte ausgenommen).

Unterhalb der Modusauswahl befindet sich die Option **Auf Arten beschränken**, mit der Sie die Karte auf eine einzelne Art reduzieren können – nützlich, wenn Sie fragen möchten: „Wo genau auf der Route habe ich die Walddrossel gehört?“. Durch den Eintrag „Alle Arten“ wird die Artenbeschränkung aufgehoben. Die beiden Filter kombinieren: z.B. *Mit Audioclip* + *Wood Thrush* zeigt nur die spielbaren Wood Thrush-Markierungen.

Wenn ein Filter aktiv ist, erhält der Titel der App-Leiste einen Untertitel mit Übereinstimmungsanzahl (z. B. *„7 Erkennungen“*) und auf der Filterschaltfläche wird ein kleiner Punkt angezeigt. *Zurücksetzen* im Blatt stellt den Standardwert wieder her.

## Symbolleistensymbole

Die Symbolleiste verwendet dieselben Symbolbedeutungen, die in [Symbole und Steuerelemente](icons-and-controls.md) beschrieben sind:

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

- Überprüfen Sie die Erkennungen anhand des Wiedergabe- und Spektrogrammkontexts
- Fügen Sie eine Art oder Anmerkung hinzu
- Schneiden Sie die Aufnahme auf das sinnvolle Intervall
- Exportieren Sie den überprüften Ergebnissatz

## Exportieren

Das Exportverhalten hängt von den in [Einstellungen](settings.md) ausgewählten Optionen ab. Die App kann Erkennungen und optional Audio in das gewählte Exportformat packen. Jeder Export wird jetzt mit vollständigen Herkunftsmetadaten ausgeliefert – App-Version, Modellname und -version, Gebietsschema der Art, Exportzeitstempel und eine Momentaufnahme aller Einstellungen zum Zeitpunkt des Exports – geschrieben in eine `"<prefix>.metadata.json"`-Seitendatei (ZIP) oder einen `"Meta"`-Block der obersten Ebene (JSON), sodass Exporte selbstbeschreibend und reproduzierbar sind.
