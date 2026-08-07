# Instellingen

BirdNET Live gebruikt één instellingenscherm voor meerdere workflows. De knop :material-tune: opent de secties die relevant zijn voor het scherm waarvandaan je komt.

## Hoe het bereik van de instellingen werkt

- Open je de instellingen vanaf het startscherm, dan zie je het volledige scherm.
- Open je de instellingen vanuit Live, Survey, Point Count of Bestandsanalyse, dan wordt het scherm gefilterd tot de relevante secties.

## Algemeen

### Thema

Kies **Donker**, **Licht** of **Systeem**.

Staat **Dynamische kleuren** aan, dan probeert BirdNET Live ook het systeemkleurenpalet van je Android-toestel over te nemen. Dat heeft alleen effect op ondersteunde Android-toestellen; op iPhone en iPad blijft de app het standaardthema van BirdNET Live gebruiken, dus de schakelaar aanzetten verandert daar niets.

Zet **Thema met hoog contrast** aan voor een zwart-wit licht of donker interfacepalet met zwaardere tekst en omkaderde vlakken in plaats van getinte kaarten. Het volgt de keuze **Donker**, **Licht** of **Systeem**, overschrijft Dynamische kleuren zolang het aanstaat, en behoudt de kleuren voor gevaar, waarschuwing, validatie, modus, score en spectrogram.

### App-taal

Stelt de taal van de interface in.

### Soortnamen

Bepaalt de taal die voor soortnamen wordt gebruikt. **Systeem** gebruikt de voorkeurstaal van de telefoon wanneer die naam beschikbaar is, ook als de interface terugvalt op Engels. **App volgen** gebruikt in plaats daarvan de taal van de interface.

### Wetenschappelijke namen tonen

Toont overal in de app de wetenschappelijke naam onder de Nederlandse naam.

### Alle gedetecteerde soorten tonen

Alleen Live-modus en Point Count. Staat standaard uit, zodat deze schermen alleen soorten tonen die in de laatste inferentiecyclus zijn gedetecteerd: in de praktijk de soorten die op dat moment roepen. Zet de optie aan om elke soort die tijdens de lopende Session is gedetecteerd zichtbaar te houden in de lijst, ook nadat die stopt met roepen of onder de betrouwbaarheidsdrempel zakt.

Staat dit aan, dan verschijnt **Sortering van de soortenlijst**. **Nieuwste eerst** toont de soorten die nu roepen bovenaan, gesorteerd op hun huidige betrouwbaarheid, daarna de behouden soorten op hun meest recente detectie. **Betrouwbaarheid** sorteert op de hoogste betrouwbaarheid die elke soort tijdens de Session bereikte, **Alfabetisch** op de vertaalde Nederlandse naam, en **Voorkomens** op het aantal detecties. In elke sorteermodus verschijnen het percentage en de balk voor de betrouwbaarheid alleen zolang die soort op dat moment roept (behouden rijen van soorten die zijn gestopt worden gedimd), en herhaalde detecties tonen een telchip aan het einde van de rij met de Nederlandse naam.

### Naam van de waarnemer

Bij het opzetten van een Survey, Point Count en ARU wordt de laatst ingevoerde, niet-lege naam van de waarnemer uit een van die modi onthouden en alvast ingevuld wanneer je de volgende keer een veld-Session opzet. Zo blijft herhaald gebruik op een persoonlijke veldtelefoon snel, terwijl je de waarnemer vóór het starten van een Session nog kunt wijzigen of wissen.

### ARU-/stationsnummer

Bij het opzetten van een ARU-inzet wordt het laatst gebruikte, niet-lege ARU-/stationsnummer onthouden en alvast ingevuld voor de volgende inzet. Is het aanwezig, dan wordt het nummer opgenomen in de naam van de ARU-Session en in de bestandsnamen van exports, zodat herhaalde inzetten op een vaste locatie ook buiten de app herkenbaar blijven.

### Weergave van tijdstempels

Bepaalt hoe de tijden per detectie in het Session-overzicht verschijnen.

- **Relatief** toont de afstand tot het begin van de opname, bijvoorbeeld `00:12:34`. Het handigst bij het nakijken van één Session en het uitlijnen met de afspeelkop van het spectrogram.
- **Absoluut** toont de lokale kloktijd waarop de detectie is vastgelegd, bijvoorbeeld `08:42:17`. Het handigst voor het koppelen aan veldnotities, weerlogboeken of gelijktijdige opnamen.

Valt een detectie op een andere kalenderdag dan het begin van de Session (bijvoorbeeld bij een nachtelijke Survey), dan krijgt de absolute tijd het achtervoegsel `+1d`, zodat je het ochtendkoor van morgen niet per ongeluk voor dat van vandaag aanziet.

Is **Absoluut** gekozen, dan verschijnt de extra schakelaar **Seconden in tijdstempels tonen**. Zet die uit als je het compactere `08:42` verkiest boven `08:42:17` — handig bij het doorlopen van lange detectielijsten. Relatieve tijden tonen altijd seconden, omdat je bij het nakijken precisie onder de minuut nodig hebt om aan te sluiten op de afspeelkop van het spectrogram.

