# Impostazioni

BirdNET Live riutilizza una schermata Impostazioni su più flussi di lavoro. Il pulsante :material-tune: apre le sezioni rilevanti per la schermata da cui provieni.

## Come funziona l'ambito delle impostazioni

- Aprire le Impostazioni dalla Home mostra la schermata completa.
- Aprire le Impostazioni da Live, Survey, Point Count o Analisi file restringe la schermata alle sezioni pertinenti.

## Generali

### Tema

Scegli **Scuro**, **Chiaro** o **Sistema**.

Se **Colore dinamico** è attivo, BirdNET Live cerca anche di adottare la palette di sistema del tuo dispositivo Android. Ha effetto solo sui dispositivi Android supportati; su iPhone e iPad l'app continua a usare il tema standard di BirdNET Live, quindi attivare l'interruttore lì non cambia nulla.

Attiva **Tema ad alto contrasto** per usare una palette dell'interfaccia in bianco e nero, chiara o scura, con testo più marcato e superfici bordate invece di schede colorate. Segue la scelta **Scuro**, **Chiaro** o **Sistema**, ha la precedenza sul colore dinamico finché è attivo e conserva i colori di pericolo, avviso, convalida, modalità, punteggio e spettrogramma.

### Lingua dell'app

Imposta la lingua dell'interfaccia.

### Nomi delle specie

Controlla la lingua usata per i nomi delle specie. **Sistema** usa la lingua preferita del telefono quando quel nome è disponibile, anche se l'interfaccia ripiega sull'inglese. **Segui l'app** usa invece la lingua dell'interfaccia.

### Mostra i nomi scientifici

Mostra i nomi scientifici sotto i nomi comuni in tutta l'app.

### Mostra tutte le specie rilevate

Solo modalità Live e Point Count. Disattivato per impostazione predefinita, quindi queste schermate continuano a mostrare solo le specie rilevate nell'ultimo ciclo di inferenza: in pratica quelle che stanno vocalizzando in questo momento. Attivalo per far sì che ogni specie rilevata durante la Session in corso resti visibile nell'elenco, anche dopo che ha smesso di vocalizzare o è scesa sotto la soglia di confidenza.

Quando è attivo compare **Ordinamento dell'elenco specie**. **Più recenti prima** mostra in alto le specie che stanno vocalizzando, ordinate per confidenza attuale, e poi le specie mantenute in base alla rilevazione più recente. **Confidenza** ordina in base alla confidenza più alta raggiunta da ciascuna specie durante la Session, **Alfabetico** in base al nome comune localizzato e **Occorrenze** in base al numero di rilevazioni. In ogni modalità di ordinamento la percentuale e la barra di confidenza compaiono solo mentre quella specie sta vocalizzando (le righe mantenute delle specie che hanno smesso sono attenuate), e le rilevazioni ripetute mostrano un contatore in fondo alla riga del nome comune.

### Nome dell'osservatore

La configurazione di Survey, Point Count e ARU ricorda l'ultimo nome di osservatore non vuoto inserito in una di queste modalità e lo precompila alla successiva preparazione di una Session sul campo. In questo modo l'uso ripetuto su un telefono da campo personale resta rapido, pur lasciandoti modificare o cancellare l'osservatore prima di avviare una Session.

### ID ARU/stazione

La configurazione ARU ricorda l'ultimo ID ARU/stazione non vuoto e lo precompila per il deployment successivo. Quando è presente, l'ID viene incluso nel nome della Session ARU e nei nomi dei file di esportazione, così i deployment ripetuti su siti fissi restano identificabili anche fuori dall'app.

### Visualizzazione dei timestamp

Controlla come compaiono gli orari delle singole rilevazioni nel riepilogo della Session.

- **Relativo** mostra lo scarto dall'inizio della registrazione, ad esempio `00:12:34`. Ideale per esaminare una singola Session e allinearsi al cursore di riproduzione dello spettrogramma.
- **Assoluto** mostra l'ora locale in cui la rilevazione è stata acquisita, ad esempio `08:42:17`. Ideale per incrociare note di campo, registri meteo o registrazioni simultanee.

Se una rilevazione cade in un giorno di calendario diverso dall'inizio della Session (ad esempio durante un rilievo notturno), l'ora assoluta riceve il suffisso `+1d`, così nessuno scambia il coro dell'alba di domani per quello di oggi.

Quando è selezionato **Assoluto** compare l'interruttore aggiuntivo **Mostra i secondi nei timestamp**. Disattivalo se preferisci il più compatto `08:42` a `08:42:17`: utile quando scorri lunghi elenchi di rilevazioni. Gli scarti relativi mostrano sempre i secondi, perché in fase di revisione serve una precisione inferiore al minuto per allinearsi al cursore dello spettrogramma.

