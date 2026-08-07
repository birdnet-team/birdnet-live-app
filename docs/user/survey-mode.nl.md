# Survey-modus

De Survey-modus is de routegebaseerde workflow voor langlopende tellingen waarbij je je verplaatst.

## Zo open je de modus

Tik op het startscherm op de kaart **Survey-modus** met het pictogram :material-routes:.

## Opzetproces

Het opzetten van een Survey is een wizard van vijf stappen.

### 1. Details

Je kunt hier invoeren:

- naam van de Survey
- transect-ID
- naam van de waarnemer
- GPS, handmatige coördinaten of geen startlocatie

Deze stap biedt ook de kaartkiezer, vernieuwt de GPS-positie wanneer je
terugkeert uit systeemschermen voor machtigingen, en toont zo nodig de
herinnering aan de machtiging voor GPS op de achtergrond. In hetzelfde
locatiegedeelte is een weerkaart beschikbaar. Staat de toegang tot weergegevens
uit, dan vraagt die om toestemming voor **Weer opzoeken toestaan**; zodra dat
aanstaat, toont die een voorbeeld van de locatie met alleen een weerpictogram,
de temperatuur en de wind. Dezelfde in de cache opgeslagen momentopname van
Open-Meteo wordt hergebruikt wanneer de Survey wordt opgeslagen.

### 2. Parameters

Deze stap bevat parameters die specifiek voor een Survey gelden, zoals:

- keuze van de microfoon
- inferentiesnelheid
- betrouwbaarheidsdrempel
- GPS-interval
- maximale duur
- opnamemodus
- fragmentcontext bij opnemen van alleen detecties
- steekproefmodus voor detecties
- limiet van top-N per soort wanneer de steekproef beperkt is

Nieuwe Survey-instellingen gebruiken standaard **0,70 Hz** inferentie. Dat
behoudt meer korte geluiden dan de zuinigere keuzes met een lagere snelheid,
terwijl het model nog steeds minder vaak draait dan bij 1,00 Hz. Survey en de
Live-modus delen één inferentieplanning en één definitie van een detectie, dus
met dezelfde inferentie-instellingen melden beide dezelfde soorten, scores en
detectieduren voor hetzelfde geluid. Lagere snelheden laten met opzet grotere
gaten tussen de overlappende analysevensters en kunnen daardoor korte geluiden
missen; 0,30 Hz blijft beschikbaar wanneer batterijduur voorop staat.

#### Steekproef van detecties

Een lange Survey kan duizenden detecties opleveren, en voor elk daarvan een audiofragment bewaren vult de opslag snel. De steekproef van detecties bepaalt **welke fragmenten op schijf worden bewaard** — *de detectieregistraties zelf blijven altijd behouden*, dus je volledige Session-log blijft ongeacht de modus intact. Registraties waarvan de audio is weggelaten, hebben in het Session-overzicht simpelweg geen afspeelbaar fragment.

Er zijn drie modi beschikbaar:

| Modus | Wat die doet |
|---|---|
| **Alles** | Bewaart elk fragment. Het meeste schijfgebruik. Aanbevolen voor korte Surveys of wanneer je van elke detectie de audio voor latere analyse wilt bewaren. |
| **Top N** | Bewaart alleen de **N fragmenten met de hoogste betrouwbaarheid per soort**. Andere fragmenten worden tijdens de Survey verwijderd. N is standaard 10 en instelbaar van 1 tot 50. |
| **Smart** | Dezelfde limiet van N per soort als Top N, **plus** ruimtelijke spreiding: komt een nieuwe detectie op dezelfde "plek" als een al bewaard fragment (binnen ongeveer 500 m en 2 minuten van elkaar), dan behoudt alleen de detectie met de hoogste betrouwbaarheid haar fragment. Zo kan één zingend exemplaar op één plek niet alle N plekken opeisen en dekken de bewaarde fragmenten het hele transect beter. |

