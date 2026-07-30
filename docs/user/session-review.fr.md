# Résumé de la session

Le Résumé de la session est l'endroit où BirdNET Live transforme les détections brutes en un enregistrement modifiable.

## Comment y accéder

BirdNET Live ouvre automatiquement le Résumé de la session une fois terminés :

- une session En direct
- un Point d'écoute
- un Relevé
- une analyse de fichiers

Vous pouvez aussi rouvrir n'importe quelle session enregistrée depuis la [Bibliothèque de sessions](session-library.md).

## Zones principales

### Résumé et lecture

Le Résumé de la session combine la lecture, la navigation dans le spectrogramme et une liste d'espèces. Pour les sessions de relevé, il peut aussi afficher un contexte cartographique.

L'en-tête de résumé en haut de l'écran porte la date, la puce de localisation (lat/lon, plus un nom de lieu résolu lorsque **Paramètres → Confidentialité → Autoriser la recherche du nom du lieu** est activé) et — lorsque **Paramètres → Confidentialité → Autoriser la recherche météo** était activé au moment de l'enregistrement — une **ligne météo** sous la localisation affichant les conditions relevées à la fin de la session : une ligne du type *« 20,1 °C · Pluie légère · 3,2 m/s SO »* précédée d'une icône météo. Appuyez sur la ligne pour déplier une petite fiche listant température, vent, précipitations et couverture nuageuse, avec l'attribution Open-Meteo. Le même instantané est repris dans l'export JSON, le bloc de métadonnées par session et le rapport HTML.

La bande de spectrogramme au-dessus du lecteur est interactive : appuyez pour vous positionner, faites glisser avec un doigt pour parcourir la chronologie, et **pincez à deux doigts pour zoomer** sur une fenêtre temporelle étroite — pratique pour examiner le minutage de cris qui se chevauchent ou décortiquer un trille rapide. Écartez à nouveau les doigts pour revenir à l'aperçu par défaut de 10 secondes. Le bouton de lecture sur l'en-tête d'une espèce choisit toujours le premier groupe qui possède réellement un clip enregistré : le bouton est donc disponible dès qu'au moins une détection de cette espèce est lisible.

### Liste des espèces

Les espèces sont regroupées en lignes dépliables. Vous pouvez examiner les détections par espèce et parcourir l'enregistrement pendant que vous les passez en revue. Les lignes de groupe sous une espèce dépliée sont en retrait pour que la carte de l'espèce parente reste visuellement distincte de ses détections.

Un champ de recherche au-dessus de la liste filtre les espèces par nom commun ou scientifique : retrouver un oiseau précis dans une session de 100 espèces se fait en quelques frappes plutôt qu'avec un long défilement. Le bouton :material-sort: à côté change l'ordre des espèces :

- **Confiance la plus élevée** (par défaut) — les espèces ayant la confiance la plus élevée pour une seule détection d'abord. Idéal pour trier les identifications les plus sûres. Lorsque vous dépliez une espèce dans ce mode, les détections avec clips audio lisibles apparaissent avant celles sans clip, puis par confiance.
- **Plus de détections** — les espèces ayant le plus grand nombre de détections d'abord. Idéal pour repérer les chanteurs dominants.
- **A → Z** — par ordre alphabétique du nom commun. Prévisible, adapté à la langue, et facile à parcourir quand une session comporte beaucoup d'espèces.
- **Détectées en premier** — par ordre chronologique de première détection. La valeur par défaut historique ; utile pour la révision en parallèle de la chronologie du spectrogramme.

Le tri choisi est conservé d'une session à l'autre.

### Ajouter une espèce à la main

Le bouton :material-plus-circle-outline: de la barre d'outils ouvre le sélecteur d'espèces pour les oiseaux que BirdNET a manqués. Toucher un résultat ne l'insère pas immédiatement : une fiche de confirmation apparaît d'abord, avec l'espèce choisie et deux cases à cocher :

- :material-ear-hearing: **Entendu** — vous avez entendu l'oiseau.
- :material-eye: **Vu** — vous avez vu l'oiseau.

Cochez l'une, les deux ou aucune, puis touchez **Ajouter**. **Annuler** — ou un glissement vers le bas — vous ramène à la recherche : une erreur de doigt ne coûte rien. **Entendu** est coché par défaut, et votre choix est conservé pour l'espèce suivante : une série d'oiseaux seulement vus ne demande de cocher **Vu** qu'une fois. Si vous laissez les deux vides, l'entrée est enregistrée sans type d'observation, et non comme « ni l'un ni l'autre ».

Le choix est stocké sur la détection et affiché sous forme d'une petite oreille et/ou d'un œil à côté du badge « manuel », partout où cette détection apparaît : en-têtes d'espèce, lignes de grappe, lecteur de clip et liste du survey en direct. Il se retrouve aussi dans les exports : colonne `Evidence` dans les CSV et les tables Raven, champ `evidence` en JSON, et pastille dans le rapport HTML. La même fiche apparaît lors d'un **Remplacer l'espèce**, pré-remplie avec ce que l'enregistrement portait déjà.

