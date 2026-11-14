# Domande frequenti

Domande frequenti.

## Generale

**D: BirdNET Live richiede una connessione Internet?**
R: No. Tutte le inferenze vengono eseguite sul dispositivo utilizzando il modello ONNX. Le uniche funzionalità di rete sono facoltative e disattivate per impostazione predefinita: i riquadri della mappa e la ricerca dei nomi dei luoghi da OpenStreetMap, le istantanee meteo da Open-Meteo e il recupero di immagini e descrizioni delle specie dall'API della tassonomia. Vedi [Impostazioni → Privacy](settings.md#privacy).

**D: Quante specie può identificare?**
R: Il modello BirdNET+ V3.0 identifica 10.048 specie in tutto il mondo: uccelli, anfibi, mammiferi e insetti (l'intersezione ridotta tra il classificatore audio e il geomodello). Riconosce anche 16 suoni non animali, come motori, sirene e musica; restano disattivati finché non attivi [Suoni non animali](settings.md#suoni-non-animali).

**D: Una specie in una Session meno recente ha un nuovo nome o non viene più rilevata. Ho perso qualcosa?**
R: No. Un aggiornamento del modello può rinominare le specie per seguire la tassonomia attuale ed eliminare quelle che il nuovo modello non copre. Le Sessions salvate non vengono modificate: una rilevazione meno recente viene mostrata con il nome attuale della specie, con immagine, traduzione e link, e le specie che il modello non rileva più restano nelle tue Sessions e nelle esportazioni esattamente come sono state registrate.

**D: Quali piattaforme sono supportate?**
R: Android (8.0+), iOS (15.0+) e Windows (sperimentale).

## Precisione

**D: Perché la mia soglia di confidenza mostra punteggi bassi?**
R: Abbassa la soglia di confidenza nelle Impostazioni per vedere più rilevazioni. Il rumore di fondo, il vento e la distanza influiscono sulla precisione.

**D: Cosa fa il filtro delle specie?**
R: Il geomodello prevede quali specie si troveranno probabilmente nella tua posizione GPS e in quale periodo dell'anno. Attiva **Filtro geografico** per nascondere le specie improbabili, **Filtro geografico adattivo** per nasconderne solo quelle su cui è incerto anche il modello audio, oppure **Ponderazione geografica** per ponderare i risultati in base alla probabilità geografica.

**D: Quanto è precisa l'identificazione?**
R: La precisione dipende dalla qualità della registrazione, dalla distanza, dal rumore di fondo e dalla specie. Le rilevazioni con confidenza elevata (>70%) sono generalmente affidabili. Verifica sempre visivamente le specie rare.

## Registrazione

**D: Dove vengono salvate le registrazioni?**
R: Nella directory dei documenti dell'app in `recordings/<session-id>/`. In formato WAV o FLAC a seconda di **Impostazioni → Audio e registrazione → Formato di registrazione**.

**D: Posso analizzare le registrazioni esistenti?**
R: Sì. Apri Analisi file dalla schermata principale, seleziona un file audio, imposta posizione e parametri e tocca Analizza. I formati supportati includono WAV, FLAC, MP3, OGG, Opus, M4A, AAC, WMA e AMR.

## Point Count

**D: Cos'è la modalità Point Count?**
R: Una modalità di rilievo a tempo per censimenti formali da punti d'ascolto. Imposti una durata fissa (3-30 minuti) e una posizione, quindi l'app ascolta senza interruzioni e si ferma automaticamente quando il timer arriva a zero.

**D: Posso mettere in pausa un Point Count?**
R: No. La conformità al protocollo richiede una registrazione ininterrotta. Puoi terminare in anticipo con il pulsante Stop.

**D: Dove finiscono i risultati di un Point Count?**
R: Compaiono nella Libreria Sessions come "Point Count #1", "Point Count #2" ecc. Puoi rivederli, modificarli ed esportarli come qualsiasi altra Session.

## Prestazioni

**D: Perché il dispositivo si scalda o la batteria si scarica in fretta?**
R: L'inferenza del modello ONNX richiede molta potenza di calcolo. Inoltre lo schermo resta acceso durante le Sessions dal vivo. È normale per l'elaborazione in tempo reale con una rete neurale.

**D: Lo spettrogramma sembra bloccato.**
R: Assicurati che l'autorizzazione al microfono sia concessa e che l'acquisizione audio sia attiva. Verifica che nessun'altra app stia utilizzando il microfono.