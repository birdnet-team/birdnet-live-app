# Uploads

Uploads senden abgeschlossene Sessions von vielen Telefonen in einen gemeinsamen Projektordner. Eine Projektleitung richtet einen Ordner einmal ein und gibt einen Link oder einen QR-Code aus; jede beitragende Person fügt ihn ein oder scannt ihn, und von da an lässt sich jede Session mit zwei Fingertipps aus dem Dialog „Teilen“ an diesen Ordner senden. ARU-Einsätze können jede abgeschlossene Session selbstständig senden.

Uploads laufen nur in eine Richtung. Die App schreibt Dateien in den Projektordner und liest, listet oder löscht dort nie etwas. Das Löschen einer Session auf Ihrem Telefon lässt die hochgeladene Kopie unberührt, und es wird nie etwas hochgeladen, solange Sie kein Ziel angehakt oder automatische ARU-Uploads eingeschaltet haben.

## Funktionsweise

Ein **Ziel** ist ein WebDAV-Ordner, in den die App schreiben kann. Drei Arten funktionieren ohne weitere Vorbereitung:

- eine **Nextcloud-File-Drop**-Freigabe, die empfohlene Wahl für die meisten Projekte;
- eine beliebige **WebDAV-Adresse** mit Benutzername und Passwort, zum Beispiel ein Ordner in Ihrem eigenen Cloud-Konto oder ein institutioneller Server;
- der **Referenz-Drop-Server**, der mit BirdNET Live ausgeliefert wird, für Projektleitungen, die Tokens je beitragender Person und einen fertigen CSV-Export wünschen (siehe [Entwicklerhandbuch](../developer/upload-drop-server.md)).

Jeder Upload ist **eine ZIP-Datei pro Session**, benannt wie der Teilen-Export, zum Beispiel `BirdNET_Live_2026-05-14_06-30-00_#13.zip`. Sie enthält immer den JSON-Datensatz der Session und, je nachdem, was Sie anhaken, das Audio, die Detektionstabellen, den HTML-Bericht und die App-Metadatendatei. Die ZIP-Datei landet in einem Ordner, der nach Ihrer **Upload-ID** benannt ist, einem achtstelligen Code, den die App aus einer zufälligen Identität ableitet, die sie für diese Installation aufbewahrt. Der Ordner der Projektleitung sieht daher so aus:

```
4ee91c8f/BirdNET_Live_2026-05-14_06-30-00_#13.zip
4ee91c8f/BirdNET_Live_2026-05-14_07-02-10_#14.zip
b27c0e51/BirdNET_Live_2026-05-14_06-45-00_#3.zip
.birdnet-live/4ee91c8f.json
.birdnet-live/b27c0e51.json
```

Der Ordner `.birdnet-live` enthält eine kleine Registrierungsdatei pro Gerät, die der Verbindungstest schreibt. Nextcloud blendet ihn aus, solange „Versteckte Dateien anzeigen“ nicht eingeschaltet ist. Er enthält die Upload-ID, die App-Version, die Plattform und die optionale **Teilnehmerkennung** (ein Name, eine E-Mail oder eine Teilnehmernummer), die eine beitragende Person eingegeben hat, damit die Projektleitung erkennt, wer hinter jedem Code steht, ohne dass je ein Name zu einem Ordnernamen wird. Dieselbe Kennung wird in den JSON-Datensatz jeder hochgeladenen Session geschrieben.

## Für Projektleitungen

### Option A: ein Nextcloud File Drop

1. Legen Sie in Nextcloud einen Ordner für das Projekt an, zum Beispiel `Frühjahrserfassung 2027`.
2. Öffnen Sie dessen Freigabebereich, erstellen Sie einen **Freigabelink** und setzen Sie dessen Berechtigungen auf **Dateien ablegen (nur Hochladen)**. Beitragende können dann Dateien hinzufügen, sehen aber nie, was andere gesendet haben.
3. Setzen Sie ein **Passwort** für den Link. Ohne Passwort kann jede Person, die den Link findet, in den Ordner hochladen. Ein File Drop lässt sich auch dann nicht lesen, daher ist ein fehlendes Passwort eine Entscheidung, die die App ohne Beanstandung akzeptiert.
4. Setzen Sie optional ein Ablaufdatum auf das Projektende.
5. Kopieren Sie den Freigabelink. Er sieht so aus: `https://cloud.example.org/s/AbCdEf123456`.