### Actions par détection

Partout où une détection apparaît — la liste des espèces, le lecteur de clips, la liste du relevé en direct et les marqueurs de la carte du relevé — le même ensemble d'actions est utilisé :

- :material-check: **Confirmer** — une coche en un toucher qui marque une détection comme vérifiée visuellement ou acoustiquement. Les groupes et marqueurs confirmés affichent une petite coche verte pour se distinguer d'un coup d'œil, et le marqueur de confirmation est conservé dans tous les formats d'export.
- :material-dots-vertical: **Plus** — ouvre un menu avec :
    - :material-share-variant: **Partager la détection** — voir *Partage* ci-dessous.
    - :material-swap-horizontal: **Remplacer l'espèce** — choisir une autre espèce pour cette détection.
    - :material-delete-outline: **Supprimer la détection** — supprime immédiatement la ligne. Une notification d'annulation apparaît quelques secondes pour rattraper les erreurs. Aucune boîte de dialogue de confirmation.
    - :material-delete-sweep-outline: **Supprimer l'espèce** — supprime en une seule fois toutes les détections de cette espèce dans la session, avec la même possibilité d'annulation. Pratique pour balayer une source de bruit mal identifiée sans déplier l'espèce et supprimer les groupes un par un.

#### Raccourcis par glissement sur les lignes de révision

Dans la liste des espèces, vous pouvez aussi agir sur une détection en faisant glisser la ligne horizontalement :

- glisser vers la **droite** → supprimer (avec annulation)
- glisser vers la **gauche** → ouvrir le panneau de remplacement d'espèce

Les deux arrière-plans sont codés par couleur (rouge erreur ou bleu primaire) pour que l'effet du geste soit évident avant de le confirmer.

Faire glisser une ligne d'**en-tête d'espèce** (vers la gauche ou la droite) supprime d'un coup toutes les détections de cette espèce, avec la même notification d'annulation. Pratique pour trier une session pleine de bruits mal identifiés.

### Partage d'une seule détection

L'entrée :material-share-variant: **Partager la détection** ouvre la feuille de partage du système avec un contenu concis et adapté au travail de terrain — nom commun et scientifique, confiance, horodatage UTC au format ISO 8601, et une URI `geo:` lorsque la détection possède des coordonnées GPS — et joint le clip audio dès qu'il est disponible. Le fichier partagé est nommé `BirdNET_Live_<timestamp>_<species>.<ext>` pour correspondre au schéma de l'export ZIP.

La pièce jointe audio est résolue dans cet ordre :

1. Le clip propre à la détection présent sur le disque.
2. **Pour les sessions enregistrant un seul fichier continu** : la fenêtre audio correspondante est extraite de l'enregistrement à la volée. Les enregistrements continus WAV et FLAC sont pris en charge, et l'extrait est livré dans le même conteneur que la source (WAV en entrée → WAV en sortie, FLAC en entrée → FLAC en sortie).
3. Si aucun n'est disponible, le partage est en texte seul — la localisation et l'horodatage figurent tout de même dans le contenu.

### Mémos vocaux

Vous pouvez joindre de courts commentaires vocaux à des détections individuelles :

- **Enregistrer** : appuyez sur le bouton :material-dots-vertical: d'un groupe de détection et sélectionnez **Enregistrer un mémo vocal** pour ouvrir la boîte de dialogue du mémo vocal. Appuyez sur le grand bouton du microphone pour démarrer l'enregistrement. Une forme d'onde en temps réel reflète votre voix. Appuyez sur le bouton d'arrêt lorsque vous avez terminé.
- **Réécouter** : une fois enregistré, vous pouvez écouter le mémo à l'aide du lecteur intégré. Pour remplacer le mémo, appuyez sur le bouton **Réenregistrer**. Pour l'enregistrer, appuyez sur le bouton **Enregistrer**.
- **Supprimer** : si une détection possède déjà un mémo vocal, vous pouvez le supprimer depuis le menu ou depuis la boîte de dialogue du mémo vocal.
- **Formats par plateforme** : sur Android et les autres plateformes, les mémos vocaux sont enregistrés au format AAC (`.m4a`) fortement compressé à 16 kHz. Sur iOS, ils utilisent automatiquement le format WAV/PCM16 (`.wav`) pour éviter les problèmes de compatibilité CoreAudio avec les sessions audio actives de l'application. Les deux formats sont entièrement pris en charge par le package d'export ZIP.
- **Export** : lors de l'export de la session au format ZIP, les mémos vocaux sont regroupés dans le répertoire `memos/` et leurs chemins relatifs sont enregistrés dans les métadonnées JSON et CSV.

### Carte du tracé du relevé

Les sessions de relevé affichent une petite carte intégrée du tracé GPS et des marqueurs de détection. Appuyez sur un marqueur de la carte intégrée pour cibler une détection — la carte se recentre dessus. Appuyez sur le bouton :material-fullscreen: **agrandir** (en haut à droite de la carte intégrée) pour ouvrir la **carte en plein écran** ; si une détection était ciblée, la carte plein écran s'ouvre centrée et zoomée sur cette détection pour que vous gardiez votre repère.

