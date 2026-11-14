# Bibliothèque de Sessions

La Bibliothèque de Sessions est l'archive des Sessions enregistrées et des fichiers traités.

## Comment l'ouvrir

Utilisez le bouton :app-libraryMusic: en bas de l'écran d'accueil.

## Ce que montre la bibliothèque

Chaque entrée de Session résume un ensemble de résultats enregistré, y compris son type, sa date, sa durée, le nombre d'espèces et le nombre de détections.

Les types de Session utilisent les mêmes icônes que l'écran d'accueil :

- :app-micRounded: — Session Live
- :app-audioFileRounded: — Fichier importé (analyse de fichiers)
- :app-locationOnRounded: — Point Count
- :app-routeRounded: — Session Survey

## Commandes de la barre supérieure

- :app-searchRounded: — recherche par date, type de Session, nom de lieu, coordonnées, nom commun ou nom scientifique
- menu du mode d'affichage — basculer entre **Détaillé**, **Compact** et **Par espèce**
- :app-filterList: — changer l'ordre de tri

## Modes d'affichage

### Détaillé

Affiche des cartes de Session complètes avec davantage de métadonnées.

### Compact

Affiche des lignes plus resserrées pour une navigation plus rapide. Chaque ligne comporte un bouton :app-expandMore: à droite qui déplie la ligne sur place pour afficher le contenu complet de la carte en vue Détaillée — pratique pour jeter un coup d'œil rapide aux statistiques d'une Session précise sans perdre votre position de défilement.

### Par espèce

Regroupe les Sessions par espèce ; chaque espèce se déplie pour afficher les Sessions qui la contiennent.

## Tri

Triez les Sessions par **date** (plus récentes ou plus anciennes d'abord), par **nom** (A–Z ou Z–A) ou par **durée** (plus longues ou plus courtes d'abord). Le tri par durée est utile pour retrouver votre relevé le plus long de la semaine, ou le plus court test de 30 secondes que vous avez enregistré par erreur.

Lorsque les Sessions sont regroupées par jour, chaque ligne d'en-tête de jour affiche d'abord le menu (:app-moreVert:) pour les actions sur toute la journée, le chevron de dépliage/repliage se trouvant à l'extrémité de la ligne. Le chevron est le *dernier* élément — même convention que toutes les autres listes dépliables de l'application — de sorte qu'un appui près du bord droit bascule toujours le groupe.

## Heure locale

Chaque horodatage affiché dans la Bibliothèque de Sessions — lignes de la liste, en-têtes de groupes par jour, badges « début » / « fin » — est rendu dans le fuseau horaire local *actuel* de votre téléphone. Les horodatages sous-jacents de la Session sont stockés en UTC : une Session réalisée à Berlin puis ouverte à New York s'affiche simplement cinq (ou six) heures plus tôt — les données sur le disque restent inchangées. Si vous voyagez pendant un long relevé, l'heure affichée suit l'appareil.

## Actions sur les lignes

Chaque ligne de Session offre deux façons d'agir dessus :

- **Menu à trois points** (:app-moreVert:) à droite de chaque carte : ouvre un petit menu avec **Ouvrir**, **Partager** et **Supprimer**. Le partage ouvre une boîte de dialogue dont les cases **Audio** et **Métadonnées** reprennent au départ les choix de Paramètres → Export et synchronisation et ne valent que pour ce partage, puis la feuille de partage du système — inutile d'ouvrir d'abord le Résumé de la Session pour envoyer une Session à un collègue.
- **Faites glisser** la ligne vers la gauche ou la droite pour la supprimer. Une boîte de dialogue de confirmation apparaît tout de même avant toute suppression : un glissement accidentel est donc récupérable.

## Que se passe-t-il ensuite

Appuyez sur une Session pour ouvrir le [Résumé de la Session](session-review.md).