Opslag en exports gebruiken ongeacht deze instelling altijd UTC-tijdstippen, dus de keuze beïnvloedt nooit de gegevens — alleen de manier waarop ze worden getoond.

## Audio

Deze bediening verschijnt in live workflows die op audio draaien.

### Audiobron

Eén venster met twee onafhankelijke bedieningselementen: **Microfoon** — van welke ingang wordt opgenomen — en **Verwerking** — hoeveel de telefoon het signaal onderweg naar binnen mag veranderen. Ze zijn vrij te combineren, dus een USB-microfoon *onbewerkt* opnemen is een volstrekt geldige opstelling. Je keuze blijft behouden tussen app-starts, en dezelfde kiezer verschijnt op de opzetschermen van Survey, Point Count en ARU. Wijzigingen werken meteen — zelfs midden in een opname wisselt de app de microfoon onder de lopende Session in plaats van op de volgende te wachten.

**Microfoon** toont met naam elke ingang die de telefoon aanbiedt: USB-, bedrade en Bluetooth-microfoons, en op veel telefoons ook de afzonderlijke ingebouwde microfoons (bijvoorbeeld *onder* en *achter*). Draadloze microfoonsets zoals de Rode Wireless GO of de DJI Mic werken via een USB-C-ontvanger en verschijnen hier dus als gewone USB-audioapparaten op volle kwaliteit.

**Verwerking** is het onderdeel dat er het meest toe doet, en geldt **alleen voor Android**. Telefoons passen standaard een op spraak afgestemde DSP toe op microfoonaudio — ruisonderdrukking, spectrale bewerking en automatische versterking — omdat de microfoon overwegend voor telefoongesprekken wordt gebruikt. Die verwerking behandelt vogelzang als ruis die onderdrukt moet worden, en geen gewone instelling zet die uit. De enige uitweg is Android om een andere *audiobron* vragen:

| Optie | Wat die doet |
|---|---|
| **Standaard van de telefoon** | Wat je telefoon normaal doet, inclusief spraakverwerking. Het oorspronkelijke gedrag, en nog steeds de standaard zodat er voor bestaande gebruikers niets verandert. |
| **Onbewerkt** | Het ruwe microfoonsignaal — geen ruisonderdrukking, geen automatische versterking. Voor vogels meestal de beste keuze. |
| **Spraakherkenning** | Zet ook ruisonderdrukking en automatische versterking uit, en werkt op vrijwel elke telefoon. |

**Probeer ze uit en vergelijk.** Welke wint hangt echt van het toestel af. *Onbewerkt* is het ideaal, maar Android honoreert dat alleen op telefoons waarvan de fabrikant ondersteuning opgeeft — op de rest valt het stilzwijgend terug en klinkt het identiek aan *Standaard van het systeem*. Daar is *Spraakherkenning* voor: de compatibiliteitsregels van Android **eisen** dat automatische versterking en ruisonderdrukking daarvoor uitstaan, dus die levert betrouwbaar onbewerkte audio, zelfs op telefoons die *Onbewerkt* negeren. Verandert overschakelen naar *Onbewerkt* niets, schakel dan over naar *Spraakherkenning*.

Verwacht dat de onbewerkte opties **zachter** klinken — dat is de weggevallen automatische versterking, geen fout. Verhoog **Versterking** om dat te compenseren als de niveaumeter laag uitslaat.

**Op iOS** is de bediening voor Verwerking verborgen en is het venster simpelweg een lijst met microfoons. iOS levert de app al vrijwel onbewerkte audio, dus er valt hier niets vergelijkbaars te kiezen.

### Versterking

Lineaire versterker die op binnenkomende audio wordt toegepast voordat die het spectrogram en de classifier bereikt. Laat die op **1,0×** staan, tenzij je ingang stelselmatig te zacht is — bijvoorbeeld een dasspeldmicrofoon met hoge impedantie op een telefoon, of een USB-interface waarvan de voorversterker te laag staat. De versterking boven 1,0 duwen zal geen roepen tevoorschijn toveren die de microfoon nooit heeft opgevangen; het schaalt alleen wat de microfoon leverde, dus harde geluiden dichtbij kunnen gaan vervormen. Onder 1,0 is nuttig in het zeldzame geval dat een te hete ingang het spectrogram verzadigt.

### Hoogdoorlaatfilter (Hz)

Snijdt laagfrequente inhoud weg vóór de inferentie met een Butterworth-filter van 24 dB/octaaf — de waarde van de schuifregelaar is de −3 dB-grensfrequentie. **0 Hz schakelt het uit.** Een grens van 100–200 Hz haalt wind, verkeersgerommel en hanteergeluid weg zonder de meeste soorten te raken; richting 500–1000 Hz verdwijnen lage roepen, uilen, hoenders en het boemen van de roerdomp, dus ga alleen zo hoog wanneer je die soorten bewust negeert in ruil voor een veel schoner spectrogram in een lawaaiige stedelijke omgeving. De gekozen grens hoort als een scherpe horizontale lijn zichtbaar te zijn in het live spectrogram.

