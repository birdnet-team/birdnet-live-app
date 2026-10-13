# Icônes et contrôles

Cette page explique les contrôles et symboles récurrents utilisés dans BirdNET Live. Les étiquettes ci-dessous correspondent exactement aux contrôles tels qu'ils apparaissent dans l'application.

## Icônes des modes

Ces icônes ont les mêmes formes que dans l’application. Ici, elles prennent la couleur du texte ; les couleurs de l’application varient selon le thème, les couleurs dynamiques et le contraste élevé.

- :app-micRounded: **En direct**
- :app-locationOnRounded: **Point d'écoute**
- :app-routeRounded: **Relevé**
- :app-timerRounded: **Mode ARU**
- :app-audioFileRounded: **Analyse de fichiers**
- :app-sdStorage: **Analyse par lots** (Prochainement)

## Contrôles de navigation partagés

| Contrôle | Où le voir | Ce qu'il fait |
|---|---|---|
| :app-tuneRounded: **Paramètres** | Bas de l'accueil, En direct, Point d'écoute, Relevé, Analyse de fichiers, Résumé de la session | Ouvre les Paramètres. Dans les écrans de mode, il ouvre les paramètres les plus pertinents pour ce type de travail. |
| :app-searchRounded: **Explorer** | Bas de l'accueil | Ouvre Explorer. |
| :app-libraryMusic: **Bibliothèque** | Bas de l'accueil | Ouvre la Bibliothèque de sessions. |
| :app-helpOutlineRounded: **Aide** | Bas de l'accueil, en-tête Explorer, tableau de bord du relevé, barre d'outils du Résumé de la session | Ouvre l'Aide ou une fiche d'aide propre à l'écran. |
| :app-infoOutline: **Info / À propos** | Bas de l'accueil, barres d'informations, fiches d'aide | Affiche des informations générales ou un contexte récapitulatif. |
| :app-arrowBackRounded: **Retour** | Mode En direct | Revient à l'écran précédent. |
| :app-openInNew: **Ouvrir en externe** | Écran À propos, liens de documentation | Ouvre une page externe, comme le Guide de l'utilisateur en ligne. |
| :app-arrowUpwardRounded: **Retour en haut** | Écran d’aide | Revient à l’introduction et aux raccourcis des sections. Apparaît après avoir fait défiler la page. |
| :app-volunteerActivism: **Faire un don** | Écran À propos | Ouvre la page de don de BirdNET. |

## Symboles météo

| Contrôle | Signification |
|---|---|
| :app-wbSunny: **Dégagé** | Ciel dégagé. |
| :app-partlyCloudyDay: **Partiellement nuageux** | Soleil et nuages pour un temps plutôt dégagé ou partiellement nuageux. |
| :app-cloudy: **Couvert** | Couverture nuageuse complète. |
| :app-foggy: **Brouillard** | Brouillard ou brouillard givrant. |
| :app-rainyLight: **Bruine** | Précipitations légères. |
| :app-rainy: **Pluie** | Pluie ou averses. |
| :app-weatherSnowy: **Neige** | Neige ou averses de neige. |
| :app-thunderstorm: **Orage** | Conditions orageuses. |

## Contrôles de démarrage, d'arrêt et de session

| Contrôle | Signification |
|---|---|
| :app-micRounded: **Micro** | Démarrer l'écoute en direct. |
| :app-stopRounded: **Arrêter** | Arrêter un enregistrement, un point d'écoute ou un relevé en cours. |
| :app-playArrowRounded: **Lecture** | Démarrer un flux de configuration prêt ou reprendre depuis un état en pause. |
| :app-close: **Fermer** / :app-stop: **Annuler** | Annuler une analyse de fichiers en cours depuis l'en-tête ou l'écran de progression. |
| :app-timerOutlined: **Minuteur** | Durée ou temps restant. |
| :app-errorOutline: **Erreur** | Erreur du modèle ou du traitement. |

## Contrôles de localisation et de date

| Contrôle | Signification |
|---|---|
| :app-myLocation: **Position actuelle** | Utiliser la position GPS actuelle de l'appareil. |
| :app-editLocationAlt: **Coordonnées manuelles** | Saisir les coordonnées manuellement. |
| :app-locationOff: **Aucune localisation** | Ignorer la localisation ou indiquer qu'elle n'est pas disponible. |
| :app-locationOn: **Localisation présente** | Confirmer une localisation, afficher les coordonnées ou étiqueter une session cartographiée. |
| :app-refresh: **Actualiser** | Relire la position actuelle ou actualiser une liste de prédictions. |
| :app-mapSheet: **Sélecteur de carte** | Choisir les coordonnées dans le sélecteur de carte. |
| :app-calendarToday: **Date** | Définir ou afficher une date. |
| :app-clear: **Effacer** | Supprimer une date sélectionnée. |

