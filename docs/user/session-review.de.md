# Session-Übersicht

In der Session-Übersicht macht BirdNET Live aus rohen Detektionen einen bearbeitbaren Datensatz.

## So gelangen Sie dorthin

BirdNET Live öffnet die Session-Übersicht automatisch nach Abschluss von:

- einer Live-Session
- einem Point Count
- einem Survey
- einem Dateianalyse-Lauf

Sie können außerdem jede gespeicherte Session aus der [Session-Bibliothek](session-library.md) erneut öffnen.

## Hauptbereiche

### Zusammenfassung und Wiedergabe

Die Session-Übersicht vereint Wiedergabe, Navigation im Spektrogramm und eine Artenliste. Bei Survey-Sessions kann sie zusätzlich den Kartenkontext anzeigen.

Die Kopfzeile mit der Zusammenfassung oben am Bildschirm enthält das Datum, einen Standort-Chip (Breiten-/Längengrad sowie optional einen aufgelösten Ortsnamen, wenn **Einstellungen → Datenschutz → Ortsnamen-Abfrage erlauben** aktiviert ist) und – sofern **Einstellungen → Datenschutz → Wetterabfrage erlauben** zum Zeitpunkt der Aufnahme aktiviert war – eine **Wetterzeile** unter dem Standort, die die am Ende der Session erfassten Bedingungen zeigt: eine kurze Zeile wie *„20,1 °C · Leichter Regen · 3,2 m/s SW“* mit vorangestelltem Wettersymbol. Tippen Sie auf die Zeile, um ein kleines Blatt mit Temperatur, Wind, Niederschlag und Bewölkung samt Open-Meteo-Quellenangabe aufzuklappen. Dieselbe Momentaufnahme erscheint auch im JSON-Export, im Metadatenblock der Session und im HTML-Report.

Der Spektrogrammstreifen über dem Player ist interaktiv: Tippen Sie, um zu springen, ziehen Sie mit einem Finger, um durch die Zeitleiste zu scrubben, und **zoomen Sie mit zwei Fingern (Pinch)** in ein schmales Zeitfenster hinein – nützlich, um das Timing überlappender Rufe zu untersuchen oder einen schnellen Triller zu zerlegen. Spreizen Sie wieder auf, um zur standardmäßigen 10-Sekunden-Übersicht zurückzukehren. Die Wiedergabetaste an einer Artenkopfzeile wählt stets den ersten Cluster, der tatsächlich einen aufgezeichneten Clip besitzt, sodass die Taste immer verfügbar ist, sobald irgendeine Detektion dieser Art abspielbar ist.

### Artenliste

Die Arten sind in aufklappbaren Zeilen gruppiert. Sie können Detektionen pro Art untersuchen und sich dabei durch die Aufnahme bewegen. Die Cluster-Zeilen unter einer aufgeklappten Art sind eingerückt, damit sich die übergeordnete Artenkarte optisch von ihren Untereinträgen abhebt.

Ein Suchfeld über der Liste filtert die Arten nach gebräuchlichem oder wissenschaftlichem Namen, sodass das Finden eines bestimmten Vogels in einer Session mit 100 Arten nur wenige Tastenanschläge statt langes Scrollen erfordert. Die Schaltfläche :material-sort: daneben ändert die Reihenfolge der Arten:

- **Höchste Konfidenz** (Standard) – Arten mit der höchsten Einzeldetektions-Konfidenz zuerst. Gut, um die sichersten Bestimmungen zu sichten. Wenn Sie in diesem Modus eine Art aufklappen, erscheinen Detektionen mit abspielbaren Audioclips vor solchen ohne Clip, danach nach Konfidenz.
- **Meiste Detektionen** – Arten mit der höchsten Anzahl an Detektionen zuerst. Gut, um die dominanten Sänger zu erkennen.
- **A → Z** – alphabetisch nach gebräuchlichem Namen. Vorhersehbar, sprachabhängig sortiert und leicht zu überfliegen, sobald eine Session viele Arten enthält.
- **Zuerst erkannt** – chronologisch nach dem Zeitpunkt der ersten Detektion. Die bisherige Standardreihenfolge; nützlich, wenn Sie parallel zur Spektrogramm-Zeitleiste prüfen.

Die gewählte Sortierung bleibt über Sessions hinweg erhalten.

### Arten manuell hinzufügen

