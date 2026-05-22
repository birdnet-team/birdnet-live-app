# Informativa sulla Privacy

**Ultimo aggiornamento:** Maggio 2026

BirdNET Live rispetta la tua privacy. Nessun dato audio o identificazione animale viene trasmesso online; tutta l'attività neurale (**BirdNET+ Audio e Geo-model**) avviene **localmente** sul tuo dispositivo.

## Raccolta Dati
La nostra applicazione non include telemetria, tracker o database in cloud.
- Audio, metadati di sessione JSON, GPS e preferenze vengono salvati nella memoria del dispositivo.
- Quando **Consenti ricerca meteo** è attivo, ogni sessione salva localmente uno snapshot di temperatura, precipitazioni, vento, nuvolosità e codice meteo alle coordinate della sessione.

## Servizi di Terze Parti

L'app può contattare i seguenti servizi esterni. Ciascuno è controllato da un interruttore indipendente in **Impostazioni → Privacy**, e **tutti e tre sono disattivati per impostazione predefinita** su una nuova installazione. Nulla esce dal dispositivo finché non lo autorizzi.

| Risorsa | Scopo | Interruttore | Inviato per ogni richiesta |
|---------|-------|--------------|----------------------------|
| Tile della mappa (OpenStreetMap) | Mappa di base per selettore di posizione, mappa live di Survey e mappa della sessione | **Impostazioni → Privacy → Consenti tile della mappa** | Coordinate del tile `(z, x, y)` e user-agent BirdNET Live — nessun PII |
| Geocoding inverso (OpenStreetMap Nominatim) | Risolvere coordinate GPS in un nome di luogo (es. “Roma, Italia”) | **Impostazioni → Privacy → Consenti ricerca nome luogo** | Lat/lon della sessione e user-agent BirdNET Live |
| Snapshot meteo (Open-Meteo) | Cattura una tantum delle condizioni (temperatura, precipitazioni, vento, nuvolosità, codice WMO) alle coordinate e all'orario di fine | **Impostazioni → Privacy → Consenti ricerca meteo** | Lat/lon della sessione e timestamp di fine, più user-agent BirdNET Live |

Le richieste di tile sono HTTPS GET standard verso `tile.openstreetmap.org`; il geocoding inverso va a `nominatim.openstreetmap.org` secondo la [Nominatim Usage Policy](https://operations.osmfoundation.org/policies/nominatim/); le richieste meteo vanno a `api.open-meteo.com`. [Open-Meteo](https://open-meteo.com/) è un servizio gratuito e non richiede né account né chiave API.

**Conservazione:** nessuno dei servizi sopra elencati conserva i tuoi dati. I valori restituiti (nome del luogo, snapshot meteo) vivono solo nel record locale della sessione e viaggiano solo nei file di esportazione che produci esplicitamente.

**Revoca:** puoi disattivare ciascuno dei tre servizi in qualsiasi momento da **Impostazioni → Privacy**. Per cancellare anche i nomi di luogo e gli snapshot meteo già salvati, elimina le sessioni interessate in Session Library oppure usa **Impostazioni → Zona pericolosa → Cancella tutti i dati**.

## Gestione ed Esportazione
Puoi eliminare singole sessioni da Session Library. Per cancellare dall'app sessioni locali, registrazioni, note vocali, liste specie personalizzate, preferenze e cache di BirdNET Live, usa **Impostazioni → Zona pericolosa → Cancella tutti i dati**. Puoi anche eliminare lo spazio di archiviazione di BirdNET Live nelle impostazioni di sistema o disinstallare l'app. Sotto **Impostazioni → Esporta → Formati** puoi spuntare qualsiasi combinazione di formati (Raven Selection Table, CSV, JSON, GPX); i formati selezionati vengono raggruppati in un unico ZIP insieme alle clip audio e al report HTML opzionale. Niente viene inviato in server cloud esterni.

## Contatti
[ccb-birdnet@cornell.edu](mailto:ccb-birdnet@cornell.edu)
