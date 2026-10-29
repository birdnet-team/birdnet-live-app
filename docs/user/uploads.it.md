# Caricamenti

I caricamenti inviano le Sessions concluse da molti telefoni in un'unica cartella di progetto. Chi guida il progetto configura una cartella una sola volta e distribuisce un link o un codice QR; ogni partecipante lo incolla o lo scansiona e, da quel momento, qualsiasi Session può essere inviata a quella cartella con due tocchi dalla finestra Condividi. Le installazioni ARU possono inviare da sole ogni Session conclusa.

I caricamenti vanno in una sola direzione. L'app scrive file nella cartella del progetto e non legge, elenca né elimina mai nulla al suo interno. Eliminare una Session sul telefono lascia intatta la copia caricata, e nulla viene mai caricato a meno che tu non abbia spuntato una destinazione o attivato i caricamenti ARU automatici.

## Come funziona

Una **destinazione** è una cartella WebDAV in cui l'app può scrivere. Tre tipi funzionano senza configurazioni aggiuntive:

- una condivisione **File Drop di Nextcloud**, la scelta consigliata per la maggior parte dei progetti;
- qualsiasi **indirizzo WebDAV** con nome utente e password, per esempio una cartella nel tuo account cloud personale o un server istituzionale;
- il **server di deposito di riferimento** fornito con BirdNET Live, per chi guida un progetto e vuole token per singolo partecipante e un'esportazione CSV pronta all'uso (vedi la [Guida per sviluppatori](../developer/upload-drop-server.md)).

Ogni caricamento è **un unico file ZIP per Session**, con lo stesso nome dell'esportazione di Condividi, per esempio `BirdNET_Live_2026-05-14_06-30-00_#13.zip`. Contiene sempre il record JSON della Session e, a seconda di cosa spunti, l'audio, le tabelle delle rilevazioni, il report HTML e il file dei metadati dell'app. Lo ZIP finisce in una cartella che prende il nome dal tuo **ID di caricamento**, un codice di otto caratteri che l'app deriva da un'identità casuale conservata per questa installazione. La cartella di chi guida il progetto appare quindi così:

```
4ee91c8f/BirdNET_Live_2026-05-14_06-30-00_#13.zip
4ee91c8f/BirdNET_Live_2026-05-14_07-02-10_#14.zip
b27c0e51/BirdNET_Live_2026-05-14_06-45-00_#3.zip
.birdnet-live/4ee91c8f.json
.birdnet-live/b27c0e51.json
```

La cartella `.birdnet-live` contiene un piccolo file di registrazione per dispositivo, scritto dalla prova di connessione. Nextcloud la nasconde a meno che «Mostra file nascosti» non sia attivo. Riporta l'ID di caricamento, la versione dell'app, la piattaforma e l'**identificativo del partecipante** facoltativo (un nome, un'e-mail o un numero di partecipante) inserito da chi partecipa, così chi guida il progetto può capire chi sta dietro ogni codice senza che un nome diventi mai il nome di una cartella. Lo stesso identificativo viene scritto nel record JSON di ogni Session caricata.

## Per chi guida un progetto

### Opzione A: un File Drop di Nextcloud

1. In Nextcloud, crea una cartella per il progetto, per esempio `Spring Survey 2027`.
2. Apri il suo pannello di condivisione, crea un **link di condivisione** e imposta i permessi su **Deposito file (solo caricamento)**. I partecipanti potranno così aggiungere file, ma non vedere mai cosa hanno inviato gli altri.
3. Imposta una **password** sul link. Senza, chiunque trovi il link può caricare nella cartella. Un File Drop non può comunque essere letto, quindi la mancanza di una password è una scelta che l'app accetta senza obiezioni.
4. Facoltativamente imposta una data di scadenza alla fine del progetto.
5. Copia il link di condivisione. Ha un aspetto simile a `https://cloud.example.org/s/AbCdEf123456`.

L'app converte da sola quel link nell'endpoint WebDAV della condivisione; i partecipanti non vedono mai un indirizzo WebDAV. Un File Drop non sovrascrive mai: quando un partecipante carica di nuovo la stessa Session, Nextcloud conserva la copia precedente con un nome numerato, quindi il file più recente è quello senza numero.

Funzionano anche le condivisioni Nextcloud con permesso di **caricamento e modifica**, ma l'app avviserà i partecipanti che la credenziale può elencare la cartella, perché chiunque abbia il link può allora leggere i dati di tutti gli altri. Le condivisioni di sola lettura vengono rifiutate dalla prova di connessione.

