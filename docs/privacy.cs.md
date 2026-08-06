# Zásady ochrany osobních údajů pro BirdNET Live

**Poslední aktualizace:** 6. srpna 2026

Tyto zásady ochrany osobních údajů se vztahují na **BirdNET Live** (dále jen **aplikace**). Aplikaci vyvíjí a nabízí **BirdNET-Team** (dále jen **vývojář** nebo **my**).

## Identita aplikace a vývojáře

| | |
|---|---|
| **Název aplikace** | BirdNET Live |
| **Název vývojáře** | BirdNET-Team |
| **Kontakt pro ochranu soukromí** | [ccb-birdnet@cornell.edu](mailto:ccb-birdnet@cornell.edu) |

BirdNET-Team poskytuje tyto zásady vlastním jménem. Vysvětlují, jak BirdNET Live chrání osobní údaje a nakládá s nimi.

## Zpracování na zařízení

Veškerá analýza zvuku a identifikace ptačích druhů probíhá **zcela ve vašem zařízení**. Aplikace využívá dva modely neuronových sítí spouštěné lokálně:

- **Zvukový klasifikátor BirdNET+** — analyzuje zvuk z mikrofonu a identifikuje ptačí druhy.
- **Geomodel BirdNET** — předpovídá, jaké druhy se s největší pravděpodobností vyskytují ve vaší lokalitě a v daném ročním období.

Žádná zvuková data nejsou nikdy přenášena na externí servery.

## Nakládání s osobními údaji

BirdNET-Team neprovozuje backend aplikace a prostřednictvím BirdNET Live nepřijímá vaše nahrávky, polohu, data Session ani jiné osobní údaje. Aplikace nemá uživatelské účty, reklamu, analytiku, sledování ani telemetrii. Zvuk a polohu zpracovává ve vašem zařízení a pouze po zapnutí volitelné síťové funkce odešle údaje popsané v části **Externí zdroje** přímo uvedenému poskytovateli třetí strany.

### Data uložená lokálně ve vašem zařízení:

| Typ dat | Účel | Úložiště |
|-----------|---------|---------|
| Zvukové nahrávky | Identifikace ptáků, přehrávání, export | Lokální soubory |
| Výsledky detekce | Druhy, spolehlivost, časové značky | Lokální JSON soubory Sessions |
| GPS souřadnice | Geotagging detekcí, trasy Survey, geomodel | Lokální JSON soubory Sessions |
| Metadata Session | Historie, kontrola, export | Lokální JSON soubory Sessions |
| Snapshot počasí (volitelný) | Jednorázový záznam teploty, srážek, větru, oblačnosti a kódu počasí na Session, když je **Povolit vyhledávání počasí** zapnuto | Lokální JSON soubory Sessions |
| Nastavení | Uživatelské předvolby | SharedPreferences |

### Přibalená offline data

Obrázky druhů, popisy a taxonomická data jsou **přibalena v aplikaci** a načítají se z lokálních souborů. Pro informace o druzích nejsou prováděny žádné síťové požadavky.

## Externí zdroje

Aplikace může přistupovat k následujícím externím zdrojům. Každý zdroj je gatovaný nezávislým přepínačem v **Nastavení → Soukromí**, a **všechny tři jsou při čisté instalaci standardně vypnuté**. Nic neopustí vaše zařízení, dokud to neschválíte.

| Zdroj | Účel | Přepínač | Odesíláno v každé žádosti |
|-------|------|----------|---------------------------|
| Mapové dlaždice (OpenStreetMap Foundation) | Základní mapa pro výběr polohy, živou mapu Survey a mapu Session | **Nastavení → Soukromí → Povolit mapové dlaždice** | Souřadnice dlaždice `(z, x, y)`, vaše IP adresa jako součást síťového spojení a user-agent BirdNET Live |
| Reverzní geokódování (Nominatim nadace OpenStreetMap Foundation) | Převod GPS souřadnic na název místa (např. „Berlín, Německo“) | **Nastavení → Soukromí → Povolit vyhledávání názvu místa** | Zeměpisná šířka/délka Session, vaše IP adresa jako součást síťového spojení a user-agent BirdNET Live |
| Snapshot počasí (OpenMeteo GmbH) | Jednorázové zachycení lokálních podmínek (teplota, srážky, vítr, oblačnost, kód počasí WMO) na souřadnicích a koncovém čase | **Nastavení → Soukromí → Povolit vyhledávání počasí** | Zeměpisná šířka/délka a koncový čas Session, vaše IP adresa jako součást síťového spojení a user-agent BirdNET Live |

Požadavky na mapové dlaždice jsou HTTPS GET na `tile.openstreetmap.org`. Souřadnice dlaždic určují zobrazenou oblast mapy. Jako každý přímý internetový požadavek také zpřístupní poskytovateli vaši IP adresu.

