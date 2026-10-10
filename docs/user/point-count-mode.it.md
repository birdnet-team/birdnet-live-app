# Modalità Point Count

La modalità Point Count è il flusso di lavoro stazionario a tempo di BirdNET Live.

## Come aprirla

Dalla Home, tocca la scheda **Modalità Point Count** con l'icona :app-locationOnRounded:.

## Flusso di configurazione

La configurazione del Point Count si articola in quattro passaggi.

### 1. Durata e posizione

Scegli:

- una delle durate disponibili: 3, 5, 10, 15, 20, 25 o 30 minuti
- se il conteggio continua a schermo spento (attivo per impostazione predefinita)
- GPS attuale con :app-myLocation:
- coordinate manuali con :app-editLocationAlt:
- nessuna posizione con :app-locationOff:
- selettore sulla mappa con :app-mapSheet:

La schermata di configurazione aggiorna il GPS quando torni dalla finestra di
autorizzazione di sistema o dalle impostazioni dell'app, così un'autorizzazione
alla posizione appena concessa dovrebbe aggiornare le coordinate senza riavviare
la procedura guidata. La stessa sezione include anche una scheda meteo. Se
l'accesso al meteo è disattivato, la scheda chiede il consenso **Consenti
ricerca meteo**; una volta abilitato, mostra un'anteprima del sito con un'icona
meteo, solo temperatura e vento. Lo stesso snapshot di Open-Meteo memorizzato
nella cache viene riutilizzato quando il Point Count viene salvato.

### 2. Parametri di inferenza

Scegli impostazioni di analisi specifiche per la Session, come frequenza di inferenza, soglia di confidenza e modalità del filtro
specie. Partono dalle tue impostazioni globali, ma possono essere regolate per
questo conteggio senza modificare i valori predefiniti.

| Controllo di configurazione | Icona |
|---|---|
| Microfono | :app-micRounded: |
| Modalità di registrazione | :app-fiberManualRecordRounded: |
| Contesto del clip | :app-timerOutlined: |
| Frequenza di inferenza | :app-speedRounded: |
| Soglia di confidenza | :app-verifiedRounded: |
| Sensibilità | :app-hearing: |
| Filtro specie | :app-filterAltRounded: |

Il pulsante :app-helpOutline: accanto a ogni controllo ne spiega l'effetto. Il controllo della durata :app-timerRounded: e il selettore della posizione hanno lo stesso pulsante di aiuto nel primo passaggio.

Scegli **Completa** per salvare audio continuo (predefinito), **Solo clip** per salvare uno spezzone per ogni vocalizzazione rilevata o **Disattivata** per non salvare audio. Questa scelta è indipendente dalla registrazione di Live Mode e viene ricordata per il prossimo Point Count. Gli spezzoni usano la stessa selezione della finestra con il punteggio massimo e lo stesso contesto di Live Mode, senza riduzione basata sulla posizione. Con **Solo clip**, il cursore **Contesto clip** imposta i secondi conservati prima e dopo ogni finestra analizzata; aggiorna anche il contesto di Live Mode.

### 3. Consigli sul campo

Questa schermata presenta una breve lista di controllo in-app da seguire prima di iniziare.

### 4. Pronto

La schermata di pronto riassume durata, scelta di registrazione e comportamento a schermo spento. Avvia con :app-playArrowRounded:.

## Schermata del Point Count in tempo reale

La schermata del Point Count in tempo reale è incentrata su una dashboard a tempo.

### Barra superiore

- :app-stopRounded: — termina il Point Count in anticipo
- :app-timerRounded: — mostra il tempo rimanente
- :app-helpOutlineRounded: — apre l'aiuto di Point Count
- :app-tuneRounded: — apre le impostazioni Point Count

### Indicatori principali

- barra di avanzamento del conto alla rovescia
- barra informativa compatta con rilevazioni attuali, numero di specie uniche e rilevazioni totali
- vista dello spettrogramma
- elenco delle rilevazioni

## Dopo il conteggio

Con **Continua a schermo spento** attivo nella configurazione di Point Count, il conteggio continua quando blocchi lo schermo o passi a un’altra app, anche con lo schermo acceso. Termina alla durata scelta; il conto alla rovescia usa il tempo realmente trascorso, quindi una schermata sospesa non prolunga il conteggio. Android mostra una notifica persistente con Apri e Interrompi. Disattiva l’interruttore per terminare prima con queste azioni. Point Count non si mette in pausa per poi riprendere, perché interromperebbe il conteggio a tempo. Se esci durante l’avvio, viene annullato con un messaggio; configuralo di nuovo. Su Windows, ridurre a icona non termina il conteggio.

Al termine del Point Count, BirdNET Live apre [Riepilogo sessione](session-review.md). Se il salvataggio automatico è attivo, salva la Session automaticamente; altrimenti salvala dal riepilogo per conservarla.

Con il salvataggio automatico attivo, un conteggio non concluso viene salvato anche all'avvio, ogni 30 secondi e quando l'app lascia il primo piano. Dopo un arresto anomalo o un'interruzione di corrente, l'ultimo conteggio parziale è disponibile nella Libreria Sessions.
