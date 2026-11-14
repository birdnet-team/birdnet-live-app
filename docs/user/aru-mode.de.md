# ARU-Modus

!!! note "Frühe Implementierung"
    Der ARU-Modus speichert derzeit Zwischenstände geplanter ARU-Einsätze, zeichnet geplante Zyklen auf, führt Live-Inferenz während aktiver Zyklen aus, speichert behaltene Detektionsclips, wenn dieser Aufnahmemodus gewählt ist, und zeigt unter Android Vordergrundbenachrichtigungen. Das iOS-Hintergrundverhalten muss noch im Feld validiert werden.

Der ARU-Modus (Autonomous Recording Unit) ist der Workflow für geplante akustische Einsätze an einem festen Standort.

## Aktueller Einrichtungsablauf

- **Details und Analyseeinstellungen**:
    - **Metadaten**: Geben Sie einen Projektnamen, eine ARU-/Stations-ID und den Beobachternamen ein.
    - **Standort**: Übernehmen Sie die Koordinaten automatisch per GPS, geben Sie Breiten- und Längengrad manuell ein oder überspringen Sie den Standort. Breitengrad und Längengrad sind erforderlich, wenn Sie eine sonnenbezogene Zeitplanung verwenden. Symbole: GPS :app-myLocation:, manuelle Koordinaten :app-editLocationAlt:, Standort überspringen :app-locationOff: und Kartenauswahl :app-mapSheet:.
    - **Analyse**: Wählen Sie Mikrofon, Inferenzrate, Konfidenzschwellenwert und Empfindlichkeit.
    - **Aufnahmeformat**: Wählen Sie zwischen FLAC (verlustfrei komprimiert) und WAV (unkomprimiert).
    - **Aufnahmemodus**:
        - *Vollständig*: Zeichnet die gesamte Dauer jedes aktiven Zyklus auf.
        - *Nur Detektionen*: Speichert kurze Audioclips rund um erkannte Lautäußerungen. Sie können den Clip-Kontext anpassen (0 bis 5 Sekunden Puffer vor und nach der Detektion) und die Detektionsauswahl festlegen (*Alle*, *Top N* oder *Smart*, um den Speicherplatzbedarf zu begrenzen).
        - *Aus*: Führt Live-Inferenz während der Zyklen aus und protokolliert Detektionen, speichert jedoch keine Audiodateien.
- **Zeitplan**:
    - **Dauer und Wiederholung**: Wählen Sie aus, wie lange jeder aktive Aufnahmezyklus dauert und wie oft er sich wiederholt.
    - **Aufnahmefenster (Diel-Muster)**: Nehmen Sie rund um die Uhr auf (*Durchgehend*) oder beschränken Sie die Zyklen auf *Tagsüber*, *Nachts* oder die Zeitfenster *Um Sonnenaufgang*, *Um Sonnenuntergang* oder *Um Sonnenaufgang und Sonnenuntergang*. Die Fenster um Sonnenaufgang und Sonnenuntergang werden anhand der Koordinaten des Einsatzes dynamisch berechnet.
    - **Ende des Zeitplans**: Wählen Sie, ob Sie den Einsatz manuell beenden oder ob er nach einer festen Anzahl abgeschlossener Zyklen oder zu einem bestimmten Datum und einer bestimmten Uhrzeit automatisch endet.
    - **Akkumanagement**: Legen Sie einen Akkustand (0–50 %) fest, unter dem der Einsatz pausiert, damit sich der Akku nicht vollständig entlädt. Zusätzlich können Sie einen Akkustand festlegen, ab dem die Aufnahmezyklen automatisch fortgesetzt werden, sobald sich der Akku wieder erholt hat (z. B. durch Solarladung).
    - **Testlauf**: Ein optionaler einminütiger Testzyklus ist standardmäßig aktiviert, um Mikrofoneingang und Inferenz sofort nach dem Start zu überprüfen; er wird nicht auf die geplante Anzahl der Zyklen angerechnet.
    - **Session-Gruppierung**: Legen Sie fest, ob jeder Zyklus als eigene Session gespeichert wird (empfohlen für kürzere Ladezeiten und eine Durchsicht Zyklus für Zyklus) oder ob alle Zyklen in einer gemeinsamen, mehrteiligen Session zusammengefasst werden.
