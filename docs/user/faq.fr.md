# FAQ

Questions fréquemment posées.

## Général

**Q : BirdNET Live nécessite-t-il une connexion Internet ?**
R : Non. Toutes les inférences s'exécutent sur l'appareil à l'aide du modèle ONNX. Les seules fonctionnalités du réseau sont les recherches d'images/descriptions d'espèces à partir de l'API de taxonomie, qui sont facultatives.

**Q : Combien d'espèces peut-il identifier ?**
R : Le modèle BirdNET+ V3.0 identifie 5 250 espèces d'oiseaux dans le monde (l'intersection élaguée du classificateur audio et du géomodèle).

**Q : Quelles plates-formes sont prises en charge ?**
R : Android (8.0+), iOS (15.0+) et Windows (expérimental).

## Précision

**Q : Pourquoi mon seuil de confiance affiche-t-il des scores faibles ?**
R : Réduisez le seuil de confiance dans les paramètres pour voir plus de détections. Le bruit de fond, le vent et la distance affectent la précision.

**Q : À quoi sert le filtre d'espèces ?**
R : Le géomodèle prédit quelles espèces sont probables à votre position GPS et à la période de l'année. Activez « Geo Exclusion » pour masquer les espèces improbables, ou « Geo Merge » pour pondérer les résultats par probabilité géographique.

**Q : Quelle est la précision de l'identification ?**
R : La précision dépend de la qualité de l’enregistrement, de la distance, du bruit de fond et de l’espèce. Les détections de confiance élevée (> 70 %) sont généralement fiables. Vérifiez toujours visuellement les espèces rares.

## Enregistrement

**Q : Où sont sauvegardés les enregistrements ?**
R : Dans le répertoire des documents de l'application sous `recordings/<session-id>/`. Les enregistrements complets sont enregistrés sous forme de fichiers WAV.

**Q : Puis-je analyser des enregistrements existants ?**
R : Oui. Ouvrez File Analysis depuis l'écran d'accueil, choisissez un fichier audio, définissez l'emplacement et les paramètres, puis appuyez sur Analyser. Les formats pris en charge incluent WAV, FLAC, MP3, OGG, Opus, M4A, AAC, WMA et AMR.

## Nombre de points

**Q : Qu'est-ce que le mode point d'écoute ?**
R : Un mode de point d'écoute chronométré pour les observations formelles d'oiseaux. Vous définissez une durée fixe (3 à 20 minutes) et un emplacement, puis l'application s'exécute en continu et s'arrête automatiquement lorsque la minuterie atteint zéro.

**Q : Puis-je suspendre un décompte de points ?**
R : Non. La conformité au protocole nécessite un enregistrement ininterrompu. Vous pouvez terminer plus tôt via le bouton d'arrêt.

**Q : Où vont les résultats d'inventaire ?**
R : Ils apparaissent dans la bibliothèque de sessions comme des sessions de point d'écoute numérotées. Vous pouvez les consulter, les modifier et les exporter comme n'importe quelle autre session.

## Performance

**Q : Pourquoi l'application chauffe-t-elle/utilise-t-elle la batterie ?**
R : L’inférence de modèle ONNX nécessite beaucoup de calcul. L'écran reste également allumé pendant les sessions en direct. Ceci est normal pour le traitement des réseaux neuronaux en temps réel.

**Q : Le spectrogramme semble figé.**
R : Assurez-vous que l'autorisation du microphone est accordée et que la capture audio est active. Vérifiez qu'aucune autre application n'utilise le microphone.
