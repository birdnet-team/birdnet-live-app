# Einstellungen

BirdNET Live nutzt einen einzigen Einstellungsbildschirm für mehrere Arbeitsabläufe. Die Schaltfläche :material-tune: öffnet die Abschnitte, die für den Bildschirm relevant sind, von dem aus Sie gekommen sind.

## Funktionsweise des Einstellungsumfangs

- Wenn Sie die Einstellungen vom Startbildschirm aus öffnen, wird der vollständige Bildschirm angezeigt.
- Wenn Sie die Einstellungen aus Live, Survey, Point Count oder der Dateianalyse öffnen, wird der Bildschirm auf die relevanten Abschnitte gefiltert.

## Allgemein

### Design

Wählen Sie **Dunkel**, **Hell** oder **System**.

Wenn **Dynamische Farben** aktiviert ist, versucht BirdNET Live zusätzlich, die Systemfarbpalette Ihres Android-Geräts zu übernehmen. Das wirkt sich nur auf unterstützten Android-Geräten aus; auf iPhone und iPad behält die App das Standarddesign von BirdNET Live bei, sodass das Einschalten dort nichts ändert.

Aktivieren Sie **Kontrastreiches Design**, um eine schwarz-weiße helle oder dunkle Oberflächenpalette mit kräftigerem Text und umrandeten Flächen statt eingefärbter Karten zu verwenden. Sie folgt der Auswahl **Dunkel**, **Hell** oder **System**, setzt Dynamische Farben außer Kraft, solange sie aktiv ist, und behält die Farben für Gefahr, Warnung, Validierung, Modus, Score und Spektrogramm bei.

### App-Sprache

Legt die Sprache der Benutzeroberfläche fest.

### Artennamen

Steuert die Sprache der Artennamen. **System** verwendet die bevorzugte Sprache des Telefons, sofern der Name dort verfügbar ist, auch wenn die Oberfläche auf Englisch zurückfällt. **Der App folgen** verwendet stattdessen die Sprache der Oberfläche.

### Wissenschaftliche Namen anzeigen

Zeigt in der gesamten App wissenschaftliche Namen unter den gebräuchlichen Namen an.

### Alle erkannten Arten anzeigen

Nur Live-Modus und Point Count. Standardmäßig deaktiviert, sodass diese Bildschirme weiterhin nur Arten anzeigen, die im letzten Inferenzzyklus erkannt wurden – also praktisch die Arten, die gerade rufen. Schalten Sie die Option ein, damit jede während der laufenden Session erkannte Art in der Liste sichtbar bleibt, auch nachdem sie verstummt ist oder unter den Konfidenzschwellenwert fällt.

Wenn dies aktiviert ist, erscheint **Sortierung der Artenliste**. **Neueste zuerst** zeigt aktuell rufende Arten zuerst, sortiert nach ihrer aktuellen Konfidenz, danach beibehaltene Arten nach ihrer jüngsten Detektion. **Konfidenz** sortiert nach der höchsten während der Session erreichten Konfidenz je Art, **Alphabetisch** nach dem lokalisierten gebräuchlichen Namen und **Vorkommen** nach der Anzahl der Detektionen. In jedem Sortiermodus erscheinen Konfidenzprozentsatz und -balken nur, solange die betreffende Art gerade ruft (beibehaltene Zeilen verstummter Arten werden abgedunkelt), und wiederholte Detektionen zeigen am Ende der Namenszeile einen Zähler-Chip.

### Beobachtername

Survey, Point Count und die ARU-Einrichtung merken sich den zuletzt in einem dieser Modi eingegebenen, nicht leeren Beobachternamen und füllen ihn beim nächsten Einrichten einer Feld-Session vor. Das hält die wiederholte Nutzung auf einem persönlichen Feldtelefon schnell und lässt Sie den Beobachter vor dem Start einer Session dennoch bearbeiten oder löschen.

### ARU-/Stations-ID

Die ARU-Einrichtung merkt sich die zuletzt verwendete, nicht leere ARU-/Stations-ID und füllt sie für den nächsten Einsatz vor. Sofern vorhanden, wird die ID in den Namen der ARU-Session und in die Exportdateinamen aufgenommen, damit wiederholte Einsätze an festen Standorten auch außerhalb der App identifizierbar bleiben.

### Zeitstempel-Anzeige

Steuert, wie Zeiten einzelner Detektionen in der Session-Übersicht dargestellt werden.

- **Relativ** zeigt den Versatz seit Beginn der Aufnahme, z. B. `00:12:34`. Am besten geeignet, um eine einzelne Session durchzusehen und den Abspielkopf des Spektrogramms abzugleichen.
- **Absolut** zeigt die lokale Uhrzeit, zu der die Detektion aufgezeichnet wurde, z. B. `08:42:17`. Am besten geeignet für den Abgleich mit Feldnotizen, Wetterprotokollen oder parallelen Aufnahmen.

Fällt eine Detektion auf einen anderen Kalendertag als der Session-Beginn (z. B. bei einer nächtlichen Survey), erhält die absolute Zeit das Suffix `+1d`, damit man den Morgenchor von morgen nicht versehentlich für den von heute hält.

Wenn **Absolut** ausgewählt ist, erscheint zusätzlich der Schalter **Sekunden in Zeitstempeln anzeigen**. Deaktivieren Sie ihn, wenn Sie das kompaktere `08:42` gegenüber `08:42:17` bevorzugen – praktisch beim Überfliegen langer Detektionslisten. Relative Versätze zeigen immer Sekunden, weil beim Durchsehen eine Genauigkeit unterhalb einer Minute nötig ist, um mit dem Abspielkopf des Spektrogramms übereinzustimmen.

