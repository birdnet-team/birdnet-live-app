# Paramètres

BirdNET Live réutilise un même écran Paramètres dans plusieurs flux de travail. Le bouton :material-tune: ouvre les sections pertinentes pour l'écran d'où vous venez.

## Comment fonctionne la portée des paramètres

- L'ouverture des Paramètres depuis l'accueil affiche l'écran complet.
- L'ouverture des Paramètres depuis En direct, Relevé, Point d'écoute ou Analyse de fichiers filtre l'écran pour n'afficher que les sections pertinentes.

## Général

### Thème

Choisissez **Sombre**, **Clair** ou **Système**.

Si **Couleurs dynamiques** est activé, BirdNET Live essaie aussi de s'accorder à la palette système de votre appareil Android. Cela n'a d'effet que sur les appareils Android compatibles ; sur iPhone et iPad, l'application conserve le thème standard de BirdNET Live, et activer l'option n'y change donc rien.

### Langue de l'application

Définit la langue de l'interface.

### Noms des espèces

Contrôle la langue utilisée pour les noms d'espèces. **Système** utilise la langue préférée du téléphone lorsque ce nom est disponible, même si l'interface revient à l'anglais. **Suivre l'app** utilise plutôt la langue de l'interface.

### Afficher les noms scientifiques

Affiche les noms scientifiques sous les noms communs dans toute l'application.

### Superposition de lecture en révision

Lorsqu'elle est activée (ce qui est le réglage par défaut), l'écoute d'un clip audio dans un Résumé de la session contenant uniquement des clips (sans enregistrement/spectrogramme audio complet) déclenche un lecteur modal superposé dédié, avec des commandes de transport et un aperçu du spectrogramme, au lieu de lire le clip en arrière-plan. Si une session dispose de l'audio complet, ce réglage est ignoré et la superposition de lecture n'est jamais affichée.

### Nom de l'observateur

La configuration du Relevé, du Point d'écoute et de l'ARU mémorise le dernier nom d'observateur non vide saisi dans l'un de ces modes et le pré-remplit la fois suivante. Cela accélère l'utilisation répétée sur un téléphone de terrain personnel tout en vous laissant modifier ou effacer l'observateur avant de démarrer une session.

### ID ARU / station

La configuration ARU mémorise le dernier ID ARU / station non vide et le pré-remplit pour le déploiement suivant. Lorsqu'il est présent, l'ID est inclus dans le nom de la session ARU et dans les noms de fichiers d'export, afin que les déploiements répétés sur un même site fixe restent identifiables en dehors de l'application.

### Affichage de l'horodatage

Contrôle l'affichage des heures de chaque détection dans le Résumé de la session.

- **Relatif** affiche le décalage depuis le début de l'enregistrement, p. ex. `00:12:34`. Idéal pour parcourir une seule session et se caler sur la tête de lecture du spectrogramme.
- **Absolu** affiche l'heure locale au moment où la détection a été capturée, p. ex. `08:42:17`. Idéal pour recouper des notes de terrain, des relevés météo ou des enregistrements simultanés.

Si une détection tombe un jour calendaire différent du début de la session (p. ex. un relevé de nuit), l'heure absolue reçoit le suffixe `+1d` pour éviter de prendre l'aube de demain pour celle d'aujourd'hui.

Lorsque **Absolu** est sélectionné, un réglage supplémentaire **Afficher les secondes dans les horodatages** apparaît. Désactivez-le si vous préférez le format plus compact `08:42` à `08:42:17` — utile pour parcourir de longues listes de détections. Les décalages relatifs affichent toujours les secondes, car l'alignement avec la tête de lecture du spectrogramme exige une précision inférieure à la minute.

Le stockage et les exports utilisent toujours des instants UTC, quel que soit ce réglage : le choix n'affecte donc jamais les données — uniquement leur affichage.

## Audio

Ces contrôles apparaissent dans les flux de travail en direct pilotés par l'audio.

