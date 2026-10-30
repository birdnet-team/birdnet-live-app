# Envois

Les envois acheminent les sessions terminées de nombreux téléphones vers un seul dossier de projet. Un responsable de projet configure un dossier une fois pour toutes et distribue un lien ou un code QR ; chaque contributeur le colle ou le scanne, et dès lors toute session peut être envoyée vers ce dossier en deux touches depuis la boîte de dialogue Partager. Les déploiements ARU peuvent envoyer d'eux-mêmes chaque session terminée.

Les envois se font dans un seul sens. L'application écrit des fichiers dans le dossier du projet et n'y lit, n'y liste ni n'y supprime jamais rien. Supprimer une session sur votre téléphone laisse la copie envoyée intacte, et rien n'est jamais envoyé sans que vous ayez coché une destination ou activé les envois ARU automatiques.

## Fonctionnement

Une **destination** est un dossier WebDAV dans lequel l'application peut écrire. Trois types fonctionnent sans configuration particulière :

- un partage **File Drop Nextcloud**, le choix recommandé pour la plupart des projets ;
- toute **adresse WebDAV** avec un nom d'utilisateur et un mot de passe, par exemple un dossier de votre propre compte cloud ou un serveur institutionnel ;
- le **serveur de dépôt de référence** livré avec BirdNET Live, pour les responsables qui veulent des jetons par contributeur et un export CSV prêt à l'emploi (voir le [Guide du développeur](../developer/upload-drop-server.md)).

Chaque envoi est **un seul fichier ZIP par session**, nommé comme l'export de Partager, par exemple `BirdNET_Live_2026-05-14_06-30-00_#13.zip`. Il contient toujours l'enregistrement JSON de la session et, selon ce que vous cochez, l'audio, les tables de détections, le rapport HTML et le fichier de métadonnées de l'application. Le ZIP est déposé dans un dossier portant le nom de votre **identifiant d'envoi**, un code à huit caractères que l'application dérive d'une identité aléatoire conservée pour cette installation. Le dossier du responsable de projet ressemble donc à ceci :

```
4ee91c8f/BirdNET_Live_2026-05-14_06-30-00_#13.zip
4ee91c8f/BirdNET_Live_2026-05-14_07-02-10_#14.zip
b27c0e51/BirdNET_Live_2026-05-14_06-45-00_#3.zip
.birdnet-live/4ee91c8f.json
.birdnet-live/b27c0e51.json
```

Le dossier `.birdnet-live` contient un petit fichier d'enregistrement par appareil, écrit par le test de connexion. Nextcloud le masque tant que « Afficher les fichiers cachés » n'est pas activé. Il porte l'identifiant d'envoi, la version de l'application, la plateforme et l'**identifiant de participant** facultatif (un nom, un e-mail ou un numéro de participant) saisi par un contributeur, afin que le responsable sache qui se trouve derrière chaque code sans qu'aucun nom ne devienne jamais un nom de dossier. Le même identifiant est écrit dans l'enregistrement JSON de chaque session envoyée.

## Pour les responsables de projet

### Option A : un File Drop Nextcloud

1. Dans Nextcloud, créez un dossier pour le projet, par exemple `Relevé printemps 2027`.
2. Ouvrez son panneau de partage, créez un **lien de partage** et réglez ses autorisations sur **Dépôt de fichiers (envoi uniquement)**. Les contributeurs peuvent alors ajouter des fichiers, mais ne voient jamais ce que les autres ont envoyé.
3. Définissez un **mot de passe** sur le lien. Sans mot de passe, toute personne qui trouve le lien peut envoyer des fichiers dans le dossier. Même dans ce cas, un File Drop ne peut pas être lu ; l'absence de mot de passe est donc un choix que l'application accepte sans protester.
4. Définissez éventuellement une date d'expiration correspondant à la fin du projet.
5. Copiez le lien de partage. Il ressemble à `https://cloud.example.org/s/AbCdEf123456`.

