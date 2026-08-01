# Riepilogo sessione

Il Riepilogo sessione è il punto in cui BirdNET Live trasforma le rilevazioni in un record modificabile.

## Come ci si arriva

BirdNET Live apre automaticamente il Riepilogo sessione al termine di:

- una Session Live
- un Point Count
- un Survey
- un'esecuzione di Analisi file

Puoi anche riaprire qualsiasi Session salvata dalla [Libreria Sessions](session-library.md).

## Aree principali

### Riepilogo e riproduzione

Il Riepilogo sessione combina riproduzione, navigazione nello spettrogramma ed elenco delle specie. Per le Sessions Survey può mostrare anche il contesto cartografico.

L'intestazione di riepilogo, in cima alla schermata, riporta la data, il chip della posizione (lat/lon più un eventuale nome del luogo risolto quando **Impostazioni → Privacy → Consenti ricerca nome luogo** è attivo) e — quando **Impostazioni → Privacy → Consenti ricerca meteo** era attivo al momento della registrazione — una **riga meteo** sotto la posizione che mostra le condizioni rilevate al termine della Session: una riga come *"20,1 °C · Pioggia leggera · 3,2 m/s SO"* preceduta da un'icona meteo. Tocca la riga per espandere un piccolo pannello con temperatura, vento, precipitazioni e nuvolosità, con l'attribuzione a Open-Meteo. Lo stesso snapshot viene riportato nell'esportazione JSON, nel blocco di metadati della Session e nel report HTML.

La striscia dello spettrogramma sopra il lettore è interattiva: tocca per spostarti, trascina con un dito per scorrere la timeline e **pizzica con due dita per ingrandire** una finestra temporale ristretta — utile quando vuoi esaminare i tempi di richiami sovrapposti o distinguere un trillo veloce. Allarga di nuovo le dita per tornare alla panoramica predefinita di 10 secondi. Il pulsante di riproduzione su un'intestazione di specie sceglie sempre il primo gruppo che ha effettivamente un clip registrato, quindi il pulsante è disponibile ogni volta che una qualsiasi rilevazione di quella specie è riproducibile.

### Elenco delle specie

Le specie sono raggruppate in righe espandibili. Puoi esaminare le rilevazioni per specie e spostarti nella registrazione mentre le rivedi. Le righe dei gruppi sotto una specie espansa sono rientrate, così la scheda della specie principale resta visivamente distinta dai suoi elementi.

Un campo di ricerca sopra l'elenco filtra le specie per nome comune o scientifico, così trovare un uccello specifico in una Session di 100 specie richiede pochi tasti invece di un lungo scorrimento. Il pulsante :material-sort: accanto cambia l'ordine delle specie:

- **Confidenza più alta** (predefinito) — prima le specie con la confidenza più alta su una singola rilevazione. Utile per smistare le identificazioni più certe. Quando espandi una specie in questa modalità, le rilevazioni con clip audio riproducibili appaiono prima di quelle senza clip, poi per confidenza.
- **Più rilevamenti** — prima le specie con il maggior numero di rilevazioni. Utile per individuare le specie più presenti nel coro.
- **A → Z** — in ordine alfabetico per nome comune. Prevedibile, adatto alla lingua impostata e facile da scorrere quando una Session ha molte specie.
- **Rilevate per prime** — in ordine cronologico in base alla prima rilevazione. Era il valore predefinito storico; utile per la revisione affiancata alla timeline dello spettrogramma.

L'ordinamento scelto viene mantenuto tra le Sessions.

### Aggiungere una specie a mano

Il pulsante :material-plus-circle-outline: nella barra degli strumenti apre il selettore di specie per gli uccelli che BirdNET non ha rilevato. Toccare un risultato non lo inserisce subito: prima compare un pannello di conferma con la specie scelta e due caselle:

- :material-ear-hearing: **Sentito** — hai sentito l'uccello.
- :material-eye: **Visto** — hai visto l'uccello.

Seleziona una, entrambe o nessuna, poi tocca **Aggiungi**. **Annulla** — o uno scorrimento verso il basso — ti riporta alla ricerca, quindi un tocco sbagliato non costa nulla. **Sentito** è selezionato per impostazione predefinita e la tua scelta resta valida per la specie successiva: per una serie di uccelli solo visti basta selezionare **Visto** una volta. Lasciandole entrambe vuote la voce viene salvata senza tipo di osservazione, non come "nessuno dei due".

La scelta viene memorizzata sulla rilevazione e mostrata come una piccola icona di orecchio e/o occhio accanto al badge manuale ovunque compaia quella rilevazione: intestazioni di specie, righe di cluster, lettore di clip e lista del survey dal vivo. Finisce anche negli export: una colonna `Evidence` in CSV e nelle tabelle Raven, un campo `evidence` in JSON e un'etichetta nel report HTML. Lo stesso pannello compare anche con **Sostituisci specie**, precompilato con ciò che il record già conteneva.

### Azioni per ogni rilevazione

