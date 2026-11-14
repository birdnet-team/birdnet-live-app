# Přehled Session

V Přehledu Session mění BirdNET Live detekce na upravitelný záznam.

## Jak se sem dostanete

BirdNET Live otevře Přehled Session automaticky po dokončení:

- Live Session
- Point Count
- Survey
- běhu Analýzy souborů

Kteroukoli uloženou Session můžete také znovu otevřít z [Knihovny Sessions](session-library.md).

## Hlavní oblasti

### Souhrn a přehrávání

Přehled Session kombinuje přehrávání, navigaci ve spektrogramu a seznam druhů. U Sessions Survey může také zobrazit kontext na mapě.

Souhrnné záhlaví v horní části obrazovky nese datum, čip polohy (zeměpisná šířka/délka a volitelně rozpoznaný název místa, je-li zapnuto **Nastavení → Soukromí → Povolit vyhledávání názvů míst**) a — pokud bylo v době nahrávání zapnuto **Nastavení → Soukromí → Povolit načítání počasí** — **řádek počasí** pod polohou s podmínkami zaznamenanými na konci Session: jednořádkový údaj jako *„20,1 °C · Slabý déšť · 3,2 m/s JZ“* uvozený ikonou počasí. Klepnutím na řádek rozbalíte malý panel s teplotou, větrem, srážkami a oblačností a uvedením zdroje Open-Meteo. Stejný snímek se promítne do exportu JSON, bloku metadat Session i do HTML reportu.

Pruh spektrogramu nad přehrávačem je interaktivní: klepnutím přejdete na pozici, tažením jedním prstem posouváte časovou osu a **roztažením dvou prstů přiblížíte** úzké časové okno — užitečné, když chcete prozkoumat načasování překrývajících se hlasů nebo rozebrat rychlý trylek. Stažením prstů zpět se vrátíte k výchozímu desetisekundovému přehledu. Tlačítko přehrávání u záhlaví druhu vždy vybere první shluk, který má skutečně nahraný klip, takže tlačítko je dostupné, kdykoli je některá z detekcí daného druhu přehratelná.

### Seznam druhů

Druhy jsou seskupené do rozbalitelných řádků. Detekce můžete procházet podle druhu a zároveň se při kontrole pohybovat nahrávkou. Řádky shluků pod rozbaleným druhem jsou odsazené, aby karta nadřazeného druhu zůstala vizuálně odlišená od svých potomků.

Vyhledávací pole nad seznamem filtruje druhy podle běžného nebo vědeckého názvu, takže nalezení jednoho konkrétního ptáka v Session se 100 druhy je otázkou několika úhozů místo dlouhého posouvání. Tlačítko :app-sort: vedle něj mění pořadí druhů:

- **Nejvyšší spolehlivost** (výchozí) — nejprve druhy s nejvyšší spolehlivostí jednotlivé detekce. Vhodné pro třídění nejjistějších identifikací. Když v tomto režimu druh rozbalíte, detekce s přehratelnými zvukovými klipy se zobrazí před detekcemi bez klipu a poté podle spolehlivosti.
- **Nejvíce detekcí** — nejprve druhy s nejvyšším počtem detekcí. Vhodné pro odhalení dominantních zpěváků.
- **A → Z** — abecedně podle běžného názvu. Předvídatelné, respektuje jazyk a snadno se prochází, jakmile Session obsahuje hodně druhů.
- **Nejdříve detekované** — chronologicky podle času první detekce. Původní výchozí volba; užitečná při kontrole spolu s časovou osou spektrogramu.

Zvolené řazení se zachová napříč Sessions.

### Ruční přidání druhu

Tlačítko :app-addCircleOutline: na panelu nástrojů otevře vyhledávání druhů pro ptáky, které BirdNET nezachytil. Klepnutí na výsledek druh hned nevloží — nejprve vyjede potvrzovací panel s vybraným druhem a dvěma zaškrtávacími políčky:

- :app-hearing: **Slyšeno** — ptáka jste slyšeli.
- :app-visibility: **Viděno** — ptáka jste viděli.

