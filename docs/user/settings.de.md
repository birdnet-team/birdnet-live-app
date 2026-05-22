# Einstellungen

BirdNET Live verwendet einen Einstellungsbildschirm für mehrere Arbeitsabläufe wieder. Der :material-tune:-Button öffnet die Abschnitte, die für den Bildschirm, von dem Sie gekommen sind, relevant sind.

## Funktionsweise des Einstellungsbereichs

- Wenn Sie die Einstellungen von zu Hause aus öffnen, wird der Vollbildmodus angezeigt.
- Wenn Sie die Einstellungen in Live, Vermessung, Punktzählung oder Dateianalyse öffnen, wird der Bildschirm nach den relevanten Abschnitten gefiltert.

## Allgemein

### Thema

Wählen Sie **Dunkel**, **Hell** oder **System**.

### App-Sprache

Legt die Sprache der Benutzeroberfläche fest.

### Artennamen

Steuert die Sprache, die für Artennamen verwendet wird. **App-Sprache folgen** verwendet dieselbe Sprache wie die Benutzeroberfläche, wenn dieser Name verfügbar ist.

### Wissenschaftliche Namen anzeigen

Zeigt wissenschaftliche Namen unterhalb gebräuchlicher Namen in der App an.

### Zeitstempel-Anzeige

Bestimmt, wie Zeitangaben einzelner Detektionen in der Sitzungsübersicht erscheinen.

- **Relativ** zeigt den Versatz seit Aufnahmebeginn, z. B. `00:12:34`. Am besten zum Durchsehen einer einzelnen Sitzung und zur Synchronisierung mit dem Spektrogramm.
- **Absolut** zeigt die lokale Uhrzeit der Detektion, z. B. `08:42:17`. Am besten zum Abgleich mit Feldnotizen, Wetterprotokollen oder gleichzeitigen Aufnahmen.

Liegt eine Detektion an einem anderen Kalendertag als der Sitzungsbeginn (z. B. bei einer Nachtaufnahme), wird der absoluten Zeit ein `+1d`-Suffix angehängt, damit man die morgige Morgendämmerung nicht mit der heutigen verwechselt.

Wenn **Absolut** ausgewählt ist, erscheint zusätzlich der Schalter **Sekunden in Zeitstempeln anzeigen**. Deaktiviere ihn, wenn du das kompaktere `08:42` dem `08:42:17` vorziehst — hilfreich beim Überfliegen langer Detektionslisten. Relative Versatzangaben zeigen immer Sekunden, weil zur Synchronisation mit dem Spektrogramm Sub-Minuten-Genauigkeit nötig ist.

Wenn **Absolut** ausgewählt ist, erscheint zusätzlich der Schalter **Sekunden in Zeitstempeln anzeigen**. Deaktiviere ihn, wenn du das kompaktere `08:42` dem `08:42:17` vorziehst — hilfreich beim Überfliegen langer Detektionslisten. Relative Versatzangaben zeigen immer Sekunden, weil zur Synchronisation mit dem Spektrogramm Sub-Minuten-Genauigkeit nötig ist.

Speicherung und Export verwenden unabhängig von dieser Einstellung immer UTC, sodass die Auswahl niemals die Daten verändert — nur deren Darstellung.

## Audio

Diese Steuerelemente werden in audiogesteuerten Live-Workflows angezeigt.

### Gewinnen

Passt die in der App angezeigte Eingangsverstärkung an. Verwenden Sie dies nur, wenn Sie sehr leise Aufnahmen oder Eingänge ausgleichen müssen.

### Hochpassfilter (Hz)

Reduziert niederfrequentes Rumpeln vor der Schlussfolgerung.

### Mikrofon

Hier können Sie ein bestimmtes Eingabegerät auswählen oder die **Systemstandards** beibehalten.

## Schlussfolgerung

### Fensterdauer

Steuert die Länge des Analysefensters.

### Vertrauensschwelle

Legt fest, wie konservativ Detektionen sein sollen.

### Empfindlichkeit

