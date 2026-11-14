# Résumé de la Session

Le Résumé de la Session est l'endroit où BirdNET Live transforme les détections brutes en un ensemble de résultats modifiable.

## Comment y accéder

BirdNET Live ouvre automatiquement le Résumé de la Session une fois terminés :

- une Session Live
- un Point Count
- un Survey
- une analyse de fichiers

Vous pouvez aussi rouvrir n'importe quelle Session enregistrée depuis la [Bibliothèque de Sessions](session-library.md).

## Zones principales

### Résumé et lecture

Le Résumé de la Session combine la lecture, la navigation dans le spectrogramme et une liste d'espèces. Pour les Sessions Survey, il peut aussi afficher un contexte cartographique.

L'en-tête de résumé en haut de l'écran porte la date, la puce de localisation (lat/lon, plus un nom de lieu résolu lorsque **Paramètres → Confidentialité → Autoriser la recherche du nom du lieu** est activé) et — lorsque **Paramètres → Confidentialité → Autoriser la recherche météo** était activé au moment de l'enregistrement — une **ligne météo** sous la localisation affichant les conditions relevées à la fin de la Session : une ligne du type *« 20,1 °C · Pluie légère · 3,2 m/s SO »* précédée d'une icône météo. Appuyez sur la ligne pour déplier une petite fiche listant température, vent, précipitations et nébulosité, avec l'attribution Open-Meteo. Le même instantané est repris dans l'export JSON, le bloc de métadonnées par Session et le rapport HTML.

La bande de spectrogramme au-dessus du lecteur est interactive : appuyez pour vous positionner, faites glisser avec un doigt pour parcourir la chronologie, et **pincez à deux doigts pour zoomer** sur une fenêtre temporelle étroite — pratique pour examiner le minutage de cris qui se chevauchent ou décortiquer un trille rapide. Écartez à nouveau les doigts pour revenir à l'aperçu par défaut de 10 secondes. Le bouton de lecture sur l'en-tête d'une espèce choisit toujours le premier groupe qui possède réellement un extrait enregistré : le bouton est donc disponible dès qu'au moins une détection de cette espèce est lisible.

### Liste des espèces

Les espèces sont regroupées en lignes dépliables. Vous pouvez examiner les détections par espèce et parcourir l'enregistrement pendant que vous les passez en revue. Les lignes de groupe sous une espèce dépliée sont en retrait pour que la carte de l'espèce parente reste visuellement distincte de ses détections.

Un champ de recherche au-dessus de la liste filtre les espèces par nom commun ou scientifique : retrouver un oiseau précis dans une Session de 100 espèces se fait en quelques frappes plutôt qu'avec un long défilement. Le bouton :app-sort: à côté change l'ordre des espèces :

- **Confiance la plus élevée** (par défaut) — les espèces ayant la confiance la plus élevée pour une seule détection d'abord. Idéal pour trier les identifications les plus sûres. Lorsque vous dépliez une espèce dans ce mode, les détections avec un extrait audio lisible apparaissent avant celles sans extrait, puis par confiance.
- **Le plus de détections** — les espèces ayant le plus grand nombre de détections d'abord. Idéal pour repérer les chanteurs dominants.
- **A → Z** — par ordre alphabétique du nom commun. Prévisible, adapté à la langue, et facile à parcourir quand une Session comporte beaucoup d'espèces.
- **Première détection** — par ordre chronologique de première détection. La valeur par défaut historique ; utile pour suivre la chronologie du spectrogramme pendant la vérification.

Le tri choisi est conservé d'une Session à l'autre.

### Ajouter une espèce à la main

Le bouton :app-addCircleOutline: de la barre d'outils ouvre le sélecteur d'espèces pour les oiseaux que BirdNET a manqués. Toucher un résultat ne l'insère pas immédiatement : un panneau de confirmation apparaît d'abord, avec l'espèce choisie et deux cases à cocher :

- :app-hearing: **Entendu** — vous avez entendu l'oiseau.
- :app-visibility: **Vu** — vous avez vu l'oiseau.

Cochez l'une, les deux ou aucune, puis touchez **Ajouter**. **Annuler** — ou un glissement vers le bas — vous ramène à la recherche : une erreur de doigt ne coûte rien. **Entendu** est coché par défaut, et votre choix est conservé pour l'espèce suivante : une série d'oiseaux seulement vus ne demande de cocher **Vu** qu'une fois. Si vous laissez les deux vides, l'entrée est enregistrée sans type d'observation, et non comme « ni l'un ni l'autre ».