Zaškrtněte jedno, obě, nebo žádné a poté klepněte na **Přidat**. Tlačítko **Zrušit** (nebo přejetí dolů) vás vrátí zpět do vyhledávání, takže omyl nic nestojí. **Slyšeno** je zaškrtnuto ve výchozím stavu a volba se přenese i na další přidávaný druh — sérii jen viděných ptáků tak zaškrtnete jednou. Necháte-li obě prázdná, záznam se uloží bez typu pozorování — nikoli jako „ani jedno“.

Volba se uloží k detekci a zobrazí se jako malá ikona ucha a/nebo oka vedle odznaku ručního zadání všude, kde se detekce objeví: v hlavičkách druhů, v řádcích shluků, v přehrávači klipů i v živém seznamu Survey. Putuje také do exportů: sloupec `Evidence` v CSV a v tabulkách Raven, pole `evidence` v JSON a štítek v HTML reportu. Stejný panel se zobrazí i u akce **Nahradit druh**, předvyplněný podle toho, co záznam už nesl.

### Akce u jednotlivých detekcí

Všude, kde se detekce objeví — v seznamu druhů, v panelu přehrávače klipu, v živém seznamu Survey i u značek na mapě Survey — se používá stejná sada akcí:

- :app-checkCircleOutline: **Potvrdit** — zaškrtnutí jedním klepnutím přímo v řádku, které označí detekci jako vizuálně či akusticky ověřenou. Potvrzené shluky a značky mapy získají malé zelené zaškrtnutí, takže na první pohled vyniknou, a tento příznak putuje do každého exportního formátu.
- :app-moreVert: **Více** — otevře nabídku dalších akcí s položkami:
    - :app-share: **Sdílet detekci** — viz *Sdílení* níže.
    - :app-swapHoriz: **Nahradit druh** — zvolí pro tuto detekci jiný druh.
    - :app-deleteOutline: **Smazat detekci** — okamžitě odebere řádek. Na pár sekund se objeví SnackBar s možností vrácení, takže omyly lze vrátit. Bez potvrzovacího dialogu.
    - :app-deleteSweep: **Smazat druh** — odebere ze Session všechny detekce daného druhu naráz, se stejným vrácením přes SnackBar. Užitečné pro odstranění chybně identifikovaného zdroje hluku, aniž byste museli druh rozbalovat a mazat shluky jeden po druhém.

#### Zkratky přejetím na řádcích přehledu

V seznamu druhů můžete s detekcí pracovat také přejetím řádku vodorovně:

- přejetí **doprava** → smazání (s možností vrácení)
- přejetí **doleva** → otevření překryvného panelu pro nahrazení druhu

Obě pozadí jsou barevně odlišená (chybová červená vs. primární modrá), takže účinek gesta je zřejmý dřív, než jej potvrdíte.

Přejetí řádku **záhlaví druhu** (doleva nebo doprava) smaže všechny detekce daného druhu naráz, se stejným vrácením přes SnackBar. Užitečné při třídění Session plné chybně identifikovaného hluku.

### Sdílení jedné detekce

Položka :app-share: **Sdílet detekci** používá stejné volby jako **Nastavení → Export a synchronizace**. Exportuje pouze tuto detekci ve zvolených artefaktech Raven, CSV, JSON, GPX, HTML a metadatech aplikace. Když je zapnuté **Zahrnout zvukové soubory**, balíček obsahuje i zvuk detekce; volba **Vždy sdílet zvuk jako WAV** je dodržena. Když jsou všechny doprovodné formáty, HTML i metadata aplikace vypnuté, systémová nabídka sdílení dostane nezabalený zvukový klip místo ZIP.

Zvuková příloha se vyhledává v tomto pořadí:

1. **U Sessions nahrávajících jeden souvislý soubor**: z nahrávky se za běhu vyřízne zvuk od počáteční po koncovou časovou značku detekce. Podporovány jsou souvislé nahrávky WAV i FLAC; komprimované zdroje z Analýzy souborů se dekódují jako WAV.
2. Jinak se použije vlastní uložený klip detekce, pokud je na disku.
3. Pokud není dostupný žádný zdroj zvuku a není vybrán žádný exportní artefakt, sdílení přejde na stručný text s druhem, spolehlivostí, časovou značkou UTC a polohou.

### Hlasové poznámky

K jednotlivým záznamům detekce můžete připojit krátké mluvené hlasové komentáře:

