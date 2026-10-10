# ARU-Modus

!!! note "Frühe Implementierung"
    Der ARU-Modus speichert derzeit Zwischenstände geplanter ARU-Aufstellungen, zeichnet geplante Zyklen auf, führt Live-Inferenz während aktiver Zyklen aus, speichert aufbewahrte Detektionsclips, wenn dieser Aufnahmemodus gewählt ist, und zeigt unter Android Vordergrundbenachrichtigungen. Das iOS-Hintergrundverhalten muss noch im Feld validiert werden.

Der ARU-Modus (Autonomous Recording Unit) ist der feste Standort-Workflow für geplante akustische Aufstellungen.

## Aktueller Setup-Ablauf

- **Details und Analyseeinstellungen**:
    - **Metadaten**: Geben Sie einen Aufstellungsnamen, eine ARU-/Stations-ID und den Namen der beobachtenden Person ein.
    - **Standort**: Geben Sie die Standortkoordinaten über eine automatische GPS-Erfassung, eine manuelle Eingabe von Breitengrad/Längengrad ein oder überspringen Sie die Standorteinrichtung. Breitengrad und Längengrad sind erforderlich, wenn Sie eine sonnenbezogene Zeitplanung verwenden. Symbole: GPS :app-myLocation:, manuelle Koordinaten :app-editLocationAlt:, Standort überspringen :app-locationOff: und Kartenauswahl :app-mapSheet:.
    - **Analyse**: Wählen Sie Mikrofon, Inferenzrate, Konfidenzschwelle und Empfindlichkeit.
    - **Aufnahmeformat**: Wählen Sie zwischen den Formaten FLAC (komprimiert verlustfrei) und WAV (unkomprimiert).
    - **Aufnahmemodus**:
        - *Vollständig*: Zeichnet die gesamte Dauer jedes aktiven Zyklus auf.
        - *Nur Detektionen*: Speichert kurze Audio-Clips um erkannte Vogelstimmen herum. Sie können den Clip-Kontext anpassen (Hinzufügen von 0 bis 5 Sekunden Puffer vor und nach der Erkennung) und die Erfassungsmethode wählen (*Alle*, *Top N* oder *Smart*, um den Speicherplatzbedarf zu begrenzen).
        - *Aus*: Führt Live-Inferenz während der Zyklen aus und protokolliert Erkennungen, speichert jedoch keine Audiodateien.
- **Zeitplan**:
    - **Dauer und Wiederholung**: Wählen Sie aus, wie lange jeder aktive Aufnahmezyklus dauert und wie oft er sich wiederholt.
    - **Aufnahmefenster (Diel-Muster)**: Wählen Sie, ob Sie rund um die Uhr aufnehmen möchten (*Jederzeit*) oder schränken Sie die Zyklen auf *Nur Tag*, *Nur Nacht* oder spezifische Zeitfenster *Um den Sonnenaufgang*, *Um den Sonnenuntergang* oder *Um Sonnenaufgang und Sonnenuntergang* ein. Die Sonnenaufgangs- und Sonnenuntergangsfenster werden dynamisch basierend auf den Koordinaten der Aufstellung berechnet.
    - **Ende des Zeitplans**: Wählen Sie, ob Sie die Aufstellung manuell beenden, nach einer festen Anzahl abgeschlossener Zyklen stoppen oder automatisch zu einem bestimmten Datum und einer bestimmten Uhrzeit stoppen möchten.
    - **Akkumanagement**: Legen Sie einen Schwellenwert für den Stopp bei niedrigem Akkustand (0-50%) fest, um die Aufstellung zu pausieren und eine vollständige Entladung des Akkus zu verhindern. Falls konfiguriert, können Sie einen Schwellenwert für die Wiederaufnahme bei niedrigem Akkustand festlegen, um Aufnahmezyklen automatisch fortzusetzen, wenn sich der Akkustand wieder erholt (z. B. durch Solarladung).
    - **Testlauf**: Ein optionaler einminütiger Testzyklus ist standardmäßig aktiviert, um die Mikrofoneingabe und Inferenz sofort nach dem Start zu überprüfen, ohne auf das geplante Zykluslimit angerechnet zu werden.
    - **Session-Gruppierung**: Konfigurieren Sie, ob jeder Zyklus als separate Session gespeichert werden soll (empfohlen für schnellere Ladezeiten und modulare Betrachtung) oder ob alle Zyklen in einer einzigen, mehrteiligen Session zusammengefasst werden sollen.
