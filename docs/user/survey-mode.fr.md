# Mode Survey

Le mode Survey est le mode itinérant de BirdNET Live, destiné aux relevés mobiles de longue durée.

## Comment l'ouvrir

Depuis l'accueil, appuyez sur la carte **Mode Survey** avec l'icône :app-routeRounded:.

## Configuration

La configuration du Survey est un assistant en cinq étapes.

### 1. Détails

Vous pouvez saisir :

- le nom du Survey
- l'identifiant du transect
- le nom de l'observateur
- le GPS :app-myLocation:, des coordonnées manuelles :app-editLocationAlt: ou aucun point de départ :app-locationOff:. Le sélecteur de carte utilise :app-mapSheet:.

Cette étape donne aussi accès au sélecteur de carte, actualise le GPS lorsque
vous revenez des écrans d'autorisation du système et affiche le rappel
d'autorisation du GPS en arrière-plan si nécessaire. Une carte météo est
disponible dans la même zone de localisation. Si l'accès à la météo est
désactivé, elle demande le consentement **Autoriser la recherche météo** ; une
fois activée, elle donne un aperçu du site avec une icône météo, la température
et le vent uniquement. Le même instantané Open-Meteo mis en cache est réutilisé
lors de l'enregistrement du relevé.

L'assistant mémorise le choix de localisation du dernier Survey lancé. Le nom et les coordonnées repartent de zéro à chaque fois.

### 2. Paramètres

Cette étape contient des paramètres propres à Survey, tels que :

- la sélection du microphone
- la fréquence d'inférence
- le seuil de confiance
- l'intervalle GPS
- la durée maximale
- le mode d'enregistrement
- le contexte de l'extrait lorsque seuls des extraits sont enregistrés
- le mode d'échantillonnage des détections
- la limite Top N par espèce lorsque l'échantillonnage est limité

| Commande de configuration | Icône |
|---|---|
| Microphone | :app-micRounded: |
| Fréquence d'inférence | :app-speedRounded: |
| Seuil de confiance | :app-verifiedRounded: |
| Intervalle GPS | :app-myLocation: |
| Durée maximale | :app-timerOutlined: |
| Enregistrement | :app-fiberManualRecordRounded: |
| Contexte de l'extrait | :app-timerOutlined: |
| Échantillonnage des détections | :app-filterAltRounded: |
| Top N par espèce | :app-formatListNumberedRounded: |

Touchez le bouton :app-helpOutline: à côté d'une commande de configuration pour afficher une explication. Les champs nom, transect, observateur, localisation et alertes ont aussi des boutons d'aide.

Les nouvelles configurations Survey utilisent une inférence de **0,70 Hz** par
défaut. Cela conserve davantage de vocalisations brèves que les options plus
économes, tout en faisant tourner le modèle moins souvent qu'à 1,00 Hz.
Survey et Live Mode partagent la même planification d'inférence et la même
définition d'une détection : à paramètres d'inférence identiques, les deux
signalent les mêmes espèces, les mêmes scores et les mêmes durées de détection
pour un même son. Les fréquences plus basses laissent volontairement des
écarts plus larges entre les fenêtres d'analyse qui se chevauchent et peuvent
donc manquer des sons brefs ; 0,30 Hz reste disponible lorsque l'autonomie est
prioritaire.

#### Échantillonnage des détections

Un long relevé peut produire des milliers de détections, et enregistrer un extrait audio pour chacune remplit vite l'espace de stockage. L'échantillonnage des détections détermine **quels extraits sont conservés sur le disque** — *les données de détection elles-mêmes sont toujours conservées*, de sorte que votre journal de Session complet reste intact quel que soit le mode. Les détections dont l'audio a été supprimé n'ont simplement aucun extrait lisible dans le Résumé de la Session.

Trois modes sont disponibles :

| Mode | Ce qu'il fait |
|---|---|
| **Toutes** | Conserve tous les extraits. Utilisation maximale du disque. Recommandé pour les relevés courts ou lorsque vous souhaitez disposer de l'audio de chaque détection pour une analyse ultérieure. |
| **Top N** | Conserve uniquement les **N extraits ayant la confiance la plus élevée par espèce**. Les autres extraits sont supprimés au fur et à mesure du relevé. La valeur N par défaut est 10, configurable de 1 à 50. |
| **Smart** | Même plafond de N par espèce que Top N, **plus** une distribution spatiale : si une nouvelle détection se situe au même « endroit » qu'un extrait déjà conservé (à environ 250 m et 2 min l'un de l'autre), seul celui ayant la confiance la plus élevée conserve son extrait. Cela évite qu'un chanteur stationnaire monopolise les N créneaux et oriente les extraits conservés vers une couverture du transect entier. |