Archiviazione ed esportazioni usano sempre istanti in UTC, indipendentemente da questa impostazione: la scelta non incide quindi mai sui dati, ma solo su come vengono mostrati.

## Audio

Questi controlli compaiono nei flussi di lavoro dal vivo basati sull'audio.

### Sorgente audio

Un pannello con due controlli indipendenti: **Microfono** — da quale ingresso registrare — e **Elaborazione** — quanto il telefono può alterare il segnale in ingresso. Si combinano liberamente, quindi un microfono USB registrato *senza elaborazione* è una configurazione del tutto valida. La selezione viene conservata tra un avvio e l'altro dell'app, e lo stesso selettore compare nelle schermate di configurazione di Survey, Point Count e ARU. Le modifiche hanno effetto immediato: anche a registrazione in corso l'app sostituisce il microfono sotto la Session attiva invece di aspettare la successiva.

**Microfono** elenca per nome ogni ingresso esposto dal telefono: microfoni USB, cablati e Bluetooth e, su molti telefoni, anche i singoli microfoni integrati (ad esempio *inferiore* e *posteriore*). I kit microfonici wireless come Rode Wireless GO o DJI Mic si collegano tramite un ricevitore USB-C, quindi compaiono qui come normali dispositivi audio USB a piena qualità.

**Elaborazione** è la parte che conta di più, ed è **solo per Android**. Per impostazione predefinita i telefoni applicano all'audio del microfono un DSP tarato sul parlato — riduzione del rumore, sagomatura spettrale e guadagno automatico — perché il microfono è usato soprattutto per le chiamate. Quell'elaborazione tratta il canto degli uccelli come rumore da sopprimere, e nessuna impostazione ordinaria la disattiva. L'unica via d'uscita è chiedere ad Android una *sorgente audio* diversa:

| Opzione | Cosa fa |
|---|---|
| **Predefinita del telefono** | Ciò che il telefono fa normalmente, elaborazione della voce inclusa. Il comportamento originario, e tuttora quello predefinito, così per gli utenti esistenti non cambia nulla. |
| **Senza elaborazione** | Il segnale grezzo del microfono: nessuna riduzione del rumore, nessun guadagno automatico. Di solito la scelta migliore per gli uccelli. |
| **Riconoscimento vocale** | Disattiva anch'esso riduzione del rumore e guadagno automatico, e funziona su quasi tutti i telefoni. |

**Provale e confronta.** Quale vinca dipende davvero dal dispositivo. *Senza elaborazione* è l'ideale, ma Android la onora solo sui telefoni il cui produttore ne dichiara il supporto: sugli altri ripiega silenziosamente e suona identica a *Predefinita di sistema*. È a questo che serve *Riconoscimento vocale*: le regole di compatibilità di Android **richiedono** che con essa guadagno automatico e soppressione del rumore siano disattivati, quindi fornisce audio non elaborato in modo affidabile anche sui telefoni che ignorano *Senza elaborazione*. Se passare a *Senza elaborazione* non cambia nulla, passa a *Riconoscimento vocale*.

Aspettati che le opzioni senza elaborazione suonino **più basse**: è l'assenza del guadagno automatico, non un difetto. Alza il **Guadagno** per compensare se l'indicatore di livello appare basso.

**Su iOS** il controllo Elaborazione è nascosto e il pannello è semplicemente un elenco di microfoni. iOS consegna già all'app un audio sostanzialmente non elaborato, quindi qui non c'è nulla di equivalente da scegliere.

### Guadagno

Amplificatore lineare applicato all'audio in ingresso prima che raggiunga lo spettrogramma e il classificatore. Lascialo a **1,0×** a meno che l'ingresso non sia sistematicamente troppo basso, ad esempio un microfono lavalier ad alta impedenza collegato a un telefono o un'interfaccia USB con il preamplificatore troppo basso. Spingere il guadagno oltre 1,0 non farà comparire per magia richiami che il microfono non ha mai catturato; riscala soltanto ciò che il microfono ha fornito, quindi i suoni forti e vicini possono saturare. Sotto 1,0 è utile nel raro caso in cui un ingresso troppo forte satura lo spettrogramma.

### Filtro passa-alto (Hz)

Taglia il contenuto a bassa frequenza prima dell'inferenza con un filtro di Butterworth a 24 dB/ottava: il valore del cursore è la frequenza di taglio a −3 dB. **0 Hz lo disattiva.** Un taglio a 100–200 Hz elimina vento, rimbombo del traffico e rumori di manipolazione senza toccare la maggior parte delle specie; avvicinandosi a 500–1000 Hz iniziano a sparire i richiami gravi, i rapaci notturni, i galliformi e il "boato" del tarabuso, quindi sali così in alto solo se stai deliberatamente ignorando quelle specie in cambio di uno spettrogramma molto più pulito in un ambiente urbano rumoroso. Il taglio che scegli dovrebbe essere visibile come una netta linea orizzontale sullo spettrogramma dal vivo.