Höhere Werte machen den Detektor freizügiger, wodurch schwächere Anrufe auf Kosten von mehr Fehlalarmen erkannt werden können.

### Inferenzrate

Steuert, wie oft BirdNET die Inferenz ausführt.

### Score-Pooling

Steuert, wie überlappende Analysefenster kombiniert werden.

## Spektrogramm

### FFT-Größe

Steuert die Frequenzauflösung im Spektrogramm.

### Farbkarte

Wählen Sie **Viridis**, **Magma** oder **Graustufen**.

### Dauer (Scrollgeschwindigkeit)

Steuert, wie viel Zeit im Spektrogrammfenster sichtbar ist.

### Frequenzbereich

Legt die obere Anzeigefrequenz fest.

### Log amplitude

Wendet eine logarithmische Skalierung auf das Spektrogramm an, um das visuelle Ablesen zu erleichtern.

## Aufnahme

### Modus

- **Vollständig** – Speichern Sie die gesamte Aufnahme
- **Nur Detektionen** – Clips rund um Detektionen speichern
- **Aus** – keine Audioaufnahme

### Clip-Kontext

Wenn **Nur Detektionen** aktiv ist, zeigt die App einen einzelnen **Clip-Kontext**-Schieberegler (0–5 s) an, der festlegt, wie viel Audio auf **beiden Seiten** jeder Detektion erhalten bleibt. Jeder Clip ist „Analysefenster + 2 × Clip-Kontext“ lang, sodass der gespeicherte Clip bei einem Analysefenster von 3 Sekunden und dem Standardkontext von 1 Sekunde 5 Sekunden lang ist. Wenn Sie den Kontext auf 2 s festlegen, erhalten Sie einen 7 s langen Clip (2 s Pre-Roll + 3 s analysiertes Audio + 2 s Post-Roll). Größere Werte geben Ihnen mehr Platz für visuelle Inspektions- oder externe Überprüfungstools auf Kosten von Speicherplatz. 0 speichert nur das analysierte Fenster selbst.

### Format

Wählen Sie **WAV** oder **FLAC**.

## Standort

### Verwenden Sie GPS

Verwenden Sie Geräte-GPS anstelle manueller Koordinaten.

### Breiten-/Längengrad

Manuelle Koordinaten werden verwendet, wenn GPS deaktiviert ist.

### Artenfilter

- **Aus** – keine geografische Filterung
- **Standortfilter** – Arten ausschließen, die unter den geografischen Schwellenwert fallen
- **Standortgewichtung** – Verwenden Sie das Geomodell als zusätzliches Gewichtungssignal

### Geofilter-Schwellenwert

Erscheint, wenn ein standortbasierter Filtermodus aktiv ist.

## Exportieren und synchronisieren

### Formate

Wähle eine beliebige Kombination von Exportformaten – jeder Speicher- bzw. Teilen-Vorgang bündelt alle ausgewählten Formate gemeinsam in ein ZIP. Wählst du nur ein Format ohne Audioclips und ohne HTML-Bericht, erhältst du aus Kompatibilitätsgründen direkt eine Rohdatei (z. B. `session.csv`):

- Raven Selection Table – für Cornell Raven Pro.
- CSV – öffnet sich in jeder Tabellenkalkulation.
- JSON – ideal für programmatische Verarbeitung; enthält die vollständigen Sitzungsmetadaten.
- GPX – Track und Wegpunkte für Karten-Apps (nur sinnvoll, wenn GPS aktiv war).

Die Intuition: Viele Workflows brauchen mehrere Formate gleichzeitig – ein CSV für die Tabelle, eine Raven-Tabelle für den Desktop-Reviewer und ein JSON für das Auswertungsskript. Mit dem früheren Einzelformat-Schalter musste man dieselbe Sitzung dreimal exportieren. Jetzt klickst du alle drei einmal an und sie wandern gemeinsam ins ZIP.

### Audiodateien einbinden

Fügen Sie gespeicherte Audiodaten neben den exportierten Tabellen oder Metadaten ein, wenn dies vom Export-Workflow unterstützt wird.

