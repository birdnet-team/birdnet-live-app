# Zásady ochrany osobních údajů

**Poslední aktualizace:** Květen 2026

BirdNET Live respektuje vaše soukromí. Tento dokument vysvětluje, jak aplikace nakládá s vašimi údaji.

## Zpracování na zařízení

Veškerá analýza zvuku a identifikace ptačích druhů probíhá **zcela ve vašem zařízení**. Aplikace využívá dva modely neuronových sítí spouštěné lokálně:

- **Zvukový klasifikátor BirdNET+** — analyzuje zvuk z mikrofonu a identifikuje ptačí druhy.
- **Geomodel BirdNET** — předpovídá, jaké druhy se s největší pravděpodobností vyskytují ve vaší lokalitě a v daném ročním období.

Žádná zvuková data nejsou nikdy přenášena na externí servery.

## Shromažďování dat

BirdNET Live **neshromažďuje, nepřenáší ani nesdílí** žádné osobní údaje. Neobsahuje analytiku, sledování ani telemetrii.

### Data uložená lokálně ve vašem zařízení:

| Typ dat | Účel | Úložiště |
|-----------|---------|---------|
| Zvukové nahrávky | Identifikace ptáků, přehrávání, export | Lokální soubory |
| Výsledky detekce | Druhy, spolehlivost, časové značky | Lokální JSON soubory relací |
| GPS souřadnice | Geotagging detekcí, trasy průzkumu, geomodel | Lokální JSON soubory relací |
| Metadata relace | Historie, kontrola, export | Lokální JSON soubory relací |
| Snapshot počasí (volitelný) | Jednorázový záznam teploty, srážek, větru, oblačnosti a kódu počasí na relaci, když je **Povolit vyhledávání počasí** zapnuto | Lokální JSON soubory relací |
| Nastavení | Uživatelské předvolby | SharedPreferences |

### Přibalená offline data

Obrázky druhů, popisy a taxonomická data jsou **přibalena v aplikaci** a načítají se z lokálních souborů. Pro informace o druzích nejsou prováděny žádné síťové požadavky.

## Externí zdroje

Aplikace může přistupovat k následujícím externím zdrojům. Každý zdroj je gatovaný nezávislým přepínačem v **Nastavení → Soukromí**, a **všechny tři jsou při čisté instalaci standardně vypnuté**. Nic neopustí vaše zařízení, dokud to neschválíte.

| Zdroj | Účel | Přepínač | Odesíláno v každé žádosti |
|-------|------|----------|---------------------------|
| Mapové dlaždice (OpenStreetMap) | Základní mapa pro výběr polohy, živou mapu Survey a mapu relace | **Nastavení → Soukromí → Povolit mapové dlaždice** | Souřadnice dlaždice `(z, x, y)` a user-agent BirdNET Live — žádné PII |
| Reverzní geokódování (OpenStreetMap Nominatim) | Převod GPS souřadnic na název místa (např. „Berlín, Německo“) | **Nastavení → Soukromí → Povolit vyhledávání názvu místa** | Lat/lon relace plus user-agent BirdNET Live |
| Snapshot počasí (Open-Meteo) | Jednorázové zachycení lokálních podmínek (teplota, srážky, vítr, oblačnost, kód počasí WMO) na souřadnicích a konečném čase | **Nastavení → Soukromí → Povolit vyhledávání počasí** | Lat/lon relace a koncový časový razítko plus user-agent BirdNET Live |

Požadavky na mapové dlaždice jsou standardní HTTPS GET na `tile.openstreetmap.org`. Odesílají se pouze souřadnice dlaždic.

Reverzní geokódování odesílá lat/lon relace na `nominatim.openstreetmap.org` přes HTTPS spolu s user-agentem BirdNET Live dle [Pravidel užívání Nominatim](https://operations.osmfoundation.org/policies/nominatim/). Výsledný název místa je uložen lokálně s relací, takže se relace geokóduje pouze jednou.

Požadavky na počasí odesílají lat/lon relace a koncový čas na `api.open-meteo.com` přes HTTPS s user-agentem BirdNET Live. [Open-Meteo](https://open-meteo.com/) je bezplatná služba a nevyžaduje účet ani API klíč. Výsledný snapshot počasí je uložen lokálně s relací a také zapsán do JSON exportu, bloku `metadata.json` relace a HTML reportu.

**Uchovávání:** žádná z výše uvedených služeb třetích stran není kontaktována, aby *nahrávala* nebo *uchovávala* uživatelská data. Vrácené hodnoty (název místa, snapshot počasí) žijí pouze v lokálním záznamu relace na vašem zařízení a putují jen do exportních souborů, které výslovně vyrobíte.

**Odvolání:** kteroukoli ze tří služeb můžete kdykoliv vypnout v **Nastavení → Soukromí**. Již uložené názvy míst a snapshoty počasí zůstávají u relací, kde byly zachyceny. Tato historická data odstraníte smazáním dotčených relací v Session Library nebo pomocí **Nastavení → Nebezpečná zóna → Vymazat všechna data**.

**Žádné další síťové požadavky se neprovádějí.** Aplikace funguje plně offline.

## GPS a Poloha
Poloha se používá pro filtrování druhů, průzkumy a bodové sčítání. Vše je lokální a lze to zakázat v nastavení systému.

## Export a Smazání dat
Nahrávky lze exportovat vícenásobně (Raven Selection Tables, CSV, JSON, GPX) a pod **Nastavení → Export → Formáty** zaškrtněte libovolnou kombinaci formátů naraz; vybrané formáty jsou sbaleny do jediného ZIPu spolu s audio klipy a volitelným samostatným HTML reportem. Jednotlivé relace lze odstranit v Session Library; úplné místní vymazání relací, nahrávek, hlasových poznámek, vlastních seznamů druhů, nastavení a mezipamětí provedete pomocí **Nastavení → Nebezpečná zóna → Vymazat všechna data**. Můžete také vymazat úložiště aplikace v nastavení systému nebo aplikaci odinstalovat.

## Kontakt
Otázky ohledně soukromí: [ccb-birdnet@cornell.edu](mailto:ccb-birdnet@cornell.edu)