## Inferentie

### Vensterduur

Bepaalt de lengte van het analysevenster. Beschikbare stappen zijn **1**, **3**, **5**, **7**, **10** en **15** seconden.

### Betrouwbaarheidsdrempel

Bepaalt hoe behoudend detecties moeten zijn. De standaard is **35%**, waarmee de live lijst zich op sterkere overeenkomsten richt en toch ruimte laat voor roepen van ver of gedeeltelijk gemaskeerd. Verlaag die wanneer je zeldzame of stille soorten inventariseert en later meer kandidaten wilt nakijken; verhoog die wanneer achtergrondgeluid of veelvoorkomende valse treffers de Session vol laten lopen.

### Gevoeligheid

Een verschuiving op de x-as die op de ruwe waarschijnlijkheidsscores van het model wordt toegepast vóór score-pooling, geografisch filteren en de betrouwbaarheidsdrempel. Het audiomodel van BirdNET bevat al een sigmoïde activatie, dus BirdNET Live rekent elke waarschijnlijkheid eerst terug naar de logit-ruimte, telt de gevoeligheidsbias erbij op en zet die daarna weer om naar een waarschijnlijkheid. Hogere waarden maken de detector toegeeflijker — zwakkere of dubbelzinniger roepen halen de drempel, ten koste van meer valse treffers. Lagere waarden zijn strenger en laten alleen zekere detecties door. De standaard van **1,0** past geen verschuiving toe en komt overeen met de BirdNET-referentie. Probeer **1,25** als je vermoedt dat het model roepen van ver mist; ga terug naar **0,75** als je overspoeld wordt door detecties van lage kwaliteit van algemene soorten. De gevoeligheid wordt meteen toegepast: die midden in een Session wijzigen werkt door vanaf het volgende inferentievenster.

### Inferentiesnelheid

Bepaalt hoe vaak BirdNET inferentie uitvoert. De schuifregelaar gebruikt
dezelfde stappen van **0,10–1,00 Hz** als het opzetten van Survey en ARU. De
vensters zijn verankerd aan opgenomen audiosamples en niet aan het aflopen van
een timer, dus het opslaan van een fragment of een tijdelijk trage
modelaanroep verschuift latere vensters niet. Met dezelfde
inferentie-instellingen analyseren de Live-modus, Point Count en Survey
dezelfde vensters en melden ze dezelfde detecties. Lagere snelheden
verminderen het werk van het model en het batterijverbruik, maar laten
grotere gaten tussen de vensters, waardoor je heel korte geluiden makkelijker
mist. Nieuwe Survey-instellingen gebruiken standaard **0,70 Hz** als
middenweg; **0,30 Hz** blijft de uitdrukkelijke keuze voor maximale
batterijduur. De bestandsanalyse heeft geen inferentiesnelheid — die gebruikt
in plaats daarvan een instelling voor [overlap](file-analysis.md).

BirdNET Live effent scores intern uit over recente inferentievensters om
eenmalige valse treffers te verminderen. Deze pooling is niet als
gebruikersinstelling beschikbaar; standaard wordt adaptieve
Log-Mean-Exp-pooling gebruikt met vijf recente vensters en een realtime
leeftijdsgrens van 10 seconden. Geaccepteerde detecties tonen de sterkste
recent ondersteunde modelbetrouwbaarheid, zodat duidelijke geluiden nog steeds
een hoge betrouwbaarheid kunnen laten zien in plaats van door de uitvlakking te
worden afgevlakt. Alle modi zetten dat poolingresultaat nu op dezelfde manier
om in detecties: een detectie begint bij haar vroegste ondersteunende venster,
draagt de sterkste ondersteunde score en eindigt aan het einde van het laatste
ondersteunende venster.

## Spectrogram

### FFT-grootte

Bepaalt de frequentieresolutie in het spectrogram.

### Kleurenschaal

Kies **Viridis**, **Magma**, **Plasma**, **Cividis**, **Jet**, **Turbo**, **Grijswaarden** of **BirdNET**. **Turbo** is de moderne, op Jet lijkende regenboogoptie.

### Duur (scrollsnelheid)

Bepaalt hoeveel tijd er in het spectrogramvenster zichtbaar is.

### Frequentiebereik

Stelt de bovenste weergegeven frequentie in.

### Log-amplitude

Past logaritmische schaling toe op het spectrogram, zodat het makkelijker af te lezen is.

### Kwaliteit

Bepaalt hoe vloeiend het spectrogrambeeld wordt geschaald. **Gemiddeld** is de standaardbalans. Kies **Laag** op oudere telefoons wanneer het scrollen hapert of het toestel warm wordt; kies **Hoog** wanneer je vloeiender beeld verkiest en je toestel genoeg GPU-ruimte heeft. De gedachte erachter: dit verandert alleen de renderkosten, niet de audioanalyse of de detectieresultaten.

## Meldingen

