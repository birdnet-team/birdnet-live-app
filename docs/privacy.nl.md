# Privacybeleid voor BirdNET Live

**Laatst bijgewerkt:** 6 augustus 2026

Dit Privacybeleid is van toepassing op **BirdNET Live** (de **app**). De app wordt ontwikkeld en aangeboden door **BirdNET-Team** (de **ontwikkelaar**, **wij** of **ons**).

## Identiteit van app en ontwikkelaar

| | |
|---|---|
| **Appnaam** | BirdNET Live |
| **Naam ontwikkelaar** | BirdNET-Team |
| **Privacycontact** | [ccb-birdnet@cornell.edu](mailto:ccb-birdnet@cornell.edu) |

BirdNET-Team verstrekt dit beleid in eigen naam. Het legt uit hoe BirdNET Live persoonlijke informatie beschermt en verwerkt.

## Verwerking op het apparaat

Alle audioanalyse en identificatie van vogelsoorten gebeuren **volledig op je apparaat**. De app gebruikt twee neurale netwerkmodellen die lokaal draaien:

- **BirdNET+ audioclassificatie** — analyseert de microfoonaudio om vogelsoorten te identificeren.
- **BirdNET geo-model** — voorspelt welke soorten waarschijnlijk zijn op jouw locatie en tijd van het jaar.

Er worden nooit audiogegevens naar externe servers verzonden.

## Verwerking van persoonlijke informatie

BirdNET-Team beheert geen app-backend en ontvangt via BirdNET Live geen opnamen, locatiegegevens, Session-gegevens of andere persoonlijke informatie van je. De app heeft geen gebruikersaccounts, advertenties, analyses, tracking of telemetrie. De app verwerkt wel audio en locatie op je apparaat en stuurt alleen wanneer je een optionele netwerkfunctie inschakelt de onder **Externe bronnen** beschreven informatie rechtstreeks naar de genoemde externe aanbieder.

### Gegevens die lokaal op je apparaat worden opgeslagen:

| Soort gegevens | Doel | Opslag |
|----------------|------|--------|
| Audio-opnamen | Vogelidentificatie, afspelen, exporteren | Lokale bestanden |
| Detectieresultaten | Soorten, betrouwbaarheid, tijdstempels | Lokale JSON-sessiebestanden |
| GPS-coördinaten | Geotaggen van detecties, Survey-tracks, geo-modelvoorspellingen | Lokale JSON-sessiebestanden |
| Sessiemetadata | Sessiegeschiedenis, controle, export | Lokale JSON-sessiebestanden |
| Weersnapshot (optioneel) | Eenmalige opname van temperatuur, neerslag, wind, bewolking en weercode per sessie wanneer **Weer opzoeken toestaan** aanstaat | Lokale JSON-sessiebestanden |
| App-instellingen | Gebruikersvoorkeuren | SharedPreferences |

### Meegeleverde offline gegevens

Soortafbeeldingen, beschrijvingen en taxonomische gegevens zijn **in de app meegeleverd** en worden uit lokale bestanden geladen. Er worden geen netwerkverzoeken gedaan voor soortinformatie.

## Externe bronnen

De app kan de volgende externe bronnen benaderen. Elke bron wordt geregeld door een onafhankelijke schakelaar onder **Instellingen → Privacy**, en **alle drie staan standaard uit** bij een nieuwe installatie. Er verlaat niets je apparaat totdat je ermee instemt.

| Bron | Doel | Geregeld door | Verzonden per verzoek |
|------|------|---------------|-----------------------|
| Kaarttegels (OpenStreetMap Foundation) | Basiskaart voor de locatiekiezer, de live Survey-kaart en de Session-kaart | **Instellingen → Privacy → Kaarttegels toestaan** | Tegelcoördinaten `(z, x, y)`, je IP-adres als onderdeel van de netwerkverbinding en de BirdNET Live user-agent |
| Reverse-geocoding (Nominatim van OpenStreetMap Foundation) | GPS-coördinaten omzetten naar een leesbare plaatsnaam (bijv. “Berlijn, Duitsland”) voor weergave bij de Session | **Instellingen → Privacy → Sta het opzoeken van plaatsnamen toe** | Breedte-/lengtegraad van de Session, je IP-adres als onderdeel van de netwerkverbinding en de BirdNET Live user-agent |
| Weersnapshot (OpenMeteo GmbH) | Eenmalige opname van lokale omstandigheden (temperatuur, neerslag, wind, bewolking, WMO-weercode) op de opnamecoördinaten en eindtijd | **Instellingen → Privacy → Weer opzoeken toestaan** | Breedte-/lengtegraad en eindtijd van de Session, je IP-adres als onderdeel van de netwerkverbinding en de BirdNET Live user-agent |

Verzoeken om kaarttegels zijn HTTPS GET-verzoeken naar `tile.openstreetmap.org`. De tegelcoördinaten identificeren het bekeken kaartgebied. Zoals bij elk rechtstreeks internetverzoek wordt ook je IP-adres aan de aanbieder bekendgemaakt.

