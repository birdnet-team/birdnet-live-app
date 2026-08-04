# Session-overzicht

In het Session-overzicht maakt BirdNET Live van ruwe detecties een bewerkbaar verslag.

## Hoe je er komt

BirdNET Live opent het Session-overzicht automatisch na afloop van:

- een Live-Session
- een punttelling
- een Survey
- een run van Bestandsanalyse

Je kunt ook elke opgeslagen Session opnieuw openen vanuit de [Session-bibliotheek](session-library.md).

## Belangrijkste onderdelen

### Samenvatting en weergave

Het Session-overzicht combineert audioweergave, navigatie door het spectrogram en een soortenlijst. Bij Survey-Sessions kan het ook de context op de kaart tonen.

De samenvattingskop bovenaan het scherm bevat de datum, een locatiechip (breedte- en lengtegraad plus optioneel een gevonden plaatsnaam wanneer **Instellingen → Privacy → Plaatsnamen opzoeken toestaan** aanstaat) en — wanneer **Instellingen → Privacy → Weer opzoeken toestaan** aanstond ten tijde van de opname — een **weerregel** onder de locatie met de omstandigheden die aan het einde van de Session zijn vastgelegd: een regel als *"20,1 °C · Lichte regen · 3,2 m/s ZW"* met een weerpictogram ervoor. Tik op de regel om een klein venster uit te klappen met de temperatuur, wind, neerslag en bewolking, met de bronvermelding van Open-Meteo. Dezelfde momentopname komt ook terug in de JSON-export, het metadatablok per Session en het HTML-rapport.

De spectrogramstrook boven de speler is interactief: tik om te zoeken, sleep met één vinger om door de tijdlijn te schuiven, en **knijp met twee vingers om in te zoomen** op een smal tijdvenster — handig wanneer je de timing van overlappende roepen wilt bekijken of een snelle triller wilt ontleden. Spreid je vingers weer om terug te keren naar het standaardoverzicht van 10 seconden. De afspeelknop op een soortkop kiest altijd het eerste cluster dat daadwerkelijk een opgenomen fragment heeft, zodat de knop beschikbaar is zodra een van de detecties van die soort afspeelbaar is.

### Soortenlijst

Soorten zijn gegroepeerd in uitklapbare rijen. Je kunt detecties per soort bekijken en tijdens het nakijken door de opname bewegen. Clusterrijen onder een uitgeklapte soort worden ingesprongen, zodat de kaart van de bovenliggende soort visueel onderscheiden blijft van de onderliggende rijen.

Een zoekveld boven de lijst filtert soorten op Nederlandse of wetenschappelijke naam, zodat één specifieke vogel vinden in een Session met 100 soorten een paar toetsaanslagen kost in plaats van lang scrollen. De knop :material-sort: ernaast wijzigt de volgorde van de soorten:

- **Hoogste betrouwbaarheid** (standaard) — soorten met de hoogste betrouwbaarheid van één detectie eerst. Handig om de meest zekere determinaties als eerste te beoordelen. Klap je in deze modus een soort uit, dan verschijnen detecties met afspeelbare audiofragmenten vóór detecties zonder fragment, daarna op betrouwbaarheid.
- **Meeste detecties** — soorten met het hoogste aantal detecties eerst. Handig om de dominante zangers te herkennen.
- **A → Z** — alfabetisch op Nederlandse naam. Voorspelbaar, taalbewust en makkelijk te overzien zodra een Session veel soorten bevat.
- **Eerst gedetecteerd** — chronologisch op het tijdstip van de eerste detectie. De historische standaard; handig bij het nakijken naast de tijdlijn van het spectrogram.

De gekozen sortering blijft behouden tussen Sessions.

### Een soort handmatig toevoegen

De werkbalkknop :material-plus-circle-outline: opent de soortkiezer voor vogels die BirdNET heeft gemist. Een zoekresultaat kiezen voegt die niet meteen toe — eerst schuift een bevestigingsvenster omhoog met de gekozen soort en twee selectievakjes:

- :material-ear-hearing: **Gehoord** — je hebt de vogel gehoord.
- :material-eye: **Gezien** — je hebt de vogel gezien.

Vink er één, beide of geen aan en tik dan op **Toevoegen**. **Annuleren** — of naar beneden vegen — brengt je terug naar het zoeken, dus een verkeerde tik kost niets. **Gehoord** staat standaard aangevinkt, en je keuze wordt overgenomen naar de volgende soort die je toevoegt, zodat je bij een reeks vogels die je alleen zag maar één keer **Gezien** hoeft aan te vinken. Laat je beide leeg, dan wordt de invoer zonder waarnemingstype opgeslagen, niet als "geen van beide".

De keuze wordt bij de detectie bewaard en getoond als een klein oor- en/of oogsymbool naast de badge voor handmatige invoer, overal waar die detectie verschijnt — soortkoppen, clusterrijen, het venster van de fragmentspeler en de lijst tijdens een live Survey. Het gaat ook mee in exports: een kolom `Evidence` in CSV- en Raven-selectietabellen, een veld `evidence` in JSON, en een pil in het HTML-rapport. Hetzelfde venster verschijnt wanneer je **Soort vervangen** gebruikt, alvast ingevuld met wat die registratie al bevatte.

### Acties per detectie

Overal waar een detectie verschijnt — de soortenlijst, het venster van de fragmentspeler, de lijst tijdens een live Survey en de markers op de Survey-kaart — gelden dezelfde acties:

- :material-check: **Bevestigen** — een vinkje met één tik dat een detectie markeert als visueel of akoestisch geverifieerd. Bevestigde clusters en kaartmarkers krijgen een klein groen vinkje zodat ze in één oogopslag opvallen, en de markering gaat mee in elk exportformaat.
- :material-dots-vertical: **Meer** — opent een overloopmenu met:
    - :material-share-variant: **Detectie delen** — zie *Delen* hieronder.
    - :material-swap-horizontal: **Soort vervangen** — kies een andere soort voor deze detectie.
    - :material-delete-outline: **Detectie verwijderen** — verwijdert de rij direct. Er verschijnt een paar seconden een SnackBar om dit ongedaan te maken, zodat missers omkeerbaar zijn. Geen bevestigingsvenster.
    - :material-delete-sweep-outline: **Soort verwijderen** — verwijdert in één keer elke detectie van die soort uit de Session, met dezelfde SnackBar om het ongedaan te maken. Handig om een verkeerd gedetermineerde geluidsbron op te ruimen zonder de soort uit te klappen en clusters een voor een te verwijderen.

#### Veegsnelkoppelingen op rijen in het overzicht

In de soortenlijst kun je een detectie ook bedienen door de rij horizontaal te vegen:

- veeg naar **rechts** → verwijderen (met ongedaan maken)
- veeg naar **links** → de overlay voor het vervangen van de soort openen

De twee achtergronden hebben een eigen kleur (foutrood tegenover primair blauw), zodat het effect van het gebaar duidelijk is voordat je het afmaakt.

Veeg je een rij met een **soortkop** (naar links of rechts), dan worden alle detecties van die soort in één keer verwijderd, met dezelfde SnackBar om het ongedaan te maken. Handig bij het opschonen van een Session vol verkeerd gedetermineerd geluid.

### Eén detectie delen

Het item :material-share-variant: **Detectie delen** gebruikt dezelfde keuzes als **Instellingen → Exporteren en synchroniseren**. Alleen deze detectie wordt geëxporteerd in de geselecteerde Raven-, CSV-, JSON-, GPX-, HTML- en app-metadata-artefacten. Wanneer **Audiobestanden opnemen** aanstaat, bevat het pakket ook de audio van de detectie; **Audio altijd als WAV delen** wordt gevolgd. Als alle begeleidende formaten, HTML en app-metadata uitstaan, ontvangt het systeemdeelvenster het onbewerkte audiofragment in plaats van een ZIP-bestand.

