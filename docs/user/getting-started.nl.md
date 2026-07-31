# Aan de slag

## Installatie

BirdNET Live is beschikbaar voor Android, iOS en Windows.

### Vereisten

- **Android**: 8.0 (API 26) of nieuwer
- **iOS**: 15.0 of nieuwer
- **Windows**: 10 of nieuwer (experimenteel)
- ~300 MB opslag voor app + modellen

### Downloaden

- **Android** — [Google Play Store](https://play.google.com/store/apps/details?id=de.tu_chemnitz.mi.kahst.birdnet_live), of installeer de ondertekende APK handmatig via de [GitHub-releasespagina](https://github.com/birdnet-team/birdnet-live-app/releases/latest).
- **iOS** — [App Store](https://apps.apple.com/us/app/birdnet-live/id6776168518).
- **Windows** — zelf bouwen vanaf de broncode; zie de [Developer Guide](../developer/building.md).

## Verloop bij het eerste gebruik

Wanneer je BirdNET Live voor het eerst opent, loopt de app met je door een korte introductie en het instellen van machtigingen.

1. Lees de introductieschermen.
2. Neem het Beleid voor aanvaardbaar gebruik en het Privacybeleid door.
3. Geef toestemming voor de microfoon zodat BirdNET Live audio kan verwerken.
4. Geef eventueel toestemming voor locatie voor geotagging, Verkennen, Point Count en Survey.
5. Sta eventueel meldingen toe voor langlopende Surveys.

## Eerste start

1. **Introductie** — Korte kennismaking met de functies en machtigingen
2. **Aanvaardbaar gebruik en privacy** — Neem het Beleid voor aanvaardbaar gebruik en het Privacybeleid door
3. **Machtigingen** — Geef toegang tot de microfoon (vereist voor alle modi)
4. **Klaar** — Begin met het herkennen van vogels!

## Overzicht van het startscherm

Het startscherm is het centrale punt.

### Kaarten voor de hoofdmodi

- :material-microphone: **Live-modus**
- :material-map-marker: **Point Count-modus**
- :material-routes: **Survey-modus**
- :material-file-music: **Bestandsanalyse**

### Knoppen onderaan

- :material-tune: **Instellingen**
- :material-magnify: **Verkennen**
- :material-music-box-multiple-outline: **Session-bibliotheek**
- :material-help-circle-outline: **Help**
- :material-information-outline: **Over**

## Wat wordt er opgeslagen

BirdNET Live slaat elke afgeronde Session automatisch op en opent die in het Session-overzicht zodra de verwerking stopt.

- Live-Sessions bewaren detecties en, afhankelijk van je instellingen, opnamen of fragmenten.
- Point Count-Sessions worden opgeslagen als punttellingen op tijd.
- Survey-Sessions bewaren de route, de detecties en bijbehorende metadata.
- Resultaten van bestandsanalyse worden omgezet in een Session die je kunt nakijken.

## Aanbevolen vervolgpagina's

- Lees [Pictogrammen en bediening](icons-and-controls.md) als je een korte uitleg wilt van de terugkerende symbolen in de interface.
- Lees [Instellingen](settings.md) voordat je drempels, filters, opnamegedrag of de spectrogramweergave wijzigt.
- Open de handleiding voor de workflow die je het vaakst gebruikt: [Live-modus](live-mode.md), [Point Count-modus](point-count-mode.md), [Survey-modus](survey-mode.md) of [Bestandsanalyse](file-analysis.md).

## Machtigingen

| Machtiging | Nodig voor | Optioneel? |
|------------|-------------|-----------|
| Microfoon | Alle opnamemodi | Vereist |
| Locatie | GPS-tagging, Survey/Point Count | Optioneel voor Live |
| Opslag | Opnamen en exports bewaren | Vereist voor opnemen |
| Meldingen | Waarschuwingen bij Survey op de achtergrond | Optioneel |
