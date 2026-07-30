# Nastavení

BirdNET Live používá jednu obrazovku Nastavení napříč více pracovními postupy. Tlačítko :material-tune: otevírá sekce, které jsou relevantní pro obrazovku, ze které jste přišli.

## Jak funguje rozsah nastavení

- Otevření Nastavení z Domů zobrazí celou obrazovku.
- Otevření Nastavení z Live, Survey, Point Count nebo Analýzy souborů omezí obrazovku na příslušné sekce.

## Obecné

### Téma

Vyberte **Tmavé**, **Světlé** nebo **Systém**.

Je-li zapnuta **Dynamická barva**, BirdNET Live se navíc pokusí převzít systémovou paletu vašeho zařízení s Androidem. To má vliv jen na podporovaných zařízeních s Androidem; na iPhonu a iPadu aplikace dál používá standardní motiv BirdNET Live, takže zapnutí přepínače zde nic nezmění.

### Jazyk aplikace

Nastaví jazyk rozhraní.

### Názvy druhů

Řídí jazyk používaný pro názvy druhů. **Systém** používá preferovaný jazyk telefonu, pokud je daný název k dispozici, i když rozhraní přejde na angličtinu. **Sledovat aplikaci** místo toho používá jazyk rozhraní.

### Zobrazit vědecké názvy

Zobrazuje vědecké názvy pod běžnými názvy v celé aplikaci.

### Přehrávací vrstva v přehledu

Je-li zapnuto (což je výchozí stav), přehrávání zvukového klipu v Přehledu Session, který obsahuje jen klipy (kde není k dispozici celá nahrávka ani spektrogram), spustí samostatný modální přehrávač s ovládáním přehrávání a náhledem spektrogramu místo přehrávání klipu na pozadí. Pokud má Session celou nahrávku, toto nastavení se ignoruje a přehrávací vrstva se nikdy nezobrazí.

### Jméno pozorovatele

Příprava Survey, Point Count a ARU si pamatuje poslední neprázdné jméno pozorovatele zadané v kterémkoli z těchto režimů a předvyplní je při příští přípravě terénní Session. Díky tomu je opakované použití na osobním terénním telefonu rychlé a zároveň můžete jméno pozorovatele před spuštěním Session upravit nebo vymazat.

### ID ARU/stanice

Příprava ARU si pamatuje poslední neprázdné ID ARU/stanice a předvyplní je pro další nasazení. Je-li vyplněno, je toto ID součástí názvu ARU Session i názvů exportovaných souborů, takže opakovaná nasazení na stejném místě zůstanou rozpoznatelná i mimo aplikaci.

### Zobrazení času

Řídí, jak se v přehledu Session zobrazují časy jednotlivých detekcí.

- **Relativní** ukazuje odstup od začátku nahrávání, např. `00:12:34`. Vhodné pro procházení jedné Session a synchronizaci s pozicí přehrávání ve spektrogramu.
- **Absolutní** ukazuje místní čas, kdy byla detekce zachycena, např. `08:42:17`. Vhodné pro porovnání s terénními poznámkami, záznamy o počasí nebo souběžnými nahrávkami.

Pokud detekce spadá na jiný kalendářní den než začátek Session (např. při noční Survey), připojí se k absolutnímu času přípona `+1d`, aby si pozorovatelé omylem nepletli zítřejší rozbřesk s dnešním.

Je-li vybrána možnost **Absolutní**, objeví se navíc přepínač **Zobrazovat sekundy v časových údajích**. Vypněte jej, pokud dáváte přednost úspornějšímu `08:42` před `08:42:17` — to se hodí při procházení dlouhých seznamů detekcí. Relativní odstupy vždy zobrazují sekundy, protože k synchronizaci s pozicí přehrávání ve spektrogramu je nutná sub-minutová přesnost.

Ukládání i export vždy používají časové okamžiky v UTC bez ohledu na toto nastavení, takže volba nikdy neovlivní vaše data — pouze způsob jejich zobrazení.

## Zvuk

Tyto ovládací prvky se objevují v živých pracovních postupech řízených zvukem.