Die Schaltfläche :material-plus-circle-outline: in der Werkzeugleiste öffnet die Artensuche für Vögel, die BirdNET übersehen hat. Ein Tipp auf ein Suchergebnis fügt die Art nicht sofort ein — zuerst erscheint ein Bestätigungsfenster mit der gewählten Art und zwei Kontrollkästchen:

- :material-ear-hearing: **Gehört** — Sie haben den Vogel gehört.
- :material-eye: **Gesehen** — Sie haben den Vogel gesehen.

Wählen Sie eines, beides oder keines aus und tippen Sie auf **Hinzufügen**. **Abbrechen** — oder ein Wisch nach unten — bringt Sie zurück zur Suche, ein Fehltipp kostet also nichts. **Gehört** ist standardmäßig aktiviert, und Ihre Auswahl bleibt für die nächste Art erhalten: Eine Reihe nur gesehener Vögel erfordert nur ein einziges Setzen von **Gesehen**. Bleiben beide leer, wird der Eintrag ohne Beobachtungsart gespeichert — nicht als „weder noch“.

Die Auswahl wird an der Detektion gespeichert und überall als kleines Ohr- und/oder Augensymbol neben dem Manuell-Abzeichen angezeigt: in Artenüberschriften, Cluster-Zeilen, im Clip-Player und in der Live-Survey-Liste. Sie wandert auch in die Exporte: als Spalte `Evidence` in CSV- und Raven-Tabellen, als Feld `evidence` in JSON und als Chip im HTML-Bericht. Dasselbe Fenster erscheint bei **Art ersetzen**, vorbelegt mit dem, was der Datensatz bereits trug.

### Aktionen je Detektion

Überall dort, wo eine Detektion erscheint – in der Artenliste, im Clip-Player-Blatt, in der Live-Survey-Liste und an den Survey-Kartenmarkierungen –, stehen dieselben Aktionen zur Verfügung:

- :material-check: **Bestätigen** – ein Ein-Tipp-Häkchen direkt in der Zeile, das eine Detektion als visuell oder akustisch überprüft markiert. Bestätigte Cluster und Kartenmarkierungen erhalten ein kleines grünes Häkchen, sodass sie auf einen Blick hervorstechen, und die Markierung wird in jedes Exportformat übernommen.
- :material-dots-vertical: **Mehr** – öffnet ein Überlaufmenü mit:
    - :material-share-variant: **Detektion teilen** – siehe *Teilen* weiter unten.
    - :material-swap-horizontal: **Art ersetzen** – eine andere Art für diese Detektion auswählen.
    - :material-delete-outline: **Detektion löschen** – entfernt die Zeile sofort. Für einige Sekunden erscheint eine SnackBar zum Rückgängigmachen, sodass Fehlgriffe umkehrbar sind. Ohne Bestätigungsdialog.
    - :material-delete-sweep-outline: **Art löschen** – entfernt jede Detektion dieser Art in einem Schritt aus der Session, mit derselben SnackBar zum Rückgängigmachen. Praktisch, um eine fehlbestimmte Geräuschquelle auszuräumen, ohne die Art aufzuklappen und die Cluster einzeln zu löschen.

#### Wisch-Kürzel in den Übersichtszeilen

In der Artenliste können Sie eine Detektion auch durch waagerechtes Wischen der Zeile bedienen:

- nach **rechts** wischen → löschen (mit Rückgängig)
- nach **links** wischen → die Einblendung zum Ersetzen der Art öffnen

Die beiden Hintergründe sind farbcodiert (Fehler-Rot gegenüber Primär-Blau), sodass die Wirkung der Geste erkennbar ist, bevor Sie sie ausführen.

Das Wischen einer **Artenkopfzeile** (nach links oder rechts) löscht alle Detektionen dieser Art auf einmal, mit derselben SnackBar zum Rückgängigmachen. Nützlich beim Sichten einer Session voller fehlbestimmter Geräusche.

### Eine einzelne Detektion teilen

Der Eintrag :material-share-variant: **Detektion teilen** öffnet das Teilen-Menü der Plattform mit einer knappen, feldtauglichen Nutzlast – gebräuchlicher und wissenschaftlicher Name, Konfidenz, Zeitstempel in ISO 8601 (UTC) sowie eine `geo:`-URI, wenn die Detektion über GPS verfügt – und hängt nach Möglichkeit den Audioclip an. Die geteilte Datei heißt `BirdNET_Live_<timestamp>_<species>.<ext>`, passend zum Schema des ZIP-Exports.

Der Audio-Anhang wird in dieser Reihenfolge ermittelt:

