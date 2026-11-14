# Symbole und Steuerelemente

Auf dieser Seite werden die wiederkehrenden Steuerelemente und Symbole erläutert, die in BirdNET Live verwendet werden. Die folgenden Beschriftungen entsprechen exakt den Steuerelementen, wie sie in der App erscheinen.

## Modussymbole

Diese Symbole haben dieselben Formen wie in der App. Hier übernehmen sie die Textfarbe; App-Farben hängen von Design, dynamischen Farben und hohem Kontrast ab.

- :app-micRounded: **Live**
- :app-locationOnRounded: **Point Count**
- :app-routeRounded: **Survey**
- :app-timerRounded: **ARU-Modus**
- :app-audioFileRounded: **Dateianalyse**
- :app-sdStorage: **Batch-Analyse** (Demnächst)

## Gemeinsame Navigationssteuerelemente

| Steuerelement | Wo Sie es sehen | Was es tut |
|---|---|---|
| :app-tuneRounded: **Einstellungen** | Start-Fußzeile, Live, Point Count, Survey, Dateianalyse, Session-Übersicht | Öffnet die Einstellungen. In den Modus-Bildschirmen werden die für den jeweiligen Arbeitsablauf relevantesten Einstellungen geöffnet. |
| :app-searchRounded: **Erkunden** | Start-Fußzeile | Öffnet Erkunden. |
| :app-libraryMusic: **Bibliothek** | Start-Fußzeile | Öffnet die Session-Bibliothek. |
| :app-helpOutlineRounded: **Hilfe** | Start-Fußzeile, Erkunden-Kopfzeile, Survey-Dashboard, Symbolleiste der Session-Übersicht | Öffnet die Hilfe oder ein bildschirmspezifisches Hilfeblatt. |
| :app-infoOutline: **Info / Über** | Start-Fußzeile, Infoleisten, Hilfeblätter | Zeigt allgemeine Informationen oder zusammenfassenden Kontext an. |
| :app-arrowBackRounded: **Zurück** | Live Mode | Kehrt zum vorherigen Bildschirm zurück. |
| :app-openInNew: **Extern öffnen** | Über-Bildschirm, Dokumentationslinks | Öffnet eine externe Seite, etwa das Online-Benutzerhandbuch. |
| :app-arrowUpwardRounded: **Nach oben** | Hilfebildschirm | Kehrt zur Einführung und den Abschnittsverknüpfungen zurück. Erscheint nach dem Herunterscrollen. |
| :app-volunteerActivism: **Spenden** | Über-Bildschirm | Öffnet die BirdNET-Spendenseite. |

## Wettersymbole

| Symbol | Bedeutung |
|---|---|
| :app-wbSunny: **Klar** | Klarer Himmel. |
| :app-partlyCloudyDay: **Teilweise bewölkt** | Sonne und Wolke für überwiegend klares oder teilweise bewölktes Wetter. |
| :app-cloudy: **Bedeckt** | Vollständige Bewölkung. |
| :app-foggy: **Nebel** | Nebel oder gefrierender Nebel. |
| :app-rainyLight: **Nieselregen** | Leichter Niederschlag. |
| :app-rainy: **Regen** | Regen oder Regenschauer. |
| :app-weatherSnowy: **Schnee** | Schnee oder Schneeschauer. |
| :app-thunderstorm: **Gewitter** | Gewitterbedingungen. |

## Start-, Stopp- und Session-Steuerung

| Steuerelement | Bedeutung |
|---|---|
| :app-micRounded: **Mikrofon** | Zuhören starten. |
| :app-stopRounded: **Stopp** | Eine laufende Aufnahme, einen Point Count oder einen Survey beenden. |
| :app-playArrowRounded: **Play** | Nach abgeschlossener Einrichtung starten oder eine pausierte Session fortsetzen. |
| :app-close: **Schließen** / :app-stop: **Abbrechen** | Eine laufende Dateianalyse über die Kopfzeile oder die Fortschrittsanzeige abbrechen. |
| :app-timerOutlined: **Timer** | Dauer oder verbleibende Zeit. |
| :app-errorOutline: **Fehler** | Modell- oder Verarbeitungsfehler. |

## Orts- und Zeitsteuerung

| Steuerelement | Bedeutung |
|---|---|
| :app-myLocation: **Aktueller Standort** | Die aktuelle GPS-Position des Geräts verwenden. |
| :app-editLocationAlt: **Manuelle Koordinaten** | Koordinaten manuell eingeben. |
| :app-locationOff: **Kein Standort** | Standort überspringen oder anzeigen, dass kein Standort verfügbar ist. |
| :app-locationOn: **Standort vorhanden** | Einen Standort bestätigen, Koordinaten anzeigen oder eine kartierte Session kennzeichnen. |
| :app-refresh: **Aktualisieren** | Den aktuellen Standort erneut auslesen oder eine Vorhersageliste aktualisieren. |
| :app-mapSheet: **Kartenauswahl** | Koordinaten aus der Kartenauswahl auswählen. |
| :app-calendarToday: **Datum** | Ein Datum festlegen oder anzeigen. |
| :app-clear: **Löschen** | Ein ausgewähltes Datum entfernen. |

## Erkunden- und Artensymbole