- **Bereit**: Überprüfen Sie den Zeitplan, den geschätzten Audiospeicherverbrauch und die Diel-Einschränkungen und starten Sie dann die Aufstellung.

Die Einrichtungselemente verwenden dieselben Symbole wie die anderen Assistenten: :app-micRounded: Mikrofon, :app-speedRounded: Inferenzrate, :app-verifiedRounded: Konfidenz, :app-hearing: Empfindlichkeit, :app-fiberManualRecordRounded: Aufnahmemodus, :app-timerOutlined: Clip-Kontext und Zyklusdauer, :app-filterAltRounded: Detektions-Sampling und :app-formatListNumberedRounded: Clip-Limit pro Art. Das Wiederholungsintervall verwendet :app-repeatRounded:, die Akku-Schwellen :app-batteryAlert: und :app-batteryChargingFull:, Testlauf und Session-Gruppierung :app-scienceRounded: und :app-libraryBooks:. Tippen Sie auf die Schaltfläche :app-helpOutline: neben einem Element, um eine Erklärung zu erhalten.

Beim Start wird sofort eine `SessionType.aru`-Session mit ARU-Zeitplanmetadaten gespeichert. Aufnahmezyklen werden außerdem alle 30 Sekunden gesichert, auch Zyklen ohne Detektionen. Nach einem Absturz oder Stromausfall erscheint die zuletzt gesicherte Aufstellung als beendete Session in der Session-Bibliothek; die Aufnahme wird nicht neu gestartet. Was seit der letzten Sicherung aufgenommen wurde, kann verloren gehen.

JSON- und ZIP-Exporte enthalten ARU-Aufstellungsmetadaten. ZIP-Exporte bündeln gespeicherte Aufnahmedateien pro Zyklus unter `aru_cycles/`.

## Aktive Aufstellung

Der aktive ARU-Bildschirm zeigt, ob die Aufstellung wartet, aufnimmt oder abgeschlossen ist. Das Layout verwendet vier Tabs:
- **Status**: Zeigt den aktuellen Aufstellungsstatus, den aktiven Zeitplan-Timer und eine Liste der Echtzeit-Detektionen.
- **Audio**: Zeigt ein live scrollendes Spektrogramm an, um den Audioeingang zu überprüfen, während die Detektionen unten sichtbar bleiben.
- **Plan**: Listet die nächsten 10 geplanten Zykluszeiten auf und zeigt die Ausrichtung an Sonnenaufgang/Sonnenuntergang an, wenn Diel-Einschränkungen aktiv sind.
- **Übersicht**: Fasst die verstrichene Zeit, die gesamte aufgezeichnete Audiodauer und die Detektionsstatistiken zusammen.

Unter Android zeigen aktive Aufstellungen eine Vordergrundbenachrichtigung mit Stopp- und Öffnen-Aktionen.

Beim Stoppen einer Aufstellung wird die Session-Übersicht geöffnet. Wenn Zyklen in einer Session gruppiert sind, wird diese kombinierte Session geöffnet. Wenn jeder Zyklus als eigene Session gespeichert wird, öffnet das Stoppen die neueste Zyklus-Session.

Unter iOS sollte diese frühe Implementierung als Vordergrund-Workflow behandelt werden, bis geplantes Audio- und Hintergrundverhalten auf iOS validiert wurde.

## Noch geplant

- Validierung des iOS-Hintergrundverhaltens.
- Vollständige Wiedergabe und Spektrogramm-Unterstützung in der Session-Übersicht für segmentierte ARU-Aufnahmen aus mehreren Dateien.