Reverse-geocodingverzoeken sturen de breedte- en lengtegraad van de sessie via HTTPS naar `nominatim.openstreetmap.org`, samen met de BirdNET Live user-agent zoals vereist door het [Nominatim-gebruiksbeleid](https://operations.osmfoundation.org/policies/nominatim/). De opgeloste plaatsnaam wordt lokaal bij de sessie opgeslagen, zodat een sessie maar één keer wordt gegeocodeerd. Er wordt geen verzoek gedaan als de sessie geen GPS-coördinaten heeft of het apparaat offline is.

Weerverzoeken sturen de breedte-/lengtegraad van de sessie en de eindtijdstempel via HTTPS naar `api.open-meteo.com`, samen met de BirdNET Live user-agent. [Open-Meteo](https://open-meteo.com/) is een gratis dienst en vereist geen account of API-sleutel. De teruggegeven weersnapshot wordt lokaal bij de sessie opgeslagen en ook weggeschreven naar de JSON-export, het `metadata.json`-blok per sessie en het HTML-rapport.

**Verwerking en bewaring door derden:** BirdNET-Team beheert deze diensten niet en ontvangt hun aanvraaggegevens niet. OpenStreetMap Foundation kan netwerktoegangsgegevens en aanvraagdetails verwerken volgens haar [Privacybeleid](https://osmfoundation.org/wiki/Privacy_Policy). Open-Meteo stelt dat serverlogs van de gratis API IP-adressen en geografische coördinaten kunnen bevatten en na 90 dagen worden verwijderd; zie de [Voorwaarden en Privacy](https://open-meteo.com/en/terms). Deze aanbieders kunnen gegevens in andere landen verwerken. Teruggegeven waarden worden lokaal in de Session opgeslagen en komen alleen in een export terecht wanneer je die maakt.

**Intrekken:** je kunt elk van de drie diensten op elk moment uitschakelen onder **Instellingen → Privacy**. Reeds lokaal opgeslagen plaatsnamen en weersnapshots blijven gekoppeld aan de sessies waarin ze zijn vastgelegd; verwijder die sessies uit de Sessiebibliotheek of gebruik **Instellingen → Gevarenzone → Wis alle gegevens** om die historische gegevens te verwijderen.

**Er worden geen andere netwerkverzoeken gedaan.** De app werkt volledig offline.

## Externe links

BirdNET Live bevat links naar websites van derden die je kunt openen — bijvoorbeeld de **eBird**-, **iNaturalist**- en **Wikipedia**-pagina's van een soort en de audiolink *„Luister naar deze soort op eBird”* in de soortweergave, plus links naar de BirdNET-projectwebsite, de broncode, de gebruikershandleiding en de donatiepagina in het scherm **Over**. Links die de app verlaten zijn gemarkeerd met een pictogram voor externe links (↗), zodat je ze vóór het tikken herkent.

Zolang een link alleen wordt weergegeven, wordt er niets verzonden, en geen enkele externe link wordt ooit automatisch geopend — een browser opent alleen wanneer je erop tikt. De link opent dan in de standaardbrowser van je apparaat en je verlaat BirdNET Live. De bestemming wordt beheerd door een derde partij en valt onder **hun eigen** privacybeleid en voorwaarden, niet onder dit beleid. Zulke sites kunnen onafhankelijk informatie over je bezoek verzamelen — bijvoorbeeld je IP-adres, apparaat- of browsergegevens en hoe je met hun pagina's omgaat — en hun eigen cookies plaatsen. We hebben geen controle over en zijn niet verantwoordelijk voor de inhoud of gegevenspraktijken van externe websites; lees het privacybeleid van elke site zelf door.

## GPS en locatie

De app gebruikt GPS-locatie voor:

- **Soortfiltering** — voorspellen welke soorten waarschijnlijk zijn op jouw locatie.
- **Survey-modus** — GPS-tracks opnemen en detecties geotaggen langs een transect.
- **Point Count-modus** — de waarnemingslocatie taggen.

GPS-gegevens worden lokaal opgeslagen en alleen in exports opgenomen wanneer je een sessie expliciet deelt of exporteert. Locatietoegang vereist je toestemming en kan op elk moment worden ingetrokken via de systeeminstellingen.

## Gegevens exporteren

Je kunt sessiegegevens exporteren in meerdere formaten (Raven Selection Tables, CSV, JSON, GPX) en onder **Instellingen → Exporteren → Formaten** elke combinatie van formaten tegelijk aanvinken; de geselecteerde formaten worden samen in één ZIP gebundeld, naast de audioclips en het optionele zelfstandige HTML-rapport. Exports worden lokaal gegenereerd en gedeeld via het deelvenster van het systeem. De app uploadt geen exportgegevens naar een server.

## Gegevens verwijderen

Afzonderlijke sessies en hun opnamen kunnen worden verwijderd uit de Sessiebibliotheek. Om de lokale sessies, opnamen, spraakmemo's, aangepaste soortenlijsten, voorkeuren en caches van BirdNET Live vanuit de app te wissen, gebruik je **Instellingen → Gevarenzone → Wis alle gegevens**. Je kunt de opslag van de BirdNET Live-app ook wissen via de instellingen van je besturingssysteem of de app verwijderen.

## Contact

Voor privacyvragen: [ccb-birdnet@cornell.edu](mailto:ccb-birdnet@cornell.edu)