1. Der eigene Clip der Detektion auf dem Speicher.
2. **Bei Sessions, die eine durchgehende Datei aufzeichnen:** Das passende Audiofenster wird im laufenden Betrieb aus der Aufnahme herausgeschnitten. Sowohl durchgehende WAV- als auch FLAC-Aufnahmen werden unterstützt, und der Ausschnitt wird im selben Container wie die Quelle ausgegeben (WAV rein → WAV raus, FLAC rein → FLAC raus).
3. Ist keines von beiden verfügbar, erfolgt die Freigabe nur als Text – Standort und Zeitstempel landen weiterhin in der Nutzlast.

### Sprachmemos

Sie können kurze, gesprochene Kommentare an einzelne Detektionsdatensätze anhängen:

- **Aufnehmen**: Tippen Sie bei einem Detektions-Cluster auf die Schaltfläche :material-dots-vertical: und wählen Sie **Sprachmemo aufnehmen**, um den Sprachmemo-Dialog zu öffnen. Tippen Sie auf die große Mikrofontaste, um die Aufnahme zu starten. Eine Live-Wellenform gibt Ihre Stimme in Echtzeit wieder. Tippen Sie auf die Stopptaste, wenn Sie fertig sind.
- **Überprüfen**: Nach der Aufnahme können Sie das Memo mit dem integrierten Player anhören. Um das Memo zu ersetzen, tippen Sie auf die Schaltfläche **Erneut aufnehmen**. Um es zu speichern, tippen Sie auf die Schaltfläche **Speichern**.
- **Löschen**: Wenn eine Detektion bereits ein Sprachmemo besitzt, können Sie es entweder über das Überlaufmenü oder über den Sprachmemo-Dialog löschen.
- **Plattformspezifische Formate**: Auf Android und anderen Plattformen werden Sprachmemos im stark komprimierten AAC-Format (`.m4a`) mit 16 kHz aufgenommen. Auf iOS verwenden sie automatisch das WAV/PCM16-Format (`.wav`), um Kompatibilitätsprobleme von CoreAudio mit den aktiven Audio-Sessions der App zu vermeiden. Beide Formate werden vom ZIP-Export vollständig unterstützt.
- **Exportieren**: Beim Export der Session als ZIP werden Sprachmemos im Verzeichnis `memos/` gebündelt, und ihre relativen Pfade werden in den JSON- und CSV-Metadaten festgehalten.

### Survey-Track-Karte

Survey-Sessions zeigen eine kleine eingebettete Karte des GPS-Tracks samt Detektionsmarkierungen. Tippen Sie auf der eingebetteten Karte auf eine Markierung, um eine Detektion zu fokussieren – die Karte zentriert sich darauf. Tippen Sie auf die Schaltfläche :material-fullscreen: **Vergrößern** (oben rechts auf der eingebetteten Karte), um die **Vollbildkarte** zu öffnen; war eine Detektion fokussiert, öffnet sich die Vollbildkarte zentriert und herangezoomt auf diese Detektion, sodass Sie Ihre Position behalten.

#### Codierung der Markierungen

- **Die Konfidenz ist farbcodiert** über eine CVD-sichere Farbskala: von niedriger zu hoher Konfidenz verläuft sie von Violettblau über Türkis/Gelb bis Rot. Die Helligkeit der Skala ändert sich monoton, sodass sie auch in Schwarzweiß und für Personen mit Rot-Grün-Sehschwäche lesbar bleibt.
- **Detektionen mit Audio** zeigen einen farbigen Ring um das Artenfoto sowie ein Wiedergabe-Badge in der Ecke – tippen Sie darauf, um dasselbe Clip-Player-Blatt wie an anderer Stelle zu öffnen, mit Bestätigen, Teilen, Ersetzen und Löschen.
- **Stille Detektionen** (kein Clip auf dem Speicher) werden kleiner, blasser und mit einem neutralgrauen Ring dargestellt, sodass Audio-Detektionen stets als der primäre Inhalt erkennbar sind.
- **Überlappende Markierungen an derselben Stelle** werden nach Wichtigkeit gestapelt: hervorgehoben > mit Audio > höhere Konfidenz, sodass eine stille Markierung mit niedriger Konfidenz niemals eine starke Audio-Detektion verdecken kann.
- **Unterhalb von Zoomstufe 14,5** vereinfachen sich die Silhouetten zu farbigen Punkten, deren Größe sich nach der Konfidenz richtet, und dichte Cluster fallen zu einer Zählblase zusammen (das Clustering wird ab Zoomstufe 15 deaktiviert).