| Steuerelement | Bedeutung |
|---|---|
| Arten-Miniaturansicht | Mitgeliefertes Bild der Art, sofern verfügbar. |
| Prozent-Badge für Konfidenz oder Geo-Modell | Eine kurze numerische Zusammenfassung der Modellausgabe. Höhere Zahlen weisen auf eine stärkere Stützung im Kontext des jeweiligen Bildschirms hin. |
| Monatsbeschriftungen (`Jan`, `Apr`, `Jul`, `Okt`, `Dez`) | Referenzpunkte im wöchentlichen Diagramm der erwarteten Häufigkeit in der Detailansicht zur Art. |

## Aktionen je Detektion

Diese Steuerelemente erscheinen in jeder Detektionszeile der App – in der Artenliste der Session-Übersicht, im Clip-Player-Blatt, in der Detektionsliste des laufenden Surveys und an den Survey-Kartenmarkierungen. Das vollständige Verhalten finden Sie unter [Session-Übersicht → Aktionen je Detektion](session-review.md#aktionen-je-detektion).

| Steuerelement | Bedeutung |
|---|---|
| :app-checkCircleOutline: **Bestätigen** | Ein-Tipp-Häkchen, das eine Detektion als visuell oder akustisch überprüft markiert. Bestätigte Detektionen erhalten ein kleines grünes Häkchen an Cluster-Zeilen und Kartenmarkierungen. |
| :app-moreVert: **Mehr** | Öffnet das Überlaufmenü je Detektion mit **Detektion teilen**, **Art ersetzen**, **Detektion löschen** und **Art löschen**. |
| :app-share: **Detektion teilen** | Teilt eine einzelne Detektion über das Teilen-Menü der Plattform und hängt nach Möglichkeit den Audioclip an – einschließlich eines Ausschnitts der laufenden Aufnahme während eines laufenden Surveys. |
| :app-swapHoriz: **Art ersetzen** | Eine andere Art für diese Detektion auswählen. Lässt sich auch durch Wischen einer Übersichtszeile nach links öffnen. |
| :app-deleteOutline: **Detektion löschen** | Entfernt die Zeile sofort. Für einige Sekunden erscheint eine SnackBar zum Rückgängigmachen. Lässt sich auch durch Wischen einer Übersichtszeile nach rechts auslösen. |
| :app-deleteSweep: **Art löschen** | Entfernt jede Detektion dieser Art in einem Schritt aus der Session, mit derselben SnackBar zum Rückgängigmachen. |
| :app-hearing: **Gehört** | Bei einer manuell hinzugefügten Detektion: Sie haben den Vogel gehört. Wird über das Kontrollkästchen im Bestätigungsfenster nach der Artenauswahl gesetzt. |
| :app-visibility: **Gesehen** | Bei einer manuell hinzugefügten Detektion: Sie haben den Vogel gesehen. Beide Symbole zusammen bedeuten gehört *und* gesehen. |

## Session-Übersicht-Symbolleiste

Diese Steuerelemente werden auf dem Bildschirm der Session-Übersicht verwendet.

| Steuerelement | Bedeutung |
|---|---|
| :app-addCircleOutline: **Hinzufügen** | Inhalte hinzufügen, etwa eine Art oder eine Anmerkung. |
| :app-undo: **Rückgängig** / :app-redo: **Wiederholen** | Durch die Bearbeitungsschritte der Übersicht zurück- oder vorgehen. |
| :app-contentCut: **Zuschneiden** | In den Zuschneide-Modus wechseln oder anzeigen, dass der Zuschneide-Modus aktiv ist. |
| :app-save: **Speichern** | Änderungen der Übersicht speichern. |
| :app-share: **Teilen** | Die Session exportieren oder teilen. |
| :app-deleteOutline: **Löschen** | Die Session verwerfen. |
| :app-playArrowRounded: **Fortsetzen** | Einen nicht abgeschlossenen Survey aus der Session-Übersicht fortsetzen, sofern diese Aktion verfügbar ist. |

## Bildschirmspezifische Statusleisten

### Live Mode

Die Live-Infoleiste verwendet :app-infoOutline: gefolgt von kompakten Beschriftungen wie:

- `aktuell` – derzeit in der Live-Liste sichtbare Detektionen
- `Arten` – Artenzahl
- `Det.` – Gesamtzahl der Detektionen
- Dauer und geschätzte Aufnahmegröße, wenn die Aufnahme aktiv ist

### Point Count

Die Point-Count-Timerleiste kombiniert :app-stopRounded: **Stopp**, :app-timerOutlined: **Timer** und einen Fortschrittsbalken, um die verbleibende zeitgesteuerte Session anzuzeigen.

### Survey

Das Survey-Dashboard verwendet:

- :app-map: **Karte** – Tab „Live-Karte“
- :app-graphicEq: **Spektrogramm** – Spektrogramm-Tab
- :app-summaryChart: **Übersicht** – Tab „Übersicht“
- :app-summaryChart: Statistikbeschriftungen im Tab „Übersicht“ des Surveys

## Im Zweifelsfall

Wenn Sie nicht sicher sind, was ein Steuerelement bewirkt, öffnen Sie das nächstgelegene Hilfeblatt in der App oder sehen Sie sich die Workflow-Seite für diesen Bildschirm in diesem Benutzerhandbuch an.
