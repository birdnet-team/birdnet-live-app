# BirdNET Live

**Profesionální bioakustika ve vaší kapse.**

BirdNET Live je aplikace ve Flutteru určená terénním výzkumníkům, ochráncům přírody a pozorovatelům ptáků, kteří v terénu potřebují spolehlivé akustické důkazy. Audio klasifikátor BirdNET+ i geomodel běží přímo ve vašem zařízení, takže identifikace druhů funguje po instalaci zcela offline.

<p align="center">
  <img src="https://img.shields.io/badge/latest-v0.19.3-orange.svg" alt="Latest release: v0.19.3">
  <img src="https://img.shields.io/badge/species-9%2C789-brightgreen.svg" alt="Species: 9,789">
  <img src="https://img.shields.io/badge/platforms-Android%20%7C%20iOS%20%7C%20Windows-green.svg" alt="Platforms">
</p>

## Funkce

- **Režim Live** – spektrogram posouvající se v reálném čase s identifikací druhů
- **Režim Point Count** – časované sčítací sessions s odpočtem a metadaty stanoviště
- **Režim Survey** – dlouhé transektové surveye s GPS sledováním, monitoringem na pozadí a vzorkováním detekcí
- **Analýza souborů** – offline analýza existujících nahrávek (WAV, FLAC, MP3, OGG a další)
- **Prozkoumat** – procházení druhů očekávaných ve vaší lokalitě podle geomodelu BirdNET
- **Knihovna Sessions** – kontrola, úprava a export minulých sessions s přehráváním zvuku
- **Export** – formáty Raven Pro, CSV, JSON, GPX a ZIP balíček s metadaty o původu
- **Inference v zařízení** – model BirdNET+ pokrývá 5 250 druhů, bez nutnosti internetu
- **Nahrávání ve FLAC** – komprimovaný záznam s menšími soubory pro dlouhé surveye
- **Přístupnost** – popisky pro čtečky obrazovky, nápovědy a volitelná mluvená oznámení detekcí
- **Responzivní rozvržení** – adaptivní rozhraní pro telefon, tablet, na výšku i na šířku

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
  <a href="https://github.com/birdnet-team/birdnet-live-app/releases/latest"><b>Download APK</b></a>
  &nbsp;·&nbsp;
  <a href="https://github.com/birdnet-team/birdnet-live-app"><b>GitHub</b></a>
  &nbsp;·&nbsp;
  <a href="https://github.com/birdnet-team/birdnet-live-app/releases"><b>All Releases</b></a>
</p>

## Rychlý start

Přehled najdete v [Uživatelské příručce](user/index.md), poté otevřete [Začínáme](user/getting-started.md), kde se dozvíte, jak BirdNET Live nainstalovat a spustit.

## Instalace na Androidu

BirdNET Live je k dispozici jako podepsaný APK pro sideloading. Stáhněte nejnovější vydání ze [stránky GitHub Releases](https://github.com/birdnet-team/birdnet-live-app/releases/latest), přeneste soubor `.apk` do telefonu a otevřete jej k instalaci. Možná bude nejprve nutné v nastavení zařízení povolit instalaci z neznámých zdrojů.

> **Poznámka:** APK má přibližně 253 MB, protože obsahuje prostředky modelu BirdNET+ pro offline inferenci.

## Pro vývojáře

Architekturu, sestavování a přispívání popisuje [Příručka pro vývojáře](developer/index.md).

## Licence

Zdrojový kód BirdNET Live je open source pod [licencí MIT](https://github.com/birdnet-team/birdnet-live-app/blob/main/LICENSE). Přibalené váhy modelů BirdNET jsou licencovány pod [Apache License 2.0](https://github.com/birdnet-team/birdnet-live-app/blob/main/MODEL_LICENSE).
