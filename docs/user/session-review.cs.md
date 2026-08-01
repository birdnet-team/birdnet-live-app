# Přehled Session

V Přehledu Session mění BirdNET Live detekce na upravitelný záznam.

## Jak se sem dostanete

BirdNET Live otevře Přehled Session automaticky po dokončení:

- Live session
- Point Count
- Survey
- běhu Analýzy souborů

Kteroukoli uloženou session můžete také znovu otevřít z [Knihovny Sessions](session-library.md).

## Hlavní oblasti

### Souhrn a přehrávání

Přehled Session kombinuje přehrávání, navigaci ve spektrogramu a seznam druhů. U sessions Survey může také zobrazit kontext na mapě.

Souhrnné záhlaví v horní části obrazovky nese datum, čip polohy (zeměpisná šířka/délka a volitelně rozpoznaný název místa, je-li zapnuto **Nastavení → Soukromí → Povolit vyhledání názvu místa**) a — pokud bylo v době nahrávání zapnuto **Nastavení → Soukromí → Povolit vyhledání počasí** — **řádek počasí** pod polohou s podmínkami zaznamenanými na konci session: jednořádkový údaj jako *„20,1 °C · Slabý déšť · 3,2 m/s JZ“* uvozený ikonou počasí. Klepnutím na řádek rozbalíte malý panel s teplotou, větrem, srážkami a oblačností a uvedením zdroje Open-Meteo. Stejný snímek se promítne do exportu JSON, bloku metadat session i do HTML reportu.

Pruh spektrogramu nad přehrávačem je interaktivní: klepnutím přejdete na pozici, tažením jedním prstem posouváte časovou osu a **stažením dvou prstů přiblížíte** úzké časové okno — užitečné, když chcete prozkoumat načasování překrývajících se hlasů nebo rozebrat rychlý trylek. Roztažením zpět se vrátíte k výchozímu desetisekundovému přehledu. Tlačítko přehrávání u záhlaví druhu vždy vybere první shluk, který má skutečně nahraný klip, takže tlačítko je dostupné, kdykoli je některá z detekcí daného druhu přehratelná.

### Seznam druhů

Druhy jsou seskupené do rozbalitelných řádků. Detekce můžete procházet podle druhu a zároveň se při kontrole pohybovat nahrávkou. Řádky shluků pod rozbaleným druhem jsou odsazené, aby karta nadřazeného druhu zůstala vizuálně odlišená od svých potomků.

Vyhledávací pole nad seznamem filtruje druhy podle běžného nebo vědeckého názvu, takže nalezení jednoho konkrétního ptáka v session se 100 druhy je otázkou několika úhozů místo dlouhého posouvání. Tlačítko :material-sort: vedle něj mění pořadí druhů:

- **Nejvyšší konfidence** (výchozí) — nejprve druhy s nejvyšší konfidencí jednotlivé detekce. Vhodné pro třídění nejjistějších identifikací. Když v tomto režimu druh rozbalíte, detekce s přehratelnými zvukovými klipy se zobrazí před detekcemi bez klipu a poté podle konfidence.
- **Nejvíce detekcí** — nejprve druhy s nejvyšším počtem detekcí. Vhodné pro odhalení dominantních zpěváků.
- **A → Z** — abecedně podle běžného názvu. Předvídatelné, respektuje jazyk a snadno se prochází, jakmile session obsahuje hodně druhů.
- **Nejprve zaznamenané** — chronologicky podle času první detekce. Původní výchozí volba; užitečná při kontrole spolu s časovou osou spektrogramu.

Zvolené řazení se zachová napříč sessions.

### Ruční přidání druhu

Tlačítko :material-plus-circle-outline: na panelu nástrojů otevře vyhledávání druhů pro ptáky, které BirdNET nezachytil. Klepnutí na výsledek druh hned nevloží — nejprve vyjede potvrzovací panel s vybraným druhem a dvěma zaškrtávacími políčky:

- :material-ear-hearing: **Slyšeno** — ptáka jste slyšeli.
- :material-eye: **Viděno** — ptáka jste viděli.

Zaškrtněte jedno, obě, nebo žádné a poté klepněte na **Přidat**. Tlačítko **Zrušit** (nebo přejetí dolů) vás vrátí zpět do vyhledávání, takže omyl nic nestojí. **Slyšeno** je zaškrtnuto ve výchozím stavu a volba se přenese i na další přidávaný druh — sérii jen viděných ptáků tak zaškrtnete jednou. Necháte-li obě prázdná, záznam se uloží bez typu pozorování — nikoli jako „ani jedno“.

Volba se uloží k detekci a zobrazí se jako malá ikona ucha a/nebo oka vedle odznaku ručního zadání všude, kde se detekce objeví: v hlavičkách druhů, v řádcích clusterů, v přehrávači klipů i v seznamu živého Survey. Putuje také do exportů: sloupec `Evidence` v CSV a v tabulkách Raven, pole `evidence` v JSON a štítek v HTML reportu. Stejný panel se zobrazí i u akce **Nahradit druh**, předvyplněný podle toho, co záznam už nesl.