Deze sectie bepaalt of BirdNET Live **detecties hardop voorleest via je koptelefoon of de telefoonluidspreker** terwijl een Session opneemt. De hele functie staat **standaard uit**, omdat die de akoestische omgeving rond de microfoon verandert — aanzetten is een bewuste afweging. Er is geen instelwizard: de kiezers voor uitgebreidheid × frequentie hieronder *zijn* de volledige instelling, dus je kunt op elk moment een andere voorinstelling aantikken en het verschil meteen horen. De gedachte erachter: tijdens lange Surveys kun je niet steeds op het scherm kijken; een discrete stem in je oor betekent dat je je blik op het habitat kunt houden en toch weet wat er zojuist te horen was.

### Detecties hardop voorlezen (hoofdschakelaar)

Staat standaard uit. Staat die aan, dan spreekt de app elke geaccepteerde detectie uit via de ingebouwde spraakuitvoer van je toestel. **Een koptelefoon wordt sterk aangeraden** — bij gebruik van de telefoonluidspreker bestaat het risico dat de melding door de microfoon wordt opgepikt en opnieuw gedetecteerd, dus de app dempt de recorder rond elke uitspraak kort om die lus te voorkomen (zie *Microfoon dempen tijdens spreken* hieronder).

### Voorinstelling voor uitgebreidheid

Hoeveel de app over elke detectie zegt. **Minimaal** spreekt alleen de soortnaam uit (het beste voor zeer lange Surveys waarbij je alleen het signaal wilt). **Gebalanceerd** is de standaard — korte, afwisselende zinnen als *"Roodborst"*, *"Roodborst gehoord"*, *"Weer een roodborst"*. **Spraakzaam** voegt wat meer context toe en komt dichter bij iemand die naast je meepraat. **Aangepast** verschijnt automatisch wanneer je de getallen onder Geavanceerd met de hand bijstelt. De gedachte erachter: dezelfde afremmingsinstellingen kunnen afhankelijk van de formulering te stil of te druk aanvoelen — met uitgebreidheid houd je de cadans en regel je alleen de woordenrijkdom.

### Voorinstelling voor frequentie

Hoe vaak de app überhaupt mag spreken. Vijf stappen van het stilst tot het spraakzaamst. **Zelden** en **Spaarzaam** wachten lang tussen meldingen en beperken het tempo — goed geschikt voor Surveys van meerdere uren waarin je een gevoel voor de activiteit wilt zonder doorlopend commentaar. **Normaal** is de standaardcadans, als in een gesprek. **Vaak** verkort de tussenpozen en verhoogt de bovengrens; passend voor korte Live-Sessions of wanneer je terugkoppeling dichter bij realtime wilt. **Voortdurend** verwijdert de aanloopvertraging volledig en laat de app in vrijwel elke detectiecyclus spreken — handig voor demonstraties, toegankelijkheid, of wanneer de wachttijd tot de eerste melding bij *Vaak* je te lang lijkt. **Aangepast** verschijnt wanneer je de tijdvelden onder Geavanceerd wijzigt. De gedachte erachter: dit is de ene knop die bepaalt of de app op de achtergrond blijft of aanwezig wordt — tik een andere voorinstelling aan en je hoort de nieuwe cadans binnen de volgende detectiecyclus, zonder opslaanknop.

### Stem

Tik op de stemregel om te kiezen uit de spraakstemmen die voor de meldingstaal zijn geïnstalleerd, of laat **Standaardstem** staan zodat het toestel kiest. De beschikbaarheid en kwaliteit van stemmen hangen af van het besturingssysteem en de geïnstalleerde spraakpakketten; extra stemmen kun je installeren via de spraakinstellingen van het toestel.

**Snelheid** loopt van 0,5×–1,5×; de standaard 1,0× is het "normale" tempo van het platform. **Toonhoogte** loopt van 0,7×–1,3×. Een kleine verlaging van de toonhoogte en een lichte vertraging kunnen meldingen buiten beter verstaanbaar maken met wind of stromend water op de achtergrond. *Voorbeeld uitspreken* geeft een voorproefje van de gekozen stem, de huidige formuleringsstijl, de snelheid en de toonhoogte zonder de instellingen te verlaten. Wijzigingen gelden vanaf de volgende melding.

### Geavanceerd

Een uitklapbaar deel met een handvol schakelaars voor het routeren van audio, plus de kiezer voor de triggermodus. Meestal hoef je dit niet te openen — de voorinstellingen voor uitgebreidheid en frequentie hierboven zijn de enige knoppen die dagelijks tellen. De getallen voor het afremmen (aanlooptijd, minimale tussenpauze, maximum per minuut, stilte bij reeksen, herstel van de recentheid) zijn gebundeld in de schuifregelaar **Frequentie**, zodat er één voor de hand liggende plek is om de cadans op of af te regelen.

