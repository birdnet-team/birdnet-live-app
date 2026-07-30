# Einstellungen

BirdNET Live nutzt einen einzigen Einstellungsbildschirm für mehrere Arbeitsabläufe. Die Schaltfläche :material-tune: öffnet die Abschnitte, die für den Bildschirm relevant sind, von dem aus Sie gekommen sind.

## Funktionsweise des Einstellungsumfangs

- Öffnen Sie die Einstellungen über die Startseite, wird der vollständige Bildschirm angezeigt.
- Öffnen Sie die Einstellungen aus Live, Survey, Point Count oder Dateianalyse, wird der Bildschirm auf die jeweils relevanten Abschnitte gefiltert.

## Allgemein

### Design

Wählen Sie **Dunkel**, **Hell** oder **System**.

Ist **Dynamische Farben** aktiviert, versucht BirdNET Live außerdem, die Systemfarbpalette Ihres Android-Geräts zu übernehmen. Das wirkt sich nur auf unterstützten Android-Geräten aus; auf iPhone und iPad behält die App das Standard-Design von BirdNET Live bei, sodass das Aktivieren des Schalters dort nichts ändert.

### App-Sprache

Legt die Sprache der Benutzeroberfläche fest.

### Artennamen

Steuert die Sprache, die für Artennamen verwendet wird. **System** nutzt die bevorzugte Sprache des Telefons, sofern dieser Name verfügbar ist, auch wenn die Benutzeroberfläche auf Englisch zurückfällt. **App folgen** verwendet stattdessen die Sprache der Benutzeroberfläche.

### Wissenschaftliche Namen anzeigen

Zeigt in der gesamten App wissenschaftliche Namen unterhalb der gebräuchlichen Namen an.

### Wiedergabe-Overlay in Review

Wenn aktiviert (das ist der Standard), löst das Anhören eines Audioclips in einer Session-Übersicht, die nur Clips enthält (also ohne vollständige Audioaufnahme bzw. Spektrogramm), ein eigenes modales Player-Overlay mit Wiedergabesteuerung und einer Spektrogramm-Vorschau aus, anstatt den Clip im Hintergrund abzuspielen. Hat eine Session vollständiges Audio, wird diese Einstellung übergangen und das Wiedergabe-Overlay nie angezeigt.

### Beobachtername

Die Einrichtung von Survey, Point Count und ARU merkt sich den zuletzt in einem dieser Modi eingegebenen, nicht leeren Beobachternamen und füllt ihn beim nächsten Aufsetzen einer Feld-Session vor. So bleibt die wiederholte Nutzung auf einem persönlichen Feldtelefon schnell, während Sie den Beobachternamen vor dem Start einer Session weiterhin bearbeiten oder löschen können.

### ARU-/Stations-ID

Die ARU-Einrichtung merkt sich die zuletzt eingegebene, nicht leere ARU-/Stations-ID und füllt sie für die nächste Aufstellung vor. Wenn vorhanden, wird die ID in den Namen der ARU-Session und in die Export-Dateinamen aufgenommen, sodass wiederholte Aufstellungen an festen Standorten auch außerhalb der App identifizierbar bleiben.

### Zeitstempel-Anzeige

Steuert, wie die Zeiten einzelner Detektionen in der Session-Übersicht erscheinen.

- **Relativ** zeigt den Versatz ab Aufnahmebeginn, z. B. `00:12:34`. Am besten zum Durchsehen einer einzelnen Session und zum Abgleich mit der Spektrogramm-Wiedergabeposition.
- **Absolut** zeigt die lokale Uhrzeit, zu der die Detektion erfasst wurde, z. B. `08:42:17`. Am besten zum Abgleich mit Feldnotizen, Wetterprotokollen oder parallelen Aufnahmen.

Fällt eine Detektion auf einen anderen Kalendertag als der Session-Beginn (z. B. bei einem Survey über Nacht), erhält die absolute Zeit ein `+1d`-Suffix, damit man das morgige Morgenkonzert nicht versehentlich als das heutige liest.

Ist **Absolut** ausgewählt, erscheint zusätzlich der Schalter **Sekunden in Zeitstempeln anzeigen**. Deaktivieren Sie ihn, wenn Sie das kompaktere `08:42` dem `08:42:17` vorziehen – hilfreich beim Überfliegen langer Detektionslisten. Relative Versatzangaben zeigen immer Sekunden, weil zum Abgleich mit der Spektrogramm-Wiedergabeposition eine Genauigkeit unterhalb der Minute nötig ist.

Speicherung und Exporte verwenden unabhängig von dieser Einstellung immer UTC-Zeitpunkte, sodass die Auswahl niemals die Daten verändert – nur deren Darstellung.