Le choix est stocké sur la détection et affiché sous forme d'une petite oreille et/ou d'un œil à côté du badge « Manuelle », partout où cette détection apparaît : en-têtes d'espèce, lignes de groupe, lecteur d'extraits et liste des détections du relevé en cours. Il se retrouve aussi dans les exports : colonne `Evidence` dans les CSV et les Raven Selection Tables, champ `evidence` en JSON, et pastille dans le rapport HTML. Le même panneau apparaît avec **Remplacer l'espèce**, prérempli avec ce que la détection portait déjà.

### Actions par détection

Partout où une détection apparaît — la liste des espèces, le lecteur d'extraits, la liste du relevé en cours et les marqueurs de la carte du relevé — le même ensemble d'actions est utilisé :

- :app-checkCircleOutline: **Confirmer** — une coche, activée d'un seul appui, qui marque une détection comme vérifiée visuellement ou acoustiquement. Les groupes et marqueurs confirmés affichent une petite coche verte pour se distinguer d'un coup d'œil, et le marqueur de confirmation est conservé dans tous les formats d'export.
- :app-moreVert: **Plus** — ouvre un menu avec :
    - :app-share: **Partager la détection** — voir *Partage* ci-dessous.
    - :app-swapHoriz: **Remplacer l'espèce** — choisir une autre espèce pour cette détection.
    - :app-deleteOutline: **Supprimer la détection** — supprime immédiatement la ligne. Une notification d'annulation apparaît quelques secondes pour rattraper les erreurs. Aucune boîte de dialogue de confirmation.
    - :app-deleteSweep: **Supprimer l'espèce** — supprime en une seule fois toutes les détections de cette espèce dans la Session, avec la même possibilité d'annulation. Pratique pour balayer une source de bruit mal identifiée sans déplier l'espèce et supprimer les groupes un par un.

#### Raccourcis par glissement dans la liste des espèces

Dans la liste des espèces, vous pouvez aussi agir sur une détection en faisant glisser la ligne horizontalement :

- glisser vers la **droite** → supprimer (avec annulation)
- glisser vers la **gauche** → ouvrir le panneau de remplacement d'espèce

Les deux arrière-plans sont codés par couleur (rouge erreur ou bleu primaire) pour que l'effet du geste soit évident avant de le confirmer.

Faire glisser une ligne d'**en-tête d'espèce** (vers la gauche ou la droite) supprime d'un coup toutes les détections de cette espèce, avec la même notification d'annulation. Pratique pour trier une Session pleine de bruits mal identifiés.

### Partage d'une seule détection

L'entrée :app-share: **Partager la détection** utilise les mêmes choix que **Paramètres → Export et synchronisation**. Elle exporte uniquement cette détection dans les fichiers Raven, CSV, JSON, GPX, HTML et métadonnées de l'application sélectionnés. Lorsque **Inclure les fichiers audio** est activé, l'archive contient aussi l'audio de la détection ; **Toujours partager l'audio en WAV** est respecté. Lorsque tous les formats, le rapport HTML et les métadonnées de l'application sont désactivés, la feuille de partage reçoit l'extrait audio brut plutôt qu'une archive ZIP.

La pièce jointe audio est résolue dans cet ordre :

1. **Pour les Sessions enregistrant un seul fichier continu** : l'audio compris entre les horodatages de début et de fin de la détection est extrait directement de l'enregistrement. Les enregistrements continus WAV et FLAC sont pris en charge ; les fichiers compressés issus de l'analyse de fichiers sont décodés en WAV.
2. Sinon, l'extrait propre à la détection est utilisé lorsqu'il est présent sur le disque.
3. Sans source audio ni fichier d'export sélectionné, le partage se réduit à un court texte avec l'espèce, la confiance, l'horodatage UTC et la position.

### Mémos vocaux

Vous pouvez joindre de courts commentaires vocaux à des détections individuelles :