## Inferenza

### Durata della finestra

Controlla la lunghezza della finestra di analisi. I valori disponibili sono **1**, **3**, **5**, **7**, **10** e **15** secondi.

### Soglia di confidenza

Stabilisce quanto debbano essere prudenti le rilevazioni. Il valore predefinito è **35 %**, che mantiene l'elenco dal vivo concentrato sulle corrispondenze più solide lasciando comunque spazio a richiami lontani o parzialmente mascherati. Abbassala se stai censendo specie rare o poco vocali e prevedi di rivedere più candidati in seguito; alzala quando il rumore di fondo o i falsi positivi frequenti affollano la Session.

### Sensibilità

Uno scostamento sull'asse x applicato ai punteggi di probabilità grezzi del modello prima del pooling dei punteggi, del filtro geografico e della soglia di confidenza. Il modello audio di BirdNET include già un'attivazione sigmoide, quindi BirdNET Live riconverte prima ogni probabilità nello spazio dei logit, aggiunge il bias di sensibilità e la riconverte poi in probabilità. Valori più alti rendono il rilevatore più permissivo: richiami più deboli o ambigui superano la soglia, al costo di più falsi positivi. Valori più bassi sono più severi e lasciano passare solo rilevazioni sicure. Il valore predefinito **1,0** non applica alcuno scostamento e corrisponde al riferimento BirdNET. Prova **1,25** se sospetti che il modello si perda richiami lontani; scendi a **0,75** se sei sommerso da rilevazioni di bassa qualità di specie comuni. La sensibilità si applica a caldo: modificarla a metà Session ha effetto dalla finestra di inferenza successiva.

### Frequenza di inferenza

Controlla con quale frequenza BirdNET esegue l'inferenza. Il cursore usa gli stessi passi **0,10–1,00 Hz** della configurazione di Survey e ARU.

BirdNET Live leviga internamente i punteggi sulle finestre di inferenza
recenti per ridurre i falsi positivi isolati. Questo pooling non è esposto come
impostazione utente; per impostazione predefinita usa una modalità di pooling
adattiva con cinque finestre recenti e un limite di anzianità di 10 secondi in
tempo reale. Alle frequenze di inferenza elevate usa il pooling per media, per
decisioni stabili dal vivo; alle cadenze più lente di Survey e ARU usa il
pooling LME, per mantenere alta la precisione su esecuzioni lunghe. Le
rilevazioni accettate mostrano la confidenza recente più alta supportata dal
modello, così le vocalizzazioni evidenti possono ancora presentare confidenza
elevata invece di essere appiattite dalla levigatura.

## Spettrogramma

### Dimensione FFT

Controlla la risoluzione in frequenza dello spettrogramma.

### Mappa dei colori

Scegli **Viridis**, **Magma**, **Plasma**, **Cividis**, **Jet**, **Turbo**, **Scala di grigi** o **BirdNET**. **Turbo** è la moderna opzione arcobaleno simile a Jet.

### Durata (velocità di scorrimento)

Controlla quanto tempo è visibile nella finestra dello spettrogramma.

### Intervallo di frequenza

Imposta la frequenza massima visualizzata.

### Ampiezza logaritmica

Applica allo spettrogramma una scala logaritmica per renderlo più leggibile.

### Qualità

Controlla con quanta morbidezza viene ridimensionata l'immagine dello spettrogramma. **Media** è l'equilibrio predefinito. Scegli **Bassa** sui telefoni più datati quando lo scorrimento scatta o il dispositivo si scalda; scegli **Alta** se preferisci un rendering più fluido e il tuo dispositivo ha margine di GPU. L'intuizione: questo cambia solo il costo di rendering, non l'analisi audio né i risultati delle rilevazioni.

## Annunci

Questa sezione stabilisce se BirdNET Live debba **leggere le rilevazioni ad alta voce nelle cuffie o dall'altoparlante del telefono** mentre una Session sta registrando. L'intera funzione è **disattivata per impostazione predefinita**, perché modifica l'ambiente acustico intorno al microfono: attivarla è un compromesso consapevole. Non esiste una procedura guidata: i selettori di livello di dettaglio × frequenza qui sotto *sono* l'intera configurazione, quindi puoi toccare un preset diverso in qualsiasi momento e sentire subito la differenza. L'intuizione: nei rilievi lunghi non puoi continuare a guardare lo schermo; una voce discreta all'orecchio ti permette di tenere gli occhi sull'habitat e sapere comunque cosa è appena stato sentito.

### Leggi le rilevazioni ad alta voce (interruttore principale)

