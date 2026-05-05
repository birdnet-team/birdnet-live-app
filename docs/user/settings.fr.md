# Paramètres

BirdNET Live réutilise un écran Paramètres sur plusieurs flux de travail. Le bouton :material-tune: ouvre les sections pertinentes pour l'écran d'où vous venez.

## Comment fonctionne la portée des paramètres

- L'ouverture des paramètres depuis l'accueil affiche le plein écran.
- L'ouverture des paramètres depuis Live, Survey, Point Count ou File Analysis filtre l'écran vers les sections pertinentes.

## Général

### Thème

Choisissez **Sombre**, **Clair** ou **Système**.

### Langue de l'application

Définit la langue de l'interface.

### Noms des espèces

Contrôle la langue utilisée pour les noms d'espèces. **Suivez la langue de l'application** utilise la même langue que l'interface lorsque ce nom est disponible.

### Afficher les noms scientifiques

Affiche les noms scientifiques sous les noms communs dans l'application.

## Audio

Ces contrôles apparaissent dans les flux de travail en direct pilotés par l'audio.

### Gagner

Ajuste le gain d'entrée affiché dans l'application. Utilisez-le uniquement lorsque vous devez compenser des enregistrements ou des entrées très silencieux.

### Filtre passe-haut (Hz)

Réduit le grondement basse fréquence avant l’inférence.

### Micro

Vous permet de choisir un périphérique d'entrée spécifique ou de conserver la **valeur par défaut du système**.

## Inférence

### Durée de la fenêtre

Contrôle la longueur de la fenêtre d'analyse.

### Seuil de confiance

Définit le degré de prudence des détections.

### Sensibilité

Des valeurs plus élevées rendent le détecteur plus permissif, ce qui permet de récupérer des appels plus faibles au prix d'un plus grand nombre de faux positifs.

### Taux d'inférence

Contrôle la fréquence à laquelle BirdNET exécute l'inférence.

### Regroupement des scores

Contrôle la façon dont les fenêtres d’analyse qui se chevauchent sont combinées.

## Spectrogramme

### Taille FFT

Contrôle la résolution de fréquence dans le spectrogramme.

### Carte des couleurs

Choisissez **Viridis**, **Magma** ou **Grayscale**.

### Durée (vitesse de défilement)

Contrôle la durée visible dans la fenêtre du spectrogramme.

### Gamme de fréquences

Définit la fréquence d’affichage supérieure.

### Log d'amplitude

Applique une mise à l'échelle logarithmique au spectrogramme pour une lecture visuelle plus facile.

## Enregistrement

###Mode

- **Full** — sauvegardez tout l'enregistrement
- **Détections uniquement** : enregistrez les clips autour des détections
- **Désactivé** — pas d'enregistrement audio

### Contexte du clip

Lorsque **Détections uniquement** est actif, l'application affiche un seul curseur **Contexte du clip** (0 à 5 s) qui définit la quantité d'audio préservée des **deux côtés** de chaque détection. Chaque clip a une longueur de « fenêtre d'analyse + 2 × contexte de clip », donc avec une fenêtre d'analyse de 3 s et le contexte par défaut de 1 s, le clip enregistré dure 5 s. Définir le contexte sur 2 s donne un clip de 7 s (2 s de pré-roll + 3 s d'audio analysé + 2 s de post-roll). Des valeurs plus élevées vous donnent plus de place pour une inspection visuelle ou des outils de révision externes au détriment de l'espace disque ; 0 enregistre uniquement la fenêtre analysée elle-même.

###Format

Choisissez **WAV** ou **FLAC**.

## Emplacement

### Utiliser le GPS

Utilisez le GPS de l'appareil au lieu des coordonnées manuelles.

### Latitude/Longitude

Coordonnées manuelles utilisées lorsque le GPS est désactivé.

### Filtre d'espèce

- **Désactivé** — pas de filtrage géographique
- **Filtre de localisation** — exclut les espèces qui se situent en dessous du seuil géographique
- **Pondération de localisation** — utilisez le géomodèle comme signal de pondération supplémentaire

### Seuil de géofiltrage

Apparaît lorsqu'un mode de filtrage basé sur l'emplacement est actif.

## Exporter et synchroniser

###Format

Choisissez une cible d'exportation :

- Tableau de sélection du Corbeau
- CSV
-JSON
- GPX (trace + waypoints)

### Inclure les fichiers audio

Incluez l'audio enregistré aux côtés des tables ou métadonnées exportées lorsque cela est pris en charge par le flux de travail d'exportation.

## À propos

La ligne **À propos** ouvre l'écran À propos de l'application.

## Zone dangereuse

### Réinitialiser l'intégration

Affiche à nouveau la séquence d'intégration au prochain lancement de l'application.

### Effacer toutes les données

Ouvre un flux de confirmation pour supprimer définitivement les données d'application stockées.

## Paramètres spécifiques au workflow en dehors des paramètres

Certains paramètres sont configurés dans leurs propres écrans de configuration plutôt que dans l'écran Paramètres partagé.

- [Point Count Mode](point-count-mode.md) a sa propre configuration de durée et d'emplacement.
- [Mode enquête](survey-mode.md) possède son propre écran de paramètres d'enquête.
- [File Analysis](file-analysis.md) a sa propre étape de paramètres d'analyse.