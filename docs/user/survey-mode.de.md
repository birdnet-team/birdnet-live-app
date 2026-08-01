# Survey-Modus

Der Survey-Modus ist der routenbasierte Arbeitsablauf für lange Surveys in Bewegung.

## So öffnen Sie ihn

Tippen Sie auf der Startseite auf die Karte **Survey** mit dem Symbol :material-routes:.

## Einrichtung

Die Einrichtung eines Surveys erfolgt über einen Assistenten mit fünf Schritten.

### 1. Details

Sie können Folgendes eingeben:

- Survey-Name
- Transekt-ID
- Name der beobachtenden Person
- GPS, manuelle Koordinaten oder kein Startort

In diesem Schritt erscheinen außerdem die Kartenauswahl, eine Aktualisierung des
GPS-Signals nach der Rückkehr von den System-Berechtigungsdialogen sowie bei
Bedarf der Hinweis auf die Hintergrund-GPS-Berechtigung. Im selben Standortbereich
steht eine Wetterkarte zur Verfügung. Ist der Wetterzugriff deaktiviert, wird die
Zustimmung **Wetterabfrage erlauben** angefragt; nach der Aktivierung zeigt die
Karte eine Vorschau des Standorts mit Wettersymbol, Temperatur und Wind. Beim
Speichern des Surveys wird dieselbe zwischengespeicherte Open-Meteo-Momentaufnahme
wiederverwendet.

### 2. Parameter

Dieser Schritt enthält Survey-spezifische Parameter wie:

- Mikrofonauswahl
- Inferenzrate
- Konfidenzschwelle
- GPS-Intervall
- maximale Dauer
- Aufnahmemodus
- Clip-Kontext für die reine Detektionsaufzeichnung
- Detektions-Sampling-Modus
- Top-N-Grenze pro Art bei begrenztem Sampling

#### Detektions-Sampling

Ein langer Survey kann Tausende von Detektionen erzeugen, und einen Audioclip für
jede einzelne zu speichern füllt den Speicher schnell. Das Detektions-Sampling
steuert, **welche Clips auf dem Gerät behalten werden** – *die Detektionseinträge
selbst bleiben immer erhalten*, sodass Ihr vollständiges Session-Protokoll
unabhängig vom Modus intakt bleibt. Einträge, deren Audio verworfen wurde, haben
in der Session-Übersicht einfach keinen abspielbaren Clip.

Es stehen drei Modi zur Verfügung:

| Modus | Funktion |
|---|---|
| **Alle** | Behält jeden Clip. Höchster Speicherbedarf. Empfohlen für kurze Surveys oder wenn Sie das Audio jeder Detektion für die spätere Analyse benötigen. |
| **Top N** | Behält nur die **N Clips mit der höchsten Konfidenz pro Art**. Weitere Clips werden während des Surveys gelöscht. Der Standardwert für N ist 10, einstellbar von 1 bis 50. |
| **Smart** | Gleiche Obergrenze von N pro Art wie bei Top N, **zusätzlich** mit räumlicher Verteilung: Landet eine neue Detektion an derselben „Stelle“ wie ein bereits behaltener Clip (innerhalb von ~500 m und ~2 Minuten), behält nur die Detektion mit der höheren Konfidenz ihren Clip. So verhindert der Modus, dass ein einzelner ortstreuer Sänger alle N Plätze belegt, und sorgt dafür, dass die behaltenen Clips das gesamte Transekt abdecken. |

Die Grenze N gilt **pro Art, nicht global** – wenn Sie 10 Rotkehlchen und
10 Buchfinken erfassen, behalten Sie 20 Clips. Es gibt keine Gesamtobergrenze für
die Anzahl der Clips, die ein Survey erzeugen kann.

Fehlt im Smart-Modus das GPS-Signal einer Detektion, greift die Same-Spot-Prüfung
auf ein reines Zeitfenster (~2 Minuten) zurück. Mit verfügbarem GPS müssen sich
sowohl Entfernung als auch Zeit überschneiden, damit zwei Detektionen als dieselbe
Stelle gelten.

### 3. Artenmeldungen

Push-Benachrichtigungen, die während eines Surveys ausgelöst werden, sobald etwas
Bemerkenswertes erkannt wird. Wählen Sie eine der folgenden Optionen:

