# Politique de Confidentialité

**Dernière mise à jour :** Mai 2026

BirdNET Live respecte votre vie privée. Ce document explique le traitement de vos données.

## Traitement sur l'Appareil
L'analyse audio et l'identification des espèces aviaires s'effectuent **intégralement sur votre appareil** (Modèles BirdNET+ et Geomodel). Aucune donnée n'est transmise aux serveurs.

## Collecte de Données
L'application **ne** collecte **aucune** donnée personnelle, analyse ou télémétrie.
- Fichiers audio, métadonnées de session JSON, GPS et préférences sont stockés localement.
- Données des espèces sont intégrées hors-ligne.
- Quand **Autoriser la requête météo** est actif, chaque session enregistre localement un instantané de température, précipitations, vent, nuages et code météo aux coordonnées de la session.

## Ressources Externes

L'application peut accéder aux services externes ci-dessous. Chacun est contrôlé par un interrupteur indépendant sous **Réglages → Confidentialité**, et **les trois sont désactivés par défaut** sur une nouvelle installation. Rien ne quitte votre appareil avant que vous l'autorisiez.

| Ressource | Objectif | Interrupteur | Envoyé à chaque requête |
|-----------|----------|--------------|--------------------------|
| Tuiles de carte (OpenStreetMap) | Carte de base pour sélecteur de position, carte live de Survey et carte de la session | **Réglages → Confidentialité → Autoriser les tuiles de carte** | Coordonnées de tuile `(z, x, y)` et user-agent BirdNET Live — pas de PII |
| Géocodage inverse (OpenStreetMap Nominatim) | Résoudre les coordonnées GPS en un nom de lieu (p. ex. «Paris, France») | **Réglages → Confidentialité → Autoriser la recherche de nom de lieu** | Lat/lon de la session et user-agent BirdNET Live |
| Instantané météo (Open-Meteo) | Capture ponctuelle des conditions (température, précipitations, vent, nuages, code WMO) aux coordonnées et à l'heure de fin | **Réglages → Confidentialité → Autoriser la requête météo** | Lat/lon de la session et horodatage de fin, plus user-agent BirdNET Live |

Les requêtes de tuiles sont des HTTPS GET standard vers `tile.openstreetmap.org` ; le géocodage inverse cible `nominatim.openstreetmap.org` selon la [Politique d'usage Nominatim](https://operations.osmfoundation.org/policies/nominatim/) ; les requêtes météo ciblent `api.open-meteo.com`. [Open-Meteo](https://open-meteo.com/) est un service gratuit et n'exige ni compte ni clé API.

**Rétention :** aucun de ces services externes ne stocke vos données. Les valeurs renvoyées (nom de lieu, instantané météo) ne vivent que dans l'enregistrement local de la session et ne voyagent que dans les fichiers d'export que vous produisez explicitement.

**Révocation :** vous pouvez désactiver l'un des trois services à tout moment sous **Réglages → Confidentialité**. Pour effacer aussi les noms de lieu et instantanés météo historiques, supprimez les sessions concernées dans Session Library ou utilisez **Réglages → Zone dangereuse → Effacer toutes les données**.

## Suppression et Exportation
Vous pouvez supprimer des sessions individuelles dans Session Library. Pour effacer depuis l'app les sessions locales, enregistrements, mémos vocaux, listes d'espèces personnalisées, préférences et caches de BirdNET Live, utilisez **Réglages → Zone dangereuse → Effacer toutes les données**. Vous pouvez aussi effacer le stockage de BirdNET Live dans les réglages du système ou désinstaller l'app. Sous **Réglages → Exporter → Formats**, vous pouvez cocher n'importe quelle combinaison de formats (Raven Selection Table, CSV, JSON, GPX) ; ils sont regroupés dans un ZIP unique avec les clips audio et le rapport HTML optionnel.

## Contact
[ccb-birdnet@cornell.edu](mailto:ccb-birdnet@cornell.edu)
