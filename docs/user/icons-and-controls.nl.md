# Pictogrammen en bediening

Deze pagina legt de terugkerende bedieningselementen en symbolen in BirdNET Live uit. De labels hieronder komen exact overeen met de bediening zoals die in de app verschijnt.

## Moduspictogrammen

Deze pictogrammen hebben dezelfde vormen als in de app. Hier volgen ze de tekstkleur; appkleuren variëren met thema, dynamische kleuren en hoog contrast.

- :app-micRounded: **Live**
- :app-locationOnRounded: **Point Count**
- :app-routeRounded: **Survey**
- :app-timerRounded: **ARU-modus**
- :app-audioFileRounded: **Bestandsanalyse**
- :app-sdStorage: **Batchanalyse** (Binnenkort beschikbaar)

## Gedeelde navigatieknoppen

| Element | Waar je het ziet | Wat het doet |
|---|---|---|
| :app-tuneRounded: **Instellingen** | Voettekst startscherm, Live, Point Count, Survey, Bestandsanalyse, Session-overzicht | Opent de instellingen. In modusschermen worden de instellingen geopend die het meest relevant zijn voor die workflow. |
| :app-searchRounded: **Verkennen** | Voettekst startscherm | Opent Verkennen. |
| :app-libraryMusic: **Bibliotheek** | Voettekst startscherm | Opent de Session-bibliotheek. |
| :app-helpOutlineRounded: **Help** | Voettekst startscherm, kop van Verkennen, Survey-dashboard, werkbalk Session-overzicht | Opent de help of een hulpvenster voor dat scherm. |
| :app-infoOutline: **Info / Over** | Voettekst startscherm, infobalken, hulpvensters | Toont algemene informatie of samenvattende context. |
| :app-arrowBackRounded: **Terug** | Live-modus | Keert terug naar het vorige scherm. |
| :app-openInNew: **Extern openen** | Scherm Over, documentatielinks | Opent een externe pagina, zoals de online gebruikershandleiding. |
| :app-arrowUpwardRounded: **Terug naar boven** | Helpscherm | Keert terug naar de introductie en sectiekoppelingen. Verschijnt na omlaag scrollen. |
| :app-volunteerActivism: **Doneren** | Scherm Over | Opent de donatiepagina van BirdNET. |

## Weersymbolen

| Element | Betekenis |
|---|---|
| :app-wbSunny: **Helder** | Onbewolkte hemel. |
| :app-partlyCloudyDay: **Half bewolkt** | Zon en wolken bij overwegend helder of half bewolkt weer. |
| :app-cloudy: **Bewolkt** | Volledig bewolkt. |
| :app-foggy: **Mist** | Mist of aanvriezende mist. |
| :app-rainyLight: **Motregen** | Lichte neerslag. |
| :app-rainy: **Regen** | Regen of regenbuien. |
| :app-weatherSnowy: **Sneeuw** | Sneeuw of sneeuwbuien. |
| :app-thunderstorm: **Onweer** | Onweersachtige omstandigheden. |

## Start, stop en Session-bediening

| Element | Betekenis |
|---|---|
| :app-micRounded: **Microfoon** | Live luisteren starten. |
| :app-stopRounded: **Stoppen** | Een lopende opname, punttelling of Survey stoppen. |
| :app-playArrowRounded: **Afspelen** | Een ingesteld startproces beginnen of hervatten vanuit een gepauzeerde, gereede toestand. |
| :app-close: **Sluiten** / :app-stop: **Annuleren** | Een lopende bestandsanalyse annuleren via de kopbalk of het voortgangsscherm. |
| :app-timerOutlined: **Timer** | Duur of resterende tijd. |
| :app-errorOutline: **Fout** | Fout in het model of de verwerking. |

## Locatie- en tijdbediening

| Element | Betekenis |
|---|---|
| :app-myLocation: **Huidige locatie** | Gebruik de huidige GPS-positie van het toestel. |
| :app-editLocationAlt: **Handmatige coördinaten** | Coördinaten handmatig invoeren. |
| :app-locationOff: **Geen locatie** | Locatie overslaan of aangeven dat er geen locatie beschikbaar is. |
| :app-locationOn: **Heeft locatie** | Een locatie bevestigen, coördinaten tonen of een Session met kaart aanduiden. |
| :app-refresh: **Vernieuwen** | De huidige locatie opnieuw uitlezen of een voorspellingslijst vernieuwen. |
| :app-mapSheet: **Kaartkiezer** | Coördinaten kiezen via de kaartkiezer. |
| :app-calendarToday: **Datum** | Een datum instellen of tonen. |
| :app-clear: **Wissen** | Een gekozen datum verwijderen. |

