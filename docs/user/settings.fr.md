# Paramètres

BirdNET Live réutilise un écran Paramètres sur plusieurs flux de travail. Le bouton :material-tune: ouvre les sections pertinentes pour l'écran d'où vous venez.

## Comment fonctionne la portée des paramètres

- L'ouverture des paramètres depuis l'accueil affiche le plein écran.
- L'ouverture des paramètres depuis Live, Survey, Point Count ou File Analysis filtre l'écran vers les sections pertinentes.

## Général

### Thème

Choisissez **Sombre**, **Clair** ou **Système**.

### Langue de l'application

Définit la langue de l'interface.

### Noms des espèces

Contrôle la langue utilisée pour les noms d'espèces. **Suivez la langue de l'application** utilise la même langue que l'interface lorsque ce nom est disponible.

### Afficher les noms scientifiques

Affiche les noms scientifiques sous les noms communs dans l'application.

### Affichage des horodatages

Contrôle l'affichage des heures de chaque détection dans la revue de session.

- **Relatif** affiche le décalage depuis le début de l'enregistrement, p. ex. `00:12:34`. Idéal pour parcourir une seule session et se caler sur le spectrogramme.
- **Absolu** affiche l'heure locale au moment de la détection, p. ex. `08:42:17`. Idéal pour recouper des notes de terrain, des journaux météo ou des enregistrements simultanés.

Si une détection tombe un jour calendaire différent du début de session (p. ex. un suivi nocturne), l'heure absolue reçoit le suffixe `+1d` pour éviter de confondre l'aube de demain avec celle d'aujourd'hui.

Lorsque **Absolu** est sélectionné, un interrupteur supplémentaire **Afficher les secondes dans les horodatages** apparaît. Désactivez-le si vous préférez le format plus compact `08:42` à `08:42:17` — utile lors du parcours de longues listes de détections. Les décalages relatifs affichent toujours les secondes car l'alignement avec le spectrogramme requiert une précision inférieure à la minute.

Lorsque **Absolu** est sélectionné, un interrupteur supplémentaire **Afficher les secondes dans les horodatages** apparaît. Désactivez-le si vous préférez le format plus compact `08:42` à `08:42:17` — utile lors du parcours de longues listes de détections. Les décalages relatifs affichent toujours les secondes car l'alignement avec le spectrogramme requiert une précision inférieure à la minute.

Le stockage et les exports utilisent toujours UTC, quel que soit ce réglage : le choix n'affecte jamais les données — seulement leur affichage.

## Audio

Ces contrôles apparaissent dans les flux de travail en direct pilotés par l'audio.

### Gagner

Ajuste le gain d'entrée affiché dans l'application. Utilisez-le uniquement lorsque vous devez compenser des enregistrements ou des entrées très silencieux.

### Filtre passe-haut (Hz)

Réduit le grondement basse fréquence avant l’inférence.

### Micro

Vous permet de choisir un périphérique d'entrée spécifique ou de conserver la **valeur par défaut du système**.

## Inférence

### Durée de la fenêtre

Contrôle la longueur de la fenêtre d'analyse.

### Seuil de confiance

Définit le degré de prudence des détections.

### Sensibilité

Des valeurs plus élevées rendent le détecteur plus permissif, ce qui permet de récupérer des appels plus faibles au prix d'un plus grand nombre de faux positifs.

### Taux d'inférence

Contrôle la fréquence à laquelle BirdNET exécute l'inférence.

### Regroupement des scores

Contrôle la façon dont les fenêtres d’analyse qui se chevauchent sont combinées.

## Spectrogramme

### Taille FFT

Contrôle la résolution de fréquence dans le spectrogramme.

### Carte des couleurs

Choisissez **Viridis**, **Magma** ou **Grayscale**.

### Durée (vitesse de défilement)

Contrôle la durée visible dans la fenêtre du spectrogramme.

### Gamme de fréquences

Définit la fréquence d’affichage supérieure.

### Log d'amplitude

Applique une mise à l'échelle logarithmique au spectrogramme pour une lecture visuelle plus facile.

## Enregistrement

###Mode

- **Full** — sauvegardez tout l'enregistrement
- **Détections uniquement** : enregistrez les clips autour des détections
- **Désactivé** — pas d'enregistrement audio

### Contexte du clip