Die App wandelt diesen Link selbst in den WebDAV-Endpunkt der Freigabe um; Beitragende sehen nie eine WebDAV-Adresse. Ein File Drop überschreibt nie: Lädt eine beitragende Person dieselbe Session erneut hoch, behält Nextcloud die ältere Kopie unter einem nummerierten Namen, sodass die neueste Datei diejenige ohne Nummer ist.

Nextcloud-Freigaben mit der Berechtigung **Hochladen und Bearbeiten** funktionieren ebenfalls, aber die App warnt Beitragende, dass die Zugangsdaten den Ordner auflisten können, weil dann jede Person mit dem Link die Daten aller anderen lesen kann. Nur-Lese-Freigaben werden vom Verbindungstest abgelehnt.

### Option B: Ihr eigener WebDAV-Ordner

Jeder WebDAV-Server funktioniert: ein Ordner in einem persönlichen Cloud-Konto, ein institutioneller Dateiserver, ownCloud oder Nextcloud mit einem regulären Konto. Beitragende geben beim Beitreten unter **Erweitert** die Adresse sowie Benutzername und Passwort ein. Verwenden Sie für ein Nextcloud- oder ownCloud-Konto ein **App-Passwort** aus den Sicherheitseinstellungen des Kontos, nie das Anmeldepasswort; wird nur ein Hostname angegeben, probiert die App zusätzlich die üblichen Nextcloud- und ownCloud-Pfade auf diesem Host aus.

Solche Zugangsdaten können den Ordner in der Regel lesen, daher zeigt der Verbindungstest eine Warnung. Bevorzugen Sie eine Einrichtung mit reinem Schreibzugriff, wenn nicht alle Beitragenden zu einem Team gehören.

### Option C: der Referenz-Drop-Server

`tools/webdav_drop_server` im Quell-Repository ist ein kleiner Python-Server mit widerrufbaren Tokens je beitragender Person, einem Befehl `collect`, der jeden hochgeladenen JSON-Datensatz in `sessions.csv`, `detections.csv` und `species_summary.csv` zusammenführt, und einem Befehl `invite`, der einen Beitrittslink und einen QR-Code ausgibt. Einrichtung und Bereitstellung sind im [Entwicklerhandbuch](../developer/upload-drop-server.md) beschrieben.

### Beitrittslink und QR-Code erstellen

Ein Beitrittslink enthält alles, was eine beitragende Person braucht, in einem Stück: das Ziel, die Zugangsdaten, einen Projektnamen und Ihre vorgeschlagenen Voreinstellungen. Öffnen Sie die [Beitrittsseite](../join.md) auf dieser Website und füllen Sie aus:

- **Share link or WebDAV address**: der Nextcloud-Freigabelink von oben oder die Adresse des WebDAV-Ordners.
- **User name**: für einen Nextcloud-Freigabelink leer lassen.
- **Share password or token**: das Freigabepasswort oder das Konto- bzw. Token-Geheimnis.
- **Project name shown in the app**: was Beitragende als Namen des Ziels sehen werden. Sie können es umbenennen, aber dies ist die Voreinstellung.
- **Suggest including audio** und **Suggest Wi-Fi only**: die Voreinstellungen für die Schalter des Ziels.

Drücken Sie **Build link and QR code**. Alles geschieht in Ihrem Browser; nichts wird irgendwohin gesendet. Das Geheimnis steckt im Teil des Links nach dem `#`, den Browser nie an den Webserver übertragen, der die Seite ausliefert.

Alternativ treten Sie dem Ziel zuerst auf Ihrem eigenen Telefon bei (siehe unten), öffnen dann das Ziel unter **Einstellungen → Export & Sync → Upload-Ziele** und tippen auf **Beitrittscode anzeigen**. Die App zeigt dieselbe Art von QR-Code mit einer Schaltfläche **Link kopieren**.

### Ausgeben

Drucken Sie den QR-Code auf den Feldbogen, zeigen Sie ihn bei der Einweisung auf einem Bildschirm oder senden Sie den Link per Nachricht. **Behandeln Sie den Link und den Code wie ein Passwort**: Jede Person, die ihn besitzt, kann in Ihr Projekt hochladen. Falls er durchsickert, ändern Sie das Freigabepasswort oder widerrufen Sie das Token und geben Sie einen neuen Code aus.

Wenn eine beitragende Person den Code mit der Kamera ihres Telefons scannt, öffnet der Browser eine kleine Zielseite mit einer Schaltfläche **Open in BirdNET Live**, die im Bildschirm „Ziel hinzufügen“ der App landet, mit bereits eingetragenem Link. Den Link direkt in diesen Bildschirm einzufügen funktioniert genauso.

