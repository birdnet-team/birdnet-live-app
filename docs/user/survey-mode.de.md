# Umfragemodus

Der Vermessungsmodus ist der routenbasierte Arbeitsablauf für lang andauernde Vermessungen in Bewegung.

## So öffnen Sie es

Tippen Sie auf der Startseite auf die Karte **Umfragemodus** mit dem Symbol :material-routes:.

## Setup-Ablauf

Die Einrichtung der Umfrage erfolgt über einen Assistenten mit fünf Schritten.

### 1. Einzelheiten

Sie können Folgendes eingeben:

- Name der Umfrage
- Transekt-ID
- Name des Beobachters
- GPS, manuelle Koordinaten oder kein Startort

In diesem Schritt werden bei Bedarf auch die Kartenauswahl und die Hintergrund-GPS-Berechtigungserinnerung angezeigt.

### 2. Parameter

Dieser Schritt enthält umfragespezifische Parameter wie:

- Mikrofonauswahl
- Inferenzrate
- Vertrauensschwelle
- GPS-Intervall
- maximale Dauer
- Aufnahmemodus
- Clip-Kontext für reine Detektionsaufzeichnung
- Detektions-Sampling-Modus
- Top-N-Grenze pro Art, wenn die Probenahme begrenzt ist

#### Detektionsprobenahme

Eine lange Umfrage kann zu Tausenden von Detektionen führen, und das Speichern eines Audioclips für jede einzelne davon füllt schnell den Speicherplatz. Die Detektionsstichprobe steuert, **welche Clips auf der Festplatte gespeichert werden** – *die Detektionsaufzeichnungen selbst werden immer gespeichert*, sodass Ihr vollständiges Sitzungsprotokoll unabhängig vom Modus intakt bleibt. Datensätze, deren Audio gelöscht wurde, haben in Session Review einfach keinen abspielbaren Clip.

Es stehen drei Modi zur Verfügung:

| Modus | Was es tut |
|---|---|
| **Alle** | Behalten Sie jeden Clip. Die meiste Festplattennutzung. Empfohlen für kurze Umfragen oder wenn Sie den Ton jeder Detektion für eine spätere Analyse benötigen. |
| **Top N** | Behalten Sie nur die **N Clips mit der höchsten Zuverlässigkeit pro Art**. Andere Clips werden während der Durchführung der Umfrage gelöscht. Der Standardwert für N ist 10, konfigurierbar von 1 bis 50. |
| **Smart** | Gleiche N-Grenze pro Art wie Top N, **plus** räumliche Verteilung: Wenn eine neue Detektion an derselben „Stelle“ wie ein bereits gespeicherter Clip landet (innerhalb von ~500 m und ~2 Minuten voneinander entfernt), behält nur der Clip mit der höheren Zuverlässigkeit seinen Clip. Dadurch wird verhindert, dass ein stationärer Sänger alle N Slots monopolisiert, und die beibehaltenen Clips tendieren dazu, den gesamten Transekt abzudecken. |

Der N-Grenzwert gilt **pro Art, nicht global** – wenn Sie 10 Rotkehlchen und 10 Buchfinken erfassen, behalten Sie 20 Clips. Es gibt keine allgemeine Obergrenze für die Anzahl der Clips, die eine Umfrage produzieren kann.

Wenn im Smart-Modus GPS bei einer Detektion fehlt, fällt die Same-Spot-Überprüfung auf ein reines Zeitfenster (~2 Minuten) zurück. Wenn GPS verfügbar ist, müssen sich Entfernung und Zeit überschneiden, damit zwei Detektionen als derselbe Punkt gelten.

### 3. Artenwarnungen

Push-Benachrichtigungen, die mitten in der Umfrage ausgelöst werden, wenn etwas Bemerkenswertes erkannt wird. Wählen Sie eines von:

- **Aus** – keine Warnungen (Standard).
- **Zuerst in der Sitzung** – eine Warnung, wenn jede Art während dieser Untersuchung zum ersten Mal gehört wird.
- **Erstmals** – Warnung nur, wenn die App in all Ihren Sitzungen zum allerersten Mal auf eine Art trifft (eine „Lifer“-Warnung). Unterstützt durch eine lebenslange Artenhistorie, die beim ersten Start automatisch aus Ihren vorhandenen Sitzungen übernommen wird.
- **Selten für diesen Standort** – Warnung, wenn die Geomodell-Wahrscheinlichkeit für den aktuellen Standort unter einem konfigurierbaren Schwellenwert liegt. Eine Live-Anzeige unter dem Schieberegler erklärt genau, was der aktuelle Wert auslöst (z. B. *„Warnungen zu Arten mit einer Wahrscheinlichkeit von unter 5 % an diesem Standort.“*).
- **Beobachtungsliste** – Warnung nur für Arten, die Sie zu einer gespeicherten benutzerdefinierten Liste hinzugefügt haben. Mit dem Assistentenschritt selbst können Sie neue Beobachtungslisten erstellen, bestehende in einem speziellen Vollbild-Editor mit durchsuchbarer Taxonomie und *Import aus Datei* (beliebige einfache „.txt“-/„.csv“-Dateien mit wissenschaftlichen Namen bearbeiten) und Listen löschen, die Sie nicht mehr benötigen.