Reverzní geokódování odesílá lat/lon Session na `nominatim.openstreetmap.org` přes HTTPS spolu s user-agentem BirdNET Live dle [Pravidel užívání Nominatim](https://operations.osmfoundation.org/policies/nominatim/). Výsledný název místa je uložen lokálně se Session, takže se každá Session geokóduje pouze jednou.

Požadavky na počasí odesílají lat/lon Session a koncový čas na `api.open-meteo.com` přes HTTPS s user-agentem BirdNET Live. [Open-Meteo](https://open-meteo.com/) je bezplatná služba a nevyžaduje účet ani API klíč. Výsledný snapshot počasí je uložen lokálně se Session a také zapsán do JSON exportu, bloku `metadata.json` dané Session a HTML reportu.

**Zpracování a uchovávání třetími stranami:** BirdNET-Team tyto služby neprovozuje a nepřijímá data z jejich požadavků. OpenStreetMap Foundation může zpracovávat údaje o přístupu k síti a podrobnosti požadavků podle svých [zásad ochrany osobních údajů](https://osmfoundation.org/wiki/Privacy_Policy). Open-Meteo uvádí, že protokoly bezplatného API mohou obsahovat IP adresy a zeměpisné souřadnice a jsou po 90 dnech smazány; viz [Podmínky a soukromí](https://open-meteo.com/en/terms). Poskytovatelé mohou údaje zpracovávat v jiných zemích. Vrácené hodnoty se uloží lokálně do Session a do exportu se dostanou pouze tehdy, když jej vytvoříte.

**Odvolání:** kteroukoli ze tří služeb můžete kdykoliv vypnout v **Nastavení → Soukromí**. Již uložené názvy míst a snapshoty počasí zůstávají u Sessions, kde byly zachyceny. Tato historická data odstraníte smazáním dotčených Sessions v Knihovně Sessions nebo pomocí **Nastavení → Nebezpečná zóna → Vymazat všechna data**.

**Žádné další síťové požadavky se neprovádějí.** Aplikace funguje plně offline.

## Externí odkazy

BirdNET Live obsahuje odkazy na webové stránky třetích stran, které můžete otevřít — například stránky druhu na **eBird**, **iNaturalist** a **Wikipedii** a zvukový odkaz *„Poslechněte si tento druh na eBird“* v zobrazení druhu, dále odkazy na web projektu BirdNET, zdrojový kód, uživatelskou příručku a stránku pro dary v obrazovce **O aplikaci**. Odkazy, které opouštějí aplikaci, jsou označeny ikonou externího odkazu (↗), abyste je před klepnutím poznali.

Dokud je odkaz pouze zobrazen, nic se neodesílá a žádný externí odkaz se nikdy neotevře automaticky — prohlížeč se otevře, až když na něj klepnete. Odkaz se poté otevře ve výchozím prohlížeči vašeho zařízení a opustíte BirdNET Live. Cílový web provozuje třetí strana a řídí se **jejími vlastními** zásadami ochrany soukromí a podmínkami, nikoli těmito. Takové weby mohou nezávisle shromažďovat informace o vaší návštěvě — například vaši IP adresu, údaje o zařízení či prohlížeči a způsob, jakým jejich stránky používáte — a mohou nastavovat vlastní soubory cookie. Obsah ani nakládání s daty externích webů nemáme pod kontrolou a neneseme za ně odpovědnost; přečtěte si prosím zásady ochrany soukromí každého webu.

## GPS a Poloha

Aplikace používá polohu GPS pro:

- **Filtrování druhů** — předpověď, které druhy se pravděpodobně vyskytují ve vaší lokalitě.
- **Režim Survey** — záznam GPS tras a geotagging detekcí podél transektu.
- **Režim Point Count** — označení místa pozorování.

Data GPS jsou uložena lokálně a do exportů jsou zahrnuta pouze tehdy, když Session výslovně sdílíte nebo exportujete. Přístup k poloze vyžaduje vaše povolení a lze jej kdykoliv odvolat v nastavení systému.

## Export dat

Data Session lze exportovat ve více formátech (Raven Selection Tables, CSV, JSON, GPX); pod **Nastavení → Export → Formáty** můžete zaškrtnout libovolnou kombinaci formátů naráz. Vybrané formáty jsou sbaleny do jediného ZIPu spolu s audio klipy a volitelným samostatným HTML reportem. Exporty se generují lokálně a sdílejí přes systémový panel sdílení. Aplikace nenahrává žádná exportovaná data na server.

## Smazání dat

Jednotlivé Sessions a jejich nahrávky lze odstranit v Knihovně Sessions. Pro místní vymazání Sessions, nahrávek, hlasových poznámek, vlastních seznamů druhů, nastavení a mezipamětí BirdNET Live přímo v aplikaci použijte **Nastavení → Nebezpečná zóna → Vymazat všechna data**. Úložiště aplikace BirdNET Live můžete také vymazat v nastavení operačního systému nebo aplikaci odinstalovat.

## Kontakt

Otázky ohledně soukromí: [ccb-birdnet@cornell.edu](mailto:ccb-birdnet@cornell.edu)