### Opzione B: la tua cartella WebDAV

Funziona qualsiasi server WebDAV: una cartella in un account cloud personale, un file server istituzionale, ownCloud oppure Nextcloud con un account normale. I partecipanti inseriscono l'indirizzo più nome utente e password in **Avanzate** quando si uniscono. Per un account Nextcloud o ownCloud usa una **password per app** dalle impostazioni di sicurezza dell'account, mai la password di accesso; quando viene indicato solo un nome host, l'app prova anche le consuete posizioni di Nextcloud e ownCloud su quell'host.

Una credenziale di questo tipo di solito può leggere la cartella, quindi la prova di connessione mostra un avviso. Preferisci una configurazione di sola scrittura quando i partecipanti non fanno tutti parte dello stesso gruppo.

### Opzione C: il server di deposito di riferimento

`tools/webdav_drop_server` nel repository dei sorgenti è un piccolo server Python con token per singolo partecipante che puoi revocare, un comando `collect` che unisce ogni record JSON caricato in `sessions.csv`, `detections.csv` e `species_summary.csv`, e un comando `invite` che stampa un link di accesso e un codice QR. Configurazione e distribuzione sono descritte nella [Guida per sviluppatori](../developer/upload-drop-server.md).

### Creare il link di accesso e il codice QR

Un link di accesso riunisce in un solo elemento tutto ciò che serve a un partecipante: la destinazione, la credenziale, un nome di progetto e le impostazioni predefinite che suggerisci. Apri la [pagina di accesso](../join.md) su questo sito e compila:

- **Share link or WebDAV address**: il link di condivisione Nextcloud di cui sopra, oppure l'indirizzo della cartella WebDAV.
- **User name**: lascia vuoto per un link di condivisione Nextcloud.
- **Share password or token**: la password della condivisione, oppure il segreto dell'account o del token.
- **Project name shown in the app**: ciò che i partecipanti vedranno come nome della destinazione. Possono rinominarla, ma questo è il valore predefinito.
- **Suggest including audio** e **Suggest Wi-Fi only**: i valori predefiniti per gli interruttori della destinazione.

Premi **Build link and QR code**. Tutto avviene nel tuo browser; nulla viene inviato da nessuna parte. Il segreto si trova nella parte del link dopo `#`, che i browser non trasmettono mai al server web che ospita la pagina.

In alternativa, unisciti prima alla destinazione sul tuo telefono (vedi sotto), poi apri la destinazione in **Impostazioni → Esportazione e sincronizzazione → Destinazioni di caricamento** e tocca **Mostra codice di accesso**. L'app mostra lo stesso tipo di codice QR con un pulsante **Copia link**.

### Distribuirlo

Stampa il codice QR sulla scheda di campo, mostralo su uno schermo durante il briefing o invia il link per messaggio. **Tratta il link e il codice come una password**: chiunque li possieda può caricare nel tuo progetto. Se trapelano, cambia la password della condivisione o revoca il token e distribuisci un nuovo codice.

Quando un partecipante scansiona il codice con la fotocamera del telefono, il browser apre una piccola pagina di destinazione con un pulsante **Open in BirdNET Live**, che porta alla schermata Aggiungi destinazione dell'app con il link già compilato. Incollare il link direttamente in quella schermata funziona esattamente allo stesso modo.

### Cosa vedrai

Una cartella per dispositivo, uno ZIP per Session e le registrazioni nascoste in `.birdnet-live`. Apri uno ZIP per trovare il record JSON (sempre presente) e le tabelle, il report e l'audio che il partecipante ha scelto di includere. Per sapere quale persona sta dietro un ID di caricamento, leggi il file di registrazione di quel codice o il campo `meta.participant` all'interno di uno qualsiasi dei suoi record JSON. Con il server di deposito di riferimento, `collect` lo fa per te e scrive una colonna `participant`.

## Per i partecipanti

### Unirsi a una destinazione

