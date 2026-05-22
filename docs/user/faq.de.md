# FAQ

Häufig gestellte Fragen.

## Allgemein

**F: Benötigt BirdNET Live eine Internetverbindung?**
A: Nein. Alle Inferenzen werden auf dem Gerät mithilfe des ONNX-Modells ausgeführt. Die einzigen Netzwerkfunktionen sind Artenbild-/Beschreibungssuchen aus der Taxonomie-API, die optional sind.

**F: Wie viele Arten können identifiziert werden?**
A: Das BirdNET+ V3.0-Modell identifiziert 5.250 Vogelarten weltweit (die beschnittene Schnittmenge von Audioklassifikator und Geomodell).

**F: Welche Plattformen werden unterstützt?**
A: Android (8.0+), iOS (15.0+) und Windows (experimentell).

## Genauigkeit

**F: Warum zeigt mein Konfidenzschwellenwert niedrige Werte an?**
A: Senken Sie den Konfidenzschwellenwert in den Einstellungen, um mehr Detektionen zu sehen. Hintergrundgeräusche, Wind und Entfernung beeinflussen die Genauigkeit.

**F: Was macht der Artenfilter?**
A: Das Geomodell sagt voraus, welche Arten an Ihrem GPS-Standort und zur Jahreszeit wahrscheinlich sind. Aktivieren Sie „Geo Exclude“, um unwahrscheinliche Arten auszublenden, oder „Geo Merge“, um die Ergebnisse nach geografischer Wahrscheinlichkeit zu gewichten.

**F: Wie genau ist die Identifizierung?**
A: Die Genauigkeit hängt von der Aufnahmequalität, der Entfernung, dem Hintergrundgeräusch und der Art ab. Detektionen mit hoher Zuverlässigkeit (>70 %) sind im Allgemeinen zuverlässig. Überprüfen Sie seltene Arten immer visuell.

## Aufnahme

**F: Wo werden Aufnahmen gespeichert?**
A: Im Dokumentenverzeichnis der App unter „recordings/<session-id>/“. Vollständige Aufnahmen werden als WAV-Dateien gespeichert.

**F: Kann ich vorhandene Aufzeichnungen analysieren?**
A: Ja. Öffnen Sie die Dateianalyse auf dem Startbildschirm, wählen Sie eine Audiodatei aus, legen Sie den Speicherort und die Parameter fest und tippen Sie auf „Analysieren“. Zu den unterstützten Formaten gehören WAV, FLAC, MP3, OGG, Opus, M4A, AAC, WMA und AMR.

## Punkteanzahl

**F: Was ist der Punktzählmodus?**
A: Ein zeitgesteuerter Vermessungsmodus für formelle Vogelpunktzählungsbeobachtungen. Sie legen eine feste Dauer (3–20 Minuten) und einen festen Ort fest, dann läuft die App kontinuierlich und stoppt automatisch, wenn der Timer Null erreicht.

**F: Kann ich eine Punktezählung pausieren?**
A: Nein. Die Einhaltung des Protokolls erfordert eine unterbrechungsfreie Aufzeichnung. Über den Stopp-Button können Sie vorzeitig beenden.

**F: Wohin gehen die Ergebnisse der Punktezählung?**
A: Sie erscheinen in der Sitzungsbibliothek als „Punktzahl Nr. 1“, „Nr. 2“ usw. Sie können sie wie jede andere Sitzung überprüfen, bearbeiten und exportieren.

## Leistung

**F: Warum ist die App warm bzw. verbraucht sie Akku?**
A: Die ONNX-Modellinferenz ist rechenintensiv. Der Bildschirm bleibt auch während Live-Sitzungen eingeschaltet. Dies ist normal für die Echtzeitverarbeitung neuronaler Netzwerke.

**F: Das Spektrogramm sieht eingefroren aus.**
A: Stellen Sie sicher, dass die Mikrofonberechtigung erteilt wurde und die Audioaufnahme aktiv ist. Stellen Sie sicher, dass keine andere App das Mikrofon verwendet.