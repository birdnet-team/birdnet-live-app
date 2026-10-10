# Point Count-modus

De Point Count-modus is de workflow voor tellingen op tijd vanaf een vast punt in BirdNET Live.

## Zo open je de modus

Tik op het startscherm op de kaart **Point Count-modus** met het pictogram :app-locationOnRounded:.

## Opzetproces

Het opzetten van een punttelling verloopt in vier stappen.

### 1. Duur en locatie

Kies:

- een van de beschikbare tijden: 3, 5, 10, 15, 20, 25 of 30 minuten
- of de telling doorgaat met het scherm uit (standaard aan)
- de huidige GPS-positie met :app-myLocation:
- handmatige coördinaten met :app-editLocationAlt:
- geen locatie met :app-locationOff:
- de kaartkiezer met :app-mapSheet:

Het opzetscherm vernieuwt de GPS-positie wanneer je terugkeert uit het
systeemvenster voor machtigingen of uit de app-instellingen, zodat een
zojuist verleende locatiemachtiging de coördinaten bijwerkt zonder de wizard
opnieuw te starten. Dezelfde sectie bevat ook een weerkaart. Staat de toegang
tot weergegevens uit, dan vraagt de kaart om toestemming voor **Weer opzoeken
toestaan**; zodra dat aanstaat, toont die een voorbeeld van de locatie met
alleen een weerpictogram, de temperatuur en de wind. Dezelfde in de cache
opgeslagen momentopname van Open-Meteo wordt hergebruikt wanneer de punttelling
wordt opgeslagen.

### 2. Inferentieparameters

Kies analyse-instellingen voor deze Session, zoals inferentiesnelheid, de betrouwbaarheidsdrempel en de modus van het
soortenfilter. Ze beginnen bij je globale instellingen, maar je kunt ze voor
deze telling aanpassen zonder je standaardwaarden te wijzigen.

| Instelling | Pictogram |
|---|---|
| Microfoon | :app-micRounded: |
| Opnamemodus | :app-fiberManualRecordRounded: |
| Fragmentcontext | :app-timerOutlined: |
| Inferentiesnelheid | :app-speedRounded: |
| Betrouwbaarheidsdrempel | :app-verifiedRounded: |
| Gevoeligheid | :app-hearing: |
| Soortenfilter | :app-filterAltRounded: |

De knop :app-helpOutline: naast elke instelling legt het effect uit. De duurkeuze :app-timerRounded: en de locatiekiezer hebben in de eerste stap dezelfde helpknop.

Kies **Vol** voor doorlopende audio (standaard), **Clips** voor een fragment van elke gedetecteerde roep of zang, of **Uit** om geen audio op te slaan. Deze keuze staat los van de opname-instelling van Live Mode en wordt onthouden voor de volgende Point Count. Fragmenten gebruiken dezelfde selectie van het venster met de hoogste score en dezelfde context als Live Mode, zonder uitdunning op basis van locatie. Bij **Clips** bepaalt **Clipcontext** hoeveel seconden vóór en na elk geanalyseerd venster blijven behouden; dit werkt ook de context van Live Mode bij.

### 3. Veldtips

Dit scherm toont een korte checklist in de app om vóór het starten door te nemen.

### 4. Gereed

Het gereedscherm vat de duur, opnamekeuze en het gedrag met het scherm uit samen. Start met :app-playArrowRounded:.

## Scherm van de lopende punttelling

Het scherm van de lopende punttelling draait om een dashboard met de klok.

### Bovenbalk

- :app-stopRounded: — de punttelling vroegtijdig beëindigen
- :app-timerRounded: — de resterende tijd tonen
- :app-helpOutlineRounded: — de help voor Point Count openen
- :app-tuneRounded: — de instellingen voor Point Count openen

### Belangrijkste aanduidingen

- voortgangsbalk met aftelling
- compacte infobalk met de huidige detecties, het aantal unieke soorten en het totaal aantal detecties
- spectrogramweergave
- detectielijst

## Na de telling

Met **Doorgaan met uitgeschakeld scherm** aan in de Point Count-instellingen gaat de telling door als je het scherm vergrendelt of naar een andere app gaat, ook als het scherm aan blijft. De telling eindigt na de gekozen duur; de afteller gebruikt werkelijk verstreken tijd, zodat een onderbroken scherm de telling niet verlengt. Android toont een blijvende melding met Openen en Stoppen. Zet de schakelaar uit om de telling bij deze acties eerder te beëindigen. Point Count pauzeert en hervat niet, omdat dat de getimede telling zou onderbreken. Verlaat je de app tijdens het starten, dan wordt de telling met een melding geannuleerd; stel haar opnieuw in. In Windows beëindigt minimaliseren de telling niet.

Na de Point Count opent BirdNET Live [Session-overzicht](session-review.md). Bij automatisch opslaan wordt de Session meteen opgeslagen; anders kun je haar vanuit het overzicht bewaren.

Met automatisch opslaan aan wordt een lopende telling ook opgeslagen bij de start, elke 30 seconden en wanneer de app de voorgrond verlaat. Na een crash of stroomuitval staat de laatst opgeslagen gedeeltelijke telling in de Session-bibliotheek.
