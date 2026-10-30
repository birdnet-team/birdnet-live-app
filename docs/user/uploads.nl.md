# Uploads

Uploads sturen afgeronde Sessions van veel telefoons naar één projectmap. Een projectleider zet één keer een map op en deelt een link of een QR-code uit; elke deelnemer plakt of scant die, en vanaf dat moment kan elke Session met twee tikken vanuit het venster Delen naar die map worden gestuurd. ARU-inzetten kunnen elke afgeronde Session uit zichzelf versturen.

Uploads gaan één kant op. De app schrijft bestanden naar de projectmap en leest, somt of verwijdert daar nooit iets. Een Session op je telefoon verwijderen laat de geüploade kopie onaangeroerd, en er wordt nooit iets geüpload tenzij je een bestemming hebt aangevinkt of automatische ARU-uploads hebt aangezet.

## Hoe het werkt

Een **bestemming** is een WebDAV-map waarin de app kan schrijven. Drie soorten werken meteen:

- een **Nextcloud File Drop**-deellink, de aanbevolen keuze voor de meeste projecten;
- elk **WebDAV-adres** met een gebruikersnaam en wachtwoord, bijvoorbeeld een map in je eigen cloudaccount of een institutionele server;
- de **referentie-dropserver** die met BirdNET Live wordt meegeleverd, voor projectleiders die tokens per deelnemer en een kant-en-klare CSV-export willen (zie de [Developer Guide](../developer/upload-drop-server.md)).

Elke upload is **één ZIP-bestand per Session**, genoemd zoals de export van Delen, bijvoorbeeld `BirdNET_Live_2026-05-14_06-30-00_#13.zip`. Het bevat altijd het JSON-record van de Session en, afhankelijk van wat je aanvinkt, de audio, de detectietabellen, het HTML-rapport en het bestand met app-metadata. De ZIP komt terecht in een map die is genoemd naar je **upload-id**, een code van acht tekens die de app afleidt uit een willekeurige identiteit die hij voor deze installatie bewaart. De map van de projectleider ziet er daardoor zo uit:

```
4ee91c8f/BirdNET_Live_2026-05-14_06-30-00_#13.zip
4ee91c8f/BirdNET_Live_2026-05-14_07-02-10_#14.zip
b27c0e51/BirdNET_Live_2026-05-14_06-45-00_#3.zip
.birdnet-live/4ee91c8f.json
.birdnet-live/b27c0e51.json
```

De map `.birdnet-live` bevat per apparaat één klein registratiebestand, geschreven door de verbindingstest. Nextcloud verbergt die map tenzij "Verborgen bestanden tonen" aanstaat. Het bestand bevat de upload-id, de app-versie, het platform en de optionele **deelnemer-id** (een naam, e-mail of deelnemernummer) die een deelnemer heeft ingevuld, zodat de projectleider kan zien wie er achter elke code zit zonder dat een naam ooit een mapnaam wordt. Dezelfde id wordt in het JSON-record van elke geüploade Session geschreven.

## Voor projectleiders

### Optie A: een Nextcloud File Drop

1. Maak in Nextcloud een map voor het project, bijvoorbeeld `Spring Survey 2027`.
2. Open het deelpaneel van de map, maak een **deellink** en zet de rechten op **File drop (alleen uploaden)**. Deelnemers kunnen dan bestanden toevoegen, maar zien nooit wat anderen hebben gestuurd.
3. Stel een **wachtwoord** in op de link. Zonder wachtwoord kan iedereen die de link vindt naar de map uploaden. Een File Drop is zelfs dan niet te lezen, dus een ontbrekend wachtwoord is een keuze die de app zonder bezwaar accepteert.
4. Stel eventueel een vervaldatum in voor het einde van het project.
5. Kopieer de deellink. Die ziet eruit als `https://cloud.example.org/s/AbCdEf123456`.