### Zisk

Lineární zesílení aplikované na příchozí zvuk dříve, než dorazí ke spektrogramu a klasifikátoru. Ponechte na **1,0×**, pokud váš vstup není trvale příliš tichý — například lavalier mikrofon s vysokou impedancí na telefonu nebo USB rozhraní s příliš nízko nastaveným předzesilovačem. Zisk nad 1,0 zázračně neodhalí hlasy, které mikrofon nezachytil; pouze přeškáluje to, co mikrofon dodal, takže hlasité blízké zvuky mohou ořezávat. Hodnota pod 1,0 je užitečná ve vzácném případě, kdy příliš silný vstup zahlcuje spektrogram.

### High-pass filtr (Hz)

Odřízne nízkofrekvenční obsah před inferencí pomocí Butterworthova filtru 24 dB/oktávu — hodnota posuvníku je mez −3 dB. **0 Hz jej vypne.** Mez 100–200 Hz odstraní vítr, dunění dopravy a manipulační hluk, aniž by zasáhla většinu druhů; posun k 500–1000 Hz začne odstraňovat nízké houkání, sovy, tetřevy a dunění bukačů, takže tak vysoko jděte jen tehdy, když tyto druhy záměrně ignorujete výměnou za mnohem čistší spektrogram v hlučném městském prostředí. Zvolená mez by měla být na živém spektrogramu vidět jako ostrá vodorovná čára.

### Zdroj zvuku

Jediný panel se dvěma nezávislými ovladači: **Mikrofon** – který vstup nahrává – a **Zpracování** – nakolik smí telefon vstupní signál upravit. Lze je libovolně kombinovat, takže nahrávat z USB mikrofonu *nezpracovaně* je zcela platné nastavení. Vaše volba se pamatuje napříč spuštěními aplikace a stejný výběr se objevuje na obrazovkách přípravy Survey, Point Count i ARU. Změny se projeví okamžitě – i uprostřed nahrávání aplikace vymění mikrofon v běžící relaci, místo aby čekala na další.

**Mikrofon** jmenovitě uvádí každý vstup, který telefon nabízí: USB, kabelové i Bluetooth mikrofony a na řadě telefonů také jednotlivé vestavěné mikrofony (například *spodní* a *zadní*). Bezdrátové mikrofonní sady jako Rode Wireless GO nebo DJI Mic se připojují přes přijímač USB-C, takže se zde objeví jako běžná zvuková zařízení USB v plné kvalitě.

**Zpracování** je ta podstatná část a existuje **jen na Androidu**. Telefony ve výchozím stavu zpracovávají zvuk z mikrofonu DSP laděným na řeč – potlačení šumu, spektrální tvarování a automatické řízení zisku –, protože mikrofon slouží především k telefonování. Toto zpracování považuje ptačí zpěv za šum, který je třeba potlačit, a žádné běžné nastavení jej nevypne. Jediná cesta ven je požádat Android o jiný *zdroj zvuku*:

| Volba | Co dělá |
|---|---|
| **Výchozí telefonu** | To, co telefon dělá běžně, včetně hlasového zpracování. Původní chování a stále výchozí volba, aby se stávajícím uživatelům nic nezměnilo. |
| **Nezpracovaný** | Surový signál z mikrofonu – bez potlačení šumu a bez automatického řízení zisku. Pro ptáky obvykle nejlepší volba. |
| **Rozpoznávání řeči** | Rovněž vypíná potlačení šumu a automatické řízení zisku a funguje téměř na každém telefonu. |

**Vyzkoušejte je a porovnejte.** Která zvítězí, skutečně závisí na konkrétním přístroji. *Nezpracovaný* je ideál, ale Android jej respektuje jen na telefonech, jejichž výrobce podporu deklaruje – na ostatních tiše přepne na náhradu a zní stejně jako *Výchozí systému*. Právě proto existuje *Rozpoznávání řeči*: pravidla kompatibility Androidu **vyžadují**, aby u tohoto zdroje bylo automatické řízení zisku i potlačení šumu vypnuté, takže dodá nezpracovaný zvuk i na telefonech, které volbu *Nezpracovaný* ignorují. Pokud přepnutí na *Nezpracovaný* nic nezmění, přepněte na *Rozpoznávání řeči*.

