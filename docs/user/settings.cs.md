# Nastavení

BirdNET Live používá jednu obrazovku Nastavení napříč více pracovními postupy. Tlačítko :material-tune: otevírá sekce, které jsou relevantní pro obrazovku, ze které jste přišli.

## Jak funguje rozsah nastavení

- Otevření nastavení z domovské obrazovky zobrazí celou obrazovku.
- Otevření nastavení z režimu Live, Survey, Point Count nebo Analýzy souborů zúží obrazovku na relevantní sekce.

## Obecné

### Motiv

Vyberte **Tmavý**, **Světlý** nebo **Systémový**.

Je-li zapnuta **Dynamická barva**, pokusí se BirdNET Live navíc převzít systémovou paletu vašeho zařízení s Androidem. To má vliv pouze na podporovaných zařízeních s Androidem; na iPhonu a iPadu aplikace nadále používá standardní motiv BirdNET Live, takže zapnutí přepínače tam nic nezmění.

Zapněte **Vysoce kontrastní motiv**, chcete-li používat černobílou světlou nebo tmavou paletu rozhraní se silnějším písmem a orámovanými plochami místo barevných karet. Řídí se volbou **Tmavý**, **Světlý** nebo **Systémový**, po dobu zapnutí má přednost před Dynamickou barvou a zachovává barvy pro nebezpečí, varování, ověření, režimy, skóre a spektrogram.

### Jazyk aplikace

Nastavuje jazyk rozhraní.

### Názvy druhů

Řídí jazyk používaný pro názvy druhů. **Systémový** použije preferovaný jazyk telefonu, pokud je daný název k dispozici, i když rozhraní přejde na angličtinu. **Podle aplikace** použije místo toho jazyk rozhraní.

### Zobrazovat vědecké názvy

Zobrazuje v celé aplikaci vědecké názvy pod běžnými názvy.

### Zobrazovat všechny detekované druhy

Pouze režim Live a Point Count. Ve výchozím nastavení vypnuto, takže tyto obrazovky zobrazují jen druhy detekované v posledním cyklu odvozování – tedy prakticky ty, které se právě ozývají. Zapněte, aby každý druh detekovaný během probíhající Session zůstal v seznamu viditelný i poté, co přestane zpívat nebo klesne pod práh spolehlivosti.

Je-li tato volba zapnuta, objeví se **Řazení seznamu druhů**. **Nejnovější první** zobrazí nahoře druhy, které se právě ozývají, seřazené podle aktuální spolehlivosti, a za nimi zachované druhy podle poslední detekce. **Spolehlivost** řadí podle nejvyšší spolehlivosti, které druh během Session dosáhl, **Abecedně** podle lokalizovaného běžného názvu a **Výskyty** podle počtu detekcí. V každém režimu řazení se procento a pruh spolehlivosti zobrazují jen po dobu, kdy se druh právě ozývá (zachované řádky umlklých druhů jsou ztlumené), a u opakovaných detekcí se na konci řádku s běžným názvem zobrazí počítadlo.

### Jméno pozorovatele

Nastavení Survey, Point Count a ARU si pamatuje poslední neprázdné jméno pozorovatele zadané v kterémkoli z těchto režimů a předvyplní jej při příští přípravě terénní Session. Opakované použití na osobním terénním telefonu tak zůstává rychlé a zároveň můžete pozorovatele před zahájením Session upravit nebo smazat.

### ID ARU/stanice

Nastavení ARU si pamatuje poslední neprázdné ID ARU/stanice a předvyplní jej pro další nasazení. Je-li vyplněno, ID se objeví v názvu Session ARU i v názvech exportovaných souborů, takže opakovaná nasazení na stálých místech zůstanou rozpoznatelná i mimo aplikaci.

### Zobrazení časových značek

Řídí, jak se v přehledu Session zobrazují časy jednotlivých detekcí.

- **Relativní** zobrazuje odstup od začátku nahrávky, například `00:12:34`. Nejvhodnější při procházení jedné Session a při zarovnávání s přehrávací značkou spektrogramu.
- **Absolutní** zobrazuje místní čas, kdy byla detekce zaznamenána, například `08:42:17`. Nejvhodnější pro porovnání s terénními poznámkami, záznamy o počasí nebo souběžnými nahrávkami.

Pokud detekce připadne na jiný kalendářní den než začátek Session (například při noční survey), získá absolutní čas příponu `+1d`, aby si nikdo nespletl zítřejší ranní sbor s dnešním.

Je-li vybráno **Absolutní**, objeví se navíc přepínač **Zobrazovat sekundy v časových značkách**. Vypněte jej, pokud dáváte přednost úspornějšímu `08:42` před `08:42:17` – hodí se při procházení dlouhých seznamů detekcí. Relativní odstupy zobrazují sekundy vždy, protože při procházení je potřeba přesnost pod jednu minutu, aby seděla s přehrávací značkou spektrogramu.

