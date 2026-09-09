# Informativa sulla Privacy di BirdNET Live

**Ultimo aggiornamento:** 6 agosto 2026

Questa Informativa sulla Privacy si applica a **BirdNET Live** (l'**app**). L'app è sviluppata e offerta da **BirdNET-Team** (lo **sviluppatore**, **noi** o **nostro**).

## Identità dell'app e dello sviluppatore

| | |
|---|---|
| **Nome dell'app** | BirdNET Live |
| **Nome dello sviluppatore** | BirdNET-Team |
| **Contatto privacy** | [ccb-birdnet@cornell.edu](mailto:ccb-birdnet@cornell.edu) |

BirdNET-Team fornisce questa informativa a proprio nome. Essa spiega come BirdNET Live protegge e tratta le informazioni personali.

## Elaborazione sul Dispositivo

Tutta l'analisi audio e l'identificazione delle specie di uccelli avvengono **interamente sul tuo dispositivo**. L'app utilizza due modelli di reti neurali eseguiti localmente:

- **Classificatore audio BirdNET+** — analizza l'audio del microfono per identificare le specie di uccelli.
- **Geo-model BirdNET** — prevede quali specie sono probabili nella tua posizione e nel periodo dell'anno.

Nessun dato audio viene mai trasmesso a server esterni.

## Trattamento delle informazioni personali

BirdNET-Team non gestisce un backend dell'app e non riceve tramite BirdNET Live registrazioni, posizione, dati delle Session o altre informazioni personali. L'app non include account utente, pubblicità, analisi, tracciamento o telemetria. Elabora tuttavia audio e posizione sul dispositivo e, solo quando attivi una funzione di rete facoltativa, invia le informazioni descritte in **Servizi di Terze Parti** direttamente al fornitore indicato.

### Dati archiviati localmente sul tuo dispositivo:

| Tipo di dato | Scopo | Archiviazione |
|--------------|-------|---------------|
| Registrazioni audio | Identificazione degli uccelli, riproduzione, esportazione | File locali |
| Risultati di rilevamento | Specie, confidenza, timestamp | File JSON di sessione locali |
| Coordinate GPS | Geotagging dei rilevamenti, tracce Survey, previsioni del geo-model | File JSON di sessione locali |
| Metadati di sessione | Cronologia sessioni, revisione, esportazione | File JSON di sessione locali |
| Snapshot meteo (opzionale) | Cattura una tantum di temperatura, precipitazioni, vento, nuvolosità e codice meteo per sessione quando **Consenti ricerca meteo** è attivo | File JSON di sessione locali |
| Impostazioni dell'app | Preferenze utente | SharedPreferences |

### Dati offline integrati

Immagini, descrizioni e dati tassonomici delle specie sono **integrati nell'app** e caricati da risorse locali. Non viene effettuata alcuna richiesta di rete per le informazioni sulle specie.

## Servizi di Terze Parti

L'app può accedere alle seguenti risorse esterne. Ciascuna è controllata da un interruttore indipendente in **Impostazioni → Privacy**, e **tutti e tre sono disattivati per impostazione predefinita** su una nuova installazione. Nulla esce dal tuo dispositivo finché non lo autorizzi.

| Risorsa | Scopo | Controllato da | Inviato per ogni richiesta |
|---------|-------|----------------|----------------------------|
| Tile della mappa (OpenStreetMap Foundation) | Mappa di base per selettore di posizione, mappa live di Survey e mappa della Session | **Impostazioni → Privacy → Consenti tile della mappa** | Coordinate del tile `(z, x, y)`, il tuo indirizzo IP come parte della connessione di rete e lo user-agent BirdNET Live |
| Geocoding inverso (Nominatim di OpenStreetMap Foundation) | Risolvere coordinate GPS in un nome di luogo leggibile (es. “Roma, Italia”) per la visualizzazione della Session | **Impostazioni → Privacy → Consenti ricerca nome luogo** | Latitudine/longitudine della Session, il tuo indirizzo IP come parte della connessione di rete e lo user-agent BirdNET Live |
| Snapshot meteo (OpenMeteo GmbH) | Cattura una tantum delle condizioni locali (temperatura, precipitazioni, vento, nuvolosità, codice WMO) alle coordinate di registrazione e all'orario di fine | **Impostazioni → Privacy → Consenti ricerca meteo** | Latitudine/longitudine e ora di fine della Session, il tuo indirizzo IP come parte della connessione di rete e lo user-agent BirdNET Live |

Le richieste dei tile sono richieste HTTPS GET a `tile.openstreetmap.org`. Le coordinate identificano l'area della mappa visualizzata. Come ogni richiesta Internet diretta, espongono anche il tuo indirizzo IP al fornitore.

Le richieste di geocoding inverso inviano la latitudine e la longitudine della sessione a `nominatim.openstreetmap.org` via HTTPS, insieme allo user-agent BirdNET Live come richiesto dalla [Nominatim Usage Policy](https://operations.osmfoundation.org/policies/nominatim/). Il nome di luogo risolto è archiviato localmente con la sessione, così una sessione viene geocodificata una sola volta. Nessuna richiesta viene effettuata se la sessione non ha coordinate GPS o il dispositivo è offline.

Le richieste meteo inviano la latitudine/longitudine della sessione e il timestamp di fine a `api.open-meteo.com` via HTTPS, insieme allo user-agent BirdNET Live. [Open-Meteo](https://open-meteo.com/) è un servizio gratuito e non richiede né account né chiave API. Lo snapshot meteo restituito è archiviato localmente con la sessione ed è anche scritto nell'esportazione JSON, nel blocco `metadata.json` della sessione e nel report HTML.

**Trattamento e conservazione da parte di terzi:** BirdNET-Team non gestisce questi servizi e non riceve i dati delle richieste. OpenStreetMap Foundation può trattare dati di accesso alla rete e dettagli delle richieste secondo la propria [Informativa sulla Privacy](https://osmfoundation.org/wiki/Privacy_Policy). Open-Meteo dichiara che i log della sua API gratuita possono contenere indirizzi IP e coordinate geografiche e vengono eliminati dopo 90 giorni; consulta i suoi [Termini e Privacy](https://open-meteo.com/en/terms). I fornitori possono trattare i dati in altri Paesi. I valori restituiti vengono salvati localmente nella Session e inclusi in un'esportazione solo quando la crei.

**Revoca:** puoi disattivare ciascuno dei tre servizi in qualsiasi momento da **Impostazioni → Privacy**. I nomi di luogo e gli snapshot meteo già archiviati localmente restano associati alle sessioni in cui sono stati acquisiti; elimina quelle sessioni dalla Libreria delle sessioni oppure usa **Impostazioni → Zona pericolosa → Cancella tutti i dati** per rimuovere quei dati storici.

**Nessun'altra richiesta di rete viene effettuata.** L'app funziona completamente offline.

## Collegamenti esterni

BirdNET Live include collegamenti a siti web di terze parti che puoi scegliere di aprire — per esempio le pagine **eBird**, **iNaturalist** e **Wikipedia** di una specie e il collegamento audio *«Ascolta questa specie su eBird»* nella vista della specie, oltre a collegamenti al sito del progetto BirdNET, al codice sorgente, alla guida utente e alla pagina per le donazioni nella schermata **Informazioni**. I collegamenti che escono dall'app sono contrassegnati da un'icona di collegamento esterno (↗) così da riconoscerli prima di toccarli.

Finché un collegamento è solo visualizzato non viene inviato nulla, e nessun collegamento esterno viene mai aperto automaticamente: il browser si apre solo quando lo tocchi. Il collegamento si apre allora nel browser predefinito del tuo dispositivo e lasci BirdNET Live. La destinazione è gestita da terzi ed è soggetta alla **propria** informativa sulla privacy e ai propri termini, non a questa. Tali siti possono raccogliere in modo indipendente informazioni sulla tua visita — per esempio il tuo indirizzo IP, i dettagli del dispositivo o del browser e il modo in cui interagisci con le loro pagine — e impostare i propri cookie. Non controlliamo né siamo responsabili dei contenuti o delle pratiche sui dati dei siti esterni; ti invitiamo a consultare l'informativa sulla privacy di ciascun sito.

## GPS e Posizione

L'app usa la posizione GPS per:

- **Filtro delle specie** — prevedere quali specie sono probabili nella tua posizione.
- **Modalità Survey** — registrare tracce GPS e geotaggare i rilevamenti lungo un transetto.
- **Modalità Point Count** — etichettare il luogo dell'osservazione.

I dati GPS sono archiviati localmente e inclusi nelle esportazioni solo quando condividi o esporti esplicitamente una sessione. L'accesso alla posizione richiede il tuo permesso e può essere revocato in qualsiasi momento dalle impostazioni di sistema.

## Esportazione Dati

Puoi esportare i dati di sessione in più formati (Raven Selection Tables, CSV, JSON, GPX) e spuntare qualsiasi combinazione di formati contemporaneamente sotto **Impostazioni → Esporta → Formati**; i formati selezionati vengono raggruppati in un unico ZIP insieme alle clip audio e al report HTML autonomo opzionale. Le esportazioni sono generate localmente e condivise tramite il pannello di condivisione del sistema. L'app non carica alcun dato di esportazione su server.

## Cancellazione Dati

Le singole sessioni e le loro registrazioni possono essere eliminate dalla Libreria delle sessioni. Per cancellare dall'app le sessioni locali, le registrazioni, le note vocali, le liste di specie personalizzate, le preferenze e le cache di BirdNET Live, usa **Impostazioni → Zona pericolosa → Cancella tutti i dati**. Puoi anche cancellare lo spazio di archiviazione dell'app BirdNET Live nelle impostazioni del tuo sistema operativo o disinstallare l'app.

## Contatti

Per domande sulla privacy: [ccb-birdnet@cornell.edu](mailto:ccb-birdnet@cornell.edu)