### Gain

Amplificateur linéaire appliqué à l'audio entrant avant qu'il n'atteigne le spectrogramme et le classifieur. Laissez à **1,0×** sauf si votre entrée est systématiquement trop faible — par exemple un micro-cravate à haute impédance sur un téléphone, ou une interface USB dont le préampli est réglé trop bas. Pousser le gain au-dessus de 1,0 ne révélera pas comme par magie des chants que le micro n'a jamais captés ; cela ne fait que remettre à l'échelle ce que le micro a fourni, de sorte que les sons forts et proches peuvent saturer. En dessous de 1,0, c'est utile dans le rare cas où une entrée trop forte sature le spectrogramme.

### Filtre passe-haut (Hz)

Coupe le contenu basse fréquence avant l'inférence à l'aide d'un filtre de Butterworth à 24 dB/octave — la valeur du curseur est la fréquence de coupure à −3 dB. **0 Hz le désactive.** Une coupure de 100 à 200 Hz élimine le vent, le grondement de la circulation et les bruits de manipulation sans toucher à la plupart des espèces ; en montant vers 500 à 1000 Hz, vous commencez à supprimer les sons graves, chouettes, tétras et butors, alors n'allez aussi haut que si vous ignorez délibérément ces espèces en échange d'un spectrogramme bien plus net dans un environnement urbain bruyant. La coupure choisie devrait apparaître comme une ligne horizontale nette sur le spectrogramme en direct.

### Source audio

Une seule feuille, deux réglages indépendants : **Microphone** — quelle entrée enregistre — et **Traitement** — dans quelle mesure le téléphone peut modifier le signal en entrée. Ils se combinent librement : enregistrer avec un micro USB en mode *non traité* est parfaitement possible. Votre choix est conservé d'un lancement à l'autre, et le même sélecteur apparaît sur les écrans de configuration du Relevé, du Point Count et de l'ARU. Les changements prennent effet immédiatement : même en pleine session, l'app remplace le micro à la volée au lieu d'attendre la session suivante.

**Microphone** liste nommément toutes les entrées exposées par le téléphone : micros USB, filaires et Bluetooth, et sur de nombreux téléphones les micros intégrés pris individuellement (par exemple *bas* et *arrière*). Les kits micro sans fil comme le Rode Wireless GO ou le DJI Mic passent par un récepteur USB-C : ils apparaissent donc ici comme de simples périphériques audio USB, en pleine qualité.

**Traitement** est la partie décisive, et elle n'existe que **sous Android**. Les téléphones appliquent par défaut au son du micro un traitement conçu pour la voix — réduction de bruit, mise en forme spectrale et gain automatique — car le micro sert avant tout à téléphoner. Ce traitement considère le chant des oiseaux comme un bruit à supprimer, et aucun réglage ordinaire ne le désactive. La seule échappatoire est de demander à Android une *source audio* différente :

| Option | Effet |
|---|---|
| **Défaut du téléphone** | Ce que fait habituellement votre téléphone, traitement vocal compris. Le comportement d'origine, et toujours la valeur par défaut afin de ne rien changer pour les utilisateurs existants. |
| **Non traitée** | Le signal brut du micro — ni réduction de bruit, ni gain automatique. Généralement le meilleur choix pour les oiseaux. |
| **Reconnaissance vocale** | Désactive elle aussi la réduction de bruit et le gain automatique, et fonctionne sur presque tous les téléphones. |

**Essayez-les et comparez.** Le gagnant dépend réellement du modèle. *Non traitée* est l'idéal, mais Android ne l'honore que sur les téléphones dont le fabricant déclare la prise en charge ; sur les autres, il bascule silencieusement et le rendu est identique à *Par défaut du système*. C'est à cela que sert *Reconnaissance vocale* : les règles de compatibilité d'Android **exigent** que le gain automatique et la réduction de bruit soient désactivés pour cette source. Elle fournit donc un son non traité même sur les téléphones qui ignorent *Non traitée*. Si passer à *Non traitée* ne change rien, passez à *Reconnaissance vocale*.