Lorsque **Détections uniquement** est actif, l'application affiche un seul curseur **Contexte du clip** (0 à 5 s) qui définit la quantité d'audio préservée des **deux côtés** de chaque détection. Chaque clip a une longueur de « fenêtre d'analyse + 2 × contexte de clip », donc avec une fenêtre d'analyse de 3 s et le contexte par défaut de 1 s, le clip enregistré dure 5 s. Définir le contexte sur 2 s donne un clip de 7 s (2 s de pré-roll + 3 s d'audio analysé + 2 s de post-roll). Des valeurs plus élevées vous donnent plus de place pour une inspection visuelle ou des outils de révision externes au détriment de l'espace disque ; 0 enregistre uniquement la fenêtre analysée elle-même.

###Format

Choisissez **WAV** ou **FLAC**.

## Emplacement

### Utiliser le GPS

Utilisez le GPS de l'appareil au lieu des coordonnées manuelles.

### Latitude/Longitude

Coordonnées manuelles utilisées lorsque le GPS est désactivé.

### Filtre d'espèce

- **Désactivé** — pas de filtrage géographique
- **Filtre de localisation** — exclut les espèces qui se situent en dessous du seuil géographique
- **Pondération de localisation** — utilisez le géomodèle comme signal de pondération supplémentaire

### Seuil de géofiltrage

Apparaît lorsqu'un mode de filtrage basé sur l'emplacement est actif.

## Exporter et synchroniser

### Formats

Cochez n'importe quelle combinaison de formats d'export — chaque enregistrement / partage regroupera tous les formats sélectionnés ensemble dans un unique ZIP. Si vous choisissez un seul format sans clips audio et sans rapport HTML, vous obtiendrez un fichier brut (p. ex. `session.csv`) par rétrocompatibilité :

- Table de sélection Raven — pour Cornell Raven Pro.
- CSV — s'ouvre dans n'importe quel tableur.
- JSON — idéal pour le traitement programmatique ; contient les métadonnées complètes de la session.
- GPX — trace et waypoints pour les applis cartographiques (utile uniquement si le GPS était actif).

L'intuition : beaucoup de workflows ont besoin de plusieurs formats simultanément — un CSV pour le tableur, une table Raven pour le relecteur bureau et un JSON pour le script d'analyse. Avant, il fallait exporter la même session trois fois ; vous cochez maintenant les trois en une seule fois et ils voyagent ensemble dans le ZIP.

### Inclure les fichiers audio

Incluez l'audio enregistré aux côtés des tables ou métadonnées exportées lorsque cela est pris en charge par le flux de travail d'exportation.

## Confidentialité

Cette section contrôle **quels services tiers BirdNET Live peut contacter en votre nom**. L'inférence elle-même s'exécute entièrement sur votre appareil — ces interrupteurs ne pilotent que des fonctions réseau optionnelles. Les trois interrupteurs sont **désactivés par défaut** sur une nouvelle installation ; rien ne sort tant que vous ne l'avez pas autorisé. L'intuition : chaque interrupteur cible un service concret et un bénéfice concret, pour que vous activiez exactement ce dont vous avez besoin.

### Autoriser les tuiles de carte

Requis pour toute carte interactive (sélecteur de position, carte live de Survey, carte de la session). Quand actif, les widgets carte demandent des tuiles raster aux serveurs publics **OpenStreetMap** ; les requêtes de coordonnées de tuile révèlent quelle zone du monde vous regardez. Quand désactivé, tous les écrans cartographiques affichent un panneau d'attente.

### Autoriser la recherche de nom de lieu

Quand actif, l'appli envoie vos coordonnées enregistrées au service **Nominatim** d'OpenStreetMap pour résoudre un nom de lieu court (p. ex. «Paris, France») affiché à côté de la session dans la Bibliothèque des sessions et dans la Revue de session. L'intuition : les coordonnées numériques sont précises mais difficiles à lire dans une longue liste ; un nom de lieu la rend lisible d'un coup d'œil. Quand désactivé, seules les coordonnées brutes sont affichées et Nominatim n'est jamais contacté.

### Autoriser la requête météo

Quand actif, chaque session enregistrée capture un instantané unique des conditions locales (température, précipitations, vent, nuages) aux coordonnées et à l'heure de fin via **Open-Meteo**. L'instantané apparaît dans la Revue de session sous la ligne de localisation et est repris dans l'export JSON, le bloc de métadonnées et le rapport HTML. L'intuition : la météo est l'un des prédicteurs les plus forts de l'activité des oiseaux, et la capturer automatiquement fait de chaque session un dossier plus complet. Open-Meteo est gratuit et ne nécessite ni compte ni clé API. Quand désactivé, aucune donnée météo n'est récupérée ni stockée.

## À propos

La ligne **À propos** ouvre l'écran À propos de l'application.

## Zone dangereuse

### Réinitialiser l'intégration

Affiche à nouveau la séquence d'intégration au prochain lancement de l'application.

### Effacer toutes les données

Supprime définitivement les sessions, détections, enregistrements, mémos vocaux, listes d'espèces personnalisées, préférences enregistrées et données en cache de cartes, noms de lieux, météo, lecture, revue et partage. Le dialogue de confirmation exige de saisir `DELETE`, puis ferme l'app afin que le prochain lancement reparte d'un état local propre.

Utilisez cette action avant de confier un appareil à une autre personne observatrice, de retirer un téléphone de terrain ou de supprimer l'historique lié aux emplacements. Exportez d'abord tout ce que vous souhaitez conserver ; cette action est irréversible.

## Paramètres spécifiques au workflow en dehors des paramètres

Certains paramètres sont configurés dans leurs propres écrans de configuration plutôt que dans l'écran Paramètres partagé.

- [Point Count Mode] (point-count-mode.md) a sa propre configuration de durée et d'emplacement.
- [Mode enquête] (survey-mode.md) possède son propre écran de paramètres d'enquête.
- [File Analysis] (file-analysis.md) a sa propre étape de paramètres d'analyse.