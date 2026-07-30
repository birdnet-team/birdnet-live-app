# Symbole und Steuerelemente

Auf dieser Seite werden die wiederkehrenden Steuerelemente und Symbole erläutert, die in BirdNET Live verwendet werden. Die folgenden Beschriftungen entsprechen exakt den Steuerelementen, wie sie in der App erscheinen.

## Gemeinsame Navigationssteuerelemente

| Steuerelement | Wo Sie es sehen | Was es tut |
|---|---|---|
| :material-tune: **Einstellungen** | Start-Fußzeile, Live, Point Count, Survey, Dateianalyse, Session-Übersicht | Öffnet die Einstellungen. In den Modus-Bildschirmen werden die für den jeweiligen Arbeitsablauf relevantesten Einstellungen geöffnet. |
| :material-magnify: **Erkunden** | Start-Fußzeile | Öffnet Erkunden. |
| :material-music-box-multiple-outline: **Bibliothek** | Start-Fußzeile | Öffnet die Session-Bibliothek. |
| :material-help-circle-outline: **Hilfe** | Start-Fußzeile, Erkunden-Kopfzeile, Survey-Dashboard, Session-Übersicht-Symbolleiste | Öffnet die Hilfe oder ein bildschirmspezifisches Hilfeblatt. |
| :material-information-outline: **Info / Über** | Start-Fußzeile, Infoleisten, Hilfeblätter | Zeigt allgemeine Informationen oder zusammenfassenden Kontext an. |
| :material-arrow-left: **Zurück** | Live-Modus | Kehrt zum vorherigen Bildschirm zurück. |
| :material-open-in-new: **Extern öffnen** | Über-Bildschirm, Dokumentationslinks | Öffnet eine externe Seite, etwa das Online-Benutzerhandbuch. |
| :material-hand-heart: **Spenden** | Über-Bildschirm | Öffnet die BirdNET-Spendenseite. |

## Wettersymbole

| Symbol | Bedeutung |
|---|---|
| :material-weather-sunny: **Klar** | Klarer Himmel. |
| :material-weather-partly-cloudy: **Teilweise bewölkt** | Sonne und Wolke für überwiegend klares oder teilweise bewölktes Wetter. |
| :material-weather-cloudy: **Bedeckt** | Vollständige Bewölkung. |
| :material-weather-fog: **Nebel** | Nebel oder gefrierender Nebel. |
| :material-weather-partly-rainy: **Nieselregen** | Leichter Niederschlag. |
| :material-weather-rainy: **Regen** | Regen oder Regenschauer. |
| :material-weather-snowy: **Schnee** | Schnee oder Schneeschauer. |
| :material-weather-lightning-rainy: **Gewitter** | Gewitterbedingungen. |

## Start-, Stopp- und Session-Steuerung

| Steuerelement | Bedeutung |
|---|---|
| :material-microphone: **Mic** | Live-Hören starten. |
| :material-stop: **Stop** | Eine aktive Aufnahme, einen Point Count oder einen Survey stoppen. |
| :material-play: **Play** | Einen konfigurierten Setup-Ablauf starten oder aus einem angehaltenen Bereitschaftszustand fortsetzen. |
| :material-close: **Schließen / Abbrechen** | Eine aktive Dateianalyse abbrechen. |
| :material-timer: **Timer** | Dauer oder verbleibende Zeit. |
| :material-alert-circle-outline: **Fehler** | Modell- oder Verarbeitungsfehler. |

## Orts- und Zeitsteuerung

| Steuerelement | Bedeutung |
|---|---|
| :material-crosshairs-gps: **Aktueller Standort** | Die aktuelle GPS-Position des Geräts verwenden. |
| :material-map-marker-plus: **Manuelle Koordinaten** | Koordinaten manuell eingeben. |
| :material-map-marker-off: **Kein Standort** | Standort überspringen oder anzeigen, dass kein Standort verfügbar ist. |
| :material-map-marker: **Standort vorhanden** | Einen Standort bestätigen, Koordinaten anzeigen oder eine kartierte Session kennzeichnen. |
| :material-refresh: **Aktualisieren** | Den aktuellen Standort erneut auslesen oder eine Vorhersageliste aktualisieren. |
| :material-map: **Kartenauswahl** | Koordinaten aus der Kartenauswahl auswählen. |
| :material-calendar: **Datum** | Ein Datum festlegen oder anzeigen. |
| :material-close: **Löschen** | Ein ausgewähltes Datum entfernen. |

## Erkunden- und Artensymbole

| Steuerelement | Bedeutung |
|---|---|
| Arten-Miniaturansicht | Mitgeliefertes Bild der Art, sofern verfügbar. |
| Prozent-Badge für Konfidenz oder Geo-Modell | Eine kurze numerische Zusammenfassung der Modellausgabe. Höhere Zahlen weisen auf eine stärkere Stützung im Kontext des jeweiligen Bildschirms hin. |
| Monatsbeschriftungen (`Jan`, `Apr`, `Jul`, `Okt`, `Dez`) | Referenzpunkte im wöchentlichen Diagramm der erwarteten Häufigkeit im Arten-Overlay. |

