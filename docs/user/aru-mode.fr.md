# Mode ARU

!!! note "Implémentation préliminaire"
    Le mode ARU enregistre actuellement des sauvegardes intermédiaires du déploiement planifié, enregistre les cycles planifiés, exécute l'inférence en direct pendant les cycles actifs, enregistre les clips de détection conservés lorsque ce mode d'enregistrement est sélectionné et affiche des contrôles de notification de premier plan sur Android. Le comportement en arrière-plan sur iOS doit encore être validé sur le terrain.

Le mode ARU (Autonomous Recording Unit) est le flux de travail pour les déploiements acoustiques planifiés sur site fixe.

## Flux de configuration actuel

- **Détails et réglages d’analyse** :
    - **Métadonnées** : saisissez le nom de déploiement, l'ID ARU/station et le nom de l'observateur.
    - **Localisation** : renseignez les coordonnées du site à l'aide de l'acquisition GPS automatique, de la saisie manuelle de latitude/longitude ou passez l'étape. La latitude et la longitude sont requises si vous utilisez un planning basé sur la position du soleil. Icônes : GPS :app-myLocation:, coordonnées manuelles :app-editLocationAlt:, ignorer la localisation :app-locationOff: et sélecteur de carte :app-mapSheet:.
    - **Analyse** : choisissez le microphone, la fréquence d’inférence, le seuil de confiance et la sensibilité.
    - **Format d'enregistrement** : choisissez entre les formats FLAC (compressé sans perte) et WAV (non compressé).
    - **Mode d'enregistrement** :
        - *Complet* : enregistre toute la durée de chaque cycle actif.
        - *Uniquement détections* : enregistre de courts clips audio autour des chants d'oiseaux détectés. Vous pouvez personnaliser le contexte du clip (ajout de 0 à 5 secondes de tampon audio pré- et post-détection) et choisir la méthode d'échantillonnage (*Toutes*, *Top N* ou échantillonnage *Smart* afin de limiter l'espace de stockage utilisé).
        - *Désactivé* : exécute l'inférence en temps réel pendant les cycles et journalise les détections, mais n'enregistre aucun fichier audio.
- **Planning (Plan)** :
    - **Durée et répétition** : sélectionnez la durée de chaque cycle d'enregistrement actif et sa fréquence de répétition.
    - **Fenêtre d'enregistrement (profil nycthéméral)** : choisissez d'enregistrer 24h/24 (*À tout moment*) ou limitez les cycles au *Jour uniquement*, à la *Nuit uniquement* ou à des fenêtres spécifiques *Autour du lever*, *Autour du coucher* ou *Autour du lever et coucher* du soleil. Les fenêtres de lever/coucher du soleil sont calculées dynamiquement selon les coordonnées du déploiement.
    - **Fin du planning** : choisissez d'arrêter le déploiement manuellement, après un nombre fixe de cycles terminés ou automatiquement à une date et heure données.
    - **Gestion de la batterie** : définissez un seuil d'arrêt en cas de batterie faible (0-50 %) pour mettre en pause les déploiements et éviter que l'appareil ne s'éteigne complètement. S'il est configuré, vous pouvez définir un seuil de reprise pour relancer automatiquement les cycles d'enregistrement lorsque la batterie remonte (par exemple grâce à une recharge solaire).
    - **Test** : un cycle de test facultatif d'une minute est activé par défaut pour vérifier l'entrée micro et l'inférence dès le démarrage, sans décompte des cycles programmés.
    - **Regroupement des Sessions** : configurez s'il faut enregistrer chaque cycle dans une Session distincte (recommandé pour des temps de chargement plus rapides et un affichage modulaire) ou combiner tous les cycles au sein d'une seule Session multisegment.
- **Prêt** : passez en revue le planning, l'estimation de stockage audio et les contraintes liées au soleil, puis lancez le déploiement.

Les contrôles de configuration utilisent les mêmes icônes que les autres assistants : :app-micRounded: microphone, :app-speedRounded: fréquence d'inférence, :app-verifiedRounded: confiance, :app-hearing: sensibilité, :app-fiberManualRecordRounded: mode d'enregistrement, :app-timerOutlined: contexte du clip et durée du cycle, :app-filterAltRounded: échantillonnage des détections et :app-formatListNumberedRounded: limite de clips par espèce. L'intervalle de répétition utilise :app-repeatRounded:, les contrôles de batterie faible :app-batteryAlert: et :app-batteryChargingFull:, le test et le regroupement des Sessions :app-scienceRounded: et :app-libraryBooks:. Touchez le bouton :app-helpOutline: à côté d'un contrôle pour afficher son explication.

Au démarrage, une Session `SessionType.aru` est immédiatement enregistrée avec les métadonnées du planning ARU. Les cycles d'enregistrement sont en outre sauvegardés toutes les 30 secondes, y compris ceux sans détection. Après un plantage ou une coupure de courant, le dernier déploiement partiel apparaît dans la Bibliothèque de sessions comme une Session terminée ; l'enregistrement ne redémarre pas. Ce qui a été capté depuis la dernière sauvegarde peut être perdu.

Les exports JSON et ZIP incluent les métadonnées du déploiement ARU. Les exports ZIP regroupent les fichiers d'enregistrement par cycle enregistrés sous `aru_cycles/`.

## Écran de déploiement actif

L'écran ARU actif indique si le déploiement est en attente, en enregistrement ou terminé. Sa mise en page utilise quatre onglets :
- **Statut** : affiche l'état actuel du déploiement, le minuteur de cycle actif et une liste des détections en temps réel.
- **Audio** : affiche un spectrogramme en direct pour vérifier l'entrée audio tout en gardant les détections visibles en dessous.
- **Plan** : liste les 10 prochains horaires de cycle programmés, avec les indications d'alignement lever/coucher de soleil si un profil nycthéméral est actif.
- **Résumé** : résume le temps écoulé, la durée totale de l'audio enregistré et les statistiques de détection.

Sur Android, les déploiements actifs affichent une notification de premier plan avec les actions Arrêter et Ouvrir.

L'arrêt d'un déploiement ouvre le Résumé de la session. Si les cycles ont été regroupés dans une seule Session, cette Session combinée s'ouvre ; s'ils ont été enregistrés séparément, la dernière Session de cycle terminée s'ouvre.

Sur iOS, cette implémentation préliminaire doit être traitée comme un flux de travail de premier plan jusqu'à ce que le comportement d'audio/arrière-plan programmé ait été validé sur iOS.

## Toujours prévu

- Validation du comportement en arrière-plan sur iOS.
- Prise en charge complète de la lecture et du spectrogramme dans le Résumé de la session pour les enregistrements ARU segmentés.
