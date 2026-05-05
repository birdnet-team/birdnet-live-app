# Impostazioni

BirdNET Live riutilizza una schermata Impostazioni su più flussi di lavoro. Il pulsante :material-tune: apre le sezioni rilevanti per la schermata da cui provieni.

## Come funziona l'ambito delle impostazioni

- L'apertura delle Impostazioni da Home mostra lo schermo intero.
- L'apertura delle Impostazioni da Live, Transetto, Conteggio a punto o Analisi file filtra la schermata nelle sezioni pertinenti.

## Generale

### Tema

Scegli **Scuro**, **Chiaro** o **Sistema**.

### Lingua dell'app

Imposta la lingua dell'interfaccia.

### Nomi delle specie

Controlla la lingua utilizzata per i nomi delle specie. **Segui la lingua dell'app** utilizza la stessa lingua dell'interfaccia quando quel nome è disponibile.

### Mostra nomi scientifici

Mostra i nomi scientifici sotto i nomi comuni nell'app.

## Audio

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

### Formato

Scegli una destinazione di esportazione:

- Tabella di selezione del corvo
-CSV
- JSON
- GPX (traccia + waypoint)

### Include file audio

Includi l'audio salvato insieme alle tabelle o ai metadati esportati quando supportato dal flusso di lavoro di esportazione.

## Di

La riga **Informazioni** apre la schermata Informazioni nell'app.

## Zona pericolosa

### Reimposta l'onboarding

Mostra nuovamente la sequenza di onboarding al successivo avvio dell'app.

### Cancella tutti i dati

Apre un flusso di conferma per la rimozione permanente dei dati dell'app archiviati.

## Parametri specifici del flusso di lavoro esterni alle impostazioni

Alcuni parametri vengono configurati all'interno delle rispettive schermate di configurazione anziché nella schermata Impostazioni condivisa.

- La [Conteggio a punto](point-count-mode.md) ha la propria durata e impostazione della posizione.
- [Transetto](survey-mode.md) dispone di una propria schermata dei parametri di sondaggio.
- [Analisi file](file-analysis.md) ha il proprio passaggio dei parametri di analisi.