### Was Sie sehen werden

Ein Ordner pro Gerät, eine ZIP-Datei pro Session und die versteckten Registrierungen in `.birdnet-live`. Öffnen Sie eine ZIP-Datei, um den JSON-Datensatz (immer vorhanden) sowie die Tabellen, den Bericht und das Audio zu finden, die die beitragende Person einbezogen hat. Um zu erfahren, welche Person hinter einer Upload-ID steht, lesen Sie die Registrierungsdatei dieses Codes oder das Feld `meta.participant` in einem beliebigen ihrer JSON-Datensätze. Beim Referenz-Drop-Server erledigt `collect` das für Sie und schreibt eine Spalte `participant`.

## Für Beitragende

### Einem Ziel beitreten

1. Öffnen Sie **Einstellungen → Export & Sync → Upload-Ziele** und tippen Sie auf **Ziel hinzufügen**. Das Scannen des QR-Codes eines Projekts mit Ihrer Kamera oder das Antippen eines erhaltenen Beitrittslinks führt Sie zum selben Bildschirm, mit bereits eingetragenem Link.
2. Fügen Sie den Beitrittslink, den Nextcloud-Freigabelink oder eine WebDAV-Adresse in **Beitrittslink oder Serveradresse** ein. Die Schaltfläche **Einfügen** übernimmt ihn aus der Zwischenablage.
3. Geben Sie optional eine **Teilnehmer-ID, Name oder E-Mail (optional)** ein. Sie wird mit jedem Upload gespeichert, damit die Projektleitung weiß, von wem er stammt, und erscheint nie in Ordnernamen. Unter dem Feld zeigt die App **Ihre Upload-ID**, den Ordner, in dem Ihre Uploads landen werden.
4. Öffnen Sie für eine einfache WebDAV-Adresse **Erweitert** und geben Sie **Benutzername** und **Passwort oder Token** ein. Ein Nextcloud-Freigabelink braucht keines von beiden; hat die Freigabe ein Passwort, geben Sie es als Passwort ein.
5. Tippen Sie auf **Verbindung testen**. Die App kontaktiert den Server, legt den versteckten Registrierungsordner an, prüft, ob die Zugangsdaten den Ordner auflisten können, und schreibt Ihre Registrierungsdatei. Das Ergebnis ist ein Satz: **Verbindung funktioniert**, eine Warnung, die Sie lesen sollten, oder ein Fehler mit der wahrscheinlichen Abhilfe.
6. Geben Sie dem Ziel einen **Name des Ziels** (aus dem Beitrittslink vorausgefüllt), entscheiden Sie, ob **Nur über WLAN hochladen** gelten soll, und tippen Sie auf **Ziel speichern**.

Gespeichert wird erst, wenn der Test bestanden ist. Die Zugangsdaten wandern in den Schlüsselbund des Geräts, nie in exportierte Daten.

Warnungen, die Sie verstehen sollten:

- **Diese Zugangsdaten können das Ziel auflisten** bedeutet, dass die Freigabe oder das Konto die Daten anderer Beitragender lesen kann. Uploads funktionieren, aber bitten Sie die Projektleitung um einen File Drop oder ein Token mit reinem Schreibzugriff, wenn am Projekt Personen außerhalb Ihres Teams beteiligt sind.
- **Diese Freigabe hat kein Passwort und lässt sich auflisten** vereint beide Risiken: Jede Person mit dem Link kann alles lesen. Bitten Sie die Projektleitung, ein Passwort zu setzen oder einen File Drop zu verwenden.
- **Dieser Server erlaubt keine Ordner** ist ein Hinweis: Uploads verwenden flache Dateinamen wie `4ee91c8f__BirdNET_Live_….zip` statt eines Ordners.

### Der Zielbildschirm

Das Antippen eines Ziels in der Liste öffnet dessen Bildschirm mit der Serveradresse, dem Zeitpunkt des Hinzufügens und der letzten Verwendung sowie diesen Steuerelementen:

- **Umbenennen** (der Stift in der App-Leiste) ändert den in der App angezeigten Namen.
- **Nur über WLAN hochladen** hält Uploads zurück, solange das Telefon im Mobilfunknetz ist.
- **ARU-Sessions automatisch hochladen** reiht jede abgeschlossene ARU-Session ohne Rückfrage für dieses Ziel ein (siehe unten).
- **Verbindung testen** wiederholt den Verbindungstest, zum Beispiel nachdem die Projektleitung das Passwort geändert hat.
- **Beitrittscode anzeigen** zeigt einen QR-Code plus **Link kopieren**, damit ein zweites Telefon demselben Ziel beitreten kann.
- **Ziel entfernen** vergisst das Ziel und seine Zugangsdaten und verwirft ausstehende Uploads dorthin. Bereits hochgeladene Sessions bleiben auf dem Server.

