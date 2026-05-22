# Nastavení

BirdNET Live opakovaně používá jednu obrazovku Nastavení pro více pracovních postupů. Tlačítko :material-tune: otevírá sekce, které jsou relevantní pro obrazovku, ze které jste přišli.

## Jak funguje rozsah nastavení

- Otevřením Nastavení z plochy se zobrazí celá obrazovka.
- Otevřením Nastavení z Live, Survey, Point Count nebo File Analysis filtruje obrazovku na příslušné sekce.

## Generál

### Téma

Vyberte **Tmavý**, **Světlý** nebo **Systém**.

### Jazyk aplikace

Nastaví jazyk rozhraní.

### Názvy druhů

Řídí jazyk používaný pro názvy druhů. **Následovat jazyk aplikace** používá stejný jazyk jako rozhraní, pokud je tento název k dispozici.

### Zobrazit vědecká jména

Zobrazuje vědecká jména pod běžnými názvy v celé aplikaci.

### Zobrazení času

Určuje, jak se v přehledu sezení zobrazují časy jednotlivých detekcí.

- **Relativní** ukáže odstup od začátku nahrávání, např. `00:12:34`. Hodí se pro procházení jedné sezení a synchronizaci se spektrogramem.
- **Absolutní** ukáže místní čas detekce, např. `08:42:17`. Hodí se k porovnání s terénními poznámkami, meteorologickými záznamy nebo jinými nahrávkami.

Pokud detekce spadá na jiný kalendářní den než začátek sezení (např. při nočním sledování), připojí se k absolutnímu času přípona `+1d`, aby si recenzenti omylem nepletli zítřejší rozbřesk se dnešním.

Když je vybrána **Absolutní**, objeví se navíc přepínač **Zobrazovat sekundy v časových údajích**. Vypněte ho, pokud dáváte přednost úspornějšímu `08:42` před `08:42:17` — hodí se při procházení dlouhých seznamů detekcí. Relativní odstupy vždy zobrazují sekundy, protože k synchronizaci se spektrogramem je nutná sub-minutová přesnost.

Když je vybrána **Absolutní**, objeví se navíc přepínač **Zobrazovat sekundy v časových údajích**. Vypněte ho, pokud dáváte přednost úspornějšímu `08:42` před `08:42:17` — hodí se při procházení dlouhých seznamů detekcí. Relativní odstupy vždy zobrazují sekundy, protože k synchronizaci se spektrogramem je nutná sub-minutová přesnost.

Ukládání i export vždy používají UTC bez ohledu na toto nastavení, takže volba nikdy neovlivní vaše data — pouze způsob jejich zobrazení.

## Zvuk

Tyto ovládací prvky se objevují v živých pracovních postupech řízených zvukem.

### Zisk

Upravuje vstupní zisk zobrazený v aplikaci. Toto použijte pouze v případě, že potřebujete kompenzovat velmi tiché nahrávky nebo vstupy.

### High-pass filtr (Hz)

Snižuje nízkofrekvenční dunění před inferencí.

### Mikrofon

Umožňuje vybrat konkrétní vstupní zařízení nebo zachovat **Výchozí nastavení systému**.

## Úsudek

### Doba trvání okna

Řídí délku okna analýzy.

### Práh spolehlivosti

Nastavuje, jak konzervativní by měly být detekce.

### Citlivost

Vyšší hodnoty činí detektor tolerantnějším, což může obnovit slabší hovory za cenu více falešných poplachů.

### Míra inference

Řídí, jak často BirdNET spouští odvození.

### Sdružování skóre

Řídí, jak jsou kombinována překrývající se okna analýzy.

## Spektrogram

### Velikost FFT

Řídí frekvenční rozlišení ve spektrogramu.

### Barevná mapa

Vyberte **Viridis**, **Magma** nebo **Stupně šedi**.

### Délka (rychlost posouvání)

Řídí, kolik času je viditelné v okně spektrogramu.

### Frekvenční rozsah

Nastavuje horní frekvenci zobrazení.

### Zaznamenat amplitudu

Aplikuje logaritmické škálování na spektrogram pro snadnější vizuální čtení.

## Nahrávání

### Režim

- **Full** — uložení celé nahrávky
- **Pouze detekce** – uložte klipy kolem detekcí
- **Vypnuto** – žádný záznam zvuku

### Kontext klipu

Když je aktivní **Pouze detekce**, aplikace zobrazí jeden posuvník **Kontext klipu** (0–5 s), který nastavuje, kolik zvuku se zachová na **obou stranách** každé detekce. Každý klip je dlouhý „okno analýzy + 2 × kontext klipu“, takže při 3s okně analýzy a výchozím 1s kontextu je uložený klip 5 s. Nastavení kontextu na 2 s poskytne 7s klip (2 s před videem + 3 s analyzovaný zvuk + 2 s po přehrání). Větší hodnoty vám poskytují více prostoru pro vizuální kontrolu nebo externí nástroje pro kontrolu za cenu místa na disku; 0 uloží pouze samotné analyzované okno.

### Formát

Vyberte **WAV** nebo **FLAC**.

## Místo

### Použijte GPS