Ukládání i exporty používají bez ohledu na toto nastavení vždy okamžiky v UTC, volba tedy nikdy neovlivní data – pouze způsob jejich zobrazení.

## Zvuk

Tyto prvky se objevují v živých pracovních postupech založených na zvuku.

### Zdroj zvuku

Jeden panel se dvěma nezávislými prvky: **Mikrofon** – z jakého vstupu nahrávat – a **Zpracování** – nakolik smí telefon signál na vstupu upravovat. Lze je libovolně kombinovat, takže USB mikrofon nahrávaný *bez zpracování* je zcela smysluplná konfigurace. Vaše volba se uchová i po restartu aplikace a stejný výběr se objevuje i na obrazovkách nastavení Survey, Point Count a ARU. Změny se projeví okamžitě – i uprostřed nahrávání aplikace vymění mikrofon pod probíhající Session, místo aby čekala na další.

**Mikrofon** vypisuje podle názvu každý vstup, který telefon nabízí: USB, drátové a Bluetooth mikrofony a na mnoha telefonech i jednotlivé vestavěné mikrofony (například *spodní* a *zadní*). Bezdrátové mikrofonní sady jako Rode Wireless GO nebo DJI Mic se připojují přes USB-C přijímač, takže se zde objevují jako běžná USB zvuková zařízení v plné kvalitě.

**Zpracování** je nejdůležitější část a týká se **pouze Androidu**. Telefony na zvuk z mikrofonu ve výchozím stavu aplikují DSP vyladěné na řeč – potlačení šumu, spektrální tvarování a automatické zesílení – protože mikrofon se používá především k hovorům. Toto zpracování považuje zpěv ptáků za šum, který je třeba potlačit, a žádné běžné nastavení jej nevypne. Jediným východiskem je požádat Android o jiný *zdroj zvuku*:

| Volba | Co dělá |
|---|---|
| **Výchozí pro telefon** | To, co váš telefon dělá běžně, včetně zpracování řeči. Původní chování a stále výchozí volba, aby se stávajícím uživatelům nic nezměnilo. |
| **Bez zpracování** | Surový signál z mikrofonu – žádné potlačení šumu, žádné automatické zesílení. Pro ptáky obvykle nejlepší volba. |
| **Rozpoznávání řeči** | Rovněž vypíná potlačení šumu a automatické zesílení a funguje téměř na každém telefonu. |

**Vyzkoušejte je a porovnejte.** Která volba vyhraje, opravdu závisí na konkrétním přístroji. *Bez zpracování* je ideál, ale Android jej respektuje jen na telefonech, u nichž výrobce podporu deklaruje – na ostatních se tiše vrátí zpět a zní stejně jako *Výchozí pro systém*. Právě proto existuje *Rozpoznávání řeči*: pravidla kompatibility Androidu **vyžadují**, aby u něj bylo automatické zesílení i potlačení šumu vypnuto, takže spolehlivě dodává nezpracovaný zvuk i na telefonech, které *Bez zpracování* ignorují. Pokud přepnutí na *Bez zpracování* nic nezmění, přepněte na *Rozpoznávání řeči*.

Počítejte s tím, že volby bez zpracování budou znít **tišeji** – to je chybějící automatické zesílení, nikoli závada. Pokud indikátor úrovně vypadá nízko, vyrovnejte to zvýšením **Zesílení**.

**Na iOS** je prvek Zpracování skrytý a panel je prostě seznam mikrofonů. iOS aplikaci předává v podstatě nezpracovaný zvuk, takže tu není co obdobného volit.

### Zesílení

Lineární zesilovač aplikovaný na příchozí zvuk dříve, než dorazí do spektrogramu a klasifikátoru. Ponechte na **1,0×**, pokud váš vstup není trvale příliš tichý – například vysokoimpedanční klopový mikrofon na telefonu nebo USB rozhraní s příliš nízko nastaveným předzesilovačem. Zesílení nad 1,0 nevykouzlí hlasy, které mikrofon nikdy nezachytil; pouze přeškáluje to, co mikrofon dodal, takže hlasité blízké zvuky se mohou přebudit. Hodnoty pod 1,0 se hodí ve vzácném případě, kdy příliš silný vstup přesycuje spektrogram.

### Horní propust (Hz)

Ořezává nízkofrekvenční obsah před odvozováním pomocí Butterworthova filtru 24 dB/oktávu – hodnota na posuvníku je mezní frekvence −3 dB. **0 Hz jej vypíná.** Mez 100–200 Hz odstraní vítr, dunění dopravy a manipulační ruch, aniž by zasáhla většinu druhů; směrem k 500–1000 Hz začnou mizet hluboké houkání, sovy, tetřevovití i dunění bukače, takže tak vysoko jděte jen tehdy, pokud tyto druhy vědomě pomíjíte výměnou za výrazně čistší spektrogram v hlučném městském prostředí. Zvolená mez by měla být na živém spektrogramu vidět jako ostrá vodorovná čára.