L'application convertit elle-même ce lien en point d'accès WebDAV du partage ; les contributeurs ne voient jamais d'adresse WebDAV. Un File Drop n'écrase jamais rien : lorsqu'un contributeur renvoie la même session, Nextcloud conserve l'ancienne copie sous un nom numéroté, de sorte que le fichier le plus récent est celui sans numéro.

Les partages Nextcloud avec autorisation **d'envoi et de modification** fonctionnent aussi, mais l'application avertira les contributeurs que l'identifiant peut lister le dossier, car toute personne disposant du lien peut alors lire les données de tous les autres. Les partages en lecture seule sont refusés par le test de connexion.

### Option B : votre propre dossier WebDAV

Tout serveur WebDAV convient : un dossier d'un compte cloud personnel, un serveur de fichiers institutionnel, ownCloud ou Nextcloud avec un compte ordinaire. Les contributeurs saisissent l'adresse ainsi qu'un nom d'utilisateur et un mot de passe sous **Avancé** au moment de rejoindre. Pour un compte Nextcloud ou ownCloud, utilisez un **mot de passe d'application** issu des réglages de sécurité du compte, jamais le mot de passe de connexion ; lorsque seul un nom d'hôte est fourni, l'application essaie aussi les emplacements habituels de Nextcloud et d'ownCloud sur cet hôte.

Un tel identifiant peut généralement lire le dossier ; le test de connexion affiche donc un avertissement. Préférez une configuration en écriture seule lorsque les contributeurs ne font pas tous partie d'une même équipe.

### Option C : le serveur de dépôt de référence

`tools/webdav_drop_server`, dans le dépôt des sources, est un petit serveur Python avec des jetons par contributeur que vous pouvez révoquer, une commande `collect` qui fusionne chaque enregistrement JSON envoyé dans `sessions.csv`, `detections.csv` et `species_summary.csv`, et une commande `invite` qui imprime un lien d'accès et un code QR. L'installation et le déploiement sont décrits dans le [Guide du développeur](../developer/upload-drop-server.md).

### Créer le lien d'accès et le code QR