## Datenschutz

Dieser Abschnitt steuert, **welche externen Dienste BirdNET Live in deinem Namen kontaktieren darf**. Die Inferenz selbst läuft vollständig auf deinem Gerät – diese Schalter regeln nur optionale Netzwerkfunktionen. Alle drei Schalter sind bei einer Neuinstallation **standardmäßig aus**; nichts wird abgerufen, bevor du es erlaubst. Die Intuition: Jeder Schalter ist auf genau einen Dienst und einen konkreten Nutzen zugeschnitten, sodass du gezielt aktivierst, was du brauchst.

### Kartenkacheln erlauben

Erforderlich für jede interaktive Karte (Standort-Picker, Survey-Live-Karte, Sitzungskarte). Wenn aktiv, laden Kartenansichten Rasterkacheln von den öffentlichen **OpenStreetMap**-Servern; Kachelanfragen verraten, welchen Bereich der Welt du gerade ansiehst. Wenn aus, zeigen alle Kartenbildschirme einen Platzhalter.

### Ortsnamen-Suche erlauben

Wenn aktiv, sendet die App deine aufgezeichneten Koordinaten an den **Nominatim**-Dienst von OpenStreetMap, um einen kurzen Ortsnamen (z. B. „Berlin, Deutschland“) aufzulösen, der in der Sessions-Bibliothek und im Session-Review angezeigt wird. Die Intuition: Numerische Koordinaten sind präzise, aber beim Scrollen schwer zu lesen – ein Ortsname macht die Liste auf einen Blick verständlich. Wenn aus, werden nur die Rohkoordinaten gezeigt und Nominatim wird nie kontaktiert.

### Wetterabfrage erlauben

Wenn aktiv, erfasst jede gespeicherte Aufnahme eine einmalige Momentaufnahme der lokalen Bedingungen (Temperatur, Niederschlag, Wind, Bewölkung) an den Aufnahmekoordinaten und der Endzeit über **Open-Meteo**. Die Daten erscheinen im Session-Review unter der Standortzeile und werden in den JSON-Export, den Metadaten-Block und den HTML-Bericht eingebettet. Die Intuition: Wetter ist einer der stärksten Prädiktoren für Vogelaktivität – automatische Erfassung macht jede Aufnahme zu einer vollständigeren Dokumentation. Open-Meteo ist kostenlos und benötigt weder Konto noch API-Schlüssel. Wenn aus, werden keine Wetterdaten abgerufen oder gespeichert.

## Um

Die Zeile **Info** öffnet den In-App-Info-Bildschirm.

## Gefahrenzone

### Onboarding zurücksetzen

Zeigt die Onboarding-Sequenz beim nächsten Start der App erneut an.

### Alle Daten löschen

Löscht dauerhaft Sessions, Detektionen, Aufnahmen, Sprachnotizen, eigene Artenlisten, gespeicherte Einstellungen sowie zwischengespeicherte Karten-, Orts-, Wetter-, Wiedergabe-, Review- und Teilen-Daten. Der Bestätigungsdialog verlangt die Eingabe von `DELETE` und schließt danach die App, damit der nächste Start aus einem sauberen lokalen Zustand erfolgt.

Verwenden Sie dies, bevor Sie ein Gerät an eine andere beobachtende Person weitergeben, ein Feldtelefon außer Dienst nehmen oder ortsbezogene Historie aus der App entfernen. Exportieren Sie zuerst alles, was Sie behalten möchten; diese Aktion kann nicht rückgängig gemacht werden.

## Workflowspezifische Parameter außerhalb der Einstellungen

Einige Parameter werden in ihren eigenen Setup-Bildschirmen konfiguriert und nicht im gemeinsamen Einstellungsbildschirm.

- [Punktzählmodus] (point-count-mode.md) hat seine eigene Dauer und Standorteinstellung.
- [Umfragemodus] (survey-mode.md) verfügt über einen eigenen Bildschirm mit Umfrageparametern.
- [Dateianalyse](file-analysis.md) verfügt über einen eigenen Analyseparameterschritt.