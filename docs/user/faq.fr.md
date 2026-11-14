# FAQ

Questions fréquemment posées.

## Général

**Q : BirdNET Live nécessite-t-il une connexion Internet ?**
R : Non. Toute l'inférence s'exécute sur l'appareil à l'aide du modèle ONNX. Les seules fonctionnalités réseau sont facultatives et désactivées par défaut : les tuiles cartographiques et la recherche de noms de lieux via OpenStreetMap, les relevés météo via Open-Meteo, ainsi que les recherches d'images et de descriptions d'espèces à partir de l'API de taxonomie. Voir [Paramètres → Confidentialité](settings.md#confidentialité).

**Q : Combien d'espèces peut-il identifier ?**
R : Le modèle BirdNET+ V3.0 identifie 10 048 espèces dans le monde — oiseaux, amphibiens, mammifères et insectes (l'intersection élaguée du classificateur audio et du géo-modèle). Il reconnaît aussi 16 sons non animaux, comme les moteurs, les sirènes et la musique ; ils restent désactivés tant que vous n'activez pas [Sons non animaux](settings.md#sons-non-animaux).

**Q : Une espèce d'une ancienne Session porte un nouveau nom ou n'est plus détectée. Ai-je perdu quelque chose ?**
R : Non. Une mise à jour du modèle peut renommer des espèces pour suivre la taxonomie actuelle et abandonner celles que le nouveau modèle ne couvre pas. Les Sessions enregistrées ne sont pas modifiées : une détection plus ancienne s'affiche sous le nom actuel de l'espèce, avec son image, sa traduction et ses liens, et les espèces que le modèle ne détecte plus restent dans vos Sessions et vos exports exactement telles qu'elles ont été enregistrées.

**Q : Quelles plates-formes sont prises en charge ?**
R : Android (8.0+), iOS (15.0+) et Windows (expérimental).

## Précision

**Q : Pourquoi mon seuil de confiance affiche-t-il des scores faibles ?**
R : Réduisez le seuil de confiance dans les paramètres pour voir plus de détections. Le bruit de fond, le vent et la distance affectent la précision.

**Q : À quoi sert le filtre d'espèces ?**
R : Le géo-modèle prédit quelles espèces sont probables à votre position GPS et à la période de l'année. Activez **Filtre géographique** pour masquer les espèces improbables, **Filtre géographique adaptatif** pour ne masquer que celles dont le modèle audio n'est pas sûr non plus, ou **Pondération géographique** pour pondérer les résultats par probabilité géographique.

**Q : Quelle est la précision de l'identification ?**
R : La précision dépend de la qualité de l’enregistrement, de la distance, du bruit de fond et de l’espèce. Les détections de confiance élevée (> 70 %) sont généralement fiables. Vérifiez toujours visuellement les espèces rares.

## Enregistrement

**Q : Où sont stockés les enregistrements ?**
R : Dans le répertoire des documents de l'application sous `recordings/<session-id>/`. Au format WAV ou FLAC selon **Paramètres → Audio et enregistrement → Format d'enregistrement**.

**Q : Puis-je analyser des enregistrements existants ?**
R : Oui. Ouvrez l'analyse de fichiers depuis l'écran d'accueil, choisissez un fichier audio, définissez le lieu et les paramètres, puis lancez l'analyse. Les formats pris en charge incluent WAV, FLAC, MP3, OGG, Opus, M4A, AAC, WMA et AMR.

## Point Count

**Q : Qu'est-ce que le mode Point Count ?**
R : Un mode chronométré pour les comptages standardisés à poste fixe (points d'écoute). Vous définissez une durée fixe (3 à 30 minutes) et un lieu, puis l'application écoute en continu et s'arrête automatiquement à la fin du compte à rebours.

**Q : Puis-je mettre un Point Count en pause ?**
R : Non. Le respect du protocole exige un enregistrement ininterrompu. Vous pouvez terminer plus tôt avec le bouton d'arrêt.

**Q : Où vont les résultats d'un Point Count ?**
R : Ils apparaissent dans la bibliothèque de Sessions sous les noms « Point Count n°1 », « n°2 », etc. Vous pouvez les consulter, les modifier et les exporter comme n'importe quelle autre Session.

## Performance

**Q : Pourquoi l'appareil chauffe-t-il et la batterie se vide-t-elle vite ?**
R : L’inférence du modèle ONNX demande beaucoup de calcul. L'écran reste également allumé pendant les Sessions en direct. C'est normal pour un réseau de neurones exécuté en temps réel.

**Q : Le spectrogramme semble figé.**
R : Assurez-vous que l'autorisation du microphone est accordée et que la capture audio est active. Vérifiez qu'aucune autre application n'utilise le microphone.