## Symboles d'Explorer et des espèces

| Contrôle | Signification |
|---|---|
| Vignette de l'espèce | Image fournie pour l'espèce lorsqu'elle est disponible. |
| Badge de pourcentage de confiance ou du géo-modèle | Un résumé numérique rapide de la sortie du modèle. Des valeurs plus élevées indiquent un appui plus fort dans le contexte de cet écran. |
| Étiquettes mensuelles (`Jan`, `Apr`, `Jul`, `Oct`, `Dec`) | Points de repère sur le graphique hebdomadaire des fréquences attendues dans le panneau des espèces. |

## Actions par détection

Ces contrôles apparaissent sur chaque ligne de détection dans l'application — liste des espèces du Résumé de la session, lecteur de clips, liste des détections du relevé en direct et marqueurs de la carte du relevé. Voir [Résumé de la session → Actions par détection](session-review.md#actions-par-détection) pour le comportement complet.

| Contrôle | Signification |
|---|---|
| :app-checkCircleOutline: **Confirmer** | Coche en un toucher qui marque une détection comme vérifiée visuellement ou acoustiquement. Les détections confirmées affichent une petite coche verte sur les lignes groupées et les marqueurs de carte. |
| :app-moreVert: **Plus** | Ouvre le menu par détection avec **Partager la détection**, **Remplacer l'espèce**, **Supprimer la détection** et **Supprimer l'espèce**. |
| :app-share: **Partager la détection** | Partage une détection via la feuille de partage du système, en joignant le clip audio lorsqu'il est disponible — y compris un extrait de l'enregistrement en cours pendant un relevé en direct. |
| :app-swapHoriz: **Remplacer l'espèce** | Choisir une autre espèce pour cette détection. S'ouvre aussi en faisant glisser une ligne vers la gauche. |
| :app-deleteOutline: **Supprimer la détection** | Supprime immédiatement la ligne. Une notification d'annulation apparaît quelques secondes. Se déclenche aussi en faisant glisser une ligne vers la droite. |
| :app-deleteSweep: **Supprimer l'espèce** | Supprime en une seule fois toutes les détections de cette espèce dans la session, avec la même possibilité d'annulation. |
| :app-hearing: **Entendu** | Sur une détection ajoutée à la main : vous avez entendu l'oiseau. Défini par la case de la fiche de confirmation affichée après le choix de l'espèce. |
| :app-visibility: **Vu** | Sur une détection ajoutée à la main : vous avez vu l'oiseau. Les deux icônes ensemble signifient entendu *et* vu. |

## Barre d'outils du Résumé de la session

Ces contrôles sont utilisés sur l'écran Résumé de la session.

| Contrôle | Signification |
|---|---|
| :app-addCircleOutline: **Ajouter** | Ajouter du contenu, comme une espèce ou une annotation. |
| :app-undo: **Annuler** / :app-redo: **Rétablir** | Reculer ou avancer dans les modifications de révision. |
| :app-contentCut: **Rogner** | Entrer en mode rognage ou indiquer que le mode rognage est actif. |
| :app-save: **Enregistrer** | Enregistrer les modifications de la révision. |
| :app-share: **Partager** | Exporter ou partager la session. |
| :app-deleteOutline: **Supprimer** | Supprimer la session. |
| :app-playArrowRounded: **Reprendre** | Reprendre un relevé inachevé depuis le Résumé de la session lorsque cette action est disponible. |

## Barres d'état spécifiques à l'écran

### Mode En direct

La barre d'informations du mode En direct utilise :app-infoOutline: suivi d'étiquettes compactes telles que :

- `now` — détections actuellement visibles dans la liste en direct
- `spp` — nombre d'espèces uniques
- `det` — nombre total de détections
- durée et taille estimée de l'enregistrement lorsque l'enregistrement est actif

### Point d'écoute

La barre de minuteur du point d'écoute combine :app-stopRounded: **Arrêter**, :app-timerOutlined: **Minuteur** et une barre de progression pour afficher le temps restant de la session minutée.

### Relevé

Le tableau de bord du relevé utilise :

- :app-map: **Carte** — onglet de la carte en direct
- :app-graphicEq: **Spectrogramme** — onglet spectrogramme
- :app-summaryChart: **Résumé** — onglet Résumé
- :app-summaryChart: étiquettes de statistiques dans la vue récapitulative du relevé

## En cas de doute

Si vous n'êtes pas sûr de la fonction d'un contrôle, ouvrez la fiche d'aide la plus proche dans l'application, ou consultez la page de ce guide consacrée à cet écran.