## Odvozování

### Délka okna

Řídí délku analytického okna. Dostupné hodnoty jsou **1**, **3**, **5**, **7**, **10** a **15** sekund.

### Práh spolehlivosti

Určuje, jak konzervativní mají detekce být. Výchozí hodnota je **35 %**, což udržuje živý seznam zaměřený na silnější shody a přitom ponechává prostor pro vzdálené nebo částečně maskované hlasy. Snižte jej, pokud mapujete vzácné nebo tiché druhy a plánujete projít více kandidátů později; zvyšte jej, když Session zahlcuje hluk pozadí nebo časté falešně pozitivní nálezy.

### Citlivost

Posun na ose x aplikovaný na surové pravděpodobnostní skóre modelu před sdružováním skóre, geografickou filtrací a prahem spolehlivosti. Zvukový model BirdNET již obsahuje sigmoidní aktivaci, proto BirdNET Live nejprve převede každou pravděpodobnost zpět do prostoru logitů, přičte posun citlivosti a poté ji převede zpět na pravděpodobnost. Vyšší hodnoty činí detektor benevolentnějším – práh překonají i slabší nebo nejednoznačnější hlasy, za cenu více falešně pozitivních nálezů. Nižší hodnoty jsou přísnější a propustí jen jisté detekce. Výchozí hodnota **1,0** neaplikuje žádný posun a odpovídá referenci BirdNET. Zkuste **1,25**, pokud máte podezření, že model přehlíží vzdálené hlasy; klesněte na **0,75**, pokud vás zaplavují nekvalitní detekce běžných druhů. Citlivost se uplatní okamžitě: změna uprostřed Session se projeví od dalšího okna odvozování.

### Frekvence odvozování

Řídí, jak často BirdNET provádí odvozování. Posuvník používá stejné kroky
**0,10–1,00 Hz** jako nastavení Survey a ARU. Okna jsou ukotvena k
zachyceným zvukovým vzorkům, nikoli k dokončení časovače, takže uložení
ukázky ani dočasně pomalé volání modelu neposune následující okna. Při
shodném nastavení odvozování analyzují režim Live, Point Count a Survey
stejná okna a hlásí stejné detekce. Nižší frekvence snižují zátěž modelu i
spotřebu baterie, ale ponechávají mezi okny širší mezery, takže velmi krátké
hlasové projevy lze snáze přeslechnout. Nové průzkumy Survey mají ve výchozím
stavu **0,70 Hz** jako střední cestu; **0,30 Hz** zůstává výslovnou volbou pro
maximální výdrž baterie. Analýza souborů frekvenci odvozování nemá — místo ní
používá nastavení [překryvu](file-analysis.md).

BirdNET Live interně vyhlazuje skóre napříč nedávnými okny odvozování, aby
omezil jednorázové falešně pozitivní nálezy. Toto sdružování není dostupné
jako uživatelské nastavení; ve výchozím stavu se používá adaptivní sdružování
Log-Mean-Exp s pěti nedávnými okny a limitem stáří 10 sekund reálného času.
Přijaté detekce zobrazují nejvyšší nedávnou podloženou spolehlivost modelu,
takže zřetelné hlasové projevy mohou stále vykazovat vysokou spolehlivost,
místo aby je vyhlazování srovnalo. Všechny režimy nyní převádějí výsledek
sdružování na detekce stejně: detekce začíná v nejstarším podpůrném okně, nese
nejvyšší podložené skóre a končí na konci posledního podpůrného okna.

## Spektrogram

### Velikost FFT

Řídí frekvenční rozlišení spektrogramu.

### Barevná paleta

Vyberte **Viridis**, **Magma**, **Plasma**, **Cividis**, **Jet**, **Turbo**, **Odstíny šedi** nebo **BirdNET**. **Turbo** je moderní duhová varianta podobná Jet.

### Délka (rychlost posunu)

Řídí, kolik času je v okně spektrogramu vidět.

### Frekvenční rozsah

Nastavuje horní zobrazovanou frekvenci.

### Logaritmická amplituda

Aplikuje na spektrogram logaritmické škálování, aby se snáze četl.

### Kvalita

Řídí, jak hladce se obraz spektrogramu škáluje. **Střední** je výchozí kompromis. Na starších telefonech zvolte **Nízkou**, pokud posun trhá nebo se zařízení zahřívá; zvolte **Vysokou**, pokud dáváte přednost hladšímu obrazu a vaše zařízení má dost výkonu GPU. Intuice: mění to pouze náročnost vykreslování, nikoli analýzu zvuku ani výsledky detekce.

## Hlasová oznámení