De app zet die link zelf om in het WebDAV-eindpunt van de deellink; deelnemers zien nooit een WebDAV-adres. Een File Drop overschrijft nooit: wanneer een deelnemer dezelfde Session opnieuw uploadt, bewaart Nextcloud de oudere kopie onder een genummerde naam, zodat het nieuwste bestand het bestand zonder nummer is.

Nextcloud-deellinks met de rechten **uploaden en bewerken** werken ook, maar de app waarschuwt deelnemers dan dat de inloggegevens de map kunnen opsommen, omdat iedereen met de link dan de gegevens van alle anderen kan lezen. Deellinks met alleen leesrechten worden door de verbindingstest geweigerd.

### Optie B: je eigen WebDAV-map

Elke WebDAV-server werkt: een map in een persoonlijk cloudaccount, een institutionele bestandsserver, ownCloud of Nextcloud met een gewoon account. Deelnemers voeren bij het deelnemen het adres plus een gebruikersnaam en wachtwoord in onder **Geavanceerd**. Gebruik voor een Nextcloud- of ownCloud-account een **app-wachtwoord** uit de beveiligingsinstellingen van het account, nooit het inlogwachtwoord; is alleen een hostnaam opgegeven, dan probeert de app ook de gebruikelijke Nextcloud- en ownCloud-locaties op die host.

Zulke inloggegevens kunnen de map meestal lezen, dus de verbindingstest toont een waarschuwing. Geef de voorkeur aan een opzet met alleen schrijfrechten wanneer niet alle deelnemers tot één team behoren.

### Optie C: de referentie-dropserver

`tools/webdav_drop_server` in de broncoderepository is een kleine Python-server met tokens per deelnemer die je kunt intrekken, een opdracht `collect` die elk geüpload JSON-record samenvoegt tot `sessions.csv`, `detections.csv` en `species_summary.csv`, en een opdracht `invite` die een deelnamelink en QR-code afdrukt. Installatie en uitrol staan beschreven in de [Developer Guide](../developer/upload-drop-server.md).

### De deelnamelink en QR-code maken

Een deelnamelink bevat alles wat een deelnemer nodig heeft in één geheel: de bestemming, de inloggegevens, een projectnaam en de standaardwaarden die jij voorstelt. Open de [deelnamepagina](../join.md) op deze site en vul in:

- **Share link or WebDAV address**: de Nextcloud-deellink van hierboven, of het adres van de WebDAV-map.
- **User name**: laat leeg voor een Nextcloud-deellink.
- **Share password or token**: het wachtwoord van de deellink, of het geheim van het account of token.
- **Project name shown in the app**: wat deelnemers als naam van de bestemming te zien krijgen. Ze kunnen die wijzigen, maar dit is de standaard.
- **Suggest including audio** en **Suggest Wi-Fi only**: de standaardwaarden voor de schakelaars van de bestemming.

Druk op **Build link and QR code**. Alles gebeurt in je browser; er wordt niets ergens naartoe gestuurd. Het geheim staat in het deel van de link na `#`, dat browsers nooit doorsturen naar de webserver die de pagina host.

Je kunt ook eerst zelf op je eigen telefoon aan de bestemming deelnemen (zie hieronder), daarna de bestemming openen onder **Instellingen → Export & synchronisatie → Uploadbestemmingen** en op **Deelnamecode tonen** tikken. De app toont dan dezelfde soort QR-code met een knop **Link kopiëren**.

### Uitdelen

Druk de QR-code af op het veldformulier, toon hem op een scherm tijdens de briefing of stuur de link per bericht. **Behandel de link en de code als een wachtwoord**: iedereen die hem heeft, kan naar je project uploaden. Lekt hij uit, wijzig dan het wachtwoord van de deellink of trek het token in en deel een nieuwe code uit.

Wanneer een deelnemer de code met de camera van de telefoon scant, opent de browser een kleine landingspagina met een knop **Open in BirdNET Live**, die uitkomt op het scherm Bestemming toevoegen van de app met de link al ingevuld. De link rechtstreeks in dat scherm plakken werkt precies hetzelfde.

### Wat je te zien krijgt