### Akce u jednotlivých detekcí

Všude, kde se detekce objeví — v seznamu druhů, v panelu přehrávače klipu, v živém seznamu Survey i u značek na mapě Survey — se používá stejná sada akcí:

- :material-check: **Potvrdit** — zaškrtnutí jedním klepnutím přímo v řádku, které označí detekci jako vizuálně či akusticky ověřenou. Potvrzené shluky a značky mapy získají malé zelené zaškrtnutí, takže na první pohled vyniknou, a tento příznak putuje do každého exportního formátu.
- :material-dots-vertical: **Více** — otevře nabídku dalších akcí s položkami:
    - :material-share-variant: **Sdílet detekci** — viz *Sdílení* níže.
    - :material-swap-horizontal: **Nahradit druh** — zvolí pro tuto detekci jiný druh.
    - :material-delete-outline: **Smazat detekci** — okamžitě odebere řádek. Na pár sekund se objeví SnackBar s možností vrácení, takže omyly lze vrátit. Bez potvrzovacího dialogu.
    - :material-delete-sweep-outline: **Smazat druh** — odebere ze session všechny detekce daného druhu naráz, se stejným vrácením přes SnackBar. Užitečné pro odstranění chybně identifikovaného zdroje hluku, aniž byste museli druh rozbalovat a mazat shluky jeden po druhém.

#### Zkratky přejetím na řádcích přehledu

V seznamu druhů můžete s detekcí pracovat také přejetím řádku vodorovně:

- přejetí **doprava** → smazání (s možností vrácení)
- přejetí **doleva** → otevření překryvného panelu pro nahrazení druhu

Obě pozadí jsou barevně odlišená (chybová červená vs. primární modrá), takže účinek gesta je zřejmý dřív, než jej potvrdíte.

Přejetí řádku **záhlaví druhu** (doleva nebo doprava) smaže všechny detekce daného druhu naráz, se stejným vrácením přes SnackBar. Užitečné při třídění session plné chybně identifikovaného hluku.

### Sdílení jedné detekce

Položka :material-share-variant: **Sdílet detekci** otevře systémový panel sdílení se stručným obsahem vhodným pro terénní nástroje — běžný a vědecký název, konfidence, časová značka v UTC podle ISO 8601 a `geo:` URI, má-li detekce GPS — a připojí zvukový klip, kdykoli je k dispozici. Sdílený soubor se jmenuje `BirdNET_Live_<timestamp>_<species>.<ext>`, aby odpovídal schématu exportu do ZIP.

Zvuková příloha se vyhledává v tomto pořadí:

1. Vlastní klip detekce uložený na disku.
2. **U sessions nahrávajících jeden souvislý soubor**: příslušné zvukové okno se za běhu vyřízne z nahrávky. Podporovány jsou souvislé nahrávky ve WAV i FLAC a výřez se posílá ve stejném kontejneru jako zdroj (WAV dovnitř → WAV ven, FLAC dovnitř → FLAC ven).
3. Pokud není dostupné ani jedno, sdílení je pouze textové — poloha a časová značka se do obsahu dostanou i tak.

### Hlasové poznámky

K jednotlivým záznamům detekce můžete připojit krátké mluvené hlasové komentáře:

- **Nahrát**: Klepnutím na tlačítko :material-dots-vertical: u shluku detekcí a výběrem možnosti **Nahrát hlasovou poznámku** otevřete dialog hlasové poznámky. Klepnutím na velké tlačítko mikrofonu spustíte nahrávání. Živá křivka zobrazuje váš hlas v reálném čase. Po dokončení klepněte na tlačítko zastavení.
- **Zkontrolovat**: Po nahrání si poznámku poslechnete v integrovaném přehrávači. Chcete-li poznámku nahradit, klepněte na tlačítko **Nahrát znovu**. Chcete-li ji uložit, klepněte na tlačítko **Uložit**.
- **Smazat**: Pokud detekce již obsahuje hlasovou poznámku, můžete ji smazat z nabídky dalších akcí nebo z dialogu hlasové poznámky.
- **Formáty podle platformy**: Na Androidu a dalších platformách se hlasové poznámky nahrávají ve výrazně komprimovaném formátu AAC (`.m4a`) na 16 kHz. Na iOS automaticky používají formát WAV/PCM16 (`.wav`), aby se předešlo problémům s kompatibilitou CoreAudio s aktivními zvukovými sessions aplikace. Oba formáty jsou plně podporovány při balení exportu do ZIP.
- **Export**: Při exportu session jako ZIP se hlasové poznámky zabalí do adresáře `memos/` a jejich relativní cesty se zaznamenají do metadat JSON a CSV.

### Mapa trasy Survey

Sessions Survey zobrazují malou vloženou mapu GPS trasy a značek detekcí. Klepnutím na značku ve vložené mapě zaměříte detekci — vložená mapa se na ni vycentruje. Klepnutím na tlačítko :material-fullscreen: **rozbalit** (vpravo nahoře ve vložené mapě) otevřete **celoobrazovkovou mapu**; pokud byla detekce zaměřena, celoobrazovková mapa se otevře vycentrovaná a přiblížená na tuto detekci, takže neztratíte pozici.