- **Nahrát**: Klepnutím na tlačítko :app-moreVert: u shluku detekcí a výběrem možnosti **Nahrát hlasovou poznámku** otevřete dialog hlasové poznámky. Klepnutím na velké tlačítko mikrofonu spustíte nahrávání. Živá křivka zobrazuje váš hlas v reálném čase. Po dokončení klepněte na tlačítko zastavení.
- **Zkontrolovat**: Po nahrání si poznámku poslechnete v integrovaném přehrávači. Chcete-li poznámku nahradit, klepněte na tlačítko **Nahrát znovu**. Chcete-li ji uložit, klepněte na tlačítko **Uložit**.
- **Smazat**: Pokud detekce již obsahuje hlasovou poznámku, můžete ji smazat z nabídky dalších akcí nebo z dialogu hlasové poznámky.
- **Formáty podle platformy**: Na Androidu a dalších platformách se hlasové poznámky nahrávají ve výrazně komprimovaném formátu AAC (`.m4a`) na 16 kHz. Na iOS automaticky používají formát WAV/PCM16 (`.wav`), aby se předešlo problémům s kompatibilitou CoreAudio s aktivními zvukovými relacemi aplikace. Oba formáty jsou plně podporovány při balení exportu do ZIP.
- **Export**: Při exportu Session jako ZIP se hlasové poznámky zabalí do adresáře `memos/` a jejich relativní cesty se zaznamenají do metadat JSON a CSV.

### Mapa trasy Survey

Sessions Survey zobrazují malou vloženou mapu GPS trasy a značek detekcí. Klepnutím na značku ve vložené mapě zaměříte detekci — vložená mapa se na ni vystředí. Klepnutím na tlačítko :app-fullscreen: **rozbalit** (vpravo nahoře ve vložené mapě) otevřete **celoobrazovkovou mapu**; pokud byla detekce zaměřena, celoobrazovková mapa se otevře vystředěná a přiblížená na tuto detekci, takže neztratíte pozici.

#### Kódování značek

- **Spolehlivost je barevně kódovaná** přechodem bezpečným pro barvoslepé: od nízké k vysoké spolehlivosti běží od fialovo-modré přes tyrkysovou/žlutou po červenou. Světlost přechodu se mění monotónně, takže zůstává čitelná v odstínech šedi i pro uživatele s poruchou rozlišení červené a zelené.
- **Detekce se zvukem** ukazují barevný prstenec kolem fotografie druhu a v rohu odznak přehrávání — klepnutím otevřete stejný panel přehrávače klipu jako jinde, s dostupným potvrzením, sdílením, nahrazením i smazáním.
- **Tiché detekce** (bez klipu na disku) se vykreslují menší, vybledlé a s neutrálně šedým prstencem, aby zvukové detekce vždy působily jako hlavní obsah.
- **Překrývající se značky na stejném místě** jsou řazené podle důležitosti: zvýrazněná > se zvukem > vyšší spolehlivost, takže tichá značka s nízkou spolehlivostí nikdy nezakryje silnou zvukovou detekci.
- **Pod přiblížením 14,5** se siluety zjednoduší na barevné body s velikostí podle spolehlivosti a husté shluky se sloučí do bubliny s počtem (shlukování se vypne při přiblížení 15).

#### Filtrování

Celoobrazovková mapa má trvalý **filtrovací čip** ukotvený vpravo nahoře. Klepnutím na něj otevřete panel filtru; štítek čipu vždy ukazuje, co je právě v platnosti (*„Všechny druhy“*, *„Se zvukovým klipem“*, *„≥ 80 %“* nebo název jednoho druhu). Dostupné filtry:

- **Všechny detekce** (výchozí).
- **Se zvukovým klipem** — pouze detekce, jejichž klip je stále na disku a přehratelný.
- **Ručně přidané** — pouze detekce, které jste přidali v Přehledu Session (vylučuje automaticky detekované).

Detekce můžete také omezit podle úrovně spolehlivosti. Posuvník nastavuje dolní mez spolehlivosti (začíná na 10 %).

