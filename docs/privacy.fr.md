# Politique de Confidentialité de BirdNET Live

**Dernière mise à jour :** 6 août 2026

La présente Politique de Confidentialité s'applique à **BirdNET Live** (l'**application**). L'application est développée et proposée par **BirdNET-Team** (le **développeur**, **nous** ou **notre**).

## Identité de l'application et du développeur

| | |
|---|---|
| **Nom de l'application** | BirdNET Live |
| **Nom du développeur** | BirdNET-Team |
| **Contact confidentialité** | [ccb-birdnet@cornell.edu](mailto:ccb-birdnet@cornell.edu) |

BirdNET-Team fournit cette politique en son propre nom. Elle explique comment BirdNET Live protège et traite les informations personnelles.

## Traitement sur l'Appareil

Toute l'analyse audio et l'identification des espèces d'oiseaux s'effectuent **intégralement sur votre appareil**. L'application utilise deux modèles de réseaux de neurones exécutés localement :

- **Classificateur audio BirdNET+** — analyse l'audio du microphone pour identifier les espèces d'oiseaux.
- **Géo-modèle BirdNET** — prédit quelles espèces sont probables à votre position et à cette période de l'année.

Aucune donnée audio n'est jamais transmise à des serveurs externes.

## Traitement des informations personnelles

BirdNET-Team n'exploite aucun serveur applicatif et ne reçoit par BirdNET Live ni vos enregistrements, ni votre position, ni vos données de Session, ni aucune autre information personnelle. L'application ne comporte aucun compte utilisateur, publicité, outil d'analyse, suivi ou télémétrie. Elle traite toutefois l'audio et la position sur votre appareil et, uniquement lorsque vous activez une fonction réseau facultative, envoie directement les informations décrites sous **Ressources Externes** au fournisseur tiers indiqué.

### Données stockées localement sur votre appareil :

| Type de donnée | Objectif | Stockage |
|----------------|----------|----------|
| Enregistrements audio | Identification des oiseaux, lecture, export | Fichiers locaux |
| Résultats de détection | Espèces, confiance, horodatages | Fichiers JSON de session locaux |
| Coordonnées GPS | Géomarquage des détections, traces de Relevé, prédictions du géo-modèle | Fichiers JSON de session locaux |
| Métadonnées de session | Historique des sessions, révision, export | Fichiers JSON de session locaux |
| Instantané météo (optionnel) | Capture ponctuelle de température, précipitations, vent, nébulosité et code météo par session quand **Autoriser la requête météo** est activé | Fichiers JSON de session locaux |
| Réglages de l'app | Préférences utilisateur | SharedPreferences |

### Données hors-ligne intégrées

Les images, descriptions et données taxonomiques des espèces sont **intégrées à l'application** et chargées depuis des ressources locales. Aucune requête réseau n'est effectuée pour les informations sur les espèces.

## Ressources Externes

L'application peut accéder aux ressources externes ci-dessous. Chacune est contrôlée par un interrupteur indépendant sous **Paramètres → Confidentialité**, et **les trois sont désactivés par défaut** sur une nouvelle installation. Rien ne quitte votre appareil avant que vous l'autorisiez.