- **Aus** – keine Meldungen (Standard).
- **Erste in Session** – eine Meldung, wenn eine Art während dieses Surveys zum
  ersten Mal gehört wird.
- **Erste überhaupt** – eine Meldung nur dann, wenn die App eine Art über alle Ihre
  Sessions hinweg zum allerersten Mal antrifft (eine „Lifer“-Meldung). Grundlage ist
  eine lebenslange Artenhistorie, die beim ersten Start automatisch aus Ihren
  vorhandenen Sessions befüllt wird.
- **Selten an diesem Ort** – eine Meldung, wenn die Wahrscheinlichkeit des
  Geo-Modells für den aktuellen Standort unter einem einstellbaren Schwellenwert
  liegt. Eine Live-Anzeige unter dem Schieberegler erklärt genau, worauf der aktuelle
  Wert reagiert (z. B. *„Meldungen bei Arten mit unter 5 % Wahrscheinlichkeit an
  diesem Standort.“*).
- **Beobachtungsliste** – eine Meldung nur bei Arten, die Sie einer gespeicherten
  eigenen Liste hinzugefügt haben. Im Assistentenschritt selbst können Sie neue
  Beobachtungslisten anlegen, bestehende Listen in einem eigenen Vollbild-Editor mit
  durchsuchbarer Taxonomie und *Aus Datei importieren* (eine beliebige einfache
  `.txt`-/`.csv`-Datei mit wissenschaftlichen Namen) bearbeiten und nicht mehr
  benötigte Listen löschen.

Unter der Modusauswahl liegt ein Schieberegler *Mindestkonfidenz*, dessen Untergrenze
automatisch auf die Konfidenzschwelle Ihrer Session gesetzt wird (Meldungen sind nie
empfindlicher als die Detektionen selbst). Ein Abschnitt **Erweitert** stellt
Drosselungsoptionen bereit – ein Kulanzfenster nach dem Start, ein festes
Mindestintervall zwischen zwei Meldungen sowie eine gleitende Obergrenze pro Minute
mit optionaler Zusammenfassung darüber hinausgehender Meldungen zu einer einzigen
Sammelbenachrichtigung – alle mit Chip-Auswahl per Fingertipp. Wenn Sie zum ersten
Mal in einen anderen Modus als *Aus* wechseln, fordert der Assistent für Sie die
Android-Benachrichtigungsberechtigung an.

### 4. Feldtipps

Eine kurze Checkliste vor dem Start, direkt im Einrichtungsablauf.

### 5. Fertig

Der Bereitschaftsbildschirm fasst die aktive Survey-Konfiguration zusammen, bevor Sie
mit :material-play: starten.

## Live-Dashboard des Surveys

Der Live-Bildschirm des Surveys hat drei Haupt-Tabs sowie eine Liste der letzten
Detektionen.

### Obere Leiste

- :material-stop: — Survey beenden
- :material-timer: — verstrichene Zeit
- :material-help-circle-outline: — Hilfeblatt zum Survey öffnen
- :material-tune: — Survey-Einstellungen öffnen

### Tabs

- :material-map-outline: — Routenkarte und verortete Detektionen
- :material-equalizer: — Spektrogramm
- Diagrammsymbol — zusammenfassende Statistiken und Artenaufschlüsselung

### Statistiken und Detektionen

Unter dem Tab-Inhalt zeigt das Survey-Dashboard eine Statistikleiste und eine Liste
der letzten Detektionen. Ein Tippen auf eine Detektion öffnet die Detailansicht der
Art.

Jede Detektionszeile bietet außerdem dieselben Aktionen pro Detektion wie die
[Session-Übersicht](session-review.md): ein :material-check: **Bestätigen** mit
einem Tipp sowie ein :material-dots-vertical: **Mehr**-Menü mit **Erkennung teilen**
und **Detektion löschen** (mit Rückgängig-Option in der SnackBar) – so können Sie
einen verrauschten Treffer schon während der Aufnahme prüfen, teilen oder entfernen,
statt auf die spätere Durchsicht zu warten.