#### Filtern

Die Vollbildkarte hat einen dauerhaften **Filter-Chip**, der oben rechts auf der Karte verankert ist. Tippen Sie darauf, um das Filterblatt zu öffnen; die Beschriftung des Chips zeigt stets, was gerade wirksam ist (*„Alle Arten“*, *„Mit Audio“*, *„≥ 80 %“* oder ein einzelner Artname). Verfügbare Filter:

- **Alle Detektionen** (Standard).
- **Mit Audioclip** – nur Detektionen, deren Clip noch auf dem Speicher liegt und abspielbar ist.
- **Manuelle Ergänzungen** – nur Detektionen, die Sie in der Session-Übersicht hinzugefügt haben (automatisch erkannte ausgenommen).

Sie können die Detektionen zusätzlich nach Konfidenz einschränken. Der Schieberegler legt die Untergrenze der Konfidenz fest (beginnt bei 10 %).

Unter dem Konfidenz-Schieberegler liegt ein Auswahlfeld **Auf Art beschränken**, mit dem Sie die Karte auf eine einzelne Art reduzieren können – nützlich für die Frage „Wo genau entlang der Route habe ich die Singdrossel gehört?“. Ein Eintrag *Alle Arten* hebt die Einschränkung auf. Die Filter lassen sich kombinieren: *Mit Audioclip* + *Singdrossel* + *> 80 %* zeigt etwa nur die abspielbaren Singdrossel-Markierungen mit über 80 %.

Ist ein Filter aktiv, erhält der Titel der App-Leiste eine Untertitelzeile mit der Trefferzahl (z. B. *„7 Detektionen“*). *Zurücksetzen* im Filterblatt stellt den Standard wieder her.

## Symbole der Symbolleiste

Die Symbolleiste verwendet dieselben Symbolbedeutungen, die unter [Symbole und Steuerelemente](icons-and-controls.md) beschrieben sind:

- :material-plus-circle-outline: — Inhalt hinzufügen
- :material-undo-variant: / :material-redo-variant: — durch Bearbeitungen schrittweise gehen
- :material-content-cut: — Zuschneide-Modus
- :material-content-save: — Bearbeitungen speichern
- :material-share-variant: — exportieren oder teilen
- :material-delete-outline: — Session verwerfen
- :material-play: — einen Survey fortsetzen, sofern diese Aktion verfügbar ist
- :material-help-circle-outline: — das Hilfeblatt zur Session-Übersicht öffnen
- :material-tune: — Einstellungen öffnen

## Typische Aufgaben bei der Durchsicht

- Detektionen anhand von Wiedergabe und Spektrogrammkontext prüfen
- eine Art oder Anmerkung hinzufügen
- die Aufnahme auf das nützliche Intervall zuschneiden
- den geprüften Ergebnissatz exportieren

## Export

Das Exportverhalten hängt von den in den [Einstellungen](settings.md) gewählten Optionen ab. Die App kann Detektionen und optional Audio in das gewählte Exportformat packen. Jeder Export enthält Herkunftsmetadaten – die App-Version, Modellname und -version, Artensprache, Export-Zeitstempel, die mit der Session gespeicherten Einstellungen sowie die relevanten Exportoptionen –, die in eine `<prefix>.metadata.json`-Begleitdatei (ZIP) oder einen `meta`-Block auf oberster Ebene (JSON) geschrieben werden, sodass Exporte selbsterklärend und reproduzierbar sind.

Der `settings`-Block des JSON-Exports hält die Werte fest, die *tatsächlich auf diese Session angewendet* wurden – Empfindlichkeit, Modus und Fensteranzahl des Score-Poolings, Mikrofonverstärkung und die Grenzfrequenz des Hochpasses – und nicht das, was gerade in den Einstellungen eingestellt ist. So können Sie ein Ergebnis Monate später reproduzieren oder zwei Surveys vergleichen, ohne sich zu merken, wie die Schieberegler beim Lauf standen.

Alle Zeitstempel in exportierten Dateinamen (`BirdNET_Live_<date>_<time>_…`) und innerhalb der CSV-/JSON-Nutzlasten werden in der *aktuellen* lokalen Zeit Ihres Smartphones formatiert. Die zugrunde liegenden Datensätze werden in UTC gespeichert und bei der Ausgabe umgerechnet.