Attendez-vous à ce que les options non traitées sonnent **plus faiblement** : c'est le gain automatique qui a disparu, pas un défaut. Augmentez le **Gain** si l'indicateur de niveau paraît bas.

**Sous iOS**, le réglage Traitement est masqué et la feuille se réduit à une liste de microphones. iOS fournit déjà à l'app un son pratiquement non traité : il n'y a donc pas d'équivalent à choisir.

## Inférence

### Durée de la fenêtre

Contrôle la longueur de la fenêtre d'analyse.

### Seuil de confiance

Définit le degré de prudence des détections. La valeur par défaut est de **35 %**, ce qui garde la liste en direct centrée sur les correspondances les plus fortes tout en laissant de la place aux chants lointains ou partiellement masqués. Abaissez-le si vous recensez des espèces rares ou discrètes et comptez examiner davantage de candidats plus tard ; augmentez-le quand le bruit de fond ou des faux positifs courants encombrent la session.

### Sensibilité

Un décalage sur l'axe x appliqué aux scores de probabilité bruts du modèle avant le Score Pooling, le filtrage géographique et le seuil de confiance. Le modèle audio BirdNET inclut déjà une activation sigmoïde ; BirdNET Live reconvertit donc d'abord chaque probabilité en espace logit, ajoute le biais de sensibilité, puis la reconvertit en probabilité. Des valeurs plus élevées rendent le détecteur plus permissif — des chants plus faibles ou plus ambigus franchissent le seuil, au prix de plus de faux positifs. Des valeurs plus basses sont plus strictes et ne laissent passer que les détections sûres. La valeur par défaut de **1,0** n'applique aucun décalage et correspond à la référence BirdNET. Essayez **1,25** si vous suspectez que le modèle manque des chants lointains ; descendez à **0,75** si vous êtes submergé par des détections de faible qualité d'espèces communes. La sensibilité est appliquée à chaud : la modifier en cours de session prend effet à la fenêtre d'inférence suivante.

### Fréquence d'inférence

Contrôle la fréquence à laquelle BirdNET exécute l'inférence.

### Agrégation des scores

Combine les scores des fenêtres d'inférence récentes pour qu'une seule fenêtre bruitée ne domine pas le résultat. **Désactivée** utilise la probabilité de chaque fenêtre — la plus réactive, la plus bruitée. **Moyenne** fait la moyenne arithmétique des fenêtres récentes pour la sortie la plus lissée. **Max** conserve le pic le plus fort par espèce, ce qui est le mode de lissage le plus réactif, adapté aux chants brefs et marqués. **LME** (log-mean-exp, par défaut) est le maximum doux de référence de BirdNET : il se comporte comme *max* quand une fenêtre domine et comme *moyenne* quand plusieurs fenêtres concordent. En mode LME, une nouvelle espèce a aussi besoin de plusieurs confirmations de fenêtres individuelles avant d'apparaître pour la première fois, tandis que les détections soutenues conservent l'essentiel de leur meilleur score récent sur une seule fenêtre, et qu'une espèce déjà visible reste affichée jusqu'à ce que son score agrégé passe sous le seuil de confiance. Changer de mode en cours de session vide la mémoire glissante pour que les anciens scores ne se reportent pas sur le nouveau mode.

### Nombre de fenêtres de pooling

Contrôle le nombre de fenêtres d'inférence consécutives qui participent à l'agrégation des scores. Une valeur plus grande lisse le score de chaque espèce sur un horizon temporel plus long, ce qui supprime les détections ponctuelles parasites — utile pour les chants réguliers et lointains, lorsque vous préférez attendre plusieurs fenêtres concordantes avant de remonter une détection. Une valeur plus petite réagit plus vite aux vocalises brèves mais laisse passer plus de bruit. La valeur par défaut de **5** correspond à celle historiquement codée en dur dans le modèle et constitue un bon point de départ pour une utilisation en direct.