Speicherung und Exporte verwenden unabhängig von dieser Einstellung immer UTC-Zeitpunkte, die Wahl beeinflusst also nie die Daten – nur ihre Darstellung.

## Audio

Diese Steuerelemente erscheinen in audiogesteuerten Live-Arbeitsabläufen.

### Audioquelle

Ein Fenster mit zwei unabhängigen Steuerelementen: **Mikrofon** – von welchem Eingang aufgenommen wird – und **Verarbeitung** – wie stark das Telefon das Signal auf dem Weg hinein verändern darf. Beide lassen sich frei kombinieren, sodass ein USB-Mikrofon *unverarbeitet* aufgenommen eine völlig sinnvolle Konfiguration ist. Ihre Auswahl bleibt über App-Starts hinweg erhalten, und dieselbe Auswahl erscheint auf den Einrichtungsbildschirmen von Survey, Point Count und ARU. Änderungen wirken sofort – selbst mitten in einer Aufnahme wechselt die App das Mikrofon unter der laufenden Session, statt auf die nächste zu warten.

**Mikrofon** listet jeden Eingang auf, den das Telefon bereitstellt, mit Namen: USB-, Kabel- und Bluetooth-Mikrofone und auf vielen Telefonen auch die einzelnen eingebauten Mikrofone (z. B. *unten* und *hinten*). Drahtlose Mikrofonsets wie das Rode Wireless GO oder das DJI Mic werden über einen USB-C-Empfänger angeschlossen und erscheinen hier daher als gewöhnliche USB-Audiogeräte in voller Qualität.

**Verarbeitung** ist der wichtigste Teil, und es gilt **nur für Android**. Telefone wenden auf Mikrofonaudio standardmäßig ein auf Sprache abgestimmtes DSP an – Rauschunterdrückung, spektrale Formung und automatische Verstärkung –, weil das Mikrofon überwiegend für Telefonate genutzt wird. Diese Verarbeitung behandelt Vogelgesang als zu unterdrückendes Rauschen, und keine gewöhnliche Einstellung schaltet sie ab. Der einzige Ausweg besteht darin, von Android eine andere *Audioquelle* anzufordern:

| Option | Wirkung |
|---|---|
| **Telefonstandard** | Was Ihr Telefon normalerweise tut, einschließlich Sprachverarbeitung. Das ursprüngliche Verhalten und weiterhin die Voreinstellung, damit sich für bestehende Nutzende nichts ändert. |
| **Unverarbeitet** | Das rohe Mikrofonsignal – keine Rauschunterdrückung, keine automatische Verstärkung. Für Vögel meist die beste Wahl. |
| **Spracherkennung** | Schaltet ebenfalls Rauschunterdrückung und automatische Verstärkung ab und funktioniert auf nahezu jedem Telefon. |

**Probieren Sie sie aus und vergleichen Sie.** Welche Option gewinnt, hängt tatsächlich vom Gerät ab. *Unverarbeitet* ist das Ideal, aber Android setzt es nur auf Telefonen um, deren Hersteller Unterstützung dafür angibt – auf allen anderen fällt es stillschweigend zurück und klingt identisch zum *Systemstandard*. Dafür gibt es *Spracherkennung*: Androids Kompatibilitätsregeln **verlangen** dafür, dass automatische Verstärkung und Rauschunterdrückung abgeschaltet sind, sodass sie zuverlässig unverarbeitetes Audio liefert, selbst auf Telefonen, die *Unverarbeitet* ignorieren. Wenn der Wechsel zu *Unverarbeitet* nichts ändert, wechseln Sie zu *Spracherkennung*.

Erwarten Sie, dass die unverarbeiteten Optionen **leiser** klingen – das ist die fehlende automatische Verstärkung, kein Fehler. Erhöhen Sie **Verstärkung**, um das auszugleichen, wenn die Pegelanzeige niedrig aussieht.

**Unter iOS** ist das Steuerelement für die Verarbeitung ausgeblendet und das Fenster ist schlicht eine Mikrofonliste. iOS übergibt der App bereits weitgehend unverarbeitetes Audio, sodass es hier nichts Entsprechendes zu wählen gibt.

### Verstärkung

Linearer Verstärker, der auf eingehendes Audio angewendet wird, bevor es das Spektrogramm und den Klassifikator erreicht. Belassen Sie ihn bei **1,0×**, sofern Ihr Eingang nicht durchgängig zu leise ist – etwa ein hochohmiges Lavaliermikrofon am Telefon oder ein USB-Interface, dessen Vorverstärker zu niedrig eingestellt ist. Eine Verstärkung über 1,0 wird keine Rufe hervorzaubern, die das Mikrofon nie erfasst hat; sie skaliert lediglich, was das Mikrofon geliefert hat, sodass laute nahe Geräusche übersteuern können. Werte unter 1,0 sind in dem seltenen Fall nützlich, dass ein zu heißer Eingang das Spektrogramm sättigt.

### Hochpassfilter (Hz)

Schneidet tieffrequente Anteile vor der Inferenz mit einem Butterworth-Filter mit 24 dB/Oktave ab – der Schiebereglerwert ist die −3-dB-Grenzfrequenz. **0 Hz deaktiviert ihn.** Eine Grenzfrequenz von 100–200 Hz entfernt Wind, Verkehrsdröhnen und Handhabungsgeräusche, ohne die meisten Arten zu beeinträchtigen; in Richtung 500–1000 Hz beginnen tiefe Rufe, Eulen, Raufußhühner und das Dröhnen der Rohrdommel zu verschwinden. Gehen Sie also nur so hoch, wenn Sie diese Arten bewusst ignorieren und dafür ein deutlich saubereres Spektrogramm in einer lauten städtischen Umgebung erhalten wollen. Die gewählte Grenzfrequenz sollte als scharfe waagerechte Linie im Live-Spektrogramm sichtbar sein.