De audiobijlage wordt in deze volgorde bepaald:

1. **Bij Sessions die één doorlopend bestand opnemen**: audio van de begin- tot de eindtijdstempel van de detectie wordt rechtstreeks uit de opname gesneden. Doorlopende WAV- en FLAC-opnamen worden ondersteund; gecomprimeerde File Analysis-bronnen worden als WAV gedecodeerd.
2. Anders wordt het opgeslagen eigen fragment van de detectie gebruikt wanneer dit op schijf staat.
3. Als geen audiobron beschikbaar is en geen export-artefact is geselecteerd, valt delen terug op een korte tekst met soort, betrouwbaarheid, UTC-tijdstempel en locatie.

### Spraaknotities

Je kunt korte gesproken opmerkingen aan afzonderlijke detectieregistraties koppelen:

- **Opnemen**: Tik op de knop :material-dots-vertical: bij een detectiecluster en kies **Spraaknotitie opnemen** om het venster voor spraaknotities te openen. Tik op de grote microfoonknop om de opname te starten. Een live golfvorm geeft je stem in realtime weer. Tik op de stopknop wanneer je klaar bent.
- **Beluisteren**: Zodra de notitie is opgenomen, kun je die met de ingebouwde speler beluisteren. Tik op **Opnieuw opnemen** om de notitie te vervangen. Tik op **Opslaan** om die te bewaren.
- **Verwijderen**: Heeft een detectie al een spraaknotitie, dan kun je die verwijderen via het overloopmenu of via het venster voor spraaknotities.
- **Formaten per platform**: Op Android en andere platformen worden spraaknotities opgenomen in sterk gecomprimeerd AAC-formaat (`.m4a`) op 16 kHz. Op iOS wordt automatisch WAV/PCM16 (`.wav`) gebruikt om compatibiliteitsproblemen met CoreAudio en de actieve audiosessies van de app te voorkomen. Beide formaten worden volledig ondersteund door de ZIP-export.
- **Exporteren**: Bij het exporteren van de Session als ZIP worden spraaknotities gebundeld in de map `memos/` en worden hun relatieve paden vastgelegd in de JSON- en CSV-metadata.

### Kaart met het Survey-spoor

Survey-Sessions tonen een kleine ingebouwde kaart met het GPS-spoor en de detectiemarkers. Tik op een marker op die kaart om een detectie te richten — de ingebouwde kaart centreert erop. Tik op de knop :material-fullscreen: **uitklappen** (rechtsboven op de ingebouwde kaart) om de **kaart op volledig scherm** te openen; was er een detectie gericht, dan opent de kaart gecentreerd en ingezoomd op die detectie, zodat je je plek behoudt.

#### Betekenis van de markers

- **De betrouwbaarheid is in kleur gecodeerd** met een kleurenschaal die veilig is bij kleurenblindheid: van lage naar hoge betrouwbaarheid loopt die van paarsblauw via turkoois en geel naar rood. De helderheid van de schaal verandert monotoon, zodat die leesbaar blijft in zwart-wit en voor mensen met rood-groen kleurenblindheid.
- **Detecties met audio** tonen een gekleurde ring rond de soortfoto plus een afspeelbadge in de hoek — tik erop om hetzelfde venster van de fragmentspeler te openen als elders, met bevestigen, delen, vervangen en verwijderen.
- **Stille detecties** (geen fragment op schijf) worden kleiner, vager en met een neutraalgrijze ring weergegeven, zodat detecties met audio altijd als de belangrijkste inhoud opvallen.
- **Overlappende markers op dezelfde plek** worden op belang gestapeld: gemarkeerd > met audio > hogere betrouwbaarheid, zodat een stille marker met lage betrouwbaarheid nooit een sterke detectie met audio kan afdekken.
- **Onder zoomniveau 14,5** worden de silhouetten teruggebracht tot gekleurde stippen waarvan de grootte de betrouwbaarheid weergeeft, en klappen dichte clusters samen tot een bel met een aantal (clusteren stopt bij zoomniveau 15).

