# Analyse de fichiers

L'Analyse de fichiers traite un enregistrement existant via le même pipeline BirdNET que les flux de travail en direct.

## Comment l'ouvrir

Depuis l'accueil, appuyez sur la carte **Analyse de fichiers** avec l'icône :material-file-music:.

### Depuis une autre application

Vous pouvez aussi transmettre un enregistrement depuis une autre application. Sur Android, partager un fichier audio avec **BirdNET Live** ou choisir **Ouvrir avec** ouvre immédiatement l'Analyse de fichiers. Sur iOS, **Ouvrir avec** est également immédiat ; après avoir utilisé la feuille de partage, ouvrez BirdNET Live ou revenez-y pour que l'enregistrement en attente soit sélectionné automatiquement. Avant l'analyse, l'application copie l'enregistrement dans son propre stockage temporaire.

## Barre supérieure

- :material-tune: — ouvrir les paramètres de l'Analyse de fichiers
- :material-close: — annuler une analyse en cours

## Formats pris en charge

Le sélecteur de fichiers actuel accepte :

- WAV / WAVE
- FLAC
- MP3
- OGG / OGA / Opus
- M4A / AAC / MP4
- WMA / AMR

## Assistant en quatre étapes

### 1. Choisir un fichier

Choisissez un fichier et examinez sa fiche de métadonnées :

- nom du fichier
- format
- durée
- taille du fichier
- fréquence d'échantillonnage

### 2. Lieu et date

Vous pouvez :

- utiliser le GPS actuel
- saisir les coordonnées manuellement
- ignorer la localisation
- choisir un point sur la carte
- définir une date d'enregistrement facultative

### 3. Paramètres

L'assistant donne accès à :

- la durée de la fenêtre
- le chevauchement
- la sensibilité
- le seuil de confiance
- le mode de filtre d'espèces

Le chevauchement détermine de combien avance chaque fenêtre d'analyse ; il est
propre à l'analyse de fichiers : le fichier entier est toujours examiné, et
davantage de chevauchement l'examine simplement plus finement. Les modes en
direct utilisent plutôt une fréquence d'inférence, car ils doivent décider à
quelle fréquence s'exécuter sur l'audio entrant, et non avec quelle finesse
couvrir un enregistrement figé.

Quelle que soit la façon dont l'analyse de fichiers obtient ses fenêtres, elle
les transforme en détections avec les mêmes règles que le mode Live, Point
Count et Survey : une détection commence à sa première fenêtre de soutien,
porte le score étayé le plus fort et se termine à la fin de la dernière
fenêtre de soutien.

### 4. Analyser

L'écran de progression affiche :

- les fenêtres traitées
- les détections trouvées
- les espèces trouvées
- le bouton d'annulation

## Résultat

Une fois l'analyse terminée, BirdNET Live convertit le résultat en une session enregistrée et ouvre le [Résumé de la session](session-review.md).