Pod posuvníkem spolehlivosti je výběr **Omezit na druh**, který umožní zúžit mapu na jediný druh — užitečné při otázce „kde přesně podél trasy jsem slyšel drozda?“. Položka *Všechny druhy* omezení druhu zruší. Filtry se kombinují: např. *Se zvukovým klipem* + *Drozd lesní* + *> 80 %* zobrazí pouze přehratelné značky drozda lesního se skóre nad 80 %.

Když je filtr aktivní, název v horní liště získá podtitul s počtem shod (např. *„7 detekcí“*). *Resetovat* v panelu vrátí výchozí stav.

## Ikony panelu nástrojů

Panel nástrojů používá stejné významy ikon, jaké popisují [Ikony a ovládací prvky](icons-and-controls.md):

- :app-addCircleOutline: — přidat obsah
- :app-undo: / :app-redo: — krok mezi úpravami
- :app-contentCut: — režim oříznutí
- :app-save: — uložit úpravy
- :app-share: — exportovat nebo sdílet
- :app-deleteOutline: — zahodit Session
- :app-playArrowRounded: — pokračovat v Survey, je-li tato akce dostupná
- :app-helpOutlineRounded: — otevřít panel nápovědy Přehledu Session
- :app-tuneRounded: — otevřít Nastavení

## Typické úkoly při kontrole

- ověření detekcí oproti přehrávání a kontextu spektrogramu
- přidání druhu nebo poznámky
- oříznutí nahrávky na užitečný interval
- export zkontrolované sady výsledků

## Export

Chování exportu závisí na možnostech zvolených v [Nastavení](settings.md). Aplikace umí do zvoleného exportního formátu zabalit detekce a volitelně i zvuk. Každý export obsahuje metadata o původu — verzi aplikace, název a verzi modelu, verzi taxonomie, jazyk názvů druhů, časovou značku exportu, nastavení uchovaná se Session a relevantní možnosti exportu — zapsaná do vedlejšího souboru `<prefix>.metadata.json` (ZIP) nebo do bloku `meta` na nejvyšší úrovni (JSON), takže exporty jsou sebepopisné a reprodukovatelné.

Každá exportovaná detekce nese také BirdNET ID svého druhu (například `BN07148`), tedy identifikátor druhu v taxonomii BirdNET: sloupec `BirdNET ID` hned za `Scientific Name` v CSV a v tabulkách Raven, pole `birdnetId` v JSON, rozšíření bodu v GPX a údaj na kartě druhu v HTML reportu. ID se dohledává až při exportu, takže ho dostanou i Sessions nahrané staršími verzemi aplikace, a to i tehdy, když se vědecký název mezitím změnil. U položek, které taxonomie nezná, například u druhu, který jste zadali sami, zůstává prázdné. ID má smysl jen spolu s verzí taxonomie, kterou metadata uvádějí pod `taxonomy`.

Pokud zařízení s polohou GPS dodá nadmořskou výšku, exporty zahrnou výšku v metrech, dostupnou vertikální přesnost, referenční povrch a čas určení polohy. JSON obsahuje vše u příslušných souřadnic a GPX u bodů trasy Survey a bodů detekcí. CSV a Raven přidávají pouze sloupec `Altitude (m)` vedle zeměpisné šířky a délky. Ručně zadané a na mapě vybrané souřadnice nemají odvozenou výšku. Detekce přidaná v přehledu Survey k určitému času dostane polohu interpolovanou mezi okolními body trasy, bez vlastního času určení polohy. Zařízení mohou používat různé referenční povrchy; před porovnáním ověřte exportované pole `altitudeReference`. Hodnota `unknown` znamená, že platforma povrch neurčila.

Blok `settings` v exportu JSON zaznamenává hodnoty, které byly *skutečně použity na tuto Session* — citlivost, režim a počet oken sdružování skóre, zesílení mikrofonu a frekvenci horní propusti — nikoli to, co je zrovna nastaveno v Nastavení teď. Díky tomu lze výsledek reprodukovat i po měsících nebo porovnat dvě Survey, aniž byste si museli pamatovat, kde byly které posuvníky při jejich pořízení.

Všechny časové značky v názvech exportovaných souborů (`BirdNET_Live_<date>_<time>_…`) i uvnitř obsahu CSV / JSON jsou formátovány v *aktuálním* místním čase vašeho telefonu. Podkladové záznamy se ukládají v UTC a při exportu se převádějí.