## Inferenz

### Fensterdauer

Steuert die Länge des Analysefensters. Verfügbare Stufen sind **1**, **3**, **5**, **7**, **10** und **15** Sekunden.

### Konfidenzschwellenwert

Legt fest, wie zurückhaltend Detektionen sein sollen. Die Voreinstellung ist **35 %**, was die Live-Liste auf stärkere Übereinstimmungen konzentriert und trotzdem Raum für entfernte oder teilweise verdeckte Rufe lässt. Senken Sie ihn, wenn Sie seltene oder leise Arten erfassen und später mehr Kandidaten durchsehen wollen; erhöhen Sie ihn, wenn Hintergrundgeräusche oder häufige Falschpositive die Session überfrachten.

### Empfindlichkeit

Ein Versatz auf der x-Achse, der auf die rohen Wahrscheinlichkeitswerte des Modells angewendet wird, bevor Score-Pooling, geografische Filterung und der Konfidenzschwellenwert greifen. Das Audiomodell von BirdNET enthält bereits eine Sigmoid-Aktivierung, daher rechnet BirdNET Live jede Wahrscheinlichkeit zunächst in den Logit-Raum zurück, addiert den Empfindlichkeits-Bias und wandelt sie anschließend wieder in eine Wahrscheinlichkeit um. Höhere Werte machen den Detektor durchlässiger – schwächere oder mehrdeutigere Rufe überschreiten den Schwellenwert, auf Kosten von mehr Falschpositiven. Niedrigere Werte sind strenger und lassen nur sichere Detektionen durch. Die Voreinstellung **1,0** wendet keinen Versatz an und entspricht der BirdNET-Referenz. Versuchen Sie **1,25**, wenn Sie vermuten, dass das Modell entfernte Rufe übersieht; gehen Sie auf **0,75**, wenn Sie mit minderwertigen Detektionen häufiger Arten überflutet werden. Die Empfindlichkeit wird sofort übernommen: Eine Änderung mitten in einer Session wirkt sich auf das nächste Inferenzfenster aus.

### Inferenzrate

Steuert, wie häufig BirdNET eine Inferenz durchführt. Der Schieberegler
verwendet dieselben Stufen von **0,10–1,00 Hz** wie die Einrichtung von Survey
und ARU. Die Fenster sind an aufgezeichnete Audio-Samples gebunden und nicht
an den Ablauf eines Timers, sodass das Speichern einer Aufnahme oder ein
vorübergehend langsamer Modellaufruf spätere Fenster nicht verschiebt. Bei
gleichen Inferenzeinstellungen analysieren Live-Modus, Point Count und Survey
dieselben Fenster und melden dieselben Detektionen. Niedrigere Raten
verringern die Modellarbeit und den Akkuverbrauch, lassen aber größere Lücken
zwischen den Fenstern, sodass sehr kurze Lautäußerungen leichter übersehen
werden. Neue Survey-Einstellungen verwenden standardmäßig **0,70 Hz** als
Mittelweg; **0,30 Hz** bleibt die ausdrückliche Option für maximale
Akkulaufzeit. Die Dateianalyse hat keine Inferenzrate — sie verwendet
stattdessen eine [Überlappung](file-analysis.md).

BirdNET Live glättet Scores intern über die jüngsten Inferenzfenster hinweg,
um einmalige Falschpositive zu reduzieren. Dieses Pooling ist nicht als
Benutzereinstellung verfügbar; standardmäßig wird adaptives
Log-Mean-Exp-Pooling mit fünf jüngsten Fenstern und einer Echtzeit-Altersgrenze
von 10 Sekunden verwendet. Akzeptierte Detektionen zeigen die stärkste kürzlich
gestützte Modellkonfidenz, sodass eindeutige Lautäußerungen weiterhin hohe
Konfidenz anzeigen können, statt von der Glättung eingeebnet zu werden. Alle
Modi wandeln dieses Pooling-Ergebnis jetzt auf dieselbe Weise in Detektionen
um: Eine Detektion beginnt bei ihrem frühesten stützenden Fenster, trägt den
stärksten gestützten Score und endet am Ende des letzten stützenden Fensters.

## Spektrogramm

### FFT-Größe

Steuert die Frequenzauflösung im Spektrogramm.

### Farbpalette

Wählen Sie **Viridis**, **Magma**, **Plasma**, **Cividis**, **Jet**, **Turbo**, **Graustufen** oder **BirdNET**. **Turbo** ist die moderne, Jet-ähnliche Regenbogenoption.

### Dauer (Scrollgeschwindigkeit)

Steuert, wie viel Zeit im Spektrogrammfenster sichtbar ist.

### Frequenzbereich

Legt die obere Anzeigefrequenz fest.

### Log-Amplitude

Wendet eine logarithmische Skalierung auf das Spektrogramm an, damit es leichter abzulesen ist.

### Qualität

Steuert, wie weich das Spektrogrammbild skaliert wird. **Mittel** ist die voreingestellte Balance. Wählen Sie **Niedrig** auf älteren Telefonen, wenn das Scrollen stockt oder das Gerät heiß wird; wählen Sie **Hoch**, wenn Sie eine weichere Darstellung bevorzugen und Ihr Gerät genügend GPU-Reserven hat. Die Intuition dahinter: Das ändert nur den Rendering-Aufwand, nicht die Audioanalyse oder die Detektionsergebnisse.

## Ansagen