## Audio

Diese Bedienelemente erscheinen in audiogesteuerten Live-Workflows.

### Verstärkung

Linearer Verstärker, der auf das eingehende Audio angewendet wird, bevor es das Spektrogramm und den Klassifikator erreicht. Belassen Sie ihn bei **1,0×**, sofern Ihr Eingang nicht durchgängig zu leise ist – etwa ein hochohmiges Lavalier-Mikrofon am Smartphone oder ein USB-Interface, dessen Vorverstärker zu niedrig eingestellt ist. Eine Verstärkung über 1,0 lässt keine Rufe erscheinen, die das Mikrofon nie aufgenommen hat; sie skaliert nur, was das Mikrofon geliefert hat, sodass laute Geräusche in der Nähe übersteuern können. Werte unter 1,0 sind im seltenen Fall nützlich, dass ein zu starker Eingang das Spektrogramm sättigt.

### Hochpassfilter (Hz)

Schneidet niederfrequente Anteile vor der Inferenz mit einem Butterworth-Filter mit 24 dB/Oktave ab – der Schiebereglerwert ist die −3-dB-Grenzfrequenz. **0 Hz deaktiviert ihn.** Eine Grenzfrequenz von 100–200 Hz entfernt Wind, Verkehrsrauschen und Handhabungsgeräusche, ohne die meisten Arten zu berühren; bei 500–1000 Hz beginnen tiefe Rufe, Eulen, Raufußhühner und das Dröhnen der Rohrdommel verloren zu gehen. Gehen Sie also nur so hoch, wenn Sie diese Arten bewusst zugunsten eines deutlich saubereren Spektrogramms in einer lauten städtischen Umgebung ausblenden. Die gewählte Grenzfrequenz sollte als scharfe waagerechte Linie im Live-Spektrogramm sichtbar sein.

### Audioquelle

Ein Auswahlfeld mit zwei unabhängigen Steuerungen: **Mikrofon** – welcher Eingang aufnimmt – und **Verarbeitung** – wie stark das Handy das Signal beim Aufnehmen verändern darf. Beide lassen sich frei kombinieren, ein USB-Mikrofon *unbearbeitet* aufzunehmen ist also völlig zulässig. Ihre Auswahl bleibt über App-Starts hinweg erhalten, und dasselbe Auswahlfeld erscheint in den Einrichtungsbildschirmen von Survey, Point Count und ARU. Änderungen wirken sofort – auch mitten in einer Aufnahme tauscht die App das Mikrofon in der laufenden Sitzung aus, statt bis zur nächsten zu warten.

**Mikrofon** listet namentlich jeden Eingang auf, den das Handy bereitstellt: USB-, Kabel- und Bluetooth-Mikrofone und auf vielen Handys auch die einzelnen eingebauten Mikrofone (z. B. *unten* und *hinten*). Funkmikrofon-Sets wie Rode Wireless GO oder DJI Mic laufen über einen USB-C-Empfänger und erscheinen hier daher als gewöhnliche USB-Audiogeräte in voller Qualität.

**Verarbeitung** ist der entscheidende Teil – und es gibt sie **nur unter Android**. Handys bearbeiten Mikrofonaufnahmen standardmäßig mit einem auf Sprache abgestimmten DSP – Rauschunterdrückung, spektrale Formung und automatische Aussteuerung –, weil das Mikrofon überwiegend zum Telefonieren dient. Diese Bearbeitung behandelt Vogelgesang als zu unterdrückendes Rauschen und lässt sich mit keiner normalen Einstellung abschalten. Der einzige Ausweg ist, Android nach einer anderen *Audioquelle* zu fragen:

| Option | Wirkung |
|---|---|
| **Handy-Standard** | Das, was Ihr Handy normalerweise tut, samt Sprachbearbeitung. Das bisherige Verhalten und weiterhin die Voreinstellung, damit sich für bestehende Nutzer nichts ändert. |
| **Unbearbeitet** | Das rohe Mikrofonsignal – keine Rauschunterdrückung, keine automatische Aussteuerung. Meist die beste Wahl für Vögel. |
| **Spracherkennung** | Schaltet Rauschunterdrückung und automatische Aussteuerung ebenfalls ab und funktioniert auf fast jedem Handy. |

