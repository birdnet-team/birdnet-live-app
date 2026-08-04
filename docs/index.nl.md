# BirdNET Live

**Professionele bioakoestiek in je broekzak.**

BirdNET Live is een Flutter-app voor veldonderzoekers, natuurbeschermers en vogelaars die betrouwbaar akoestisch bewijs in het veld nodig hebben. De app draait de BirdNET+ audioclassifier en het geomodel rechtstreeks op je toestel, zodat soortherkenning na installatie volledig offline werkt.

<p align="center">
  <img src="https://img.shields.io/badge/latest-v1.0.5-orange.svg" alt="Latest release: v1.0.5">
  <img src="https://img.shields.io/badge/species-9%2C789-brightgreen.svg" alt="Species: 9,789">
  <img src="https://img.shields.io/badge/platforms-Android%20%7C%20iOS%20%7C%20Windows-green.svg" alt="Platforms">
</p>

## Functies

- **Live-modus** - Realtime meelopend spectrogram met soortherkenning
- **Point Count-modus** - Sessions op tijd met aftelklok en metadata van het telpunt
- **Survey-modus** - Langlopende transecttellingen met GPS-tracking, monitoring op de achtergrond en steekproeven van detecties
- **Bestandsanalyse** - Offline analyse van bestaande opnamen (WAV, FLAC, MP3, OGG en meer)
- **ARU-modus** - Maak van je toestel een akoestische opnameunit voor inzetten van meerdere dagen
- **Verkennen** - Blader door de soorten die op jouw locatie te verwachten zijn met het BirdNET-geomodel
- **Session-bibliotheek** - Bekijk, bewerk en exporteer eerdere Sessions met audioweergave
- **Export** - Raven Pro, CSV, JSON, GPX en ZIP-bundels met herkomstmetadata
- **Inferentie op het toestel** - Het BirdNET+-model dekt 9.789 soorten, zonder internet
- **FLAC-opname** - Gecomprimeerde audio met kleinere bestanden voor lange tellingen
- **Toegankelijkheid** - Labels voor schermlezers, tooltips en optionele gesproken meldingen van detecties
- **Responsieve indelingen** - Interfaces die zich aanpassen aan telefoon, tablet, staand en liggend
- **Lokalisatie** - Interface en gesproken meldingen in 11 talen

<p align="center">
  <img src="../assets/screenshots/live-mode.png" alt="Live Mode" width="150">
  <img src="../assets/screenshots/session-review.png" alt="Session Review" width="150">
  <img src="../assets/screenshots/explore.png" alt="Explore" width="150">
  <img src="../assets/screenshots/species.png" alt="Species Overlay" width="150">
  <img src="../assets/screenshots/file-analysis.png" alt="File Analysis" width="150">
</p>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=de.tu_chemnitz.mi.kahst.birdnet_live"><b>Google Play</b></a>
  &nbsp;·&nbsp;
  <a href="https://apps.apple.com/us/app/birdnet-live/id6776168518"><b>App Store</b></a>
  &nbsp;·&nbsp;
  <a href="https://github.com/birdnet-team/birdnet-live-app/releases/latest"><b>Download APK</b></a>
  &nbsp;·&nbsp;
  <a href="https://github.com/birdnet-team/birdnet-live-app"><b>GitHub</b></a>
  &nbsp;·&nbsp;
  <a href="https://github.com/birdnet-team/birdnet-live-app/releases"><b>All Releases</b></a>
</p>

## Snel starten

Lees de [Gebruikershandleiding](user/index.md) voor een overzicht en open daarna [Aan de slag](user/getting-started.md) om BirdNET Live te installeren en te gebruiken.

## Installeren

BirdNET Live is beschikbaar in de [Google Play Store](https://play.google.com/store/apps/details?id=de.tu_chemnitz.mi.kahst.birdnet_live) en in de [App Store](https://apps.apple.com/us/app/birdnet-live/id6776168518).

Op Android kun je de app ook handmatig installeren als ondertekende APK: download de nieuwste release van de [GitHub-releasespagina](https://github.com/birdnet-team/birdnet-live-app/releases/latest), zet het `.apk`-bestand op je telefoon en open het om te installeren. Mogelijk moet je eerst installatie uit onbekende bronnen toestaan in de instellingen van je toestel.

> **Let op:** de APK is ongeveer 260 MB omdat het de BirdNET+-modelbestanden en alle soortafbeeldingen voor offline gebruik bevat.

## Voor ontwikkelaars

Bekijk de [Developer Guide](developer/index.md) voor architectuur, bouwen en bijdragen. De ontwikkelaarsdocumentatie is alleen in het Engels beschikbaar.

## Licentie

De broncode van BirdNET Live is open source onder de [MIT-licentie](https://github.com/birdnet-team/birdnet-live-app/blob/main/LICENSE). De meegeleverde BirdNET-modelgewichten vallen onder de [Apache-licentie 2.0](https://github.com/birdnet-team/birdnet-live-app/blob/main/MODEL_LICENSE).