Dieser Abschnitt steuert, ob BirdNET Live **Detektionen über Ihre Kopfhörer oder den Telefonlautsprecher vorliest**, während eine Session aufzeichnet. Die gesamte Funktion ist **standardmäßig deaktiviert**, weil sie die akustische Umgebung rund um das Mikrofon verändert – sie einzuschalten ist eine bewusste Abwägung. Es gibt keinen Einrichtungsassistenten: Die Auswahl aus Ausführlichkeit × Häufigkeit weiter unten *ist* die gesamte Einrichtung, Sie können also jederzeit eine andere Voreinstellung antippen und den Unterschied sofort hören. Die Intuition dahinter: In langen Surveys können Sie nicht ständig auf den Bildschirm schauen; eine dezente Stimme im Ohr bedeutet, dass Sie den Blick im Habitat lassen und trotzdem wissen, was gerade zu hören war.

### Detektionen vorlesen (Hauptschalter)

Standardmäßig deaktiviert. Wenn aktiviert, spricht die App jede akzeptierte Detektion über die eingebaute Sprachausgabe Ihres Geräts. **Kopfhörer werden dringend empfohlen** – bei Nutzung des Telefonlautsprechers besteht die Gefahr, dass die Ansage vom Mikrofon aufgenommen und erneut detektiert wird. Deshalb schaltet die App den Recorder rund um jede Äußerung kurz stumm, um diese Schleife zu verhindern (siehe *Mikrofon während des Sprechens stummschalten* weiter unten).

### Voreinstellung für die Ausführlichkeit

Wie viel die App zu jeder Detektion sagt. **Minimal** spricht nur den Artnamen (am besten für sehr lange Surveys, in denen Sie nur den Hinweis wollen). **Ausgewogen** ist die Voreinstellung – kurze, abwechslungsreiche Formulierungen wie *„Rotkehlchen“*, *„Rotkehlchen gehört“*, *„Wieder ein Rotkehlchen“*. **Gesprächig** ergänzt etwas mehr Kontext und kommt dem Gefühl näher, dass jemand nebenher kommentiert. **Benutzerdefiniert** erscheint automatisch, wenn Sie die Zahlenwerte unter Erweitert von Hand anpassen. Die Intuition dahinter: Dieselben Drosselungseinstellungen können je nach Formulierung entweder zu still oder zu geschwätzig wirken – die Ausführlichkeit lässt Sie den Takt beibehalten und nur die Wortmenge regeln.

### Voreinstellung für die Häufigkeit

Wie oft die App überhaupt sprechen darf. Fünf Stufen von am leisesten bis am gesprächigsten. **Selten** und **Sparsam** warten lange zwischen Ansagen und begrenzen die Rate – gut geeignet für mehrstündige Surveys, in denen Sie ein Gefühl für die Aktivität wollen, aber keinen laufenden Kommentar. **Normal** ist der voreingestellte, gesprächsähnliche Takt. **Häufig** verkürzt die Abstände und hebt die Obergrenze an; passend für kurze Live-Sessions oder wenn Sie Rückmeldung näher an Echtzeit möchten. **Ständig** entfernt die Startverzögerung vollständig und lässt die App in nahezu jedem Detektionszyklus sprechen – nützlich für Vorführungen, Barrierefreiheit oder wenn Ihnen die Lücke bis zur ersten Ansage bei *Häufig* zu lang erscheint. **Benutzerdefiniert** erscheint, wenn Sie die Zeitfelder unter Erweitert ändern. Die Intuition dahinter: Das ist der eine Regler, der entscheidet, ob die App im Hintergrund bleibt oder zur Präsenz wird – tippen Sie eine andere Voreinstellung an, und Sie hören den neuen Takt schon im nächsten Detektionszyklus, ohne Speichern-Schaltfläche.

### Stimme

Tippen Sie auf die Stimmzeile, um unter den für die Ansagesprache installierten Sprachausgabestimmen zu wählen, oder belassen Sie **Standardstimme**, damit das Gerät entscheidet. Verfügbarkeit und Qualität der Stimmen hängen vom Betriebssystem und den installierten Sprachpaketen ab; zusätzliche Stimmen lassen sich in den Sprachausgabeeinstellungen des Geräts installieren.

**Geschwindigkeit** reicht von 0,5×–1,5×; die Voreinstellung 1,0× ist das „normale“ Tempo der Plattform. **Tonhöhe** reicht von 0,7×–1,3×. Eine leichte Absenkung der Tonhöhe und eine geringe Verlangsamung können Ansagen im Freien bei Wind oder fließendem Wasser im Hintergrund verständlicher machen. *Beispiel sprechen* gibt eine Vorschau der gewählten Stimme, des aktuellen Formulierungsstils, der Geschwindigkeit und der Tonhöhe, ohne die Einstellungen zu verlassen. Änderungen gelten ab der nächsten Ansage.

### Erweitert

Ein aufklappbarer Bereich mit einigen Schaltern zur Audioführung sowie der Auswahl des Auslösemodus. In der Regel müssen Sie ihn nicht öffnen – die Voreinstellungen für Ausführlichkeit und Häufigkeit weiter oben sind die einzigen Regler, die im Alltag zählen. Die Zahlenwerte zur Ratenbegrenzung (Startkarenz, Mindestabstand, Maximum pro Minute, Serienstille, Rücksetzung der Aktualität) sind im Schieberegler **Häufigkeit** gebündelt, sodass es eine offensichtliche Stelle gibt, um den Takt anzuheben oder abzusenken.