Der erste Eintrag der Zielliste ist **Ihre Upload-ID**, mit der Teilnehmerkennung darunter; tippen Sie darauf, um die Kennung zu ändern. Das Ändern verschiebt nichts auf dem Server, da die Ordner nach der ID benannt sind.

### Eine Session hochladen

Uploads starten aus derselben Aktion **Teilen**, die Sie bereits verwenden, an drei Stellen:

- im **Drei-Punkte-Menü** (:app-moreVert:) einer Session-Karte in der Session-Bibliothek;
- über die Schaltfläche **Teilen** nach dem Auswählen mehrerer Sessions in der Session-Bibliothek;
- über das Symbol **Teilen** (:app-share:) in der Symbolleiste der Session-Übersicht.

Sobald mindestens ein Ziel existiert, hat der Dialog „Teilen“ zwei Reiter:

- **Inhalt** wählt, was der Export enthält: **Audio** (die vollständige Aufnahme oder die Detektionsclips, wenn nur Clips behalten wurden) und **Metadaten** (die Tabellen, der Bericht und die App-Metadatendatei, die unter Export & Sync aktiviert sind). Die Kästchen entsprechen anfangs Ihren Einstellungen und gelten nur für dieses Teilen.
- **Senden an** listet **Teilen-Dialog** (andere Apps, Dateien, Nachrichten) und ein Kästchen pro Ziel. Die Markierung am Reiter zählt die angehakten Ziele. Beim letzten Mal angehakte Ziele sind vorausgewählt, außer denen, an die diese Session bereits gesendet wurde: Sie beginnen abgewählt und zeigen **Hochgeladen** mit dem Datum sowie **Ankreuzen, um erneut hochzuladen**. Beim Öffnen des Dialogs prüft die App im Stillen jedes Ziel; meldet der Server, dass er den Upload ablehnen würde, zum Beispiel weil das Passwort geändert oder die Freigabe entfernt wurde, wird die Zeile rot und nennt den Grund.

Wählen Sie **Teilen-Dialog** ab, und die Schaltfläche heißt **Hochladen**; sind beide angehakt, heißt sie **Teilen und hochladen**. Eine Snackbar bestätigt, wie viele Sessions eingereiht wurden. Eine Session kommt immer zuerst in die Warteschlange und wird im Hintergrund hochgeladen, sodass Sie weiterarbeiten können.

### Einen Upload verfolgen

Die Session-Karte in der Session-Bibliothek zeigt den Status als erste Zeile unter dem Session-Titel: **In der Warteschlange**, **Wartet auf WLAN**, **Wartet auf eine Netzverbindung**, **Wird hochgeladen…**, **Hochgeladen am** mit dem Datum oder ein Fehler. Tippen Sie auf die Zeile für die Liste je Ziel mit **Jetzt wiederholen** und **Aus der Warteschlange entfernen**. Die Session-Übersicht zeigt denselben Status als Wolkensymbol in der App-Leiste; Antippen öffnet dieselbe Liste.

Fehlgeschlagene Uploads wiederholen sich selbstständig mit wachsenden Abständen von bis zu sechs Stunden, bis zu dreißig Versuche lang. **Fehlgeschlagen, wird wiederholt** bedeutet, dass die App es erneut versuchen wird. **Upload fehlgeschlagen. Prüfen Sie die Einstellungen des Ziels.** bedeutet, dass der Server abgelehnt hat und eine Wiederholung nicht helfen kann: Das Passwort wurde geändert, Uploads wurden abgeschaltet oder das Ziel wurde entfernt. Öffnen Sie das Ziel, führen Sie **Verbindung testen** aus und entfernen Sie es und fügen Sie es erneut hinzu, falls sich die Zugangsdaten geändert haben.

Die Zeile und das Symbol erscheinen nur, solange mindestens ein Ziel, an das die Session gesendet wurde, noch in den Einstellungen existiert. Entfernen Sie das Ziel, verschwinden sie, weil „hochgeladen“ dann keine Aussage mehr über irgendein Ziel ist, das Sie haben.

### Was im Hintergrund läuft

