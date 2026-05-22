# Impostazioni

BirdNET Live riutilizza una schermata Impostazioni su più flussi di lavoro. Il pulsante :material-tune: apre le sezioni rilevanti per la schermata da cui provieni.

## Come funziona l'ambito delle impostazioni

- L'apertura delle Impostazioni da Home mostra lo schermo intero.
- L'apertura delle Impostazioni da Live, Sondaggio, Conteggio punti o Analisi file filtra la schermata nelle sezioni pertinenti.

## Generale

### Tema

Scegli **Scuro**, **Chiaro** o **Sistema**.

### Lingua dell'app

Imposta la lingua dell'interfaccia.

### Nomi delle specie

Controlla la lingua utilizzata per i nomi delle specie. **Segui la lingua dell'app** utilizza la stessa lingua dell'interfaccia quando quel nome è disponibile.

### Mostra nomi scientifici

Mostra i nomi scientifici sotto i nomi comuni nell'app.

### Visualizzazione degli orari

Controlla come compaiono gli orari delle singole rilevazioni nella revisione di sessione.

- **Relativo** mostra l'offset dall'inizio della registrazione, es. `00:12:34`. Utile per esaminare una singola sessione e allinearsi allo spettrogramma.
- **Assoluto** mostra l'orario locale di cattura della rilevazione, es. `08:42:17`. Utile per incrociare note di campo, registri meteo o registrazioni simultanee.

Se una rilevazione cade in un giorno di calendario diverso da quello d'inizio sessione (es. un monitoraggio notturno), l'orario assoluto riceve il suffisso `+1d` per evitare che l'alba di domani venga scambiata per quella di oggi.

Quando è selezionata **Assoluta**, compare anche l'interruttore **Mostra i secondi negli orari**. Disattivalo se preferisci il formato più compatto `08:42` rispetto a `08:42:17` — utile quando si scorrono lunghi elenchi di rilevazioni. Gli scostamenti relativi mostrano sempre i secondi perché l'allineamento con lo spettrogramma richiede precisione sotto il minuto.

Quando è selezionata **Assoluta**, compare anche l'interruttore **Mostra i secondi negli orari**. Disattivalo se preferisci il formato più compatto `08:42` rispetto a `08:42:17` — utile quando si scorrono lunghi elenchi di rilevazioni. Gli scostamenti relativi mostrano sempre i secondi perché l'allineamento con lo spettrogramma richiede precisione sotto il minuto.

Archiviazione ed esportazioni usano sempre UTC indipendentemente da questa impostazione, perciò la scelta non altera mai i dati — solo la loro presentazione.

##Audio

Questi controlli vengono visualizzati nei flussi di lavoro live basati su audio.

### Guadagno

Regola il guadagno in ingresso mostrato nell'app. Utilizzatelo solo quando è necessario compensare registrazioni o ingressi molto silenziosi.

### Filtro passa-alto (Hz)

Riduce il rimbombo a bassa frequenza prima dell'inferenza.

### Microfono

Consente di scegliere un dispositivo di input specifico o di mantenere l'**impostazione predefinita del sistema**.

## Inferenza

### Durata della finestra

Controlla la lunghezza della finestra di analisi.

### Soglia di confidenza

Imposta il modo in cui dovrebbero essere conservativi i rilevamenti.

### Sensibilità

Valori più alti rendono il rilevatore più permissivo, che può recuperare le chiamate più deboli al costo di più falsi positivi.

### Tasso di inferenza

Controlla la frequenza con cui BirdNET esegue l'inferenza.

### Raggruppamento dei punteggi

Controlla il modo in cui vengono combinate le finestre di analisi sovrapposte.

## Spettrogramma

### Dimensione FFT

Controlla la risoluzione della frequenza nello spettrogramma.

### Mappa dei colori

Scegli **Viridis**, **Magma** o **Scala di grigi**.

### Durata (velocità di scorrimento)

Controlla quanto tempo è visibile nella finestra dello spettrogramma.

### Gamma di frequenza

Imposta la frequenza di visualizzazione superiore.

### Registra l'ampiezza

Applica la scala logaritmica allo spettrogramma per facilitare la lettura visiva.

## Registrazione

### Modalità

- **Completo**: salva l'intera registrazione
- **Solo rilevamenti**: salva clip relativi ai rilevamenti
- **Off**: nessuna registrazione audio

### Contesto della clip

Quando **Solo rilevamenti** è attivo, l'app mostra un singolo cursore **Contesto clip** (0-5 s) che imposta la quantità di audio da conservare su **entrambi i lati** di ciascun rilevamento. Ogni clip è lunga `finestra di analisi + 2 × contesto della clip`, quindi con una finestra di analisi di 3 s e il contesto predefinito di 1 s la clip salvata è di 5 s. Impostando il contesto su 2 s si ottiene una clip di 7 s (2 s di pre-roll + 3 s di audio analizzato + 2 s di post-roll). Valori più grandi offrono più spazio per l'ispezione visiva o per strumenti di revisione esterni a scapito dello spazio su disco; 0 salva solo la finestra analizzata stessa.

### Formato

Scegli **WAV** o **FLAC**.

## Posizione