Disattivato per impostazione predefinita. Una volta attivo, l'app pronuncia ogni rilevazione accettata usando la sintesi vocale integrata del dispositivo. **Le cuffie sono vivamente consigliate**: usando l'altoparlante del telefono c'è il rischio che l'annuncio venga captato dal microfono e rilevato di nuovo, perciò l'app silenzia brevemente la registrazione attorno a ogni pronuncia per evitare questo anello (vedi *Silenzia il microfono mentre parla* più avanti).

### Preset del livello di dettaglio

Quanto l'app dice di ogni rilevazione. **Minimo** pronuncia solo il nome della specie (ideale per rilievi molto lunghi in cui vuoi soltanto il segnale). **Bilanciato** è il valore predefinito: frasi brevi e variate come *«Pettirosso»*, *«Sentito un pettirosso»*, *«Ancora un pettirosso»*. **Loquace** aggiunge un po' più di contesto e si avvicina all'avere qualcuno che commenta accanto a te. **Personalizzato** compare automaticamente se modifichi a mano i valori numerici in Avanzate. L'intuizione: le stesse impostazioni di limitazione possono risultare troppo silenziose o troppo chiacchierone a seconda di come sono formulate; il livello di dettaglio ti permette di mantenere la cadenza e regolare solo la quantità di parole.

### Preset della frequenza

Con quale frequenza all'app è consentito parlare. Cinque livelli, dal più silenzioso al più loquace. **Raro** e **Parco** attendono a lungo tra un annuncio e l'altro e ne limitano il ritmo: adatti a rilievi di più ore in cui vuoi percepire l'attività senza un commento continuo. **Normale** è la cadenza conversazionale predefinita. **Frequente** accorcia gli intervalli e alza il tetto; adatto a brevi Session Live o quando vuoi un riscontro più vicino al tempo reale. **Costante** elimina del tutto il ritardo iniziale e lascia parlare l'app in quasi ogni ciclo di rilevazione: utile per dimostrazioni, accessibilità, o quando l'attesa prima del primo annuncio con *Frequente* ti sembra troppo lunga. **Personalizzato** compare quando modifichi i campi temporali in Avanzate. L'intuizione: è l'unica manopola che decide se l'app resta sullo sfondo o diventa una presenza; tocca un preset diverso e sentirai la nuova cadenza già al ciclo di rilevazione successivo, senza pulsante di salvataggio.

### Voce

Tocca la riga della voce per scegliere tra le voci di sintesi installate per la lingua degli annunci, oppure lascia selezionata **Voce predefinita** per far decidere il dispositivo. Disponibilità e qualità delle voci dipendono dal sistema operativo e dai pacchetti vocali installati; puoi installare voci aggiuntive dalle impostazioni di sintesi vocale del dispositivo.

**Velocità** va da 0,5× a 1,5×; il valore predefinito 1,0× è il ritmo «normale» della piattaforma. **Tono** va da 0,7× a 1,3×. Abbassare leggermente il tono e rallentare un po' può rendere gli annunci più comprensibili all'aperto, con vento o acqua che scorre sullo sfondo. *Riproduci un esempio* consente di ascoltare la voce scelta, lo stile di formulazione attuale, la velocità e il tono senza uscire dalle Impostazioni. Le modifiche si applicano all'annuncio successivo.

### Avanzate

Una sezione a scomparsa che espone alcuni interruttori di instradamento audio e il selettore della modalità di attivazione. In genere non serve aprirla: i preset di livello di dettaglio e frequenza qui sopra sono le uniche manopole che contano nell'uso quotidiano. I valori numerici della limitazione (tolleranza iniziale, intervallo minimo, massimo al minuto, silenzio nelle sequenze, azzeramento della recency) sono raccolti nel cursore **Frequenza**, così c'è un unico punto ovvio dove alzare o abbassare la cadenza.

