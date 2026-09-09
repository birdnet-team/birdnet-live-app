# Analisi file

L'Analisi file elabora una registrazione esistente attraverso la stessa pipeline BirdNET che alimenta i flussi di lavoro in tempo reale.

## Come aprirla

Dalla Home, tocca la scheda **Analisi file** con l'icona :material-file-music:.

### Da un'altra app

Puoi anche inviare una registrazione da un'altra app. Su Android, condividere un file audio con **BirdNET Live** o scegliere **Apri con** apre subito l'Analisi file. Su iOS, anche **Apri con** è immediato; dopo aver usato il menu di condivisione, apri BirdNET Live o torna all'app e la registrazione in attesa verrà selezionata automaticamente. Prima dell'analisi, l'app copia la registrazione nel proprio spazio di archiviazione temporaneo.

## Barra dell'app

- :material-tune: — apre le impostazioni di Analisi file
- :material-close: — annulla un'analisi in corso

## Formati supportati

Il selettore file attuale accetta:

- WAV / WAVE
- FLAC
- MP3
- OGG / OGA / Opus
- M4A / AAC / MP4
- WMA / AMR

## Procedura guidata in quattro passaggi

### 1. Seleziona file

Scegli un file ed esamina la relativa scheda dei metadati:

- nome del file
- formato
- durata
- dimensione del file
- frequenza di campionamento

### 2. Posizione e data

Puoi:

- usare il GPS attuale
- inserire le coordinate manualmente
- saltare la posizione
- scegliere un punto sulla mappa
- impostare una data di registrazione facoltativa

### 3. Parametri

La procedura guidata mostra:

- durata della finestra
- sovrapposizione
- sensibilità
- soglia di confidenza
- modalità del filtro specie

La sovrapposizione controlla di quanto avanza ogni finestra di analisi ed è
specifica dell'analisi file: l'intero file viene sempre esaminato, e più
sovrapposizione lo esamina semplicemente in modo più fine. Le modalità dal
vivo usano invece una frequenza di inferenza, perché devono decidere ogni
quanto eseguire il modello sull'audio in arrivo e non quanto finemente coprire
una registrazione già fissata.

In qualunque modo l'analisi file arrivi alle sue finestre, le trasforma in
rilevazioni con le stesse regole della modalità Live, di Point Count e di
Survey: una rilevazione inizia alla sua prima finestra di supporto, porta il
punteggio supportato più alto e termina alla fine dell'ultima finestra di
supporto.

### 4. Analizza

La schermata di avanzamento mostra:

- finestre elaborate
- rilevazioni trovate
- specie trovate
- pulsante di annullamento

## Risultato

Al termine dell'analisi, BirdNET Live converte l'output in una Session salvata e apre il [Riepilogo sessione](session-review.md).
