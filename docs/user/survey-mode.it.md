# Modalità Survey

La modalità Survey è il flusso di lavoro basato sul percorso per Survey in movimento di lunga durata.

## Come aprirla

Dalla Home, tocca la scheda **Modalità Survey** con l'icona :material-routes:.

## Flusso di configurazione

La configurazione del Survey è una procedura guidata in cinque passaggi.

### 1. Dettagli

Puoi inserire:

- nome del Survey
- ID del transetto
- nome dell'osservatore
- GPS, coordinate manuali o nessuna posizione di partenza

Questo passaggio mostra anche il selettore sulla mappa, aggiorna il GPS quando
torni dalle schermate di autorizzazione di sistema e mostra il promemoria
dell'autorizzazione al GPS in background quando necessario. Nella stessa area
della posizione è disponibile una scheda meteo. Se l'accesso al meteo è
disattivato, chiede il consenso **Consenti ricerca meteo**; una volta abilitato,
mostra un'anteprima del sito con un'icona meteo, solo temperatura e vento. Lo
stesso snapshot di Open-Meteo memorizzato nella cache viene riutilizzato quando
il Survey viene salvato.

### 2. Parametri

Questo passaggio contiene parametri specifici del Survey, come:

- selezione del microfono
- frequenza di inferenza
- soglia di confidenza
- intervallo GPS
- durata massima
- modalità di registrazione
- contesto del clip per la registrazione di solo rilevazioni
- modalità di campionamento delle rilevazioni
- limite Top N per specie quando il campionamento è limitato

Le nuove impostazioni di Survey usano un'inferenza di **0,70 Hz** come
predefinita. In questo modo si conservano più vocalizzazioni brevi rispetto
alle scelte a frequenza più bassa per il risparmio energetico, pur eseguendo
il modello meno spesso che a 1,00 Hz. Survey e la modalità Live condividono
una sola pianificazione dell'inferenza e una sola definizione di rilevazione:
a parità di impostazioni di inferenza, entrambe segnalano le stesse specie,
gli stessi punteggi e le stesse durate di rilevazione per lo stesso suono. Le
frequenze più basse lasciano intenzionalmente spazi più ampi tra le finestre
di analisi sovrapposte e possono quindi perdere suoni brevi; 0,30 Hz resta
disponibile quando la durata della batteria è la priorità.

#### Campionamento delle rilevazioni

Un Survey lungo può produrre migliaia di rilevazioni, e salvare un clip audio per ognuna riempie rapidamente lo spazio di archiviazione. Il campionamento delle rilevazioni controlla **quali clip vengono conservati su disco** — *i record delle rilevazioni vengono sempre conservati*, quindi il registro completo della Session resta intatto a prescindere dalla modalità. I record il cui audio è stato scartato semplicemente non hanno un clip riproducibile nel Riepilogo sessione.

Sono disponibili tre modalità:

| Modalità | Cosa fa |
|---|---|
| **Tutte** | Conserva ogni clip. Massimo uso del disco. Consigliata per Survey brevi o quando vuoi l'audio di ogni rilevazione per un'analisi successiva. |
| **Top N** | Conserva solo le **N clip con confidenza più alta per specie**. Gli altri clip vengono eliminati man mano che il Survey procede. N predefinito è 10, configurabile da 1 a 50. |
| **Smart** | Stesso limite per specie di N come Top N, **più** distribuzione spaziale: se una nuova rilevazione cade nello stesso "punto" di un clip già conservato (entro ~500 m e ~2 min l'uno dall'altro), solo quella con confidenza più alta mantiene il clip. Questo evita che un singolo cantore stazionario monopolizzi tutti gli N slot e orienta i clip conservati verso la copertura dell'intero transetto. |

Il limite N è **per specie, non globale**: se registri 10 pettirossi e 10 fringuelli, conservi 20 clip. Non esiste un limite complessivo al numero di clip che un Survey può produrre.

In modalità Smart, se il GPS manca su una rilevazione, il controllo dello stesso punto ripiega su una finestra basata solo sul tempo (~2 min). Con il GPS disponibile, sia la distanza sia il tempo devono sovrapporsi affinché due rilevazioni siano considerate lo stesso punto.

### 3. Avvisi specie

Notifiche in stile push che si attivano a metà Survey quando viene rilevato qualcosa di notevole. Scegli una tra:

- **Disattivato** — nessun avviso (predefinito).
- **Prima nella Session** — un avviso la prima volta che ogni specie viene sentita durante questo Survey.
- **Prima volta in assoluto** — avvisa solo quando l'app incontra una specie per la primissima volta in tutte le tue Sessions (un avviso "lifer"). Si basa su una cronologia delle specie a vita, popolata automaticamente dalle tue Sessions esistenti al primo avvio.
- **Rara per questa zona** — avvisa quando la probabilità del geo-modello per la posizione attuale è sotto una soglia configurabile. Una lettura in tempo reale sotto il cursore spiega esattamente cosa attiverà il valore corrente (ad esempio *"Avvisa su specie con meno del 5% di probabilità in questa zona."*).
- **Lista di osservazione** — avvisa solo sulle specie che hai aggiunto a una lista personalizzata salvata. Lo stesso passaggio della procedura guidata consente di creare nuove liste di osservazione, modificare quelle esistenti in un editor a schermo intero dedicato con tassonomia ricercabile e *Importa da file* (un semplice `.txt`/`.csv` di nomi scientifici) ed eliminare le liste che non servono più.

