# BirdNET Live

**Bioacoustique professionnelle dans votre poche.**

BirdNET Live est une application Flutter conçue pour les chercheurs de terrain, les naturalistes et les ornithologues amateurs qui ont besoin de preuves acoustiques fiables sur le terrain. Elle exécute le classifieur audio BirdNET+ et le géo-modèle directement sur votre appareil : l'identification des espèces fonctionne donc entièrement hors ligne une fois l'application installée.

<p align="center">
  <img src="https://img.shields.io/badge/latest-v0.19.0-orange.svg" alt="Latest release: v0.19.0">
  <img src="https://img.shields.io/badge/species-9%2C789-brightgreen.svg" alt="Species: 9,789">
  <img src="https://img.shields.io/badge/platforms-Android%20%7C%20iOS%20%7C%20Windows-green.svg" alt="Platforms">
</p>

## Fonctionnalités

- **Mode En direct** - Spectrogramme défilant en temps réel avec identification des espèces
- **Mode Point d'écoute** - Sessions minutées avec compte à rebours et métadonnées de la station
- **Mode Relevé** - Relevés de transects de longue durée avec suivi GPS, surveillance en arrière-plan et échantillonnage des détections
- **Mode Analyse de fichiers** - Analyse hors ligne d'enregistrements existants (WAV, FLAC, MP3, OGG et plus)
- **Explorer** - Parcourez les espèces attendues à votre position grâce au géo-modèle BirdNET
- **Bibliothèque de sessions** - Consultez, modifiez et exportez vos sessions passées avec lecture audio
- **Export** - Formats Raven Pro, CSV, JSON, GPX et paquet ZIP avec métadonnées de provenance
- **Inférence sur l'appareil** - Le modèle BirdNET+ couvre 5 250 espèces, sans connexion Internet
- **Enregistrement FLAC** - Capture audio compressée avec des fichiers plus légers pour les longs relevés
- **Accessibilité** - Étiquettes pour lecteurs d'écran, infobulles et annonces vocales des détections en option
- **Mises en page adaptatives** - Interfaces adaptées au téléphone, à la tablette, en mode portrait et paysage

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

## Démarrage rapide

Consultez le [Guide de l'utilisateur](user/index.md) pour une vue d'ensemble, puis ouvrez [Mise en route](user/getting-started.md) pour installer et lancer BirdNET Live.

## Installation sur Android

BirdNET Live est disponible sous forme d'APK signé à installer manuellement (sideloading). Téléchargez la dernière version depuis la [page des Releases GitHub](https://github.com/birdnet-team/birdnet-live-app/releases/latest), transférez le fichier `.apk` sur votre téléphone et ouvrez-le pour l'installer. Vous devrez peut-être d'abord autoriser l'installation depuis des sources inconnues dans les paramètres de votre appareil.

> **Note :** L'APK pèse environ 253 Mo car il inclut les ressources du modèle BirdNET+ pour l'inférence hors ligne.

## Pour les développeurs

Consultez le [Guide du développeur](developer/index.md) pour l'architecture, la compilation et la contribution.

## Licence

Le code source de BirdNET Live est un logiciel libre publié sous [licence MIT](https://github.com/birdnet-team/birdnet-live-app/blob/main/LICENSE). Les poids des modèles BirdNET intégrés sont sous [Apache License 2.0](https://github.com/birdnet-team/birdnet-live-app/blob/main/MODEL_LICENSE).