- **Telefoonluidspreker toestaan** — Staat die uit, dan worden meldingen stilzwijgend overgeslagen als er geen koptelefoon of externe luidspreker is aangesloten. Staat die aan, dan wordt de telefoonluidspreker als terugval gebruikt. Zet dit aan voor ontspannen luisteren thuis; laat het uit bij veldwerk om akoestische terugkoppeling naar de microfoon uit te sluiten.
- **Microfoon dempen tijdens spreken** — Vervangt binnenkomende audio door stilte terwijl de app spreekt, zodat het geluid uit de luidspreker niet door de microfoon kan worden opgepikt en opnieuw gedetecteerd. Sterk aanbevolen (en de standaard). Zet dit alleen uit wanneer je microfoon akoestisch is afgeschermd van de telefoonluidspreker — bijvoorbeeld een dasspeldmicrofoon aan een andere kabel of een Bluetooth-headset.
- **Andere audio zachter zetten** — Verlaagt tijdens de melding kort het volume van muziek of podcasts uit andere apps en herstelt dat daarna. Staat standaard aan. Uit speelt op volle sterkte door.
- **Signaaltoon vóór het spreken** — Speelt vóór elke uitspraak een korte, zachte toon zodat je oor even de tijd heeft om van passief luisteren over te schakelen op aandacht voor de stem. Staat standaard aan. Vooral handig wanneer meldingen zeldzaam zijn of wanneer er muziek op de achtergrond speelt.
- **Wat er wordt gemeld** — Bepaalt welke detecties überhaupt in aanmerking komen voor een melding. *Elke detectie* (standaard) laat het afremmen beslissen. *Eerste keer per Session* meldt een soort alleen de eerste keer dat die in de huidige Session voorkomt. *Alleen waarnemingslijst* beperkt meldingen tot soorten op je waarnemingslijst (handig bij gericht Survey-werk waarbij je alleen over je prioritaire taxa wilt horen en verder niets).

## Opname

### Modus

- **Volledig** — de hele opname bewaren
- **Alleen detecties** — fragmenten rond detecties bewaren
- **Uit** — geen audio-opname

### Fragmentcontext

Is **Alleen detecties** actief, dan toont de app één schuifregelaar **Fragmentcontext** (0–5 s) die bepaalt hoeveel audio er aan **beide zijden** van elke detectie bewaard blijft. Elk fragment duurt `analysevenster + 2 × fragmentcontext`, dus met een analysevenster van 3 s en de standaardcontext van 1 s is het bewaarde fragment 5 s. Zet je de context op 2 s, dan levert dat een fragment van 7 s op (2 s aanloop + 3 s geanalyseerde audio + 2 s uitloop). Grotere waarden geven je meer ruimte voor visuele inspectie of externe controlegereedschappen, ten koste van schijfruimte; 0 bewaart alleen het geanalyseerde venster zelf.

### Formaat

Kies **WAV** of **FLAC**. WAV is groter, maar breed compatibel en snel te inspecteren. FLAC behoudt dezelfde verliesvrije audiokwaliteit met minder opslag, wat voor lange Sessions doorgaans beter is.

Deze instelling geldt voor audio die BirdNET Live opneemt. **Bestandsanalyse** bewaart een door de app beheerde kopie van het geïmporteerde bestand in het oorspronkelijke formaat, zodat MP3-, AAC-, WAV- en FLAC-uploads zonder extra conversiestap na te kijken blijven.

### Opname automatisch starten (alleen Live-modus)

Staat die aan, dan begint de Live-modus met opnemen zodra het scherm opent en het model klaar is met laden — zonder dat je op de microfoonknop hoeft te tikken. Handig voor kioskachtige opstellingen, handsfree gebruik (bijvoorbeeld het toestel in het veld gemonteerd) of elke workflow waarbij Live openen sowieso "nu starten" betekent. Staat standaard uit, zodat een onbedoelde tik op de Live-tegel op het startscherm niet stilzwijgend een Session begint. Het automatisch starten gebeurt maar één keer per schermbezoek, dus een Session stoppen en opnieuw op de microfoon tikken werkt gewoon als handmatige herstart.

Deze instelling regelt het openen van de Live-modus binnen de app. De [Quick Listen-widget](live-mode.md) begint bij een tik te luisteren, wat deze instelling ook is, en laat de instelling ongemoeid. Loopt of start er al een Session van Point Count, Survey, Bestandsanalyse of de ARU-modus, dan blijft die Session behouden en word je gevraagd die eerst te stoppen.

### Sessions automatisch opslaan (Live en Point Count)

Staat die aan (de standaard), dan wordt een afgeronde Live- of Point Count-Session automatisch aan je bibliotheek toegevoegd op het moment dat die eindigt. Staat die uit, dan opent een afgeronde Session in het overzicht met de markering **niet opgeslagen**: het opslaanpictogram licht op en je moet erop tikken om de Session te bewaren. Verlaat je het overzicht zonder op te slaan, dan worden de Session en de opnamen weggegooid. Dat past bij kort meeluisteren waarbij je alleen af en toe een opmerkelijk resultaat wilt bewaren in plaats van elke korte opname te verzamelen. Survey- en ARU-inzetten slaan altijd automatisch op — een lange onbemande run is te kostbaar om te verliezen door het opslaan te vergeten — dus daar geldt deze schakelaar niet.

## Weergave

### Weergave-overlay in het overzicht