#### Codage des marqueurs

- **La confiance est codée par couleur** avec une rampe adaptée aux daltoniens : de la confiance faible à élevée, elle va du bleu-violet au rouge en passant par le turquoise/jaune. La luminosité de la rampe varie de façon monotone pour rester lisible en monochrome et pour les personnes ayant une déficience de la vision des couleurs rouge-vert.
- **Les détections avec audio** affichent un anneau coloré autour de la photo de l'espèce, plus un badge de lecture dans le coin — appuyez dessus pour ouvrir le même lecteur de clips utilisé ailleurs, avec confirmation, partage, remplacement et suppression tous disponibles.
- **Les détections muettes** (aucun clip sur le disque) s'affichent plus petites, atténuées et avec un anneau gris neutre, pour que les détections audio restent toujours le contenu principal.
- **Les marqueurs qui se chevauchent au même endroit** sont superposés par ordre d'importance : mis en évidence > audio > confiance plus élevée, de sorte qu'un marqueur muet à faible confiance ne peut jamais masquer une détection audio forte.
- **En dessous du zoom 14,5**, les silhouettes se réduisent à des points colorés dimensionnés selon la confiance, et les groupes denses se rassemblent en une bulle de comptage (le regroupement se désactive au zoom 15).

#### Filtrage

La carte plein écran dispose d'une **puce de filtre** persistante ancrée en haut à droite. Appuyez dessus pour ouvrir la fiche de filtre ; l'étiquette de la puce indique toujours ce qui est actif (*« Toutes les espèces »*, *« Avec audio »*, *« ≥ 80 % »* ou un nom d'espèce unique). Filtres disponibles :

- **Toutes les détections** (par défaut).
- **Avec clip audio** — uniquement les détections dont le clip est encore sur le disque et lisible.
- **Ajouts manuels** — uniquement les détections que vous avez ajoutées dans le Résumé de la session (exclut celles détectées automatiquement).

Vous pouvez aussi restreindre les détections par niveau de confiance. Le curseur définit le seuil minimal de confiance (commence à 10 %).

Sous le curseur de confiance se trouve un sélecteur **Limiter à une espèce** qui permet de réduire la carte à une seule espèce — utile pour savoir « où exactement le long du parcours ai-je entendu la grive des bois ? ». Une entrée *Toutes les espèces* lève la restriction d'espèce. Les filtres se combinent : par exemple *Avec clip audio* + *Grive des bois* + *> 80 %* n'affiche que les marqueurs lisibles de Grive des bois ayant obtenu plus de 80 %.

Lorsqu'un filtre est actif, le titre de la barre supérieure gagne un sous-titre indiquant le nombre de correspondances (par exemple *« 7 détections »*). *Réinitialiser* dans la fiche ramène à l'état par défaut.

## Icônes de la barre d'outils

La barre d'outils utilise les mêmes significations d'icônes que celles décrites dans [Icônes et contrôles](icons-and-controls.md) :

- :material-plus-circle-outline: — ajouter du contenu
- :material-undo-variant: / :material-redo-variant: — parcourir les modifications
- :material-content-cut: — mode rognage
- :material-content-save: — enregistrer les modifications
- :material-share-variant: — exporter ou partager
- :material-delete-outline: — supprimer la session
- :material-play: — reprendre un relevé lorsque cette action est disponible
- :material-help-circle-outline: — ouvrir la fiche d'aide du Résumé de la session
- :material-tune: — ouvrir les Paramètres

## Tâches de révision courantes

- vérifier les détections en regard de la lecture et du contexte du spectrogramme
- ajouter une espèce ou une annotation
- rogner l'enregistrement à l'intervalle utile
- exporter l'ensemble de résultats révisé

## Export

Le comportement d'export dépend des options choisies dans les [Paramètres](settings.md). L'application peut empaqueter les détections et, en option, l'audio dans le format d'export choisi. Chaque export est accompagné de métadonnées de provenance — version de l'application, nom et version du modèle, langue des espèces, horodatage de l'export, paramètres conservés avec la session, ainsi que les options d'export pertinentes — écrites dans un fichier annexe `<prefix>.metadata.json` (ZIP) ou un bloc `meta` de premier niveau (JSON), afin que les exports soient auto-descriptifs et reproductibles.

Le bloc `settings` de l'export JSON enregistre les valeurs *réellement appliquées à cette session* — sensibilité, mode et nombre de fenêtres d'agrégation des scores, gain du microphone et fréquence de coupure du passe-haut — et non celles qui se trouvent dans les Paramètres maintenant. Vous pouvez ainsi reproduire un résultat des mois plus tard, ou comparer deux relevés, sans avoir à vous souvenir de la position de chaque curseur au moment de l'exécution.

Tous les horodatages dans les noms de fichiers exportés (`BirdNET_Live_<date>_<time>_…`) et à l'intérieur des données CSV / JSON sont formatés à l'heure locale *actuelle* de votre téléphone. Les enregistrements sous-jacents sont stockés en UTC et convertis à la sortie.
