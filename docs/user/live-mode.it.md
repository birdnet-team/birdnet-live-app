# Modalità Live

La modalità Live è il modo più veloce per ascoltare tramite il microfono del telefono ed esaminare le rilevazioni man mano che appaiono in tempo reale.

## Come aprirla

Dalla schermata Home, tocca la scheda **Modalità Live** con l'icona :app-micRounded:.

## Widget «Ascolto rapido»

**Solo Android.** Un widget nella schermata Home avvia l'ascolto con un solo tocco, senza dover prima aprire l'app e navigare fino alla modalità — comodo quando senti qualcosa che vuoi identificare prima che smetta di cantare.

Si aggiunge come qualsiasi altro widget: tieni premuto uno spazio libero della schermata Home, tocca **Widget**, cerca **BirdNET Live** e trascina fuori uno dei due riquadri.

- **Ascolto rapido** (2×1) — icona con l'etichetta **Avvia ascolto**
- **Ascolto rapido (compatto)** (1×1) — solo icona

Fanno la stessa cosa. Toccando l'uno o l'altro si apre la modalità Live e l'ascolto parte subito, qualunque sia il valore dell'impostazione **Avvia registrazione automaticamente**. Il widget non modifica quell'impostazione.

Se la modalità Live è già aperta, il widget torna alla stessa schermata invece di ricrearla. Una Session in corso o in pausa continua senza modifiche; se è ferma, l'ascolto parte nella schermata esistente.

Ascolto rapido non sostituisce mai un'altra modalità in esecuzione. Se una Session Point Count, Survey, File Analysis o [modalità ARU](aru-mode.md) è in corso o si sta avviando, l'app torna in primo piano e chiede di interrompere prima quella Session. La schermata e il lavoro restano accessibili e non vengono interrotti.

## Barra superiore

La barra superiore contiene tre elementi:

- :app-arrowBackRounded: — esce dalla modalità Live
- testo di stato al centro — `Inizializzazione…`, `Caricamento modello…`, `Pronto`, `Identificazione delle specie…`, `In pausa` o `Errore`
- :app-tuneRounded: — apre la vista Impostazioni specifica di Live

## Pulsante di azione principale

Il grande pulsante circolare in basso al centro cambia stato:

- :app-mic: — avvia l'ascolto
- :app-stopRounded: — interrompe la Session attiva
- :app-playArrowRounded: — riprende da uno stato in pausa pronto a partire

## Cosa vedi durante l'ascolto

### Spettrogramma

Lo spettrogramma scorre continuamente mentre la cattura è attiva. Mostra il contenuto in frequenza nel tempo, usando la mappa colori, la dimensione FFT, l'intervallo di frequenza e la durata configurati nelle Impostazioni.

### Elenco delle rilevazioni

Le rilevazioni recenti compaiono sotto lo spettrogramma. Ogni riga può mostrare:

- immagine della specie
- nome comune
- nome scientifico facoltativo
- valore di confidenza

Tocca la riga di una specie per aprire il pannello dei dettagli della specie.

### Barra informativa della Session

La riga informativa compatta sotto lo spettrogramma riassume la Session corrente, ad esempio:

- rilevazioni attualmente visibili
- numero di specie uniche (`spp`)
- rilevazioni totali (`det`)
- durata trascorsa
- dimensione stimata della registrazione quando la registrazione è attiva

## Comportamento della registrazione

La registrazione si controlla in [Impostazioni](settings.md).

- **Completa** registra l'intera Session.
- **Solo rilevazioni** registra clip attorno alle rilevazioni.
- **Disattivata** disabilita la registrazione.

Quando interrompi la modalità Live, BirdNET Live salva la Session e apre il [Riepilogo sessione](session-review.md).

Quando il salvataggio automatico delle Session è attivo, la modalità Live salva anche una Session parziale all'avvio, ogni 30 secondi e quando l'app passa in background. Dopo un arresto anomalo o un'interruzione di corrente, l'ultimo salvataggio è disponibile nella Libreria Sessions. Le modifiche successive a quel salvataggio possono andare perse. Disattivando il salvataggio automatico si disattivano anche questi salvataggi intermedi.

## Ascolto a schermo spento

Live Mode normalmente si mette in pausa quando blocchi lo schermo o lasci l’app e riprende la stessa Session al ritorno. La prima volta, un dialogo propone l’ascolto limitato in background. Nelle [impostazioni di registrazione](settings.md), attiva **Continua a schermo spento** e scegli un massimo di 15, 30, 60 o 120 minuti (30 predefiniti). Il limite si applica a ogni periodo fuori dall’app; raggiungerlo termina la Session. Android mostra una notifica persistente con Apri e Interrompi. Su Windows, Live Mode continua ad ascoltare con la finestra ridotta a icona.
