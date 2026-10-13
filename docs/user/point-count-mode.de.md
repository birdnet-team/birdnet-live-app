# Point-Count-Modus

Der Point-Count-Modus ist der zeitgesteuerte, stationäre Arbeitsablauf in BirdNET Live.

## So öffnen Sie ihn

Tippen Sie auf der Startseite auf die Karte **Point-Count-Modus** mit dem Symbol :app-locationOnRounded:.

## Einrichtungsablauf

Die Einrichtung eines Point Counts erfolgt in vier Schritten.

### 1. Dauer und Standort

Wählen Sie:

- eine der verfügbaren Dauern: 3, 5, 10, 15, 20, 25 oder 30 Minuten
- ob die Zählung bei ausgeschaltetem Bildschirm weiterläuft (standardmäßig aktiviert)
- aktuelles GPS mit :app-myLocation:
- manuelle Koordinaten mit :app-editLocationAlt:
- keinen Standort mit :app-locationOff:
- die Kartenauswahl mit :app-mapSheet:

Der Einrichtungsbildschirm aktualisiert das GPS, sobald Sie aus dem
System-Berechtigungsdialog oder den App-Einstellungen zurückkehren, sodass eine
neu erteilte Standortberechtigung die Koordinaten aktualisiert, ohne den
Assistenten neu zu starten. Im selben Bereich befindet sich außerdem eine
Wetterkarte. Ist der Wetterzugriff deaktiviert, fragt die Karte die Zustimmung
**Wetterabfrage erlauben** ab; nach der Aktivierung zeigt sie eine Vorschau des
Standorts – allerdings nur mit Wettersymbol, Temperatur und Wind. Beim Speichern
des Point Counts wird dieselbe zwischengespeicherte Open-Meteo-Momentaufnahme
wiederverwendet.

### 2. Inferenzparameter

Wählen Sie sessionspezifische Analyseeinstellungen wie Inferenzrate,
Konfidenzschwelle und Modus des Artenfilters. Diese gehen von Ihren globalen
Einstellungen aus, lassen sich aber für diese Zählung anpassen, ohne Ihre
Standardwerte zu ändern.

| Einrichtungselement | Symbol |
|---|---|
| Mikrofon | :app-micRounded: |
| Aufnahmemodus | :app-fiberManualRecordRounded: |
| Clip-Kontext | :app-timerOutlined: |
| Inferenzrate | :app-speedRounded: |
| Konfidenzschwelle | :app-verifiedRounded: |
| Empfindlichkeit | :app-hearing: |
| Artenfilter | :app-filterAltRounded: |

Die Schaltfläche :app-helpOutline: neben jedem Element erklärt dessen Wirkung. Die Dauerauswahl :app-timerRounded: und die Standortauswahl haben im ersten Schritt dieselbe Hilfeschaltfläche.

Wählen Sie **Vollständig**, um durchgehend Audio zu speichern (Standard), **Clips** für einen Clip je erkannter Lautäußerung oder **Aus**, um kein Audio zu speichern. Diese Auswahl ist unabhängig von der Aufnahmeeinstellung des Live Mode und wird für den nächsten Point Count gespeichert. Clips verwenden dieselbe Auswahl des Spitzenfensters und denselben Clip-Kontext wie Live Mode, ohne standortabhängige Ausdünnung. Bei **Clips** legt der Schieberegler **Clip-Kontext** fest, wie viele Sekunden vor und nach jedem analysierten Fenster erhalten bleiben; er aktualisiert auch den Clip-Kontext des Live Mode.

### 3. Feldtipps

Dieser Bildschirm bietet vor dem Start eine kurze In-App-Checkliste.

### 4. Fertig

Der Bereitschaftsbildschirm fasst Dauer, Aufnahmeauswahl und Verhalten bei ausgeschaltetem Bildschirm zusammen. Starten Sie mit :app-playArrowRounded:.

## Live-Bildschirm des Point Counts

Der Live-Bildschirm des Point Counts konzentriert sich auf ein zeitgesteuertes Dashboard.

### Obere Leiste

- :app-stopRounded: — den Point Count vorzeitig beenden
- :app-timerRounded: — verbleibende Zeit anzeigen
- :app-helpOutlineRounded: — Point-Count-Hilfe öffnen
- :app-tuneRounded: — Point-Count-Einstellungen öffnen

### Hauptanzeigen

- Countdown-Fortschrittsbalken
- kompakte Infoleiste mit aktuellen Detektionen, Anzahl der eindeutigen Arten und Gesamtzahl der Detektionen
- Spektrogrammansicht
- Detektionsliste

## Nach der Zählung

Mit **Bei ausgeschaltetem Bildschirm fortsetzen** in der Point Count-Einrichtung läuft die Zählung beim Sperren des Bildschirms oder Wechseln zu einer anderen App weiter, auch wenn der Bildschirm anbleibt. Sie endet nach der gewählten Dauer; der Countdown verwendet die tatsächlich verstrichene Zeit, sodass ein angehaltener Bildschirm die Zählung nicht verlängert. Android zeigt eine dauerhafte Benachrichtigung mit Öffnen und Stopp. Deaktivieren Sie den Schalter, um die Zählung bei diesen Aktionen vorzeitig zu beenden. Point Counts werden nicht pausiert und fortgesetzt, weil dies die zeitgebundene Zählung unterbrechen würde. Verlassen Sie die App während des Starts, wird die Zählung mit einer Meldung abgebrochen; richten Sie sie erneut ein. Unter Windows beendet das Minimieren des Fensters die Zählung nicht.

Wenn der Point Count endet, öffnet BirdNET Live [Session-Übersicht](session-review.md). Bei aktiviertem automatischem Speichern wird die Session automatisch gespeichert; andernfalls speichern Sie sie bei Bedarf in der Übersicht.

Bei aktiviertem automatischem Speichern wird eine laufende Zählung außerdem beim Start, alle 30 Sekunden und beim Verlassen des Vordergrunds gesichert. Nach einem Absturz oder Stromausfall steht die zuletzt gesicherte Teilzählung in der Session-Bibliothek bereit.