**Probieren und vergleichen Sie.** Welche Option gewinnt, hängt tatsächlich vom Gerät ab. *Unbearbeitet* ist das Ideal, aber Android setzt es nur auf Handys um, deren Hersteller die Unterstützung meldet – auf allen anderen greift stillschweigend ein Rückfall, und es klingt wie *Systemstandard*. Dafür gibt es *Spracherkennung*: Androids Kompatibilitätsvorgaben **verlangen**, dass automatische Aussteuerung und Rauschunterdrückung dabei aus sind. Sie liefert also auch auf Handys unbearbeitetes Audio, die *Unbearbeitet* ignorieren. Wenn *Unbearbeitet* nichts ändert, wechseln Sie zu *Spracherkennung*.

Rechnen Sie damit, dass die unbearbeiteten Optionen **leiser** klingen – das ist die fehlende automatische Aussteuerung, kein Fehler. Erhöhen Sie bei zu niedriger Pegelanzeige die **Verstärkung**.

**Unter iOS** ist die Steuerung „Verarbeitung“ ausgeblendet und das Auswahlfeld ist schlicht eine Mikrofonliste. iOS liefert der App bereits weitgehend unbearbeitetes Audio, es gibt also nichts Vergleichbares zu wählen.

## Inferenz

### Fensterdauer

Steuert die Länge des Analysefensters.

### Konfidenzschwellenwert

Legt fest, wie konservativ Detektionen sein sollen. Der Standard ist **35 %**, was die Live-Liste auf stärkere Treffer fokussiert und zugleich Raum für entfernte oder teilweise verdeckte Rufe lässt. Senken Sie ihn, wenn Sie seltene oder leise Arten erfassen und mehr Kandidaten später prüfen möchten; erhöhen Sie ihn, wenn Hintergrundgeräusche oder häufige Fehltreffer die Session überfüllen.

### Empfindlichkeit

Ein x-Achsen-Offset auf den rohen Wahrscheinlichkeits-Scores des Modells, bevor Score-Pooling, geografische Filterung und der Konfidenzschwellenwert greifen. Das BirdNET-Audiomodell enthält bereits eine Sigmoid-Aktivierung; BirdNET Live wandelt deshalb jede Wahrscheinlichkeit zuerst zurück in den Logit-Raum, addiert den Empfindlichkeits-Bias und wandelt sie dann wieder in eine Wahrscheinlichkeit um. Höhere Werte machen den Detektor freizügiger – schwächere oder mehrdeutige Rufe überschreiten die Schwelle, auf Kosten von mehr Fehltreffern. Niedrigere Werte sind strenger und lassen nur sichere Detektionen durch. Der Standard von **1,0** wendet keinen Offset an und entspricht der BirdNET-Referenz. Probieren Sie **1,25**, wenn Sie vermuten, dass das Modell entfernte Rufe übersieht; gehen Sie auf **0,75**, wenn Sie von minderwertigen Detektionen häufiger Arten überflutet werden. Die Empfindlichkeit wird sofort angewendet: Eine Änderung während der Session greift im nächsten Inferenzfenster.

### Inferenzrate

Steuert, wie oft BirdNET die Inferenz ausführt.

### Score-Pooling

Kombiniert die Scores über die jüngsten Inferenzfenster, sodass ein einzelnes verrauschtes Fenster das Ergebnis nicht dominiert. **Aus** verwendet die Wahrscheinlichkeit jedes Fensters – am reaktivsten, am verrauschtesten. **Durchschnitt** bildet das arithmetische Mittel der jüngsten Fenster für die glatteste Ausgabe. **Max** behält den lautesten Spitzenwert pro Art und ist damit der reaktivste Glättungsmodus, gut für kurze, scharfe Rufe. **LME** (Log-Mean-Exp, der Standard) ist BirdNETs Referenz-Softmaximum: Es verhält sich wie *Max*, wenn ein Fenster dominiert, und wie *Durchschnitt*, wenn mehrere Fenster übereinstimmen. Im LME-Modus benötigt eine neue Art zudem wiederholte Unterstützung über mehrere einzelne Fenster, bevor sie erstmals erscheint, während gestützte Detektionen den Großteil ihres stärksten jüngsten Fenster-Scores behalten und bereits sichtbare Arten so lange bestehen bleiben, bis ihr gepoolter Score unter den Konfidenzschwellenwert fällt. Ein Moduswechsel während der Session leert den gleitenden Puffer, damit keine alten Scores in den neuen Modus übergehen.

### Anzahl Pooling-Fenster

Steuert, wie viele aufeinanderfolgende Inferenzfenster am Score-Pooling teilnehmen.
Ein größerer Wert glättet den Score jeder Art über einen längeren Zeithorizont, was
vereinzelte Fehldetektionen unterdrückt – nützlich bei gleichmäßigen, entfernten
Rufen, bei denen Sie lieber einige bestätigende Fenster abwarten, bevor Sie eine
Detektion auslösen. Ein kleinerer Wert reagiert schneller auf kurze Lautäußerungen,
lässt aber mehr Rauschen durch. Der Standard von **5** entspricht dem Wert, der
historisch fest im Modell verankert war, und ist ein sinnvoller Ausgangspunkt für
den Live-Einsatz.

