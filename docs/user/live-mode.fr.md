# Mode en direct

Le mode Live est le moyen le plus rapide d'écouter via le microphone du téléphone et d'examiner les détections au fur et à mesure qu'elles apparaissent.

## Comment l'ouvrir

Depuis l'écran d'accueil, appuyez sur la carte **Mode direct** avec l'icône :material-microphone:.

## Barre supérieure

La barre supérieure contient trois éléments :

- :material-arrow-left: — quitter le mode Live
- Texte d'état central : « Initialisation », « Chargement du modèle », « Prêt », « Identification des espèces », « Pause » ou « Erreur »
- :material-tune: — ouvre la vue Paramètres spécifiques à Live

## Bouton d'action principal

Le gros bouton circulaire en bas au centre change d'état :

- :matériel-microphone : — commencer à écouter
- :material-stop: — arrête la session active
- :material-play : - reprise à partir d'un état prêt en pause

## Ce que vous voyez en écoutant

### Spectrogramme

Le spectrogramme défile en continu pendant que la capture est active. Il affiche le contenu des fréquences au fil du temps et utilise la carte des couleurs, la taille FFT, la plage de fréquences et la durée des paramètres.

### Liste de détection

Les détections récentes apparaissent sous le spectrogramme. Chaque ligne peut afficher :

- image de l'espèce
- nom commun
- nom scientifique facultatif
- valeur de confiance

Appuyez sur une ligne d'espèce pour ouvrir la superposition des détails de l'espèce.

### Barre d'informations sur la session

La ligne d'information compacte sous le spectrogramme résume la session en cours, par exemple :

- détections actuelles affichées maintenant
- nombre d'espèces uniques (`spp`)
- nombre total de détections (`det`)
- durée écoulée
- taille d'enregistrement estimée lorsque l'enregistrement est activé

## Comportement d'enregistrement

L'enregistrement est contrôlé dans [Paramètres](settings.md).

- **Full** enregistre toute la session.
- **Détections uniquement** enregistre les clips autour des détections.
- **Off** désactive l'enregistrement.

Lorsque vous arrêtez le mode Live, BirdNET Live enregistre la session et ouvre [Session Review](session-review.md).