De limiet N geldt **per soort, niet in totaal** — neem je 10 roodborsten en 10 vinken op, dan bewaar je 20 fragmenten. Er is geen totale bovengrens aan het aantal fragmenten dat een Survey kan opleveren.

Ontbreekt in de Smart-modus de GPS-positie bij een detectie, dan valt de controle op dezelfde plek terug op een venster van alleen tijd (ongeveer 2 minuten). Is er wel GPS, dan moeten zowel afstand als tijd overlappen om twee detecties als dezelfde plek te tellen.

### 3. Soortmeldingen

Meldingen in pushstijl die tijdens de Survey afgaan wanneer er iets opmerkelijks wordt gedetecteerd. Kies een van deze opties:

- **Uit** — geen meldingen (standaard).
- **Eerste in Session** — één melding de eerste keer dat elke soort tijdens deze Survey wordt gehoord.
- **Allereerste keer** — alleen een melding wanneer de app een soort voor het allereerst tegenkomt over al je Sessions heen (een "lifer"-melding). Gebaseerd op een levenslange soortenhistorie die bij de eerste start automatisch uit je bestaande Sessions wordt gevuld.
- **Zeldzaam voor deze locatie** — een melding wanneer de kans volgens het geomodel voor de huidige locatie onder een instelbare drempel ligt. Een live uitlezing onder de schuifregelaar legt precies uit waarop de huidige waarde afgaat (bijvoorbeeld *"Meldingen bij soorten met minder dan 5 % kans op deze locatie."*).
- **Waarnemingslijst** — alleen meldingen bij soorten die je aan een opgeslagen eigen lijst hebt toegevoegd. In deze wizardstap kun je nieuwe waarnemingslijsten aanmaken, bestaande lijsten bewerken in een speciale volledig scherm-editor met doorzoekbare taxonomie en *Importeren uit bestand* (elk gewoon `.txt`- of `.csv`-bestand met wetenschappelijke namen), en lijsten verwijderen die je niet meer nodig hebt.

Onder de moduskiezer staat een schuifregelaar voor de *Minimale betrouwbaarheid*, die automatisch niet lager gaat dan de betrouwbaarheidsdrempel van je Session (meldingen zijn nooit gevoeliger dan de detecties zelf). Een sectie **Geavanceerd** biedt bediening voor het afremmen — een aanloopvenster bij de start, een harde minimale tussentijd tussen twee meldingen, en een schuivende limiet per minuut met de optie om meldingen boven die limiet te bundelen in één samenvattende melding — allemaal met chipkiezers die je met één tik bedient. De eerste keer dat je naar een andere modus dan Uit overschakelt, vraagt de wizard de Android-machtiging voor meldingen voor je aan.

### 4. Veldtips

Een korte checklist vóór de start, binnen het opzetproces.

### 5. Gereed

Het gereedscherm vat de actieve Survey-configuratie samen voordat je start met :material-play:.

## Live Survey-dashboard

Het scherm van de lopende Survey heeft drie hoofdtabbladen plus een lijst met recente detecties.

### Bovenbalk

- :material-stop: — de Survey beëindigen
- :material-timer: — verstreken tijd
- :material-help-circle-outline: — het hulpvenster van de Survey openen
- :material-tune: — de Survey-instellingen openen

### Tabbladen

- :material-map-outline: — routekaart en detecties op de kaart
- :material-equalizer: — spectrogram
- grafiekpictogram — samenvattende statistieken en verdeling per soort

### Statistieken en detecties

Onder de inhoud van het tabblad toont het Survey-dashboard een statistiekbalk en een lijst met recente detecties. Tik op een detectie om de overlay met soortdetails te openen.

Elke detectierij biedt ook dezelfde acties per detectie als in het [Session-overzicht](session-review.md): een vinkje :material-check: **Bevestigen** met één tik en een overloopmenu :material-dots-vertical: **Meer** met **Detectie delen** en **Detectie verwijderen** (met een SnackBar om dat ongedaan te maken) — zo kun je een storende treffer al tijdens de opname bevestigen, delen of verwijderen in plaats van te wachten op het overzicht achteraf.