### Usa il GPS

Utilizza il GPS del dispositivo invece delle coordinate manuali.

### Latitudine/longitudine

Coordinate manuali utilizzate quando il GPS è disabilitato.

### Filtro specie

- **Off**: nessun filtro geografico
- **Filtro posizione**: esclude le specie che ricadono al di sotto della soglia geografica
- **Ponderazione della posizione**: utilizza il modello geografico come segnale di ponderazione aggiuntivo

### Soglia del filtro geografico

Appare quando è attiva una modalità di filtro basata sulla posizione.

## Esporta e sincronizza

### Formati

Spunta qualsiasi combinazione di formati di esportazione: ogni salvataggio / condivisione raggrupperà tutti i formati selezionati in un unico ZIP. Se scegli un solo formato senza clip audio e senza report HTML, otterrai un file grezzo (es. `session.csv`) per retrocompatibilità:

- Tabella di selezione Raven — per Cornell Raven Pro.
- CSV — si apre in qualsiasi foglio di calcolo.
- JSON — ottimo per l'elaborazione programmatica; contiene i metadati completi della sessione.
- GPX — traccia e waypoint per app cartografiche (utile solo se il GPS era attivo).

L'intuizione: molti flussi di lavoro richiedono più formati contemporaneamente — un CSV per il foglio, una tabella Raven per il revisore desktop e un JSON per lo script di analisi. Prima bisognava esportare tre volte la stessa sessione; ora spunti tutti e tre una volta sola e viaggiano insieme nel ZIP.

### Include file audio

Includi l'audio salvato insieme alle tabelle o ai metadati esportati quando supportato dal flusso di lavoro di esportazione.

## Privacy

Questa sezione controlla **quali servizi di terze parti BirdNET Live può contattare per tuo conto**. L'inferenza viene eseguita interamente sul tuo dispositivo — questi interruttori governano solo funzionalità di rete opzionali. Tutti e tre gli interruttori sono **disattivati per impostazione predefinita** su una nuova installazione; nulla esce finché non lo autorizzi. L'intuizione: ogni interruttore copre un servizio concreto e un beneficio concreto, così attivi esattamente ciò che ti serve.

### Consenti tile della mappa

Richiesto per qualsiasi mappa interattiva (selettore di posizione, mappa live di Survey, mappa della sessione). Quando attivo, i widget mappa scaricano tile raster dai server pubblici **OpenStreetMap**; le richieste di coordinate dei tile rivelano quale area del mondo stai guardando. Quando disattivato, tutte le schermate di mappa mostrano un pannello segnaposto.

### Consenti ricerca nome luogo

Quando attivo, l'app invia le tue coordinate registrate al servizio **Nominatim** di OpenStreetMap per ottenere un breve nome di luogo (es. “Roma, Italia”) mostrato accanto alla sessione nella Libreria delle sessioni e nella Revisione della sessione. L'intuizione: le coordinate numeriche sono precise ma difficili da leggere in un lungo elenco; un nome di luogo lo rende leggibile a colpo d'occhio. Quando disattivato, vengono mostrate solo le coordinate grezze e Nominatim non viene mai contattato.

### Consenti ricerca meteo

Quando attivo, ogni sessione salvata cattura un'istantanea una tantum delle condizioni locali (temperatura, precipitazioni, vento, nuvolosità) alle coordinate di registrazione e all'ora di fine tramite **Open-Meteo**. L'istantanea compare nella Revisione della sessione sotto la riga della posizione e viene riportata nell'esportazione JSON, nel blocco metadati e nel report HTML. L'intuizione: il meteo è uno dei predittori più forti dell'attività degli uccelli, e catturarlo automaticamente trasforma ogni sessione in un documento più completo. Open-Meteo è gratuito e non richiede né account né chiave API. Quando disattivato, nessun dato meteo viene scaricato o salvato.

## Di

La riga **Informazioni** apre la schermata Informazioni nell'app.

## Zona pericolosa

### Reimposta l'onboarding

Mostra nuovamente la sequenza di onboarding al successivo avvio dell'app.

### Cancella tutti i dati

Elimina in modo permanente sessioni, rilevazioni, registrazioni, note vocali, liste specie personalizzate, preferenze salvate e dati cache di mappe, nomi di luoghi, meteo, riproduzione, revisione e condivisione. La finestra di conferma richiede di digitare `DELETE`, poi chiude l'app in modo che il prossimo avvio parta da uno stato locale pulito.

Usalo prima di consegnare un dispositivo a un'altra persona osservatrice, dismettere un telefono da campo o rimuovere dall'app cronologia collegata alla posizione. Esporta prima tutto ciò che vuoi conservare; questa azione non può essere annullata.

## Parametri specifici del flusso di lavoro esterni alle impostazioni

Alcuni parametri vengono configurati all'interno delle rispettive schermate di configurazione anziché nella schermata Impostazioni condivisa.

- La [Modalità conteggio punti](point-count-mode.md) ha la propria durata e impostazione della posizione.
- [Modalità sondaggio](survey-mode.md) dispone di una propria schermata dei parametri di sondaggio.
- [Analisi file](file-analysis.md) ha il proprio passaggio dei parametri di analisi.