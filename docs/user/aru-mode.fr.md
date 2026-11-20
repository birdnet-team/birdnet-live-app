# Mode ARU

!!! note "Implémentation préliminaire"
    Le mode ARU enregistre actuellement des sauvegardes intermédiaires du déploiement planifié, enregistre les cycles planifiés, exécute l'inférence en direct pendant les cycles actifs, enregistre les extraits de détection conservés lorsque ce mode d'enregistrement est sélectionné et affiche des commandes dans une notification de premier plan sur Android. Le comportement en arrière-plan sur iOS doit encore être validé sur le terrain.

Le mode ARU (Autonomous Recording Unit) est le mode destiné aux déploiements acoustiques planifiés sur site fixe.

## Configuration actuelle

- **Déploiement** (détails et paramètres d'analyse) :
    - **Métadonnées** : saisissez le nom du projet, l'ID ARU / station et le nom de l'observateur.
    - **Localisation** : renseignez les coordonnées du site à l'aide de l'acquisition GPS automatique, de la saisie manuelle de latitude/longitude, ou n'indiquez aucune localisation. La latitude et la longitude sont requises si vous utilisez un planning basé sur la position du soleil. Icônes : GPS :app-myLocation:, coordonnées manuelles :app-editLocationAlt:, aucune localisation :app-locationOff: et sélecteur de carte :app-mapSheet:.
    - **Analyse** : choisissez le microphone, la fréquence d’inférence, le seuil de confiance et la sensibilité.
    - **Format d'enregistrement** : choisissez entre les formats FLAC (compressé sans perte) et WAV (non compressé).
    - **Mode d'enregistrement** :
        - *Complet* : enregistre toute la durée de chaque cycle actif.
        - *Détections uniquement* : enregistre de courts extraits audio autour des vocalisations détectées. Vous pouvez régler le contexte de l'extrait (0 à 5 secondes d'audio conservées avant et après la détection) et choisir la méthode d'échantillonnage (*Toutes*, *Top N* ou échantillonnage *Smart* afin de limiter l'espace de stockage utilisé).
        - *Désactivé* : exécute l'inférence en temps réel pendant les cycles et journalise les détections, mais n'enregistre aucun fichier audio.
- **Planning** :
    - **Durée et répétition** : sélectionnez la durée de chaque cycle d'enregistrement actif et sa fréquence de répétition.
    - **Fenêtre d'enregistrement (profil nycthéméral)** : choisissez d'enregistrer 24 h/24 (*En continu*) ou limitez les cycles à *Jour*, à *Nuit* ou aux fenêtres *Autour du lever du soleil*, *Autour du coucher du soleil* ou *Autour du lever et du coucher du soleil*. Les fenêtres de lever/coucher du soleil sont calculées dynamiquement selon les coordonnées du déploiement.
    - **Fin du déploiement** : choisissez d'arrêter le déploiement manuellement, après un nombre fixe de cycles terminés ou automatiquement à une date et heure données.
    - **Gestion de la batterie** : définissez un seuil d'arrêt en cas de batterie faible (0-50 %) pour mettre en pause les déploiements et éviter que l'appareil ne s'éteigne complètement. S'il est configuré, vous pouvez définir un seuil de reprise pour relancer automatiquement les cycles d'enregistrement lorsque la batterie remonte (par exemple grâce à une recharge solaire).
    - **Cycle de test** : un cycle de test facultatif d'une minute est activé par défaut pour vérifier l'entrée micro et l'inférence dès le démarrage, sans compter parmi les cycles planifiés.
    - **Regroupement des Sessions** : choisissez d'enregistrer chaque cycle dans sa propre Session (recommandé pour des temps de chargement plus courts et un affichage modulaire) ou de regrouper tous les cycles dans une Session unique multisegment.
- **Prêt** : passez en revue le planning, l'estimation de stockage audio et les contraintes liées au soleil, puis lancez le déploiement.

Les commandes de configuration utilisent les mêmes icônes que les autres assistants : :app-micRounded: microphone, :app-speedRounded: fréquence d'inférence, :app-verifiedRounded: confiance, :app-hearing: sensibilité, :app-fiberManualRecordRounded: mode d'enregistrement, :app-timerOutlined: contexte de l'extrait et durée du cycle, :app-filterAltRounded: échantillonnage des détections et :app-formatListNumberedRounded: limite d'extraits par espèce. L'intervalle de répétition utilise :app-repeatRounded:, les commandes de batterie faible :app-batteryAlert: et :app-batteryChargingFull:, le cycle de test et le regroupement des Sessions :app-scienceRounded: et :app-libraryBooks:. Touchez le bouton :app-helpOutline: à côté d'une commande pour afficher son explication.

Au démarrage, une Session `SessionType.aru` est immédiatement enregistrée avec les métadonnées du planning ARU. Les cycles d'enregistrement sont en outre sauvegardés toutes les 30 secondes, y compris ceux sans détection. Après un plantage ou une coupure de courant, le dernier déploiement partiel apparaît dans la Bibliothèque de Sessions comme une Session terminée ; l'enregistrement ne redémarre pas. Ce qui a été capté depuis la dernière sauvegarde peut être perdu.

Les exports JSON et ZIP incluent les métadonnées du déploiement ARU. Les exports ZIP regroupent les fichiers d'enregistrement par cycle enregistrés sous `aru_cycles/`.

La configuration mémorise les choix d'enregistrement et de planification du dernier déploiement lancé. Le nom du déploiement, les coordonnées et la date de fin repartent de zéro à chaque fois.

## Écran de déploiement actif

L'écran ARU actif indique si le déploiement est en attente, en enregistrement ou terminé. Sa mise en page utilise quatre onglets :
- **État** : affiche l'état actuel du déploiement, le minuteur de cycle actif et une liste des détections en temps réel.
- **Audio** : affiche un spectrogramme en direct pour vérifier l'entrée audio tout en gardant les détections visibles en dessous.
- **Planning** : liste les 10 prochains cycles planifiés, avec les indications d'alignement lever/coucher de soleil si un profil nycthéméral est actif.
- **Résumé** : résume le temps écoulé, la durée totale de l'audio enregistré et les statistiques de détection.

Sur Android, les déploiements actifs affichent une notification de premier plan avec les actions Arrêter et Ouvrir.

L'arrêt d'un déploiement ouvre le Résumé de la Session. Si les cycles ont été regroupés dans une Session unique, cette Session s'ouvre ; s'ils ont été enregistrés séparément, la dernière Session de cycle terminée s'ouvre.

Sur iOS, cette implémentation préliminaire doit être utilisée au premier plan tant que l'enregistrement planifié en arrière-plan n'a pas été validé sur iOS.

## Toujours prévu

- Validation du comportement en arrière-plan sur iOS.
- Prise en charge complète de la lecture et du spectrogramme dans le Résumé de la Session pour les enregistrements ARU segmentés.