Tato sekce určuje, zda má BirdNET Live **předčítat detekce nahlas do sluchátek nebo přes reproduktor telefonu**, zatímco Session nahrává. Celá funkce je **ve výchozím stavu vypnutá**, protože mění akustické prostředí kolem mikrofonu – její zapnutí je vědomý kompromis. Neexistuje žádný průvodce nastavením: výběr míry podrobnosti × frekvence níže *je* celé nastavení, takže můžete kdykoli klepnout na jinou předvolbu a rozdíl hned slyšet. Intuice: při dlouhých surveyích nemůžete stále sledovat obrazovku; nenápadný hlas v uchu znamená, že můžete nechat oči na biotopu a přesto vědět, co se právě ozvalo.

### Předčítat detekce nahlas (hlavní přepínač)

Ve výchozím stavu vypnuto. Po zapnutí aplikace vysloví každou přijatou detekci pomocí vestavěného hlasového výstupu vašeho zařízení. **Důrazně doporučujeme sluchátka** – při použití reproduktoru telefonu hrozí, že oznámení zachytí mikrofon a znovu je detekuje, proto aplikace kolem každé promluvy krátce ztlumí nahrávání, aby této smyčce zabránila (viz *Ztlumit mikrofon během mluvení* níže).

### Předvolba podrobnosti

Kolik toho aplikace o každé detekci řekne. **Minimální** vysloví jen název druhu (nejvhodnější pro velmi dlouhé surveye, kde chcete pouze signál). **Vyvážená** je výchozí – krátké, obměňované formulace jako *„Červenka“*, *„Slyšet červenku“*, *„Zase červenka“*. **Upovídaná** přidává trochu více kontextu a blíží se tomu, jako by vedle vás někdo komentoval. **Vlastní** se objeví automaticky, jakmile ručně upravíte číselné hodnoty v části Pokročilé. Intuice: stejná nastavení omezování mohou působit buď příliš tiše, nebo příliš upovídaně podle formulace – podrobnost vám umožní zachovat tempo a měnit jen množství slov.

### Předvolba frekvence

Jak často smí aplikace vůbec mluvit. Pět stupňů od nejtiššího po nejupovídanější. **Zřídka** a **Střídmě** mezi oznámeními dlouho vyčkávají a omezují jejich tempo – dobře se hodí pro několikahodinové surveye, kde chcete mít přehled o aktivitě, ale ne průběžný komentář. **Normálně** je výchozí, konverzační tempo. **Často** zkracuje mezery a zvedá strop; hodí se pro krátké Session režimu Live nebo když chcete zpětnou vazbu blíže reálnému času. **Neustále** zcela odstraní úvodní prodlevu a nechá aplikaci mluvit téměř v každém cyklu detekce – užitečné pro ukázky, přístupnost nebo když vám mezera před prvním oznámením u volby *Často* připadá příliš dlouhá. **Vlastní** se objeví, když změníte časová pole v části Pokročilé. Intuice: tohle je ten jediný knoflík, který rozhoduje, zda aplikace zůstane v pozadí, nebo se stane přítomností – klepněte na jinou předvolbu a nové tempo uslyšíte už v dalším cyklu detekce, bez tlačítka uložit.

### Hlas

Klepnutím na řádek hlasu vyberte z hlasů hlasového výstupu nainstalovaných pro jazyk oznámení, nebo ponechte **Výchozí hlas** a nechte volbu na zařízení. Dostupnost a kvalita hlasů závisí na operačním systému a nainstalovaných hlasových balíčcích; další hlasy lze nainstalovat v nastavení hlasového výstupu zařízení.

**Rychlost** má rozsah 0,5×–1,5×; výchozí 1,0× je „normální“ tempo platformy. **Výška tónu** má rozsah 0,7×–1,3×. Mírné snížení výšky tónu a lehké zpomalení mohou usnadnit porozumění oznámením venku při větru nebo šumu tekoucí vody. *Přehrát ukázku* umožní poslechnout si zvolený hlas, aktuální styl formulací, rychlost a výšku tónu, aniž byste opustili nastavení. Změny platí od dalšího oznámení.

### Pokročilé

Rozbalovací část s několika přepínači směrování zvuku a výběrem režimu spouštění. Obvykle ji nemusíte otevírat – předvolby podrobnosti a frekvence výše jsou jediné knoflíky, na kterých v běžném provozu záleží. Číselné hodnoty omezování (počáteční odklad, minimální rozestup, maximum za minutu, ticho při sérii, reset aktuálnosti) jsou sdruženy do posuvníku **Frekvence**, takže existuje jedno zřejmé místo, kde tempo přidat nebo ubrat.

