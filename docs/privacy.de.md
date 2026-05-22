# Datenschutzerklärung

**Zuletzt aktualisiert:** Mai 2026

BirdNET Live respektiert Ihre Privatsphäre. Dieses Dokument erklärt, wie die App mit Ihren Daten umgeht.

## Lokale Verarbeitung auf dem Gerät

Die gesamte Audioanalyse und Vogelartenbestimmung findet **vollständig auf Ihrem Gerät** statt. Die App verwendet zwei neuronale Netzwerkmodelle, die lokal ausgeführt werden:

- **BirdNET+ Audio-Klassifikator** — analysiert das Mikrofon-Audio, um Vogelarten zu identifizieren.
- **BirdNET Geo-Modell** — sagt vorher, welche Arten an Ihrem Standort und zu dieser Jahreszeit wahrscheinlich sind.

Es werden niemals Audiodaten an externe Server übertragen.

## Datenerfassung

BirdNET Live sammelt, überträgt oder teilt **keine** personenbezogenen Daten. Es gibt keine Analysen, kein Tracking und keine Telemetrie.

### Lokal auf Ihrem Gerät gespeicherte Daten:

| Datentyp | Zweck | Speicherort |
|-----------|---------|---------|
| Audioaufnahmen | Vogelbestimmung, Wiedergabe, Export | Lokale Dateien |
| Detektionsergebnisse | Arten, Konfidenz, Zeitstempel | Lokale JSON-Sitzungsdateien |
| GPS-Koordinaten | Geotagging von Detektionen, Survey-Tracks, Geo-Modell-Vorhersagen | Lokale JSON-Sitzungsdateien |
| Sitzungs-Metadaten | Sitzungsverlauf, Überprüfung, Export | Lokale JSON-Sitzungsdateien |
| Wetter-Snapshot (optional) | Einmalige Aufnahme von Temperatur, Niederschlag, Wind, Bewölkung und Wettercode pro Sitzung, wenn **Wetterabfrage erlauben** aktiv ist | Lokale JSON-Sitzungsdateien |
| App-Einstellungen | Benutzereinstellungen | SharedPreferences |

### Gebündelte Offline-Daten

Artenbilder, Beschreibungen und Taxonomie-Daten sind **in die App integriert** und werden aus lokalen Assets geladen. Es werden keine Netzwerkanfragen für Arteninformationen gestellt.

## Externe Ressourcen

Die App kann auf die folgenden externen Ressourcen zugreifen. Jede Ressource ist durch einen unabhängigen Schalter unter **Einstellungen → Datenschutz** gegated, und **alle drei sind bei einer Neuinstallation standardmäßig deaktiviert**. Nichts verlässt Ihr Gerät, bevor Sie zustimmen.

| Ressource | Zweck | Schalter | Pro Anfrage gesendet |
|----------|-------|----------|----------------------|
| Kartenkacheln (OpenStreetMap) | Basiskarte für Standortauswahl, Survey-Live-Karte und Sitzungskarte | **Einstellungen → Datenschutz → Kartenkacheln erlauben** | Kachelkoordinaten `(z, x, y)` und BirdNET-Live-User-Agent — keine PII |
| Reverse Geocoding (OpenStreetMap Nominatim) | Auflösung von GPS-Koordinaten in einen lesbaren Ortsnamen (z. B. „Berlin, Deutschland“) | **Einstellungen → Datenschutz → Ortsnamen-Suche erlauben** | Lat/Lon der Sitzung plus BirdNET-Live-User-Agent |
| Wetter-Snapshot (Open-Meteo) | Einmalige Aufnahme der lokalen Bedingungen (Temperatur, Niederschlag, Wind, Bewölkung, WMO-Wettercode) an Aufnahmekoordinaten und Endzeit | **Einstellungen → Datenschutz → Wetterabfrage erlauben** | Lat/Lon der Sitzung und Endzeitstempel plus BirdNET-Live-User-Agent |

Kartenkachel-Anfragen sind standardmäßige HTTPS-GET-Anfragen an `tile.openstreetmap.org`. Es werden nur Kachelkoordinaten gesendet — keine personenbezogenen Daten.