Místo ručních souřadnic použijte GPS zařízení.

### Zeměpisná šířka/délka

Manuální souřadnice používané, když je vypnuta GPS.

### Filtr druhů

- **Vypnuto** – žádné geografické filtrování
- **Filtr lokality** – vyloučí druhy, které spadají pod geografický práh
- **Vážení polohy** – použijte geomodel jako dodatečný signál vážení

### Prahová hodnota geografického filtru

Zobrazuje se, když je aktivní režim filtru podle polohy.

## Export a synchronizace

### Formáty

Zaškrtněte libovolnou kombinaci výstupních formátů — každé uložení / sdílení sbalí všechny vybrané formáty dohromady do jediného ZIPu. Pokud zvolíte jediný formát bez audioklipů a bez HTML reportu, dostanete kvůli zpětné kompatibilitě syrový soubor (např. `session.csv`):

- Tabulka výběru Raven — pro Cornell Raven Pro.
- CSV — otevře se v jakémkoli tabulkovém procesoru.
- JSON — nejvhodnější pro programové zpracování; nese kompletní metadata relace.
- GPX — trasa a trasové body pro mapové aplikace (smysluplné jen, když bylo aktivní GPS).

Intuice: spousta workflow potřebuje více formátů zároveň — CSV do tabulky, Raven tabulku pro desktopový review a JSON pro analytický skript. Dříve to znamenalo exportovat tutéž relaci třikrát; teď zaškrtnete všechny tři najednou a putují do ZIPu společně.

### Zahrnout zvukové soubory

Zahrňte uložený zvuk vedle exportovaných tabulek nebo metadat, pokud to pracovní postup exportu podporuje.

## Soukromí

Tato sekce řídí, **které externí služby smí BirdNET Live kontaktovat vaším jménem**. Samotná inference běží zcela na vašem zařízení — tyto přepínače řídí pouze volitelné síťové funkce. Všechny tři přepínače jsou při čisté instalaci **standardně vypnuté**; nic se nenahraje, dokud to neschválíte. Intuice: každý přepínač pokrývá právě jednu službu a jeden konkrétní přínos, takže si zapnete přesně to, co potřebujete.

### Povolit mapové dlaždice

Vyžadováno pro každou interaktivní mapu (výběr polohy, živá mapa Survey, mapa relace). Když je zapnuto, mapové prvky stahují rastrové dlaždice z veřejných serverů **OpenStreetMap**; požadavky o souřadnice dlaždic prozrazují, kterou oblast světa právě prohlížíte. Když je vypnuto, všechny mapové obrazovky zobrazí zástupný panel.

### Povolit vyhledávání názvu místa

Když je zapnuto, aplikace odesílá vaše souřadnice službě **Nominatim** OpenStreetMap, aby získala krátký název místa (např. „Berlín, Německo“) zobrazený vedle relace v Knihovně relací a v Přehledu relace. Intuice: numerické souřadnice jsou přesné, ale špatně se čtou ve dlouhém seznamu — název místa zlistuje seznam srozumitelný na první pohled. Když je vypnuto, ukazují se jen hrubé souřadnice a Nominatim nikdy není kontaktován.

### Povolit vyhledávání počasí

Když je zapnuto, každá uložená relace zachytí jednorázovou momentku místních podmínek (teplota, srážky, vítr, oblačnost) na souřadnicích záznamu a v čase ukončení prostřednictvím **Open-Meteo**. Momentka se objeví v Přehledu relace pod řádkem polohy a propíše se do JSON exportu, metadatového bloku a HTML reportu. Intuice: počasí je jeden z nejsilnějších prediktorů ptačí aktivity; jeho automatický záznam dělá z každé relace úplnější dokument. Open-Meteo je zdarma a nevyžaduje účet ani API klíč. Když je vypnuto, žádná data o počasí se nestahují ani neukládají.

## O

Řádek **O aplikaci** otevře obrazovku O aplikaci v aplikaci.

## Nebezpečná zóna

### Resetovat registraci

Při příštím spuštění aplikace znovu zobrazí vstupní sekvenci.

### Vymazat všechna data

Trvale smaže relace, detekce, nahrávky, hlasové poznámky, vlastní seznamy druhů, uložená nastavení a data v mezipaměti pro mapy, názvy míst, počasí, přehrávání, revizi a sdílení. Potvrzovací dialog vyžaduje zadání `DELETE` a poté aplikaci zavře, aby další spuštění začalo s čistým místním stavem.

Použijte tuto volbu před předáním zařízení jinému pozorovateli, vyřazením terénního telefonu nebo odstraněním historie navázané na polohu z aplikace. Vše, co potřebujete, nejprve exportujte; tuto akci nelze vrátit zpět.

## Parametry specifické pro pracovní postup mimo nastavení

Některé parametry se konfigurují na vlastních obrazovkách nastavení, nikoli na obrazovce sdílených nastavení.

- [Point Count Mode] (point-count-mode.md) má své vlastní nastavení doby trvání a umístění.
- [Survey Mode] (survey-mode.md) má vlastní obrazovku s parametry průzkumu.
- [File Analysis] (file-analysis.md) má svůj vlastní krok analýzy parametrů.