1. Apri **Impostazioni → Esportazione e sincronizzazione → Destinazioni di caricamento** e tocca **Aggiungi destinazione**. Scansionare il codice QR di un progetto con la fotocamera, o toccare un link di accesso che hai ricevuto, ti porta alla stessa schermata con il link già compilato.
2. Incolla il link di accesso, il link di condivisione Nextcloud o un indirizzo WebDAV in **Link di accesso o indirizzo del server**. Il pulsante **Incolla** lo prende dagli appunti.
3. Facoltativamente inserisci un **ID partecipante, nome o e-mail (facoltativo)**. Viene salvato con ogni caricamento così chi guida il progetto sa chi l'ha inviato, e non compare mai nei nomi delle cartelle. Sotto il campo l'app mostra **Il tuo ID di caricamento**, la cartella in cui finiranno i tuoi caricamenti.
4. Per un semplice indirizzo WebDAV, apri **Avanzate** e inserisci **Nome utente** e **Password o token**. Un link di condivisione Nextcloud non ha bisogno di nessuno dei due; se la condivisione ha una password, inseriscila come password.
5. Tocca **Prova connessione**. L'app contatta il server, crea la cartella di registrazione nascosta, verifica se la credenziale può elencare la cartella e scrive il tuo file di registrazione. Il risultato è una sola frase: **La connessione funziona**, un avviso che dovresti leggere, oppure un errore con la probabile soluzione.
6. Dai alla destinazione un **Nome della destinazione** (precompilato dal link di accesso), decidi se attivare **Carica solo con Wi-Fi** e tocca **Salva destinazione**.

Nulla viene salvato finché la prova non è riuscita. La credenziale va nel portachiavi del dispositivo, mai nei dati esportati.

Avvisi che vale la pena capire:

- **Questa credenziale può elencare la destinazione** significa che la condivisione o l'account può leggere i dati degli altri partecipanti. I caricamenti funzionano, ma chiedi a chi guida il progetto un File Drop o un token di sola scrittura se il progetto coinvolge persone esterne al tuo gruppo.
- **Questa condivisione non ha una password e può essere elencata** combina i due rischi: chiunque abbia il link può leggere tutto. Chiedi a chi guida il progetto di impostare una password o di usare un File Drop.
- **Questo server non consente cartelle** è solo informativo: i caricamenti usano nomi di file piatti come `4ee91c8f__BirdNET_Live_….zip` invece di una cartella.

### La schermata della destinazione

Toccando una destinazione nell'elenco si apre la sua schermata con l'indirizzo del server, quando è stata aggiunta e usata l'ultima volta, e questi controlli:

- **Rinomina** (la matita nella barra dell'app) cambia il nome mostrato nell'app.
- **Carica solo con Wi-Fi** trattiene i caricamenti mentre il telefono è su rete cellulare.
- **Carica automaticamente le Sessions ARU** mette in coda ogni Session ARU conclusa per questa destinazione senza chiedere (vedi sotto).
- **Prova connessione** ripete la prova di connessione, per esempio dopo che chi guida il progetto ha cambiato la password.
- **Mostra codice di accesso** visualizza un codice QR più **Copia link**, così un secondo telefono può unirsi alla stessa destinazione.
- **Rimuovi destinazione** dimentica la destinazione e la sua credenziale e scarta i caricamenti in attesa verso di essa. Le Sessions già caricate restano sul server.

La prima voce dell'elenco delle destinazioni è **Il tuo ID di caricamento**, con l'identificativo del partecipante sotto; toccala per cambiare l'identificativo. Cambiarlo non sposta nulla sul server, perché le cartelle prendono il nome dall'ID.

### Caricare una Session

I caricamenti partono dalla stessa azione **Condividi** che già usi, in tre punti:

- il **menu a tre punti** (:app-moreVert:) di una scheda Session nella Libreria Sessions;
- il pulsante **Condividi** dopo aver selezionato più Sessions nella Libreria Sessions;
- l'icona **Condividi** (:app-share:) nella barra degli strumenti del Riepilogo sessione.

La finestra Condividi ha due schede non appena esiste almeno una destinazione:

- **Contenuto** sceglie cosa contiene l'esportazione: **Audio** (la registrazione completa, o gli spezzoni delle rilevazioni quando sono stati conservati solo quelli) e **Metadati** (le tabelle, il report e il file dei metadati dell'app attivati in Esportazione e sincronizzazione). Le caselle partono allineate alle tue impostazioni e valgono solo per questa condivisione.
- **Invia a** elenca **Finestra di condivisione** (altre app, file, messaggi) e una casella per destinazione. Il badge sulla scheda conta le destinazioni spuntate. Le destinazioni spuntate l'ultima volta sono già selezionate, tranne quelle a cui questa Session è già stata inviata: partono deselezionate e mostrano **Caricato** con la data e **Spunta per caricare di nuovo**. Quando la finestra si apre, l'app controlla silenziosamente ogni destinazione; se il server dichiara che rifiuterebbe il caricamento, per esempio perché la password è cambiata o la condivisione è stata rimossa, la riga diventa rossa con il motivo.

