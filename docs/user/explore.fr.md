# Explorer

Explorer affiche les espèces prévues pour la position et la saison actuelles à l'aide du géo-modèle BirdNET.

## Comment l'ouvrir

Ouvrez **Explorer** depuis le bas de l'écran d'accueil à l'aide du bouton :app-searchRounded:.

## Barre supérieure et en-tête

### Barre supérieure

- :app-refresh: — actualiser la position et reconstruire la liste des espèces prédites

### En-tête de localisation

L'en-tête affiche :

- le nom du lieu obtenu par géocodage inverse lorsqu'il est disponible
- les coordonnées sous le nom du lieu
- :app-helpOutlineRounded: — ouvrir la fiche d'aide d'Explorer

## Liste des espèces

Chaque fiche d'espèce peut comprendre :

- l'image fournie de l'espèce
- le nom commun
- le nom scientifique (facultatif)
- la pastille de niveau d'abondance

Appuyez sur une fiche pour ouvrir le panneau de détails de l'espèce.

### Niveaux d'abondance

Au lieu d'un pourcentage brut, chaque fiche affiche un **niveau d'abondance** pour le lieu et la saison actuels. La pastille de niveau combine deux indices :

- un **cercle** qui se remplit de ⅙ à plein à mesure que l'espèce devient plus probable
- la **première lettre** du nom du niveau (le nom complet est lu par les lecteurs d'écran et affiché dans les détails de l'espèce)

La couleur de la pastille suit l'échelle de score partagée de l'application, passant du rouge (moins probable) au vert (plus probable) à mesure que le niveau augmente.

Il existe six niveaux, du plus au moins probable :

| Niveau | Signification |
| --- | --- |
| **Abondante** | Parmi les prédictions les plus fortes ici |
| **Commune** | Très probable |
| **Fréquente** | Probable |
| **Inhabituelle** | Possible |
| **Sporadique** | Peu probable |
| **Rare** | Parmi les prédictions les plus faibles ici |

Les niveaux sont **relatifs au lieu actuel**. Ils s'adaptent à la force avec laquelle le géo-modèle prédit les espèces dans cette zone, de sorte que les limites se déplacent selon la distribution locale des scores : dans un lieu avec de nombreuses prédictions sûres, une espèce a besoin d'un score très élevé pour être *Abondante*, tandis que dans une zone aux prédictions plus faibles le même niveau est atteint à un score plus bas. Un même score peut donc correspondre à des niveaux différents selon les endroits, ce qui garde le classement pertinent partout.

## Panneau de détails de l'espèce

Le panneau peut afficher :

- une image plus grande
- le crédit de l'image
- les noms commun et scientifique
- le texte descriptif fourni lorsqu'il est disponible
- le graphique hebdomadaire des fréquences attendues
- des liens externes tels que eBird, iNaturalist ou Wikipedia lorsqu'ils sont disponibles pour cette espèce

## À quoi sert Explorer

Explorer est une vue de référence géolocalisée dans l'application. Elle vous aide à comparer le contexte de localisation actuel de l'application avec les espèces que vous pourriez rencontrer.

Elle ne modifie **pas** par elle-même les données des sessions enregistrées. Le filtrage des détections est contrôlé séparément via les [Paramètres](settings.md).