Dieselben Aktionen stehen auf der **Live-Routenkarte** zur Verfügung: Tippen Sie auf
einen Detektionsmarker, um den Clip-Player mit Bestätigen, Teilen und Löschen zu
öffnen. Das Teilen während eines Surveys funktioniert auch dann, wenn Sie statt
einzelner Clips eine durchgehende WAV-Aufnahme gewählt haben – das passende
Audiofenster wird dabei direkt aus der laufenden Aufnahme herausgeschnitten. Weitere
Details finden Sie unter
[Session-Übersicht → Eine einzelne Detektion teilen](session-review.md#eine-einzelne-detektion-teilen).

### Eine Beobachtung erfassen

Die Schaltfläche :material-plus-circle-outline: im laufenden Survey öffnet ein kleines Menü mit **Art hinzufügen** und **Notiz hinzufügen**. **Art hinzufügen** öffnet dieselbe Artensuche wie [Session Review](session-review.md#arten-manuell-hinzufügen) — Wählen Sie eine Art, setzen Sie im Bestätigungsfenster :material-ear-hearing: **Gehört** und/oder :material-eye: **Gesehen** und tippen Sie auf **Hinzufügen**. Der Eintrag erhält den Zeitstempel dieses Moments und die aktuelle GPS-Position und erscheint sofort in der Detektionsliste und auf der Routenkarte — mit Manuell-Abzeichen und den passenden Ohr-/Augensymbolen.

Sprachmemos fehlen hier bewusst: Das Mikrofon ist mit der Aufnahme des Surveys belegt. Hängen Sie sie nach dem Ende des Surveys in Session Review an.

## Hintergrundbetrieb

Im Survey-Modus bleibt während der Aufnahme eine dauerhafte
Vordergrundbenachrichtigung sichtbar, damit Android die Audio-Pipeline nicht anhält.
Aufgeklappt zeigt die Benachrichtigung:

- die verstrichene Zeit, die Anzahl der Detektionen, die Artenzahl und die
  zurückgelegte Strecke sowie
- die **drei zuletzt erkannten Arten** mit ihrer Konfidenz und einem relativen
  Zeitstempel (`gerade eben`, `vor 42 s`, `vor 5 min`, `vor 2 h`).

Die Benachrichtigung – Titel, aktuelle Detektionen und Statistikzeile – ist
vollständig in die ausgewählte Sprache der App übersetzt und nutzt dieselben
Einstellungen für die Artensprache und *Wissenschaftliche Namen anzeigen* wie die
Karten in der App.

Artenmeldungen (sofern aktiviert) erscheinen auf einem eigenen
Android-Benachrichtigungskanal, sodass Sie Meldungen unabhängig von der stillen,
laufenden Aufnahmebenachrichtigung stummschalten können. Das Meldungssymbol entspricht
dem Symbol der Vordergrundbenachrichtigung (ein einfarbiger Vogel), und der
Meldungstext zeigt nur den *Grund* – *„Erste Detektion dieses Surveys“*, *„Auf Ihrer
Beobachtungsliste“*, *„An diesem Ort mit unter 4 % Wahrscheinlichkeit erkannt“* –
während der Artname im fett dargestellten Benachrichtigungstitel steht, wo Android ihn
am größten anzeigt.

Wenn Sie einen unbeendeten Survey aus der Session-Bibliothek **fortsetzen**, wird die
Meldungslogik aus Ihren *aktuellen* Benachrichtigungseinstellungen neu aufgesetzt –
nicht aus der Konfiguration vom Tag des Starts. Schalten Sie Meldungen vor dem Tippen
auf *Fortsetzen* aus (oder ändern Sie Modus, Beobachtungsliste oder Drosselung), und
der fortgesetzte Survey übernimmt die neuen Einstellungen sofort.

## Auf der Karte überprüfen

Die Vollbild-Kartenansicht des Surveys (die Schaltfläche :material-fullscreen: in der
Session-Übersicht) öffnet beim Tippen auf einen Marker einen Clip-Player. Die
Steuerleiste hat neben der Wiedergabetaste Schaltflächen für „Vorherige“ und
„Nächste“ – sie blättern in chronologischer Reihenfolge durch die Detektionen, jedoch
**nur durch die aktuell auf der Karte sichtbaren**. Jeder aktive Filter nach Art,
Konfidenz oder Modus-Chip schränkt die Wiedergabeliste entsprechend ein. Bei der
ersten bzw. letzten Detektion der gefilterten Liste werden die Schaltflächen
ausgegraut.

## Nach dem Beenden

BirdNET Live speichert den abgeschlossenen Survey und öffnet die
[Session-Übersicht](session-review.md).