Staat die aan (de standaard), dan opent het beluisteren van een audiofragment in een Session-overzicht met alleen fragmenten (waar geen volledige audio-opname of spectrogram beschikbaar is) een eigen modale speleroverlay met transportbediening en een spectrogramvoorbeeld, in plaats van het fragment op de achtergrond af te spelen. Heeft een Session volledige audio, dan wordt deze instelling overgeslagen en verschijnt de weergave-overlay nooit.

### Spraaknotities automatisch afspelen

Staat standaard uit. Staat die aan, dan speelt een spraaknotitie die aan een annotatie met tijdstempel hangt automatisch af tijdens het Session-overzicht, op het moment dat de afspeelkop de opgenomen positie passeert. De notitie wordt over de opname heen gemengd in plaats van die te pauzeren, zodat je je gesproken notitie in context naast de originele audio hoort. Laat die uit als je notities liever handmatig start door op hun annotatiechip te tikken.

### Demping bij spraaknotities

Wordt alleen getoond wanneer **Spraaknotities automatisch afspelen** aanstaat. Bepaalt hoeveel de hoofdopname wordt verlaagd terwijl een automatische spraaknotitie speelt. Hogere waarden maken gesproken notities beter verstaanbaar; lagere waarden laten meer van de oorspronkelijke opname onder de notitie doorklinken.

## Locatie

### GPS gebruiken

Gebruik de GPS van het toestel in plaats van handmatige coördinaten. Op Android
komen de posities van de locatievoorziening van het platform en niet van Google
Play Services, zodat de app het dialoogvenster van Google over
locatienauwkeurigheid niet activeert. Staat dit uit, dan leest de app uit
zichzelf nooit de GPS uit en vraagt die geen locatiemachtiging aan: de wizards
voor het opzetten van Survey, Point Count en ARU openen op handmatige invoer
met je opgeslagen coördinaten, GPS-tracking tijdens een Survey draait niet, en
het voorbereiden van offline kaarten centreert eveneens op die coördinaten.

### Handmatige coördinaten

De coördinaten die worden gebruikt wanneer **GPS gebruiken** uitstaat. Zowel breedte- als lengtegraad zijn bewerkbare tekstvelden, dus je kunt een exacte waarde **typen** of er een **plakken** die je uit een andere app hebt gekopieerd — veel nauwkeuriger dan een schuifregelaar over een aanraakscherm slepen. Voer decimale graden in (bijvoorbeeld `52.5200` en `13.4050`). Je kunt ook een gecombineerde tekst `breedtegraad, lengtegraad` (gescheiden door komma, puntkomma of spatie) in *een van beide* velden plakken, waarna beide velden in één keer worden gevuld — dat sluit aan op wat de meeste kaarten en websites op het klembord zetten. Waarden buiten bereik of niet-numerieke invoer worden ter plekke gemarkeerd en niet opgeslagen; geldige waarden blijven behouden terwijl je typt. De gedachte erachter: de meest voorkomende reden om een locatie handmatig in te stellen is het determineren van een geluid dat elders is opgenomen, en die locatie komt meestal als tekst van buiten — typen en plakken maken daar één nauwkeurige stap van. Wijs je liever een plek aan dan getallen in te voeren, dan opent **Kies op kaart** dezelfde kaartkiezer op volledig scherm als de opzetschermen, met de huidige coördinaten als startpunt, en vult die beide velden met de plek waarop je tikt.

### GPS nu vernieuwen

Dwingt een verse positiebepaling af in plaats van de laatst opgeslagen waarde te hergebruiken. De gedachte erachter: GPS-opvragingen worden per scherm in de cache bewaard zodat een opzetscherm niet bij elke opening op een satellietfix hoeft te wachten, maar die cache kan kilometers verouderd zijn als je sinds de vorige Session naar een nieuwe plek bent gereden. Tik hierop wanneer je bent verplaatst en wilt dat het geofilter *hier* gebruikt en niet de plek waar je ochtend begon. De huidige coördinaten uit de cache staan in de ondertitel, zodat je kunt controleren waar de app denkt dat je bent. Lukt een GPS-fix niet binnen ongeveer 10 seconden, dan valt de app terug op de laatst bekende locatie van het besturingssysteem en waarschuwt die je met een SnackBar, zodat je weet dat de waarde verouderd is.

### Offline kaarten downloaden

Het downloaden van offline kaarten is momenteel verborgen zolang BirdNET Live de openbare tegeldienst van OpenStreetMap gebruikt. OpenStreetMap ondersteunt normaal interactief kaartgebruik met bronvermelding, een duidelijke user agent en lokale caching, maar staat geen bulkmatig vooraf ophalen of downloadfuncties voor offline kaarten vanaf `tile.openstreetmap.org` toe. De implementatie van de downloader blijft behouden voor een toekomstige tegelbron die offline pakketten uitdrukkelijk toestaat.

### Soortenfilter

- **Uit** — geen geografische filtering
- **Locatiefilter** — soorten uitsluiten die onder de geografische drempel vallen
- **Locatieweging** — het geomodel als extra wegingssignaal gebruiken

### Drempel van het geofilter

Verschijnt wanneer er een filtermodus op basis van locatie actief is.