#### Filteren

De kaart op volledig scherm heeft een vaste **filterchip** rechtsboven op de kaart. Tik erop om het filtervenster te openen; het label van de chip toont altijd wat er nu geldt (*"Alle soorten"*, *"Met audio"*, *"≥ 80%"* of één soortnaam). Beschikbare filters:

- **Alle detecties** (standaard).
- **Met audiofragment** — alleen detecties waarvan het fragment nog op schijf staat en afspeelbaar is.
- **Handmatige toevoegingen** — alleen detecties die je zelf in het Session-overzicht hebt toegevoegd (automatisch gedetecteerde vallen af).

Je kunt de detecties ook op betrouwbaarheid beperken. De schuifregelaar stelt de ondergrens van de betrouwbaarheid in (begint bij 10%).

Onder de schuifregelaar voor betrouwbaarheid staat een kiezer **Beperken tot soort** waarmee je de kaart tot één soort kunt terugbrengen — handig voor de vraag "waar precies langs de route hoorde ik de grote lijster?". Het item *Alle soorten* heft de beperking op. De filters werken samen: bijvoorbeeld *Met audiofragment* + *Grote lijster* + *> 80%* toont alleen de afspeelbare markers van de grote lijster die boven de 80% scoorden.

Is er een filter actief, dan krijgt de titel in de appbalk een ondertitel met het aantal treffers (bijvoorbeeld *"7 detecties"*). *Herstellen* in het venster keert terug naar de standaard.

## Werkbalkpictogrammen

De werkbalk gebruikt dezelfde betekenissen van pictogrammen als beschreven in [Pictogrammen en bediening](icons-and-controls.md):

- :material-plus-circle-outline: — inhoud toevoegen
- :material-undo-variant: / :material-redo-variant: — door bewerkingen stappen
- :material-content-cut: — bijsnijdmodus
- :material-content-save: — bewerkingen opslaan
- :material-share-variant: — exporteren of delen
- :material-delete-outline: — Session weggooien
- :material-play: — een Survey voortzetten wanneer die actie beschikbaar is
- :material-help-circle-outline: — het hulpvenster van het Session-overzicht openen
- :material-tune: — de instellingen openen

## Gebruikelijke taken bij het nakijken

- detecties toetsen aan de audioweergave en de context van het spectrogram
- een soort of annotatie toevoegen
- de opname bijsnijden tot het bruikbare deel
- de nagekeken resultatenset exporteren

## Export

Het exportgedrag hangt af van de opties die je in [Instellingen](settings.md) hebt gekozen. De app kan detecties en optioneel audio in het gekozen exportformaat verpakken. Elke export gaat vergezeld van herkomstmetadata — de versie van de app, de naam en versie van het model, de taal van de soortnamen, het tijdstempel van de export, de bij de Session bewaarde instellingen en de relevante exportopties — weggeschreven naar een bijbestand `<prefix>.metadata.json` (ZIP) of een `meta`-blok op het hoogste niveau (JSON), zodat exports zichzelf beschrijven en reproduceerbaar zijn.

Het blok `settings` in de JSON-export legt de waarden vast die *daadwerkelijk op deze Session zijn toegepast* — gevoeligheid, de modus en het aantal vensters voor score-pooling, de microfoonversterking en de grensfrequentie van het hoogdoorlaatfilter — en niet wat er nu toevallig in de instellingen staat. Zo kun je maanden later een resultaat reproduceren of twee Surveys vergelijken zonder te onthouden hoe de schuifregelaars stonden toen je ze draaide.

Alle tijdstempels in geëxporteerde bestandsnamen (`BirdNET_Live_<date>_<time>_…`) en binnen CSV- en JSON-ladingen worden weergegeven in de *huidige* lokale tijd van je telefoon. De onderliggende registraties worden in UTC bewaard en bij het exporteren omgerekend.