Unter der Modusauswahl befindet sich ein Schieberegler *Mindestkonfidenz*, der automatisch auf den Konfidenzschwellenwert Ihrer Sitzung eingestellt wird (Warnungen sind niemals empfindlicher als die Detektionen selbst). Ein Abschnitt **Erweitert** stellt Drosselungskontrollen bereit – ein Zeitfenster für den Start, ein festes Mindestintervall zwischen zwei beliebigen Warnungen und eine gleitende Obergrenze pro Minute mit optionaler Zusammenführung von Überschreitungswarnungen in einer einzigen zusammenfassenden Benachrichtigung – alles mit One-Tap-Chip-Selektoren. Wenn Sie zum ersten Mal in einen Nicht-Aus-Modus wechseln, fordert der Assistent für Sie die Berechtigung zur Android-Benachrichtigung an.

### 4. Feldtipps

Eine kurze Checkliste vor dem Start im Einrichtungsablauf.

### 5. Fertig

Der Bereitschaftsbildschirm fasst die aktive Umfragekonfiguration zusammen, bevor Sie mit :material-play: beginnen.

## Live-Umfrage-Dashboard

Der Live-Umfragebildschirm verfügt über drei Hauptregisterkarten sowie eine Liste der letzten Detektionen.

### Obere Leiste

- :material-stop: — Umfrage beenden
- :material-timer: — verstrichene Zeit
- :material-help-circle-outline: – Öffnen Sie das Hilfeblatt zur Umfrage
- :material-tune: – Öffnen Sie die Umfrageeinstellungen

### Tabs

- :material-map-outline: – Routenkarte und zugeordnete Detektionen
- :material-equalizer: — Spektrogramm
- Diagrammsymbol – zusammenfassende Statistiken und Artenaufschlüsselung

### Statistiken und Detektionen

Unterhalb des Tab-Inhalts zeigt das Umfrage-Dashboard eine Statistikleiste und eine Liste der letzten Detektionen an. Wenn Sie auf eine Detektion tippen, wird die Überlagerung mit den Artendetails geöffnet.

## Hintergrundbetrieb

Im Umfragemodus bleibt während der Aufnahme eine permanente Vordergrundbenachrichtigung sichtbar, sodass Android die Audiopipeline nicht anhält. Die Benachrichtigung wird erweitert und zeigt Folgendes an:

- die verstrichene Zeit, die Detektionszahl, die Artenzahl und die zurückgelegte Strecke und
- die **drei jüngsten einzigartigen Arten** mit ihrer Konfidenz und einem relativen Zeitstempel („gerade jetzt“, „vor 42 Sekunden“, „vor 5 Minuten“, „vor 2 Stunden“).

Die Benachrichtigung – Titel, aktuelle Detektionen und Statistikfußzeile – wird vollständig in die ausgewählte Sprache der App übersetzt und verwendet dieselben Artengebietseinstellungen und *Wissenschaftliche Namen anzeigen*-Einstellungen wie die In-App-Karten.

Artenwarnungen (sofern aktiviert) werden auf einem separaten Android-Benachrichtigungskanal angezeigt, sodass Sie Warnungen unabhängig von der stillen laufenden Aufzeichnungsbenachrichtigung stummschalten können. Das Warnsymbol entspricht dem Benachrichtigungssymbol im Vordergrund (ein einfarbiger Vogel) und in den Warnmeldungskörpern wird nur der *Grund* angezeigt – *„Erste Detektion dieser Umfrage“*, *„Auf Ihrer Beobachtungsliste“*, *„An diesem Ort mit weniger als 4 % Wahrscheinlichkeit detektiert“* – wobei der Name der Art im fett gedruckten Benachrichtigungstitel verbleibt, wo Android ihn am größten darstellt.

## Nach dem Stoppen

BirdNET Live speichert die fertige Umfrage und öffnet [Session Review](session-review.md).