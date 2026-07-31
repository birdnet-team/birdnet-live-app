# Ikony a ovládací prvky

Tato stránka vysvětluje opakující se ovládací prvky a symboly používané v celém BirdNET Live. Popisky níže odpovídají přesně tak, jak se ovládací prvky zobrazují v aplikaci.

## Sdílené navigační ovládací prvky

| Ovládací prvek | Kde jej najdete | Co dělá |
|---|---|---|
| :material-tune: **Nastavení** | zápatí Domů, Live, Point Count, Survey, Analýza souborů, Přehled Session | Otevře Nastavení. Na obrazovkách režimů otevře nastavení nejrelevantnější pro daný pracovní postup. |
| :material-magnify: **Prozkoumat** | zápatí Domů | Otevře Prozkoumat. |
| :material-music-box-multiple-outline: **Knihovna** | zápatí Domů | Otevře Knihovnu Sessions. |
| :material-help-circle-outline: **Nápověda** | zápatí Domů, záhlaví Prozkoumat, panel Survey, panel nástrojů Přehled Session | Otevře nápovědu nebo panel nápovědy pro konkrétní obrazovku. |
| :material-information-outline: **Info / O aplikaci** | zápatí Domů, informační lišty, panely nápovědy | Zobrazí obecné informace nebo souhrnný kontext. |
| :material-arrow-left: **Zpět** | Režim Live | Vrátí se na předchozí obrazovku. |
| :material-open-in-new: **Otevřít externí** | obrazovka O aplikaci, odkazy na dokumentaci | Otevře externí stránku, například online Uživatelskou příručku. |
| :material-hand-heart: **Přispět** | obrazovka O aplikaci | Otevře stránku pro příspěvky BirdNETu. |

## Symboly počasí

| Symbol | Význam |
|---|---|
| :material-weather-sunny: **Jasno** | Jasná obloha. |
| :material-weather-partly-cloudy: **Polojasno** | Slunce a mraky pro převážně jasné nebo polojasné počasí. |
| :material-weather-cloudy: **Zataženo** | Souvislá oblačnost. |
| :material-weather-fog: **Mlha** | Mlha nebo námrazová mlha. |
| :material-weather-partly-rainy: **Mrholení** | Slabé srážky. |
| :material-weather-rainy: **Déšť** | Déšť nebo dešťové přeháňky. |
| :material-weather-snowy: **Sníh** | Sníh nebo sněhové přeháňky. |
| :material-weather-lightning-rainy: **Bouřka** | Bouřkové podmínky. |

## Ovládací prvky spuštění, zastavení a session

| Ovládací prvek | Význam |
|---|---|
| :material-microphone: **Mikrofon** | Spustí živý poslech. |
| :material-stop: **Stop** | Zastaví aktivní nahrávání, point count nebo survey. |
| :material-play: **Přehrát** | Spustí nakonfigurovaný postup nastavení nebo pokračuje ze stavu pozastaveno-připraveno. |
| :material-close: **Zavřít / Zrušit** | Zruší probíhající analýzu souborů. |
| :material-timer: **Časovač** | Doba trvání nebo zbývající čas. |
| :material-alert-circle-outline: **Chyba** | Chyba modelu nebo zpracování. |

## Ovládací prvky polohy a času

| Ovládací prvek | Význam |
|---|---|
| :material-crosshairs-gps: **Aktuální poloha** | Použije aktuální GPS polohu zařízení. |
| :material-map-marker-plus: **Ruční souřadnice** | Zadání souřadnic ručně. |
| :material-map-marker-off: **Žádná poloha** | Přeskočí polohu nebo signalizuje, že poloha není k dispozici. |
| :material-map-marker: **Má polohu** | Potvrdí polohu, zobrazí souřadnice nebo označí session na mapě. |
| :material-refresh: **Aktualizovat** | Znovu načte aktuální polohu nebo obnoví seznam předpovědí. |
| :material-map: **Výběr na mapě** | Vybere souřadnice z výběru na mapě. |
| :material-calendar: **Datum** | Nastaví nebo zobrazí datum. |
| :material-close: **Vymazat** | Odebere vybrané datum. |

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
| :material-check: **Potvrdit** | Zaškrtnutí jedním klepnutím, které označí detekci jako vizuálně či akusticky ověřenou. Potvrzené detekce dostanou malé zelené zaškrtnutí na řádcích shluků a na značkách mapy. |
| :material-dots-vertical: **Více** | Otevře nabídku dalších akcí detekce s položkami **Sdílet detekci**, **Nahradit druh**, **Smazat detekci** a **Smazat druh**. |
| :material-share-variant: **Sdílet detekci** | Sdílí jednu detekci přes systémový panel sdílení a připojí zvukový klip, kdykoli je k dispozici — včetně úseku právě probíhající nahrávky během živé survey. |
| :material-swap-horizontal: **Nahradit druh** | Zvolí pro tuto detekci jiný druh. Otevře se také přejetím řádku přehledu doleva. |
| :material-delete-outline: **Smazat detekci** | Okamžitě odebere řádek. Na pár sekund se objeví SnackBar s možností vrácení. Spustí se také přejetím řádku přehledu doprava. |
| :material-delete-sweep-outline: **Smazat druh** | Odebere ze session všechny detekce daného druhu naráz, se stejným vrácením přes SnackBar. |
| :material-ear-hearing: **Slyšeno** | U ručně přidané detekce: ptáka jste slyšeli. Nastavuje se políčkem v potvrzovacím panelu po výběru druhu. |
| :material-eye: **Viděno** | U ručně přidané detekce: ptáka jste viděli. Obě ikony současně znamenají slyšeno *i* viděno. |

## Panel nástrojů Přehledu Session

Tyto ovládací prvky se používají na obrazovce Přehled Session.

| Ovládací prvek | Význam |
|---|---|
| :material-plus-circle-outline: **Přidat** | Přidá obsah, například druh nebo poznámku. |
| :material-undo-variant: **Zpět** / :material-redo-variant: **Znovu** | Krok zpět nebo vpřed v úpravách přehledu. |
| :material-content-cut: **Oříznout** | Vstup do režimu oříznutí nebo signalizace, že je aktivní. |
| :material-content-save: **Uložit** | Uloží změny přehledu. |
| :material-share-variant: **Sdílet** | Exportuje nebo sdílí session. |
| :material-delete-outline: **Smazat** | Zahodí session. |
| :material-play: **Pokračovat** | Pokračuje v nedokončené survey z Přehledu Session, je-li tato akce dostupná. |

## Stavové lišty specifické pro obrazovku

### Režim Live

Informační lišta Live používá :material-information-outline: následovanou kompaktními štítky, jako jsou:

- `now` — detekce aktuálně viditelné v živém seznamu
- `spp` — počet jedinečných druhů
- `det` — celkový počet detekcí
- doba trvání a odhadovaná velikost nahrávky, když je nahrávání aktivní

### Point Count

Lišta časovače Point Count kombinuje :material-stop: **Stop**, :material-timer: **Časovač** a ukazatel průběhu, který ukazuje zbývající část časované session.

### Survey

Panel Survey používá:

- :material-map-outline: **Mapa** — karta živé mapy
- :material-equalizer: **Spektrogram** — karta spektrogramu
- :material-chart-bar: **Souhrn** — karta souhrnu
- :material-chart-bar: štítky statistik v souhrnném zobrazení survey

## Když si nejste jisti

Pokud si nejste jisti, co ovládací prvek dělá, otevřete nejbližší panel nápovědy v aplikaci nebo si v této uživatelské příručce projděte stránku pracovního postupu dané obrazovky.