- **Consenti l'altoparlante del telefono** — Quando è disattivato, gli annunci vengono saltati in silenzio se non ci sono cuffie né altoparlanti esterni collegati. Quando è attivo, l'altoparlante del telefono funge da ripiego. Attivalo per un ascolto informale in casa; sul campo lascialo disattivato per escludere qualsiasi ritorno acustico nel microfono.
- **Silenzia il microfono mentre parla** — Sostituisce l'audio in ingresso con silenzio mentre l'app parla, così l'uscita dell'altoparlante non può essere captata dal microfono e rilevata di nuovo. Fortemente consigliato (e predefinito). Disattivalo solo se il tuo microfono è isolato acusticamente dall'altoparlante del telefono, ad esempio un microfono a clip su un altro cavo o un auricolare Bluetooth.
- **Abbassa gli altri audio** — Riduce brevemente il volume di musica o podcast di altre app durante l'annuncio e lo ripristina dopo. Attivo per impostazione predefinita. Se disattivato, la riproduzione prosegue a volume pieno.
- **Tono prima di parlare** — Riproduce un tono breve e discreto prima di ogni pronuncia, così l'orecchio ha un istante per passare dall'ascolto passivo all'attenzione verso la voce. Attivo per impostazione predefinita. Particolarmente utile quando gli annunci sono radi o c'è musica di sottofondo.
- **Cosa annunciare** — Sceglie quali rilevazioni siano idonee a un annuncio. *Ogni rilevazione* (predefinito) lascia decidere alla limitazione. *Prima volta per Session* annuncia una specie solo alla sua prima comparsa nella Session corrente. *Solo lista di controllo* limita gli annunci alle specie della tua lista (utile in rilievi mirati, dove vuoi sentire solo i taxa prioritari e nient'altro).

## Registrazione

### Modalità

- **Completa** — salva l'intera registrazione
- **Solo rilevazioni** — salva spezzoni attorno alle rilevazioni
- **Disattivata** — nessuna registrazione audio

### Contesto dello spezzone

Quando **Solo rilevazioni** è attivo, l'app mostra un unico cursore **Contesto dello spezzone** (0–5 s) che stabilisce quanto audio venga conservato su **entrambi i lati** di ogni rilevazione. Ogni spezzone dura `finestra di analisi + 2 × contesto dello spezzone`, quindi con una finestra di analisi di 3 s e il contesto predefinito di 1 s lo spezzone salvato è di 5 s. Impostando il contesto a 2 s si ottiene uno spezzone di 7 s (2 s prima + 3 s di audio analizzato + 2 s dopo). Valori più alti danno più margine per l'ispezione visiva o per strumenti di revisione esterni, a scapito dello spazio su disco; 0 salva solo la finestra analizzata.

### Formato

Scegli **WAV** o **FLAC**. WAV occupa di più, ma è ampiamente compatibile e rapido da ispezionare. FLAC mantiene la stessa qualità audio senza perdita occupando meno spazio, cosa di solito preferibile per Session lunghe.

Questa impostazione riguarda l'audio registrato da BirdNET Live. L'**Analisi file** conserva una copia gestita dall'app del file importato nel formato originale, così i file MP3, AAC, WAV e FLAC restano consultabili senza un ulteriore passaggio di conversione.

### Avvia la registrazione automaticamente (solo modalità Live)

Una volta attivo, la modalità Live inizia a registrare appena la schermata si apre e il modello finisce di caricarsi, senza dover toccare il pulsante del microfono. Utile per installazioni tipo chiosco, uso a mani libere (ad esempio il dispositivo montato sul campo) o qualunque flusso in cui aprire Live significhi già «si comincia adesso». Disattivato per impostazione predefinita, così un tocco accidentale sul riquadro Live nella schermata iniziale non avvia silenziosamente una Session. L'avvio automatico scatta una sola volta per visita alla schermata, quindi arrestare una Session e toccare di nuovo il microfono continua a funzionare come riavvio manuale.

Questa impostazione riguarda l'apertura della modalità Live dall'interno dell'app. Il [widget Quick Listen](live-mode.md) inizia ad ascoltare quando lo tocchi, qualunque sia questa impostazione, e non la modifica. Se una Session di Point Count, Survey, Analisi file o modalità ARU è già in corso o in avvio, quella Session viene preservata e ti viene chiesto di arrestarla prima.

### Salva automaticamente le Sessions (Live e Point Count)

Una volta attivo (impostazione predefinita), una Session Live o Point Count completata viene aggiunta automaticamente alla tua libreria nel momento in cui termina. Se disattivato, una Session conclusa si apre nel riepilogo contrassegnata come **non salvata**: l'icona di salvataggio è evidenziata e devi toccarla per conservare la Session. Uscire dal riepilogo senza salvare elimina la Session e le sue registrazioni. È adatto agli ascolti rapidi, in cui vuoi conservare solo l'occasionale risultato interessante invece di accumulare ogni breve registrazione. I deployment Survey e ARU salvano sempre automaticamente — un'esecuzione lunga e non presidiata è troppo preziosa per perderla dimenticando di toccare Salva — quindi lì questo interruttore non si applica.

## Riproduzione

### Overlay di riproduzione nel riepilogo

Una volta attivo (impostazione predefinita), ascoltare uno spezzone audio in un riepilogo di Session composta solo da spezzoni (dove non è disponibile una registrazione completa né lo spettrogramma) apre un overlay modale di riproduzione dedicato, con controlli di trasporto e anteprima dello spettrogramma, invece di riprodurre lo spezzone in sottofondo. Se una Session ha l'audio completo, questa impostazione viene ignorata e l'overlay di riproduzione non compare mai.

### Riproduci automaticamente i memo vocali

Disattivato per impostazione predefinita. Una volta attivo, un memo vocale allegato a un'annotazione con marca temporale viene riprodotto automaticamente durante il Riepilogo sessione nel momento in cui il cursore di riproduzione supera la posizione registrata. Il memo viene miscelato sopra la registrazione anziché metterla in pausa, così senti il tuo commento nel contesto insieme all'audio originale. Lascialo disattivato se preferisci avviare i memo manualmente toccando la relativa etichetta di annotazione.

### Attenuazione con i memo vocali

Mostrato solo quando **Riproduci automaticamente i memo vocali** è attivo. Controlla quanto viene abbassata la registrazione principale durante la riproduzione di un memo vocale automatico. Valori più alti rendono i memo più comprensibili; valori più bassi lasciano udire di più della registrazione originale sotto il memo.

## Posizione

### Usa il GPS

Usa il GPS del dispositivo invece delle coordinate inserite manualmente. Su
Android le posizioni provengono dal fornitore di localizzazione della
piattaforma e non dai servizi Google Play, quindi l'app non attiva la finestra
di Google sulla precisione della posizione. Con questa opzione disattivata,
l'app non legge mai il GPS di propria iniziativa né chiede l'autorizzazione
alla posizione: le procedure guidate di Survey, Point Count e ARU si aprono
sull'inserimento manuale con le coordinate salvate, il tracciamento GPS del
rilievo non viene eseguito e anche la preparazione delle mappe offline si
centra su quelle coordinate.

### Coordinate manuali

Le coordinate usate quando **Usa il GPS** è disattivato. Sia la latitudine sia la longitudine sono campi di testo modificabili, quindi puoi **digitare** un valore esatto o **incollarne** uno copiato da un'altra app: molto più preciso che trascinare un cursore su uno schermo tattile. Inserisci gradi decimali (ad esempio `52.5200` e `13.4050`). Puoi anche incollare una stringa combinata `latitudine, longitudine` (separata da virgola, punto e virgola o spazio) in *uno qualsiasi* dei due campi e si compilano entrambi in un colpo solo, il che corrisponde a ciò che la maggior parte di mappe e siti web mette negli appunti. I valori fuori intervallo o non numerici vengono segnalati sul posto e non salvati; i valori validi restano mentre digiti. L'intuizione: il motivo più comune per impostare una posizione manuale è identificare un suono registrato altrove rispetto a dove sei ora, e quella posizione di solito arriva come testo da un'altra fonte: digitare e incollare la trasformano in un unico passaggio preciso. Se preferisci indicare un punto invece di digitare numeri, **Scegli sulla mappa** apre lo stesso selettore di mappa a schermo intero usato nelle schermate di configurazione, inizializzato con le coordinate correnti, e compila entrambi i campi con il punto che tocchi.

### Aggiorna il GPS adesso

Forza una nuova localizzazione invece di riutilizzare l'ultimo valore memorizzato nella cache dall'app. L'intuizione: le richieste GPS vengono memorizzate in cache per singola schermata, così una schermata di configurazione non deve attendere un fix satellitare a ogni apertura, ma quella cache può essere vecchia di chilometri se dall'ultima Session ti sei spostato in un posto nuovo. Toccalo quando ti sei spostato e vuoi che il geofiltro usi *qui*, e non il punto in cui è iniziata la tua mattinata. Le coordinate correnti in cache sono indicate nel sottotitolo, così puoi verificare dove l'app pensa che tu sia. Se il GPS non ottiene un fix entro circa 10 secondi, l'app ripiega sull'ultima posizione nota fornita dal sistema operativo e ti avvisa con una SnackBar, così sai che il valore è obsoleto.

### Download di mappe offline

I download di mappe offline sono attualmente nascosti finché BirdNET Live usa il servizio pubblico di tasselli di OpenStreetMap. OpenStreetMap consente la normale navigazione interattiva delle mappe con attribuzione, uno user agent chiaro e cache locale, ma non permette il prelievo massivo anticipato né funzioni di download di mappe offline da `tile.openstreetmap.org`. L'implementazione del downloader viene mantenuta in vista di una futura sorgente di tasselli che consenta esplicitamente i pacchetti offline.

### Filtro specie

- **Disattivato** — nessun filtro geografico
- **Filtro per posizione** — escludi le specie sotto la soglia geografica
- **Ponderazione per posizione** — usa il geo-modello come segnale di ponderazione aggiuntivo

### Soglia del geo-filtro

Compare quando è attiva una modalità di filtro basata sulla posizione.

## Esportazione e sincronizzazione

### Formati

Spunta qualsiasi combinazione di formati di esportazione: ogni salvataggio o condivisione raccoglierà tutti i formati selezionati insieme in un unico ZIP. Scegliendo un solo formato senza spezzoni audio e senza report HTML otterrai un file grezzo (ad esempio `session.csv`) invece di uno ZIP, per compatibilità con le versioni precedenti:

- Raven Selection Table — per l'uso in Cornell Raven Pro.
- CSV — si apre in qualsiasi foglio di calcolo.
- JSON — il più comodo per l'elaborazione programmatica; contiene tutti i metadati della Session.
- GPX — traccia e waypoint per gli strumenti cartografici (ha senso solo se il GPS era attivo).

L'intuizione: molti flussi di lavoro richiedono più di un formato alla volta — un CSV per il foglio di calcolo, una tabella Raven per chi rivede al computer e un JSON per lo script di analisi. Districare tutto questo con un selettore a formato singolo significava, un tempo, esportare tre volte la stessa Session. Ora ne spunti tre in una volta e viaggiano insieme nello ZIP.

### Includi i file audio

Includi l'audio salvato accanto alle tabelle o ai metadati esportati, quando il flusso di esportazione lo supporta. Anche la condivisione di una singola rilevazione segue questa impostazione: una registrazione Session completa viene ritagliata alle marche temporali esatte di inizio e fine della rilevazione, mentre una Session con sole rilevazioni usa il suo clip conservato.

### Condividi sempre l'audio come WAV

Mostrato solo quando **Includi i file audio** è attivo. Una volta attivo, le registrazioni FLAC vengono convertite in WAV prima della condivisione o dell'esportazione. WAV è universalmente compatibile ma nettamente più grande di FLAC, quindi lascialo disattivato a meno che lo strumento a destinazione non sappia leggere il FLAC: alcuni software di analisi desktop più datati e qualche modulo di caricamento ancora non ci riescono.

### Includi i metadati dell'app

Una volta attivo, lo ZIP di esportazione contiene un file di corredo `*.metadata.json` che descrive come è stata prodotta la Session: versione di BirdNET Live, identità del modello, l'istantanea meteo acquisita all'inizio della Session e qualsiasi avviso sull'integrità dell'audio rilevato durante la registrazione. L'intuizione: è proprio questa tracciabilità a permettere a te (o a chi rivede) di riprodurre o verificare una Session mesi dopo. Disattivali quando vuoi condividere in modo pulito solo l'audio e i formati scelti, ad esempio caricare un singolo WAV su iNaturalist o eBird senza file specifici dell'app al seguito.

### Includi il report HTML

Una volta attivo, ogni ZIP di esportazione contiene anche un file `<session>_report.html` accanto alla tabella, agli spezzoni audio e al GPX. Aprilo in un qualsiasi browser e ottieni un riepilogo della Session pronto per la stampa: scheda di intestazione con data, luogo, osservatore e totali; una mappa interattiva della traccia GPS e dei marcatori di rilevazione; una scheda per ogni rilevazione con la miniatura della tassonomia Cornell, i nomi, l'etichetta del punteggio, la tua conferma, l'eventuale nota che hai scritto e lo spezzone audio originale in un lettore integrato; oltre alle impostazioni di analisi usate. L'intuizione: un CSV è ottimo per le pipeline di analisi ma inutile per condividere con un collaboratore non tecnico o per stampare un breve riepilogo di campo: il report HTML colma questa lacuna con un tocco. Le miniature delle specie e i tasselli della mappa richiedono una connessione alla prima apertura del file (vengono caricati in diretta dall'API di tassonomia di BirdNET e da OpenStreetMap), ma tutto il resto — testo, impaginazione, riproduzione audio, collegamenti — funziona interamente offline. Disattivalo se ti servono solo i dati grezzi e vuoi uno ZIP più leggero di qualche KB.