- **Enregistrer** : appuyez sur le bouton :app-moreVert: d'un groupe de détection et sélectionnez **Enregistrer un mémo vocal** pour ouvrir la boîte de dialogue du mémo vocal. Appuyez sur le grand bouton du microphone pour démarrer l'enregistrement. Une forme d'onde en temps réel reflète votre voix. Appuyez sur le bouton d'arrêt lorsque vous avez terminé.
- **Réécouter** : une fois enregistré, vous pouvez écouter le mémo à l'aide du lecteur intégré. Pour remplacer le mémo, appuyez sur le bouton **Réenregistrer**. Pour l'enregistrer, appuyez sur le bouton **Enregistrer**.
- **Supprimer** : si une détection possède déjà un mémo vocal, vous pouvez le supprimer depuis le menu ou depuis la boîte de dialogue du mémo vocal.
- **Formats par plateforme** : sur Android et les autres plateformes, les mémos vocaux sont enregistrés au format AAC (`.m4a`) fortement compressé à 16 kHz. Sur iOS, ils utilisent automatiquement le format WAV/PCM16 (`.wav`) pour éviter les problèmes de compatibilité CoreAudio avec les sessions audio actives de l'application. Les deux formats sont entièrement pris en charge par l'archive ZIP d'export.
- **Export** : lors de l'export de la Session au format ZIP, les mémos vocaux sont regroupés dans le répertoire `memos/` et leurs chemins relatifs sont enregistrés dans les métadonnées JSON et CSV.

### Carte du tracé du Survey

Les Sessions Survey affichent une petite carte intégrée du tracé GPS et des marqueurs de détection. Appuyez sur un marqueur de la carte intégrée pour cibler une détection — la carte se recentre dessus. Appuyez sur le bouton :app-fullscreen: **agrandir** (en haut à droite de la carte intégrée) pour ouvrir la **carte en plein écran** ; si une détection était ciblée, la carte plein écran s'ouvre centrée et zoomée sur cette détection pour que vous gardiez votre repère.

#### Codage des marqueurs

- **La confiance est codée par couleur** avec une rampe adaptée aux daltoniens : de la confiance faible à élevée, elle va du bleu-violet au rouge en passant par le turquoise/jaune. La luminosité de la rampe varie de façon monotone pour rester lisible en monochrome et pour les personnes ayant une déficience de la vision des couleurs rouge-vert.
- **Les détections avec audio** affichent un anneau coloré autour de la photo de l'espèce, plus un badge de lecture dans le coin — appuyez dessus pour ouvrir le même lecteur d'extraits utilisé ailleurs, avec confirmation, partage, remplacement et suppression tous disponibles.
- **Les détections muettes** (aucun extrait sur le disque) s'affichent plus petites, atténuées et avec un anneau gris neutre, pour que les détections audio restent toujours le contenu principal.
- **Les marqueurs qui se chevauchent au même endroit** sont superposés par ordre d'importance : mis en évidence > audio > confiance plus élevée, de sorte qu'un marqueur muet à faible confiance ne peut jamais masquer une détection audio forte.
- **En dessous du zoom 14,5**, les silhouettes se réduisent à des points colorés dimensionnés selon la confiance, et les groupes denses se rassemblent en une bulle de comptage (le regroupement se désactive au zoom 15).

#### Filtrage