Ovunque compaia una rilevazione — l'elenco delle specie, il pannello del lettore dei clip, l'elenco del Survey in tempo reale e i marcatori sulla mappa del Survey — si usa lo stesso insieme di azioni:

- :material-check: **Conferma** — un segno di spunta inline con un tocco che contrassegna una rilevazione come verificata visivamente o acusticamente. I gruppi e i marcatori confermati ottengono un piccolo segno verde che li fa risaltare a colpo d'occhio, e il contrassegno viene mantenuto in ogni formato di esportazione.
- :material-dots-vertical: **Altro** — apre un menu aggiuntivo con:
    - :material-share-variant: **Condividi rilevazione** — vedi *Condivisione* più sotto.
    - :material-swap-horizontal: **Sostituisci specie** — scegli una specie diversa per questa rilevazione.
    - :material-delete-outline: **Elimina rilevazione** — rimuove subito la riga. Per alcuni secondi appare una SnackBar per annullare, così gli errori sono reversibili. Nessuna finestra di conferma.
    - :material-delete-sweep-outline: **Elimina specie** — rimuove in un colpo solo tutte le rilevazioni di quella specie dalla Session, con la stessa SnackBar per annullare. Utile per eliminare una sorgente di rumore identificata male senza espandere la specie ed eliminare i gruppi uno per uno.

#### Scorciatoie con lo scorrimento sulle righe in revisione

Nell'elenco delle specie puoi agire su una rilevazione anche scorrendo la riga in orizzontale:

- scorri **a destra** → elimina (con annullamento)
- scorri **a sinistra** → apre il pannello di sostituzione della specie

I due sfondi hanno colori distinti (rosso di errore vs blu primario), così l'effetto del gesto è chiaro prima di confermare.

Scorrendo la riga di un'**intestazione di specie** (a sinistra o a destra) si eliminano tutte le rilevazioni di quella specie in una volta, con la stessa SnackBar per annullare. Utile quando smisti una Session piena di rumori identificati male.

### Condivisione di una singola rilevazione

La voce :material-share-variant: **Condividi rilevazione** apre il foglio di condivisione del sistema con un contenuto sintetico e adatto agli strumenti da campo — nome comune + scientifico, confidenza, marca temporale UTC in ISO 8601 e un URI `geo:` quando la rilevazione ha il GPS — e allega il clip audio quando disponibile. Il file condiviso si chiama `BirdNET_Live_<timestamp>_<species>.<ext>` per allinearsi allo schema di esportazione ZIP.

L'allegato audio viene determinato in questo ordine:

1. Il clip della singola rilevazione presente su disco.
2. **Per le Sessions che registrano un unico file continuo**: la finestra audio pertinente viene estratta al volo dalla registrazione. Sono supportate registrazioni continue sia WAV sia FLAC e lo spezzone viene fornito nello stesso contenitore della sorgente (WAV in → WAV out, FLAC in → FLAC out).
3. Se nessuno dei due è disponibile, la condivisione è di solo testo — posizione e marca temporale finiscono comunque nel contenuto.

### Memo vocali

Puoi allegare brevi commenti vocali ai singoli record di rilevazione:

- **Registra**: tocca il pulsante :material-dots-vertical: su un gruppo di rilevazioni e seleziona **Registra memo vocale** per aprire la finestra del memo vocale. Tocca il grande pulsante del microfono per avviare la registrazione. Una forma d'onda in tempo reale riflette la tua voce. Tocca il pulsante di arresto al termine.
- **Rivedi**: una volta registrato, puoi ascoltare il memo con il lettore integrato. Per sostituirlo, tocca il pulsante **Registra di nuovo**. Per salvarlo, tocca il pulsante **Salva**.
- **Elimina**: se una rilevazione ha già un memo vocale allegato, puoi eliminarlo dal menu aggiuntivo o dalla finestra del memo vocale.
- **Formati specifici per piattaforma**: su Android e altre piattaforme i memo vocali vengono registrati in formato AAC (`.m4a`) altamente compresso a 16 kHz. Su iOS usano automaticamente il formato WAV/PCM16 (`.wav`) per evitare problemi di compatibilità CoreAudio con le sessioni audio attive dell'app. Entrambi i formati sono pienamente supportati dal pacchetto ZIP di esportazione.
- **Esportazione**: quando esporti la Session come ZIP, i memo vocali vengono inclusi nella directory `memos/` e i loro percorsi relativi vengono registrati nei metadati JSON e CSV.

### Mappa del percorso del Survey

Le Sessions Survey mostrano una piccola mappa integrata del percorso GPS e dei marcatori delle rilevazioni. Tocca un marcatore sulla mappa integrata per mettere a fuoco una rilevazione — la mappa si centra su di essa. Tocca il pulsante :material-fullscreen: **espandi** (in alto a destra della mappa integrata) per aprire la **mappa a schermo intero**; se una rilevazione era a fuoco, la mappa a schermo intero si apre centrata e ingrandita su quella rilevazione, così non perdi il segno.

#### Codifica dei marcatori