### Condivisione del solo audio

Togli la spunta a ogni formato **e** al report HTML **e** alla casella dei metadati dell'app, lasciando solo **Includi i file audio**: Condividi consegnerà al pannello di sistema la registrazione grezza (ad esempio `BirdNET_Live_…flac`) invece di uno ZIP. È la via più semplice per inviare una Session direttamente a iNaturalist, eBird o qualsiasi altra app che si aspetti un file audio non impacchettato. Le Sessions con più spezzoni di rilevazione producono comunque uno ZIP; condividendo una sola rilevazione viene consegnato quell'unico clip grezzo.

## Privacy

Questa sezione stabilisce **quali servizi di terze parti BirdNET Live può contattare per tuo conto**. L'inferenza vera e propria viene eseguita interamente sul tuo dispositivo: questi interruttori regolano solo funzioni di rete facoltative che arricchiscono l'esperienza. Su un'installazione nuova tutti e tre gli interruttori sono **disattivati per impostazione predefinita**; nulla esce finché non lo consenti. L'intuizione: ogni interruttore è circoscritto a un servizio concreto e a un beneficio concreto, così puoi attivare esattamente ciò che è utile al tuo lavoro e nient'altro.

### Consenti i tasselli della mappa

Necessario per qualsiasi mappa interattiva nell'app (il selettore di posizione, la mappa dal vivo di Survey e la mappa della Session). Una volta attivo, i componenti mappa scaricano tasselli raster dai server pubblici di **OpenStreetMap**; le richieste delle coordinate dei tasselli rivelano quale area del mondo stai guardando. I tasselli vengono memorizzati localmente in cache fino a sei mesi, con un tetto di 6000 tasselli, così le visualizzazioni ripetute restano efficienti senza crescere all'infinito. Attivarlo abilita anche **Consenti la ricerca dei nomi dei luoghi**, perché la maggior parte di chi carica le mappe si aspetta che le Sessions mostrino anche nomi di luogo leggibili. Puoi poi disattivare separatamente la ricerca dei nomi dei luoghi. Quando i tasselli sono disattivati, ogni schermata con mappa ripiega su una scheda segnaposto, così il resto dell'app continua a funzionare senza fughe verso la rete.