Eén map per apparaat, één ZIP per Session en de verborgen `.birdnet-live`-registraties. Open een ZIP en je vindt het JSON-record (altijd aanwezig) en de tabellen, het rapport en de audio die de deelnemer heeft meegestuurd. Wil je weten welke persoon achter een upload-id zit, lees dan het registratiebestand voor die code of het veld `meta.participant` in een van de bijbehorende JSON-records. Bij de referentie-dropserver doet `collect` dit voor je en schrijft het een kolom `participant`.

## Voor deelnemers

### Deelnemen aan een bestemming

1. Open **Instellingen → Export & synchronisatie → Uploadbestemmingen** en tik op **Bestemming toevoegen**. De QR-code van een project met je camera scannen, of op een ontvangen deelnamelink tikken, brengt je naar hetzelfde scherm met de link al ingevuld.
2. Plak de deelnamelink, de Nextcloud-deellink of een WebDAV-adres in **Deelnamelink of serveradres**. De knop **Plakken** haalt hem van het klembord.
3. Vul eventueel een **Deelnemer-id, naam of e-mail (optioneel)** in. Die wordt bij elke upload opgeslagen zodat de projectleider weet van wie die komt, en verschijnt nooit in mapnamen. Onder het veld toont de app **Je upload-id**, de map waarin je uploads terechtkomen.
4. Open bij een gewoon WebDAV-adres **Geavanceerd** en vul de **Gebruikersnaam** en het **Wachtwoord of token** in. Een Nextcloud-deellink heeft geen van beide nodig; heeft de deellink een wachtwoord, vul dat dan in als wachtwoord.
5. Tik op **Verbinding testen**. De app neemt contact op met de server, maakt de verborgen registratiemap aan, controleert of de inloggegevens de map kunnen opsommen en schrijft je registratiebestand. Het resultaat is één zin: **Verbinding werkt**, een waarschuwing die je moet lezen, of een fout met de waarschijnlijke oplossing.
6. Geef de bestemming een **Naam van de bestemming** (vooraf ingevuld vanuit de deelnamelink), kies of je **Alleen uploaden via wifi** wilt, en tik op **Bestemming opslaan**.

Er wordt niets opgeslagen voordat de test is geslaagd. De inloggegevens gaan naar de sleutelhanger van het apparaat, nooit naar geëxporteerde gegevens.

Waarschuwingen die het begrijpen waard zijn:

- **Met deze inloggegevens kan de bestemming worden opgesomd** betekent dat de deellink of het account de gegevens van andere deelnemers kan lezen. Uploads werken, maar vraag de projectleider om een File Drop of een token met alleen schrijfrechten als er mensen van buiten je team aan het project meedoen.
- **Deze deellink heeft geen wachtwoord en kan worden opgesomd** combineert beide risico's: iedereen met de link kan alles lezen. Vraag de projectleider een wachtwoord in te stellen of een File Drop te gebruiken.
- **Deze server staat geen mappen toe** is informatief: uploads gebruiken platte bestandsnamen zoals `4ee91c8f__BirdNET_Live_….zip` in plaats van een map.

### Het scherm van de bestemming

Tik je op een bestemming in de lijst, dan opent haar scherm met het serveradres, wanneer ze is toegevoegd en voor het laatst gebruikt, en deze bediening:

- **Naam wijzigen** (het potlood in de app-balk) wijzigt de naam die in de app wordt getoond.
- **Alleen uploaden via wifi** houdt uploads vast zolang de telefoon op mobiele data zit.
- **Alle Sessions automatisch uploaden** zet elke afgeronde Session uit elke modus zonder vragen voor deze bestemming in de wachtrij, met de standaardwaarden voor Audio en Metagegevens uit Export & synchronisatie. Zolang dit aanstaat, blijft ook **ARU-Sessions automatisch uploaden** aan. Verwijder je daarna een Session in Session Review, dan vervalt een upload die nog niet is begonnen, maar wat al is verzonden blijft op de server.
- **ARU-Sessions automatisch uploaden** zet elke afgeronde ARU Session zonder vragen voor deze bestemming in de wachtrij (zie hieronder).
- **Verbinding testen** herhaalt de verbindingstest, bijvoorbeeld nadat de projectleider het wachtwoord heeft gewijzigd.
- **Deelnamecode tonen** toont een QR-code plus **Link kopiëren**, zodat een tweede telefoon aan dezelfde bestemming kan deelnemen.
- **Bestemming verwijderen** vergeet de bestemming en haar inloggegevens en laat wachtende uploads ernaar vervallen. Al geüploade Sessions blijven op de server.