- **Telefonlautsprecher erlauben** – Wenn deaktiviert, werden Ansagen stillschweigend übersprungen, sofern keine Kopfhörer oder externen Lautsprecher angeschlossen sind. Wenn aktiviert, dient der Telefonlautsprecher als Rückfalloption. Schalten Sie das für gelegentliches Zuhören zu Hause ein; lassen Sie es für die Feldarbeit aus, um akustische Rückkopplung ins Mikrofon sicher auszuschließen.
- **Mikrofon während des Sprechens stummschalten** – Ersetzt eingehendes Audio durch Stille, während die App spricht, damit die Lautsprecherausgabe nicht vom Mikrofon aufgenommen und erneut detektiert werden kann. Sehr empfehlenswert (und die Voreinstellung). Schalten Sie das nur ab, wenn Ihr Mikrofon akustisch vom Telefonlautsprecher entkoppelt ist – etwa ein Ansteckmikrofon an einem anderen Kabel oder ein Bluetooth-Headset.
- **Andere Audioquellen leiser stellen** – Senkt während der Ansage kurz die Lautstärke von Musik oder Podcasts aus anderen Apps und stellt sie danach wieder her. Standardmäßig aktiviert. Deaktiviert wird in voller Mischung wiedergegeben.
- **Signalton vor dem Sprechen** – Spielt vor jeder Äußerung einen kurzen, leisen Ton, damit Ihr Ohr einen Moment hat, vom passiven Hören zur Aufmerksamkeit für die Stimme zu wechseln. Standardmäßig aktiviert. Besonders hilfreich, wenn Ansagen selten sind oder im Hintergrund Musik läuft.
- **Was angesagt wird** – Legt fest, welche Detektionen überhaupt für eine Ansage infrage kommen. *Jede Detektion* (Voreinstellung) überlässt die Entscheidung der Drosselung. *Erstes Mal pro Session* sagt eine Art nur beim ersten Auftreten in der aktuellen Session an. *Nur Beobachtungsliste* beschränkt Ansagen auf Arten Ihrer Beobachtungsliste (nützlich für gezielte Survey-Arbeit, bei der Sie nur von Ihren prioritären Taxa hören wollen und von nichts sonst).

## Aufnahme

### Modus

- **Vollständig** – die gesamte Aufnahme speichern
- **Nur Detektionen** – Clips rund um Detektionen speichern
- **Aus** – keine Audioaufnahme

### Clip-Kontext

Wenn **Nur Detektionen** aktiv ist, zeigt die App einen einzelnen Schieberegler **Clip-Kontext** (0–5 s), der festlegt, wie viel Audio auf **beiden Seiten** jeder Detektion erhalten bleibt. Jeder Clip ist `Analysefenster + 2 × Clip-Kontext` lang, mit einem Analysefenster von 3 s und dem voreingestellten Kontext von 1 s ist der gespeicherte Clip also 5 s lang. Ein Kontext von 2 s ergibt einen Clip von 7 s (2 s Vorlauf + 3 s analysiertes Audio + 2 s Nachlauf). Größere Werte geben Ihnen mehr Spielraum für die visuelle Prüfung oder externe Auswertungswerkzeuge, kosten aber Speicherplatz; 0 speichert nur das analysierte Fenster selbst.

### Format

Wählen Sie **WAV** oder **FLAC**. WAV ist größer, aber weithin kompatibel und schnell zu prüfen. FLAC behält dieselbe verlustfreie Audioqualität bei geringerem Speicherbedarf, was für lange Sessions meist besser ist.

Diese Einstellung gilt für Audio, das BirdNET Live aufnimmt. Die **Dateianalyse** behält eine von der App verwaltete Kopie der importierten Datei in ihrem Originalformat, sodass MP3-, AAC-, WAV- und FLAC-Uploads ohne zusätzlichen Konvertierungsschritt durchsehbar bleiben.

### Aufnahme automatisch starten (nur Live-Modus)

Wenn aktiviert, beginnt der Live-Modus mit der Aufnahme, sobald der Bildschirm geöffnet ist und das Modell geladen wurde – ohne die Mikrofonschaltfläche antippen zu müssen. Nützlich für Kiosk-artige Aufstellungen, freihändige Nutzung (z. B. das Gerät im Feld montiert) oder jeden Ablauf, bei dem das Öffnen von Live ohnehin „jetzt starten“ bedeutet. Standardmäßig deaktiviert, damit ein versehentliches Antippen der Live-Kachel auf dem Startbildschirm nicht stillschweigend eine Session beginnt. Der automatische Start erfolgt nur einmal pro Bildschirmbesuch, sodass ein Beenden der Session und erneutes Antippen des Mikrofons weiterhin als manueller Neustart funktioniert.

Diese Einstellung betrifft das Öffnen des Live-Modus innerhalb der App. Das [Quick-Listen-Widget](live-mode.md) beginnt beim Antippen zu lauschen, unabhängig von dieser Einstellung, und lässt die Einstellung unberührt. Läuft oder startet bereits eine Session von Point Count, Survey, Dateianalyse oder ARU-Modus, bleibt diese Session erhalten und Sie werden gebeten, sie zuerst zu beenden.

### Sessions automatisch speichern (Live und Point Count)

Wenn aktiviert (die Voreinstellung), wird eine abgeschlossene Live- oder Point-Count-Session in dem Moment automatisch zu Ihrer Bibliothek hinzugefügt, in dem sie endet. Wenn deaktiviert, öffnet sich eine beendete Session in der Übersicht als **nicht gespeichert**: Das Speichersymbol ist hervorgehoben und Sie müssen es antippen, um die Session zu behalten. Verlassen Sie die Übersicht ohne zu speichern, werden Session und Aufnahmen verworfen. Das eignet sich für kurzes Hineinhören, bei dem Sie nur gelegentlich ein bemerkenswertes Ergebnis behalten wollen, statt jede kurze Aufnahme anzusammeln. Survey- und ARU-Einsätze speichern immer automatisch – ein langer unbeaufsichtigter Lauf ist zu wertvoll, um ihn durch vergessenes Speichern zu verlieren –, dieser Schalter gilt dort also nicht.

## Wiedergabe

### Wiedergabe-Overlay in der Übersicht

