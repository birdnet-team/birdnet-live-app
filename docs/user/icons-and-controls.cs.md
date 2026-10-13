# Ikony a ovládací prvky

Tato stránka vysvětluje opakující se ovládací prvky a symboly používané v celém BirdNET Live. Popisky níže odpovídají přesně tak, jak se ovládací prvky zobrazují v aplikaci.

## Ikony režimů

Tyto ikony mají stejné tvary jako v aplikaci. Zde přebírají barvu textu; barvy aplikace se mění podle motivu, dynamických barev a vysokého kontrastu.

- :app-micRounded: **Live**
- :app-locationOnRounded: **Point Count**
- :app-routeRounded: **Survey**
- :app-timerRounded: **Režim ARU**
- :app-audioFileRounded: **Analýza souborů**
- :app-sdStorage: **Dávková analýza** (Již brzy)

## Sdílené navigační ovládací prvky

| Ovládací prvek | Kde jej najdete | Co dělá |
|---|---|---|
| :app-tuneRounded: **Nastavení** | zápatí Domů, Live, Point Count, Survey, Analýza souborů, Přehled Session | Otevře Nastavení. Na obrazovkách režimů otevře nastavení nejrelevantnější pro daný pracovní postup. |
| :app-searchRounded: **Prozkoumat** | zápatí Domů | Otevře Prozkoumat. |
| :app-libraryMusic: **Knihovna** | zápatí Domů | Otevře Knihovnu Sessions. |
| :app-helpOutlineRounded: **Nápověda** | zápatí Domů, záhlaví Prozkoumat, panel Survey, panel nástrojů Přehled Session | Otevře nápovědu nebo panel nápovědy pro konkrétní obrazovku. |
| :app-infoOutline: **Info / O aplikaci** | zápatí Domů, informační lišty, panely nápovědy | Zobrazí obecné informace nebo souhrnný kontext. |
| :app-arrowBackRounded: **Zpět** | Režim Live | Vrátí se na předchozí obrazovku. |
| :app-openInNew: **Otevřít externí** | obrazovka O aplikaci, odkazy na dokumentaci | Otevře externí stránku, například online Uživatelskou příručku. |
| :app-arrowUpwardRounded: **Zpět nahoru** | Obrazovka nápovědy | Vrátí se k úvodu a odkazům na oddíly. Zobrazí se po posunutí dolů. |
| :app-volunteerActivism: **Přispět** | obrazovka O aplikaci | Otevře stránku pro příspěvky BirdNETu. |

## Symboly počasí

| Symbol | Význam |
|---|---|
| :app-wbSunny: **Jasno** | Jasná obloha. |
| :app-partlyCloudyDay: **Polojasno** | Slunce a mraky pro převážně jasné nebo polojasné počasí. |
| :app-cloudy: **Zataženo** | Souvislá oblačnost. |
| :app-foggy: **Mlha** | Mlha nebo námrazová mlha. |
| :app-rainyLight: **Mrholení** | Slabé srážky. |
| :app-rainy: **Déšť** | Déšť nebo dešťové přeháňky. |
| :app-weatherSnowy: **Sníh** | Sníh nebo sněhové přeháňky. |
| :app-thunderstorm: **Bouřka** | Bouřkové podmínky. |

## Ovládací prvky spuštění, zastavení a session

| Ovládací prvek | Význam |
|---|---|
| :app-micRounded: **Mikrofon** | Spustí živý poslech. |
| :app-stopRounded: **Stop** | Zastaví aktivní nahrávání, point count nebo survey. |
| :app-playArrowRounded: **Přehrát** | Spustí nakonfigurovaný postup nastavení nebo pokračuje ze stavu pozastaveno-připraveno. |
| :app-close: **Zavřít** / :app-stop: **Zrušit** | Zruší probíhající analýzu souborů z horní lišty nebo z obrazovky průběhu. |
| :app-timerOutlined: **Časovač** | Doba trvání nebo zbývající čas. |
| :app-errorOutline: **Chyba** | Chyba modelu nebo zpracování. |

## Ovládací prvky polohy a času

| Ovládací prvek | Význam |
|---|---|
| :app-myLocation: **Aktuální poloha** | Použije aktuální GPS polohu zařízení. |
| :app-editLocationAlt: **Ruční souřadnice** | Zadání souřadnic ručně. |
| :app-locationOff: **Žádná poloha** | Přeskočí polohu nebo signalizuje, že poloha není k dispozici. |
| :app-locationOn: **Má polohu** | Potvrdí polohu, zobrazí souřadnice nebo označí session na mapě. |
| :app-refresh: **Aktualizovat** | Znovu načte aktuální polohu nebo obnoví seznam předpovědí. |
| :app-mapSheet: **Výběr na mapě** | Vybere souřadnice z výběru na mapě. |
| :app-calendarToday: **Datum** | Nastaví nebo zobrazí datum. |
| :app-clear: **Vymazat** | Odebere vybrané datum. |