## Export & synchronisatie

### Formaten

Vink een willekeurige combinatie van exportformaten aan — bij elke keer opslaan of delen worden alle gekozen formaten samen in één ZIP gebundeld. Kies je één formaat zonder audiofragmenten en zonder HTML-rapport, dan krijg je omwille van achterwaartse compatibiliteit een kaal bestand (bijvoorbeeld `session.csv`) in plaats van een ZIP:

- Raven Selection Table — voor gebruik in Cornell Raven Pro.
- CSV — te openen in elk spreadsheetprogramma.
- JSON — het eenvoudigst voor programmatische verwerking; bevat de volledige metadata per Session.
- GPX — spoor en waypoints voor gebruik in kaartgereedschap (alleen zinvol wanneer GPS aanstond).

De gedachte erachter: veel workflows hebben tegelijk meer dan één formaat nodig — een CSV voor de spreadsheet, een Raven-tabel voor wie op de desktop nakijkt, en een JSON voor het analysescript. Dat uit elkaar trekken met een schakelaar voor één formaat betekende vroeger dezelfde Session drie keer exporteren. Nu vink je alle drie in één keer aan en reizen ze samen in de ZIP.

### Audiobestanden meesturen

Neem de opgeslagen audio mee naast de geëxporteerde tabellen of metadata wanneer de exportworkflow dat ondersteunt. Het delen van één detectie volgt deze instelling ook: een volledige Session-opname wordt op de exacte begin- en eindtijdstempels van die detectie gesneden, terwijl een Session met alleen detecties het bewaarde fragment gebruikt.

### Audio altijd als WAV delen

Wordt alleen getoond wanneer **Audiobestanden meesturen** aanstaat. Staat die aan, dan worden FLAC-opnamen vóór het delen of exporteren naar WAV omgezet. WAV is universeel compatibel maar aanzienlijk groter dan FLAC, dus laat dit uit tenzij het gereedschap aan de ontvangende kant geen FLAC kan lezen — sommige oudere desktopanalysesoftware en een enkel uploadformulier kunnen dat nog steeds niet.

### App-metadata meesturen

Staat die aan, dan bevat de export-ZIP een bijbestand `*.metadata.json` dat beschrijft hoe de Session tot stand kwam: de versie van BirdNET Live, de identiteit van het model, de weermomentopname die bij aanvang van de Session is vastgelegd, en eventuele waarschuwingen over de integriteit van de audio die tijdens het opnemen zijn gesignaleerd. De gedachte erachter: juist die herkomst stelt jou (of iemand die het nakijkt) in staat een Session maanden later te reproduceren of te controleren. Zet die uit wanneer je alleen de audio en je gekozen formaten netjes wilt delen — bijvoorbeeld om één WAV-bestand bij iNaturalist of eBird te plaatsen zonder dat er app-specifieke bestanden meeliften.

### HTML-rapport meesturen

Staat die aan, dan bevat elke export-ZIP ook een bestand `<session>_report.html` naast de tabel, de audiofragmenten en de GPX. Open het in een willekeurige webbrowser en je krijgt een afdrukklare samenvatting van de Session: een kopkaart met de datum, locatie, waarnemer en totalen; een interactieve kaart met het GPS-spoor en de detectiemarkers; een kaart per detectie met de miniatuur uit de Cornell-taxonomie, de namen, de scorepil, jouw bevestiging, een eventuele notitie die je hebt getypt en het originele audiofragment als ingebouwde speler; en de gebruikte analyse-instellingen. De gedachte erachter: een CSV is prima voor analysepijplijnen maar nutteloos om te delen met een niet-technische collega of om een korte veldsamenvatting af te drukken — het HTML-rapport vult dat gat met één tik. Miniaturen van soorten en kaarttegels hebben bij het eerste openen van het bestand een verbinding nodig (ze worden live opgehaald bij de BirdNET-taxonomie-API en OpenStreetMap), maar al het overige — tekst, opmaak, audioweergave, links — werkt volledig offline. Zet dit uit als je alleen de ruwe gegevens nodig hebt en de ZIP een paar KB kleiner wilt houden.

### Alleen audio delen

Haal het vinkje weg bij elk formaat **én** bij het HTML-rapport **én** bij het vakje voor app-metadata, zodat alleen **Audiobestanden meesturen** overblijft: dan geeft Delen de kale opname (bijvoorbeeld `BirdNET_Live_…flac`) aan het systeemvenster in plaats van een ZIP. Dat is de eenvoudigste route om een Session rechtstreeks naar iNaturalist, eBird of een andere app te sturen die een onverpakt audiobestand verwacht. Sessions met meerdere detectiefragmenten leveren nog steeds een ZIP op; bij het delen van één detectie wordt dat ene kale fragment overgedragen.

## Privacy

Deze sectie bepaalt **welke diensten van derden BirdNET Live namens jou mag benaderen**. De inferentie zelf draait volledig op je toestel — deze schakelaars regelen alleen optionele netwerkfuncties die de ervaring verrijken. Alle drie de schakelaars staan bij een verse installatie **standaard uit**; er gaat niets naar buiten voordat jij het zegt. De gedachte erachter: elke schakelaar is begrensd tot één concrete dienst en één concreet voordeel, zodat je precies kunt kiezen wat je workflow helpt en verder niets.