Dezelfde acties zijn beschikbaar vanaf de **live routekaart**: tik op een detectiemarker om het venster van de fragmentspeler te openen met bevestigen, delen en verwijderen. Delen tijdens een Survey werkt ook wanneer je hebt gekozen voor één doorlopende WAV-opname in plaats van fragmenten per detectie — het relevante audiovenster wordt ter plekke uit het lopende bestand gesneden. Zie [Session-overzicht → Eén detectie delen](session-review.md#eén-detectie-delen) voor details.

### Een waarneming vastleggen

De knop :material-plus-circle-outline: op de lopende Survey opent een klein menu met **Soort toevoegen** en **Notitie toevoegen**. **Soort toevoegen** opent dezelfde kiezer als in het [Session-overzicht](session-review.md#een-soort-handmatig-toevoegen): kies een soort, vink dan :material-ear-hearing: **Gehoord** en/of :material-eye: **Gezien** aan op het bevestigingsvenster en tik op **Toevoegen**. De invoer krijgt een tijdstempel van dat moment, wordt aan de huidige GPS-positie gekoppeld en verschijnt meteen in de detectielijst en op de routekaart, met de badge voor handmatige invoer en de bijbehorende oor- en oogsymbolen.

Spraaknotities ontbreken hier bewust: de microfoon is bezet met de opname van de Survey zelf. Voeg ze na afloop toe in het Session-overzicht.

## Werking op de achtergrond

De Survey-modus houdt tijdens het opnemen een blijvende voorgrondmelding zichtbaar, zodat Android de audiopijplijn niet onderbreekt. De melding klapt uit en toont:

- de verstreken tijd, het aantal detecties, het aantal soorten en de afgelegde afstand, en
- de **drie meest recente unieke soorten** met hun betrouwbaarheid en een relatief tijdstempel (`zojuist`, `42s geleden`, `5m geleden`, `2u geleden`).

De melding — titel, recente detecties en de statistiekregel onderaan — is volledig vertaald naar de gekozen taal van de app en gebruikt dezelfde voorkeuren voor de taal van soortnamen en *Wetenschappelijke namen tonen* als de kaarten in de app.

Soortmeldingen verschijnen (indien ingeschakeld) op een apart Android-meldingskanaal, zodat je meldingen los kunt dempen van de stille, doorlopende opnamemelding. Het meldingspictogram komt overeen met dat van de voorgrondmelding (een monochrome vogel), en de tekst van de melding toont alleen de *reden* — *"Eerste detectie van deze Survey"*, *"Staat op je waarnemingslijst"*, *"Op deze locatie gedetecteerd met minder dan 4% kans"* — terwijl de soortnaam in de vetgedrukte meldingstitel blijft staan, waar Android die het grootst weergeeft.

Wanneer je een onafgeronde Survey vanuit de Session-bibliotheek **hervat**, wordt de meldingspijplijn opnieuw ingesteld op je *huidige* meldingsvoorkeuren — niet op wat je had ingesteld op de dag dat je de Survey begon. Zet meldingen uit (of wijzig de modus, de waarnemingslijst of het afremmen) voordat je op Hervatten tikt, en de hervatte Survey volgt de nieuwe instellingen meteen.

## Nakijken op de kaart

De Survey-kaart op volledig scherm (de knop :material-fullscreen: in het Session-overzicht) opent een fragmentspeler wanneer je op een marker tikt. In de transportrij staan knoppen voor vorige en volgende naast de afspeelknop — die lopen chronologisch door de detecties, maar **alleen door de detecties die op dat moment op de kaart zichtbaar zijn**, dus elk actief filter op soort, betrouwbaarheid of moduschip beperkt de afspeellijst navenant. De knoppen worden grijs bij de eerste en laatste detectie in de gefilterde lijst.

## Na het stoppen

BirdNET Live slaat de afgeronde Survey op en opent het [Session-overzicht](session-review.md).