### Consenti la ricerca dei nomi dei luoghi

Una volta attivo, l'app invia le coordinate registrate al servizio **Nominatim di OpenStreetMap** per ricavare un nome di luogo breve (ad esempio *«Berlino, Germania»*), mostrato accanto alla Session nella Libreria delle sessioni e nel Riepilogo sessione. L'intuizione: le coordinate numeriche sono precise ma difficili da leggere a colpo d'occhio scorrendo un lungo elenco di Sessions; un nome di luogo rende l'elenco leggibile in un istante. Se disattivato, le Sessions mostrano solo latitudine e longitudine grezze e Nominatim non viene mai contattato.

### Consenti la consultazione meteo

Una volta attivo, ogni Session salvata acquisisce tramite **Open-Meteo** un'istantanea una tantum delle condizioni locali (temperatura, precipitazioni, vento, nuvolosità) alle coordinate di registrazione e all'orario di fine. L'istantanea compare nel Riepilogo sessione sotto la riga della posizione e viene riportata nell'esportazione JSON, nel blocco di metadati della Session e nel report HTML. L'intuizione: il meteo è uno dei predittori più forti dell'attività degli uccelli, e catturarlo automaticamente — senza doverti ricordare di consultare un'altra app — rende ogni Session un documento più completo. Open-Meteo è un servizio gratuito e non richiede né account né chiave API. Se disattivato, non viene recuperato né conservato alcun dato meteo. Anche la configurazione di Point Count e Survey mostra una scheda meteo compatta vicino ai controlli di posizione: chiede questo consenso solo quando serve, una volta abilitata mostra l'anteprima come icona + temperatura + vento e riutilizza la stessa istantanea in cache al salvataggio della Session.