- **Povolit reproduktor telefonu** – Když je vypnuto, oznámení se tiše přeskočí, pokud nejsou připojena sluchátka ani externí reproduktor. Když je zapnuto, použije se jako záloha reproduktor telefonu. Zapněte to pro nezávazný poslech doma; v terénu nechte vypnuté, abyste vyloučili akustickou zpětnou vazbu do mikrofonu.
- **Ztlumit mikrofon během mluvení** – Nahrazuje příchozí zvuk tichem, dokud aplikace mluví, aby zvuk z reproduktoru nemohl zachytit mikrofon a znovu jej detekovat. Vřele doporučeno (a výchozí). Vypněte jen tehdy, je-li váš mikrofon akusticky oddělen od reproduktoru telefonu – například klopový mikrofon na jiném kabelu nebo Bluetooth náhlavní souprava.
- **Ztlumit ostatní zvuk** – Po dobu oznámení krátce sníží hlasitost hudby nebo podcastů z jiných aplikací a poté ji obnoví. Ve výchozím stavu zapnuto. Vypnuto přehrává v plné hlasitosti.
- **Signál před promluvou** – Před každou promluvou přehraje krátký tichý tón, aby vaše ucho mělo chvíli na přechod z pasivního poslechu k pozornosti vůči hlasu. Ve výchozím stavu zapnuto. Zvlášť užitečné, jsou-li oznámení řídká nebo hraje-li na pozadí hudba.
- **Co oznamovat** – Určuje, které detekce vůbec připadají v úvahu pro oznámení. *Každou detekci* (výchozí) ponechá rozhodnutí na omezování. *Poprvé za Session* oznámí druh jen při jeho prvním výskytu v aktuální Session. *Jen sledovaný seznam* omezí oznámení na druhy z vašeho sledovaného seznamu (užitečné při cílené survey práci, kdy chcete slyšet pouze o prioritních taxonech).

## Nahrávání

### Režim

- **Úplné** – uložit celou nahrávku
- **Jen detekce** – uložit úseky kolem detekcí
- **Vypnuto** – bez nahrávání zvuku

### Kontext úseku

Je-li aktivní **Jen detekce**, zobrazí aplikace jediný posuvník **Kontext úseku** (0–5 s), který určuje, kolik zvuku se zachová na **obou stranách** každé detekce. Každý úsek trvá `analytické okno + 2 × kontext úseku`, takže při analytickém okně 3 s a výchozím kontextu 1 s má uložený úsek 5 s. Kontext 2 s dá úsek 7 s (2 s před + 3 s analyzovaného zvuku + 2 s po). Vyšší hodnoty vám dají více prostoru pro vizuální kontrolu nebo externí nástroje, za cenu místa na disku; hodnota 0 uloží jen samotné analyzované okno.

### Formát

Vyberte **WAV** nebo **FLAC**. WAV je větší, ale široce kompatibilní a rychle se kontroluje. FLAC zachovává stejnou bezeztrátovou kvalitu zvuku při menší spotřebě místa, což je u dlouhých Session obvykle lepší.

Toto nastavení platí pro zvuk, který nahrává BirdNET Live. **Analýza souborů** uchovává aplikací spravovanou kopii importovaného souboru v původním formátu, takže nahrané soubory MP3, AAC, WAV a FLAC zůstávají k dispozici k procházení bez dalšího převodu.

### Automaticky spustit nahrávání (jen režim Live)

Po zapnutí začne režim Live nahrávat, jakmile se obrazovka otevře a model se načte – bez klepnutí na tlačítko mikrofonu. Užitečné pro instalace typu kiosek, práci bez rukou (například zařízení upevněné v terénu) nebo pro jakýkoli postup, kde otevření režimu Live stejně znamená „začínáme teď“. Ve výchozím stavu vypnuto, aby náhodné klepnutí na dlaždici Live na domovské obrazovce tiše nezahájilo Session. Automatické spuštění proběhne jen jednou za návštěvu obrazovky, takže zastavení Session a opětovné klepnutí na mikrofon nadále funguje jako ruční restart.

Toto nastavení se týká otevírání režimu Live uvnitř aplikace. [Widget Quick Listen](live-mode.md) při klepnutí začne poslouchat bez ohledu na toto nastavení a nastavení nemění. Pokud již běží nebo se spouští Session režimu Point Count, Survey, Analýzy souborů nebo ARU, tato Session se zachová a budete požádáni, abyste ji nejprve zastavili.

### Automaticky ukládat Sessions (Live a Point Count)

Po zapnutí (výchozí) se dokončená Session režimu Live nebo Point Count přidá do vaší knihovny automaticky ve chvíli, kdy skončí. Po vypnutí se dokončená Session otevře v přehledu s označením **neuloženo**: ikona uložení je zvýrazněná a musíte na ni klepnout, aby se Session zachovala. Odchod z přehledu bez uložení Session i s nahrávkami zahodí. To se hodí pro krátký poslech, kdy chcete uchovat jen občasný pozoruhodný výsledek místo hromadění každé krátké nahrávky. Nasazení Survey a ARU se ukládají vždy automaticky – dlouhý běh bez dozoru je příliš cenný, aby se ztratil kvůli zapomenutému uložení – takže tam se tento přepínač neuplatní.

## Přehrávání

### Překryv přehrávače v přehledu