Počítejte s tím, že nezpracované volby budou znít **tišeji** – to chybí automatické řízení zisku, není to závada. Pokud je ukazatel úrovně nízko, zvyšte **Zisk**.

**Na iOS** je ovladač Zpracování skrytý a panel je prostě seznam mikrofonů. iOS aplikaci předává v podstatě nezpracovaný zvuk, takže není z čeho obdobného vybírat.

## Inference

### Doba trvání okna

Řídí délku analyzačního okna. Dostupné kroky jsou **1**, **3**, **5**, **7**, **10** a **15** sekund.

### Práh spolehlivosti

Nastavuje, jak konzervativní by detekce měly být. Výchozí hodnota je **35 %**, což udržuje živý seznam zaměřený na silnější shody a zároveň ponechává prostor pro vzdálené nebo částečně překryté hlasy. Snižte ji, pokud mapujete vzácné nebo tiché druhy a plánujete více kandidátů posoudit později; zvyšte ji, když Session zahlcuje hluk pozadí nebo běžné falešné detekce.

### Citlivost

Posun na ose x aplikovaný na surová pravděpodobnostní skóre modelu před Score Pooling, geografickým filtrováním a kontrolou prahu spolehlivosti. Audiomodel BirdNET už obsahuje sigmoidovou aktivaci, takže BirdNET Live nejprve převede každou pravděpodobnost zpět do logitového prostoru, přičte bias citlivosti a potom ji převede zpět na pravděpodobnost. Vyšší hodnoty činí detektor tolerantnějším — slabší nebo nejednoznačnější hlasy překročí práh za cenu více falešných detekcí. Nižší hodnoty jsou přísnější a propouštějí jen jisté detekce. Výchozí hodnota **1,0** nepřidává žádný posun a odpovídá referenci BirdNET. Zkuste **1,25**, pokud máte podezření, že model přehlíží vzdálené hlasy; snižte na **0,75**, pokud vás zaplavují nekvalitní detekce běžných druhů. Citlivost se aplikuje za běhu: změna v průběhu Session se projeví v dalším inferenčním okně.

### Míra inference

Řídí, jak často BirdNET spouští inferenci. Posuvník používá stejné kroky **0,10–1,00 Hz** jako příprava Survey a ARU.

## Spektrogram

### Velikost FFT

Řídí frekvenční rozlišení ve spektrogramu.

### Barevná mapa

Vyberte **Viridis**, **Magma**, **Plasma**, **Cividis**, **Jet**, **Turbo**, **Stupně šedi** nebo **BirdNET**. **Turbo** je moderní duhová možnost podobná Jet.

### Délka (rychlost posouvání)

Řídí, kolik času je v okně spektrogramu viditelné.

### Frekvenční rozsah

Nastavuje horní zobrazovanou frekvenci.

### Logaritmická amplituda

Aplikuje na spektrogram logaritmické škálování pro snazší vizuální čtení.

### Kvalita

Řídí, jak hladce se obraz spektrogramu škáluje. **Střední** je výchozí vyvážená volba. Na starších telefonech zvolte **Nízká**, pokud se posouvání zasekává nebo se zařízení zahřívá; zvolte **Vysoká**, pokud chcete hladší zobrazení a zařízení má dostatečnou rezervu GPU. Intuice: mění se pouze náročnost vykreslování, nikoli analýza zvuku ani výsledky detekce.

## Hlasová oznámení

Tato sekce řídí, zda BirdNET Live **čte detekce nahlas do sluchátek nebo z reproduktoru telefonu**, zatímco Session nahrává. Celá funkce je **ve výchozím stavu vypnutá**, protože mění akustické prostředí kolem mikrofonu — její zapnutí je vědomý kompromis. Není zde žádný průvodce nastavením: výběry „podrobnost × četnost“ níže *jsou* celé nastavení, takže můžete kdykoli klepnout na jinou předvolbu a okamžitě uslyšet rozdíl. Intuice: při dlouhých Survey nemůžete neustále sledovat obrazovku; nenápadný hlas v uchu znamená, že můžete mít oči na stanovišti a přitom vědět, co se právě ozvalo.