- **La confidenza è codificata a colori** con una scala adatta ai daltonici: dalla confidenza bassa a quella alta si va dal blu-viola attraverso il verde acqua/giallo fino al rosso. La luminosità della scala cambia in modo monotono, così resta leggibile in monocromia e per chi ha un deficit della visione dei colori rosso-verde.
- **Le rilevazioni con audio** mostrano un anello colorato attorno alla foto della specie più un badge di riproduzione nell'angolo — toccale per aprire lo stesso pannello del lettore dei clip usato altrove, con conferma, condivisione, sostituzione ed eliminazione disponibili.
- **Le rilevazioni silenziose** (senza clip su disco) appaiono più piccole, sbiadite e con un anello grigio neutro, così le rilevazioni con audio risultano sempre il contenuto principale.
- **I marcatori sovrapposti nello stesso punto** vengono ordinati in profondità per importanza: evidenziato > con audio > confidenza più alta, così un marcatore silenzioso a bassa confidenza non può mai nascondere una rilevazione con audio forte.
- **Sotto lo zoom 14,5** le sagome si riducono a punti colorati dimensionati in base alla confidenza e i gruppi densi si comprimono in una bolla con il conteggio (il raggruppamento si disattiva allo zoom 15).

#### Filtraggio

La mappa a schermo intero ha un **chip di filtro** persistente ancorato in alto a destra. Toccalo per aprire il pannello dei filtri; l'etichetta del chip mostra sempre il filtro attivo (*"Tutte le specie"*, *"Con audio"*, *"≥ 80%"* o il nome di una singola specie). Filtri disponibili:

- **Tutte le rilevazioni** (predefinito).
- **Con clip audio** — solo le rilevazioni il cui clip è ancora su disco e riproducibile.
- **Aggiunte manuali** — solo le rilevazioni che hai aggiunto nel Riepilogo sessione (esclude quelle rilevate automaticamente).

Puoi anche limitare le rilevazioni per livello di confidenza. Il cursore imposta la soglia minima di confidenza (parte dal 10%).

Sotto il cursore della confidenza c'è un selettore **Limita a una specie** che permette di restringere la mappa a una sola specie — utile per chiedersi "dove esattamente lungo il percorso ho sentito il tordo boschereccio?". Una voce *Tutte le specie* azzera la restrizione. I filtri si combinano: ad esempio *Con clip audio* + *Tordo boschereccio* + *> 80%* mostra solo i marcatori riproducibili di Tordo boschereccio con punteggio superiore all'80%.

Quando un filtro è attivo, il titolo della barra dell'app acquisisce un sottotitolo con il conteggio delle corrispondenze (ad esempio *"7 rilevazioni"*). *Reimposta* nel pannello riporta al valore predefinito.

## Icone della barra degli strumenti

La barra degli strumenti usa gli stessi significati delle icone descritti in [Icone e controlli](icons-and-controls.md):

- :material-plus-circle-outline: — aggiungi contenuti
- :material-undo-variant: / :material-redo-variant: — scorri tra le modifiche
- :material-content-cut: — modalità di ritaglio
- :material-content-save: — salva le modifiche
- :material-share-variant: — esporta o condividi
- :material-delete-outline: — scarta la Session
- :material-play: — continua un Survey quando questa azione è disponibile
- :material-help-circle-outline: — apre il pannello di aiuto del Riepilogo sessione
- :material-tune: — apre le Impostazioni

## Operazioni tipiche di revisione

- verificare le rilevazioni rispetto alla riproduzione e al contesto dello spettrogramma
- aggiungere una specie o un'annotazione
- ritagliare la registrazione all'intervallo utile
- esportare l'insieme di risultati revisionato

## Esportazione

Il comportamento dell'esportazione dipende dalle opzioni selezionate nelle [Impostazioni](settings.md). L'app può racchiudere le rilevazioni e, facoltativamente, l'audio nel formato di esportazione scelto. Ogni esportazione include metadati di provenienza — versione dell'app, nome e versione del modello, lingua delle specie, marca temporale dell'esportazione, impostazioni conservate con la Session e le opzioni di esportazione pertinenti — scritti in un file accessorio `<prefix>.metadata.json` (ZIP) o in un blocco `meta` di primo livello (JSON), così che le esportazioni siano autodescrittive e riproducibili.

Il blocco `settings` dell'esportazione JSON registra i valori *effettivamente applicati a questa Session* — sensibilità, modalità di score pooling e numero di finestre, guadagno del microfono e taglio del filtro passa-alto — non quelli impostati ora nelle Impostazioni. Questo significa che puoi riprodurre un risultato mesi dopo, o confrontare due Survey, senza dover ricordare la posizione dei vari cursori al momento dell'esecuzione.

Tutte le marche temporali nei nomi dei file esportati (`BirdNET_Live_<date>_<time>_…`) e all'interno dei contenuti CSV / JSON sono formattate nell'ora locale *attuale* del telefono. I record sottostanti sono memorizzati in UTC e convertiti in uscita.
