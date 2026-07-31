# FAQ

Häufig gestellte Fragen.

## Allgemein

**F: Benötigt BirdNET Live eine Internetverbindung?**
A: Nein. Die gesamte Inferenz läuft auf dem Gerät mithilfe des ONNX-Modells. Die einzigen Netzwerkfunktionen sind optional und standardmäßig deaktiviert: Kartenkacheln und Ortsnamen-Suche von OpenStreetMap, Wettermomentaufnahmen von Open-Meteo sowie Abfragen von Artenbildern und -beschreibungen aus der Taxonomie-API. Siehe [Einstellungen → Datenschutz](settings.md#datenschutz).

**F: Wie viele Arten können identifiziert werden?**
A: Das BirdNET+ V3.0-Modell identifiziert 9.789 Arten weltweit – Vögel, Amphibien, Säugetiere und Insekten (die taxonomisch abgeglichene, reduzierte Schnittmenge aus Audio-Klassifikator und Geomodell).

**F: Welche Plattformen werden unterstützt?**
A: Android (8.0+), iOS (15.0+) und Windows (experimentell).

## Genauigkeit

**F: Warum zeigt mein Konfidenzschwellenwert niedrige Werte an?**
A: Senken Sie den Konfidenzschwellenwert in den Einstellungen, um mehr Detektionen zu sehen. Hintergrundgeräusche, Wind und Entfernung beeinflussen die Genauigkeit.

**F: Was macht der Artenfilter?**
A: Das Geo-Modell sagt voraus, welche Arten an Ihrem GPS-Standort und zur jeweiligen Jahreszeit wahrscheinlich sind. Aktivieren Sie **Standortfilter**, um unwahrscheinliche Arten auszublenden, oder **Standortgewichtung**, um die Ergebnisse nach geografischer Wahrscheinlichkeit zu gewichten.

**F: Wie genau ist die Bestimmung?**
A: Die Genauigkeit hängt von der Aufnahmequalität, der Entfernung, dem Hintergrundgeräusch und der Art ab. Detektionen mit hoher Konfidenz (>70 %) sind im Allgemeinen verlässlich. Überprüfen Sie seltene Arten stets visuell.

## Aufnahme

**F: Wo werden Aufnahmen gespeichert?**
A: Im Dokumentenverzeichnis der App unter `recordings/<session-id>/`. Je nach **Einstellungen → Aufnahme → Format** als WAV oder FLAC.

**F: Kann ich vorhandene Aufnahmen analysieren?**
A: Ja. Öffnen Sie die Dateianalyse auf dem Startbildschirm, wählen Sie eine Audiodatei, legen Sie Standort und Parameter fest und tippen Sie auf „Analysieren“. Zu den unterstützten Formaten gehören WAV, FLAC, MP3, OGG, Opus, M4A, AAC, WMA und AMR.

## Point Count

**F: Was ist der Point-Count-Modus?**
A: Ein zeitgesteuerter Survey-Modus für formelle Punkt-Stopp-Zählungen von Vögeln. Sie legen eine feste Dauer (3–20 Minuten) und einen Standort fest; die App läuft dann kontinuierlich und stoppt automatisch, sobald der Timer null erreicht.

**F: Kann ich einen Point Count pausieren?**
A: Nein. Die Einhaltung des Protokolls erfordert eine unterbrechungsfreie Aufnahme. Sie können eine Zählung jedoch über die Stopp-Schaltfläche vorzeitig beenden.

**F: Wohin gelangen die Ergebnisse eines Point Counts?**
A: Sie erscheinen in der Session-Bibliothek als „Point Count #1“, „#2“ usw. Sie können sie wie jede andere Session prüfen, bearbeiten und exportieren.

## Leistung

**F: Warum wird die App warm bzw. verbraucht sie Akku?**
A: Die Inferenz des ONNX-Modells ist rechenintensiv, und der Bildschirm bleibt während Live-Sessions eingeschaltet. Das ist für die Echtzeitverarbeitung neuronaler Netze normal.

**F: Das Spektrogramm sieht eingefroren aus.**
A: Stellen Sie sicher, dass die Mikrofonberechtigung erteilt ist und die Audioaufnahme aktiv ist. Prüfen Sie, dass keine andere App das Mikrofon verwendet.
