# Point Count-modus

De Point Count-modus is de workflow voor tellingen op tijd vanaf een vast punt in BirdNET Live.

## Zo open je de modus

Tik op het startscherm op de kaart **Point Count-modus** met het pictogram :material-map-marker:.

## Opzetproces

Het opzetten van een punttelling verloopt in vier stappen.

### 1. Duur en locatie

Kies:

- een van de beschikbare chips voor de duur
- de huidige GPS-positie met :material-crosshairs-gps:
- handmatige coördinaten met :material-map-marker-plus:
- geen locatie met :material-map-marker-off:
- de kaartkiezer met :material-map:

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

Kies analyse-instellingen voor deze Session, zoals de vensterduur, de
inferentiesnelheid, de betrouwbaarheidsdrempel en de modus van het
soortenfilter. Ze beginnen bij je globale instellingen, maar je kunt ze voor
deze telling aanpassen zonder je standaardwaarden te wijzigen.

### 3. Veldtips

Dit scherm toont een korte checklist in de app om vóór het starten door te nemen.

### 4. Gereed

Het gereedscherm vat de gekozen duur samen en laat je starten met :material-play:.

## Scherm van de lopende punttelling

Het scherm van de lopende punttelling draait om een dashboard met de klok.

### Bovenbalk

- :material-stop: — de punttelling vroegtijdig beëindigen
- :material-timer: — de resterende tijd tonen
- :material-tune: — de instellingen voor Point Count openen

### Belangrijkste aanduidingen

- voortgangsbalk met aftelling
- compacte infobalk met de huidige detecties, het aantal unieke soorten en het totaal aantal detecties
- spectrogramweergave
- detectielijst

## Na de telling

Wanneer de punttelling eindigt, slaat BirdNET Live de Session op en opent het [Session-overzicht](session-review.md).