### Číst detekce nahlas (hlavní přepínač)

Ve výchozím stavu vypnuto. Po zapnutí aplikace přečte každou přijatou detekci pomocí vestavěného převodu textu na řeč vašeho zařízení. **Důrazně doporučujeme sluchátka** — při použití reproduktoru telefonu hrozí, že mikrofon oznámení zachytí a znovu detekuje, takže aplikace kolem každého výroku rekordér krátce ztlumí, aby této smyčce zabránila (viz *Ztlumit mikrofon během mluvení* níže).

### Předvolba podrobnosti

Kolik toho aplikace o každé detekci řekne. **Minimální** přečte jen název druhu (nejlepší pro velmi dlouhé Survey, kde chcete jen signál). **Vyvážená** je výchozí — krátké, obměňované fráze jako *„Červenka“*, *„Slyšel jsem červenku“*, *„Znovu červenka“*. **Upovídaná** přidá trochu více kontextu a blíží se tomu, jako by vás někdo komentoval. **Vlastní** se objeví automaticky, pokud ručně upravíte pokročilé číselné hodnoty. Intuice: stejné nastavení omezování může působit buď příliš tiše, nebo příliš hlučně podle formulace — podrobnost vám umožní zachovat tempo a jen doladit upovídanost.

### Předvolba četnosti

Jak často smí aplikace vůbec mluvit. Pět kroků od nejtiššího po nejhovornější. **Vzácně** a **Řídce** čekají mezi oznámeními dlouho a omezují tempo — dobře se hodí pro několikahodinové Survey, kde chcete mít přehled o aktivitě bez nepřetržitého komentáře. **Normální** je výchozí konverzační tempo. **Často** zkrátí mezery a zvedne strop; vhodné pro krátké Live Sessions nebo když chcete zpětnou vazbu blíže reálnému času. **Neustále** zcela odstraní úvodní prodlevu a nechá aplikaci mluvit téměř při každém detekčním cyklu — užitečné pro ukázky, přístupnost nebo kdykoli vám prodleva před prvním oznámením v režimu *Často* připadá příliš dlouhá. **Vlastní** se objeví, když změníte časové hodnoty v Pokročilém nastavení. Intuice: tohle je ten jeden ovladač, který rozhoduje, zda aplikace zůstane v pozadí, nebo se stane přítomným společníkem — klepněte na jinou předvolbu a nové tempo uslyšíte během dalšího detekčního cyklu, bez nutnosti cokoli ukládat.

### Hlas (rychlost a výška)

Dva posuvníky, které upravují hlas platformního TTS. **Rychlost** je v rozsahu 0,5×–1,5×; výchozí 1,0× je „normální“ tempo platformy. **Výška** je v rozsahu 0,7×–1,3×. Intuice: mírné snížení výšky a malé zpomalení mohou výrazně usnadnit porozumění oznámením venku, kde v pozadí šumí vítr nebo tekoucí voda; tlačítko *Přehrát ukázku* níže přehraje tři běžné názvy ptáků s aktuálním nastavením, takže můžete ladit bez opuštění obrazovky.

### Pokročilé

Rozbalovací sekce, která odhalí několik přepínačů směrování zvuku a výběr režimu spouštění. Obvykle ji nemusíte otevírat — předvolby podrobnosti a četnosti výše jsou jediné ovladače, na kterých denně záleží. Číselné hodnoty omezování tempa (úvodní prodleva, minimální mezera, maximum za minutu, ztišení při sérii, reset nedávnosti) jsou zabaleny do posuvníku **Četnost**, takže je jedno zřejmé místo, kde tempo zvýšit nebo snížit.