Het eerste item in de lijst met bestemmingen is **Je upload-id**, met de deelnemer-id eronder; tik erop om de id te wijzigen. Die wijzigen verplaatst niets op de server, omdat mappen naar de id zijn genoemd.

### Een Session uploaden

Uploads beginnen vanuit dezelfde actie **Delen** die je al gebruikt, op drie plekken:

- het **menu met drie punten** (:app-moreVert:) van een Session-kaart in de Session-bibliotheek;
- de knop **Delen** na het selecteren van meerdere Sessions in de Session-bibliotheek;
- het pictogram **Delen** (:app-share:) in de werkbalk van het Session-overzicht.

Zodra er minstens één bestemming bestaat, heeft het venster Delen twee tabbladen:

- **Inhoud** bepaalt wat de export bevat: **Audio** (de volledige opname, of de detectiefragmenten als alleen fragmenten zijn bewaard) en **Metagegevens** (de tabellen, het rapport en het bestand met app-metadata die onder Export & synchronisatie aanstaan). De vakjes volgen bij het openen je instellingen en gelden alleen voor deze share.
- **Versturen naar** toont **Deelvenster** (andere apps, bestanden, berichten) en één vakje per bestemming. De badge op het tabblad telt de aangevinkte bestemmingen. De bestemmingen die je de vorige keer hebt aangevinkt staan al aan, behalve die waarnaar deze Session al is gestuurd: die beginnen uitgevinkt en tonen **Geüpload** met de datum en **Vink aan om opnieuw te uploaden**. Bij het openen van het venster controleert de app stilletjes elke bestemming; meldt de server dat hij de upload zou weigeren, bijvoorbeeld omdat het wachtwoord is gewijzigd of de deellink is verwijderd, dan kleurt de rij rood met de reden.

Vink **Deelvenster** uit en de knop heet **Uploaden**; staan beide aan, dan heet hij **Delen en uploaden**. Een snackbar bevestigt hoeveel Sessions in de wachtrij zijn gezet. Een Session gaat altijd eerst de wachtrij in en wordt op de achtergrond geüpload, zodat je verder kunt werken.

### Een upload volgen

De Session-kaart in de Session-bibliotheek toont de status als eerste regel onder de Session-titel: **In de wachtrij**, **Wacht op wifi**, **Wacht op een netwerk**, **Bezig met uploaden…**, **Geüpload** met de datum, of een fout. Tik op de regel voor de lijst per bestemming met **Nu opnieuw proberen** en **Uit de wachtrij halen**. Het Session-overzicht toont dezelfde status als wolkpictogram in de app-balk; erop tikken opent dezelfde lijst.

Mislukte uploads proberen het uit zichzelf opnieuw met oplopende wachttijden, tot zes uur uit elkaar, en maximaal dertig pogingen. **Mislukt, wordt opnieuw geprobeerd** betekent dat de app het opnieuw zal proberen. **Upload mislukt. Controleer de instellingen van de bestemming.** betekent dat de server heeft geweigerd en een nieuwe poging niet helpt: het wachtwoord is gewijzigd, uploads zijn uitgezet of de bestemming is verwijderd. Open de bestemming, voer **Verbinding testen** uit, en verwijder haar en voeg haar opnieuw toe als de inloggegevens zijn gewijzigd.