Un lien d'accès réunit en un seul élément tout ce dont un contributeur a besoin : la destination, l'identifiant, un nom de projet et les valeurs par défaut que vous suggérez. Ouvrez la [page d'accès](../join.md) de ce site et renseignez :

- **Share link or WebDAV address** : le lien de partage Nextcloud ci-dessus, ou l'adresse du dossier WebDAV.
- **User name** : laissez vide pour un lien de partage Nextcloud.
- **Share password or token** : le mot de passe du partage, ou le secret du compte ou du jeton.
- **Project name shown in the app** : ce que les contributeurs verront comme nom de la destination. Ils peuvent le renommer, mais c'est la valeur par défaut.
- **Suggest including audio** et **Suggest Wi-Fi only** : les valeurs par défaut des interrupteurs de la destination.

Appuyez sur **Build link and QR code**. Tout se passe dans votre navigateur ; rien n'est envoyé nulle part. Le secret se trouve dans la partie du lien après `#`, que les navigateurs ne transmettent jamais au serveur web qui héberge la page.

Vous pouvez aussi rejoindre d'abord la destination sur votre propre téléphone (voir plus bas), puis ouvrir la destination sous **Paramètres → Export et synchronisation → Destinations d'envoi** et toucher **Afficher le code d'accès**. L'application affiche le même type de code QR avec un bouton **Copier le lien**.

### Le distribuer

Imprimez le code QR sur la fiche de terrain, affichez-le sur un écran lors du briefing ou envoyez le lien par message. **Traitez le lien et le code comme un mot de passe** : toute personne qui le détient peut envoyer des fichiers dans votre projet. S'il fuit, changez le mot de passe du partage ou révoquez le jeton, puis distribuez un nouveau code.

Lorsqu'un contributeur scanne le code avec l'appareil photo de son téléphone, le navigateur ouvre une petite page d'accueil avec un bouton **Open in BirdNET Live**, qui mène à l'écran Ajouter une destination de l'application avec le lien déjà renseigné. Coller le lien directement dans cet écran fonctionne exactement de la même manière.

### Ce que vous verrez

Un dossier par appareil, un ZIP par session et les enregistrements cachés `.birdnet-live`. Ouvrez un ZIP pour y trouver l'enregistrement JSON (toujours présent) ainsi que les tables, le rapport et l'audio que le contributeur a choisi d'inclure. Pour savoir quelle personne se trouve derrière un identifiant d'envoi, lisez le fichier d'enregistrement de ce code ou le champ `meta.participant` dans n'importe lequel de ses enregistrements JSON. Avec le serveur de dépôt de référence, `collect` s'en charge pour vous et écrit une colonne `participant`.

## Pour les contributeurs

### Rejoindre une destination

1. Ouvrez **Paramètres → Export et synchronisation → Destinations d'envoi** et touchez **Ajouter une destination**. Scanner le code QR d'un projet avec votre appareil photo, ou toucher un lien d'accès que vous avez reçu, vous amène au même écran avec le lien déjà renseigné.
2. Collez le lien d'accès, le lien de partage Nextcloud ou une adresse WebDAV dans **Lien d'accès ou adresse du serveur**. Le bouton **Coller** le récupère depuis le presse-papiers.
3. Saisissez éventuellement un **Identifiant de participant, nom ou e-mail (facultatif)**. Il est enregistré avec chaque envoi pour que le responsable de projet sache qui l'a envoyé, et il n'apparaît jamais dans les noms de dossier. Sous le champ, l'application affiche **Votre identifiant d'envoi**, le dossier dans lequel vos envois seront déposés.
4. Pour une simple adresse WebDAV, ouvrez **Avancé** et saisissez le **Nom d'utilisateur** et le **Mot de passe ou jeton**. Un lien de partage Nextcloud n'a besoin ni de l'un ni de l'autre ; si le partage a un mot de passe, saisissez-le comme mot de passe.
5. Touchez **Tester la connexion**. L'application contacte le serveur, crée le dossier d'enregistrement caché, vérifie si l'identifiant peut lister le dossier et écrit votre fichier d'enregistrement. Le résultat tient en une phrase : **La connexion fonctionne**, un avertissement que vous devriez lire, ou un échec avec la solution probable.
6. Donnez à la destination un **Nom de la destination** (prérempli depuis le lien d'accès), décidez s'il faut **Envoyer uniquement en Wi-Fi**, puis touchez **Enregistrer la destination**.

Rien n'est enregistré tant que le test n'a pas réussi. L'identifiant est placé dans le trousseau de l'appareil, jamais dans les données exportées.

Avertissements qu'il vaut la peine de comprendre :

- **Cet identifiant peut lister la destination** signifie que le partage ou le compte peut lire les données des autres contributeurs. Les envois fonctionnent, mais demandez au responsable un File Drop ou un jeton en écriture seule si le projet implique des personnes extérieures à votre équipe.
- **Ce partage n'a pas de mot de passe et peut être listé** cumule les deux risques : toute personne disposant du lien peut tout lire. Demandez au responsable de définir un mot de passe ou d'utiliser un File Drop.
- **Ce serveur n'autorise pas les dossiers** est purement informatif : les envois utilisent des noms de fichiers à plat tels que `4ee91c8f__BirdNET_Live_….zip` au lieu d'un dossier.

### L'écran de la destination

Toucher une destination dans la liste ouvre son écran avec l'adresse du serveur, la date d'ajout et de dernière utilisation, et ces commandes :

- **Renommer** (le crayon dans la barre d'application) modifie le nom affiché dans l'application.
- **Envoyer uniquement en Wi-Fi** retient les envois tant que le téléphone est sur le réseau cellulaire.
- **Envoyer toutes les Sessions automatiquement** met en file chaque Session terminée, quel que soit le mode, pour cette destination sans rien demander, en utilisant les valeurs par défaut d'Export et synchronisation pour l'audio et les métadonnées. Tant que cette option est active, **Envoyer les Sessions ARU automatiquement** reste également active. Si vous supprimez ensuite une Session dans Session Review, un envoi qui n'a pas commencé est annulé, mais ce qui a déjà été envoyé reste sur le serveur.
- **Envoyer les Sessions ARU automatiquement** met en file chaque ARU Session terminée pour cette destination sans rien demander (voir plus bas).
- **Tester la connexion** répète le test de connexion, par exemple après que le responsable a changé le mot de passe.
- **Afficher le code d'accès** affiche un code QR ainsi que **Copier le lien** pour qu'un second téléphone rejoigne la même destination.
- **Retirer la destination** oublie la destination et son identifiant et abandonne les envois en attente vers celle-ci. Les sessions déjà envoyées restent sur le serveur.

La première entrée de la liste des destinations est **Votre identifiant d'envoi**, avec l'identifiant de participant en dessous ; touchez-la pour modifier l'identifiant. Le modifier ne déplace rien sur le serveur, puisque les dossiers portent le nom de l'ID.

### Envoyer une session

Les envois démarrent depuis la même action **Partager** que vous utilisez déjà, à trois endroits :

- le **menu à trois points** (:app-moreVert:) d'une carte de session dans la Bibliothèque de sessions ;
- le bouton **Partager** après avoir sélectionné plusieurs sessions dans la Bibliothèque de sessions ;
- l'icône **Partager** (:app-share:) dans la barre d'outils du Résumé de la session.

La boîte de dialogue Partager comporte deux onglets dès qu'au moins une destination existe :

- **Contenu** choisit ce que contient l'export : **Audio** (l'enregistrement complet, ou les extraits de détection lorsque seuls les extraits ont été conservés) et **Métadonnées** (les tables, le rapport et le fichier de métadonnées de l'application activés sous Export et synchronisation). Les cases reprennent au départ vos réglages et ne s'appliquent qu'à ce partage.
- **Envoyer vers** liste **Feuille de partage** (autres applications, fichiers, messages) et une case par destination. Le badge de l'onglet compte les destinations cochées. Les destinations cochées la dernière fois sont précochées, sauf celles vers lesquelles cette session est déjà partie : elles démarrent décochées et affichent **Envoyé le** suivi de la date et **Cochez pour renvoyer**. À l'ouverture de la boîte de dialogue, l'application vérifie discrètement chaque destination ; si le serveur indique qu'il refuserait l'envoi, par exemple parce que le mot de passe a changé ou que le partage a été supprimé, la ligne passe en rouge avec la raison.

Décochez **Feuille de partage** et le bouton indique **Envoyer** ; avec les deux cochés, il indique **Partager et envoyer**. Une notification confirme combien de sessions ont été mises en file. Une session passe toujours d'abord par la file d'attente et est envoyée en arrière-plan, vous pouvez donc continuer à travailler.

### Suivre un envoi

La carte de session dans la Bibliothèque de sessions affiche l'état en première ligne sous le titre de la session : **En attente**, **En attente du Wi-Fi**, **En attente d'un réseau**, **Envoi en cours…**, **Envoyé le** suivi de la date, ou un échec. Touchez la ligne pour afficher la liste par destination avec **Réessayer maintenant** et **Retirer de la file**. Le Résumé de la session affiche le même état sous forme d'icône nuage dans la barre d'application ; la toucher ouvre la même liste.

Les envois échoués se relancent d'eux-mêmes avec des délais croissants, jusqu'à six heures d'intervalle, pour un maximum de trente tentatives. **Échec, nouvel essai prévu** signifie que l'application réessaiera. **L'envoi a échoué. Vérifiez les réglages de la destination.** signifie que le serveur a refusé et qu'une nouvelle tentative ne peut rien y changer : le mot de passe a changé, les envois ont été désactivés ou la destination a été retirée. Ouvrez la destination, lancez **Tester la connexion**, puis retirez-la et ajoutez-la de nouveau si l'identifiant a changé.

La ligne et l'icône n'apparaissent que tant qu'au moins une destination vers laquelle la session a été envoyée existe encore dans les Paramètres. Retirez la destination et elles disparaissent, car « envoyé » n'est plus un fait concernant une destination que vous possédez.

### Ce qui s'exécute en arrière-plan

Les envois en file s'exécutent tant que l'application est ouverte et chaque fois qu'elle revient au premier plan. Sur Android, ils s'exécutent aussi lorsque l'application est fermée : le système les démarre dès qu'un réseau adapté est disponible, le Wi-Fi lorsque la destination l'exige, et continue de réessayer jusqu'à ce que la file soit vide. Sur iOS, les envois s'exécutent tant que l'application est ouverte.

### Renvoyer une session

Renvoyer la même session, par exemple après avoir corrigé des détections dans le Résumé de la session, écrit le même nom de fichier dans le même dossier. Les serveurs qui le permettent remplacent le fichier ; un File Drop Nextcloud conserve au lieu de cela l'ancienne copie sous un nom numéroté. Dans les deux cas, le responsable de projet obtient la version la plus récente, et rien n'est supprimé.

## Mode ARU

Les déploiements sur le terrain produisent de nombreuses sessions, souvent alors que personne n'est près du téléphone. Activez **Envoyer les Sessions ARU automatiquement** sur une destination, et chaque ARU Session terminée est mise en file pour celle-ci sans boîte de dialogue, en utilisant les valeurs par défaut d'Export et synchronisation pour Audio et Métadonnées. Un déploiement qui enregistre chaque cycle comme une session distincte envoie cycle par cycle ; la session combinée du déploiement n'est pas envoyée deux fois.

Laissez **Envoyer uniquement en Wi-Fi** activé pour une station sur un forfait cellulaire, sauf si le forfait peut absorber l'audio, et envisagez d'enregistrer en **Détections uniquement** ou **Désactivé** lorsque l'audio serait trop volumineux à envoyer. Les envois partent alors dès que le téléphone voit un réseau adapté, y compris lorsque l'application est en arrière-plan sur Android.

## Deux exemples concrets

### Un relevé de week-end avec un File Drop Nextcloud

Le responsable crée un dossier `Birdathon 2027` dans le Nextcloud de l'université, le partage en File Drop avec un mot de passe, colle le lien de partage et le mot de passe dans la page d'accès, nomme le projet et imprime le code QR sur la fiche de briefing. Vingt bénévoles le scannent le samedi matin, saisissent leur nom comme identifiant de participant, réussissent le test de connexion et enregistrent.

Le dimanche soir, chaque bénévole ouvre la Bibliothèque de sessions, sélectionne les sessions du week-end, touche Partager, laisse le projet coché sous Envoyer vers et touche **Envoyer**. Les envois attendent le Wi-Fi de la maison et se terminent pendant la nuit. Le lundi, le responsable trouve vingt dossiers nommés par identifiant d'envoi, chacun avec une poignée de ZIP, et lit les noms des bénévoles dans les fichiers d'enregistrement cachés ou dans le champ `meta.participant` des enregistrements JSON.

### Des corrections dans le Résumé de la session, puis une station ARU

Un contributeur révise une session, retire deux fausses détections, ajoute une espèce à la main et enregistre. L'icône nuage dans la barre d'application du Résumé de la session indique que la session a été envoyée samedi. Il touche l'icône Partager dans la barre d'outils, coche le projet sous Envoyer vers, où il démarre décoché et indique **Envoyé le** suivi de la date, puis appuie sur **Envoyer**. Le ZIP corrigé remplace le précédent, ou se dépose à côté de lui sous un nom numéroté sur un File Drop.

Le même contributeur laisse un téléphone comme station ARU dans une roselière, avec un point d'accès Wi-Fi dans la cabane. Il rejoint la destination du projet sur ce téléphone, active **Envoyer les Sessions ARU automatiquement** et garde **Envoyer uniquement en Wi-Fi** activé. Chaque matin, les cycles nocturnes terminés sont mis en file et envoyés pendant que la station est au repos ; le responsable voit de nouveaux ZIP apparaître sous l'identifiant d'envoi de ce téléphone sans que personne n'y touche.

## Confidentialité et responsabilité

Les destinations d'envoi sont exploitées par les organisateurs de projet, et non par BirdNET-Team. Le dossier, le serveur, qui peut le lire et combien de temps les données sont conservées relèvent des propres règles de confidentialité et de sécurité de l'organisateur ; demandez-lui des précisions avant de rejoindre. BirdNET Live n'écrit que ce que vous avez choisi d'envoyer et conserve l'identifiant dans le trousseau de votre appareil.

Un envoi contient ce que contiendrait un Partager : l'enregistrement JSON de la session avec les détections, les heures, les coordonnées, le nom de l'observateur et le nom du lieu s'ils sont définis, l'identifiant d'envoi de l'appareil, l'identifiant de participant que vous avez saisi et la version de l'application ; plus l'audio, les tables et le rapport que vous avez cochés. Vérifiez l'onglet Contenu avant d'envoyer, et excluez l'audio lorsqu'un enregistrement peut contenir des voix ou toute autre chose que vous ne remettriez pas au projet. **Vous êtes responsable de ce que vous envoyez.** N'envoyez ni ne partagez des données que vous considérez comme privées ou confidentielles, et n'envoyez pas d'enregistrements que vous n'êtes pas autorisé à transmettre.

## Dépannage

| Message | Signification | Que faire |
| --- | --- | --- |
| Ceci ne ressemble pas à un lien ni à une adresse de serveur. | Le texte n'est pas une URL. | Collez le lien d'accès, le lien de partage ou l'adresse `https://` en entier. |
| Le serveur a refusé les identifiants. | Mot de passe erroné ou manquant, ou partage supprimé. Nextcloud répond aussi de cette manière pour les partages supprimés. | Utilisez le mot de passe du partage ou un mot de passe d'application ; demandez au responsable si le partage existe encore. |
| Cette adresse n'est pas un point d'accès WebDAV. | Vous avez collé la page web d'un dossier, et non un lien de partage ou une adresse WebDAV. | Collez le lien de partage (`…/s/…`) ou l'adresse WebDAV. |
| Les envois ne sont pas autorisés ici. | Le partage est en lecture seule. | Demandez au responsable un File Drop ou l'autorisation d'envoi. |
| Le dossier n'existe pas sur le serveur. | L'adresse ne pointe sur rien, ou le dossier a été supprimé. | Vérifiez l'adresse avec le responsable. |
| Le certificat du serveur n'a pas pu être vérifié. | TLS autosigné ou défectueux. | Demandez au responsable une adresse avec un certificat valide. |
| Cette adresse utilise HTTP non chiffré. | Connexion non chiffrée en dehors de votre réseau local. | Utilisez une adresse `https://`. |
| En attente du Wi-Fi | La destination est réglée sur Wi-Fi uniquement et le téléphone est sur le réseau cellulaire. | Attendez, ou désactivez l'interrupteur Wi-Fi uniquement de la destination. |
| Échec, nouvel essai prévu | Un problème temporaire, comme une connexion interrompue ou une erreur du serveur. | Rien ; l'application réessaie d'elle-même. **Réessayer maintenant** force une tentative. |
| L'envoi a échoué. Vérifiez les réglages de la destination. | Le serveur a refusé pour une raison qu'une nouvelle tentative ne peut pas corriger. | Ouvrez la destination, lancez **Tester la connexion**, puis retirez-la et ajoutez-la de nouveau si l'identifiant a changé. |
| L'identifiant de cette destination est absent du trousseau de l'appareil. | L'entrée du trousseau a été perdue, par exemple après une restauration sur un nouveau téléphone. | Retirez la destination et ajoutez-la de nouveau. |

Voir aussi le réglage [Destinations d'envoi](settings.md#destinations-denvoi) ainsi que les guides [Bibliothèque de sessions](session-library.md) et [Résumé de la session](session-review.md).