- **Povolit reproduktor telefonu** — Je-li vypnuto, oznámení se tiše přeskočí, pokud nejsou připojena sluchátka ani externí reproduktor. Je-li zapnuto, použije se jako záloha reproduktor telefonu. Zapněte při ležérním poslechu doma; v terénu nechte vypnuté, abyste zaručili, že se do mikrofonu nedostane akustická zpětná vazba.
- **Ztlumit mikrofon během mluvení** — Nahradí příchozí zvuk tichem, dokud aplikace mluví, aby výstup z reproduktoru nemohl být zachycen mikrofonem a znovu detekován. Vřele doporučeno (a výchozí). Vypněte jen tehdy, pokud je váš mikrofon akusticky oddělen od reproduktoru telefonu — například klopový mikrofon na zvláštním kabelu nebo Bluetooth headset.
- **Ztišit ostatní zvuk** — Během oznámení krátce sníží hlasitost hudby nebo podcastů z jiných aplikací a poté ji obnoví. Ve výchozím stavu zapnuto. Vypnuto přehrává v plné hlasitosti.
- **Signální tón před mluvením** — Před každým výrokem přehraje krátký tichý tón, aby vaše ucho mělo chvíli na přepnutí z pasivního poslechu na vnímání hlasu. Ve výchozím stavu zapnuto. Zvlášť užitečné, když jsou oznámení řídká nebo když máte v pozadí hudbu.
- **Co oznamovat** — Vybírá, které detekce vůbec připadají v úvahu k oznámení. *Každou detekci* (výchozí) ponechá rozhodnutí na omezování. *Poprvé v Session* oznámí druh jen při jeho prvním výskytu v aktuální Session. *Pouze sledované* omezí oznámení na druhy z vašeho seznamu sledovaných (užitečné u cílené práce v Survey, kde chcete slyšet jen své prioritní taxony a nic jiného).

## Nahrávání

### Režim

- **Plný** — uloží celou nahrávku
- **Pouze detekce** — uloží klipy kolem detekcí
- **Vypnuto** — žádný záznam zvuku

### Kontext klipu

Když je aktivní **Pouze detekce**, aplikace zobrazí jeden posuvník **Kontext klipu** (0–5 s), který nastavuje, kolik zvuku se zachová na **obou stranách** každé detekce. Každý klip je dlouhý `analyzační okno + 2 × kontext klipu`, takže při 3s analyzačním okně a výchozím 1s kontextu je uložený klip 5 s. Nastavení kontextu na 2 s dá 7s klip (2 s před + 3 s analyzovaný zvuk + 2 s po). Větší hodnoty vám dají více prostoru pro vizuální kontrolu nebo externí nástroje za cenu místa na disku; hodnota 0 uloží jen samotné analyzované okno.

### Formát

Vyberte **WAV** nebo **FLAC**. WAV je větší, ale široce kompatibilní a rychlý k prohlížení. FLAC zachovává stejnou bezztrátovou kvalitu zvuku při menší spotřebě úložiště, což je obvykle lepší pro dlouhé Sessions.

Toto nastavení platí pro zvuk nahraný BirdNET Live. **Analýza souborů** udržuje aplikací spravovanou kopii importovaného souboru v původním formátu, takže nahrané MP3, AAC, WAV i FLAC zůstanou prohlížitelné bez kroku konverze navíc.

### Automatické spuštění nahrávání (pouze režim Live)

Je-li zapnuto, režim Live začne nahrávat hned po otevření obrazovky a dokončení načtení modelu — bez nutnosti klepnout na tlačítko mikrofonu. Užitečné pro kioskové nasazení, hands-free použití (např. upevnění zařízení v terénu) nebo jakýkoli postup, kde uživatel již ví, že otevření Live vždy znamená „začni teď“. Ve výchozím stavu vypnuto, aby náhodné klepnutí na dlaždici Live na domovské obrazovce tiše nespustilo Session. Automatické spuštění se aktivuje jen jednou na každou návštěvu obrazovky, takže zastavení Session a opětovné klepnutí na mikrofon stále funguje jako ruční restart.

