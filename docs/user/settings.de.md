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

Legt fest, wie konservativ Erkennungen sein sollen.

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
- **Nur Erkennungen** – Clips rund um Erkennungen speichern
- **Aus** – keine Audioaufnahme

### Clip-Kontext

Wenn **Nur Erkennungen** aktiv ist, zeigt die App einen einzelnen **Clip-Kontext**-Schieberegler (0–5 s) an, der festlegt, wie viel Audio auf **beiden Seiten** jeder Erkennung erhalten bleibt. Jeder Clip ist „Analysefenster + 2 × Clip-Kontext“ lang, sodass der gespeicherte Clip bei einem Analysefenster von 3 Sekunden und dem Standardkontext von 1 Sekunde 5 Sekunden lang ist. Wenn Sie den Kontext auf 2 s festlegen, erhalten Sie einen 7 s langen Clip (2 s Pre-Roll + 3 s analysiertes Audio + 2 s Post-Roll). Größere Werte geben Ihnen mehr Platz für visuelle Inspektions- oder externe Überprüfungstools auf Kosten von Speicherplatz. 0 speichert nur das analysierte Fenster selbst.

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

### Format

Wählen Sie ein Exportziel:

- Raben-Auswahltabelle
- CSV
- JSON
- GPX (Track + Wegpunkte)

### Audiodateien einbinden

Fügen Sie gespeicherte Audiodaten neben den exportierten Tabellen oder Metadaten ein, wenn dies vom Export-Workflow unterstützt wird.

## Um

Die Zeile **Info** öffnet den In-App-Info-Bildschirm.

## Gefahrenzone

### Onboarding zurücksetzen

Zeigt die Onboarding-Sequenz beim nächsten Start der App erneut an.

### Alle Daten löschen

Öffnet einen Bestätigungsablauf zum dauerhaften Entfernen gespeicherter App-Daten.

## Workflowspezifische Parameter außerhalb der Einstellungen

Einige Parameter werden in ihren eigenen Setup-Bildschirmen konfiguriert und nicht im gemeinsamen Einstellungsbildschirm.

- [Punktzählmodus](point-count-mode.md) hat seine eigene Dauer und Standorteinstellung.
- [Umfragemodus](survey-mode.md) verfügt über einen eigenen Bildschirm mit Umfrageparametern.
- [Dateianalyse](file-analysis.md) verfügt über einen eigenen Analyseparameterschritt.