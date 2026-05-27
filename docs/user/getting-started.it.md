# Iniziare

## Installazione

BirdNET Live è disponibile per Android, iOS e Windows.

### Requisiti

- **Android**: 8.0 (API 26) o successiva
- **iOS**: 15.0 o successivo
- **Windows**: 10 o successivo (sperimentale)
- ~300 MB di spazio di archiviazione per app + modelli

### Scaricamento

*I link di distribuzione verranno aggiunti quando disponibili.*

## Flusso dell'app per la prima volta

Quando apri BirdNET Live per la prima volta, l'app segue un breve flusso di onboarding e la configurazione delle autorizzazioni.

1. Leggi le schermate di onboarding.
2. Accetta i Termini di utilizzo e l'Informativa sulla privacy.
3. Concedere l'autorizzazione al microfono in modo che BirdNET Live possa elaborare l'audio.
4. Facoltativamente, consentire l'autorizzazione alla posizione per geotagging, Esplora, Conteggio punti e Sondaggio.
5. Facoltativamente, consenti notifiche per sondaggi di lunga durata.

## Primo lancio

1. **Onboarding**: rapida introduzione a funzionalità e autorizzazioni
2. **Termini e privacy**: accetta i Termini di utilizzo e l'Informativa sulla privacy
3. **Autorizzazioni**: concedi l'accesso al microfono (richiesto per tutte le modalità)
4. **Pronto**: inizia a identificare gli uccelli!

## Panoramica della schermata iniziale

La schermata Home è l'hub principale.

### Carte della modalità principale

- :material-microfono: **Modalità live**
- :material-map-marker: **Modalità conteggio punti**
- :material-route: **Modalità sondaggio**
- :material-file-music: **Analisi file**

### Widget Android

BirdNET Live include due widget Android: **BirdNET Live shortcut** e **BirdNET Live statistics**.

- Solo Android. Il supporto alla schermata di blocco dipende dal dispositivo e dall'host dei widget.
- Apri [Widget Android](android-widgets.md) per configurazione, comportamento e dettagli d'uso.

### Pulsanti del piè di pagina

- :material-tune: **Impostazioni**
- :material-magnify: **Esplora**
- :material-music-box-multiple-outline: **Libreria sessioni**
- :material-help-circle-outline: **Aiuto**
- :schema-informazioni-materiale: **Informazioni**

## Cosa viene salvato

BirdNET Live salva automaticamente le sessioni completate e le apre in Session Review dopo l'interruzione dell'elaborazione.

- Le sessioni live salvano i rilevamenti e, a seconda delle impostazioni, le registrazioni o i clip.
- Le sessioni di conteggio punti vengono salvate come sessioni di conteggio punti temporizzate.
- Le sessioni di sondaggio salvano il percorso, i rilevamenti e i relativi metadati.
- I risultati dell'analisi dei file vengono convertiti in una sessione rivedibile.

## Pagine successive consigliate

- Leggi [Icone e controlli](icons-and-controls.md) se desideri una rapida spiegazione dei simboli ricorrenti dell'interfaccia utente.
- Leggere [Impostazioni](settings.md) prima di modificare soglie, filtri, comportamento di registrazione o visualizzazione dello spettrogramma.
- Apri la guida per il flusso di lavoro che utilizzi più spesso: [Modalità live](live-mode.md), [Modalità conteggio punti](point-count-mode.md), [Modalità sondaggio](survey-mode.md) o [Analisi file](file-analysis.md).

## Autorizzazioni

| Autorizzazione | Obbligatorio per | Opzionale? |
|------------|-------------|-----------|
| Microfono | Tutte le modalità di registrazione | Obbligatorio |
| Posizione | Tagging GPS, rilevamento/conteggio punti | Facoltativo per Live |
| Stoccaggio | Salvataggio di registrazioni, esportazioni | Necessario per la registrazione |
| Notifiche | Avvisi di sondaggi di fondo | Facoltativo |