Eingereihte Uploads laufen, solange die App geöffnet ist, und immer dann, wenn sie in den Vordergrund zurückkehrt. Unter Android laufen sie auch bei geschlossener App: Das System startet sie, sobald ein passendes Netz verfügbar ist, WLAN, wenn das Ziel es verlangt, und wiederholt sie, bis die Warteschlange leer ist. Unter iOS laufen Uploads, solange die App geöffnet ist.

### Eine Session erneut hochladen

Dieselbe Session erneut hochzuladen, zum Beispiel nach dem Korrigieren von Detektionen in der Session-Übersicht, schreibt denselben Dateinamen in denselben Ordner. Server, die es erlauben, ersetzen die Datei; ein Nextcloud File Drop behält stattdessen die ältere Kopie unter einem nummerierten Namen. In beiden Fällen erhält die Projektleitung die neueste Version, und nichts wird gelöscht.

## ARU-Modus

Feldeinsätze erzeugen viele Sessions, oft während niemand am Telefon ist. Schalten Sie bei einem Ziel **ARU-Sessions automatisch hochladen** ein, und jede abgeschlossene ARU-Session wird ohne Dialog dafür eingereiht, mit den Export-&-Sync-Voreinstellungen für Audio und Metadaten. Ein Einsatz, der jeden Zyklus als eigene Session speichert, lädt Zyklus für Zyklus hoch; die zusammengefasste Einsatz-Session wird nicht doppelt hochgeladen.

Lassen Sie **Nur über WLAN hochladen** für eine Station mit Mobilfunkvertrag eingeschaltet, sofern der Vertrag das Audio nicht verkraftet, und erwägen Sie die Aufnahme mit **Nur Detektionen** oder **Aus**, wenn das Audio zum Senden zu groß wäre. Die Uploads fließen dann ab, sobald das Telefon ein passendes Netz sieht, unter Android auch, während die App im Hintergrund ist.

## Zwei Beispiele aus der Praxis

### Eine Wochenenderfassung mit einem Nextcloud File Drop

Die Projektleitung legt in der Universitäts-Nextcloud einen Ordner `Birdathon 2027` an, gibt ihn als File Drop mit Passwort frei, fügt Freigabelink und Passwort auf der Beitrittsseite ein, benennt das Projekt und druckt den QR-Code auf den Einweisungsbogen. Zwanzig Freiwillige scannen ihn am Samstagmorgen, geben ihren Namen als Teilnehmerkennung ein, bestehen den Verbindungstest und speichern.

Am Sonntagabend öffnet jede freiwillige Person die Session-Bibliothek, wählt die Sessions des Wochenendes aus, tippt auf Teilen, lässt das Projekt unter Senden an angehakt und tippt auf **Hochladen**. Die Uploads warten zu Hause auf WLAN und werden über Nacht fertig. Am Montag findet die Projektleitung zwanzig nach Upload-ID benannte Ordner mit jeweils einer Handvoll ZIP-Dateien und liest die Namen der Freiwilligen aus den versteckten Registrierungsdateien oder dem Feld `meta.participant` in den JSON-Datensätzen.

### Korrekturen in der Session-Übersicht, dann eine ARU-Station

Eine beitragende Person überprüft eine Session, entfernt zwei falsche Detektionen, fügt eine Art von Hand hinzu und speichert. Das Wolkensymbol in der App-Leiste der Session-Übersicht zeigt, dass die Session am Samstag hochgeladen wurde. Sie tippt auf das Teilen-Symbol in der Symbolleiste, hakt das Projekt unter Senden an an, wo es abgewählt beginnt und **Hochgeladen** mit dem Datum anzeigt, und drückt **Hochladen**. Die korrigierte ZIP-Datei ersetzt die frühere oder landet auf einem File Drop mit nummeriertem Namen daneben.

Dieselbe Person lässt ein Telefon als ARU-Station an einem Röhricht mit einem WLAN-Hotspot in der Hütte zurück. Sie tritt dem Projektziel auf diesem Telefon bei, schaltet **ARU-Sessions automatisch hochladen** ein und lässt **Nur über WLAN hochladen** eingeschaltet. Jeden Morgen werden die abgeschlossenen Nachtzyklen eingereiht und hochgeladen, während die Station ruht; die Projektleitung sieht neue ZIP-Dateien unter der Upload-ID dieses Telefons erscheinen, ohne dass jemand es anfasst.

## Datenschutz und Verantwortung