## Symbolen bij Verkennen en soorten

| Element | Betekenis |
|---|---|
| Miniatuur van de soort | Meegeleverde afbeelding van de soort, indien beschikbaar. |
| Badge met betrouwbaarheid of geomodelpercentage | Een korte numerieke samenvatting van de modeluitvoer. Hogere getallen duiden op sterkere ondersteuning binnen de context van dat scherm. |
| Maandlabels (`jan`, `apr`, `jul`, `okt`, `dec`) | Referentiepunten op de grafiek met de wekelijks verwachte frequentie in de soortoverlay. |

## Acties per detectie

Deze knoppen verschijnen op elke detectierij in de app — de soortenlijst in het Session-overzicht, het venster van de fragmentspeler, de detectielijst tijdens een live Survey en de markers op de Survey-kaart. Zie [Session-overzicht → Acties per detectie](session-review.md#acties-per-detectie) voor het volledige gedrag.

| Element | Betekenis |
|---|---|
| :app-checkCircleOutline: **Bevestigen** | Vinkje met één tik dat een detectie markeert als visueel of akoestisch geverifieerd. Bevestigde detecties krijgen een klein groen vinkje op clusterrijen en kaartmarkers. |
| :app-moreVert: **Meer** | Opent het overloopmenu per detectie met **Detectie delen**, **Soort vervangen**, **Detectie verwijderen** en **Soort verwijderen**. |
| :app-share: **Detectie delen** | Deelt één detectie via het deelvenster van het systeem en voegt het audiofragment toe wanneer dat beschikbaar is — inclusief een stukje van de lopende opname tijdens een live Survey. |
| :app-swapHoriz: **Soort vervangen** | Kies een andere soort voor deze detectie. Opent ook door een rij in het overzicht naar links te vegen. |
| :app-deleteOutline: **Detectie verwijderen** | Verwijdert de rij direct. Er verschijnt een paar seconden een SnackBar om dit ongedaan te maken. Wordt ook geactiveerd door een rij in het overzicht naar rechts te vegen. |
| :app-deleteSweep: **Soort verwijderen** | Verwijdert in één keer elke detectie van die soort uit de Session, met dezelfde SnackBar om het ongedaan te maken. |
| :app-hearing: **Gehoord** | Bij een handmatig toegevoegde detectie: je hebt de vogel gehoord. In te stellen met het selectievakje op het bevestigingsvenster dat verschijnt na het kiezen van een soort. |
| :app-visibility: **Gezien** | Bij een handmatig toegevoegde detectie: je hebt de vogel gezien. Beide symbolen samen betekenen gehoord *én* gezien. |

## Werkbalk van het Session-overzicht

Deze knoppen gebruik je in het scherm Session-overzicht.

| Element | Betekenis |
|---|---|
| :app-addCircleOutline: **Toevoegen** | Inhoud toevoegen, zoals een soort of annotatie. |
| :app-undo: **Ongedaan maken** / :app-redo: **Opnieuw** | Stap terug of vooruit door de bewerkingen in het overzicht. |
| :app-contentCut: **Bijsnijden** | De bijsnijdmodus openen of tonen dat die actief is. |
| :app-save: **Opslaan** | Wijzigingen in het overzicht opslaan. |
| :app-share: **Delen** | De Session exporteren of delen. |
| :app-deleteOutline: **Verwijderen** | De Session weggooien. |
| :app-playArrowRounded: **Doorgaan** | Een onafgeronde Survey vanuit het Session-overzicht voortzetten wanneer die actie beschikbaar is. |

## Statusbalken per scherm

### Live-modus

De Live-infobalk gebruikt :app-infoOutline: gevolgd door compacte labels, zoals:

- `now` — detecties die momenteel in de live lijst zichtbaar zijn
- `spp` — aantal unieke soorten
- `det` — totaal aantal detecties
- duur en geschatte opnamegrootte wanneer er wordt opgenomen

### Point Count

De timerbalk van de punttelling combineert :app-stopRounded: **Stoppen**, :app-timerOutlined: **Timer** en een voortgangsbalk om de resterende tijd van de Session te tonen.

### Survey

Het Survey-dashboard gebruikt:

- :app-map: **Kaart** — tabblad met de live kaart
- :app-graphicEq: **Spectrogram** — tabblad met het spectrogram
- :app-summaryChart: **Samenvatting** — tabblad met de samenvatting
- :app-summaryChart: labels met statistieken in de samenvattingsweergave van de Survey

## Bij twijfel

Weet je niet zeker wat een knop doet, open dan het dichtstbijzijnde hulpvenster in de app, of raadpleeg de pagina over de workflow van dat scherm in deze gebruikershandleiding.