Reverse-Geocoding-Anfragen senden Breiten- und Längengrad der Sitzung über HTTPS an `nominatim.openstreetmap.org`, zusammen mit dem BirdNET-Live-User-Agent gemäß den [Nominatim-Nutzungsbedingungen](https://operations.osmfoundation.org/policies/nominatim/). Der ermittelte Ortsname wird lokal mit der Sitzung gespeichert, sodass eine Sitzung nur einmal geokodiert wird. Es erfolgt keine Anfrage, wenn die Sitzung keine GPS-Koordinaten enthält oder das Gerät offline ist.

Wetteranfragen senden Lat/Lon der Sitzung und den Endzeitstempel über HTTPS an `api.open-meteo.com`, zusammen mit dem BirdNET-Live-User-Agent. [Open-Meteo](https://open-meteo.com/) ist ein kostenloser Dienst und benötigt weder Konto noch API-Schlüssel. Der zurückgegebene Wetter-Snapshot wird lokal mit der Sitzung gespeichert und in den JSON-Export, den `metadata.json`-Block der Sitzung sowie den HTML-Bericht geschrieben.

**Aufbewahrung:** Keiner der oben genannten Drittanbieterdienste wird kontaktiert, um Nutzerdaten *hochzuladen* oder zu *speichern*. Rückgabewerte (Ortsname, Wetter-Snapshot) liegen ausschließlich im lokalen Sitzungsdatensatz auf Ihrem Gerät und gelangen nur in Exportdateien, die Sie ausdrücklich erzeugen.

**Widerruf:** Sie können jeden der drei Dienste jederzeit unter **Einstellungen → Datenschutz** deaktivieren. Bereits lokal gespeicherte Ortsnamen und Wetter-Snapshots bleiben an den Sitzungen, in denen sie erfasst wurden. Um diese historischen Daten zu entfernen, löschen Sie die betroffenen Sitzungen in der Session Library oder verwenden Sie **Einstellungen → Gefahrenzone → Alle Daten löschen**.

**Es werden keine weiteren Netzwerkanfragen gestellt.** Die App funktioniert vollständig offline.

## GPS & Standort

Die App verwendet den GPS-Standort für:

- **Artenfilterung** — Vorhersage, welche Arten an Ihrem Standort wahrscheinlich sind.
- **Survey-Modus** — Aufzeichnung von GPS-Tracks und Geotagging von Detektionen entlang eines Transekts.
- **Point-Count-Modus** — Markierung des Beobachtungsorts.

GPS-Daten werden lokal gespeichert und nur dann in Exporte einbezogen, wenn Sie eine Sitzung ausdrücklich teilen oder exportieren. Der Standortzugriff erfordert Ihre Erlaubnis und kann jederzeit über die Systemeinstellungen widerrufen werden.

## Datenexport

Sie können Sitzungsdaten in verschiedenen Formaten exportieren (Raven Selection Tables, CSV, JSON, GPX) und unter **Einstellungen → Export → Formate** beliebig viele Formate gleichzeitig anhaken; ausgewählte Formate werden in einem einzigen ZIP zusammen mit Audioclips und dem optionalen, eigenständigen HTML-Bericht gebündelt. Exporte werden lokal generiert und über das Teilen-Menü des Systems geteilt. Die App lädt keine Exportdaten auf Server hoch.

## Datenlöschung

Einzelne Sitzungen und ihre Aufnahmen können in der Session Library gelöscht werden. Um lokale BirdNET-Live-Sessions, Aufnahmen, Sprachnotizen, eigene Artenlisten, Einstellungen und Caches direkt in der App zu löschen, verwenden Sie **Einstellungen → Gefahrenzone → Alle Daten löschen**. Alternativ können Sie den BirdNET-Live-App-Speicher in den Systemeinstellungen löschen oder die App deinstallieren.

## Kontakt

Für Fragen zum Datenschutz: [ccb-birdnet@cornell.edu](mailto:ccb-birdnet@cornell.edu)