## Spectrogramme

### Taille FFT

Contrôle la résolution fréquentielle du spectrogramme.

### Palette de couleurs

Choisissez **Viridis**, **Magma** ou **Niveaux de gris**.

### Durée (vitesse de défilement)

Contrôle la durée visible dans la fenêtre du spectrogramme.

### Plage de fréquences

Définit la fréquence d'affichage supérieure.

### Amplitude logarithmique

Applique une échelle logarithmique au spectrogramme pour une lecture visuelle plus facile.

### Qualité

Contrôle la fluidité de la mise à l'échelle de l'image du spectrogramme. **Moyenne** est le compromis par défaut. Choisissez **Basse** sur les téléphones plus anciens si le défilement saccade ou si l'appareil chauffe ; choisissez **Haute** si vous préférez un rendu plus fluide et que votre appareil dispose d'une marge GPU suffisante. L'intuition : cela ne modifie que le coût de rendu, pas l'analyse audio ni les résultats de détection.

## Annonces

Cette section contrôle si BirdNET Live **énonce les détections à voix haute via vos écouteurs ou le haut-parleur du téléphone** pendant l'enregistrement d'une session. La fonction est **désactivée par défaut** car elle modifie l'environnement acoustique autour du microphone — l'activer est un compromis volontaire. Il n'y a pas d'assistant de configuration : les sélecteurs de verbosité × fréquence ci-dessous *constituent* toute la configuration, vous pouvez donc choisir un autre préréglage à tout moment et entendre immédiatement la différence. L'intuition : lors de longs relevés, vous ne pouvez pas regarder l'écran en permanence ; une voix discrète à l'oreille vous permet de garder les yeux sur l'habitat tout en sachant ce qui vient d'être entendu.

### Énoncer les détections à voix haute (interrupteur principal)

