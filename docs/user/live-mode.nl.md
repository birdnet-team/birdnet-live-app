# Live-modus

De Live-modus is de snelste manier om via de telefoonmicrofoon mee te luisteren en detecties in realtime te bekijken.

## Zo open je de modus

Tik op het startscherm op de kaart **Live-modus** met het pictogram :material-microphone:.

## Quick Listen-widget

**Alleen Android.** Een widget op het startscherm begint met één tik te luisteren, zonder dat je de app hoeft te openen en erin te navigeren — handig wanneer je iets hoort dat je wilt laten herkennen voordat het stopt met roepen.

Je voegt de widget toe zoals elke andere widget: houd een lege plek op het startscherm ingedrukt, tik op **Widgets**, zoek **BirdNET Live** en sleep een van de twee tegels naar buiten.

- **Quick Listen** (2×1) — pictogram met het label **Start Listening**
- **Quick Listen (compact)** (1×1) — alleen het pictogram

Beide doen hetzelfde. Als je op een van beide tikt, opent de Live-modus en begint het luisteren meteen, ongeacht hoe de instelling **Opname automatisch starten** staat. De widget wijzigt die instelling niet.

Als de Live-modus al open is, keert de widget terug naar datzelfde scherm in plaats van het opnieuw op te bouwen. Een lopende of gepauzeerde Session gaat ongewijzigd verder; is die gestopt, dan start het luisteren op het bestaande scherm.

Quick Listen vervangt nooit een andere lopende modus. Loopt of start er een Session van Point Count, Survey, Bestandsanalyse of de [ARU-modus](aru-mode.md), dan komt de app naar de voorgrond en vraagt of je die Session eerst wilt stoppen. Het bijbehorende scherm en het werk blijven bereikbaar en worden niet onderbroken.

## Bovenbalk

De bovenbalk bevat drie elementen:

- :material-arrow-left: — de Live-modus verlaten
- statustekst in het midden — `Initialiseren`, `Model laden`, `Gereed`, `Soorten herkennen`, `Gepauzeerd` of `Fout`
- :material-tune: — de instellingen openen die specifiek voor Live gelden

## Hoofdknop

De grote ronde knop onderaan in het midden wisselt van toestand:

- :material-microphone: — beginnen met luisteren
- :material-stop: — de actieve Session stoppen
- :material-play: — hervatten vanuit een gepauzeerde, gereede toestand

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