De regel en het pictogram verschijnen alleen zolang minstens één bestemming waarnaar de Session is gestuurd nog in Instellingen bestaat. Verwijder de bestemming en ze verdwijnen, omdat "geüpload" dan geen feit meer is over een bestemming die je hebt.

### Wat er op de achtergrond draait

Uploads in de wachtrij lopen terwijl de app open is en telkens wanneer die naar de voorgrond terugkeert. Op Android lopen ze ook met de app gesloten: het systeem start ze zodra een geschikt netwerk beschikbaar is, wifi als de bestemming daarom vraagt, en blijft het opnieuw proberen tot de wachtrij leeg is. Op iOS lopen uploads terwijl de app open is.

### Een Session opnieuw uploaden

Dezelfde Session opnieuw uploaden, bijvoorbeeld na het corrigeren van detecties in het Session-overzicht, schrijft dezelfde bestandsnaam naar dezelfde map. Servers die dat toestaan vervangen het bestand; een Nextcloud File Drop bewaart in plaats daarvan de oudere kopie onder een genummerde naam. In beide gevallen krijgt de projectleider de nieuwste versie, en er wordt niets verwijderd.

## ARU-modus

Veldinzetten leveren veel Sessions op, vaak terwijl er niemand bij de telefoon is. Zet **ARU-Sessions automatisch uploaden** aan bij een bestemming, en elke afgeronde ARU Session wordt er zonder venster voor in de wachtrij gezet, met de standaardwaarden voor Audio en Metagegevens uit Export & synchronisatie. Een inzet die elke cyclus als eigen Session opslaat, uploadt cyclus voor cyclus; de gecombineerde inzet-Session wordt niet dubbel geüpload.

Laat **Alleen uploaden via wifi** aanstaan voor een station op een mobiel abonnement, tenzij het abonnement de audio aankan, en overweeg op te nemen met **Alleen detecties** of **Uit** wanneer de audio te groot zou zijn om te versturen. De uploads stromen dan weg zodra de telefoon een geschikt netwerk ziet, ook terwijl de app op Android op de achtergrond staat.

## Twee uitgewerkte voorbeelden

### Een weekend-Survey met een Nextcloud File Drop

De projectleider maakt een map `Birdathon 2027` in de Nextcloud van de universiteit, deelt die als File Drop met een wachtwoord, plakt de deellink en het wachtwoord in de deelnamepagina, geeft het project een naam en drukt de QR-code af op het briefingformulier. Twintig vrijwilligers scannen hem op zaterdagochtend, vullen hun naam in als deelnemer-id, doorstaan de verbindingstest en slaan op.

Op zondagavond opent elke vrijwilliger de Session-bibliotheek, selecteert de Sessions van het weekend, tikt op Delen, laat het project aangevinkt onder Versturen naar en tikt op **Uploaden**. De uploads wachten thuis op wifi en zijn 's nachts klaar. Op maandag vindt de projectleider twintig mappen genoemd naar upload-id, elk met een handvol ZIP's, en leest de namen van de vrijwilligers uit de verborgen registratiebestanden of het veld `meta.participant` in de JSON-records.

### Correcties in het Session-overzicht, daarna een ARU-station

Een deelnemer kijkt een Session na, verwijdert twee valse detecties, voegt met de hand een soort toe en slaat op. Het wolkpictogram in de app-balk van het Session-overzicht laat zien dat de Session op zaterdag is geüpload. Ze tikken op het pictogram Delen in de werkbalk, vinken het project aan onder Versturen naar, waar het uitgevinkt begint en **Geüpload** met de datum toont, en drukken op **Uploaden**. De gecorrigeerde ZIP vervangt de eerdere, of komt er op een File Drop naast te staan met een genummerde naam.

Dezelfde deelnemer laat een telefoon als ARU-station achter bij een rietveld met een wifi-hotspot in de hut. Ze nemen op die telefoon deel aan de projectbestemming, zetten **ARU-Sessions automatisch uploaden** aan en laten **Alleen uploaden via wifi** aanstaan. Elke ochtend worden de afgeronde nachtcycli in de wachtrij gezet en geüpload terwijl het station stilstaat; de projectleider ziet nieuwe ZIP's verschijnen onder de upload-id van die telefoon zonder dat iemand hem aanraakt.

