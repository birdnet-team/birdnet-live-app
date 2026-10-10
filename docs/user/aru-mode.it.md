# Modalità ARU

!!! note "Implementazione iniziale"
    La modalità ARU attualmente salva checkpoint della distribuzione programmata, registra i cicli pianificati, esegue l'inferenza live durante i cicli attivi, salva i clip di rilevazione conservati quando è selezionata quella modalità di registrazione e mostra i controlli di notifica in primo piano su Android. Il comportamento in background su iOS deve ancora essere validato sul campo.

La modalità ARU (Autonomous Recording Unit) è il flusso di lavoro per distribuzioni acustiche programmate in una posizione fissa.

## Flusso di configurazione attuale

- **Dettagli e impostazioni di analisi**:
    - **Metadati**: inserisci il nome della distribuzione, l'ID ARU/stazione e il nome dell'osservatore.
    - **Posizione**: fornisci le coordinate del sito tramite acquisizione automatica del GPS, immissione manuale di latitudine/longitudine o salta l'impostazione della posizione. La latitudine e la longitudine sono richieste se utilizzi la pianificazione vincolata al sole. Icone: GPS :app-myLocation:, coordinate manuali :app-editLocationAlt:, salta posizione :app-locationOff: e selettore sulla mappa :app-mapSheet:.
    - **Analisi**: Scegli microfono, frequenza di inferenza, soglia di confidenza e sensibilità.
    - **Formato di registrazione**: scegli tra i formati FLAC (compresso senza perdita) e WAV (non compresso).
    - **Modalità di registrazione**:
        - *Completa*: registra l'intera durata di ciascun ciclo attivo.
        - *Solo rilevazioni*: salva brevi clip audio attorno ai canti degli uccelli rilevati. Puoi personalizzare il contesto del clip (aggiungendo da 0 a 5 secondi di buffer audio prima e dopo la rilevazione) e scegliere il metodo di campionamento (*Tutte*, *Top N* o campionamento *Smart* per limitare l'uso della memoria).
        - *Disattivato*: esegue l'inferenza in tempo reale durante i cicli e registra le rilevazioni, ma non salva file audio.
- **Pianificazione (Programma)**:
    - **Durata e ripetizione**: seleziona la durata di ciascun ciclo di registrazione attivo e la frequenza di ripetizione.
    - **Finestra di registrazione (modello diel)**: scegli di registrare 24 ore su 24 (*In qualsiasi momento*) o limita i cicli a *Solo giorno*, *Solo notte* o a intervalli specifici *Intorno all'alba*, *Intorno al tramonto* o *Intorno all'alba e al tramonto*. Gli intervalli di alba/tramonto vengono calcolati in modo dinamico in base alle coordinate della distribuzione.
    - **Fine pianificazione**: scegli se arrestare la distribuzione manualmente, dopo un numero fisso di cicli completati o automaticamente a una data e ora specificate.
    - **Gestione della batteria**: imposta una soglia di arresto per batteria scarica (0-50%) per mettere in pausa la distribuzione ed evitare lo scaricamento completo della batteria. Se configurata, puoi impostare una soglia di riattivazione per riprendere automaticamente i cicli di registrazione quando il livello della batteria si ripristina (ad esempio, tramite ricarica solare).
    - **Ciclo di test**: un ciclo di prova facoltativo di un minuto è abilitato per impostazione predefinita per verificare l'ingresso del microfono e l'inferenza subito all'avvio, senza contare ai fini del limite dei cicli pianificati.
    - **Raggruppamento Session**: configura se salvare ogni ciclo come una Session separata (consigliato per tempi di caricamento più rapidi e visualizzazione modulare) o combinare tutti i cicli in un'unica Session a segmenti multipli.
- **Pronto**: verifica il programma, la stima del consumo di memoria audio e i vincoli legati al sole, quindi avvia la distribuzione.

I controlli di configurazione usano le stesse icone delle altre procedure guidate: :app-micRounded: microfono, :app-speedRounded: frequenza di inferenza, :app-verifiedRounded: confidenza, :app-hearing: sensibilità, :app-fiberManualRecordRounded: modalità di registrazione, :app-timerOutlined: contesto del clip e durata del ciclo, :app-filterAltRounded: campionamento delle rilevazioni e :app-formatListNumberedRounded: limite di clip per specie. L'intervallo di ripetizione usa :app-repeatRounded:, i controlli della batteria scarica :app-batteryAlert: e :app-batteryChargingFull:, il test e il raggruppamento delle Session :app-scienceRounded: e :app-libraryBooks:. Tocca il pulsante :app-helpOutline: accanto a un controllo per leggerne la spiegazione.

All'avvio viene salvata subito una Session `SessionType.aru` con metadati del programma ARU. Inoltre i cicli di registrazione vengono salvati ogni 30 secondi, anche quelli senza rilevazioni. Dopo un arresto anomalo o un'interruzione di corrente, l'ultima distribuzione parziale compare nella Libreria Sessions come Session terminata; la registrazione non riparte. Quanto registrato dopo l'ultimo salvataggio può andare perso.

Le esportazioni JSON e ZIP includono i metadati della distribuzione ARU. Le esportazioni ZIP raggruppano i file di registrazione salvati per ciclo sotto `aru_cycles/`.

## Schermata di distribuzione attiva

La schermata ARU attiva mostra se la distribuzione è in attesa, in registrazione o completata. Il layout usa quattro schede:
- **Stato**: mostra lo stato attuale della distribuzione, il timer della pianificazione attiva e un elenco delle rilevazioni in tempo reale.
- **Audio**: mostra uno spettrogramma in tempo reale per verificare l'ingresso audio, mantenendo visibili le rilevazioni sotto.
- **Pianificazione**: elenca i prossimi 10 cicli pianificati, indicando gli allineamenti alba/tramonto se sono attivi vincoli diel.
- **Riepilogo**: riassume il tempo trascorso, la durata totale dell'audio registrato e le statistiche delle rilevazioni.

Su Android, le distribuzioni attive mostrano una notifica in primo piano con azioni Interrompi e Apri.

Interrompere una distribuzione apre la Revisione Session. Se i cicli sono stati raggruppati in un'unica Session, viene aperta quella Session combinata; se salvati come Session separate, si apre l'ultima Session di ciclo completata.

Su iOS, questa implementazione iniziale deve essere trattata come un flusso di lavoro in primo piano finché il comportamento di audio/background pianificato non sia stato validato su iOS.

## Ancora pianificato

- Validazione del comportamento in background su iOS.
- Supporto completo per riproduzione e spettrogramma in Session Review per le registrazioni ARU segmentate.