Wenn aktiviert (die Voreinstellung), öffnet das Anhören eines Audioclips in einer reinen Clip-Session-Übersicht (in der keine vollständige Audioaufnahme bzw. kein Spektrogramm verfügbar ist) ein eigenes modales Wiedergabe-Overlay mit Transportsteuerung und Spektrogrammvorschau, statt den Clip im Hintergrund abzuspielen. Verfügt eine Session über vollständiges Audio, wird diese Einstellung übergangen und das Wiedergabe-Overlay nie angezeigt.

### Sprachnotizen automatisch abspielen

Standardmäßig deaktiviert. Wenn aktiviert, wird eine an eine zeitgebundene Anmerkung angehängte Sprachnotiz während der Session-Übersicht automatisch abgespielt, sobald der Abspielkopf ihre aufgezeichnete Position überschreitet. Die Notiz wird über die Aufnahme gemischt, statt sie zu pausieren, sodass Sie Ihre gesprochene Notiz im Kontext gemeinsam mit dem Originalaudio hören. Lassen Sie sie deaktiviert, wenn Sie Notizen lieber manuell durch Antippen ihres Anmerkungs-Chips auslösen.

### Absenkung bei Sprachnotizen

Wird nur angezeigt, wenn **Sprachnotizen automatisch abspielen** aktiviert ist. Steuert, wie stark die Hauptaufnahme abgesenkt wird, während eine automatische Sprachnotiz läuft. Höhere Werte machen gesprochene Notizen besser hörbar; niedrigere Werte lassen mehr von der Originalaufnahme unter der Notiz durchklingen.

## Standort

### GPS verwenden

Geräte-GPS statt manueller Koordinaten verwenden. Unter Android stammen die
Ortungen vom Standortdienst der Plattform und nicht von den Google Play
Services, sodass die App den Google-Dialog zur Standortgenauigkeit nicht
auslöst. Ist diese Option deaktiviert, liest die App von sich aus nie das GPS
und fragt keine Standortberechtigung an: Die Einrichtungsassistenten von
Survey, Point Count und ARU öffnen sich mit der manuellen Eingabe Ihrer
gespeicherten Koordinaten, das GPS-Tracking der Survey läuft nicht, und auch
die Vorbereitung von Offline-Karten zentriert auf diese Koordinaten.

### Breiten-/Längengrad

Die Koordinaten, die verwendet werden, wenn **GPS verwenden** deaktiviert ist. Breiten- und Längengrad sind beide bearbeitbare Textfelder, Sie können also einen exakten Wert **eingeben** oder einen aus einer anderen App kopierten Wert **einfügen** – weit präziser, als auf einem Touchscreen an einem Schieberegler zu ziehen. Geben Sie Dezimalgrad ein (z. B. `52.5200` und `13.4050`). Sie können auch eine kombinierte Zeichenfolge `Breitengrad, Längengrad` (getrennt durch Komma, Semikolon oder Leerzeichen) in *eines* der Felder einfügen, und beide Felder werden auf einmal gefüllt – das entspricht dem, was die meisten Karten und Websites in die Zwischenablage legen. Werte außerhalb des gültigen Bereichs oder nicht numerische Eingaben werden direkt markiert und nicht gespeichert; gültige Werte bleiben während der Eingabe erhalten. Die Intuition dahinter: Der häufigste Grund, einen Standort manuell zu setzen, ist die Bestimmung einer Aufnahme von einem anderen Ort als dem, an dem Sie gerade sind, und dieser Standort kommt meist als Text von anderswo – Eingeben und Einfügen machen daraus einen einzigen präzisen Schritt. Wenn Sie lieber auf eine Stelle zeigen als Zahlen einzugeben, öffnet **Auf Karte auswählen** dieselbe Vollbild-Kartenauswahl wie die Einrichtungsbildschirme, vorbelegt mit den aktuellen Koordinaten, und füllt beide Felder mit dem angetippten Ort.

### GPS jetzt aktualisieren

Erzwingt eine frische Standortbestimmung, statt den zuletzt zwischengespeicherten Wert weiterzuverwenden. Die Intuition dahinter: GPS-Abfragen werden pro Bildschirm zwischengespeichert, damit ein Einrichtungsbildschirm nicht bei jedem Öffnen auf eine Satellitenortung warten muss – dieser Zwischenspeicher kann aber kilometerweit veraltet sein, wenn Sie seit der letzten Session an einen neuen Ort gefahren sind. Tippen Sie darauf, wenn Sie sich bewegt haben und der Geofilter *hier* verwenden soll und nicht den Ort, an dem Ihr Morgen begann. Die aktuell zwischengespeicherten Koordinaten stehen im Untertitel, sodass Sie prüfen können, wo die App Sie vermutet. Gelingt innerhalb von etwa 10 Sekunden keine GPS-Ortung, fällt die App auf den vom Betriebssystem gemeldeten letzten bekannten Standort zurück und warnt Sie mit einer Snackbar, damit Sie wissen, dass der Wert veraltet ist.

### Offline-Karten-Downloads

Offline-Karten-Downloads sind derzeit ausgeblendet, solange BirdNET Live den öffentlichen Kachel-Dienst von OpenStreetMap nutzt. OpenStreetMap unterstützt normales interaktives Kartenbrowsen mit Namensnennung, klarem User-Agent und lokalem Zwischenspeicher, erlaubt aber kein Massen-Vorabladen oder Offline-Karten-Downloads von `tile.openstreetmap.org`. Die Implementierung des Downloaders bleibt für eine künftige Kachelquelle erhalten, die Offline-Pakete ausdrücklich gestattet.

### Artenfilter

- **Aus** – keine geografische Filterung
- **Standortfilter** – Arten ausschließen, die unter dem geografischen Schwellenwert liegen
- **Standortgewichtung** – das Geo-Modell als zusätzliches Gewichtungssignal verwenden

