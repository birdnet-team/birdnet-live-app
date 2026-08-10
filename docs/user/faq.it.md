# Domande frequenti

Domande frequenti.

## Generale

**D: BirdNET Live richiede una connessione Internet?**
R: No. Tutte le inferenze vengono eseguite sul dispositivo utilizzando il modello ONNX. Le uniche funzionalità di rete sono facoltative e disattivate per impostazione predefinita: i tasselli della mappa e la ricerca dei nomi dei luoghi da OpenStreetMap, le istantanee meteo da Open-Meteo e il recupero di immagini e descrizioni delle specie dall'API della tassonomia. Vedi [Impostazioni → Privacy](settings.md#privacy).

**D: Quante specie può identificare?**
R: Il modello BirdNET+ V3.0 identifica 9.789 specie in tutto il mondo: uccelli, anfibi, mammiferi e insetti (l'intersezione ridotta tra il classificatore audio e il geomodello).

**D: Quali piattaforme sono supportate?**
R: Android (8.0+), iOS (15.0+) e Windows (sperimentale).

## Precisione

**D: Perché la mia soglia di confidenza mostra punteggi bassi?**
R: Abbassa la soglia di confidenza nelle Impostazioni per vedere più rilevamenti. Il rumore di fondo, il vento e la distanza influiscono sulla precisione.

**D: Cosa fa il filtro delle specie?**
R: Il modello geografico prevede quali specie si troveranno probabilmente nella tua posizione GPS e in quale periodo dell'anno. Attiva **Filtro per posizione** per nascondere le specie improbabili, **Filtro adattivo per posizione** per nasconderne solo quelle su cui è incerto anche il modello audio, oppure **Ponderazione per posizione** per ponderare i risultati in base alla probabilità geografica.

**D: Quanto è precisa l'identificazione?**
R: La precisione dipende dalla qualità della registrazione, dalla distanza, dal rumore di fondo e dalla specie. I rilevamenti con elevata affidabilità (>70%) sono generalmente affidabili. Verifica sempre visivamente le specie rare.

## Registrazione

**D: Dove vengono salvate le registrazioni?**
R: Nella directory dei documenti dell'app in `recordings/<session-id>/`. In formato WAV o FLAC a seconda di **Impostazioni → Registrazione → Formato**.

**D: Posso analizzare le registrazioni esistenti?**
R: Sì. Apri Analisi file dalla schermata principale, seleziona un file audio, imposta posizione e parametri e tocca Analizza. I formati supportati includono WAV, FLAC, MP3, OGG, Opus, M4A, AAC, WMA e AMR.

## Conteggio punti

**D: Cos'è la modalità conteggio punti?**
R: Una modalità di rilevamento a tempo per osservazioni formali di conteggio dei punti aviari. Imposti una durata fissa (3-20 minuti) e una posizione, quindi l'app funziona continuamente e si arresta automaticamente quando il timer raggiunge lo zero.

**D: Posso mettere in pausa il conteggio dei punti?**
R: No. La conformità al protocollo richiede una registrazione ininterrotta. Puoi terminare prima tramite il pulsante stop.

**D: Dove vanno a finire i risultati del conteggio dei punti?**
R: Vengono visualizzati nella Libreria sessioni come "Conteggio punti n. 1", "N. 2" ecc. Puoi rivederli, modificarli ed esportarli come qualsiasi altra sessione.

## Prestazione

**D: Perché l'app è calda/consuma la batteria?**
R: L'inferenza del modello ONNX richiede un utilizzo intensivo del calcolo. Lo schermo rimane acceso anche durante le sessioni live. Questo è normale per l'elaborazione della rete neurale in tempo reale.

**D: Lo spettrogramma sembra congelato.**
R: Assicurati che l'autorizzazione del microfono sia concessa e che l'acquisizione audio sia attiva. Verifica che nessun'altra app stia utilizzando il microfono.