Po zapnutí (výchozí) otevře poslech zvukového úseku v přehledu Session složené jen z úseků (kde není k dispozici úplná nahrávka ani spektrogram) samostatný modální překryv přehrávače s ovládáním a náhledem spektrogramu, místo aby úsek přehrál na pozadí. Má-li Session úplný zvuk, toto nastavení se obchází a překryv přehrávače se nikdy nezobrazí.

### Automaticky přehrávat hlasové poznámky

Ve výchozím stavu vypnuto. Po zapnutí se hlasová poznámka připojená k časované anotaci během přehledu Session přehraje automaticky ve chvíli, kdy přehrávací značka mine její zaznamenanou pozici. Poznámka se přimíchá přes nahrávku, místo aby ji pozastavila, takže svou mluvenou poznámku slyšíte v kontextu spolu s původním zvukem. Ponechte vypnuté, pokud dáváte přednost ručnímu spouštění poznámek klepnutím na jejich anotační štítek.

### Ztlumení při hlasových poznámkách

Zobrazuje se jen tehdy, je-li zapnuto **Automaticky přehrávat hlasové poznámky**. Určuje, nakolik se hlavní nahrávka ztlumí během přehrávání automatické hlasové poznámky. Vyšší hodnoty činí mluvené poznámky srozumitelnějšími; nižší hodnoty ponechávají pod poznámkou slyšet více z původní nahrávky.

## Poloha

### Používat GPS

Používat GPS zařízení místo ručně zadaných souřadnic. Na Androidu pocházejí
polohy od poskytovatele polohy dané platformy, nikoli od služeb Google Play,
takže aplikace nevyvolá dialog Googlu o přesnosti polohy. Je-li tato volba
vypnutá, aplikace sama nikdy nečte GPS ani nežádá o oprávnění k poloze:
průvodci nastavením Survey, Point Count a ARU se otevřou na ručním zadání s
vašimi uloženými souřadnicemi, sledování GPS během Survey neběží a příprava
offline map se rovněž vystředí na tyto souřadnice.

### Ruční souřadnice

Souřadnice použité, když je **Používat GPS** vypnuto. Zeměpisná šířka i délka jsou upravitelná textová pole, takže můžete přesnou hodnotu **napsat** nebo **vložit** zkopírovanou z jiné aplikace – mnohem přesnější než tahat posuvníkem po dotykové obrazovce. Zadávejte desetinné stupně (například `52.5200` a `13.4050`). Můžete také vložit spojený řetězec `šířka, délka` (oddělený čárkou, středníkem nebo mezerou) do *kteréhokoli* z polí a obě pole se vyplní naráz – odpovídá to tomu, co většina map a webů dává do schránky. Hodnoty mimo rozsah nebo nečíselný vstup se rovnou označí a neuloží; platné hodnoty se během psaní udrží. Intuice: nejčastějším důvodem pro ruční nastavení polohy je určení zvuku nahraného jinde, než kde právě jste, a tato poloha obvykle přichází jako text odjinud – psaní a vkládání z toho udělá jediný přesný krok. Pokud raději ukážete na místo, než abyste psali čísla, **Vybrat na mapě** otevře stejný celoobrazovkový výběr map jako obrazovky nastavení, přednastavený na aktuální souřadnice, a obě pole vyplní místem, na které klepnete.

### Aktualizovat GPS teď

Vynutí nové určení polohy místo opakovaného použití poslední hodnoty z mezipaměti. Intuice: dotazy na GPS se ukládají do mezipaměti pro každou obrazovku zvlášť, aby obrazovka nastavení nemusela při každém otevření čekat na signál ze satelitů – tato mezipaměť ale může být o kilometry zastaralá, pokud jste od minulé Session přejeli na nové místo. Klepněte na to, když jste se přesunuli a chcete, aby geofiltr použil polohu *zde*, a ne tu, kde jste začínali ráno. Aktuální souřadnice z mezipaměti jsou uvedeny v podtitulku, takže si můžete ověřit, kde vás aplikace předpokládá. Pokud se polohu nepodaří určit do přibližně 10 sekund, aplikace se vrátí k poslední známé poloze z operačního systému a upozorní vás lištou SnackBar, abyste věděli, že hodnota je zastaralá.

### Stahování offline map

Stahování offline map je momentálně skryté, dokud BirdNET Live používá veřejnou dlaždicovou službu OpenStreetMap. OpenStreetMap umožňuje běžné interaktivní procházení map s uvedením zdroje, jasným identifikátorem klienta a lokální mezipamětí, ale nepovoluje hromadné předstahování ani funkce stahování offline map z `tile.openstreetmap.org`. Implementace stahovače zůstává zachována pro budoucí zdroj dlaždic, který offline balíčky výslovně povolí.

### Filtr druhů

- **Vypnuto** – bez geografické filtrace
- **Filtr podle polohy** – vyloučit druhy pod geografickým prahem
- **Vážení podle polohy** – použít geomodel jako doplňkový vážicí signál