Toto nastavení se týká otevření režimu Live z aplikace. [Widget „Rychlý poslech“](live-mode.md) po klepnutí spustí poslech bez ohledu na toto nastavení a nijak je nemění. Pokud již běží nebo se spouští Session Point Count, Survey, File Analysis nebo režimu ARU, zachová ji a místo toho vás vyzve, abyste ji nejprve zastavili.

## Poloha

### Použít GPS

Místo ručních souřadnic použijte GPS zařízení.

### Ruční souřadnice

Souřadnice použité, když je **Použít GPS** vypnuto. Zeměpisná šířka i délka jsou editovatelná textová pole, takže můžete přesnou hodnotu **napsat** nebo **vložit** zkopírovanou z jiné aplikace — mnohem přesněji než taháním posuvníku na dotykové obrazovce. Zadejte desetinné stupně (např. `52.5200` a `13.4050`). Do *kteréhokoli* pole můžete také vložit spojený řetězec `šířka, délka` (oddělený čárkou, středníkem nebo mezerou) a obě pole se vyplní naráz, což odpovídá tomu, co většina map a webů ukládá do schránky. Hodnoty mimo rozsah nebo nečíselné se rovnou označí a neuloží; platné hodnoty se zachovávají při psaní. Intuice: nejčastějším důvodem k nastavení ruční polohy je určit zvuk nahraný jinde, než kde jste teď, a tato poloha obvykle přichází jako text odjinud — psaní a vkládání z toho dělají jeden přesný krok.

### Obnovit GPS nyní

Vynutí čerstvé určení polohy místo opětovného použití poslední hodnoty uložené v mezipaměti. Intuice: vyhledání GPS se ukládá do mezipaměti pro každou obrazovku, aby obrazovka přípravy nemusela při každém otevření čekat na satelitní určení, ale tato mezipaměť může být míle stará, pokud jste od poslední Session přejeli na nové místo. Klepněte na toto, když jste se přesunuli a chcete, aby geofiltr použil *tady*, ne místo, kde jste začínali ráno. Aktuální souřadnice z mezipaměti jsou zobrazeny v podtitulku, takže si můžete ověřit, kde si aplikace myslí, že jste. Pokud GPS nezíská určení do ~10 sekund, aplikace se vrátí k poslední známé poloze poskytnuté OS a upozorní vás snackbarem, abyste věděli, že hodnota je zastaralá.

### Offline stahování map

Offline stahování map je v současnosti skryto, dokud BirdNET Live používá veřejnou dlaždicovou službu OpenStreetMap. OpenStreetMap podporuje běžné interaktivní procházení map s uvedením zdroje, jasným user-agentem a lokálním ukládáním do mezipaměti, ale neumožňuje hromadné přednačítání ani funkce offline stahování map z `tile.openstreetmap.org`. Implementace stahovače je ponechána pro budoucí zdroj dlaždic, který offline balíčky výslovně povolí.

### Filtr druhů

- **Vypnuto** — žádné geografické filtrování
- **Filtr lokality** — vyloučí druhy, které spadají pod geografický práh
- **Vážení polohy** — použije geomodel jako doplňkový vážicí signál

### Práh geofiltru

Objeví se, když je aktivní režim filtru podle polohy.

## Export a synchronizace

### Formáty

Zaškrtněte libovolnou kombinaci exportních formátů — každé uložení / sdílení sbalí všechny vybrané formáty dohromady do jediného ZIPu. Zvolíte-li jediný formát bez audio klipů a bez HTML reportu, dostanete kvůli zpětné kompatibilitě syrový soubor (např. `session.csv`) místo ZIPu:

- Raven Selection Table — pro použití v Cornell Raven Pro.
- CSV — otevře se v jakémkoli tabulkovém procesoru.
- JSON — nejvhodnější pro programové zpracování; nese kompletní metadata jednotlivé Session.
- GPX — trasa a trasové body pro mapové nástroje (smysluplné jen, když bylo GPS zapnuté).

