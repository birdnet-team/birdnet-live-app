# Live-Modus

Der Live-Modus ist die schnellste Möglichkeit, über das Smartphone-Mikrofon zuzuhören und Detektionen in Echtzeit zu prüfen, sobald sie erscheinen.

## So öffnen Sie ihn

Tippen Sie auf dem Startbildschirm auf die Karte **Live-Modus** mit dem Symbol :material-microphone:.

## Widget „Schnell lauschen“

**Nur Android.** Ein Widget auf dem Startbildschirm beginnt mit einem einzigen Tippen zuzuhören, ohne dass Sie zuerst die App öffnen und dorthin navigieren müssen — praktisch, wenn Sie etwas hören, das Sie bestimmen möchten, bevor es verstummt.

Fügen Sie es wie jedes andere Widget hinzu: Halten Sie eine freie Stelle auf dem Startbildschirm gedrückt, tippen Sie auf **Widgets**, suchen Sie **BirdNET Live** und ziehen Sie eine der beiden Kacheln heraus.

- **Schnell lauschen** (2×1) — Symbol mit der Beschriftung **Zuhören starten**
- **Schnell lauschen (kompakt)** (1×1) — nur Symbol

Beide tun dasselbe. Ein Tippen auf eine der beiden öffnet den Live-Modus und beginnt sofort zuzuhören, unabhängig davon, wie die Einstellung **Aufnahme automatisch starten** gesetzt ist. Das Widget ändert diese Einstellung nicht.

Ist der Live-Modus bereits geöffnet, kehrt das Widget zu genau diesem Bildschirm zurück, statt ihn neu aufzubauen. Eine laufende oder pausierte Session bleibt unverändert; ist sie gestoppt, beginnt das Zuhören auf dem vorhandenen Bildschirm.

Quick Listen ersetzt niemals einen anderen laufenden Modus. Wenn eine Point Count-, Survey-, File Analysis- oder [ARU-Modus](aru-mode.md)-Session läuft oder gestartet wird, holt die App sich in den Vordergrund und fordert Sie auf, diese Session zuerst zu beenden. Bildschirm und Arbeit bleiben erreichbar und werden nicht unterbrochen.

## Obere Leiste

Die obere Leiste enthält drei Elemente:

- :material-arrow-left: – Live-Modus verlassen
- mittlerer Statustext – `Initialisierung`, `Modell wird geladen`, `Bereit`, `Arten werden identifiziert`, `Pausiert` oder `Fehler`
- :material-tune: – die Live-spezifische Einstellungsansicht öffnen

## Hauptaktionsschaltfläche

Die große runde Schaltfläche unten in der Mitte wechselt ihren Zustand:

- :material-microphone: – Zuhören starten
- :material-stop: – die aktive Session stoppen
- :material-play: – aus einem pausierten Bereitschaftszustand fortsetzen

## Was Sie beim Zuhören sehen

### Spektrogramm

Das Spektrogramm scrollt kontinuierlich, solange die Erfassung aktiv ist. Es zeigt den Frequenzinhalt im Zeitverlauf und nutzt die Farbkarte, die FFT-Größe, den Frequenzbereich und die Dauer, die in den Einstellungen konfiguriert sind.

### Detektionsliste

Aktuelle Detektionen erscheinen unterhalb des Spektrogramms. Jede Zeile kann Folgendes anzeigen:

- Artenbild
- gebräuchlicher Name
- optionaler wissenschaftlicher Name
- Konfidenzwert

Tippen Sie auf eine Artenzeile, um die Einblendung mit den Artendetails zu öffnen.

### Session-Infoleiste

Die kompakte Infozeile unter dem Spektrogramm fasst die aktuelle Session zusammen, zum Beispiel:

- derzeit angezeigte Detektionen
- Anzahl der eindeutigen Arten (`spp`)
- Gesamtzahl der Detektionen (`det`)
- verstrichene Dauer
- geschätzte Aufnahmegröße, wenn die Aufnahme aktiviert ist

## Aufnahmeverhalten

Die Aufnahme wird in den [Einstellungen](settings.md) gesteuert.

- **Vollständig** zeichnet die gesamte Session auf.
- **Nur Detektionen** zeichnet Clips rund um Detektionen auf.
- **Aus** deaktiviert die Aufnahme.

Wenn Sie den Live-Modus beenden, speichert BirdNET Live die Session und öffnet die [Session-Übersicht](session-review.md).