### Geofilter-Schwellenwert

Erscheint, wenn ein standortbasierter Filtermodus aktiv ist.

## Export & Sync

### Formate

Wählen Sie eine beliebige Kombination von Exportformaten aus – bei jedem Speichern/Teilen werden alle ausgewählten Formate gemeinsam in einem einzigen ZIP gebündelt. Wählen Sie ein einzelnes Format ohne Audioclips und ohne HTML-Bericht, erhalten Sie aus Gründen der Abwärtskompatibilität eine reine Datei (z. B. `session.csv`) statt eines ZIP:

- Raven Selection Table – zur Verwendung in Cornell Raven Pro.
- CSV – lässt sich in jeder Tabellenkalkulation öffnen.
- JSON – am einfachsten für die programmatische Verarbeitung; enthält die vollständigen Metadaten je Session.
- GPX – Track und Wegpunkte zur Verwendung in Kartenwerkzeugen (nur sinnvoll, wenn GPS aktiviert war).

Die Intuition dahinter: Viele Arbeitsabläufe brauchen mehr als ein Format gleichzeitig – eine CSV für die Tabellenkalkulation, eine Raven-Tabelle für die Auswertung am Desktop und eine JSON für das Analyseskript. Mit einem Einzelformat-Schalter hieß das früher, dieselbe Session dreimal zu exportieren. Jetzt haken Sie alle drei einmal an und sie reisen gemeinsam im ZIP.

### Audiodateien einschließen

Gespeichertes Audio zusammen mit den exportierten Tabellen oder Metadaten einschließen, sofern der Exportablauf das unterstützt. Auch das Teilen einer einzelnen Detektion folgt dieser Einstellung: Eine vollständige Session-Aufnahme wird auf die exakten Start- und Endzeitstempel der Detektion geschnitten, während eine Session nur mit Detektionsclips ihren gespeicherten Clip verwendet.

### Audio immer als WAV teilen

Wird nur angezeigt, wenn **Audiodateien einschließen** aktiviert ist. Wenn aktiviert, werden FLAC-Aufnahmen vor dem Teilen oder Exportieren in WAV umgewandelt. WAV ist universell kompatibel, aber deutlich größer als FLAC. Lassen Sie die Option daher aus, sofern das Werkzeug auf der Empfängerseite FLAC nicht lesen kann – manche ältere Desktop-Analysesoftware und einige Upload-Formulare können das bis heute nicht.

### App-Metadaten einschließen

Wenn aktiviert, enthält das Export-ZIP eine Begleitdatei `*.metadata.json`, die beschreibt, wie die Session entstanden ist: Version von BirdNET Live, Modellidentität, die zu Session-Beginn erfasste Wettermomentaufnahme sowie alle während der Aufnahme erkannten Warnungen zur Audiointegrität. Die Intuition dahinter: Genau diese Herkunftsangaben erlauben es Ihnen (oder einer prüfenden Person), eine Session Monate später zu reproduzieren oder nachzuvollziehen. Schalten Sie sie ab, wenn Sie sauber nur das Audio und Ihre gewählten Formate teilen wollen – etwa, um eine einzelne WAV-Datei ohne app-spezifische Beigaben bei iNaturalist oder eBird einzustellen.

### HTML-Bericht einschließen

Wenn aktiviert, enthält jedes Export-ZIP zusätzlich eine Datei `<session>_report.html` neben Tabelle, Audioclips und GPX. Öffnen Sie sie in einem beliebigen Webbrowser, und Sie erhalten eine druckfertige Zusammenfassung der Session: Kopfkarte mit Datum, Standort, Beobachter und Summen; eine interaktive Karte des GPS-Tracks und der Detektionsmarker; je Detektion eine Karte mit Miniaturbild aus der Cornell-Taxonomie, Namen, Score-Plakette, Ihrer Bestätigung, einer eventuell eingegebenen Notiz und dem originalen Audioclip als eingebettetem Player; sowie die verwendeten Analyseeinstellungen. Die Intuition dahinter: Eine CSV eignet sich hervorragend für Analysepipelines, taugt aber nicht zum Teilen mit einer nicht technischen Person oder zum Ausdrucken einer kurzen Feldzusammenfassung – der HTML-Bericht schließt diese Lücke mit einem Tippen. Artenminiaturen und Kartenkacheln benötigen beim ersten Öffnen der Datei eine Verbindung (sie werden live von der BirdNET-Taxonomie-API und von OpenStreetMap geladen), aber alles Übrige – Text, Layout, Audiowiedergabe, Links – funktioniert vollständig offline. Schalten Sie das ab, wenn Sie nur die Rohdaten brauchen und das ZIP ein paar KB kleiner halten wollen.

### Nur Audio teilen

Nehmen Sie den Haken bei jedem Format **und** beim HTML-Bericht **und** beim Feld für die App-Metadaten weg, sodass nur **Audiodateien einschließen** bleibt: Dann übergibt „Teilen“ dem Systemdialog die reine Aufnahme (z. B. `BirdNET_Live_…flac`) statt eines ZIP. Das ist der reibungsarme Weg, eine Session direkt an iNaturalist, eBird oder jede andere App zu senden, die eine unverpackte Audiodatei erwartet. Sessions mit mehreren Detektionsclips erzeugen weiterhin ein ZIP; beim Teilen einer einzelnen Detektion wird deren einzelner roher Clip übergeben.

## Datenschutz

Dieser Abschnitt steuert, **welche Drittdienste BirdNET Live in Ihrem Namen kontaktieren darf**. Die Inferenz selbst läuft vollständig auf Ihrem Gerät – diese Schalter regeln nur optionale Netzwerkfunktionen, die das Erlebnis anreichern. Alle drei Schalter sind bei einer Neuinstallation **standardmäßig deaktiviert**; nichts wird nach außen gesendet, bevor Sie es erlauben. Die Intuition dahinter: Jeder Schalter ist auf genau einen Dienst und genau einen Nutzen begrenzt, sodass Sie sich für genau das entscheiden können, was Ihrem Arbeitsablauf hilft – und für nichts anderes.