Togli la spunta a **Finestra di condivisione** e il pulsante recita **Carica**; con entrambe spuntate recita **Condividi e carica**. Una snackbar conferma quante Sessions sono state messe in coda. Una Session va sempre prima in coda e viene caricata in background, così puoi continuare a lavorare.

### Seguire un caricamento

La scheda della Session nella Libreria Sessions mostra lo stato come prima riga sotto il titolo della Session: **In coda**, **In attesa del Wi-Fi**, **In attesa di una rete**, **Caricamento in corso…**, **Caricato il** seguito dalla data, oppure un errore. Tocca la riga per l'elenco per destinazione con **Riprova ora** e **Rimuovi dalla coda**. Il Riepilogo sessione mostra lo stesso stato come icona nuvola nella barra dell'app; toccandola si apre lo stesso elenco.

I caricamenti non riusciti vengono ritentati da soli con attese crescenti, fino a sei ore di distanza, per un massimo di trenta tentativi. **Non riuscito, verrà ritentato** significa che l'app riproverà. **Caricamento non riuscito. Controlla le impostazioni della destinazione.** significa che il server ha rifiutato e un nuovo tentativo non può aiutare: la password è cambiata, i caricamenti sono stati disattivati o la destinazione è stata rimossa. Apri la destinazione, esegui **Prova connessione** e rimuovila e aggiungila di nuovo se la credenziale è cambiata.

La riga e l'icona compaiono solo finché almeno una destinazione a cui la Session è stata inviata esiste ancora nelle Impostazioni. Rimuovi la destinazione e scompaiono, perché «caricato» non è più un fatto riferito a una destinazione che possiedi.

### Cosa avviene in background

I caricamenti in coda procedono mentre l'app è aperta e ogni volta che torna in primo piano. Su Android procedono anche con l'app chiusa: il sistema li avvia non appena è disponibile una rete adatta, Wi-Fi quando la destinazione lo richiede, e continua a riprovare finché la coda non è vuota. Su iOS i caricamenti procedono mentre l'app è aperta.

### Caricare di nuovo una Session

Caricare di nuovo la stessa Session, per esempio dopo aver corretto le rilevazioni nel Riepilogo sessione, scrive lo stesso nome di file nella stessa cartella. I server che lo consentono sostituiscono il file; un File Drop di Nextcloud conserva invece la copia precedente con un nome numerato. In entrambi i casi chi guida il progetto riceve la versione più recente e nulla viene eliminato.

## Modalità ARU

Le installazioni sul campo producono molte Sessions, spesso mentre nessuno è al telefono. Attiva **Carica automaticamente le Sessions ARU** su una destinazione, e ogni Session ARU conclusa viene messa in coda per essa senza alcuna finestra, usando le impostazioni predefinite di Esportazione e sincronizzazione per Audio e Metadati. Un'installazione che salva ogni ciclo come Session a sé carica ciclo per ciclo; la Session complessiva dell'installazione non viene caricata due volte.

Lascia **Carica solo con Wi-Fi** attivo per una stazione con un piano dati cellulare, a meno che il piano non possa reggere l'audio, e valuta di registrare in modalità **Solo rilevazioni** o **Disattivata** quando l'audio sarebbe troppo grande da inviare. I caricamenti fluiscono poi ogni volta che il telefono vede una rete adatta, anche mentre l'app è in background su Android.

## Due esempi pratici

### Un Survey nel fine settimana con un File Drop di Nextcloud

Chi guida il progetto crea una cartella `Birdathon 2027` nel Nextcloud dell'università, la condivide come File Drop con una password, incolla il link di condivisione e la password nella pagina di accesso, dà un nome al progetto e stampa il codice QR sulla scheda del briefing. Venti volontari lo scansionano sabato mattina, inseriscono il proprio nome come identificativo del partecipante, superano la prova di connessione e salvano.

Domenica sera ogni volontario apre la Libreria Sessions, seleziona le Sessions del fine settimana, tocca Condividi, lascia il progetto spuntato in Invia a e tocca **Carica**. I caricamenti aspettano il Wi-Fi di casa e si completano durante la notte. Lunedì chi guida il progetto trova venti cartelle con il nome dell'ID di caricamento, ciascuna con una manciata di ZIP, e legge i nomi dei volontari dai file di registrazione nascosti o dal campo `meta.participant` nei record JSON.

### Correzioni nel Riepilogo sessione, poi una stazione ARU

