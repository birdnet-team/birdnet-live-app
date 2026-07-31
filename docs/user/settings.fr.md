# Paramètres

BirdNET Live réutilise un même écran Paramètres dans plusieurs flux de travail. Le bouton :material-tune: ouvre les sections pertinentes pour l'écran d'où vous venez.

## Fonctionnement de la portée des paramètres

- Ouvrir les Paramètres depuis l'Accueil affiche l'écran complet.
- Ouvrir les Paramètres depuis Live, Survey, Point Count ou l'Analyse de fichiers restreint l'écran aux sections pertinentes.

## Général

### Thème

Choisissez **Sombre**, **Clair** ou **Système**.

Si **Couleur dynamique** est activée, BirdNET Live tente également de reprendre la palette système de votre appareil Android. Cela n'a d'effet que sur les appareils Android compatibles ; sur iPhone et iPad, l'application conserve le thème BirdNET Live standard, activer l'interrupteur n'y change donc rien.

Activez **Thème à contraste élevé** pour utiliser une palette d'interface claire ou sombre en noir et blanc, avec un texte plus épais et des surfaces bordées plutôt que des cartes teintées. Il suit le choix **Sombre**, **Clair** ou **Système**, prend le pas sur la couleur dynamique tant qu'il est actif, et conserve les couleurs de danger, d'avertissement, de validation, de mode, de score et du spectrogramme.

### Langue de l'application

Définit la langue de l'interface.

### Noms d'espèces

Contrôle la langue utilisée pour les noms d'espèces. **Système** utilise la langue préférée du téléphone lorsque ce nom est disponible, même si l'interface bascule en anglais. **Suivre l'application** utilise plutôt la langue de l'interface.

### Afficher les noms scientifiques

Affiche les noms scientifiques sous les noms communs dans toute l'application.

### Afficher toutes les espèces détectées

Modes Live et Point Count uniquement. Désactivé par défaut, ces écrans continuent donc de n'afficher que les espèces détectées lors du dernier cycle d'inférence : en pratique, celles qui chantent en ce moment. Activez-le pour que chaque espèce détectée pendant la session en cours reste visible dans la liste, même après qu'elle s'est tue ou est passée sous le seuil de confiance.