## Spektrogramm

### FFT-Größe

Steuert die Frequenzauflösung im Spektrogramm.

### Farbpalette

Wählen Sie **Viridis**, **Magma** oder **Graustufen**.

### Dauer (Scrollgeschwindigkeit)

Steuert, wie viel Zeit im Spektrogrammfenster sichtbar ist.

### Frequenzbereich

Legt die obere Anzeigefrequenz fest.

### Log-Amplitude

Wendet eine logarithmische Skalierung auf das Spektrogramm an, um das visuelle Ablesen zu erleichtern.

### Qualität

Steuert, wie glatt das Spektrogrammbild skaliert wird. **Mittel** ist die ausgewogene Standardeinstellung. Wählen Sie **Niedrig** auf älteren Smartphones, wenn das Scrollen ruckelt oder das Gerät warm wird; wählen Sie **Hoch**, wenn Sie eine weichere Darstellung bevorzugen und Ihr Gerät genug GPU-Reserve hat. Zur Orientierung: Diese Einstellung verändert nur den Darstellungsaufwand, nicht die Audioanalyse oder die Detektionsergebnisse.

## Ansagen

Dieser Abschnitt steuert, ob BirdNET Live **Detektionen über Ihre Kopfhörer oder den Smartphone-Lautsprecher vorliest**, während eine Session aufgenommen wird. Die gesamte Funktion ist **standardmäßig aus**, weil sie die akustische Umgebung rund um das Mikrofon verändert – sie zu aktivieren ist eine bewusste Abwägung. Es gibt keinen Einrichtungsassistenten: Die Auswahlfelder für Ausführlichkeit × Häufigkeit weiter unten *sind* die gesamte Einrichtung, sodass Sie jederzeit eine andere Voreinstellung antippen und den Unterschied sofort hören können. Zur Orientierung: Bei langen Surveys können Sie nicht ständig auf den Bildschirm schauen; eine dezente Stimme im Ohr bedeutet, dass Sie Ihren Blick auf den Lebensraum richten und trotzdem wissen, was gerade gehört wurde.

### Detektionen vorlesen (Hauptschalter)

Standardmäßig aus. Wenn aktiviert, spricht die App jede angenommene Detektion über die geräteeigene Text-to-Speech-Funktion aus. **Kopfhörer werden dringend empfohlen** – beim Smartphone-Lautsprecher besteht die Gefahr, dass die Ansage vom Mikrofon aufgenommen und erneut erkannt wird. Daher schaltet die App den Recorder rund um jede Ausgabe kurz stumm, um diese Schleife zu verhindern (siehe *Mikrofon beim Sprechen stummschalten* weiter unten).

### Voreinstellung für die Ausführlichkeit

Wie viel die App zu jeder Detektion sagt. **Minimal** spricht nur den Artnamen (am besten für sehr lange Surveys, bei denen Sie nur das Stichwort möchten). **Ausgewogen** ist der Standard – kurze, abwechslungsreiche Formulierungen wie *„Rotkehlchen“*, *„Rotkehlchen gehört“*, *„Wieder ein Rotkehlchen“*. **Gesprächig** fügt etwas mehr Kontext hinzu und kommt dem Gefühl näher, dass jemand neben Ihnen kommentiert. **Individuell** erscheint automatisch, wenn Sie die numerischen Werte unter „Erweitert“ von Hand anpassen. Zur Orientierung: Dieselben Drosselungseinstellungen können je nach Formulierung zu still oder zu geschwätzig wirken – über die Ausführlichkeit behalten Sie die Taktung bei und regeln nur die Wortfülle.

### Voreinstellung für die Häufigkeit