Un cursore *Confidenza minima* si trova sotto il selettore della modalità e viene automaticamente limitato alla soglia di confidenza della Session (gli avvisi non sono mai più sensibili delle rilevazioni stesse). Una sezione **Avanzato** espone i controlli di frequenza — un margine iniziale all'avvio, un intervallo minimo rigido tra due avvisi qualsiasi e un limite mobile al minuto con il raggruppamento opzionale degli avvisi oltre il limite in un'unica notifica di riepilogo — tutti con selettori a chip da un tocco. La prima volta che passi a una modalità diversa da Disattivato, la procedura guidata richiede al posto tuo l'autorizzazione alle notifiche di Android.

### 4. Consigli sul campo

Una breve lista di controllo pre-avvio all'interno del flusso di configurazione.

### 5. Pronto

La schermata di pronto riassume la configurazione attiva del Survey prima di iniziare con :material-play:.

## Dashboard del Survey in tempo reale

La schermata del Survey in tempo reale ha tre schede principali più un elenco delle rilevazioni recenti.

### Barra superiore

- :material-stop: — termina il Survey
- :material-timer: — tempo trascorso
- :material-help-circle-outline: — apre il pannello di aiuto del Survey
- :material-tune: — apre le impostazioni del Survey

### Schede

- :material-map-outline: — mappa del percorso e rilevazioni mappate
- :material-equalizer: — spettrogramma
- icona del grafico — statistiche riassuntive e suddivisione per specie

### Statistiche e rilevazioni

Sotto il contenuto della scheda, la dashboard del Survey mostra una barra delle statistiche e un elenco delle rilevazioni recenti. Toccando una rilevazione si apre il pannello dei dettagli della specie.

Ogni riga di rilevazione mostra anche le stesse azioni per rilevazione usate nel [Riepilogo sessione](session-review.md): un segno di spunta :material-check: **Conferma** da un tocco e un menu :material-dots-vertical: **Altro** con **Condividi rilevazione** ed **Elimina rilevazione** (con SnackBar per annullare) — così puoi convalidare, condividere o rimuovere un risultato rumoroso durante la cattura, senza attendere la revisione post-Session.

Le stesse azioni sono disponibili dalla **mappa del percorso in tempo reale**: tocca un marcatore di rilevazione per aprire il pannello del lettore dei clip con conferma, condivisione ed eliminazione. La condivisione durante un Survey funziona anche quando hai scelto un'unica registrazione WAV continua invece dei clip per rilevazione — la finestra audio pertinente viene estratta al volo dal file in corso. Vedi [Riepilogo sessione → Condivisione di una singola rilevazione](session-review.md#condivisione-di-una-singola-rilevazione) per i dettagli.

### Registrare un'osservazione

Il pulsante :material-plus-circle-outline: del survey dal vivo apre un piccolo menu con **Aggiungi specie** e **Aggiungi nota**. **Aggiungi specie** apre lo stesso selettore usato in [Session Review](session-review.md#aggiungere-una-specie-a-mano), scegli una specie, poi seleziona :material-ear-hearing: **Sentito** e/o :material-eye: **Visto** nel pannello di conferma e tocca **Aggiungi**. La voce viene marcata con l'ora di quel momento e con la posizione GPS corrente e compare subito nell'elenco delle rilevazioni e sulla mappa del percorso, con il badge manuale e le relative icone orecchio / occhio.

I memo vocali sono volutamente assenti qui: il microfono è impegnato con la registrazione del survey. Aggiungili in Session Review al termine.

## Funzionamento in background

La modalità Survey mantiene visibile una notifica persistente in primo piano durante la registrazione, così Android non sospende la pipeline audio. La notifica si espande per mostrare:

- il tempo trascorso, il numero di rilevazioni, il numero di specie e la distanza percorsa, e
- le **tre specie uniche più recenti** con la loro confidenza e una marca temporale relativa (`proprio ora`, `42 s fa`, `5 min fa`, `2 h fa`).

La notifica — titolo, rilevazioni recenti e piè di pagina delle statistiche — è completamente tradotta nella lingua selezionata nell'app e usa le stesse preferenze di lingua delle specie e *Mostra nomi scientifici* delle schede in-app.

Gli avvisi specie (quando abilitati) compaiono su un canale di notifica Android separato, così puoi silenziarli indipendentemente dalla notifica silenziosa della registrazione in corso. L'icona dell'avviso corrisponde a quella della notifica in primo piano (un uccello monocromatico) e il corpo degli avvisi mostra solo il *motivo* — *"Primo rilevamento in questo Survey"*, *"Nella tua lista di osservazione"*, *"Rilevata in questa posizione con meno del 4% di probabilità"* — lasciando il nome della specie nel titolo in grassetto della notifica, dove Android lo mostra più grande.

Quando **riprendi** un Survey non completato dalla Libreria Sessions, la pipeline degli avvisi viene riarmata dalle tue preferenze di notifica *attuali* — non da quelle configurate il giorno in cui hai avviato il Survey. Disattiva gli avvisi (o cambia modalità, lista di osservazione o controllo della frequenza) prima di toccare Riprendi e il Survey ripreso rispetterà subito le nuove impostazioni.

## Revisione sulla mappa

La vista della mappa del Survey a schermo intero (il pulsante :material-fullscreen: nel Riepilogo sessione) apre un lettore di clip quando tocchi un marcatore. La riga dei comandi ha i pulsanti per la rilevazione precedente e successiva ai lati del comando di riproduzione — scorrono le rilevazioni in ordine cronologico, ma **solo quelle attualmente visibili sulla mappa**, quindi qualsiasi filtro attivo per specie, confidenza o chip di modalità restringe di conseguenza la playlist. I pulsanti si disattivano alla prima/ultima rilevazione dell'elenco filtrato.

## Dopo l'interruzione

BirdNET Live salva il Survey completato e apre il [Riepilogo sessione](session-review.md).
