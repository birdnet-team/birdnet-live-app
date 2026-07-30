# Mode En direct

Le mode En direct est le moyen le plus rapide d'écouter via le microphone du téléphone et d'examiner les détections au fur et à mesure qu'elles apparaissent en temps réel.

## Comment l'ouvrir

Depuis l'écran d'accueil, appuyez sur la carte **Mode En direct** avec l'icône :material-microphone:.

## Widget « Écoute rapide »

**Android uniquement.** Un widget sur l'écran d'accueil démarre l'écoute en un seul appui, sans avoir à ouvrir l'application puis à y naviguer — pratique lorsque vous entendez quelque chose que vous voulez identifier avant qu'il ne se taise.

Ajoutez-le comme n'importe quel widget : appuyez longuement sur un espace libre de l'écran d'accueil, appuyez sur **Widgets**, cherchez **BirdNET Live** et faites glisser l'une des deux tuiles.

- **Écoute rapide** (2×1) — icône accompagnée du libellé **Démarrer l'écoute**
- **Écoute rapide (compacte)** (1×1) — icône seule

Les deux font la même chose. Un appui sur l'une ou l'autre ouvre le mode En direct et commence à écouter immédiatement, quel que soit le réglage **Démarrer l'enregistrement automatiquement**. Le widget ne modifie pas ce réglage.

Si le mode En direct est déjà ouvert, le widget revient à ce même écran au lieu de le reconstruire. Une Session en cours ou en pause continue sans changement ; si elle est arrêtée, l'écoute démarre sur l'écran existant.

Écoute rapide ne remplace jamais un autre mode en cours. Si une Session Point Count, Survey, File Analysis ou [mode ARU](aru-mode.md) est en cours ou démarre, l'application revient au premier plan et vous demande d'arrêter d'abord cette Session. Son écran et son travail restent accessibles et ne sont pas interrompus.

## Barre supérieure

La barre supérieure contient trois éléments :

- :material-arrow-left: — quitter le mode En direct
- texte d'état central — « Initialisation », « Chargement du modèle », « Prêt », « Identification des espèces », « En pause » ou « Erreur »
- :material-tune: — ouvrir la vue Paramètres propre au mode En direct

## Bouton d'action principal

Le grand bouton circulaire en bas au centre change d'état :

- :material-microphone: — démarrer l'écoute
- :material-stop: — arrêter la session active
- :material-play: — reprendre depuis un état en pause

## Ce que vous voyez pendant l'écoute

### Spectrogramme

Le spectrogramme défile en continu pendant que la capture est active. Il affiche le contenu fréquentiel au fil du temps, en utilisant la palette de couleurs, la taille FFT, la plage de fréquences et la durée configurées dans les Paramètres.

### Liste des détections

Les détections récentes apparaissent sous le spectrogramme. Chaque ligne peut afficher :

- l'image de l'espèce
- le nom commun
- le nom scientifique (facultatif)
- la valeur de confiance

Appuyez sur une ligne d'espèce pour ouvrir le panneau de détails de l'espèce.

### Barre d'informations de la session

La ligne d'information compacte sous le spectrogramme résume la session en cours, par exemple :

- détections actuellement affichées
- nombre d'espèces uniques (`spp`)
- nombre total de détections (`det`)
- durée écoulée
- taille estimée de l'enregistrement lorsque l'enregistrement est activé

## Comportement d'enregistrement

L'enregistrement est contrôlé dans les [Paramètres](settings.md).

- **Complet** enregistre toute la session.
- **Détections uniquement** enregistre des clips autour des détections.
- **Désactivé** désactive l'enregistrement.

Lorsque vous arrêtez le mode En direct, BirdNET Live enregistre la session et ouvre le [Résumé de la session](session-review.md).