## Privacy en verantwoordelijkheid

Uploadbestemmingen worden beheerd door projectorganisatoren, niet door BirdNET-Team. De map, de server, wie die kan lezen en hoe lang de gegevens worden bewaard, vallen onder de eigen privacy- en beveiligingsregels van de organisator; vraag die om details voordat je deelneemt. BirdNET Live schrijft alleen wat jij hebt gekozen te versturen en bewaart de inloggegevens in de sleutelhanger van je apparaat.

Een upload bevat wat een share zou bevatten: het JSON-record van de Session met detecties, tijden, coördinaten, de naam van de waarnemer en de locatienaam als die zijn ingesteld, de upload-id van het apparaat, de deelnemer-id die je hebt ingevuld en de app-versie; plus de audio, tabellen en het rapport die je hebt aangevinkt. Controleer het tabblad Inhoud voordat je verstuurt, en laat audio weg wanneer een opname stemmen kan bevatten of iets anders wat je niet aan het project zou geven. **Je bent zelf verantwoordelijk voor wat je uploadt.** Upload of deel geen gegevens die je als privé of vertrouwelijk beschouwt, en upload geen opnamen die je niet mag doorgeven.

## Probleemoplossing

| Melding | Wat die betekent | Wat je kunt doen |
| --- | --- | --- |
| Dit lijkt niet op een link of serveradres. | De tekst is geen URL. | Plak de volledige deelnamelink, deellink of het `https://`-adres. |
| De server weigerde de inloggegevens. | Verkeerd of ontbrekend wachtwoord, of een verwijderde deellink. Nextcloud antwoordt zo ook bij verwijderde deellinks. | Gebruik het wachtwoord van de deellink of een app-wachtwoord; vraag de projectleider of de deellink nog bestaat. |
| Dit adres is geen WebDAV-eindpunt. | Je hebt de webpagina van een map geplakt, geen deellink of WebDAV-adres. | Plak de deellink (`…/s/…`) of het WebDAV-adres. |
| Uploaden is hier niet toegestaan. | De deellink heeft alleen leesrechten. | Vraag de projectleider om een File Drop of uploadrechten. |
| De map bestaat niet op de server. | Het adres wijst nergens naar, of de map is verwijderd. | Controleer het adres bij de projectleider. |
| Het certificaat van de server kon niet worden geverifieerd. | Zelfondertekende of defecte TLS. | Vraag de projectleider om een adres met een geldig certificaat. |
| Dit adres gebruikt onversleuteld HTTP. | Onversleutelde verbinding buiten je lokale netwerk. | Gebruik een `https://`-adres. |
| Wacht op wifi | De bestemming staat op alleen wifi en de telefoon zit op mobiele data. | Wacht, of zet de wifi-schakelaar van de bestemming uit. |
| Mislukt, wordt opnieuw geprobeerd | Een tijdelijk probleem zoals een weggevallen verbinding of een serverfout. | Niets; de app probeert het uit zichzelf opnieuw. **Nu opnieuw proberen** dwingt een poging af. |
| Upload mislukt. Controleer de instellingen van de bestemming. | De server heeft geweigerd om een reden die een nieuwe poging niet oplost. | Open de bestemming, voer **Verbinding testen** uit, en verwijder haar en voeg haar opnieuw toe als de inloggegevens zijn gewijzigd. |
| De inloggegevens voor deze bestemming ontbreken in de sleutelhanger van het apparaat. | De sleutelhangervermelding is verloren gegaan, bijvoorbeeld na een herstel naar een nieuwe telefoon. | Verwijder de bestemming en voeg haar opnieuw toe. |

Zie ook de instelling [Uploadbestemmingen](settings.md#uploadbestemmingen) en de handleidingen [Session-bibliotheek](session-library.md) en [Session-overzicht](session-review.md).
