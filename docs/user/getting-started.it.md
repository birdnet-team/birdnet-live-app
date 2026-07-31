# Primi passi

## Installazione

BirdNET Live è disponibile per Android, iOS e Windows.

### Requisiti

- **Android**: 8.0 (API 26) o successiva
- **iOS**: 15.0 o successivo
- **Windows**: 10 o successivo (sperimentale)
- ~300 MB di spazio di archiviazione per app + modelli

### Download

- **Android**: [Google Play](https://play.google.com/store/apps/details?id=de.tu_chemnitz.mi.kahst.birdnet_live), oppure installa manualmente l’APK firmato dalla [pagina GitHub Releases](https://github.com/birdnet-team/birdnet-live-app/releases/latest).
- **iOS**: [App Store](https://apps.apple.com/us/app/birdnet-live/id6776168518).
- **Windows**: compila dai sorgenti; vedi la [Guida per gli sviluppatori](../developer/building.md).

## Flusso dell'app al primo avvio

Quando apri BirdNET Live per la prima volta, l'app ti guida attraverso un breve flusso di introduzione e la configurazione delle autorizzazioni.

1. Leggi le schermate introduttive.
2. Leggi la Politica di uso accettabile e l'Informativa sulla privacy.
3. Concedi l'autorizzazione al microfono affinché BirdNET Live possa elaborare l'audio.
4. Facoltativamente, consenti l'autorizzazione alla posizione per la georeferenziazione, Esplora, Point Count e Survey.
5. Facoltativamente, consenti le notifiche per i Survey di lunga durata.

## Primo avvio

1. **Introduzione**: rapida presentazione di funzionalità e autorizzazioni
2. **Uso accettabile e privacy**: leggi la Politica di uso accettabile e l'Informativa sulla privacy
3. **Autorizzazioni**: concedi l'accesso al microfono (richiesto per tutte le modalità)
4. **Pronto**: inizia a identificare gli uccelli!

## Panoramica della schermata Home

La schermata Home è l'hub principale.

### Schede delle modalità principali

- :material-microphone: **Modalità Live**
- :material-map-marker: **Modalità Point Count**
- :material-routes: **Modalità Survey**
- :material-file-music: **Analisi file**

### Pulsanti del piè di pagina

- :material-tune: **Impostazioni**
- :material-magnify: **Esplora**
- :material-music-box-multiple-outline: **Libreria Sessions**
- :material-help-circle-outline: **Aiuto**
- :material-information-outline: **Informazioni**

## Cosa viene salvato

BirdNET Live salva automaticamente ogni Session completata e la apre nel Riepilogo sessione al termine dell'elaborazione.

- Le Sessions Live salvano le rilevazioni e, a seconda delle impostazioni, le registrazioni o i clip.
- Le Sessions Point Count vengono salvate come sessioni Point Count a tempo.
- Le Sessions Survey salvano il percorso, le rilevazioni e i relativi metadati.
- I risultati dell'Analisi file vengono convertiti in una Session esaminabile.

## Pagine successive consigliate

- Leggi [Icone e controlli](icons-and-controls.md) se vuoi una rapida spiegazione dei simboli ricorrenti dell'interfaccia.
- Leggi [Impostazioni](settings.md) prima di modificare soglie, filtri, comportamento di registrazione o visualizzazione dello spettrogramma.
- Apri la guida del flusso di lavoro che usi più spesso: [Modalità Live](live-mode.md), [Modalità Point Count](point-count-mode.md), [Modalità Survey](survey-mode.md) o [Analisi file](file-analysis.md).

## Autorizzazioni

| Autorizzazione | Necessaria per | Opzionale? |
|------------|-------------|-----------|
| Microfono | Tutte le modalità di registrazione | Obbligatoria |
| Posizione | Tagging GPS, Survey/Point Count | Opzionale per Live |
| Archiviazione | Salvataggio di registrazioni ed esportazioni | Necessaria per la registrazione |
| Notifiche | Avvisi dei Survey in background | Opzionale |