Wie oft die App überhaupt sprechen darf. Fünf Stufen von am leisesten bis am gesprächigsten. **Selten** und **Sparsam** warten lange zwischen den Ansagen und begrenzen die Rate – gut geeignet für mehrstündige Surveys, bei denen Sie ein Gefühl für die Aktivität ohne fortlaufenden Kommentar möchten. **Normal** ist die standardmäßige Gesprächstaktung. **Häufig** verkürzt die Abstände und hebt die Obergrenze an; passend für kurze Live-Sessions oder wenn Sie eine Rückmeldung näher an Echtzeit wünschen. **Ständig** entfernt die Startverzögerung vollständig und lässt die App bei nahezu jedem Detektionszyklus sprechen – nützlich für Demos, Barrierefreiheit oder immer dann, wenn die Pause vor der ersten Ansage bei *Häufig* zu lang wirkt. **Individuell** erscheint, wenn Sie die Timing-Felder unter „Erweitert“ ändern. Zur Orientierung: Dies ist der eine Regler, der entscheidet, ob die App im Hintergrund bleibt oder zur Präsenz wird – tippen Sie eine andere Voreinstellung an und Sie hören die neue Taktung schon im nächsten Detektionszyklus, ohne Speichern-Schaltfläche.

### Stimme (Geschwindigkeit und Tonhöhe)

Zwei Schieberegler, die die TTS-Stimme der Plattform anpassen. **Geschwindigkeit** reicht von 0,5× bis 1,5×; der Standard von 1,0× ist das „normale“ Tempo der Plattform. **Tonhöhe** reicht von 0,7× bis 1,3×. Zur Orientierung: Eine leichte Absenkung der Tonhöhe und eine kleine Verlangsamung können Ansagen im Freien bei Wind oder fließendem Wasser im Hintergrund deutlich verständlicher machen; die Schaltfläche *Beispiel sprechen* darunter spielt drei gängige Vogelnamen mit den aktuellen Einstellungen vor, sodass Sie ohne Bildschirmwechsel ausprobieren können.

### Erweitert

Ein aufklappbarer Bereich mit einigen Schaltern für die Audio-Wegeführung sowie dem Auswahlfeld für den Auslösemodus. In der Regel müssen Sie ihn nicht öffnen – die Voreinstellungen für Ausführlichkeit und Häufigkeit oben sind die einzigen Regler, die im Alltag zählen. Die numerischen Werte zur Ratenbegrenzung (Startverzögerung, Mindestabstand, Maximum pro Minute, Serienpause, Aktualität zurücksetzen) sind im Schieberegler **Häufigkeit** gebündelt, sodass es eine offensichtliche Stelle gibt, an der Sie die Taktung höher oder niedriger drehen.

- **Telefonlautsprecher erlauben** – Wenn aus, werden Ansagen stillschweigend übersprungen, falls keine Kopfhörer oder externen Lautsprecher angeschlossen sind. Wenn an, dient der Smartphone-Lautsprecher als Ausweichlösung. Aktivieren Sie dies für entspanntes Zuhören zu Hause; lassen Sie es bei Feldarbeit aus, um akustische Rückkopplung ins Mikrofon auszuschließen.
- **Mikrofon beim Sprechen stummschalten** – Ersetzt das eingehende Audio während des Sprechens durch Stille, sodass die Lautsprecherausgabe nicht vom Mikrofon aufgenommen und erneut erkannt werden kann. Sehr empfohlen (und der Standard). Schalten Sie dies nur aus, wenn Ihr Mikrofon akustisch vom Smartphone-Lautsprecher getrennt ist – etwa ein Ansteckmikrofon an einem anderen Kabel oder ein Bluetooth-Headset.
- **Andere Audioausgabe absenken** – Senkt während der Ansage kurz die Lautstärke von Musik oder Podcasts anderer Apps und stellt sie danach wieder her. Standardmäßig an. Aus spielt in voller Mischung.
- **Signalton vor der Ansage** – Spielt vor jeder Ausgabe einen kurzen, leisen Ton, damit Ihr Ohr einen Moment hat, vom passiven Zuhören zur Stimme umzuschalten. Standardmäßig an. Besonders hilfreich, wenn Ansagen selten sind oder im Hintergrund Musik läuft.
- **Was angesagt wird** – Legt fest, welche Detektionen überhaupt für eine Ansage in Frage kommen. *Jede Detektion* (Standard) überlässt die Entscheidung der Drosselung. *Erste pro Session* sagt eine Art nur beim ersten Auftreten in der aktuellen Session an. *Nur Beobachtungsliste* beschränkt Ansagen auf Arten Ihrer Beobachtungsliste (nützlich für gezielte Survey-Arbeit, bei der Sie nur von Ihren prioritären Taxa hören möchten und von nichts sonst).

## Aufnahme

### Modus

- **Vollständig** – die gesamte Aufnahme speichern
- **Nur Detektionen** – Clips rund um Detektionen speichern
- **Aus** – keine Audioaufnahme

### Clip-Kontext