#### Kódování značek

- **Konfidence je barevně kódovaná** přechodem bezpečným pro barvosleposti: od nízké k vysoké konfidenci běží od fialovo-modré přes tyrkysovou/žlutou po červenou. Světlost přechodu se mění monotónně, takže zůstává čitelná v odstínech šedi i pro uživatele s poruchou rozlišení červené a zelené.
- **Detekce se zvukem** ukazují barevný prstenec kolem fotografie druhu a v rohu odznak přehrávání — klepnutím otevřete stejný panel přehrávače klipu jako jinde, s dostupným potvrzením, sdílením, nahrazením i smazáním.
- **Tiché detekce** (bez klipu na disku) se vykreslují menší, vybledlé a s neutrálně šedým prstencem, aby zvukové detekce vždy působily jako hlavní obsah.
- **Překrývající se značky na stejném místě** jsou řazené podle důležitosti: zvýrazněná > se zvukem > vyšší konfidence, takže tichá značka s nízkou konfidencí nikdy nezakryje silnou zvukovou detekci.
- **Pod přiblížením 14,5** se siluety zjednoduší na barevné body s velikostí podle konfidence a husté shluky se sloučí do bubliny s počtem (shlukování se vypne při přiblížení 15).

#### Filtrování

Celoobrazovková mapa má trvalý **filtrovací čip** ukotvený vpravo nahoře. Klepnutím na něj otevřete panel filtru; štítek čipu vždy ukazuje, co je právě v platnosti (*„Všechny druhy“*, *„S audiozaznamem“*, *„≥ 80 %“* nebo název jednoho druhu). Dostupné filtry:

- **Všechny detekce** (výchozí).
- **S audiozaznamem** — pouze detekce, jejichž klip je stále na disku a přehratelný.
- **Ručně přidané** — pouze detekce, které jste přidali v Přehledu Session (vylučuje automaticky detekované).

Detekce můžete také omezit podle úrovně konfidence. Posuvník nastavuje dolní mez konfidence (začíná na 10 %).

Pod posuvníkem konfidence je výběr **Omezit na druh**, který umožní zúžit mapu na jediný druh — užitečné při otázce „kde přesně podél trasy jsem slyšel drozda?“. Položka *Všechny druhy* omezení druhu zruší. Filtry se kombinují: např. *S audiozaznamem* + *Drozd lesní* + *> 80 %* zobrazí pouze přehratelné značky drozda lesního se skóre nad 80 %.

Když je filtr aktivní, název v horní liště získá podtitul s počtem shod (např. *„7 detekcí“*). *Resetovat* v panelu vrátí výchozí stav.

## Ikony panelu nástrojů

Panel nástrojů používá stejné významy ikon, jaké popisují [Ikony a ovládací prvky](icons-and-controls.md):

- :material-plus-circle-outline: — přidat obsah
- :material-undo-variant: / :material-redo-variant: — krok mezi úpravami
- :material-content-cut: — režim oříznutí
- :material-content-save: — uložit úpravy
- :material-share-variant: — exportovat nebo sdílet
- :material-delete-outline: — zahodit session
- :material-play: — pokračovat v survey, je-li tato akce dostupná
- :material-help-circle-outline: — otevřít panel nápovědy Přehledu Session
- :material-tune: — otevřít Nastavení

## Typické úkoly při kontrole

- ověření detekcí oproti přehrávání a kontextu spektrogramu
- přidání druhu nebo poznámky
- oříznutí nahrávky na užitečný interval
- export zkontrolované sady výsledků

## Export

Chování exportu závisí na možnostech zvolených v [Nastavení](settings.md). Aplikace umí do zvoleného exportního formátu zabalit detekce a volitelně i zvuk. Každý export obsahuje metadata o původu — verzi aplikace, název a verzi modelu, jazyk názvů druhů, časovou značku exportu, nastavení uchovaná se session a relevantní možnosti exportu — zapsaná do vedlejšího souboru `<prefix>.metadata.json` (ZIP) nebo do bloku `meta` na nejvyšší úrovni (JSON), takže exporty jsou sebepopisné a reprodukovatelné.

Blok `settings` v exportu JSON zaznamenává hodnoty, které byly *skutečně použity na tuto session* — citlivost, režim a počet oken score poolingu, zesílení mikrofonu a frekvenci horní propusti — nikoli to, co je zrovna nastaveno v Nastavení teď. Díky tomu lze výsledek reprodukovat i po měsících nebo porovnat dvě surveye, aniž byste si museli pamatovat, kde byly které posuvníky při jejich pořízení.

Všechny časové značky v názvech exportovaných souborů (`BirdNET_Live_<date>_<time>_…`) i uvnitř obsahu CSV / JSON jsou formátovány v *aktuálním* místním čase vašeho telefonu. Podkladové záznamy se ukládají v UTC a při exportu se převádějí.