Lorsque cette option est activée, **Tri de la liste d'espèces** apparaît. **Les plus récentes d'abord** place en tête les espèces qui chantent actuellement, triées par leur confiance du moment, puis les espèces conservées selon leur détection la plus récente. **Confiance** trie selon la confiance la plus élevée atteinte par chaque espèce pendant la session, **Alphabétique** selon le nom commun localisé, et **Occurrences** selon le nombre de détections. Dans tous les modes de tri, le pourcentage et la barre de confiance n'apparaissent que tant que l'espèce chante (les lignes conservées d'espèces devenues silencieuses sont estompées), et les détections répétées affichent un compteur en fin de ligne du nom commun.

### Nom de l'observateur

La configuration de Survey, Point Count et ARU mémorise le dernier nom d'observateur non vide saisi dans l'un de ces modes et le préremplit la fois suivante où vous préparez une session de terrain. L'usage répété sur un téléphone de terrain personnel reste ainsi rapide, tout en vous laissant modifier ou effacer l'observateur avant de démarrer une session.

### ID d'ARU/station

La configuration ARU mémorise le dernier ID d'ARU/station non vide et le préremplit pour le déploiement suivant. Lorsqu'il est renseigné, l'ID figure dans le nom de la session ARU et dans les noms de fichiers d'export, de sorte que les déploiements répétés sur des sites fixes restent identifiables en dehors de l'application.

### Affichage des horodatages

Contrôle la façon dont les heures de chaque détection apparaissent dans le résumé de la session.

- **Relatif** affiche le décalage depuis le début de l'enregistrement, par exemple `00:12:34`. Idéal pour parcourir une seule session et se caler sur la tête de lecture du spectrogramme.
- **Absolu** affiche l'heure locale à laquelle la détection a été captée, par exemple `08:42:17`. Idéal pour recouper avec des notes de terrain, des relevés météo ou des enregistrements simultanés.

Si une détection tombe un jour calendaire différent du début de la session (par exemple lors d'un relevé nocturne), l'heure absolue reçoit le suffixe `+1d`, afin qu'on ne prenne pas le chœur de l'aube de demain pour celui d'aujourd'hui.

Lorsque **Absolu** est sélectionné, un interrupteur supplémentaire **Afficher les secondes dans les horodatages** apparaît. Désactivez-le si vous préférez le plus compact `08:42` à `08:42:17` — pratique pour parcourir de longues listes de détections. Les décalages relatifs affichent toujours les secondes, car il faut une précision inférieure à la minute pour s'aligner sur la tête de lecture du spectrogramme.

Le stockage et les exports utilisent toujours des instants en UTC, quel que soit ce paramètre : le choix n'affecte donc jamais les données, seulement leur affichage.

## Audio

Ces commandes apparaissent dans les flux de travail en direct fondés sur l'audio.

### Source audio

Un panneau avec deux commandes indépendantes : **Microphone** — depuis quelle entrée enregistrer — et **Traitement** — dans quelle mesure le téléphone peut modifier le signal en entrée. Elles se combinent librement, donc un micro USB enregistré *sans traitement* est une configuration tout à fait valable. Votre choix est conservé d'un lancement à l'autre, et le même sélecteur apparaît sur les écrans de configuration Survey, Point Count et ARU. Les changements prennent effet immédiatement : même en cours d'enregistrement, l'application change de micro sous la session en cours plutôt que d'attendre la suivante.

**Microphone** liste par leur nom toutes les entrées exposées par le téléphone : micros USB, filaires et Bluetooth, et sur de nombreux téléphones les micros intégrés pris séparément (par exemple *bas* et *arrière*). Les kits micro sans fil comme le Rode Wireless GO ou le DJI Mic se connectent via un récepteur USB-C : ils apparaissent donc ici comme de simples périphériques audio USB, en pleine qualité.

**Traitement** est la partie la plus importante, et elle concerne **uniquement Android**. Les téléphones appliquent par défaut à l'audio du micro un DSP calibré pour la parole — réduction de bruit, mise en forme spectrale et gain automatique — parce que le micro sert avant tout aux appels. Ce traitement considère le chant des oiseaux comme un bruit à supprimer, et aucun réglage ordinaire ne le désactive. La seule échappatoire consiste à demander à Android une *source audio* différente :

| Option | Effet |
|---|---|
| **Réglage par défaut du téléphone** | Ce que fait normalement votre téléphone, traitement de la voix compris. Le comportement d'origine, et toujours celui par défaut, pour que rien ne change pour les utilisateurs existants. |
| **Sans traitement** | Le signal brut du micro : ni réduction de bruit, ni gain automatique. Généralement le meilleur choix pour les oiseaux. |
| **Reconnaissance vocale** | Désactive elle aussi la réduction de bruit et le gain automatique, et fonctionne sur presque tous les téléphones. |

**Essayez-les et comparez.** Laquelle l'emporte dépend réellement de l'appareil. *Sans traitement* est l'idéal, mais Android ne l'honore que sur les téléphones dont le fabricant déclare la prise en charge — sur les autres, il retombe silencieusement sur le comportement par défaut et sonne comme *Réglage par défaut du système*. C'est à cela que sert *Reconnaissance vocale* : les règles de compatibilité d'Android **exigent** que le gain automatique et la suppression de bruit soient désactivés pour ce mode, qui fournit donc un audio non traité de façon fiable, même sur les téléphones qui ignorent *Sans traitement*. Si passer à *Sans traitement* ne change rien, passez à *Reconnaissance vocale*.

Attendez-vous à ce que les options sans traitement sonnent **plus bas** : c'est l'absence de gain automatique, pas un défaut. Augmentez le **Gain** pour compenser si l'indicateur de niveau paraît faible.

**Sous iOS**, la commande Traitement est masquée et le panneau se réduit à une liste de micros. iOS livre déjà à l'application un audio pour l'essentiel non traité : il n'y a donc rien d'équivalent à choisir.

### Gain

Amplificateur linéaire appliqué à l'audio entrant avant qu'il n'atteigne le spectrogramme et le classificateur. Laissez-le à **1,0×** sauf si votre entrée est systématiquement trop faible — par exemple un micro-cravate à haute impédance sur un téléphone, ou une interface USB dont le préampli est réglé trop bas. Pousser le gain au-delà de 1,0 ne fera pas apparaître par magie des cris que le micro n'a jamais captés ; cela ne fait que remettre à l'échelle ce que le micro a fourni, si bien que les sons forts et proches peuvent saturer. En dessous de 1,0, c'est utile dans le cas rare où une entrée trop chaude sature le spectrogramme.

### Filtre passe-haut (Hz)

Coupe les basses fréquences avant l'inférence à l'aide d'un filtre de Butterworth à 24 dB/octave — la valeur du curseur est la fréquence de coupure à −3 dB. **0 Hz le désactive.** Une coupure de 100–200 Hz élimine le vent, le grondement de la circulation et les bruits de manipulation sans toucher à la plupart des espèces ; en allant vers 500–1000 Hz, on commence à supprimer les hululements graves, les chouettes, les tétraonidés et le beuglement du butor : ne montez donc si haut que si vous ignorez délibérément ces espèces en échange d'un spectrogramme bien plus propre en milieu urbain bruyant. La coupure que vous choisissez devrait apparaître comme une ligne horizontale nette sur le spectrogramme en direct.

## Inférence

### Durée de la fenêtre

Contrôle la longueur de la fenêtre d'analyse. Les paliers disponibles sont **1**, **3**, **5**, **7**, **10** et **15** secondes.

### Seuil de confiance

Définit le degré de prudence des détections. La valeur par défaut est **35 %**, ce qui garde la liste en direct centrée sur les correspondances les plus solides tout en laissant de la place aux cris lointains ou partiellement masqués. Abaissez-le si vous recensez des espèces rares ou discrètes et prévoyez de passer en revue davantage de candidats ensuite ; relevez-le lorsque le bruit de fond ou des faux positifs fréquents encombrent la session.

### Sensibilité

Un décalage sur l'axe des x appliqué aux scores de probabilité bruts du modèle avant la mise en commun des scores, le filtrage géographique et le seuil de confiance. Le modèle audio de BirdNET comporte déjà une activation sigmoïde : BirdNET Live reconvertit donc d'abord chaque probabilité dans l'espace des logits, ajoute le biais de sensibilité, puis la reconvertit en probabilité. Des valeurs plus élevées rendent le détecteur plus permissif — des cris plus faibles ou plus ambigus franchissent le seuil, au prix de davantage de faux positifs. Des valeurs plus basses sont plus strictes et ne laissent passer que les détections sûres. La valeur par défaut de **1,0** n'applique aucun décalage et correspond à la référence BirdNET. Essayez **1,25** si vous soupçonnez le modèle de manquer des cris lointains ; descendez à **0,75** si vous êtes submergé de détections de faible qualité d'espèces communes. La sensibilité s'applique à chaud : la modifier en cours de session prend effet à la fenêtre d'inférence suivante.

### Fréquence d'inférence

Contrôle la fréquence à laquelle BirdNET exécute l'inférence. Le curseur utilise les mêmes paliers de **0,10–1,00 Hz** que la configuration Survey et ARU.

BirdNET Live lisse en interne les scores sur les fenêtres d'inférence récentes
afin de réduire les faux positifs isolés. Cette mise en commun n'est pas
exposée comme paramètre utilisateur ; par défaut, un mode adaptatif est
utilisé, avec cinq fenêtres récentes et une limite d'ancienneté de 10 secondes
en temps réel. Aux fréquences d'inférence élevées, il utilise une mise en
commun par moyenne pour des décisions stables en direct ; aux cadences plus
lentes de Survey et ARU, il utilise la mise en commun LME afin de maintenir
une précision élevée sur les longues durées. Les détections acceptées
affichent la plus forte confiance récente étayée par le modèle, de sorte que
des vocalisations évidentes peuvent toujours afficher une confiance élevée au
lieu d'être aplaties par le lissage.

## Spectrogramme

### Taille de FFT

Contrôle la résolution fréquentielle du spectrogramme.

### Palette de couleurs

Choisissez **Viridis**, **Magma**, **Plasma**, **Cividis**, **Jet**, **Turbo**, **Niveaux de gris** ou **BirdNET**. **Turbo** est l'option arc-en-ciel moderne, proche de Jet.

### Durée (vitesse de défilement)

Contrôle la quantité de temps visible dans la fenêtre du spectrogramme.

### Plage de fréquences

Définit la fréquence maximale affichée.

### Amplitude logarithmique

Applique une échelle logarithmique au spectrogramme pour en faciliter la lecture.

### Qualité

Contrôle la finesse de mise à l'échelle de l'image du spectrogramme. **Moyenne** est le compromis par défaut. Choisissez **Basse** sur les téléphones anciens lorsque le défilement saccade ou que l'appareil chauffe ; choisissez **Haute** si vous préférez un rendu plus fluide et que votre appareil dispose de marge GPU. L'intuition : cela ne change que le coût de rendu, pas l'analyse audio ni les résultats de détection.

## Annonces

Cette section détermine si BirdNET Live doit **lire les détections à voix haute dans vos écouteurs ou par le haut-parleur du téléphone** pendant qu'une session enregistre. La fonction entière est **désactivée par défaut**, car elle modifie l'environnement acoustique autour du micro : l'activer est un compromis assumé. Il n'y a pas d'assistant de configuration : les sélecteurs de niveau de détail × fréquence ci-dessous *constituent* toute la configuration, vous pouvez donc appuyer sur un autre préréglage à tout moment et entendre la différence immédiatement. L'intuition : lors de longs relevés, vous ne pouvez pas garder les yeux sur l'écran ; une voix discrète à l'oreille vous permet de rester concentré sur l'habitat tout en sachant ce qui vient d'être entendu.

### Lire les détections à voix haute (interrupteur principal)

Désactivé par défaut. Une fois activé, l'application énonce chaque détection acceptée à l'aide de la synthèse vocale intégrée de votre appareil. **Les écouteurs sont vivement recommandés** : avec le haut-parleur du téléphone, l'annonce risque d'être captée par le micro et détectée à nouveau ; l'application coupe donc brièvement l'enregistrement autour de chaque énoncé pour éviter cette boucle (voir *Couper le micro pendant la parole* plus bas).

### Préréglage de niveau de détail

Ce que l'application dit de chaque détection. **Minimal** énonce uniquement le nom de l'espèce (idéal pour les relevés très longs où vous ne voulez que le signal). **Équilibré** est le réglage par défaut : des formules courtes et variées comme *« Rougegorge »*, *« On entend un rougegorge »*, *« Encore un rougegorge »*. **Bavard** ajoute un peu plus de contexte et se rapproche d'un commentaire à vos côtés. **Personnalisé** apparaît automatiquement si vous ajustez à la main les valeurs numériques d'Avancé. L'intuition : les mêmes réglages de limitation peuvent sembler trop discrets ou trop bavards selon la formulation — le niveau de détail vous permet de conserver la cadence et de ne régler que le nombre de mots.

### Préréglage de fréquence

À quelle fréquence l'application est autorisée à parler. Cinq paliers, du plus discret au plus bavard. **Rare** et **Parcimonieux** attendent longtemps entre les annonces et en limitent le rythme : bien adaptés aux relevés de plusieurs heures où vous voulez percevoir l'activité sans commentaire continu. **Normal** est la cadence conversationnelle par défaut. **Fréquent** raccourcit les intervalles et relève le plafond ; adapté aux courtes sessions Live ou lorsque vous voulez un retour plus proche du temps réel. **Constant** supprime totalement le délai initial et laisse l'application parler à presque chaque cycle de détection : utile pour les démonstrations, l'accessibilité, ou lorsque l'attente avant la première annonce en mode *Fréquent* vous paraît trop longue. **Personnalisé** apparaît lorsque vous modifiez les champs de temporisation dans Avancé. L'intuition : c'est le seul réglage qui décide si l'application reste en arrière-plan ou devient une présence — appuyez sur un autre préréglage et vous entendrez la nouvelle cadence dès le cycle de détection suivant, sans bouton d'enregistrement.

### Voix

Appuyez sur la ligne de la voix pour choisir parmi les voix de synthèse installées pour la langue des annonces, ou laissez **Voix par défaut** pour laisser l'appareil décider. La disponibilité et la qualité des voix dépendent du système d'exploitation et des paquets vocaux installés ; des voix supplémentaires peuvent être installées depuis les réglages de synthèse vocale de l'appareil.

**Vitesse** s'étend de 0,5× à 1,5× ; la valeur par défaut de 1,0× correspond au débit « normal » de la plateforme. **Hauteur** s'étend de 0,7× à 1,3×. Une légère baisse de hauteur et un ralentissement modéré peuvent rendre les annonces plus faciles à comprendre en extérieur, avec du vent ou de l'eau courante en fond. *Écouter un exemple* permet de prévisualiser la voix choisie, le style de formulation actuel, la vitesse et la hauteur sans quitter les Paramètres. Les modifications s'appliquent à l'annonce suivante.

### Avancé

Un volet dépliant qui expose quelques interrupteurs de routage audio ainsi que le sélecteur de mode de déclenchement. En général, vous n'avez pas besoin de l'ouvrir : les préréglages de niveau de détail et de fréquence ci-dessus sont les seuls réglages qui comptent au quotidien. Les valeurs numériques de limitation (délai de démarrage, intervalle minimal, maximum par minute, silence en série, réinitialisation de récence) sont regroupées dans le curseur **Fréquence**, de sorte qu'il n'existe qu'un seul endroit évident pour accélérer ou ralentir la cadence.

- **Autoriser le haut-parleur du téléphone** — Lorsque c'est désactivé, les annonces sont silencieusement ignorées si aucun écouteur ni haut-parleur externe n'est connecté. Lorsque c'est activé, le haut-parleur du téléphone sert de solution de repli. Activez-le pour une écoute décontractée à la maison ; laissez-le désactivé sur le terrain pour exclure tout retour acoustique vers le micro.
- **Couper le micro pendant la parole** — Remplace l'audio entrant par du silence pendant que l'application parle, afin que la sortie du haut-parleur ne puisse pas être captée par le micro et détectée à nouveau. Vivement recommandé (et activé par défaut). Ne le désactivez que si votre micro est isolé acoustiquement du haut-parleur du téléphone — par exemple un micro-cravate sur un autre câble ou un casque Bluetooth.
- **Baisser les autres sources audio** — Réduit brièvement le volume de la musique ou des podcasts d'autres applications pendant l'annonce, puis le rétablit. Activé par défaut. Désactivé, la lecture se poursuit à plein volume.
- **Tonalité avant de parler** — Joue une tonalité brève et discrète avant chaque énoncé, pour laisser à votre oreille le temps de passer de l'écoute passive à l'attention portée à la voix. Activé par défaut. Particulièrement utile lorsque les annonces sont rares ou qu'une musique joue en fond.
- **Ce qu'il faut annoncer** — Détermine quelles détections sont éligibles à une annonce. *Chaque détection* (par défaut) laisse la limitation décider. *Première fois par session* n'annonce une espèce que lors de sa première apparition dans la session en cours. *Liste de suivi uniquement* limite les annonces aux espèces de votre liste de suivi (utile pour un travail de relevé ciblé, où vous ne voulez entendre parler que de vos taxons prioritaires).

## Enregistrement

### Mode

- **Complet** — enregistrer tout l'enregistrement
- **Détections uniquement** — enregistrer des extraits autour des détections
- **Désactivé** — pas d'enregistrement audio

### Contexte de l'extrait

Lorsque **Détections uniquement** est actif, l'application affiche un unique curseur **Contexte de l'extrait** (0–5 s) qui fixe la quantité d'audio conservée **de part et d'autre** de chaque détection. Chaque extrait dure `fenêtre d'analyse + 2 × contexte de l'extrait` : avec une fenêtre d'analyse de 3 s et le contexte par défaut de 1 s, l'extrait enregistré fait donc 5 s. Un contexte de 2 s donne un extrait de 7 s (2 s avant + 3 s d'audio analysé + 2 s après). Des valeurs plus élevées vous laissent plus de marge pour l'inspection visuelle ou des outils d'analyse externes, au prix d'espace disque ; 0 n'enregistre que la fenêtre analysée elle-même.

### Format

Choisissez **WAV** ou **FLAC**. WAV est plus volumineux mais largement compatible et rapide à inspecter. FLAC conserve la même qualité audio sans perte tout en occupant moins d'espace, ce qui vaut généralement mieux pour les longues sessions.

Ce réglage s'applique à l'audio enregistré par BirdNET Live. L'**Analyse de fichiers** conserve une copie gérée par l'application du fichier importé dans son format d'origine : les fichiers MP3, AAC, WAV et FLAC restent donc consultables sans étape de conversion supplémentaire.

### Démarrer l'enregistrement automatiquement (mode Live uniquement)

Une fois activé, le mode Live commence à enregistrer dès l'ouverture de l'écran et la fin du chargement du modèle — sans avoir à appuyer sur le bouton du micro. Utile pour des installations de type borne, une utilisation mains libres (appareil monté sur le terrain, par exemple) ou tout flux où ouvrir Live signifie déjà « on démarre maintenant ». Désactivé par défaut, afin qu'un appui accidentel sur la tuile Live depuis l'écran d'accueil ne lance pas silencieusement une session. Le démarrage automatique ne se produit qu'une fois par visite de l'écran : arrêter une session puis réappuyer sur le micro fonctionne donc toujours comme un redémarrage manuel.

Ce réglage concerne l'ouverture du mode Live depuis l'application. Le [widget Quick Listen](live-mode.md) commence à écouter dès qu'on appuie dessus, quel que soit ce réglage, et ne le modifie pas. Si une session Point Count, Survey, Analyse de fichiers ou mode ARU est déjà en cours ou en cours de démarrage, cette session est préservée et il vous est demandé de l'arrêter d'abord.

### Enregistrer les sessions automatiquement (Live et Point Count)

Une fois activé (valeur par défaut), une session Live ou Point Count terminée est ajoutée automatiquement à votre bibliothèque dès qu'elle prend fin. Une fois désactivé, une session terminée s'ouvre dans le résumé avec la mention **non enregistrée** : l'icône d'enregistrement est mise en évidence et vous devez appuyer dessus pour conserver la session. Quitter le résumé sans enregistrer supprime la session et ses enregistrements. Cela convient aux écoutes rapides où vous ne souhaitez conserver qu'un résultat notable de temps en temps plutôt que d'accumuler chaque court enregistrement. Les déploiements Survey et ARU s'enregistrent toujours automatiquement — une longue session sans surveillance est trop précieuse pour être perdue faute d'avoir appuyé sur Enregistrer — ce commutateur ne s'y applique donc pas.

## Lecture

### Superposition de lecture dans le résumé

Une fois activé (valeur par défaut), écouter un extrait audio dans un résumé de session composé uniquement d'extraits (où aucun enregistrement complet ni spectrogramme n'est disponible) ouvre une superposition de lecture modale dédiée, avec commandes de transport et aperçu du spectrogramme, au lieu de lire l'extrait en arrière-plan. Si une session dispose de l'audio complet, ce réglage est contourné et la superposition de lecture n'apparaît jamais.

### Lire automatiquement les mémos vocaux

Désactivé par défaut. Une fois activé, un mémo vocal joint à une annotation horodatée est lu automatiquement pendant le Résumé de la session, au moment où la tête de lecture franchit sa position enregistrée. Le mémo est mixé par-dessus l'enregistrement plutôt que de le mettre en pause, vous entendez donc votre commentaire en contexte, avec l'audio d'origine. Laissez-le désactivé si vous préférez déclencher les mémos manuellement en appuyant sur leur étiquette d'annotation.

### Atténuation lors des mémos vocaux

Affiché uniquement lorsque **Lire automatiquement les mémos vocaux** est activé. Contrôle de combien l'enregistrement principal est atténué pendant la lecture d'un mémo vocal automatique. Des valeurs plus élevées rendent les mémos plus faciles à comprendre ; des valeurs plus basses laissent entendre davantage de l'enregistrement d'origine sous le mémo.

## Position

### Utiliser le GPS

Utiliser le GPS de l'appareil plutôt que des coordonnées saisies manuellement.
Sous Android, les positions proviennent du fournisseur de localisation de la
plateforme et non des services Google Play : l'application ne déclenche donc
pas la boîte de dialogue Google sur la précision de la localisation. Lorsque
cette option est désactivée, l'application ne lit jamais le GPS d'elle-même et
ne demande pas d'autorisation de localisation : les assistants de configuration
Survey, Point Count et ARU s'ouvrent sur la saisie manuelle avec vos
coordonnées enregistrées, le suivi GPS du relevé ne s'exécute pas, et la
préparation des cartes hors ligne se centre elle aussi sur ces coordonnées.

### Coordonnées manuelles

Les coordonnées utilisées lorsque **Utiliser le GPS** est désactivé. La latitude et la longitude sont toutes deux des champs de texte modifiables : vous pouvez donc **saisir** une valeur exacte ou **coller** une valeur copiée depuis une autre application — bien plus précis que faire glisser un curseur sur un écran tactile. Saisissez des degrés décimaux (par exemple `52.5200` et `13.4050`). Vous pouvez aussi coller une chaîne combinée `latitude, longitude` (séparée par une virgule, un point-virgule ou une espace) dans *l'un ou l'autre* des champs : les deux se remplissent d'un coup, ce qui correspond à ce que la plupart des cartes et sites web placent dans le presse-papiers. Les valeurs hors plage ou non numériques sont signalées sur place et ne sont pas enregistrées ; les valeurs valides sont conservées au fil de la saisie. L'intuition : la raison la plus fréquente de définir une position manuelle est d'identifier un son enregistré ailleurs que là où vous êtes, et cette position arrive généralement sous forme de texte depuis une autre source — saisir et coller en font une seule étape précise. Si vous préférez pointer un endroit plutôt que saisir des chiffres, **Choisir sur la carte** ouvre le même sélecteur de carte plein écran que les écrans de configuration, initialisé sur les coordonnées actuelles, et remplit les deux champs avec le lieu sur lequel vous appuyez.

### Actualiser le GPS maintenant

Force une nouvelle localisation au lieu de réutiliser la dernière valeur mise en cache par l'application. L'intuition : les relevés GPS sont mis en cache écran par écran pour qu'un écran de configuration n'ait pas à attendre un point satellite à chaque ouverture, mais ce cache peut être périmé de plusieurs kilomètres si vous avez roulé jusqu'à un nouveau site depuis la session précédente. Appuyez dessus lorsque vous vous êtes déplacé et que vous voulez que le filtre géographique utilise *ici*, et non l'endroit où votre matinée a commencé. Les coordonnées actuellement en cache sont indiquées dans le sous-titre, afin que vous puissiez vérifier où l'application vous situe. Si le GPS n'obtient pas de point en une dizaine de secondes, l'application se rabat sur la dernière position connue fournie par le système et vous avertit par un SnackBar pour que vous sachiez que la valeur est périmée.

### Téléchargements de cartes hors ligne

Les téléchargements de cartes hors ligne sont masqués pour l'instant, tant que BirdNET Live utilise le service public de tuiles OpenStreetMap. OpenStreetMap autorise la navigation cartographique interactive normale avec attribution, un agent utilisateur clair et une mise en cache locale, mais n'autorise ni le préchargement en masse ni les fonctions de téléchargement de cartes hors ligne depuis `tile.openstreetmap.org`. L'implémentation du téléchargeur est conservée pour une future source de tuiles qui autoriserait explicitement les paquets hors ligne.

### Filtre d'espèces

- **Désactivé** — pas de filtrage géographique
- **Filtre par position** — exclure les espèces sous le seuil géographique
- **Pondération par position** — utiliser le géo-modèle comme signal de pondération supplémentaire

### Seuil du géo-filtre

Apparaît lorsqu'un mode de filtrage fondé sur la position est actif.

## Export et synchronisation

### Formats

Cochez n'importe quelle combinaison de formats d'export : chaque enregistrement ou partage regroupera tous les formats sélectionnés dans une seule archive ZIP. Si vous choisissez un format unique, sans extraits audio ni rapport HTML, vous obtiendrez un fichier brut (par exemple `session.csv`) au lieu d'un ZIP, par compatibilité ascendante :

- Raven Selection Table — pour une utilisation dans Cornell Raven Pro.
- CSV — s'ouvre dans n'importe quel tableur.
- JSON — le plus commode pour un traitement programmatique ; contient l'ensemble des métadonnées de la session.
- GPX — trace et points de passage pour les outils cartographiques (n'a de sens que si le GPS était activé).

L'intuition : de nombreux flux de travail ont besoin de plusieurs formats à la fois — un CSV pour le tableur, une table Raven pour la relecture sur ordinateur et un JSON pour le script d'analyse. Démêler cela avec un sélecteur de format unique revenait auparavant à exporter trois fois la même session. Désormais, vous cochez les trois d'un coup et ils voyagent ensemble dans le ZIP.

### Inclure les fichiers audio

Inclure l'audio enregistré à côté des tableaux ou métadonnées exportés lorsque le flux d'export le permet.

### Toujours partager l'audio en WAV

Affiché uniquement lorsque **Inclure les fichiers audio** est activé. Une fois activé, les enregistrements FLAC sont convertis en WAV avant partage ou export. WAV est universellement compatible mais nettement plus volumineux que FLAC : laissez donc cette option désactivée, sauf si l'outil destinataire ne sait pas lire le FLAC — certains logiciels d'analyse de bureau anciens et quelques formulaires d'envoi ne le savent toujours pas.

### Inclure les métadonnées de l'application

Une fois activé, l'archive ZIP d'export contient un fichier annexe `*.metadata.json` décrivant comment la session a été produite : version de BirdNET Live, identité du modèle, relevé météo capturé au début de la session et tout avertissement d'intégrité audio détecté pendant l'enregistrement. L'intuition : c'est cette traçabilité qui vous permet (ou permet à un relecteur) de reproduire ou de vérifier une session des mois plus tard. Désactivez-la lorsque vous voulez partager proprement uniquement l'audio et les formats choisis — par exemple déposer un seul fichier WAV sur iNaturalist ou eBird sans fichiers propres à l'application.

### Inclure le rapport HTML

Une fois activé, chaque archive ZIP d'export contient également un fichier `<session>_report.html` à côté du tableau, des extraits audio et du GPX. Ouvrez-le dans n'importe quel navigateur et vous obtenez un résumé de session prêt à imprimer : une carte d'en-tête avec la date, le lieu, l'observateur et les totaux ; une carte interactive de la trace GPS et des marqueurs de détection ; une fiche par détection avec la vignette de la taxonomie Cornell, les noms, la pastille de score, votre confirmation, la note éventuelle que vous avez saisie et l'extrait audio d'origine dans un lecteur intégré ; ainsi que les paramètres d'analyse utilisés. L'intuition : un CSV est parfait pour les chaînes d'analyse mais inutile pour partager avec un collaborateur non technique ou imprimer un bref récapitulatif de terrain — le rapport HTML comble ce manque en un appui. Les vignettes d'espèces et les tuiles de carte nécessitent une connexion à la première ouverture du fichier (elles sont chargées en direct depuis l'API de taxonomie BirdNET et depuis OpenStreetMap), mais tout le reste — texte, mise en page, lecture audio, liens — fonctionne entièrement hors ligne. Désactivez-le si vous n'avez besoin que des données brutes et voulez un ZIP plus léger de quelques Ko.

### Partage de l'audio seul

Décochez tous les formats **ainsi que** le rapport HTML **et** la case des métadonnées de l'application, en ne laissant que **Inclure les fichiers audio** : Partager remettra alors au panneau système l'enregistrement brut (par exemple `BirdNET_Live_…flac`) au lieu d'un ZIP. C'est la voie la plus directe pour envoyer une session vers iNaturalist, eBird ou toute autre application attendant un fichier audio non empaqueté. Les sessions constituées d'extraits de détection (sans enregistrement complet) produisent toujours un ZIP, car il y a alors plus d'un fichier à partager.

## Confidentialité

Cette section détermine **quels services tiers BirdNET Live peut contacter en votre nom**. L'inférence elle-même s'exécute entièrement sur votre appareil : ces interrupteurs ne régissent que des fonctions réseau facultatives qui enrichissent l'expérience. Les trois interrupteurs sont **désactivés par défaut** sur une installation neuve ; rien ne sort tant que vous ne l'avez pas autorisé. L'intuition : chaque interrupteur se limite à un service concret et à un bénéfice concret, vous pouvez donc activer exactement ce qui est utile à votre travail, et rien d'autre.

### Autoriser les tuiles de carte

Nécessaire pour toute carte interactive de l'application (le sélecteur de position, la carte en direct de Survey et la carte de la session). Une fois activé, les composants cartographiques récupèrent des tuiles raster depuis les serveurs publics d'**OpenStreetMap** ; les requêtes de coordonnées de tuiles révèlent quelle zone du monde vous consultez. Les tuiles sont mises en cache localement jusqu'à six mois, avec un plafond de 6000 tuiles pour que la consultation répétée des cartes reste efficace sans croître indéfiniment. Activer cette option active aussi **Autoriser la recherche de noms de lieux**, car la plupart des personnes qui chargent des cartes s'attendent également à voir des noms de lieux lisibles sur leurs sessions. Vous pouvez ensuite désactiver séparément la recherche de noms de lieux. Lorsque les tuiles de carte sont désactivées, chaque écran cartographique bascule sur une carte de substitution, si bien que le reste de l'application continue de fonctionner sans fuite réseau.

### Autoriser la recherche de noms de lieux

Une fois activé, l'application envoie vos coordonnées enregistrées au service **Nominatim d'OpenStreetMap** afin d'obtenir un nom de lieu court (par exemple *« Berlin, Allemagne »*), affiché à côté de la session dans la Bibliothèque de sessions et le Résumé de la session. L'intuition : des coordonnées numériques sont précises mais difficiles à parcourir du regard dans une longue liste de sessions — un nom de lieu rend la liste lisible d'un coup d'œil. Une fois désactivé, les sessions n'affichent que la latitude et la longitude brutes, et Nominatim n'est jamais contacté.

### Autoriser la consultation météo

Une fois activé, chaque session enregistrée capture via **Open-Meteo** un relevé ponctuel des conditions locales (température, précipitations, vent, nébulosité) aux coordonnées d'enregistrement et à l'heure de fin. Le relevé apparaît dans le Résumé de la session sous la ligne de position et est repris dans l'export JSON, le bloc de métadonnées de la session et le rapport HTML. L'intuition : la météo est l'un des meilleurs prédicteurs de l'activité des oiseaux, et la capturer automatiquement — sans devoir penser à consulter une autre application — fait de chaque session un enregistrement plus complet. Open-Meteo est un service gratuit qui ne nécessite ni compte ni clé d'API. Une fois désactivé, aucune donnée météo n'est récupérée ni conservée. La configuration Point Count et Survey affiche également une carte météo compacte près des commandes de position : elle ne demande ce consentement que lorsque c'est nécessaire, présente le résultat sous forme d'icône + température + vent une fois activée, et réutilise le même relevé en cache lors de l'enregistrement de la session.

## À propos

La ligne **À propos** ouvre l'écran d'informations dans l'application.

## Zone de danger

### Réinitialiser l'introduction

Réaffiche la séquence d'introduction au prochain lancement de l'application.

### Réinitialiser tous les paramètres

Rétablit chaque préférence de cet écran à sa valeur par défaut. Les sessions, enregistrements, mémos vocaux, exports et tuiles de carte en cache restent intacts : seules les préférences enregistrées (curseurs, interrupteurs, choix des sélecteurs) sont effacées. L'application se ferme après confirmation, afin que les nouvelles valeurs par défaut prennent effet au prochain lancement.

Utile lorsque vous ne savez plus quel curseur vous avez déplacé et qui a cassé quelque chose, ou lorsque vous confiez l'appareil à quelqu'un d'autre et voulez une configuration propre sans perdre les données collectées.

### Effacer toutes les données

Supprime définitivement les sessions, détections, enregistrements, mémos vocaux, listes d'espèces personnalisées, préférences enregistrées, ainsi que les données en cache de cartes, noms de lieux, météo, lecture, résumé et partage. La boîte de dialogue de confirmation exige de saisir `DELETE`, puis ferme l'application afin que le prochain lancement reparte d'un état local vierge.

Utilisez-la avant de confier un appareil à un autre observateur, de retirer du service un téléphone de terrain ou de supprimer de l'application l'historique lié aux positions. Exportez d'abord tout ce dont vous avez besoin ; cette action est irréversible.

## Paramètres propres à un flux, hors Paramètres

Certains paramètres se configurent dans leurs propres écrans de configuration plutôt que dans l'écran Paramètres partagé.

- [Mode Point d'écoute](point-count-mode.md) dispose de sa propre configuration de durée et de position.
- [Mode Relevé](survey-mode.md) dispose de son propre écran de paramètres de relevé.
- [Analyse de fichiers](file-analysis.md) dispose de sa propre étape de paramètres d'analyse.
