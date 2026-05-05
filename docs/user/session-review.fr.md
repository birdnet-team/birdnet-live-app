# Examen de la session

La révision de session est l'endroit où BirdNET Live transforme les détections en un enregistrement modifiable.

## Comment y parvenir

BirdNET Live ouvre automatiquement la révision de session après avoir terminé :

- une session Live
- un décompte de points
- une enquête
- une analyse de fichiers

Vous pouvez également rouvrir n'importe quelle session enregistrée à partir de [Bibliothèque de sessions](session-library.md).

## Domaines principaux

### Résumé et lecture

Session Review combine la lecture, la navigation par spectrogramme et une liste d’espèces. Pour les sessions d'enquête, il peut également afficher le contexte cartographié.

### Liste des espèces

Les espèces sont regroupées en lignes extensibles. Vous pouvez inspecter les détections par espèce et parcourir l’enregistrement tout en les examinant.

### Carte des pistes d'enquête

Les sessions d'enquête affichent une petite carte en ligne de la trace GPS et des marqueurs de détection. Appuyez dessus pour ouvrir une **carte plein écran** avec les mêmes données.

La barre d'application de la carte plein écran comporte un bouton :material-filter-list-outlined: **filter** qui ouvre une feuille pour restreindre les marqueurs à afficher. Filtres disponibles :

- **Toutes les détections** (par défaut).
- **Avec clip audio** — uniquement les détections dont le clip est toujours sur le disque et lisible.
- **Confiance élevée** – uniquement les détections égales ou supérieures à 80 % de confiance.
- **Ajouts manuels** — uniquement les détections que vous avez ajoutées dans Session Review (à l'exclusion de celles détectées automatiquement).

Sous le sélecteur de mode se trouve un sélecteur **Limite aux espèces** qui vous permet de réduire la carte à une seule espèce — utile pour demander « où exactement le long de l'itinéraire ai-je entendu la grive des bois ? ». Une entrée *Toutes les espèces* efface la restriction d'espèce. Les deux filtres se combinent : par ex. *Avec clip audio* + *Grive des bois* affiche uniquement les marqueurs jouables de la Grive des bois.

Lorsqu'un filtre est actif, le titre de la barre d'application obtient un sous-titre correspondant au nombre de correspondances (par exemple *"7 détections"*) et le bouton de filtre affiche un petit point. *Réinitialiser* dans la feuille revient à la valeur par défaut.

## Icônes de la barre d'outils

La barre d'outils utilise les mêmes significations d'icônes décrites dans [Icônes et contrôles](icons-and-controls.md) :

- :material-plus-circle-outline : — ajouter du contenu
- :material-undo-variant: / :material-redo-variant: — étape par étape dans les modifications
- :material-content-cut: — mode de découpage
- :material-content-save : — enregistrer les modifications
- :material-share-variant : — exporter ou partager
- :material-delete-outline : — supprimer la session
- :material-play : — continue une enquête lorsque cette action est disponible
- :material-help-circle-outline : — ouvre la feuille d'aide de révision de session
- :material-tune : — ouvrez les paramètres

## Tâches de révision typiques

- vérifier les détections par rapport au contexte de lecture et de spectrogramme
- ajouter une espèce ou une annotation
- couper l'enregistrement à l'intervalle utile
- exporter l'ensemble de résultats révisé

## Exporter

Le comportement de l'exportation dépend des options sélectionnées dans [Paramètres](settings.md). L'application peut regrouper les détections et, éventuellement, l'audio dans le format d'exportation choisi. Chaque exportation est désormais livrée avec des métadonnées complètes de provenance — la version de l'application, le nom et la version du modèle, les paramètres régionaux de l'espèce, l'horodatage de l'exportation et un instantané de tous les paramètres au moment de l'exportation — écrites dans un fichier latéral `"<prefix>.metadata.json"` (ZIP) ou un bloc `meta` de niveau supérieur (JSON) afin que les exportations soient auto-descriptives et reproductibles.
