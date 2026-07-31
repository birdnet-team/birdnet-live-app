# ARU-modus

!!! note "Vroege implementatie"
    De ARU-modus maakt momenteel een herstelbare Session voor een geplande inzet aan, neemt geplande cycli op, draait live inferentie tijdens actieve cycli, bewaart detectiefragmenten wanneer die opnamemodus is gekozen en toont op Android bediening via een voorgrondmelding. Het gedrag op de achtergrond op iOS moet nog in het veld worden gevalideerd.

De ARU-modus (Autonomous Recording Unit) is de workflow voor geplande akoestische inzetten op een vaste locatie.

## Huidig opzetproces

- **Inzet en audio**:
    - **Metadata**: Voer een naam voor de inzet, een ARU-/stationsnummer en de naam van de waarnemer in.
    - **Locatie**: Geef de coördinaten van de locatie op via automatische GPS-bepaling of handmatige invoer van breedte- en lengtegraad, of sla het instellen van de locatie over. Breedte- en lengtegraad zijn verplicht wanneer je planning op de zonnestand baseert.
    - **Opnameformaat**: Kies tussen FLAC (gecomprimeerd, verliesvrij) en WAV (ongecomprimeerd).
    - **Opnamemodus**:
        - *Volledig*: Neemt elke actieve cyclus in zijn geheel op.
        - *Alleen detecties*: Bewaart korte audiofragmenten rond gedetecteerde vogelgeluiden. Je kunt de fragmentcontext aanpassen (0 tot 5 seconden audiobuffer vóór en na de detectie) en de steekproefmethode kiezen (*Alles*, *Top N* of *Smart* om het opslaggebruik te beperken).
        - *Uit*: Draait realtime inferentie tijdens de cycli en legt detecties vast, maar bewaart geen audiobestanden.
- **Planning**:
    - **Duur en herhaling**: Kies hoe lang elke actieve opnamecyclus duurt en hoe vaak die zich herhaalt.
    - **Opnamevenster (dagritme)**: Kies of je 24/7 opneemt (*Elk moment*) of de cycli beperkt tot *Alleen overdag*, *Alleen 's nachts*, of specifieke vensters *Rond zonsopgang*, *Rond zonsondergang* of *Rond zonsopgang en zonsondergang*. De vensters rond zonsopgang en zonsondergang worden dynamisch berekend op basis van de coördinaten van de inzet.
    - **Einde van de planning**: Kies of je de inzet handmatig stopt, stopt na een vast aantal voltooide cycli, of automatisch stopt op een bepaalde datum en tijd.
    - **Batterijbeheer**: Stel een stopdrempel voor een lage batterij in (0-50%) om inzetten te pauzeren en te voorkomen dat de batterij volledig leegloopt. Als je die instelt, kun je ook een hervattingsdrempel opgeven zodat opnamecycli automatisch doorgaan wanneer het batterijniveau weer stijgt (bijvoorbeeld door opladen op zonne-energie).
    - **Testrun**: Een optionele testcyclus van één minuut staat standaard aan om meteen bij de start de microfooningang en de inferentie te controleren, zonder mee te tellen voor het geplande aantal cycli.
    - **Groepering van Sessions**: Stel in of elke cyclus als een aparte Session wordt opgeslagen (aanbevolen voor snellere laadtijden en modulair bekijken) of dat alle cycli in één Session met meerdere segmenten worden gecombineerd.
- **Gereed**: Bekijk de planning, het geschatte opslagverbruik voor audio en de beperkingen op het dagritme, en start dan de inzet.

Zodra je een inzet start, wordt meteen een Session van het type `SessionType.aru` met de metadata van de ARU-planning opgeslagen, zodat de staat van de cycli later kan worden hersteld.

JSON- en ZIP-exports bevatten de metadata van de ARU-inzet. ZIP-exports bundelen de opgeslagen opnamebestanden per cyclus onder `aru_cycles/`.

## Scherm van de actieve inzet

Het scherm van de actieve ARU-inzet toont of die wacht, opneemt of voltooid is. De indeling gebruikt vier tabbladen:
- **Status**: Toont de huidige staat van de inzet, de timer van de actieve planning en een lijst met realtime detecties.
- **Audio**: Toont een live meelopend spectrogram om de audio-invoer te controleren, met de detecties eronder in beeld.
- **Planning**: Somt de eerstvolgende 10 geplande cyclustijden op en geeft aan of ze op zonsopgang of zonsondergang zijn afgestemd wanneer er beperkingen op het dagritme gelden.
- **Samenvatting**: Vat de verstreken tijd, de totale duur van de opgenomen audio en de detectiestatistieken samen.

Op Android tonen actieve inzetten een voorgrondmelding met de acties Stoppen en Openen.

Wanneer je een inzet stopt, opent het Session-overzicht. Zijn de cycli in één Session gegroepeerd, dan opent die gecombineerde Session; zijn ze als aparte Sessions opgeslagen, dan opent de Session van de laatst voltooide cyclus.

Behandel deze vroege implementatie op iOS als een workflow op de voorgrond totdat geplande audio-opname en het gedrag op de achtergrond op dat platform zijn gevalideerd.

## Nog gepland

- Validatie van het gedrag op de achtergrond op iOS.
- Volledige ondersteuning voor weergave en spectrogram in het Session-overzicht voor ARU-opnamen die uit meerdere bestandssegmenten bestaan.