Désactivé par défaut. Une fois activé, l'application énonce chaque détection acceptée via la synthèse vocale intégrée de votre appareil. **Les écouteurs sont fortement recommandés** — utiliser le haut-parleur du téléphone risque de faire reprendre l'annonce par le microphone et de la redétecter, c'est pourquoi l'application coupe brièvement le micro autour de chaque énoncé pour éviter cette boucle (voir *Couper le micro pendant l'énoncé* ci-dessous).

### Préréglage de verbosité

À quel point l'application commente chaque détection. **Minimal** énonce seulement le nom de l'espèce (idéal pour de très longs relevés où vous ne voulez qu'un repère). **Équilibré** est le réglage par défaut — des phrases courtes et variées comme *« Rougegorge »*, *« Un rougegorge entendu »*, *« Encore un rougegorge »*. **Bavard** ajoute un peu plus de contexte, comme si quelqu'un commentait à vos côtés. **Personnalisé** apparaît automatiquement si vous modifiez à la main les valeurs avancées. L'intuition : un même réglage de fréquence peut sembler trop discret ou trop bavard selon la formulation — la verbosité vous laisse garder la cadence et ne régler que le nombre de mots.

### Préréglage de fréquence

À quelle fréquence l'application est autorisée à parler. Cinq niveaux, du plus discret au plus bavard. **Très rare** et **Rare** attendent longtemps entre les annonces et plafonnent le débit — bien adaptés aux relevés de plusieurs heures où vous voulez un sentiment d'activité sans commentaire continu. **Normal** est la cadence conversationnelle par défaut. **Fréquent** raccourcit les intervalles et relève le plafond ; adapté aux courtes sessions En direct ou quand vous voulez un retour plus proche du temps réel. **Constant** supprime entièrement le délai de démarrage et laisse l'application parler à presque chaque cycle de détection — utile pour les démonstrations, l'accessibilité, ou quand le délai avant la première annonce en *Fréquent* vous paraît trop long. **Personnalisé** apparaît quand vous modifiez les champs de timing dans Avancé. L'intuition : c'est le seul réglage qui décide si l'application reste en arrière-plan ou devient une présence — choisissez un autre préréglage et vous entendrez la nouvelle cadence dès le cycle de détection suivant, sans bouton d'enregistrement.

### Voix (vitesse et tonalité)

Deux curseurs qui ajustent la voix de la synthèse vocale de la plateforme. **Vitesse** va de 0,5× à 1,5× ; la valeur par défaut 1,0× correspond au rythme « normal » de la plateforme. **Tonalité** va de 0,7× à 1,3×. L'intuition : une légère baisse de tonalité et un léger ralentissement peuvent rendre les annonces bien plus faciles à comprendre en extérieur avec du vent ou de l'eau en fond ; le bouton *Tester un exemple* ci-dessous prévisualise trois noms d'oiseaux courants avec les réglages actuels pour itérer sans quitter l'écran.

### Avancé

Une section dépliable qui expose quelques interrupteurs de routage audio ainsi que le sélecteur de mode de déclenchement. En général, vous n'avez pas besoin de l'ouvrir — les préréglages de verbosité et de fréquence ci-dessus sont les seuls réglages qui comptent au quotidien. Les valeurs de limitation de débit (délai de démarrage, écart minimum, max par minute, pause de série, réinitialisation de récence) sont regroupées dans le curseur **Fréquence**, pour qu'il y ait un seul endroit évident où régler la cadence.

- **Autoriser le haut-parleur du téléphone** — Désactivé, les annonces sont silencieusement sautées s'il n'y a ni écouteurs ni haut-parleur externe connectés. Activé, le haut-parleur du téléphone sert de repli. Activez-le pour une écoute occasionnelle à la maison ; laissez-le désactivé sur le terrain pour garantir l'absence de retour acoustique vers le microphone.
- **Couper le micro pendant l'énoncé** — Remplace l'audio entrant par du silence pendant que l'application parle, pour que la sortie du haut-parleur ne soit pas reprise par le microphone et redétectée. Fortement recommandé (et activé par défaut). Ne le désactivez que si votre microphone est acoustiquement isolé du haut-parleur du téléphone — par exemple un micro-cravate sur un autre câble ou une oreillette Bluetooth.
- **Atténuer les autres sons** — Baisse brièvement le volume de la musique ou des podcasts des autres applications pendant l'annonce, puis le restaure. Activé par défaut. Désactivé, l'annonce joue au volume plein.
- **Bip avant l'annonce** — Joue un bref signal sonore avant chaque énoncé pour que votre oreille ait un instant pour passer de l'écoute passive à l'attention à la voix. Activé par défaut. Particulièrement utile quand les annonces sont peu fréquentes ou quand de la musique joue en fond.
- **Que faut-il annoncer** — Détermine quelles détections peuvent donner lieu à une annonce. *Chaque détection* (par défaut) laisse la limitation décider. *Première fois par session* annonce une espèce uniquement à sa première apparition dans la session en cours. *Liste de suivi uniquement* limite les annonces aux espèces de votre liste de suivi (utile pour un relevé ciblé où vous ne voulez entendre que vos taxons prioritaires).

## Enregistrement

### Mode

- **Complet** — enregistrer tout l'enregistrement
- **Détections uniquement** — enregistrer des clips autour des détections
- **Désactivé** — aucun enregistrement audio

### Contexte du clip

Lorsque **Détections uniquement** est actif, l'application affiche un unique curseur **Contexte du clip** (0 à 5 s) qui définit la quantité d'audio conservée de **chaque côté** de chaque détection. Chaque clip a une longueur de « fenêtre d'analyse + 2 × contexte du clip » : avec une fenêtre d'analyse de 3 s et le contexte par défaut de 1 s, le clip enregistré dure 5 s. Régler le contexte sur 2 s donne un clip de 7 s (2 s avant + 3 s d'audio analysé + 2 s après). Des valeurs plus élevées vous laissent plus de marge pour l'inspection visuelle ou des outils de révision externes, au prix d'espace disque ; 0 n'enregistre que la fenêtre analysée elle-même.

### Format

Choisissez **WAV** ou **FLAC**. WAV est plus volumineux mais largement compatible et rapide à inspecter. FLAC conserve la même qualité audio sans perte tout en occupant moins d'espace, ce qui est généralement préférable pour les longues sessions.

Ce réglage s'applique à l'audio enregistré par BirdNET Live. L'**Analyse de fichiers** conserve une copie gérée par l'application du fichier importé dans son format d'origine, de sorte que les imports MP3, AAC, WAV et FLAC restent consultables sans étape de conversion supplémentaire.

### Démarrer l'enregistrement automatiquement (mode En direct uniquement)

Une fois activé, le mode En direct commence à enregistrer dès l'ouverture de l'écran et la fin du chargement du modèle — sans avoir à appuyer sur le bouton du microphone. Utile pour les installations de type kiosque, l'usage mains libres (p. ex. appareil monté sur le terrain) ou tout flux où vous savez déjà qu'ouvrir le mode En direct signifie « démarrer maintenant ». Désactivé par défaut pour qu'un appui accidentel sur la tuile En direct depuis l'accueil ne lance pas silencieusement une session. Le démarrage automatique ne se déclenche qu'une fois par visite de l'écran : arrêter une session puis réappuyer sur le micro fonctionne toujours comme un redémarrage manuel.

Ce réglage concerne l'ouverture du mode En direct depuis l'application. Le [widget « Écoute rapide »](live-mode.md) démarre l'écoute lorsqu'on appuie dessus, quel que soit ce réglage, et le laisse inchangé. Si une Session Point Count, Survey, File Analysis ou mode ARU est déjà en cours ou démarre, il la préserve et vous demande d'abord de l'arrêter.

## Localisation

### Utiliser le GPS

Utiliser le GPS de l'appareil au lieu des coordonnées manuelles.

### Latitude / Longitude

Coordonnées manuelles utilisées lorsque le GPS est désactivé.

### Actualiser le GPS maintenant

Force un nouveau point de localisation au lieu de réutiliser la dernière valeur mise en cache. L'intuition : les relevés GPS sont mis en cache par écran pour qu'un écran de configuration ne bloque pas en attendant un point satellite à chaque ouverture, mais ce cache peut être très en retard si vous avez roulé jusqu'à un nouvel endroit depuis la dernière session. Appuyez ici lorsque vous vous êtes déplacé et que vous voulez que le filtre géographique utilise *ici*, pas l'endroit d'où vous êtes parti le matin. Les coordonnées actuellement en cache sont indiquées dans le sous-titre pour que vous puissiez vérifier où l'application pense que vous vous trouvez. Si le GPS n'obtient pas de point en ~10 secondes, l'application se rabat sur la dernière position connue fournie par le système et vous avertit par une notification pour signaler que la valeur n'est plus à jour.

### Téléchargements de cartes hors ligne

Les téléchargements de cartes hors ligne sont actuellement masqués tant que BirdNET Live utilise le service de tuiles public OpenStreetMap. OpenStreetMap autorise une navigation cartographique interactive normale avec attribution, un user agent clair et une mise en cache locale, mais ne permet pas le préchargement en masse ni les fonctions de téléchargement de cartes hors ligne depuis `tile.openstreetmap.org`. L'implémentation du téléchargeur est conservée pour une future source de tuiles qui autorise explicitement les paquets hors ligne.

### Filtre d'espèces

- **Désactivé** — aucun filtrage géographique
- **Filtre géographique** — exclut les espèces situées sous le seuil géographique
- **Pondération géographique** — utilise le géo-modèle comme signal de pondération supplémentaire

### Seuil du filtre géographique

Apparaît lorsqu'un mode de filtre basé sur la localisation est actif.

## Export et synchronisation

### Formats

Cochez n'importe quelle combinaison de formats d'export — chaque enregistrement / partage regroupera tous les formats sélectionnés dans un unique ZIP. Si vous choisissez un seul format, sans clips audio et sans rapport HTML, vous obtiendrez un fichier brut (p. ex. `session.csv`) plutôt qu'un ZIP, par rétrocompatibilité :

- Table de sélection Raven — pour Cornell Raven Pro.
- CSV — s'ouvre dans n'importe quel tableur.
- JSON — le plus simple pour un traitement programmatique ; contient les métadonnées complètes par session.
- GPX — tracé et points de passage pour les outils cartographiques (utile uniquement si le GPS était activé).

L'intuition : beaucoup de flux de travail ont besoin de plusieurs formats à la fois — un CSV pour le tableur, une table Raven pour la révision sur ordinateur et un JSON pour le script d'analyse. Avant, démêler cela avec un seul format à la fois revenait à exporter la même session trois fois. Maintenant, vous cochez les trois une seule fois et ils voyagent ensemble dans le ZIP.

### Inclure les fichiers audio

Inclut l'audio enregistré aux côtés des tables ou métadonnées exportées lorsque le flux d'export le prend en charge.

### Inclure le rapport HTML

Une fois activé, chaque ZIP d'export contient aussi un fichier `<session>_report.html` à côté de la table, des clips audio et du GPX. Ouvrez-le dans n'importe quel navigateur pour obtenir un résumé prêt à imprimer de la session : carte d'en-tête avec date, lieu, observateur et totaux ; carte interactive du tracé GPS et des marqueurs de détection ; une fiche par détection avec la vignette de la taxonomie Cornell, les noms, la pastille de score, votre confirmation, toute note saisie et le clip audio d'origine intégré sous forme de lecteur ; et les paramètres d'analyse utilisés. L'intuition : un CSV est parfait pour les chaînes d'analyse mais inutile pour partager avec une personne non technique ou imprimer un résumé de terrain rapide — le rapport HTML comble ce manque en un appui. Les vignettes d'espèces et les tuiles de carte nécessitent une connexion la première fois que le fichier est ouvert (elles sont récupérées en direct depuis l'API de taxonomie BirdNET et OpenStreetMap), mais tout le reste — texte, mise en page, lecture audio, liens — fonctionne entièrement hors ligne. Désactivez-le si vous n'avez besoin que des données brutes et voulez garder le ZIP un peu plus léger.

## Confidentialité

Cette section contrôle **quels services tiers BirdNET Live peut contacter en votre nom**. L'inférence elle-même s'exécute entièrement sur votre appareil — ces interrupteurs ne pilotent que des fonctions réseau optionnelles qui enrichissent l'expérience. Les trois interrupteurs sont **désactivés par défaut** sur une nouvelle installation ; rien ne sort tant que vous ne l'avez pas autorisé. L'intuition : chaque interrupteur est limité à un service concret et un bénéfice concret, pour que vous activiez exactement ce qui est utile à votre flux de travail et rien d'autre.

### Autoriser les tuiles de carte

Requis pour toute carte interactive de l'application (le sélecteur de position, la carte en direct du Relevé et la carte de la session). Une fois activé, les widgets de carte récupèrent des tuiles raster depuis les serveurs publics **OpenStreetMap** ; les requêtes de coordonnées de tuile révèlent quelle zone du monde vous regardez. Les tuiles sont mises en cache localement jusqu'à six mois, avec un plafond de 6000 tuiles pour que les consultations répétées restent efficaces sans croître indéfiniment. Activer cette option active aussi **Autoriser la recherche du nom du lieu**, car la plupart des personnes qui chargent des cartes s'attendent à ce que les sessions affichent aussi des noms de lieux lisibles. Vous pouvez désactiver à nouveau la recherche de nom de lieu séparément. Lorsque les tuiles de carte sont désactivées, chaque écran de carte se rabat sur un panneau d'attente, de sorte que le reste de l'application fonctionne toujours sans fuite réseau.

### Autoriser la recherche du nom du lieu

Une fois activé, l'application envoie vos coordonnées enregistrées au service **Nominatim** d'OpenStreetMap pour obtenir un nom de lieu court (p. ex. *« Berlin, Allemagne »*) affiché à côté de la session dans la Bibliothèque de sessions et le Résumé de la session. L'intuition : les coordonnées numériques sont précises mais difficiles à parcourir dans une longue liste de sessions — un nom de lieu rend la liste lisible d'un coup d'œil. Lorsqu'il est désactivé, les sessions n'affichent que les coordonnées brutes, et Nominatim n'est jamais contacté.

### Autoriser la recherche météo

Une fois activé, chaque session enregistrée capture un instantané unique des conditions locales (température, précipitations, vent, couverture nuageuse) aux coordonnées et à l'heure de fin de l'enregistrement via **Open-Meteo**. L'instantané apparaît dans le Résumé de la session sous la ligne de localisation et est repris dans l'export JSON, le bloc de métadonnées par session et le rapport HTML. L'intuition : la météo est l'un des prédicteurs les plus forts de l'activité des oiseaux, et la capturer automatiquement — sans avoir à penser à consulter une autre application — fait de chaque session un dossier plus complet. Open-Meteo est un service gratuit qui ne nécessite ni compte ni clé d'API. Lorsqu'il est désactivé, aucune donnée météo n'est récupérée ni stockée. La configuration du Point d'écoute et du Relevé affiche aussi une carte météo compacte près de leurs contrôles de localisation : elle ne demande ce consentement que lorsque c'est nécessaire, prévisualise le résultat sous forme d'icône + température + vent une fois activée, et réutilise le même instantané mis en cache lors de l'enregistrement de la session.

## À propos

La ligne **À propos** ouvre l'écran À propos intégré à l'application.

## Zone de danger

### Réinitialiser l'introduction

Affiche à nouveau la séquence d'introduction au prochain lancement de l'application.

### Réinitialiser tous les paramètres

Restaure chaque préférence de cet écran à sa valeur par défaut. Les sessions, enregistrements, mémos vocaux, exports et tuiles de carte en cache restent intacts — seules les préférences enregistrées (curseurs, interrupteurs, choix de sélecteurs) sont effacées. L'application se ferme après confirmation pour que les nouvelles valeurs par défaut s'appliquent au prochain lancement.

Utile lorsque vous ne savez plus quel curseur déplacé a cassé quelque chose, ou quand vous confiez l'appareil à quelqu'un d'autre et voulez une configuration propre sans perdre les données collectées.

### Supprimer toutes les données

Supprime définitivement les sessions, détections, enregistrements, mémos vocaux, listes d'espèces personnalisées, préférences enregistrées et données en cache de cartes, noms de lieux, météo, lecture, révision et partage. La boîte de dialogue de confirmation exige de saisir `DELETE`, puis ferme l'application pour que le prochain lancement reparte d'un état local propre.

Utilisez cette action avant de confier un appareil à une autre personne observatrice, de mettre au rebut un téléphone de terrain ou de supprimer l'historique lié aux emplacements. Exportez d'abord tout ce dont vous avez besoin ; cette action est irréversible.

## Paramètres spécifiques aux flux de travail, hors Paramètres

Certains paramètres se configurent dans leurs propres écrans de configuration plutôt que dans l'écran Paramètres partagé.

- [Mode Point d'écoute](point-count-mode.md) possède sa propre configuration de durée et de localisation.
- [Mode Relevé](survey-mode.md) possède son propre écran de paramètres de relevé.
- [Analyse de fichiers](file-analysis.md) possède sa propre étape de paramètres d'analyse.