### Kartenkacheln erlauben

Erforderlich für jede interaktive Karte in der App (die Standortauswahl, die Live-Karte der Survey und die Session-Karte). Wenn aktiviert, laden die Karten-Widgets Rasterkacheln von den öffentlichen **OpenStreetMap**-Servern; die Anfragen nach Kachelkoordinaten verraten, welchen Weltausschnitt Sie gerade betrachten. Kacheln werden bis zu sechs Monate lokal zwischengespeichert, begrenzt auf 6000 Kacheln, damit wiederholte Kartenansichten effizient bleiben, ohne unbegrenzt zu wachsen. Das Aktivieren schaltet auch **Ortsnamen-Suche erlauben** ein, weil die meisten Nutzenden, die Karten laden, auch lesbare Ortsnamen bei ihren Sessions erwarten. Sie können die Ortsnamen-Suche separat wieder abschalten. Sind Kartenkacheln deaktiviert, zeigt jeder Kartenbildschirm eine Platzhalterkarte, sodass der Rest der App ohne Netzwerkabfluss weiter funktioniert.

### Ortsnamen-Suche erlauben

Wenn aktiviert, sendet die App Ihre aufgezeichneten Koordinaten an den Dienst **Nominatim von OpenStreetMap**, um einen kurzen Ortsnamen aufzulösen (z. B. *„Berlin, Deutschland“*), der neben der Session in der Session-Bibliothek und der Session-Übersicht angezeigt wird. Die Intuition dahinter: Numerische Koordinaten sind präzise, aber beim Scrollen durch eine lange Session-Liste schwer zu erfassen – ein Ortsname macht die Liste auf einen Blick lesbar. Wenn deaktiviert, zeigen Sessions nur die rohen Breiten-/Längengrade, und Nominatim wird nie kontaktiert.

### Wetterabfrage erlauben

Wenn aktiviert, erfasst jede gespeicherte Session über **Open-Meteo** eine einmalige Momentaufnahme der örtlichen Bedingungen (Temperatur, Niederschlag, Wind, Bewölkung) an den Aufnahmekoordinaten und zur Endzeit. Die Momentaufnahme erscheint in der Session-Übersicht unter der Standortzeile und wird in den JSON-Export, den Metadatenblock je Session und den HTML-Bericht übernommen. Die Intuition dahinter: Das Wetter ist einer der stärksten Prädiktoren für Vogelaktivität, und es automatisch zu erfassen – ohne dass Sie daran denken müssen, eine separate App zu prüfen – macht jede Session zu einem vollständigeren Beleg. Open-Meteo ist ein kostenloser Dienst und benötigt weder Konto noch API-Schlüssel. Wenn deaktiviert, werden keine Wetterdaten abgerufen oder gespeichert. Die Einrichtung von Point Count und Survey zeigt außerdem eine kompakte Wetterkarte nahe den Standortsteuerungen: Sie fragt diese Einwilligung nur bei Bedarf ab, zeigt nach dem Aktivieren eine Vorschau aus Symbol + Temperatur + Wind und verwendet beim Speichern der Session dieselbe zwischengespeicherte Momentaufnahme.

## Über

Die Zeile **Über** öffnet den Info-Bildschirm in der App.

## Gefahrenzone

### Onboarding zurücksetzen

Zeigt die Onboarding-Sequenz beim nächsten Start der App erneut.

### Alle Einstellungen zurücksetzen

Setzt jede Einstellung auf diesem Bildschirm auf ihren Standardwert zurück. Sessions, Aufnahmen, Sprachnotizen, Exporte und zwischengespeicherte Kartenkacheln bleiben unangetastet – nur die gespeicherten Einstellungen (Schieberegler, Schalter, Auswahlwerte) werden gelöscht. Nach der Bestätigung schließt sich die App, damit die neuen Standardwerte beim nächsten Start greifen.

Nützlich, wenn Sie nicht sicher sind, an welchem Schieberegler Sie gedreht haben, der etwas kaputt gemacht hat, oder wenn Sie das Gerät an jemanden weitergeben und eine saubere Konfiguration wollen, ohne die erhobenen Daten zu verlieren.

### Alle Daten löschen

Löscht dauerhaft Sessions, Detektionen, Aufnahmen, Sprachnotizen, eigene Artenlisten, gespeicherte Einstellungen sowie zwischengespeicherte Karten-, Ortsnamen-, Wetter-, Wiedergabe-, Übersichts- und Teilen-Daten. Der Bestätigungsdialog verlangt die Eingabe von `DELETE` und schließt anschließend die App, sodass der nächste Start mit einem sauberen lokalen Zustand beginnt.

Verwenden Sie das, bevor Sie ein Gerät an eine andere beobachtende Person übergeben, ein Feldtelefon ausmustern oder standortbezogene Historie aus der App entfernen. Exportieren Sie vorher alles, was Sie benötigen; dieser Vorgang lässt sich nicht rückgängig machen.

## Workflowspezifische Parameter außerhalb der Einstellungen

Einige Parameter werden in eigenen Einrichtungsbildschirmen konfiguriert und nicht im gemeinsamen Einstellungsbildschirm.

- [Point-Count-Modus](point-count-mode.md) hat eine eigene Einrichtung für Dauer und Standort.
- [Survey-Modus](survey-mode.md) hat einen eigenen Bildschirm für Survey-Parameter.
- [Dateianalyse](file-analysis.md) hat einen eigenen Schritt für Analyseparameter.