Wenn **Nur Detektionen** aktiv ist, zeigt die App einen einzelnen Schieberegler **Clip-Kontext** (0–5 s), der festlegt, wie viel Audio auf **beiden Seiten** jeder Detektion erhalten bleibt. Jeder Clip ist `Analysefenster + 2 × Clip-Kontext` lang, sodass der gespeicherte Clip bei einem Analysefenster von 3 s und dem Standardkontext von 1 s 5 s lang ist. Ein Kontext von 2 s ergibt einen 7 s langen Clip (2 s Pre-Roll + 3 s analysiertes Audio + 2 s Post-Roll). Größere Werte geben Ihnen mehr Spielraum für die visuelle Prüfung oder externe Analysewerkzeuge, kosten aber Speicherplatz; 0 speichert nur das analysierte Fenster selbst.

### Format

Wählen Sie **WAV** oder **FLAC**. WAV ist größer, aber breit kompatibel und schnell zu prüfen. FLAC behält dieselbe verlustfreie Audioqualität bei geringerem Speicherbedarf, was bei langen Sessions meist die bessere Wahl ist.

Diese Einstellung gilt für von BirdNET Live aufgenommenes Audio. Die **Dateianalyse** behält eine von der App verwaltete Kopie der importierten Datei in ihrem Originalformat, sodass MP3-, AAC-, WAV- und FLAC-Importe ohne zusätzlichen Konvertierungsschritt prüfbar bleiben.

### Aufnahme automatisch starten (nur Live-Modus)

Wenn aktiviert, beginnt der Live-Modus mit der Aufnahme, sobald der Bildschirm geöffnet und das Modell geladen ist – ein Tippen auf die Mikrofontaste ist nicht nötig. Nützlich für kioskartige Aufstellungen, freihändige Nutzung (z. B. wenn das Gerät im Feld montiert ist) oder jeden Arbeitsablauf, bei dem von vornherein klar ist, dass das Öffnen von Live immer „jetzt starten“ bedeutet. Standardmäßig deaktiviert, damit ein versehentliches Tippen auf die Live-Kachel auf der Startseite nicht still eine Session beginnt. Der automatische Start löst nur einmal pro Bildschirmaufruf aus, sodass das Stoppen einer Session und erneutes Antippen des Mikrofons weiterhin als manueller Neustart funktioniert.

Diese Einstellung gilt für das Öffnen des Live-Modus innerhalb der App. Das [Widget „Schnell lauschen“](live-mode.md) beginnt beim Antippen immer zuzuhören, unabhängig von dieser Einstellung, und lässt sie unverändert.

## Standort

### GPS verwenden

Geräte-GPS anstelle manueller Koordinaten verwenden.

### Breiten-/Längengrad

Manuelle Koordinaten, die verwendet werden, wenn GPS deaktiviert ist.

### GPS jetzt aktualisieren

Erzwingt eine neue Standortbestimmung, anstatt den letzten von der App zwischengespeicherten Wert wiederzuverwenden. Zur Orientierung: GPS-Abfragen werden pro Bildschirm zwischengespeichert, damit ein Einrichtungsbildschirm nicht bei jedem Öffnen auf einen Satellitenfix wartet, doch dieser Zwischenspeicher kann meilenweit veraltet sein, wenn Sie seit der letzten Session zu einem neuen Ort gefahren sind. Tippen Sie hier, wenn Sie sich bewegt haben und möchten, dass der Geo-Filter *hier* statt dort verwendet, wo Sie morgens gestartet sind. Die aktuell zwischengespeicherten Koordinaten werden im Untertitel angezeigt, sodass Sie prüfen können, wovon die App ausgeht. Kann GPS innerhalb von etwa 10 Sekunden keinen Fix ermitteln, greift die App auf den vom Betriebssystem gemeldeten letzten bekannten Standort zurück und warnt Sie per SnackBar, sodass Sie wissen, dass der Wert veraltet ist.

### Offline-Karten-Downloads

Offline-Karten-Downloads sind derzeit ausgeblendet, solange BirdNET Live den öffentlichen Kachel-Dienst von OpenStreetMap nutzt. OpenStreetMap unterstützt normales interaktives Durchsuchen von Karten mit Quellenangabe, eindeutigem User-Agent und lokalem Caching, erlaubt jedoch kein Massen-Vorabrufen oder Offline-Karten-Downloads von `tile.openstreetmap.org`. Die Downloader-Implementierung wird für eine künftige Kachelquelle aufbewahrt, die Offline-Pakete ausdrücklich erlaubt.

### Artenfilter

- **Aus** – keine geografische Filterung
- **Standortfilter** – Arten ausschließen, die unter den geografischen Schwellenwert fallen
- **Standortgewichtung** – das Geo-Modell als zusätzliches Gewichtungssignal verwenden

### Geofilter-Schwellenwert

