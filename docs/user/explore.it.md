# Esplora

Esplora mostra le specie previste per la posizione e la stagione attuali usando il geo-modello BirdNET.

## Come aprirlo

Apri **Esplora** dal piè di pagina della Home usando il pulsante :app-searchRounded:.

## Barra dell'app e intestazione

### Barra dell'app

- :app-refresh: — aggiorna la posizione e ricostruisce l'elenco delle specie previste

### Intestazione della posizione

L'intestazione mostra:

- il nome del luogo ottenuto tramite geocoding inverso, quando disponibile
- le coordinate sotto il nome del luogo
- :app-helpOutlineRounded: — apre il pannello di aiuto di Esplora

## Elenco delle specie

Ogni scheda di specie può includere:

- immagine della specie inclusa nell'app
- nome comune
- nome scientifico facoltativo
- chip del livello di abbondanza

Tocca una scheda per aprire il pannello dei dettagli della specie.

### Livelli di abbondanza

Invece di una percentuale grezza, ogni scheda mostra un **livello di abbondanza** per il luogo e la stagione attuali. Il chip del livello combina due indizi:

- un **cerchio** che si riempie da ⅙ a pieno man mano che la specie diventa più probabile
- la **prima lettera** del nome del livello (il nome completo viene letto dagli screen reader e mostrato nei dettagli della specie)

Il colore del chip segue la scala di punteggio condivisa dell'app, passando dal rosso (meno probabile) al verde (più probabile) man mano che il livello sale.

Ci sono sei livelli, dal più al meno probabile:

| Livello | Significato |
| --- | --- |
| **Abbondante** | Tra le previsioni più forti qui |
| **Comune** | Molto probabile |
| **Frequente** | Probabile |
| **Insolita** | Possibile |
| **Scarsa** | Improbabile |
| **Rara** | Tra le previsioni più deboli qui |

I livelli sono **relativi alla posizione attuale**. Si adattano a quanto fortemente il geo-modello prevede le specie in quest'area, quindi i limiti si spostano con la distribuzione locale dei punteggi: in un luogo con molte previsioni sicure una specie ha bisogno di un punteggio molto alto per essere *Abbondante*, mentre in un'area con previsioni più deboli lo stesso livello si raggiunge con un punteggio inferiore. Lo stesso punteggio può quindi ricadere in livelli diversi in luoghi diversi, mantenendo la classifica significativa ovunque.

## Pannello dei dettagli della specie

Il pannello può mostrare:

- un'immagine più grande
- i crediti dell'immagine
- nomi comuni e scientifici
- testo descrittivo incluso nell'app, quando disponibile
- il grafico settimanale della frequenza prevista
- link esterni come eBird, iNaturalist o Wikipedia, quando disponibili per quella specie

## A cosa serve Esplora

Esplora è una vista di riferimento sensibile alla posizione all'interno dell'app. Ti aiuta a confrontare il contesto della posizione attuale dell'app con le specie che potresti aspettarti di incontrare.

Da sola **non** modifica i dati delle Sessions salvate. Il filtraggio delle rilevazioni si controlla separatamente tramite le [Impostazioni](settings.md).