### Kaarttegels toestaan

Vereist voor elke interactieve kaart in de app (de locatiekiezer, de live kaart van de Survey en de Session-kaart). Staat die aan, dan halen de kaartwidgets rastertegels op bij de openbare servers van **OpenStreetMap**; de verzoeken om tegelcoördinaten verraden welk deel van de wereld je bekijkt. Tegels worden tot zes maanden lokaal in de cache bewaard, met een limiet van 6000 tegels zodat herhaald kaartgebruik efficiënt blijft zonder onbeperkt te groeien. Dit aanzetten schakelt ook **Plaatsnamen opzoeken toestaan** in, omdat de meeste gebruikers die kaarten laden ook verwachten dat Sessions leesbare plaatsnamen tonen. Je kunt het opzoeken van plaatsnamen apart weer uitzetten. Staan kaarttegels uit, dan valt elk kaartscherm terug op een plaatsaanduidingskaart, zodat de rest van de app blijft werken zonder dat er iets naar het netwerk lekt.

### Plaatsnamen opzoeken toestaan

Staat die aan, dan stuurt de app je vastgelegde coördinaten naar de dienst **Nominatim van OpenStreetMap** om een korte plaatsnaam te bepalen (bijvoorbeeld *"Berlijn, Duitsland"*), die naast de Session in de Session-bibliotheek en het Session-overzicht wordt getoond. De gedachte erachter: numerieke coördinaten zijn nauwkeurig maar lastig te overzien wanneer je door een lange lijst met Sessions scrolt — een plaatsnaam maakt de lijst in één oogopslag leesbaar. Staat die uit, dan tonen Sessions alleen de ruwe breedte- en lengtegraad, en wordt Nominatim nooit benaderd.

### Weer opzoeken toestaan

Staat die aan, dan legt elke opgeslagen Session via **Open-Meteo** eenmalig een momentopname vast van de plaatselijke omstandigheden (temperatuur, neerslag, wind, bewolking) op de opnamecoördinaten en het eindtijdstip. De momentopname belandt in het Session-overzicht onder de locatieregel en wordt overgenomen in de JSON-export, het metadatablok per Session en het HTML-rapport. De gedachte erachter: het weer is een van de sterkste voorspellers van vogelactiviteit, en dat automatisch vastleggen — zonder dat jij eraan moet denken een aparte app te raadplegen — maakt van elke Session een vollediger verslag. Open-Meteo is een gratis dienst en vereist noch een account noch een API-sleutel. Staat die uit, dan worden er geen weergegevens opgehaald of bewaard. Bij het opzetten van Point Count en Survey verschijnt ook een compacte weerkaart bij de locatiebediening: die vraagt deze toestemming alleen wanneer dat nodig is, toont na inschakeling een voorbeeld als pictogram + temperatuur + wind, en hergebruikt dezelfde momentopname uit de cache wanneer de Session wordt opgeslagen.

## Over

De regel **Over** opent het scherm Over in de app.

## Gevarenzone

### Introductie opnieuw instellen

Toont de introductiereeks opnieuw bij de volgende start van de app.

### Alle instellingen herstellen

Zet elke voorkeur op dit scherm terug naar de standaardwaarde. Sessions, opnamen, spraaknotities, exports en kaarttegels in de cache blijven onaangeroerd — alleen de opgeslagen voorkeuren (schuifregelaars, schakelaars, keuzes in kiezers) worden gewist. Na bevestiging sluit de app zodat de nieuwe standaardwaarden bij de volgende start van kracht zijn.

Handig wanneer je niet zeker weet aan welke schuifregelaar je hebt gedraaid waardoor iets misging, of wanneer je het toestel aan iemand anders geeft en een schone configuratie wilt zonder de verzamelde gegevens te verliezen.

### Alle gegevens wissen

Verwijdert definitief Sessions, detecties, opnamen, spraaknotities, eigen soortenlijsten, opgeslagen voorkeuren en gegevens in de cache voor kaarten, plaatsnamen, weer, weergave, overzicht en delen. Het bevestigingsvenster vraagt je `DELETE` te typen en sluit daarna de app, zodat de volgende start met een schone lokale staat begint.

Gebruik dit voordat je een toestel aan een andere waarnemer overdraagt, een veldtelefoon uit dienst neemt of aan locatie gekoppelde historie uit de app verwijdert. Exporteer eerst alles wat je nodig hebt; deze actie kan niet ongedaan worden gemaakt.

## Workflowspecifieke parameters buiten de instellingen

Sommige parameters stel je in hun eigen opzetschermen in, niet in het gedeelde instellingenscherm.

- [Point Count-modus](point-count-mode.md) heeft een eigen instelling voor duur en locatie.
- [Survey-modus](survey-mode.md) heeft een eigen scherm met Survey-parameters.
- [Bestandsanalyse](file-analysis.md) heeft een eigen stap voor analyseparameters.
