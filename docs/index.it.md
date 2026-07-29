# BirdNET Live

**Bioacustica professionale in tasca.**

BirdNET Live è un'app Flutter pensata per chi fa ricerca sul campo, per chi si occupa di conservazione e per il birdwatching, e ha bisogno di prove acustiche affidabili sul campo. Esegue il classificatore audio BirdNET+ e il geo-modello direttamente sul dispositivo, quindi l'identificazione delle specie funziona completamente offline una volta installata.

<p align="center">
  <img src="https://img.shields.io/badge/latest-v0.19.5-orange.svg" alt="Latest release: v0.19.5">
  <img src="https://img.shields.io/badge/species-9%2C789-brightgreen.svg" alt="Species: 9,789">
  <img src="https://img.shields.io/badge/platforms-Android%20%7C%20iOS%20%7C%20Windows-green.svg" alt="Platforms">
</p>

## Funzionalità

- **Modalità Live** - Spettrogramma a scorrimento in tempo reale con identificazione delle specie
- **Modalità Point Count** - Sessioni a tempo con timer di conto alla rovescia e metadati della stazione
- **Modalità Survey** - Survey su transetti di lunga durata con tracciamento GPS, monitoraggio in background e campionamento delle rilevazioni
- **Modalità Analisi file** - Analisi offline di registrazioni esistenti (WAV, FLAC, MP3, OGG e altri)
- **Esplora** - Sfoglia le specie attese nella tua posizione usando il geo-modello BirdNET
- **Libreria Sessions** - Esamina, modifica ed esporta le Sessions passate con riproduzione audio
- **Esportazione** - Formati Raven Pro, CSV, JSON, GPX e pacchetto ZIP con metadati di provenienza
- **Inferenza sul dispositivo** - Il modello BirdNET+ copre 5.250 specie, senza necessità di connessione a Internet
- **Registrazione FLAC** - Acquisizione audio compressa con file più piccoli per Survey lunghi
- **Accessibilità** - Etichette per screen reader, descrizioni comando e annunci vocali opzionali delle rilevazioni
- **Layout adattivi** - Interfacce adattabili per telefono, tablet, orientamento verticale e orizzontale

<p align="center">
  <img src="../assets/screenshots/live-mode.png" alt="Live Mode" width="150">
  <img src="../assets/screenshots/session-review.png" alt="Session Review" width="150">
  <img src="../assets/screenshots/explore.png" alt="Explore" width="150">
  <img src="../assets/screenshots/species.png" alt="Species Overlay" width="150">
  <img src="../assets/screenshots/file-analysis.png" alt="File Analysis" width="150">
</p>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=de.tu_chemnitz.mi.kahst.birdnet_live"><b>Google Play</b></a>
  &nbsp;·&nbsp;
  <a href="https://github.com/birdnet-team/birdnet-live-app/releases/latest"><b>Download APK</b></a>
  &nbsp;·&nbsp;
  <a href="https://github.com/birdnet-team/birdnet-live-app"><b>GitHub</b></a>
  &nbsp;·&nbsp;
  <a href="https://github.com/birdnet-team/birdnet-live-app/releases"><b>All Releases</b></a>
</p>

## Avvio rapido

Consulta la [Guida per l'utente](user/index.md) per una panoramica, poi apri [Primi passi](user/getting-started.md) per installare e avviare BirdNET Live.

## Installazione su Android

BirdNET Live è disponibile come APK firmato per il sideloading. Scarica l'ultima versione dalla [pagina GitHub Releases](https://github.com/birdnet-team/birdnet-live-app/releases/latest), trasferisci il file `.apk` sul telefono e aprilo per installarlo. Potrebbe essere necessario consentire prima l'installazione da origini sconosciute nelle impostazioni del dispositivo.

> **Nota:** l'APK pesa circa 253 MB perché include le risorse del modello BirdNET+ per l'inferenza offline.

## Per gli sviluppatori

Consulta la [Guida per sviluppatori](developer/index.md) per architettura, compilazione e contributi.

## Licenza

Il codice sorgente di BirdNET Live è open source sotto [licenza MIT](https://github.com/birdnet-team/birdnet-live-app/blob/main/LICENSE). I pesi dei modelli BirdNET inclusi sono concessi con [Apache License 2.0](https://github.com/birdnet-team/birdnet-live-app/blob/main/MODEL_LICENSE).