- **Bereit**: Überprüfen Sie den Zeitplan, den geschätzten Audiospeicherverbrauch und die Diel-Einschränkungen und starten Sie dann den Einsatz.

Die Einrichtungselemente verwenden dieselben Symbole wie die anderen Assistenten: :app-micRounded: Mikrofon, :app-speedRounded: Inferenzrate, :app-verifiedRounded: Konfidenz, :app-hearing: Empfindlichkeit, :app-fiberManualRecordRounded: Aufnahmemodus, :app-timerOutlined: Clip-Kontext und Zyklusdauer, :app-filterAltRounded: Detektionsauswahl und :app-formatListNumberedRounded: Top N pro Art. Das Wiederholungsintervall verwendet :app-repeatRounded:, die Akku-Schwellenwerte :app-batteryAlert: und :app-batteryChargingFull:, Testlauf und Session-Gruppierung :app-scienceRounded: und :app-libraryBooks:. Tippen Sie auf die Schaltfläche :app-helpOutline: neben einem Element, um eine Erklärung zu erhalten.

Beim Start wird sofort eine `SessionType.aru`-Session mit ARU-Zeitplanmetadaten gespeichert. Aufnahmezyklen werden außerdem alle 30 Sekunden gesichert, auch Zyklen ohne Detektionen. Nach einem Absturz oder Stromausfall erscheint der zuletzt gesicherte Einsatz als beendete Session in der Session-Bibliothek; die Aufnahme wird nicht neu gestartet. Was seit der letzten Sicherung aufgenommen wurde, kann verloren gehen.

JSON- und ZIP-Exporte enthalten die Metadaten des ARU-Einsatzes. ZIP-Exporte bündeln gespeicherte Aufnahmedateien pro Zyklus unter `aru_cycles/`.

## Aktiver Einsatz

Der aktive ARU-Bildschirm zeigt, ob der Einsatz wartet, aufnimmt oder abgeschlossen ist. Das Layout verwendet vier Tabs:
- **Status**: Zeigt den aktuellen Status des Einsatzes, den aktiven Zeitplan-Timer und eine Liste der Echtzeit-Detektionen.
- **Audio**: Zeigt ein live mitlaufendes Spektrogramm an, um den Audioeingang zu überprüfen, während die Detektionen unten sichtbar bleiben.
- **Plan**: Listet die nächsten 10 geplanten Zykluszeiten auf und zeigt die Ausrichtung an Sonnenaufgang/Sonnenuntergang an, wenn Diel-Einschränkungen aktiv sind.
- **Übersicht**: Fasst die verstrichene Zeit, die gesamte aufgezeichnete Audiodauer und die Detektionsstatistiken zusammen.

Unter Android zeigen aktive Einsätze eine Vordergrundbenachrichtigung mit Stopp- und Öffnen-Aktionen.

Beim Beenden eines Einsatzes wird die Session-Übersicht geöffnet. Wenn die Zyklen in einer gemeinsamen Session zusammengefasst sind, wird diese Session geöffnet. Wenn jeder Zyklus als eigene Session gespeichert wird, öffnet sich die neueste Zyklus-Session.

Unter iOS sollte diese frühe Implementierung als Vordergrund-Workflow behandelt werden, bis geplantes Audio- und Hintergrundverhalten auf iOS validiert wurde.

## Noch geplant

- Validierung des iOS-Hintergrundverhaltens.
- Vollständige Wiedergabe und Spektrogramm-Unterstützung in der Session-Übersicht für segmentierte ARU-Aufnahmen aus mehreren Dateien.