### Práh geofiltru

Objeví se, když je aktivní režim filtrace založený na poloze.

## Export a synchronizace

### Formáty

Zaškrtněte libovolnou kombinaci exportních formátů – při každém uložení či sdílení se všechny zvolené formáty sbalí společně do jednoho ZIP. Zvolíte-li jediný formát bez zvukových úseků a bez HTML zprávy, dostanete kvůli zpětné kompatibilitě samostatný soubor (například `session.csv`) místo ZIP:

- Raven Selection Table – pro použití v Cornell Raven Pro.
- CSV – otevře se v jakémkoli tabulkovém procesoru.
- JSON – nejsnazší pro programové zpracování; nese úplná metadata Session.
- GPX – trasa a body zájmu pro mapové nástroje (má smysl jen tehdy, bylo-li zapnuto GPS).

Intuice: mnoho pracovních postupů potřebuje více formátů najednou – CSV do tabulky, tabulku Raven pro kolegu u počítače a JSON pro analytický skript. Rozplétat to přepínačem jediného formátu dříve znamenalo exportovat tutéž Session třikrát. Nyní zaškrtnete všechny tři jednou a putují společně v ZIP.

### Zahrnout zvukové soubory

Zahrnout uložený zvuk vedle exportovaných tabulek nebo metadat, pokud to daný postup exportu podporuje. Sdílení jedné detekce se také řídí tímto nastavením: úplná nahrávka Session se ořízne na přesné počáteční a koncové časové značky detekce, zatímco Session pouze s detekcemi použije její uložený klip.

### Zvuk vždy sdílet jako WAV

Zobrazuje se jen tehdy, je-li zapnuto **Zahrnout zvukové soubory**. Po zapnutí se nahrávky FLAC před sdílením nebo exportem převedou na WAV. WAV je univerzálně kompatibilní, ale výrazně větší než FLAC, proto tuto volbu nechte vypnutou, pokud nástroj na přijímající straně neumí FLAC přečíst – některý starší desktopový analytický software a několik nahrávacích formulářů to dodnes neumí.

### Zahrnout metadata aplikace

Po zapnutí nese exportní ZIP doprovodný soubor `*.metadata.json`, který popisuje, jak Session vznikla: verzi BirdNET Live, identitu modelu, snímek počasí pořízený na začátku Session a všechna varování o integritě zvuku zjištěná během nahrávání. Intuice: právě tyto údaje o původu vám (nebo tomu, kdo výsledky kontroluje) umožní Session po měsících zopakovat či ověřit. Vypněte je, chcete-li čistě sdílet jen zvuk a zvolené formáty – například vložit jediný soubor WAV do iNaturalist nebo eBird bez souborů specifických pro aplikaci.

### Zahrnout HTML zprávu

Po zapnutí obsahuje každý exportní ZIP navíc soubor `<session>_report.html` vedle tabulky, zvukových úseků a GPX. Otevřete jej v libovolném prohlížeči a dostanete souhrn Session připravený k tisku: záhlaví s datem, místem, pozorovatelem a součty; interaktivní mapu trasy GPS a značek detekcí; kartu pro každou detekci s náhledem z taxonomie Cornell, názvy, štítkem skóre, vaším potvrzením, případnou zapsanou poznámkou a původním zvukovým úsekem ve vestavěném přehrávači; a použitá nastavení analýzy. Intuice: CSV je skvělé pro analytické postupy, ale nehodí se ke sdílení s netechnickým kolegou ani k vytištění krátkého terénního souhrnu – HTML zpráva tuto mezeru zaplní jedním klepnutím. Náhledy druhů a mapové dlaždice potřebují při prvním otevření souboru připojení (načítají se živě z API taxonomie BirdNET a z OpenStreetMap), ale vše ostatní – text, rozvržení, přehrávání zvuku, odkazy – funguje zcela offline. Vypněte to, pokud potřebujete jen surová data a chcete mít ZIP o pár kB menší.

### Sdílení pouze zvuku

Odškrtněte každý formát **i** HTML zprávu **i** políčko metadat aplikace, takže zůstane jen **Zahrnout zvukové soubory**: pak Sdílet předá systémovému panelu surovou nahrávku (například `BirdNET_Live_…flac`) místo ZIP. To je nejjednodušší cesta, jak poslat Session přímo do iNaturalist, eBird nebo jakékoli jiné aplikace, která očekává nezabalený zvukový soubor. Sessions složené z více úseků detekcí stále vytvoří ZIP; při sdílení jedné detekce se předá její jediný surový klip.

## Soukromí

Tato sekce určuje, **které služby třetích stran smí BirdNET Live vaším jménem kontaktovat**. Samotné odvozování běží zcela na vašem zařízení – tyto přepínače řídí pouze volitelné síťové funkce, které zpříjemňují používání. Všechny tři přepínače jsou při čerstvé instalaci **ve výchozím stavu vypnuté**; ven neodejde nic, dokud to nedovolíte. Intuice: každý přepínač je omezen na jednu konkrétní službu a jeden konkrétní přínos, takže si můžete zapnout přesně to, co je pro vaši práci užitečné, a nic dalšího.

