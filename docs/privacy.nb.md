# Personvernerklæring for BirdNET Live

**Sist oppdatert:** 6. august 2026

Denne personvernerklæringen gjelder for **BirdNET Live** (**appen**). Appen utvikles og tilbys av **BirdNET-Team** (**utvikleren**, **vi** eller **oss**).

## Identiteten til appen og utvikleren

| | |
|---|---|
| **Appnavn** | BirdNET Live |
| **Utviklernavn** | BirdNET-Team |
| **Personvernkontakt** | [ccb-birdnet@cornell.edu](mailto:ccb-birdnet@cornell.edu) |

BirdNET-Team gir denne erklæringen i eget navn. Den forklarer hvordan BirdNET Live beskytter og behandler personopplysninger.

## Behandling på enheten

All lydanalyse og artsidentifisering skjer **utelukkende på enheten din**. Appen bruker to nevrale nettverksmodeller som kjører lokalt:

- **BirdNET+ lydklassifikator** — analyserer mikrofonlyd for å identifisere arter.
- **BirdNET geomodell** — forutsier hvilke arter som sannsynligvis finnes på stedet og årstiden.

Lyddata overføres aldri til eksterne servere.

## Behandling av personopplysninger

BirdNET-Team driver ingen serverløsning for appen og mottar ikke opptakene dine, posisjonen din, Session-data eller andre personopplysninger gjennom BirdNET Live. Appen har ingen brukerkontoer, reklame, analyse, sporing eller telemetri. Appen behandler lyd og posisjon på enheten din og sender bare opplysningene som er beskrevet under **Eksterne ressurser**, direkte til den navngitte tredjepartsleverandøren når du aktiverer en valgfri nettverksfunksjon.

### Data som lagres lokalt på enheten din

| Datatype | Formål | Lagring |
|----------|--------|---------|
| Lydopptak | Artsidentifisering, avspilling, eksport | Lokale filer |
| Deteksjonsresultater | Art, konfidens, tidsstempler | Lokale JSON-filer for Session |
| GPS-koordinater | Geotagging av deteksjoner, Survey-spor, geomodellprediksjoner | Lokale JSON-filer for Session |
| Session-metadata | Session-historikk, gjennomgang, eksport | Lokale JSON-filer for Session |
| Værøyeblikksbilde (valgfritt) | Engangsregistrering av temperatur, nedbør, vind, skydekke og værkode per Session når **Tillat væroppslag** er på | Lokale JSON-filer for Session |
| Appinnstillinger | Brukerinnstillinger | SharedPreferences |

### Medfølgende frakoblede data

Artsbilder, beskrivelser og taksonomidata er **inkludert i appen** og lastes fra lokale ressurser. Det gjøres ingen nettverksforespørsler for artsinformasjon.

## Eksterne ressurser

Appen kan bruke følgende eksterne ressurser. Hver ressurs styres av en egen bryter under **Innstillinger → Personvern**, og **alle tre er av som standard** ved en ny installasjon. Ingenting forlater enheten før du aktivt velger det.

| Ressurs | Formål | Styres av | Sendes ved hver forespørsel |
|---------|--------|-----------|-----------------------------|
| Kartfliser (OpenStreetMap Foundation) | Grunnkart for posisjonsvelgeren, det direkte Survey-kartet og Session-kartet | **Innstillinger → Personvern → Tillat kartfliser** | Fliskoordinater `(z, x, y)`, IP-adressen din som del av nettverkstilkoblingen og BirdNET Live-user-agent-strengen |
| Omvendt geokoding (OpenStreetMap Foundations Nominatim) | Gjør GPS-koordinater om til et lesbart stedsnavn for visning i en Session | **Innstillinger → Personvern → Tillat oppslag av stedsnavn** | Session-ens bredde- og lengdegrad, IP-adressen din som del av nettverkstilkoblingen og BirdNET Live-user-agent-strengen |
| Værøyeblikksbilde (OpenMeteo GmbH) | Engangsregistrering av lokale forhold ved opptakskoordinatene og sluttidspunktet | **Innstillinger → Personvern → Tillat væroppslag** | Session-ens bredde- og lengdegrad og sluttidspunkt, IP-adressen din som del av nettverkstilkoblingen og BirdNET Live-user-agent-strengen |

Kartflisforespørsler er HTTPS GET-forespørsler til `tile.openstreetmap.org`. Fliskoordinatene identifiserer kartområdet som vises. Som alle direkte Internett-forespørsler gjør forespørselen også IP-adressen din synlig for tjenesteleverandøren.

