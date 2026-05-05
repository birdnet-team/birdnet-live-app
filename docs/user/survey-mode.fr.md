# Mode relevé

Le mode Relevé est le flux de travail sur transect pour les relevés mobiles de longue durée.

## Comment l'ouvrir

Depuis l'écran d'accueil, appuyez sur la carte du mode relevé avec l'icône :material-routes:.

## Flux de configuration

La configuration de l'enquête est un assistant en cinq étapes.

### 1. Détails

Vous pouvez saisir :

- nom de l'enquête
- identifiant du transect
- nom de l'observateur
- GPS, coordonnées manuelles ou aucun lieu de départ

Cette étape expose également le sélecteur de carte et le rappel d'autorisation GPS en arrière-plan si nécessaire.

### 2. Paramètres

Cette étape contient des paramètres propres au relevé, notamment :

- sélection du microphone
- taux d'inférence
- seuil de confiance
- Intervalle GPS
- durée maximale
- mode d'enregistrement
- contexte de clip pour l'enregistrement avec détection uniquement
- mode d'échantillonnage de détection
- limite du top N par espèce lorsque l'échantillonnage est limité

#### Échantillonnage de détection

Une longue enquête peut produire des milliers de détections, et l’enregistrement d’un clip audio pour chacune d’entre elles remplit rapidement l’espace de stockage. L'échantillonnage de détection contrôle **quels clips sont conservés sur le disque** — *les enregistrements de détection eux-mêmes sont toujours conservés*, de sorte que votre journal de session complet reste intact quel que soit le mode. Les enregistrements dont l'audio a été supprimé n'ont tout simplement aucun clip lisible dans Session Review.

Trois modes sont disponibles :

| Mode | Ce qu'il fait |
| --- | --- |
| **Tous** | Gardez chaque clip. Utilisation maximale du disque. Recommandé pour les enquêtes courtes ou lorsque vous souhaitez que l'audio de chaque détection soit analysé ultérieurement. |
| **Haut N** | Conservez uniquement les **N clips ayant le niveau de confiance le plus élevé par espèce**. Les autres clips sont supprimés au fur et à mesure du relevé. La valeur par défaut de N est 10, configurable de 1 à 50. |
| **Intelligent** | Même plafond de N par espèce que Top N, **plus** distribution spatiale : si une nouvelle détection atterrit au même « endroit » qu'un clip déjà conservé (à environ 500 m et ~ 2 min l'un de l'autre), seul celui avec le niveau de confiance le plus élevé conserve son clip. Cela empêche un chanteur stationnaire de monopoliser tous les N créneaux et oriente les clips conservés vers la couverture du transect complet. |

La limite N est **par espèce, et non globale** — si vous enregistrez 10 merles et 10 pinsons, vous conservez 20 clips. Il n’y a pas de limite globale au nombre de clips qu’une enquête peut produire.

En mode Smart, si le GPS manque lors d'une détection, la vérification au même endroit revient à une fenêtre temporelle uniquement (~ 2 min). Avec le GPS disponible, la distance et le temps doivent se chevaucher pour que deux détections comptent comme le même point.

### 3. Alertes sur les espèces

Notifications qui se déclenchent en cours de relevé lorsqu'une détection mérite votre attention. Choisissez un mode :

- **Désactivé** — aucune alerte (par défaut).
- **Première session** — une alerte la première fois que chaque espèce est entendue au cours de cette enquête.
- **Toute première** — alerte uniquement lorsque l'application rencontre une espèce pour la première fois sur l'ensemble de vos sessions. Cette option s'appuie sur un historique global des espèces, automatiquement constitué à partir de vos sessions existantes au premier lancement.
- **Rare pour cet emplacement** — alerte lorsque la probabilité du géo-modèle pour la position actuelle passe sous un seuil configurable. Un texte d'aide affiché sous le curseur indique précisément ce que déclenchera la valeur choisie, par exemple *"Alerter pour les espèces dont la probabilité est inférieure à 5 % à cet endroit."*.
- **Liste de suivi** — alerte uniquement pour les espèces ajoutées à une liste personnalisée enregistrée. Cette étape permet de créer de nouvelles listes, de modifier les listes existantes dans un éditeur plein écran avec taxonomie consultable et *Importer à partir d'un fichier* (tout fichier `.txt` ou `.csv` de noms scientifiques), puis de supprimer les listes devenues inutiles.

Un curseur *Confiance minimale* se trouve sous le sélecteur de mode et est automatiquement aligné sur le seuil de confiance de la session, car les alertes ne sont jamais plus sensibles que les détections elles-mêmes. La section **Avancé** donne accès aux contrôles de limitation : délai de grâce au démarrage, intervalle minimal strict entre deux alertes et plafond glissant par minute, avec possibilité de regrouper les alertes excédentaires dans une notification récapitulative unique. La première fois que vous passez à un mode autre que **Désactivé**, l'assistant vous demande l'autorisation d'envoyer des notifications Android.

### 4. Conseils sur le terrain

Une courte liste de contrôle de pré-démarrage dans le flux de configuration.

### 5. Prêt

L'écran prêt résume la configuration d'enquête active avant de commencer avec :material-play:.

## Tableau de bord de l'enquête en direct

L'écran Enquête en direct comporte trois onglets principaux ainsi qu'une liste de détections récentes.

### Barre supérieure

- :material-stop: — terminer l'enquête
- :material-timer: — temps écoulé
- :material-help-circle-outline : — ouvre la feuille d'aide à l'enquête
- :material-tune : — ouvre les paramètres de l'enquête

### Onglets

- :material-map-outline: — carte d'itinéraire et détections cartographiées
- :material-equalizer: — spectrogramme
- icône de graphique - statistiques récapitulatives et répartition des espèces

### Statistiques et détections

Sous le contenu de l'onglet, le tableau de bord de l'enquête affiche une barre de statistiques et une liste de détections récentes. Appuyer sur une détection ouvre la superposition des détails de l’espèce.

## Opération en arrière-plan

Le mode Enquête maintient une notification persistante au premier plan visible pendant l'enregistrement afin qu'Android ne suspende pas le pipeline audio. La notification se développe pour afficher :

- le temps écoulé, le nombre de détections, le nombre d'espèces et la distance parcourue, et
- les **trois espèces uniques les plus récentes** avec leur niveau de confiance et un horodatage relatif (« à l'instant », « il y a 42 s », « il y a 5 min », « il y a 2 h »).

La notification (titre, détections récentes et pied de page des statistiques) est entièrement traduite dans la langue sélectionnée de l'application et utilise les mêmes paramètres régionaux d'espèce et les mêmes préférences *Afficher les noms scientifiques* que les cartes intégrées à l'application.

Les alertes d'espèces (lorsqu'elles sont activées) apparaissent sur un canal de notification Android distinct afin que vous puissiez désactiver les alertes indépendamment de la notification d'enregistrement silencieux en cours. L'icône d'alerte correspond à l'icône de notification au premier plan (un oiseau monochrome) et les corps d'alerte affichent uniquement la *raison* — *"Première détection de cette enquête"*, *"Sur votre liste de surveillance"*, *"Détecté à cet endroit avec moins de 4 % de probabilité"* — laissant le nom de l'espèce dans le titre de notification en gras là où Android le rend le plus grand.

## Après l'arrêt

BirdNET Live enregistre l'enquête terminée et ouvre [Session Review](session-review.md).
