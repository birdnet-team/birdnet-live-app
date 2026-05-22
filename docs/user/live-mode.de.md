# Live-Modus

Der Live-Modus ist die schnellste Möglichkeit, über das Telefonmikrofon zuzuhören und Detektionen sofort zu überprüfen.

## So öffnen Sie es

Tippen Sie auf dem Startbildschirm auf die Karte **Live-Modus** mit dem Symbol :material-microphone:.

## Obere Leiste

Die obere Leiste enthält drei Elemente:

- :material-arrow-left: – Live-Modus verlassen
- mittlerer Statustext – „Initialisierung“, „Modell wird geladen“, „Bereit“, „Art wird identifiziert“, „Pausiert“ oder „Fehler“.
- :material-tune: – Öffnet die Ansicht „Live-spezifische Einstellungen“.

## Hauptaktionsschaltfläche

Die große kreisförmige Schaltfläche unten in der Mitte ändert ihren Status:

- :material-microphone: – fang an zuzuhören
- :material-stop: – Stoppt die aktive Sitzung
- :material-play: – Fortsetzung aus einem angehaltenen Bereitschaftszustand

## Was Sie beim Zuhören sehen

### Spektrogramm

Das Spektrogramm scrollt kontinuierlich, während die Erfassung aktiv ist. Es zeigt den Frequenzinhalt im Zeitverlauf an und verwendet die Farbkarte, die FFT-Größe, den Frequenzbereich und die Dauer aus den Einstellungen.

### Detektionsliste

Aktuelle Detektionen werden unterhalb des Spektrogramms angezeigt. Jede Zeile kann Folgendes anzeigen:

- Artenbild
- gebräuchlicher Name
- optionaler wissenschaftlicher Name
- Vertrauenswert

Tippen Sie auf eine Artenzeile, um die Überlagerung mit den Artendetails zu öffnen.

### Sitzungsinfoleiste

Die kompakte Infozeile unter dem Spektrogramm fasst die aktuelle Sitzung zusammen, zum Beispiel:

- Aktuelle Detektionen werden jetzt angezeigt
- Anzahl einzigartiger Arten („spp“)
- Gesamtdetektionen („det“)
- verstrichene Dauer
- geschätzte Aufnahmegröße, wenn die Aufnahme aktiviert ist

## Aufnahmeverhalten

Die Aufnahme wird in den [Einstellungen] (settings.md) gesteuert.

- **Full** zeichnet die gesamte Sitzung auf.
- **Nur Detektionen** zeichnet Clips rund um Detektionen auf.
- **Aus** deaktiviert die Aufnahme.

Wenn Sie den Live-Modus beenden, speichert BirdNET Live die Sitzung und öffnet [Sitzungsüberprüfung] (session-review.md).