Forespørsler om omvendt geokoding sender Session-ens bredde- og lengdegrad til `nominatim.openstreetmap.org` over HTTPS, sammen med BirdNET Live-user-agent-strengen som kreves av [retningslinjene for bruk av Nominatim](https://operations.osmfoundation.org/policies/nominatim/). Det returnerte stedsnavnet lagres lokalt i Session-en, slik at hver Session bare geokodes én gang. Ingen forespørsel gjøres hvis Session-en mangler GPS-koordinater eller enheten er frakoblet.

Værforespørsler sender Session-ens bredde- og lengdegrad og sluttidspunkt til `api.open-meteo.com` over HTTPS, sammen med BirdNET Live-user-agent-strengen. [Open-Meteo](https://open-meteo.com/) er en gratis tjeneste og krever verken konto eller API-nøkkel. Det returnerte værøyeblikksbildet lagres lokalt i Session-en og skrives også til JSON-eksporten, Session-ens `metadata.json`-blokk og HTML-rapporten.

**Tredjepartsbehandling og lagring:** BirdNET-Team driver ikke disse tjenestene og mottar ikke forespørselsdataene deres. OpenStreetMap Foundation kan behandle nettverkstilgangsdata og forespørselsdetaljer i henhold til sin [personvernerklæring](https://osmfoundation.org/wiki/Privacy_Policy). Open-Meteo opplyser at webserverlogger for det gratis API-et kan inneholde IP-adresser og geografiske koordinater, og at loggene slettes etter 90 dager. Se deres [vilkår og personverninformasjon](https://open-meteo.com/en/terms). Leverandørene kan behandle data i andre land enn ditt. Returnerte stedsnavn og værdata lagres lokalt i Session-en og blir bare med i en eksport når du oppretter den.

**Tilbaketrekking:** Du kan deaktivere hver av de tre tjenestene når som helst under **Innstillinger → Personvern**. Stedsnavn og værdata som allerede er lagret lokalt, forblir knyttet til Session-ene der de ble hentet. Slett disse Session-ene fra Session-biblioteket, eller bruk **Innstillinger → Faresone → Slett alle data** for å fjerne historiske data.

**Appen starter ingen andre nettverksforespørsler selv.** Appen fungerer fullt ut frakoblet. Innhold du bevisst åpner i nettleseren, blant annet eksterne lenker og eksporterte HTML-rapporter, kan gjøre nettleserforespørsler som beskrevet nedenfor.

## Eksterne lenker

BirdNET Live inneholder lenker til tredjepartsnettsteder som du kan velge å åpne. Dette omfatter for eksempel en arts sider hos **eBird**, **iNaturalist** og **Wikipedia**, lydlenken *«Lytt til denne arten på eBird»* i artsvisningen og lenker til BirdNET-prosjektets nettsted, kildekoden, brukerveiledningen og donasjonssiden på **Om**-skjermen. Lenker som forlater appen, er merket med et ikon for ekstern lenke (↗), slik at du kan gjenkjenne dem før du trykker.

Ingenting sendes mens en lenke bare vises, og ingen ekstern lenke åpnes automatisk. Nettleseren åpnes bare når du trykker på en lenke. Da åpnes den i enhetens standardnettleser, og du forlater BirdNET Live. Målet drives av en tredjepart og styres av **deres egen** personvernerklæring og vilkår, ikke denne erklæringen. Slike nettsteder kan selv samle inn opplysninger om besøket ditt, for eksempel IP-adressen din, enhets- eller nettleseropplysninger og hvordan du bruker sidene, og de kan bruke egne informasjonskapsler. Vi kontrollerer ikke og er ikke ansvarlige for innholdet eller datapraksisen på eksterne nettsteder. Les personvernerklæringen til det enkelte nettstedet.

## GPS og posisjon

Appen bruker GPS-posisjon til:

- **Artsfiltrering** — å forutsi hvilke arter som sannsynligvis finnes på stedet.
- **Survey-modus** — å registrere GPS-spor og geotagge deteksjoner langs en transekt.
- **Point Count-modus** — å merke observasjonsstedet.

GPS-data lagres lokalt og tas bare med i eksporter når du uttrykkelig deler eller eksporterer en Session. Posisjonstilgang krever tillatelse fra deg og kan når som helst trekkes tilbake i systeminnstillingene.

## Dataeksport

Du kan eksportere Session-data i flere formater (Raven Selection Tables, CSV, JSON, GPX) og velge en hvilken som helst kombinasjon under **Innstillinger → Eksport → Formater**. De valgte formatene samles i én ZIP-fil sammen med eventuelle lydklipp og den valgfrie HTML-rapporten. Eksporter opprettes lokalt og deles via systemets delingsmeny. Appen laster ikke opp eksportdata til noen server.

## Sletting av data

Individuelle Sessions og tilhørende opptak kan slettes fra Session-biblioteket. For å slette BirdNET Lives lokale Sessions, opptak, talememoer, egendefinerte artslister, innstillinger og hurtigbuffere fra appen bruker du **Innstillinger → Faresone → Slett alle data**. Du kan også tømme BirdNET Lives applagring i operativsystemets innstillinger eller avinstallere appen.

## Kontakt

For spørsmål om personvern: [ccb-birdnet@cornell.edu](mailto:ccb-birdnet@cornell.edu)