La limite N est **par espèce, pas globale** — si vous enregistrez 10 rougegorges et 10 pinsons, vous conservez 20 extraits. Il n'y a aucune limite globale au nombre d'extraits qu'un relevé peut produire.

En mode Smart, si le GPS manque sur une détection, la vérification « même endroit » se rabat sur une fenêtre temporelle uniquement (environ 2 min). Avec le GPS disponible, la distance et le temps doivent tous deux se chevaucher pour que deux détections comptent comme le même endroit.

### 3. Alertes d'espèces

Des notifications de type push qui se déclenchent en cours de relevé lorsqu'une espèce notable est détectée. Choisissez l'une des options suivantes :

- **Désactivé** — aucune alerte (par défaut).
- **Première de la Session** — une alerte à la première détection de chaque espèce pendant ce relevé.
- **Toute première** — alerter uniquement lorsque l'application rencontre une espèce pour la toute première fois sur l'ensemble de vos Sessions (une alerte « lifer »). S'appuie sur un historique des espèces sur la durée, renseigné automatiquement à partir de vos Sessions existantes au premier lancement.
- **Rare ici** — alerter lorsque la probabilité du géo-modèle pour la position actuelle est inférieure à un seuil configurable. Un affichage en direct sous le curseur explique exactement ce qui déclenchera la valeur actuelle (par exemple *« Alerte pour les espèces dont la probabilité à cet endroit est inférieure à 5 %. »*).
- **Liste de suivi** — alerter uniquement sur les espèces que vous avez ajoutées à une liste personnalisée enregistrée. L'étape de l'assistant permet de créer de nouvelles listes de suivi, de modifier celles existantes dans un éditeur plein écran dédié avec taxonomie consultable et *Importer depuis un fichier* (n'importe quel fichier `.txt`/`.csv` simple de noms scientifiques), et de supprimer les listes dont vous n'avez plus besoin.

Un curseur *Confiance minimale* se trouve sous le sélecteur de mode et ne peut pas descendre sous le seuil de confiance de votre Session (les alertes ne sont jamais plus sensibles que les détections elles-mêmes). Une section **Avancé** donne accès à la limitation de la fréquence — un délai de démarrage, un intervalle minimum strict entre deux alertes et un plafond glissant par minute, avec regroupement facultatif des alertes en excès dans une seule notification récapitulative — le tout réglable d'un seul appui. La première fois que vous passez à un mode autre que Désactivé, l'assistant demande pour vous l'autorisation de notification Android.

### 4. Conseils de terrain

Une courte liste de vérification avant le départ, intégrée à la configuration.

### 5. Prêt

L'écran « Prêt » récapitule la configuration active du relevé avant de démarrer avec :app-playArrowRounded:.

## Tableau de bord du Survey

Le tableau de bord du Survey comporte trois onglets principaux ainsi qu'une liste des détections récentes.

### Barre supérieure

- :app-stopRounded: — terminer le relevé
- :app-timerOutlined: — temps écoulé
- :app-helpOutlineRounded: — ouvrir l'aide du tableau de bord du Survey
- :app-tuneRounded: — ouvrir les paramètres de Survey

### Onglets

- :app-map: — carte de l'itinéraire et détections cartographiées
- :app-graphicEq: — spectrogramme
- icône de graphique — statistiques récapitulatives et répartition des espèces

### Statistiques et détections

Sous le contenu de l'onglet, le tableau de bord du Survey affiche une barre de statistiques et une liste des détections récentes. Toucher une détection ouvre la fiche détaillée de l'espèce.

Chaque ligne de détection donne aussi accès aux mêmes actions par détection que dans le [Résumé de la Session](session-review.md) : une coche :app-checkCircleOutline: **Confirmer** d'un seul appui et un menu :app-moreVert: **Plus** avec **Partager la détection** et **Supprimer la détection** (avec annulation par notification) — vous pouvez ainsi valider, partager ou supprimer une détection bruitée en pleine capture, sans attendre le Résumé de la Session.

Les mêmes actions sont disponibles depuis la **carte de l'itinéraire en direct** : appuyez sur un marqueur de détection pour ouvrir le lecteur d'extraits avec confirmation, partage et suppression. Le partage pendant un relevé fonctionne même si vous avez choisi un seul enregistrement WAV continu au lieu d'extraits par détection — la fenêtre audio correspondante est extraite à la volée du fichier en cours. Voir [Résumé de la Session → Partage d'une seule détection](session-review.md#partage-dune-seule-détection) pour plus de détails.

### Enregistrer une observation

Le bouton :app-addCircleOutline: du Survey en cours ouvre un petit menu avec **Ajouter une espèce** et **Ajouter une note**. **Ajouter une espèce** ouvre le même sélecteur que le [Résumé de la Session](session-review.md#ajouter-une-espèce-à-la-main) : choisissez une espèce, puis cochez :app-hearing: **Entendu** et/ou :app-visibility: **Vu** dans le panneau de confirmation et touchez **Ajouter**. L'entrée est horodatée à cet instant, associée au point GPS courant, et apparaît immédiatement dans la liste des détections et sur la carte de l'itinéraire, avec le badge « Manuelle » et les icônes oreille / œil correspondantes.

Les mémos vocaux sont volontairement absents ici : le microphone est occupé par la capture du Survey. Ajoutez-les dans le Résumé de la Session une fois le Survey terminé.

## Fonctionnement en arrière-plan

Le mode Survey garde une notification persistante de premier plan visible pendant l'enregistrement pour qu'Android ne suspende pas le pipeline audio. La notification se déplie pour afficher :

- le temps écoulé, le nombre de détections, le nombre d'espèces et la distance parcourue, et
- les **trois espèces distinctes les plus récentes** avec leur confiance et un horodatage relatif (« à l'instant », « il y a 42 s », « il y a 5 min », « il y a 2 h »).

La notification — titre, détections récentes et pied de statistiques — est entièrement traduite dans la langue sélectionnée de l'application et utilise les mêmes préférences de langue des espèces et *Afficher les noms scientifiques* que les cartes d'espèces dans l'application.

Les alertes d'espèces (lorsqu'elles sont activées) apparaissent sur un canal de notification Android distinct, afin que vous puissiez les couper indépendamment de la notification silencieuse d'enregistrement en cours. L'icône d'alerte correspond à celle de la notification de premier plan (un oiseau monochrome), et le corps des alertes n'affiche que la *raison* — *« Première détection de ce relevé »*, *« Sur votre liste de suivi »*, *« Rare ici (4 % a priori) »* — en laissant le nom de l'espèce dans le titre en gras, là où Android l'affiche le plus grand.

Lorsque vous **reprenez** un relevé inachevé depuis la Bibliothèque de Sessions, le système d'alertes est réarmé à partir de vos préférences de notification *actuelles* — et non de celles configurées le jour où vous avez commencé le relevé. Désactivez les alertes (ou changez le mode, la liste de suivi ou la limitation de fréquence) avant d'appuyer sur Reprendre, et le relevé repris respectera immédiatement les nouveaux paramètres.

## Vérification sur la carte

La vue carte plein écran du relevé (le bouton :app-fullscreen: dans le Résumé de la Session) ouvre un lecteur d'extraits lorsque vous appuyez sur un marqueur. La barre de lecture comporte des boutons précédent et suivant de part et d'autre de la commande de lecture — ils parcourent les détections par ordre chronologique, mais **uniquement celles actuellement visibles sur la carte** : tout filtre actif d'espèce, de confiance ou de mode restreint donc la liste de lecture en conséquence. Les boutons se grisent à la première et à la dernière détection de la liste filtrée.

## Après l'arrêt

BirdNET Live enregistre le relevé terminé et ouvre le [Résumé de la Session](session-review.md).

Le relevé en cours est enregistré au démarrage, toutes les 30 secondes et lorsque l'application quitte le premier plan. Après un plantage ou une coupure de courant, le dernier relevé partiel apparaît dans la Bibliothèque de Sessions comme une Session terminée. L'enregistrement ne redémarre pas. Les observations postérieures à la dernière sauvegarde peuvent manquer.