Erscheint, wenn ein standortbasierter Filtermodus aktiv ist.

## Export & Sync

### Formate

Wählen Sie eine beliebige Kombination von Exportformaten – jeder Speicher- bzw. Teilen-Vorgang bündelt alle ausgewählten Formate gemeinsam in einem einzigen ZIP. Wählen Sie ein einzelnes Format ohne Audioclips und ohne HTML-Report, erhalten Sie aus Kompatibilitätsgründen eine Rohdatei (z. B. `session.csv`) statt eines ZIP:

- Raven Selection Table – zur Verwendung in Cornell Raven Pro.
- CSV – öffnet sich in jeder Tabellenkalkulation.
- JSON – am einfachsten für die programmatische Verarbeitung; enthält die vollständigen Metadaten je Session.
- GPX – Track und Wegpunkte zur Verwendung in Kartenwerkzeugen (nur sinnvoll, wenn GPS aktiv war).

Zur Orientierung: Viele Arbeitsabläufe brauchen mehr als ein Format gleichzeitig – eine CSV für die Tabelle, eine Raven-Tabelle für die Durchsicht am Desktop und eine JSON für das Analyseskript. Mit dem früheren Einzelformat-Schalter musste man dieselbe Session dreimal exportieren. Jetzt haken Sie alle drei einmal an und sie wandern gemeinsam ins ZIP.

### Audiodateien einschließen

Schließt gespeichertes Audio neben den exportierten Tabellen oder Metadaten ein, sofern der Export-Workflow dies unterstützt.

### HTML-Bericht einschließen

Wenn aktiviert, enthält jedes Export-ZIP neben der Tabelle, den Audioclips und der GPX-Datei auch eine Datei `report.html`. Öffnen Sie sie in einem beliebigen Webbrowser und Sie erhalten eine druckfertige Zusammenfassung der Session: eine Kopfkarte mit Datum, Standort, Beobachterin oder Beobachter und Summen; eine interaktive Karte des GPS-Tracks samt Detektionsmarkierungen; eine Karte je Detektion mit der Cornell-Taxonomie-Miniatur, Namen, Score-Pille, Ihrer Bestätigung, einer von Ihnen eingegebenen Notiz und dem Original-Audioclip direkt als Player; sowie die verwendeten Analyseeinstellungen. Zur Orientierung: Eine CSV ist großartig für Analyse-Pipelines, aber nutzlos zum Teilen mit nicht-technischen Mitwirkenden oder zum Ausdrucken einer kurzen Feldzusammenfassung – der HTML-Bericht füllt diese Lücke mit einem Tipp. Artenminiaturen und Kartenkacheln benötigen beim ersten Öffnen der Datei eine Verbindung (sie werden live von der BirdNET-Taxonomie-API und von OpenStreetMap geladen), aber alles andere – Text, Layout, Audiowiedergabe, Links – funktioniert vollständig offline. Schalten Sie dies aus, wenn Sie nur die Rohdaten benötigen und das ZIP einige KB kleiner halten möchten.

## Datenschutz

Dieser Abschnitt steuert, **welche Drittanbieter-Dienste BirdNET Live in Ihrem Namen kontaktieren darf**. Die Inferenz selbst läuft vollständig auf Ihrem Gerät – diese Schalter regeln nur optionale Netzwerkfunktionen, die das Erlebnis erweitern. Alle drei Schalter sind bei einer Neuinstallation **standardmäßig aus**; nichts wird abgerufen, bevor Sie es erlauben. Zur Orientierung: Jeder Schalter ist auf genau einen konkreten Dienst und einen konkreten Nutzen zugeschnitten, sodass Sie gezielt aktivieren, was für Ihren Arbeitsablauf nützlich ist – und sonst nichts.

### Kartenkacheln erlauben

Erforderlich für jede interaktive Karte in der App (die Standortauswahl, die Survey-Live-Karte und die Session-Karte). Wenn aktiviert, laden die Karten-Widgets Rasterkacheln von den öffentlichen **OpenStreetMap**-Servern; die Kachelkoordinaten-Anfragen verraten, welchen Bereich der Welt Sie gerade ansehen. Kacheln werden bis zu sechs Monate lokal zwischengespeichert, begrenzt auf 6000 Kacheln, sodass wiederholte Kartenansichten effizient bleiben, ohne unbegrenzt zu wachsen. Das Aktivieren schaltet außerdem **Ortsnamen-Suche erlauben** ein, da die meisten Nutzenden, die Karten laden, auch lesbare Ortsnamen in ihren Sessions erwarten. Sie können die Ortsnamen-Suche separat wieder ausschalten. Sind Kartenkacheln aus, greift jeder Kartenbildschirm auf eine Platzhalterkarte zurück, sodass der Rest der App ohne Netzwerkzugriff weiterhin funktioniert.

