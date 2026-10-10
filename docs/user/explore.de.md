# Erkunden

Erkunden zeigt mithilfe des BirdNET-Geo-Modells die Arten, die für den aktuellen Standort und die aktuelle Jahreszeit vorhergesagt werden.

## So öffnen Sie es

Öffnen Sie **Erkunden** in der Fußzeile der Startseite über die Schaltfläche :app-searchRounded:.

## App-Leiste und Kopfzeile

### App-Leiste

- :app-refresh: – Standort aktualisieren und die Liste der vorhergesagten Arten neu aufbauen

### Standort-Kopfzeile

Die Kopfzeile zeigt:

- den aktuellen, per Reverse-Geocoding ermittelten Ortsnamen, sofern verfügbar
- die Koordinaten unter dem Ortsnamen
- :app-helpOutlineRounded: – das Hilfeblatt zu Erkunden öffnen

## Artenliste

Jede Artenkarte kann Folgendes enthalten:

- mitgeliefertes Artenbild
- gebräuchlicher Name
- optionaler wissenschaftlicher Name
- Häufigkeitsstufen-Chip

Tippen Sie auf eine Karte, um die Einblendung mit den Artendetails zu öffnen.

### Häufigkeitsstufen

Statt eines rohen Prozentwerts zeigt jede Karte eine **Häufigkeitsstufe** für den aktuellen Ort und die Jahreszeit. Der Stufen-Chip vereint zwei Hinweise:

- einen **Kreis**, der sich von ⅙ bis vollständig füllt, je wahrscheinlicher die Art ist
- den **ersten Buchstaben** des Stufennamens (der vollständige Name wird von Screenreadern vorgelesen und in den Artendetails angezeigt)

Die Farbe des Chips folgt der gemeinsamen Bewertungsskala der App und wandert von Rot (unwahrscheinlicher) zu Grün (wahrscheinlicher), je höher die Stufe.

Es gibt sechs Stufen, von am wahrscheinlichsten bis am wenigsten wahrscheinlich:

| Stufe | Bedeutung |
| --- | --- |
| **Zahlreich** | Zu den stärksten Vorhersagen hier |
| **Häufig** | Sehr wahrscheinlich |
| **Verbreitet** | Wahrscheinlich |
| **Mäßig** | Möglich |
| **Spärlich** | Unwahrscheinlich |
| **Rar** | Zu den schwächsten Vorhersagen hier |

Die Stufen sind **relativ zum aktuellen Standort**. Sie passen sich daran an, wie stark das Geo-Modell Arten in diesem Gebiet vorhersagt, sodass sich die Grenzen mit der lokalen Score-Verteilung verschieben: An einem Ort mit vielen sicheren Vorhersagen braucht eine Art einen sehr hohen Score, um *Zahlreich* zu sein, während in einem Gebiet mit schwächeren Vorhersagen dieselbe Stufe bei einem niedrigeren Score erreicht wird. Derselbe Score kann also an verschiedenen Orten in verschiedene Stufen fallen, wodurch die Rangfolge überall aussagekräftig bleibt.

## Einblendung der Artendetails

Die Einblendung kann Folgendes anzeigen:

- größeres Bild
- Bildnachweis
- gebräuchliche und wissenschaftliche Namen
- mitgelieferter Beschreibungstext, sofern verfügbar
- wöchentliches Diagramm mit der erwarteten Häufigkeit
- externe Links wie eBird, iNaturalist oder Wikipedia, sofern für diese Art verfügbar

## Wofür Erkunden da ist

Erkunden ist eine standortbezogene Referenzansicht innerhalb der App. Es hilft Ihnen, den aktuellen Standortkontext der App mit den Arten zu vergleichen, denen Sie wahrscheinlich begegnen werden.

Gespeicherte Session-Daten werden dadurch **nicht** verändert. Die Detektionsfilterung wird separat über die [Einstellungen](settings.md) gesteuert.