| Ressource | Objectif | Contrôlé par | Envoyé à chaque requête |
|-----------|----------|--------------|--------------------------|
| Tuiles de carte (OpenStreetMap Foundation) | Carte de base pour le sélecteur de position, la carte en direct du Survey et la carte de la Session | **Paramètres → Confidentialité → Autoriser les tuiles de carte** | Coordonnées de tuile `(z, x, y)`, votre adresse IP dans le cadre de la connexion réseau et le user-agent BirdNET Live |
| Géocodage inverse (Nominatim d'OpenStreetMap Foundation) | Résoudre les coordonnées GPS en un nom de lieu lisible (p. ex. « Paris, France ») pour l'affichage de la Session | **Paramètres → Confidentialité → Autoriser la recherche de nom de lieu** | Latitude/longitude de la Session, votre adresse IP dans le cadre de la connexion réseau et le user-agent BirdNET Live |
| Instantané météo (OpenMeteo GmbH) | Capture ponctuelle des conditions locales (température, précipitations, vent, nébulosité, code WMO) aux coordonnées d'enregistrement et à l'heure de fin | **Paramètres → Confidentialité → Autoriser la requête météo** | Latitude/longitude et heure de fin de la Session, votre adresse IP dans le cadre de la connexion réseau et le user-agent BirdNET Live |

Les requêtes de tuiles de carte sont des requêtes HTTPS GET vers `tile.openstreetmap.org`. Les coordonnées identifient la zone de carte affichée. Comme toute requête Internet directe, elles exposent également votre adresse IP au fournisseur.

Les requêtes de géocodage inverse envoient la latitude et la longitude de la session à `nominatim.openstreetmap.org` par HTTPS, avec le user-agent BirdNET Live comme l'exige la [Politique d'usage Nominatim](https://operations.osmfoundation.org/policies/nominatim/). Le nom de lieu résolu est stocké localement avec la session, de sorte qu'une session n'est géocodée qu'une seule fois. Aucune requête n'est effectuée si la session n'a pas de coordonnées GPS ou si l'appareil est hors ligne.

Les requêtes météo envoient la latitude/longitude de la session et l'horodatage de fin à `api.open-meteo.com` par HTTPS, avec le user-agent BirdNET Live. [Open-Meteo](https://open-meteo.com/) est un service gratuit qui n'exige ni compte ni clé API. L'instantané météo renvoyé est stocké localement avec la session et également écrit dans l'export JSON, dans le bloc `metadata.json` de la session et dans le rapport HTML.

**Traitement et conservation par des tiers :** BirdNET-Team n'exploite pas ces services et ne reçoit pas les données de leurs requêtes. OpenStreetMap Foundation peut traiter les données d'accès réseau et les détails des requêtes conformément à sa [Politique de Confidentialité](https://osmfoundation.org/wiki/Privacy_Policy). Open-Meteo indique que les journaux de son API gratuite peuvent contenir des adresses IP et des coordonnées géographiques et sont supprimés après 90 jours ; consultez ses [Conditions et règles de confidentialité](https://open-meteo.com/en/terms). Ces fournisseurs peuvent traiter les données dans d'autres pays. Les valeurs renvoyées sont stockées localement dans la Session et n'entrent dans un export que lorsque vous le créez.

**Révocation :** vous pouvez désactiver l'un des trois services à tout moment sous **Paramètres → Confidentialité**. Les noms de lieu et instantanés météo déjà stockés localement restent attachés aux sessions où ils ont été capturés ; supprimez ces sessions depuis Session Library ou utilisez **Paramètres → Zone dangereuse → Effacer toutes les données** pour retirer ces données historiques.

**Aucune autre requête réseau n'est effectuée.** L'application fonctionne entièrement hors ligne.

## Liens externes

BirdNET Live comporte des liens vers des sites tiers que vous pouvez choisir d'ouvrir — par exemple les pages **eBird**, **iNaturalist** et **Wikipédia** d'une espèce et le lien audio *«Écouter cette espèce sur eBird»* dans la vue d'espèce, ainsi que des liens vers le site du projet BirdNET, le code source, le guide d'utilisation et la page de don depuis l'écran **À propos**. Les liens qui quittent l'application sont marqués d'une icône de lien externe (↗) afin que vous les reconnaissiez avant de les toucher.

Tant qu'un lien est seulement affiché, rien n'est envoyé, et aucun lien externe ne s'ouvre automatiquement : un navigateur ne s'ouvre que lorsque vous le touchez. Le lien s'ouvre alors dans le navigateur par défaut de votre appareil et vous quittez BirdNET Live. La destination est exploitée par un tiers et régie par **sa propre** politique de confidentialité et ses conditions, non par la présente. Ces sites peuvent collecter de manière indépendante des informations sur votre visite — par exemple votre adresse IP, des détails sur votre appareil ou navigateur et votre façon d'interagir avec leurs pages — et déposer leurs propres cookies. Nous ne contrôlons pas et n'assumons aucune responsabilité quant au contenu ou aux pratiques de données des sites externes ; nous vous invitons à consulter la politique de confidentialité de chaque site.

## GPS et Localisation

L'application utilise la localisation GPS pour :

- **Filtrage des espèces** — prédire quelles espèces sont probables à votre position.
- **Mode Relevé** — enregistrer des traces GPS et géomarquer les détections le long d'un transect.
- **Mode Point d'écoute** — marquer le lieu de l'observation.

Les données GPS sont stockées localement et incluses dans les exports uniquement lorsque vous partagez ou exportez explicitement une session. L'accès à la localisation nécessite votre autorisation et peut être révoqué à tout moment via les réglages du système.

## Export de Données

Vous pouvez exporter les données de session dans plusieurs formats (Raven Selection Tables, CSV, JSON, GPX) et cocher n'importe quelle combinaison de formats à la fois sous **Paramètres → Exporter → Formats** ; les formats sélectionnés sont regroupés dans un ZIP unique avec les clips audio et le rapport HTML autonome optionnel. Les exports sont générés localement et partagés via la feuille de partage du système. L'application ne téléverse aucune donnée d'export sur un serveur.

## Suppression de Données

Les sessions individuelles et leurs enregistrements peuvent être supprimés depuis Session Library. Pour effacer depuis l'application les sessions locales, enregistrements, mémos vocaux, listes d'espèces personnalisées, préférences et caches de BirdNET Live, utilisez **Paramètres → Zone dangereuse → Effacer toutes les données**. Vous pouvez aussi effacer le stockage de l'application BirdNET Live dans les réglages de votre système d'exploitation ou désinstaller l'application.

## Contact

Pour toute question de confidentialité : [ccb-birdnet@cornell.edu](mailto:ccb-birdnet@cornell.edu)