Intuice: mnoho pracovních postupů potřebuje více formátů zároveň — CSV do tabulky, Raven tabulku pro desktopový review a JSON pro analytický skript. Dříve to znamenalo exportovat tutéž Session třikrát; teď zaškrtnete všechny tři najednou a putují do ZIPu společně.

### Zahrnout zvukové soubory

Zahrne uložený zvuk vedle exportovaných tabulek nebo metadat, pokud to pracovní postup exportu podporuje.

### Zahrnout metadata aplikace

Je-li zapnuto, export ZIP nese vedlejší soubor `*.metadata.json` popisující, jak byla Session vytvořena: verze BirdNET Live, identita modelu, snapshot počasí zachycený na začátku Session a případná varování o integritě zvuku zjištěná během nahrávání. Intuice: tento původ je to, co vám (nebo recenzentovi) umožní Session o měsíce později reprodukovat nebo auditovat. Vypněte, když chcete čistě sdílet jen zvuk a vybrané formáty — například vložit jediný WAV do iNaturalist nebo eBird bez přibalených souborů specifických pro aplikaci.

### Zahrnout HTML report

Je-li zapnuto, každý export ZIP obsahuje vedle tabulky, audio klipů a GPX také soubor `report.html`. Otevřete jej v libovolném webovém prohlížeči a získáte tiskově připravený souhrn Session: záhlaví s datem, polohou, pozorovatelem a součty; interaktivní mapu GPS trasy a značek detekcí; kartu pro každou detekci s náhledem z taxonomie Cornell, názvy, štítkem skóre, vaším potvrzením, případnou poznámkou, kterou jste napsali, a původním audio klipem vloženým jako přehrávač; a použitá nastavení analýzy. Intuice: CSV je skvělé pro analytické pipeline, ale nepoužitelné pro sdílení s netechnickým spolupracovníkem nebo pro rychlý tištěný terénní souhrn — HTML report tuto mezeru zaplní jedním klepnutím. Náhledy druhů a mapové dlaždice potřebují připojení při prvním otevření souboru (načítají se živě z taxonomického API BirdNET a z OpenStreetMap), ale vše ostatní — text, rozvržení, přehrávání zvuku, odkazy — funguje plně offline. Vypněte, pokud potřebujete jen surová data a chcete ZIP udržet o pár KB menší.

### Sdílení pouze zvuku

Odškrtněte všechny formáty **i** HTML report **i** pole metadat aplikace, aby zůstalo jen **Zahrnout zvukové soubory**, a Sdílet předá systémovému panelu surovou nahrávku (např. `BirdNET_Live_…flac`) místo ZIPu. To je nejjednodušší cesta, jak Session poslat rovnou do iNaturalist, eBird nebo jakékoli jiné aplikace, která chce nezabalený zvukový soubor. Sessions tvořené detekčními klipy (bez celé nahrávky) stále vytvoří ZIP, protože je třeba sdílet více souborů.

## Soukromí

Tato sekce řídí, **které externí služby třetích stran smí BirdNET Live kontaktovat vaším jménem**. Samotná inference běží zcela na vašem zařízení — tyto přepínače řídí pouze volitelné síťové funkce, které obohacují zážitek. Všechny tři přepínače jsou při čisté instalaci **standardně vypnuté**; nic se neodešle, dokud to nedovolíte. Intuice: každý přepínač pokrývá právě jednu konkrétní službu a jeden konkrétní přínos, takže si zapnete přesně to, co je pro váš postup užitečné, a nic jiného.

### Povolit mapové dlaždice

Vyžadováno pro každou interaktivní mapu v aplikaci (výběr polohy, živá mapa Survey a mapa Session). Je-li zapnuto, mapové prvky stahují rastrové dlaždice z veřejných serverů **OpenStreetMap**; požadavky o souřadnice dlaždic prozrazují, kterou oblast světa právě prohlížíte. Dlaždice se ukládají do lokální mezipaměti až na šest měsíců, s limitem 6000 dlaždic, aby opakované zobrazení map zůstalo efektivní a mezipaměť nerostla bez omezení. Zapnutí tohoto přepínače zároveň zapne **Povolit vyhledávání názvu místa**, protože většina uživatelů, kteří načítají mapy, očekává, že se u Sessions zobrazí i čitelné názvy míst. Vyhledávání názvu místa lze následně vypnout zvlášť. Když jsou mapové dlaždice vypnuté, každá mapová obrazovka se vrátí k zástupné kartě, takže zbytek aplikace funguje i bez síťového úniku.