## Aktionen je Erkennung

Diese Steuerelemente erscheinen in jeder Erkennungszeile der App – in der Artenliste der Session-Übersicht, im Clip-Player-Blatt, in der Erkennungsliste des laufenden Survey und an den Survey-Kartenmarkierungen. Das vollständige Verhalten finden Sie unter [Session-Übersicht → Aktionen je Erkennung](session-review.md#per-detection-actions).

| Steuerelement | Bedeutung |
|---|---|
| :material-check: **Bestätigen** | Ein-Tipp-Häkchen, das eine Erkennung als visuell oder akustisch überprüft markiert. Bestätigte Erkennungen erhalten ein kleines grünes Häkchen an Cluster-Zeilen und Kartenmarkierungen. |
| :material-dots-vertical: **Mehr** | Öffnet das Überlaufmenü je Erkennung mit **Erkennung teilen**, **Art ersetzen**, **Erkennung löschen** und **Art löschen**. |
| :material-share-variant: **Erkennung teilen** | Teilt eine einzelne Erkennung über das Teilen-Menü der Plattform und hängt nach Möglichkeit den Audioclip an – einschließlich eines Ausschnitts der laufenden Aufnahme während eines Live-Survey. |
| :material-swap-horizontal: **Art ersetzen** | Eine andere Art für diese Erkennung auswählen. Lässt sich auch durch Wischen einer Übersichtszeile nach links öffnen. |
| :material-delete-outline: **Erkennung löschen** | Entfernt die Zeile sofort. Für einige Sekunden erscheint eine SnackBar zum Rückgängigmachen. Lässt sich auch durch Wischen einer Übersichtszeile nach rechts auslösen. |
| :material-delete-sweep-outline: **Art löschen** | Entfernt jede Erkennung dieser Art in einem Schritt aus der Session, mit derselben SnackBar zum Rückgängigmachen. |
| :material-ear-hearing: **Gehört** | Bei einer manuell hinzugefügten Detektion: Sie haben den Vogel gehört. Wird über das Kontrollkästchen im Bestätigungsfenster nach der Artenauswahl gesetzt. |
| :material-eye: **Gesehen** | Bei einer manuell hinzugefügten Detektion: Sie haben den Vogel gesehen. Beide Symbole zusammen bedeuten gehört *und* gesehen. |

## Session-Übersicht-Symbolleiste

Diese Steuerelemente werden auf dem Bildschirm der Session-Übersicht verwendet.

| Steuerelement | Bedeutung |
|---|---|
| :material-plus-circle-outline: **Hinzufügen** | Inhalte hinzufügen, etwa eine Art oder eine Anmerkung. |
| :material-undo-variant: **Rückgängig** / :material-redo-variant: **Wiederherstellen** | Durch die Bearbeitungsschritte der Übersicht zurück- oder vorgehen. |
| :material-content-cut: **Trimmen** | In den Trimm-Modus wechseln oder anzeigen, dass der Trimm-Modus aktiv ist. |
| :material-content-save: **Speichern** | Änderungen der Übersicht speichern. |
| :material-share-variant: **Teilen** | Die Session exportieren oder teilen. |
| :material-delete-outline: **Löschen** | Die Session verwerfen. |
| :material-play: **Fortsetzen** | Einen nicht abgeschlossenen Survey aus der Session-Übersicht fortsetzen, sofern diese Aktion verfügbar ist. |

## Bildschirmspezifische Statusleisten

### Live-Modus

Die Live-Infoleiste verwendet :material-information-outline: gefolgt von kompakten Beschriftungen wie:

- `now` – derzeit in der Live-Liste sichtbare Erkennungen
- `spp` – Anzahl der eindeutigen Arten
- `det` – Gesamtzahl der Erkennungen
- Dauer und geschätzte Aufnahmegröße, wenn die Aufnahme aktiv ist

### Point Count

Die Point-Count-Timerleiste kombiniert :material-stop: **Stop**, :material-timer: **Timer** und einen Fortschrittsbalken, um die verbleibende zeitgesteuerte Session anzuzeigen.

### Survey

Das Survey-Dashboard verwendet:

- :material-map-outline: **Karte** – Tab „Live-Karte“
- :material-equalizer: **Spektrogramm** – Spektrogramm-Tab
- :material-chart-bar: **Zusammenfassung** – Zusammenfassungs-Tab
- :material-chart-bar: Statistikbeschriftungen in der Zusammenfassungsansicht des Survey

## Im Zweifelsfall

Wenn Sie nicht sicher sind, was ein Steuerelement bewirkt, öffnen Sie das nächstgelegene Hilfeblatt in der App oder sehen Sie sich die Workflow-Seite für diesen Bildschirm in diesem Benutzerhandbuch an.
