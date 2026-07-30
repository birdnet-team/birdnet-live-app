# Mode Relevé

Le mode Relevé est le flux de travail basé sur l'itinéraire, destiné aux relevés mobiles de longue durée.

## Comment l'ouvrir

Depuis l'accueil, appuyez sur la carte **Mode Relevé** avec l'icône :material-routes:.

## Flux de configuration

La configuration du relevé est un assistant en cinq étapes.

### 1. Détails

Vous pouvez saisir :

- le nom du relevé
- l'identifiant du transect
- le nom de l'observateur
- le GPS, des coordonnées manuelles ou aucun point de départ

Cette étape donne aussi accès au sélecteur de carte, actualise le GPS lorsque
vous revenez des écrans d'autorisation du système et affiche le rappel
d'autorisation du GPS en arrière-plan si nécessaire. Une carte météo est
disponible dans la même zone de localisation. Si l'accès à la météo est
désactivé, elle demande le consentement **Autoriser la recherche météo** ; une
fois activée, elle donne un aperçu du site avec une icône météo, la température
et le vent uniquement. Le même instantané Open-Meteo mis en cache est réutilisé
lors de l'enregistrement du relevé.

### 2. Paramètres

Cette étape contient des paramètres propres au Relevé, tels que :

- la sélection du microphone
- la fréquence d'inférence
- le seuil de confiance
- l'intervalle GPS
- la durée maximale
- le mode d'enregistrement
- le contexte du clip pour l'enregistrement des détections uniquement
- le mode d'échantillonnage des détections
- la limite Top N par espèce lorsque l'échantillonnage est limité

#### Échantillonnage des détections

Un long relevé peut produire des milliers de détections, et enregistrer un clip audio pour chacune remplit vite l'espace de stockage. L'échantillonnage des détections contrôle **quels clips sont conservés sur le disque** — *les enregistrements de détection eux-mêmes sont toujours conservés*, de sorte que votre journal de session complet reste intact quel que soit le mode. Les détections dont l'audio a été supprimé n'ont simplement aucun clip lisible dans le Résumé de la session.

Trois modes sont disponibles :

| Mode | Ce qu'il fait |
|---|---|
| **Toutes** | Conserve tous les clips. Utilisation maximale du disque. Recommandé pour les relevés courts ou lorsque vous souhaitez disposer de l'audio de chaque détection pour une analyse ultérieure. |
| **Top N** | Conserve uniquement les **N clips ayant la confiance la plus élevée par espèce**. Les autres clips sont supprimés au fur et à mesure du relevé. La valeur N par défaut est 10, configurable de 1 à 50. |
| **Smart** | Même plafond de N par espèce que Top N, **plus** une distribution spatiale : si une nouvelle détection se situe au même « endroit » qu'un clip déjà conservé (à environ 500 m et 2 min l'un de l'autre), seul celui ayant la confiance la plus élevée conserve son clip. Cela évite qu'un chanteur stationnaire monopolise les N créneaux et oriente les clips conservés vers une couverture du transect entier. |

La limite N est **par espèce, pas globale** — si vous enregistrez 10 rougegorges et 10 pinsons, vous conservez 20 clips. Il n'y a aucune limite globale au nombre de clips qu'un relevé peut produire.

En mode Smart, si le GPS manque sur une détection, la vérification « même endroit » se rabat sur une fenêtre temporelle uniquement (environ 2 min). Avec le GPS disponible, la distance et le temps doivent tous deux se chevaucher pour que deux détections comptent comme le même endroit.

### 3. Alertes d'espèces

Des notifications de type push qui se déclenchent en cours de relevé lorsqu'une espèce notable est détectée. Choisissez l'une des options suivantes :