### Povolit mapové dlaždice

Vyžadováno pro jakoukoli interaktivní mapu v aplikaci (výběr polohy, živou mapu Survey a mapu Session). Po zapnutí načítají mapové prvky rastrové dlaždice z veřejných serverů **OpenStreetMap**; dotazy na souřadnice dlaždic prozrazují, na jakou část světa se právě díváte. Dlaždice se ukládají lokálně do mezipaměti až na šest měsíců, s limitem 6000 dlaždic, aby opakované prohlížení map zůstalo efektivní a nerostlo bez omezení. Zapnutí této volby zapne také **Povolit vyhledávání názvů míst**, protože většina uživatelů, kteří načítají mapy, očekává, že se u Sessions zobrazí i čitelné názvy míst. Vyhledávání názvů míst můžete poté vypnout zvlášť. Jsou-li mapové dlaždice vypnuté, každá obrazovka s mapou přejde na zástupnou kartu, takže zbytek aplikace funguje dál bez úniku do sítě.

### Povolit vyhledávání názvů míst

Po zapnutí odesílá aplikace vaše zaznamenané souřadnice službě **Nominatim od OpenStreetMap**, aby zjistila krátký název místa (například „Berlín, Německo“), který se zobrazuje vedle Session v Knihovně Sessions a v přehledu Session. Intuice: číselné souřadnice jsou přesné, ale při procházení dlouhého seznamu Sessions se špatně čtou – název místa udělá ze seznamu něco, co přečtete na první pohled. Po vypnutí Sessions zobrazují jen surovou šířku a délku a Nominatim se nikdy nekontaktuje.

### Povolit vyhledávání počasí

Po zapnutí zachytí každá uložená Session prostřednictvím **Open-Meteo** jednorázový snímek místních podmínek (teplotu, srážky, vítr, oblačnost) pro souřadnice nahrávky a čas ukončení. Snímek se objeví v přehledu Session pod řádkem polohy a promítne se do exportu JSON, bloku metadat Session i HTML zprávy. Intuice: počasí je jedním z nejsilnějších prediktorů ptačí aktivity a jeho automatické zachycení – aniž byste museli pamatovat na kontrolu jiné aplikace – dělá z každé Session úplnější záznam. Open-Meteo je bezplatná služba a nevyžaduje účet ani API klíč. Po vypnutí se žádná data o počasí nenačítají ani neukládají. Nastavení Point Count a Survey rovněž zobrazuje kompaktní kartu počasí u prvků polohy: o tento souhlas žádá jen v případě potřeby, po zapnutí ukáže náhled jako ikonu + teplotu + vítr a při ukládání Session znovu použije tentýž snímek z mezipaměti.

## O aplikaci

Řádek **O aplikaci** otevře obrazovku s informacemi uvnitř aplikace.

## Nebezpečná zóna

### Resetovat úvodní průvodce

Zobrazí úvodní sekvenci znovu při příštím spuštění aplikace.

### Resetovat všechna nastavení

Vrátí každou předvolbu na této obrazovce na výchozí hodnotu. Sessions, nahrávky, hlasové poznámky, exporty a mapové dlaždice v mezipaměti zůstanou nedotčené – smažou se jen uložené předvolby (posuvníky, přepínače, zvolené hodnoty). Po potvrzení se aplikace zavře, aby se nové výchozí hodnoty projevily při dalším spuštění.

Užitečné, když si nejste jisti, kterým posuvníkem jste pohnuli a něco tím rozbili, nebo když zařízení předáváte někomu jinému a chcete čistou konfiguraci bez ztráty nasbíraných dat.

### Smazat všechna data

Trvale smaže Sessions, detekce, nahrávky, hlasové poznámky, vlastní seznamy druhů, uložené předvolby a data v mezipaměti pro mapy, názvy míst, počasí, přehrávání, přehled a sdílení. Potvrzovací dialog vyžaduje napsat `DELETE` a poté aplikaci zavře, takže další spuštění začne z čistého lokálního stavu.

Použijte to, než zařízení předáte jinému pozorovateli, vyřadíte terénní telefon z provozu nebo z aplikace odstraníte historii vázanou na polohu. Nejprve vyexportujte vše, co potřebujete; tuto akci nelze vrátit zpět.

## Parametry jednotlivých postupů mimo nastavení

Některé parametry se konfigurují na vlastních obrazovkách nastavení, nikoli na sdílené obrazovce nastavení.

- [Režim Point Count](point-count-mode.md) má vlastní nastavení délky a polohy.
- [Režim Survey](survey-mode.md) má vlastní obrazovku parametrů Survey.
- [Analýza souborů](file-analysis.md) má vlastní krok s parametry analýzy.