## Informazioni

La riga **Informazioni** apre la schermata informativa all'interno dell'app.

## Zona pericolosa

### Reimposta l'introduzione

Mostra di nuovo la sequenza introduttiva al successivo avvio dell'app.

### Reimposta tutte le impostazioni

Riporta ogni preferenza di questa schermata al valore predefinito. Sessions, registrazioni, memo vocali, esportazioni e tasselli della mappa in cache restano intatti: vengono cancellate solo le preferenze salvate (cursori, interruttori, scelte dei selettori). Dopo la conferma l'app si chiude, così i nuovi valori predefiniti hanno effetto al prossimo avvio.

Utile quando non sei sicuro di quale cursore hai spostato rompendo qualcosa, o quando consegni il dispositivo a un'altra persona e vuoi una configurazione pulita senza perdere i dati raccolti.

### Cancella tutti i dati

Elimina definitivamente Sessions, rilevazioni, registrazioni, memo vocali, elenchi di specie personalizzati, preferenze salvate e i dati in cache di mappe, nomi dei luoghi, meteo, riproduzione, riepilogo e condivisione. La finestra di conferma richiede di digitare `DELETE` e poi chiude l'app, così il prossimo avvio riparte da uno stato locale pulito.

Usalo prima di consegnare un dispositivo a un altro osservatore, di dismettere un telefono da campo o di rimuovere dall'app la cronologia legata alla posizione. Esporta prima tutto ciò che ti serve; questa azione non è reversibile.

## Parametri specifici del flusso fuori dalle Impostazioni

Alcuni parametri si configurano nelle rispettive schermate di configurazione anziché nella schermata Impostazioni condivisa.

- [Modalità Point Count](point-count-mode.md) ha una propria configurazione di durata e posizione.
- [Modalità Survey](survey-mode.md) ha una propria schermata di parametri del rilievo.
- [Analisi file](file-analysis.md) ha un proprio passaggio dei parametri di analisi.