Upload-Ziele werden von Projektleitungen betrieben, nicht vom BirdNET-Team. Der Ordner, der Server, wer ihn lesen kann und wie lange die Daten aufbewahrt werden, unterliegen den eigenen Datenschutz- und Sicherheitsregeln der Projektleitung; fragen Sie dort nach Einzelheiten, bevor Sie beitreten. BirdNET Live schreibt nur, was Sie zum Senden ausgewählt haben, und bewahrt die Zugangsdaten im Schlüsselbund Ihres Geräts auf.

Ein Upload enthält, was ein Teilen enthalten würde: den JSON-Datensatz der Session mit Detektionen, Zeiten, Koordinaten, dem Beobachternamen und dem Ortsnamen, falls gesetzt, der Upload-ID des Geräts, der von Ihnen eingegebenen Teilnehmerkennung und der App-Version; dazu das Audio, die Tabellen und den Bericht, die Sie angehakt haben. Prüfen Sie den Reiter Inhalt vor dem Senden und lassen Sie das Audio weg, wenn eine Aufnahme Stimmen oder anderes enthalten könnte, das Sie dem Projekt nicht aushändigen würden. **Sie sind für das verantwortlich, was Sie hochladen.** Laden Sie keine Daten hoch und teilen Sie keine Daten, die Sie als privat oder vertraulich betrachten, und laden Sie keine Aufnahmen hoch, die Sie nicht weitergeben dürfen.

## Fehlerbehebung

| Meldung | Bedeutung | Was zu tun ist |
| --- | --- | --- |
| Das sieht nicht wie ein Link oder eine Serveradresse aus. | Der Text ist keine URL. | Fügen Sie den vollständigen Beitrittslink, Freigabelink oder die `https://`-Adresse ein. |
| Der Server hat die Zugangsdaten abgelehnt. | Falsches oder fehlendes Passwort oder eine entfernte Freigabe. Nextcloud antwortet so auch bei gelöschten Freigaben. | Verwenden Sie das Freigabepasswort oder ein App-Passwort; fragen Sie die Projektleitung, ob die Freigabe noch existiert. |
| Diese Adresse ist kein WebDAV-Endpunkt. | Sie haben die Webseite eines Ordners eingefügt, keinen Freigabelink und keine WebDAV-Adresse. | Fügen Sie den Freigabelink (`…/s/…`) oder die WebDAV-Adresse ein. |
| Uploads sind hier nicht erlaubt. | Die Freigabe ist schreibgeschützt. | Bitten Sie die Projektleitung um einen File Drop oder eine Upload-Berechtigung. |
| Der Ordner existiert auf dem Server nicht. | Die Adresse zeigt ins Leere, oder der Ordner wurde gelöscht. | Prüfen Sie die Adresse mit der Projektleitung. |
| Das Zertifikat des Servers konnte nicht überprüft werden. | Selbstsigniertes oder defektes TLS. | Bitten Sie die Projektleitung um eine Adresse mit gültigem Zertifikat. |
| Diese Adresse verwendet unverschlüsseltes HTTP. | Unverschlüsselte Verbindung außerhalb Ihres lokalen Netzwerks. | Verwenden Sie eine `https://`-Adresse. |
| Wartet auf WLAN | Das Ziel ist auf „Nur über WLAN“ eingestellt, und das Telefon ist im Mobilfunknetz. | Warten Sie, oder schalten Sie den WLAN-Schalter des Ziels aus. |
| Fehlgeschlagen, wird wiederholt | Ein vorübergehendes Problem wie eine abgebrochene Verbindung oder ein Serverfehler. | Nichts; die App wiederholt es selbstständig. **Jetzt wiederholen** erzwingt einen Versuch. |
| Upload fehlgeschlagen. Prüfen Sie die Einstellungen des Ziels. | Der Server hat aus einem Grund abgelehnt, den eine Wiederholung nicht beheben kann. | Öffnen Sie das Ziel, führen Sie **Verbindung testen** aus und entfernen Sie es und fügen Sie es erneut hinzu, falls sich die Zugangsdaten geändert haben. |
| Die Zugangsdaten für dieses Ziel fehlen im Schlüsselbund des Geräts. | Der Schlüsselbund-Eintrag ging verloren, zum Beispiel nach einer Wiederherstellung auf einem neuen Telefon. | Entfernen Sie das Ziel und fügen Sie es erneut hinzu. |

Siehe auch die Einstellung [Upload-Ziele](settings.md#upload-ziele) sowie die Anleitungen zur [Session-Bibliothek](session-library.md) und zur [Session-Übersicht](session-review.md).