Un partecipante rivede una Session, rimuove due false rilevazioni, aggiunge una specie a mano e salva. L'icona nuvola nella barra dell'app del Riepilogo sessione mostra che la Session è stata caricata sabato. Tocca l'icona Condividi nella barra degli strumenti, spunta il progetto in Invia a, dove parte deselezionato e recita **Caricato** con la data, e preme **Carica**. Lo ZIP corretto sostituisce quello precedente, oppure finisce accanto a esso con un nome numerato su un File Drop.

Lo stesso partecipante lascia un telefono come stazione ARU presso un canneto con un hotspot Wi-Fi nel capanno. Si unisce alla destinazione del progetto su quel telefono, attiva **Carica automaticamente le Sessions ARU** e lascia attivo **Carica solo con Wi-Fi**. Ogni mattina i cicli notturni conclusi vengono messi in coda e caricati mentre la stazione è inattiva; chi guida il progetto vede comparire nuovi ZIP sotto l'ID di caricamento di quel telefono senza che nessuno lo tocchi.

## Privacy e responsabilità

Le destinazioni di caricamento sono gestite da chi organizza i progetti, non dal BirdNET-Team. La cartella, il server, chi può leggerlo e per quanto tempo i dati vengono conservati sono regolati dalle norme di privacy e sicurezza dell'organizzatore; chiedigli i dettagli prima di unirti. BirdNET Live scrive solo ciò che hai scelto di inviare e conserva la credenziale nel portachiavi del tuo dispositivo.

Un caricamento contiene ciò che conterrebbe una condivisione: il record JSON della Session con rilevazioni, orari, coordinate, il nome dell'osservatore e il nome del luogo se impostati, l'ID di caricamento del dispositivo, l'identificativo del partecipante che hai inserito e la versione dell'app; più l'audio, le tabelle e il report che hai spuntato. Rivedi la scheda Contenuto prima di inviare e lascia fuori l'audio quando una registrazione può contenere voci o qualsiasi altra cosa che non consegneresti al progetto. **Sei responsabile di ciò che carichi.** Non caricare né condividere dati che consideri privati o confidenziali, e non caricare registrazioni che non sei autorizzato a trasmettere.

## Risoluzione dei problemi

| Messaggio | Cosa significa | Cosa fare |
| --- | --- | --- |
| Non sembra un link né un indirizzo di server. | Il testo non è un URL. | Incolla l'intero link di accesso, il link di condivisione o l'indirizzo `https://`. |
| Il server ha rifiutato le credenziali. | Password errata o mancante, oppure condivisione rimossa. Nextcloud risponde così anche per le condivisioni eliminate. | Usa la password della condivisione o una password per app; chiedi a chi guida il progetto se la condivisione esiste ancora. |
| Questo indirizzo non è un endpoint WebDAV. | Hai incollato la pagina web di una cartella, non un link di condivisione o un indirizzo WebDAV. | Incolla il link di condivisione (`…/s/…`) o l'indirizzo WebDAV. |
| I caricamenti non sono consentiti qui. | La condivisione è di sola lettura. | Chiedi a chi guida il progetto un File Drop o il permesso di caricamento. |
| La cartella non esiste sul server. | L'indirizzo non punta a nulla, oppure la cartella è stata eliminata. | Verifica l'indirizzo con chi guida il progetto. |
| Impossibile verificare il certificato del server. | TLS autofirmato o difettoso. | Chiedi a chi guida il progetto un indirizzo con un certificato valido. |
| Questo indirizzo usa HTTP non cifrato. | Connessione non cifrata fuori dalla tua rete locale. | Usa un indirizzo `https://`. |
| In attesa del Wi-Fi | La destinazione è impostata su solo Wi-Fi e il telefono è su rete cellulare. | Aspetta, oppure disattiva l'interruttore solo Wi-Fi della destinazione. |
| Non riuscito, verrà ritentato | Un problema temporaneo come una connessione interrotta o un errore del server. | Nulla; l'app riprova da sola. **Riprova ora** forza un tentativo. |
| Caricamento non riuscito. Controlla le impostazioni della destinazione. | Il server ha rifiutato per un motivo che un nuovo tentativo non può risolvere. | Apri la destinazione, esegui **Prova connessione** e rimuovila e aggiungila di nuovo se la credenziale è cambiata. |
| La credenziale di questa destinazione manca dal portachiavi del dispositivo. | La voce del portachiavi è andata perduta, per esempio dopo un ripristino su un nuovo telefono. | Rimuovi la destinazione e aggiungila di nuovo. |

Vedi anche l'impostazione [Destinazioni di caricamento](settings.md#destinazioni-di-caricamento) e le guide [Libreria Sessions](session-library.md) e [Riepilogo sessione](session-review.md).