### Povolit vyhledávání názvu místa

Je-li zapnuto, aplikace odešle vaše zaznamenané souřadnice službě **Nominatim** od OpenStreetMap, aby získala krátký název místa (např. *„Berlín, Německo“*) zobrazený vedle Session v Knihovně Sessions a v Přehledu Session. Intuice: numerické souřadnice jsou přesné, ale špatně se čtou při procházení dlouhého seznamu Sessions — název místa promění seznam v něco, co přečtete na první pohled. Když je vypnuto, Sessions ukazují jen surové lat/lon a Nominatim není nikdy kontaktován.

### Povolit vyhledávání počasí

Je-li zapnuto, každá uložená Session zachytí jednorázový snapshot místních podmínek (teplota, srážky, vítr, oblačnost) na souřadnicích záznamu a v čase ukončení prostřednictvím služby **Open-Meteo**. Snapshot se objeví v Přehledu Session pod řádkem polohy a propíše se do JSON exportu, bloku metadat jednotlivé Session a HTML reportu. Intuice: počasí je jedním z nejsilnějších prediktorů ptačí aktivity a jeho automatické zachycení — aniž byste museli pamatovat na kontrolu v jiné aplikaci — dělá z každé Session úplnější záznam. Open-Meteo je bezplatná služba a nevyžaduje účet ani API klíč. Když je vypnuto, žádná data o počasí se nestahují ani neukládají. Příprava Point Count a Survey také zobrazuje kompaktní kartu počasí poblíž ovládacích prvků polohy: o souhlas žádá jen tehdy, když je potřeba, po zapnutí ukáže náhled výsledku jako ikona + teplota + vítr a při uložení Session znovu použije stejný snapshot z mezipaměti.

## O aplikaci

Řádek **O aplikaci** otevře obrazovku O aplikaci v aplikaci.

## Nebezpečná zóna

### Obnovit úvodní průvodce

Při příštím spuštění aplikace znovu zobrazí úvodní průvodce.

### Obnovit všechna nastavení

Vrátí každou předvolbu na této obrazovce na výchozí hodnotu. Sessions, nahrávky, hlasové poznámky, exporty a mapové dlaždice v mezipaměti zůstanou nedotčené — vymažou se jen uložené předvolby (posuvníky, přepínače, volby výběru). Aplikace se po potvrzení zavře, aby se nové výchozí hodnoty projevily při příštím spuštění.

Užitečné, když si nejste jisti, který posuvník jste posunuli a tím něco rozbili, nebo když předáváte zařízení někomu jinému a chcete čistou konfiguraci bez ztráty nasbíraných dat.

### Vymazat všechna data

Trvale smaže Sessions, detekce, nahrávky, hlasové poznámky, vlastní seznamy druhů, uložené předvolby a data v mezipaměti pro mapy, názvy míst, počasí, přehrávání, přehled a sdílení. Potvrzovací dialog vyžaduje zadání `DELETE` a poté aplikaci zavře, aby další spuštění začalo s čistým místním stavem.

Použijte před předáním zařízení jinému pozorovateli, vyřazením terénního telefonu nebo odstraněním historie navázané na polohu z aplikace. Vše, co potřebujete, nejprve exportujte; tuto akci nelze vrátit zpět.

## Parametry specifické pro pracovní postup mimo nastavení

Některé parametry se konfigurují na vlastních obrazovkách přípravy, nikoli na sdílené obrazovce Nastavení.

- [Režim Point Count](point-count-mode.md) má vlastní nastavení doby trvání a polohy.
- [Režim Survey](survey-mode.md) má vlastní obrazovku s parametry Survey.
- [Analýza souborů](file-analysis.md) má vlastní krok parametrů analýzy.
