# Verkennen

Verkennen toont de soorten die met het BirdNET-geomodel voor de huidige locatie en het huidige seizoen worden voorspeld.

## Zo open je de modus

Open **Verkennen** vanuit de voettekst van het startscherm met de knop :material-magnify:.

## Appbalk en kop

### Appbalk

- :material-refresh: — de locatie vernieuwen en de lijst met voorspelde soorten opnieuw opbouwen

### Locatiekop

De kop toont:

- de huidige, via reverse geocoding gevonden plaatsnaam wanneer die beschikbaar is
- de coördinaten onder de plaatsnaam
- :material-help-circle-outline: — het hulpvenster van Verkennen openen

## Soortenlijst

Elke soortkaart kan het volgende bevatten:

- meegeleverde afbeelding van de soort
- Nederlandse naam
- optioneel de wetenschappelijke naam
- chip met de abundantieklasse

Tik op een kaart om de overlay met soortdetails te openen.

### Abundantieklassen

In plaats van een ruw percentage toont elke kaart een **abundantieklasse** voor de huidige plaats en het huidige seizoen. De chip combineert twee aanwijzingen:

- een **cirkel** die van ⅙ tot volledig vult naarmate de soort waarschijnlijker wordt
- de **eerste letter** van de naam van de klasse (de volledige naam wordt door schermlezers voorgelezen en in de overlay met soortdetails getoond)

De kleur van de chip volgt de gedeelde scoreschaal van de app en verloopt van rood (minder waarschijnlijk) naar groen (waarschijnlijker) naarmate de klasse stijgt.

Er zijn zes klassen, van meest naar minst waarschijnlijk:

| Klasse | Betekenis |
| --- | --- |
| **Talrijk** | Behoort hier tot de sterkste voorspellingen |
| **Algemeen** | Zeer waarschijnlijk |
| **Regelmatig** | Waarschijnlijk |
| **Ongewoon** | Mogelijk |
| **Schaars** | Onwaarschijnlijk |
| **Zeldzaam** | Behoort hier tot de zwakste voorspellingen |

De klassen zijn **relatief ten opzichte van de huidige locatie**. Ze passen zich aan de mate waarin het geomodel soorten in dit gebied voorspelt, zodat de grenzen meebewegen met de lokale scoreverdeling: op een plek met veel stellige voorspellingen heeft een soort een zeer hoge score nodig om **Talrijk** te zijn, terwijl dezelfde klasse in een gebied met zwakkere voorspellingen al bij een lagere score wordt bereikt. Dezelfde score kan dus op verschillende plekken in verschillende klassen vallen, waardoor de rangschikking overal betekenisvol blijft.

## Overlay met soortdetails

De overlay kan het volgende tonen:

- een grotere afbeelding
- de bronvermelding van de afbeelding
- de Nederlandse en wetenschappelijke naam
- meegeleverde beschrijvende tekst wanneer die beschikbaar is
- grafiek met de wekelijks verwachte frequentie
- externe links zoals eBird, iNaturalist of Wikipedia wanneer die voor die soort beschikbaar zijn

## Waar Verkennen voor bedoeld is

Verkennen is een locatiebewuste naslagweergave binnen de app. Het helpt je de huidige locatiecontext van de app te vergelijken met de soorten die je zou kunnen tegenkomen.

Het verandert **niet** uit zichzelf de opgeslagen Session-gegevens. Het filteren van detecties regel je apart via [Instellingen](settings.md).
