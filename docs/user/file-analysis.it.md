# Analisi file

L'Analisi file elabora una registrazione esistente attraverso la stessa pipeline BirdNET che alimenta i flussi di lavoro in tempo reale.

## Come aprirla

Dalla Home, tocca la scheda **Analisi file** con l'icona :app-audioFileRounded:.

### Da un'altra app

Puoi anche inviare una registrazione da un'altra app. Su Android, condividere un file audio con **BirdNET Live** o scegliere **Apri con** apre subito l'Analisi file. Su iOS, anche **Apri con** è immediato; dopo aver usato il menu di condivisione, apri BirdNET Live o torna all'app e la registrazione in attesa verrà selezionata automaticamente. Prima dell'analisi, l'app copia la registrazione nel proprio spazio di archiviazione temporaneo.

## Barra dell'app

- :app-tuneRounded: — apre le impostazioni di Analisi file
- :app-helpOutlineRounded: — apre l'aiuto di Analisi file
- :app-close: — annulla un'analisi in corso

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

- usare il GPS attuale :app-myLocation:
- inserire le coordinate manualmente :app-editLocationAlt:
- saltare la posizione :app-locationOff:
- scegliere un punto sulla mappa :app-mapSheet:
- impostare una data di registrazione facoltativa :app-calendarTodayRounded:

### 3. Parametri

La procedura guidata mostra:

- durata della finestra
- sovrapposizione
- sensibilità
- soglia di confidenza
- modalità del filtro specie

| Controllo di configurazione | Icona |
|---|---|
| Durata della finestra | :app-timerOutlined: |
| Sovrapposizione | :app-swapHoriz: |
| Sensibilità | :app-hearing: |
| Soglia di confidenza | :app-verifiedRounded: |
| Filtro specie | :app-filterAltRounded: |

Tocca il pulsante :app-helpOutline: accanto a un controllo per leggerne la spiegazione. Anche i passaggi di file, posizione e data di registrazione hanno pulsanti di aiuto.

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
