# Transetto

Il Transetto è il flusso di lavoro basato sul percorso per rilievi mobili di lunga durata.

## Come aprirlo

Da Home, tocca la scheda **Transetto** con l'icona :material-routes:.

## Flusso di configurazione

La configurazione del transetto è una procedura guidata in cinque passaggi.

### 1. Dettagli

Puoi inserire:

- nome del transetto
- ID del transetto
- nome dell'osservatore
- GPS, coordinate manuali o nessuna posizione di partenza

Questo passaggio espone anche il selettore della mappa e il promemoria dell'autorizzazione GPS in background quando necessario.

### 2. Parametri

Questo passaggio contiene parametri specifici del transetto, come:

- selezione del microfono
- tasso di inferenza
- soglia di confidenza
- Intervallo GPS
- durata massima
- modalità di registrazione
- contesto della clip per la registrazione di solo rilevamento
- modalità di campionamento del rilevamento
- limite massimo N per specie quando il campionamento è limitato

#### Campionamento di rilevamento

Un transetto lungo può produrre migliaia di rilevamenti e il salvataggio di una clip audio per ognuno di essi riempie rapidamente lo spazio di archiviazione. Il campionamento del rilevamento controlla **quali clip vengono conservati sul disco** — *i record di rilevamento vengono sempre conservati*, quindi il registro completo della sessione rimane intatto indipendentemente dalla modalità. I record il cui audio è stato eliminato semplicemente non hanno clip riproducibili in Session Review.

Sono disponibili tre modalità:

| Modalità | Cosa fa |
| --- | --- |
| **Tutti** | Conserva ogni clip. Maggior utilizzo del disco. Consigliato per transetti brevi o quando si desidera l'audio di ogni rilevamento per un'analisi successiva. |
| **Top N** | Conserva solo le **N clip con la massima affidabilità per specie**. Gli altri clip vengono eliminati durante l'esecuzione del transetto. N predefinito è 10, configurabile da 1 a 50. |
| **Intelligente** | Stesso limite per specie di N come Top N, **più** distribuzione spaziale: se un nuovo rilevamento arriva nello stesso "punto" di una clip già conservata (entro ~ 500 me ~ 2 minuti l'una dall'altra), solo quella con maggiore sicurezza mantiene la clip. Ciò impedisce a un cantante stazionario di monopolizzare tutti gli N slot e di orientare le clip mantenute verso la copertura dell'intero transetto. |

Il limite N è **per specie, non globale**: se registri 10 pettirossi e 10 fringuelli, conservi 20 clip. Non esiste un limite complessivo al numero di clip che un transetto può produrre.

In modalità Smart, se il GPS manca durante un rilevamento, il controllo sullo stesso punto ritorna a una finestra di solo tempo (~2 minuti). Con il GPS disponibile, sia la distanza che il tempo devono sovrapporsi affinché due rilevamenti vengano conteggiati come lo stesso punto.

### 3. Avvisi sulle specie

Notifiche in stile push che si attivano durante il transetto quando viene rilevato qualcosa di degno di nota. Scegli una modalità:

- **Off**: nessun avviso (impostazione predefinita).
- **Prima sessione**: un avviso la prima volta che ogni specie viene ascoltata durante questo transetto.
- **Prima in assoluto**: avvisa solo quando l'app incontra una specie per la prima volta in tutte le tue sessioni (un avviso "ergastolo"). Supportato da una cronologia delle specie che dura tutta la vita, popolata automaticamente dalle sessioni esistenti al primo avvio.
- **Raro per questa posizione**: avvisa quando la probabilità del modello geografico per la posizione corrente è inferiore a una soglia configurabile. Una lettura in tempo reale sotto il cursore spiega esattamente su cosa si attiverà il valore corrente (ad esempio *"Avvisi su specie con meno del 5% di probabilità in questa posizione."*).
- **Lista di controllo**: avvisa solo sulle specie che hai aggiunto a un elenco personalizzato salvato. La procedura guidata stessa ti consente di creare nuove liste di controllo, modificare quelle esistenti in un editor a schermo intero dedicato con tassonomia ricercabile e *Importa da file* (qualsiasi semplice `.txt`/`.csv` di nomi scientifici) ed eliminare le liste che non ti servono più.

Un dispositivo di scorrimento *Confidenza minima* si trova sotto il selettore della modalità e viene automaticamente impostato sulla soglia di confidenza della sessione (gli avvisi non sono mai più sensibili dei rilevamenti stessi). Una sezione **Avanzate** espone i controlli di limitazione: una finestra di tolleranza all'avvio, un intervallo minimo rigido tra due avvisi qualsiasi e un limite mobile al minuto con fusione opzionale degli avvisi di superamento del limite in un'unica notifica di riepilogo, il tutto con selettori di chip con un solo tocco. La prima volta che passi a una modalità non disattivata, la procedura guidata richiede l'autorizzazione per le notifiche Android.

### 4. Suggerimenti sul campo

Una breve lista di controllo pre-avvio all'interno del flusso di configurazione.

### 5. Pronto

La schermata di riepilogo riassume la configurazione attiva del transetto prima di iniziare con :material-play:.

## Pannello di controllo del transetto in tempo reale

La schermata del transetto in tempo reale presenta tre schede principali più un elenco dei rilevamenti recenti.

### Barra superiore

- :material-stop: — termina il transetto
- :material-timer: — tempo trascorso
- :material-help-circle-outline: - apre il foglio di aiuto del transetto
- :material-tune: - apre le impostazioni del transetto

### Schede

- :material-map-outline: — mappa del percorso e rilevamenti mappati
- :equalizzatore materiale: — spettrogramma
- icona del grafico: statistiche riassuntive e suddivisione delle specie

### Statistiche e rilevamenti

Sotto il contenuto della scheda, il dashboard del transetto mostra una barra delle statistiche e un elenco di rilevamenti recenti. Toccando un rilevamento si apre la sovrapposizione dei dettagli della specie.

## Operazione in background

La modalità Transetto mantiene visibile una notifica persistente in primo piano durante la registrazione in modo che Android non sospenda la pipeline audio. La notifica si espande per mostrare:

- il tempo trascorso, il conteggio dei rilevamenti, il conteggio delle specie e la distanza percorsa e
- le **tre specie uniche più recenti** con la loro confidenza e un relativo timestamp ("proprio adesso", "42s fa", "5m fa", "2h fa").

La notifica (titolo, rilevamenti recenti e piè di pagina delle statistiche) è completamente tradotta nella lingua selezionata dall'app e utilizza le stesse preferenze specie-locali e *Mostra nomi scientifici* delle schede in-app.

Gli avvisi sulle specie (se abilitati) vengono visualizzati su un canale di notifica Android separato in modo da poter disattivare gli avvisi indipendentemente dalla notifica silenziosa della registrazione in corso. L'icona di avviso corrisponde all'icona di notifica in primo piano (un uccello monocromatico) e i testi degli avvisi mostrano solo il *motivo* — *"Primo rilevamento di questo transetto"*, *"Nella tua lista di controllo"*, *"Rilevato in questa posizione con meno del 4% di probabilità"* - lasciando il nome della specie nel titolo della notifica in grassetto dove Android lo rende più grande.

## Dopo l'interruzione

BirdNET Live salva il transetto concluso e apre [Revisione sessione](session-review.md).
