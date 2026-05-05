# Revisione della sessione

Session Review è il luogo in cui BirdNET Live trasforma i rilevamenti in un record modificabile.

## Come raggiungerlo

BirdNET Live apre automaticamente la revisione della sessione dopo aver completato:

- una sessione dal vivo
- un conteggio a punto
- un transetto
- un'esecuzione di analisi dei file

Puoi anche riaprire qualsiasi sessione salvata da [Libreria sessioni](session-library.md).

## Aree principali

### Riepilogo e riproduzione

Session Review combina la riproduzione, la navigazione dello spettrogramma e un elenco di specie. Per le sessioni di transetto può anche mostrare il contesto mappato.

### Elenco delle specie

Le specie sono raggruppate in righe espandibili. Puoi esaminare i rilevamenti per specie e spostarti nella registrazione mentre li rivedi.

### Mappa del percorso del transetto

Le sessioni di transetto mostrano una piccola mappa in linea della traccia GPS e dei marker di rilevamento. Toccalo per aprire una **mappa a schermo intero** con gli stessi dati.

La barra delle applicazioni della mappa a schermo intero ha un pulsante :material-filter-list-outlined: **filtro** che apre un foglio per limitare quali indicatori vengono mostrati. Filtri disponibili:

- **Tutti i rilevamenti** (impostazione predefinita).
- **Con clip audio**: solo i rilevamenti la cui clip è ancora su disco e riproducibile.
- **Alta confidenza**: solo rilevamenti pari o superiori all'80% di confidenza.
- **Aggiunte manuali**: solo i rilevamenti aggiunti in Session Review (esclusi quelli rilevati automaticamente).

Sotto il selettore della modalità c'è un selettore **Limiti alle specie** che ti consente di ridurre la mappa a una singola specie, utile per chiedere "dove esattamente lungo il percorso ho sentito il tordo selvatico?". Una voce *Tutte le specie* annulla la limitazione delle specie. I due filtri si combinano: ad es. *Con clip audio* + *Wood Thrush* mostra solo i segnalini Wood Thrush giocabili.

Quando un filtro è attivo, il titolo della barra dell'app ottiene un sottotitolo per il conteggio delle corrispondenze (ad esempio *"7 rilevamenti"*) e il pulsante del filtro mostra un piccolo punto. *Reimposta* nel foglio ritorna ai valori predefiniti.

## Icone della barra degli strumenti

La barra degli strumenti utilizza gli stessi significati delle icone descritti in [Icone e controlli](icons-and-controls.md):

- :material-plus-circle-outline: - aggiungi contenuto
- :material-undo-variant: / :material-redo-variant: - passa attraverso le modifiche
- :material-content-cut: - modalità di ritaglio
- :material-content-save: - salva le modifiche
- :material-share-variant: — esportazione o condivisione
- :material-delete-outline: - sessione di eliminazione
- :material-play: — continua un transetto quando l'azione è disponibile
- :material-help-circle-outline: - apre il foglio di aiuto per la revisione della sessione
- :material-tune: - apri Impostazioni

## Attività tipiche di revisione

- verificare i rilevamenti rispetto alla riproduzione e al contesto dello spettrogramma
- aggiungere una specie o un'annotazione
- ritagliare la registrazione all'intervallo utile
- esportare il set di risultati rivisto

## Esporta

Il comportamento dell'esportazione dipende dalle opzioni selezionate in [Impostazioni](settings.md). L'app può comprimere i rilevamenti e, facoltativamente, l'audio nel formato di esportazione scelto. Ogni esportazione ora viene fornita con metadati di provenienza completi (versione dell'app, nome e versione del modello, impostazioni locali della specie, timestamp di esportazione e un'istantanea di tutte le impostazioni al momento dell'esportazione) scritti in un file laterale `prefix.metadata.json` (ZIP) o in un blocco "meta" di livello superiore (JSON) in modo che le esportazioni siano autodescrittive e riproducibili.
