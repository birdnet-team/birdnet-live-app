# Live-modus

De Live-modus is de snelste manier om via de telefoonmicrofoon mee te luisteren en detecties in realtime te bekijken.

## Zo open je de modus

Tik op het startscherm op de kaart **Live-modus** met het pictogram :app-micRounded:.

## Quick Listen

Quick Listen begint met één tik te luisteren, zonder dat je de app hoeft te openen en erin te navigeren — handig wanneer je iets hoort dat je wilt laten herkennen voordat het stopt met roepen. Elk van de onderstaande ingangen opent de Live-modus en begint meteen te luisteren, ongeacht hoe de instelling **Opname automatisch starten** staat, en geen van ze wijzigt die instelling.

### Android: widget op het startscherm

Je voegt de widget toe zoals elke andere widget: houd een lege plek op het startscherm ingedrukt, tik op **Widgets**, zoek **BirdNET Live** en sleep een van de twee tegels naar buiten.

- **Snel luisteren** (2×1) — pictogram met het label **Luisteren starten**
- **Snel luisteren (compact)** (1×1) — alleen het pictogram

Beide doen hetzelfde.

### iOS: Opdrachten, Siri, actieknop en app-pictogram

BirdNET Live biedt het systeem de actie **Luisteren starten** aan, dus je hoeft niets zelf te bouwen:

- **Actieknop** (iPhone 15 Pro en nieuwer) — open **Instellingen → Actieknop**, kies **Opdracht** en selecteer **Luisteren starten** onder BirdNET Live. De knop ingedrukt houden start daarna het luisteren.
- **Siri** — zeg "Begin met luisteren met BirdNET Live", "Luister naar vogels met BirdNET Live" of "Herken een vogel met BirdNET Live".
- **Opdrachten-app** — de actie **Luisteren starten** staat onder BirdNET Live. Gebruik hem in een eigen opdracht, zet die opdracht op het startscherm of start hem via Tik op achterkant, een focus of een NFC-tag.
- **App-pictogram** — houd het BirdNET Live-pictogram op het startscherm ingedrukt en tik op **Luisteren starten**.
- **URL** — automatiseringen die een URL openen, kunnen `birdnetlive://listen` gebruiken.

Siri-zinnen en de vermelding in de actieknopkiezer vereisen iOS 17. De Opdrachten-actie, het pictogrammenu en de URL werken ook op iOS 16.

### Wat er daarna gebeurt

Als de Live-modus al open is, keert Quick Listen terug naar datzelfde scherm in plaats van het opnieuw op te bouwen. Een lopende of gepauzeerde Session gaat ongewijzigd verder; is die gestopt, dan start het luisteren op het bestaande scherm.

Quick Listen vervangt nooit een andere lopende modus. Loopt of start er een Session van Point Count, Survey, Bestandsanalyse of de [ARU-modus](aru-mode.md), dan komt de app naar de voorgrond en vraagt of je die Session eerst wilt stoppen. Het bijbehorende scherm en het werk blijven bereikbaar en worden niet onderbroken.

## Bovenbalk

De bovenbalk bevat drie elementen:

- :app-arrowBackRounded: — de Live-modus verlaten
- statustekst in het midden — `Initialiseren`, `Model laden`, `Gereed`, `Soorten herkennen`, `Gepauzeerd` of `Fout`
- :app-tuneRounded: — de instellingen openen die specifiek voor Live gelden

## Hoofdknop

De grote ronde knop onderaan in het midden wisselt van toestand:

- :app-mic: — beginnen met luisteren
- :app-stopRounded: — de actieve Session stoppen
- :app-playArrowRounded: — hervatten vanuit een gepauzeerde, gereede toestand

## Wat je ziet tijdens het luisteren

### Spectrogram

Het spectrogram loopt doorlopend mee zolang er opgenomen wordt. Het toont de frequentie-inhoud in de tijd, met de kleurenschaal, FFT-grootte, het frequentiebereik en de duur die in de instellingen zijn geconfigureerd.

### Detectielijst

Recente detecties verschijnen onder het spectrogram. Elke rij kan het volgende tonen:

- afbeelding van de soort
- Nederlandse naam
- optioneel de wetenschappelijke naam
- betrouwbaarheidswaarde

Tik op een soortrij om de overlay met soortdetails te openen.

### Session-infobalk

De compacte informatieregel onder het spectrogram vat de huidige Session samen, bijvoorbeeld:

- detecties die nu worden getoond
- aantal unieke soorten (`spp`)
- totaal aantal detecties (`det`)
- verstreken tijd
- geschatte opnamegrootte wanneer opnemen aanstaat

## Opnamegedrag

Opnemen regel je in [Instellingen](settings.md).

- **Volledig** neemt de hele Session op.
- **Alleen detecties** neemt fragmenten rond detecties op.
- **Uit** schakelt opnemen uit.

Wanneer je de Live-modus stopt, slaat BirdNET Live de Session op en opent het [Session-overzicht](session-review.md).

Als automatisch opslaan van Sessions aanstaat, slaat de Live-modus ook een gedeeltelijke Session op bij de start, elke 30 seconden en wanneer de app naar de achtergrond gaat. Na een crash of stroomuitval staat de laatst opgeslagen stand in de Session-bibliotheek. Wijzigingen sinds die opslag kunnen verloren gaan. Zet je automatisch opslaan uit, dan vervallen ook deze tussentijdse opslagmomenten.

## Luisteren met het scherm uit

Live Mode pauzeert normaal als je het scherm vergrendelt of de app verlaat en hervat dezelfde Session als je terugkomt. De eerste keer biedt een dialoog beperkt luisteren op de achtergrond aan. Zet in de [opname-instellingen](settings.md) **Doorgaan met uitgeschakeld scherm** aan en kies maximaal 15, 30, 60 of 120 minuten (standaard 30). De limiet geldt voor iedere periode buiten de app; bij het bereiken eindigt de Session. Android toont een blijvende melding met Openen en Stoppen. In Windows blijft Live Mode luisteren met een geminimaliseerd venster.
