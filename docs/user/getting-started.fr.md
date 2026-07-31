# Mise en route

## Installation

BirdNET Live est disponible pour Android, iOS et Windows.

### Configuration requise

- **Android** : 8.0 (API 26) ou version ultérieure
- **iOS** : 15.0 ou version ultérieure
- **Windows** : 10 ou version ultérieure (expérimental)
- ~300 Mo de stockage pour l'application et les modèles

### Téléchargement

- **Android** : [Google Play](https://play.google.com/store/apps/details?id=de.tu_chemnitz.mi.kahst.birdnet_live), ou installez manuellement l’APK signé depuis la [page des Releases GitHub](https://github.com/birdnet-team/birdnet-live-app/releases/latest).
- **iOS** : [App Store](https://apps.apple.com/us/app/birdnet-live/id6776168518).
- **Windows** : compilez depuis les sources ; voir le [Guide du développeur](../developer/building.md).

## Premier lancement de l'application

Lorsque vous ouvrez BirdNET Live pour la première fois, l'application vous guide à travers une courte introduction et la configuration des autorisations.

1. Lisez les écrans d'introduction.
2. Acceptez les conditions d'utilisation et la politique de confidentialité.
3. Accordez l'autorisation du microphone pour que BirdNET Live puisse traiter l'audio.
4. Autorisez éventuellement la localisation pour la géolocalisation, Explorer, le Point d'écoute et le Relevé.
5. Autorisez éventuellement les notifications pour les relevés de longue durée.

## Premier démarrage

1. **Introduction** — Présentation rapide des fonctionnalités et des autorisations
2. **Utilisation acceptable et confidentialité** — consultez la politique d'utilisation acceptable et la politique de confidentialité
3. **Autorisations** — Accordez l'accès au microphone (obligatoire pour tous les modes)
4. **Prêt** — Commencez à identifier les oiseaux !

## Aperçu de l'écran d'accueil

L'écran d'accueil est le point central de l'application.

### Cartes des modes principaux

- :material-microphone: **Mode En direct**
- :material-map-marker: **Mode Point d'écoute**
- :material-routes: **Mode Relevé**
- :material-file-music: **Analyse de fichiers**

### Boutons du bas

- :material-tune: **Paramètres**
- :material-magnify: **Explorer**
- :material-music-box-multiple-outline: **Bibliothèque de sessions**
- :material-help-circle-outline: **Aide**
- :material-information-outline: **À propos**

## Ce qui est enregistré

BirdNET Live enregistre automatiquement chaque session terminée et l'ouvre dans le Résumé de la session une fois le traitement arrêté.

- Les sessions En direct enregistrent les détections et, selon vos paramètres, les enregistrements ou les clips.
- Les sessions Point d'écoute sont enregistrées comme des points d'écoute minutés.
- Les sessions Relevé enregistrent l'itinéraire, les détections et les métadonnées associées.
- Les résultats de l'Analyse de fichiers sont convertis en une session consultable.

## Pages suivantes recommandées

- Lisez [Icônes et contrôles](icons-and-controls.md) si vous souhaitez une explication rapide des symboles récurrents de l'interface.
- Lisez [Paramètres](settings.md) avant de modifier les seuils, les filtres, le comportement d'enregistrement ou l'affichage du spectrogramme.
- Ouvrez le guide du type de travail que vous utilisez le plus souvent : [Mode En direct](live-mode.md), [Mode Point d'écoute](point-count-mode.md), [Mode Relevé](survey-mode.md) ou [Analyse de fichiers](file-analysis.md).

## Autorisations

| Autorisation | Requise pour | Facultative ? |
|------------|-------------|---------------|
| Microphone | Tous les modes d'enregistrement | Obligatoire |
| Localisation | Géolocalisation GPS, Relevé/Point d'écoute | Facultative pour le mode En direct |
| Stockage | Sauvegarde des enregistrements, exports | Nécessaire pour l'enregistrement |
| Notifications | Alertes de relevé en arrière-plan | Facultative |
