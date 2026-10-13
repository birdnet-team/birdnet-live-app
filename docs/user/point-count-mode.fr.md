# Mode Point d'écoute

Le mode Point d'écoute est le flux de travail stationnaire et minuté de BirdNET Live.

## Comment l'ouvrir

Depuis l'accueil, appuyez sur la carte **Mode Point d'écoute** avec l'icône :app-locationOnRounded:.

## Flux de configuration

La configuration du point d'écoute comporte quatre étapes.

### 1. Durée et localisation

Choisissez :

- l’une des durées proposées : 3, 5, 10, 15, 20, 25 ou 30 minutes
- si le comptage continue avec l’écran éteint (activé par défaut)
- la position GPS actuelle avec :app-myLocation:
- des coordonnées manuelles avec :app-editLocationAlt:
- aucune localisation avec :app-locationOff:
- le sélecteur de carte avec :app-mapSheet:

L'écran de configuration actualise le GPS lorsque vous revenez de la boîte de
dialogue d'autorisation du système ou des paramètres de l'application : une
autorisation de localisation nouvellement accordée met donc à jour les
coordonnées sans avoir à relancer l'assistant. Cette même section comporte aussi
une carte météo. Si l'accès à la météo est désactivé, la carte demande le
consentement **Autoriser la recherche météo** ; une fois activée, elle donne un
aperçu du site avec une icône météo, la température et le vent uniquement. Le
même instantané Open-Meteo mis en cache est réutilisé lors de l'enregistrement
du point d'écoute.

### 2. Paramètres d'inférence

Choisissez les réglages d'analyse propres à la session, comme la fréquence d'inférence, le seuil de confiance et le mode de filtre
d'espèces. Ils partent de vos paramètres globaux, mais peuvent être ajustés pour
ce comptage sans modifier vos valeurs par défaut.

| Contrôle de configuration | Icône |
|---|---|
| Microphone | :app-micRounded: |
| Mode d'enregistrement | :app-fiberManualRecordRounded: |
| Contexte du clip | :app-timerOutlined: |
| Fréquence d'inférence | :app-speedRounded: |
| Seuil de confiance | :app-verifiedRounded: |
| Sensibilité | :app-hearing: |
| Filtre d'espèces | :app-filterAltRounded: |

Le bouton :app-helpOutline: à côté de chaque contrôle explique son effet. Le contrôle de durée :app-timerRounded: et le sélecteur de localisation ont le même bouton d'aide à la première étape.

Choisissez **Complet** pour enregistrer en continu (par défaut), **Extraits** pour garder un extrait de chaque vocalisation détectée ou **Désactivé** pour ne pas enregistrer d’audio. Ce choix est indépendant du réglage de Live Mode et mémorisé pour le prochain Point Count. Les extraits utilisent la même sélection de fenêtre au score maximal et le même contexte que Live Mode, sans réduction selon la localisation. Avec **Extraits**, le curseur **Contexte du clip** fixe les secondes conservées avant et après chaque fenêtre analysée ; il met aussi à jour le contexte de Live Mode.

### 3. Conseils de terrain

Cet écran présente une courte liste de vérification dans l'application à parcourir avant de commencer.

### 4. Prêt

L’écran prêt récapitule la durée, le choix d’enregistrement et le comportement avec l’écran éteint. Démarrez avec :app-playArrowRounded:.

## Écran du point d'écoute en direct

L'écran du point d'écoute en direct se concentre sur un tableau de bord minuté.

### Barre supérieure

- :app-stopRounded: — arrêter le point d'écoute prématurément
- :app-timerRounded: — afficher le temps restant
- :app-helpOutlineRounded: — ouvrir l'aide du Point Count
- :app-tuneRounded: — ouvrir les paramètres du Point d'écoute

### Principaux indicateurs

- barre de progression du compte à rebours
- barre d'informations compacte avec les détections actuelles, le nombre d'espèces uniques et le nombre total de détections
- vue du spectrogramme
- liste des détections

## Après le comptage

Avec **Continuer avec l’écran éteint** activé dans la configuration de Point Count, le comptage continue lorsque vous verrouillez l’écran ou changez d’application, même si l’écran reste allumé. Il s’arrête après la durée choisie ; le compte à rebours utilise le temps réellement écoulé, donc un écran suspendu ne prolonge pas le comptage. Android affiche une notification persistante avec Ouvrir et Arrêter. Désactivez le commutateur pour que ces actions terminent le comptage plus tôt. Point Count ne se met pas en pause pour reprendre ensuite, car cela interromprait le comptage chronométré. Si vous quittez pendant le démarrage, il est annulé avec un message ; configurez-le à nouveau. Sous Windows, réduire la fenêtre ne termine pas le comptage.

À la fin du Point Count, BirdNET Live ouvre [Résumé de la session](session-review.md). La Session est enregistrée automatiquement si cette option est activée ; sinon, enregistrez-la depuis le résumé pour la conserver.

Lorsque l'enregistrement automatique est activé, un comptage en cours est aussi enregistré au démarrage, toutes les 30 secondes et lorsque l'application quitte le premier plan. Après un plantage ou une coupure de courant, le dernier comptage partiel est disponible dans la Bibliothèque de sessions.