- **Désactivé** — aucune alerte (par défaut).
- **Première de la session** — une alerte à la première détection de chaque espèce pendant ce relevé.
- **Toute première** — alerter uniquement lorsque l'application rencontre une espèce pour la toute première fois sur l'ensemble de vos sessions (une alerte « lifer »). S'appuie sur un historique des espèces sur la durée, renseigné automatiquement à partir de vos sessions existantes au premier lancement.
- **Rare ici** — alerter lorsque la probabilité du géo-modèle pour la position actuelle est inférieure à un seuil configurable. Un affichage en direct sous le curseur explique exactement ce qui déclenchera la valeur actuelle (par exemple *« Alerte sur les espèces avec moins de 5 % de probabilité à cet endroit. »*).
- **Liste de suivi** — alerter uniquement sur les espèces que vous avez ajoutées à une liste personnalisée enregistrée. L'étape de l'assistant permet de créer de nouvelles listes de suivi, de modifier celles existantes dans un éditeur plein écran dédié avec taxonomie consultable et *Importer depuis un fichier* (n'importe quel fichier `.txt`/`.csv` simple de noms scientifiques), et de supprimer les listes dont vous n'avez plus besoin.

Un curseur *Confiance minimale* se trouve sous le sélecteur de mode et est automatiquement plafonné à votre seuil de confiance de session (les alertes ne sont jamais plus sensibles que les détections elles-mêmes). Une section **Avancé** donne accès aux contrôles de fréquence — un délai de démarrage, un intervalle minimum strict entre deux alertes et un plafond glissant par minute, avec regroupement facultatif des alertes en excès dans une seule notification récapitulative — le tout avec des sélecteurs en un toucher. La première fois que vous passez à un mode autre que Désactivé, l'assistant demande pour vous l'autorisation de notification Android.

### 4. Conseils de terrain

Une courte liste de vérification avant le départ, intégrée au flux de configuration.

### 5. Prêt

L'écran prêt récapitule la configuration active du relevé avant de démarrer avec :material-play:.

## Tableau de bord du relevé en direct

L'écran du Relevé en direct comporte trois onglets principaux ainsi qu'une liste des détections récentes.

### Barre supérieure

- :material-stop: — terminer le relevé
- :material-timer: — temps écoulé
- :material-help-circle-outline: — ouvrir la fiche d'aide du Relevé
- :material-tune: — ouvrir les paramètres du Relevé

### Onglets

- :material-map-outline: — carte de l'itinéraire et détections cartographiées
- :material-equalizer: — spectrogramme
- icône de graphique — statistiques récapitulatives et répartition des espèces

### Statistiques et détections

Sous le contenu de l'onglet, le tableau de bord du relevé affiche une barre de statistiques et une liste des détections récentes. Appuyer sur une détection ouvre le panneau de détails de l'espèce.

Chaque ligne de détection donne aussi accès aux mêmes actions par détection que dans le [Résumé de la session](session-review.md) : une coche :material-check: **Confirmer** en un toucher et un menu :material-dots-vertical: **Plus** avec **Partager la détection** et **Supprimer la détection** (avec annulation par notification) — vous pouvez ainsi valider, partager ou supprimer une détection bruitée en pleine capture, sans attendre la révision après la session.

Les mêmes actions sont disponibles depuis la **carte de l'itinéraire en direct** : appuyez sur un marqueur de détection pour ouvrir le lecteur de clips avec confirmation, partage et suppression. Le partage pendant un relevé fonctionne même si vous avez choisi un seul enregistrement WAV continu au lieu de clips par détection — la fenêtre audio correspondante est extraite à la volée du fichier en cours. Voir [Résumé de la session → Partage d'une seule détection](session-review.md#partage-dune-seule-détection) pour plus de détails.

### Enregistrer une observation

Le bouton :material-plus-circle-outline: du survey en direct ouvre un petit menu avec **Ajouter une espèce** et **Ajouter une note**. **Ajouter une espèce** ouvre le même sélecteur que [Session Review](session-review.md#ajouter-une-espece-a-la-main), choisissez une espèce, puis cochez :material-ear-hearing: **Entendu** et/ou :material-eye: **Vu** sur la fiche de confirmation et touchez **Ajouter**. L'entrée est horodatée à cet instant, associée au point GPS courant, et apparaît immédiatement dans la liste des détections et sur la carte de l'itinéraire, avec le badge « manuel » et les icônes oreille / œil correspondantes.

Les mémos vocaux sont volontairement absents ici : le microphone est occupé par la capture du survey. Ajoutez-les dans Session Review une fois le survey terminé.

## Fonctionnement en arrière-plan

Le mode Relevé garde une notification persistante de premier plan visible pendant l'enregistrement pour qu'Android ne suspende pas le pipeline audio. La notification se déplie pour afficher :

- le temps écoulé, le nombre de détections, le nombre d'espèces et la distance parcourue, et
- les **trois espèces uniques les plus récentes** avec leur confiance et un horodatage relatif (« à l'instant », « il y a 42 s », « il y a 5 min », « il y a 2 h »).

La notification — titre, détections récentes et pied de statistiques — est entièrement traduite dans la langue sélectionnée de l'application et utilise les mêmes préférences de langue des espèces et *Afficher les noms scientifiques* que les fiches dans l'application.

Les alertes d'espèces (lorsqu'elles sont activées) apparaissent sur un canal de notification Android distinct, afin que vous puissiez les couper indépendamment de la notification silencieuse d'enregistrement en cours. L'icône d'alerte correspond à celle de la notification de premier plan (un oiseau monochrome), et le corps des alertes n'affiche que la *raison* — *« Première détection de ce relevé »*, *« Sur votre liste de suivi »*, *« Détecté à cet endroit avec moins de 4 % de probabilité »* — en laissant le nom de l'espèce dans le titre en gras, là où Android l'affiche le plus grand.

Lorsque vous **reprenez** un relevé inachevé depuis la Bibliothèque de sessions, le système d'alertes est réarmé à partir de vos préférences de notification *actuelles* — et non de celles configurées le jour où vous avez commencé le relevé. Désactivez les alertes (ou changez le mode, la liste de suivi ou la limitation de fréquence) avant d'appuyer sur Reprendre, et le relevé repris respectera immédiatement les nouveaux réglages.

## Révision sur la carte

La vue carte plein écran du relevé (le bouton :material-fullscreen: dans le Résumé de la session) ouvre un lecteur de clips lorsque vous appuyez sur un marqueur. La barre de transport comporte des boutons précédent et suivant de part et d'autre de la commande de lecture — ils parcourent les détections par ordre chronologique, mais **uniquement celles actuellement visibles sur la carte** : tout filtre actif d'espèce, de confiance ou de mode restreint donc la liste de lecture en conséquence. Les boutons se grisent à la première et à la dernière détection de la liste filtrée.

## Après l'arrêt

BirdNET Live enregistre le relevé terminé et ouvre le [Résumé de la session](session-review.md).