## Symboly Prozkoumat a druhů

| Prvek | Význam |
|---|---|
| Miniatura druhu | Přibalený obrázek druhu, pokud je k dispozici. |
| Procentuální odznak spolehlivosti nebo geomodelu | Rychlé číselné shrnutí výstupu modelu. Vyšší čísla znamenají silnější podporu v kontextu dané obrazovky. |
| Měsíční štítky (`led`, `dub`, `čvc`, `říj`, `pro`) | Referenční body na týdenním grafu očekávané četnosti v překryvném panelu druhu. |

## Akce u jednotlivých detekcí

Tyto ovládací prvky se objevují u každého řádku detekce v celé aplikaci — v seznamu druhů v Přehledu Session, v panelu přehrávače klipu, v živém seznamu detekcí Survey a u značek na mapě Survey. Úplné chování popisuje [Přehled Session → Akce u jednotlivých detekcí](session-review.md#akce-u-jednotlivých-detekcí).

| Ovládací prvek | Význam |
|---|---|
| :app-checkCircleOutline: **Potvrdit** | Zaškrtnutí jedním klepnutím, které označí detekci jako vizuálně či akusticky ověřenou. Potvrzené detekce dostanou malé zelené zaškrtnutí na řádcích shluků a na značkách mapy. |
| :app-moreVert: **Více** | Otevře nabídku dalších akcí detekce s položkami **Sdílet detekci**, **Nahradit druh**, **Smazat detekci** a **Smazat druh**. |
| :app-share: **Sdílet detekci** | Sdílí jednu detekci přes systémový panel sdílení a připojí zvukový klip, kdykoli je k dispozici — včetně úseku právě probíhající nahrávky během živé survey. |
| :app-swapHoriz: **Nahradit druh** | Zvolí pro tuto detekci jiný druh. Otevře se také přejetím řádku přehledu doleva. |
| :app-deleteOutline: **Smazat detekci** | Okamžitě odebere řádek. Na pár sekund se objeví SnackBar s možností vrácení. Spustí se také přejetím řádku přehledu doprava. |
| :app-deleteSweep: **Smazat druh** | Odebere ze session všechny detekce daného druhu naráz, se stejným vrácením přes SnackBar. |
| :app-hearing: **Slyšeno** | U ručně přidané detekce: ptáka jste slyšeli. Nastavuje se políčkem v potvrzovacím panelu po výběru druhu. |
| :app-visibility: **Viděno** | U ručně přidané detekce: ptáka jste viděli. Obě ikony současně znamenají slyšeno *i* viděno. |

## Panel nástrojů Přehledu Session

Tyto ovládací prvky se používají na obrazovce Přehled Session.

| Ovládací prvek | Význam |
|---|---|
| :app-addCircleOutline: **Přidat** | Přidá obsah, například druh nebo poznámku. |
| :app-undo: **Zpět** / :app-redo: **Znovu** | Krok zpět nebo vpřed v úpravách přehledu. |
| :app-contentCut: **Oříznout** | Vstup do režimu oříznutí nebo signalizace, že je aktivní. |
| :app-save: **Uložit** | Uloží změny přehledu. |
| :app-share: **Sdílet** | Exportuje nebo sdílí session. |
| :app-deleteOutline: **Smazat** | Zahodí session. |
| :app-playArrowRounded: **Pokračovat** | Pokračuje v nedokončené survey z Přehledu Session, je-li tato akce dostupná. |

## Stavové lišty specifické pro obrazovku

### Režim Live

Informační lišta Live používá :app-infoOutline: následovanou kompaktními štítky, jako jsou:

- `now` — detekce aktuálně viditelné v živém seznamu
- `spp` — počet jedinečných druhů
- `det` — celkový počet detekcí
- doba trvání a odhadovaná velikost nahrávky, když je nahrávání aktivní

### Point Count

Lišta časovače Point Count kombinuje :app-stopRounded: **Stop**, :app-timerOutlined: **Časovač** a ukazatel průběhu, který ukazuje zbývající část časované session.

### Survey

Panel Survey používá:

- :app-map: **Mapa** — karta živé mapy
- :app-graphicEq: **Spektrogram** — karta spektrogramu
- :app-summaryChart: **Souhrn** — karta souhrnu
- :app-summaryChart: štítky statistik v souhrnném zobrazení survey

## Když si nejste jisti

Pokud si nejste jisti, co ovládací prvek dělá, otevřete nejbližší panel nápovědy v aplikaci nebo si v této uživatelské příručce projděte stránku pracovního postupu dané obrazovky.