La carte plein écran dispose d'une **puce de filtre** persistante ancrée en haut à droite. Appuyez dessus pour ouvrir le panneau de filtre ; l'étiquette de la puce indique toujours ce qui est actif (*« Toutes les espèces »*, *« Avec audio »*, *« ≥ 80 % »* ou un nom d'espèce unique). Filtres disponibles :

- **Toutes les détections** (par défaut).
- **Avec extrait audio** — uniquement les détections dont l'extrait est encore sur le disque et lisible.
- **Ajouts manuels** — uniquement les détections que vous avez ajoutées dans le Résumé de la Session (exclut celles détectées automatiquement).

Vous pouvez aussi restreindre les détections par niveau de confiance. Le curseur définit le seuil minimal de confiance (commence à 10 %).

Sous le curseur de confiance se trouve un sélecteur **Limiter à une espèce** qui permet de réduire la carte à une seule espèce — utile pour savoir « où exactement le long du parcours ai-je entendu la grive des bois ? ». Une entrée *Toutes les espèces* lève la restriction d'espèce. Les filtres se combinent : par exemple *Avec extrait audio* + *Grive des bois* + *> 80 %* n'affiche que les marqueurs lisibles de Grive des bois ayant obtenu plus de 80 %.

Lorsqu'un filtre est actif, le titre de la barre supérieure gagne un sous-titre indiquant le nombre de correspondances (par exemple *« 7 détections »*). *Réinitialiser* dans le panneau ramène à l'état par défaut.

## Icônes de la barre d'outils

La barre d'outils utilise les mêmes significations d'icônes que celles décrites dans [Icônes et commandes](icons-and-controls.md) :

- :app-addCircleOutline: — ajouter du contenu
- :app-undo: / :app-redo: — parcourir les modifications
- :app-contentCut: — mode rognage
- :app-save: — enregistrer les modifications
- :app-share: — exporter ou partager
- :app-deleteOutline: — supprimer la Session
- :app-playArrowRounded: — reprendre un Survey lorsque cette action est disponible
- :app-helpOutlineRounded: — ouvrir le panneau d'aide du Résumé de la Session
- :app-tuneRounded: — ouvrir les Paramètres

## Tâches de vérification courantes

- vérifier les détections en regard de la lecture et du contexte du spectrogramme
- ajouter une espèce ou une annotation
- rogner l'enregistrement à l'intervalle utile
- exporter l'ensemble de résultats vérifié

## Export

Le comportement d'export dépend des options choisies dans les [Paramètres](settings.md). L'application peut regrouper les détections et, si vous le souhaitez, l'audio dans les formats d'export choisis. Chaque export est accompagné de métadonnées de provenance — version de l'application, nom et version du modèle, version de la taxonomie, langue des espèces, horodatage de l'export, paramètres conservés avec la Session, ainsi que les options d'export pertinentes — écrites dans un fichier annexe `<prefix>.metadata.json` (ZIP) ou un bloc `meta` de premier niveau (JSON), afin que les exports soient auto-descriptifs et reproductibles.

Chaque détection exportée porte aussi le BirdNET ID de son espèce (par exemple `BN07148`), l'identifiant de cette espèce dans la taxonomie BirdNET : colonne `BirdNET ID` juste après `Scientific Name` dans les CSV et les Raven Selection Tables, champ `birdnetId` en JSON, extension du point en GPX, et mention sur la fiche de l'espèce dans le rapport HTML. L'identifiant est recherché au moment de l'export ; les Sessions enregistrées avec des versions antérieures de l'application le reçoivent donc aussi, même si un nom scientifique a changé depuis. Il reste vide pour les entrées que la taxonomie ne connaît pas, par exemple une espèce que vous avez saisie vous-même. Un identifiant n'a de sens qu'avec la version de sa taxonomie, que les métadonnées consignent sous `taxonomy`.

Si l’appareil fournit une altitude avec une position GPS, les exports incluent la hauteur en mètres, la précision verticale disponible, la surface de référence et l’heure de mesure. JSON inclut tout avec les coordonnées associées ; GPX inclut ces données aux points de trace Survey et aux points de détection. CSV et Raven ajoutent seulement une colonne `Altitude (m)` près de la latitude et de la longitude. Aucune altitude n’est déduite pour les coordonnées manuelles ou choisies sur la carte. Une détection ajoutée à un instant précis dans le Résumé d'une Session Survey reçoit une position interpolée entre les points de trace voisins, sans heure de mesure propre. Les appareils peuvent utiliser des surfaces de référence différentes ; vérifiez `altitudeReference` avant toute comparaison. `unknown` signifie que la plateforme n’a pas identifié la surface.

Le bloc `settings` de l'export JSON enregistre les valeurs *réellement appliquées à cette Session* — sensibilité, mode et nombre de fenêtres d'agrégation des scores, gain du microphone et fréquence de coupure du passe-haut — et non celles qui se trouvent dans les Paramètres maintenant. Vous pouvez ainsi reproduire un résultat des mois plus tard, ou comparer deux relevés, sans avoir à vous souvenir de la position de chaque curseur au moment de l'exécution.

Tous les horodatages dans les noms de fichiers exportés (`BirdNET_Live_<date>_<time>_…`) et à l'intérieur des données CSV / JSON sont formatés à l'heure locale *actuelle* de votre téléphone. Les enregistrements sous-jacents sont stockés en UTC et convertis à la sortie.