### Ortsnamen-Suche erlauben

Wenn aktiviert, sendet die App Ihre aufgezeichneten Koordinaten an den Dienst **Nominatim** von OpenStreetMap, um einen kurzen Ortsnamen aufzulösen (z. B. *„Berlin, Deutschland“*), der neben der Session in der Session-Bibliothek und in der Session-Übersicht angezeigt wird. Zur Orientierung: Numerische Koordinaten sind präzise, aber beim Scrollen durch eine lange Session-Liste schwer zu erfassen – ein Ortsname macht die Liste auf einen Blick lesbar. Wenn aus, zeigen Sessions nur die rohen Breiten-/Längengrade, und Nominatim wird nie kontaktiert.

### Wetterabfrage erlauben

Wenn aktiviert, erfasst jede gespeicherte Session eine einmalige Momentaufnahme der lokalen Bedingungen (Temperatur, Niederschlag, Wind, Bewölkung) an den Aufnahmekoordinaten und zur Endzeit über **Open-Meteo**. Die Momentaufnahme erscheint in der Session-Übersicht unter der Standortzeile und wird in den JSON-Export, den Metadatenblock der Session und den HTML-Bericht übernommen. Zur Orientierung: Das Wetter ist einer der stärksten Prädiktoren für Vogelaktivität, und es automatisch zu erfassen – ohne dass Sie an eine separate App denken müssen – macht jede Session zu einer vollständigeren Dokumentation. Open-Meteo ist ein kostenloser Dienst und benötigt weder ein Konto noch einen API-Schlüssel. Wenn aus, werden keine Wetterdaten abgerufen oder gespeichert. Die Einrichtung von Point Count und Survey zeigt nahe ihren Standort-Bedienelementen ebenfalls eine kompakte Wetterkarte: Sie fragt diese Zustimmung nur bei Bedarf ab, zeigt nach der Aktivierung eine Vorschau aus Symbol + Temperatur + Wind und verwendet beim Speichern der Session dieselbe zwischengespeicherte Momentaufnahme.

## Über

Die Zeile **Über** öffnet den In-App-Bildschirm „Über“.

## Gefahrenzone

### Onboarding zurücksetzen

Zeigt die Onboarding-Sequenz beim nächsten Start der App erneut an.

### Alle Einstellungen zurücksetzen

Setzt jede Einstellung auf diesem Bildschirm auf ihren Standardwert zurück. Sessions, Aufnahmen, Sprachmemos, Exporte und zwischengespeicherte Kartenkacheln bleiben unangetastet – nur die gespeicherten Einstellungen (Schieberegler, Schalter, Auswahlen) werden gelöscht. Nach der Bestätigung wird die App geschlossen, damit die neuen Standardwerte beim nächsten Start wirksam werden.

Nützlich, wenn Sie nicht sicher sind, welchen Schieberegler Sie verstellt haben, der etwas durcheinandergebracht hat, oder wenn Sie das Gerät jemandem übergeben und eine saubere Konfiguration möchten, ohne die gesammelten Daten zu verlieren.

### Alle Daten löschen

Löscht dauerhaft Sessions, Detektionen, Aufnahmen, Sprachmemos, eigene Artenlisten, gespeicherte Einstellungen sowie zwischengespeicherte Karten-, Ortsnamen-, Wetter-, Wiedergabe-, Review- und Teilen-Daten. Der Bestätigungsdialog verlangt die Eingabe von `DELETE` und schließt danach die App, sodass der nächste Start aus einem sauberen lokalen Zustand erfolgt.

Verwenden Sie dies, bevor Sie ein Gerät an eine andere beobachtende Person weitergeben, ein Feldtelefon außer Dienst nehmen oder ortsbezogene Historie aus der App entfernen. Exportieren Sie zuerst alles, was Sie benötigen; diese Aktion kann nicht rückgängig gemacht werden.

## Workflowspezifische Parameter außerhalb der Einstellungen

Einige Parameter werden in ihren eigenen Einrichtungsbildschirmen konfiguriert und nicht im gemeinsamen Einstellungsbildschirm.

- [Point-Count-Modus](point-count-mode.md) hat eine eigene Einrichtung für Dauer und Standort.
- [Survey-Modus](survey-mode.md) hat einen eigenen Bildschirm mit Survey-Parametern.
- [Dateianalyse](file-analysis.md) hat einen eigenen Schritt für die Analyseparameter.
