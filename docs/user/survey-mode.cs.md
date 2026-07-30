# Režim Survey

Režim Survey je pracovní postup založený na trase pro dlouhotrvající pohyblivé surveye.

## Jak jej otevřít

Na domovské obrazovce klepněte na kartu **Survey** s ikonou :material-routes:.

## Postup nastavení

Nastavení Survey je pětikrokový průvodce.

### 1. Detaily

Můžete zadat:

- název survey
- ID transektu
- jméno pozorovatele
- GPS, ruční souřadnice nebo žádnou výchozí polohu

Tento krok také zpřístupní výběr na mapě, obnoví GPS, když se vrátíte ze systémových obrazovek oprávnění, a v případě potřeby zobrazí připomenutí oprávnění ke GPS na pozadí. Ve stejné sekci polohy je k dispozici karta počasí. Pokud je přístup k počasí vypnutý, požádá o souhlas **Povolit vyhledání počasí**; po zapnutí zobrazí náhled místa s ikonou počasí, teplotou a pouze větrem. Stejný uložený snímek z Open-Meteo se znovu použije při uložení survey.

### 2. Parametry

Tento krok obsahuje parametry specifické pro Survey, například:

- výběr mikrofonu
- rychlost inference
- práh spolehlivosti
- GPS interval
- maximální dobu trvání
- režim nahrávání
- kontext klipu pro nahrávání jen klipů
- režim vzorkování detekcí
- limit Top N na druh, je-li vzorkování omezené

#### Vzorkování detekcí

Dlouhá survey může vytvořit tisíce detekcí a uložení zvukového klipu ke každé z nich rychle zaplní úložiště. Vzorkování detekcí řídí, **které klipy se uchovají na disku** — *samotné záznamy detekcí se uchovávají vždy*, takže váš úplný protokol session zůstane nedotčený bez ohledu na režim. Záznamy, jejichž zvuk byl zahozen, prostě nemají v Přehledu Session přehratelný klip.

K dispozici jsou tři režimy:

| Režim | Co dělá |
|---|---|
| **Všechny** | Uchová každý klip. Největší využití disku. Doporučeno pro krátké surveye nebo když chcete zvuk každé detekce pro pozdější analýzu. |
| **Top N** | Uchová pouze **N klipů s nejvyšší konfidencí na druh**. Ostatní klipy se během survey mažou. Výchozí N je 10, nastavitelné od 1 do 50. |
| **Smart** | Stejný strop N na druh jako Top N, **navíc** prostorové rozložení: pokud nová detekce padne na stejné „místo“ jako už uchovaný klip (do ~500 m a ~2 min od sebe), klip si ponechá jen ta s vyšší konfidencí. To brání jednomu stacionárnímu zpěvákovi v zabrání všech N míst a vychyluje uchovávané klipy směrem k pokrytí celého transektu. |

Limit N je **na druh, nikoli globální** — pokud zaznamenáte 10 červenek a 10 pěnkav, ponecháte si 20 klipů. Neexistuje žádný celkový strop počtu klipů, které survey může vytvořit.

V režimu Smart se při chybějícím GPS u detekce kontrola stejného místa vrátí k oknu pouze podle času (~2 min). Je-li GPS dostupné, musí se pro započítání dvou detekcí jako stejného místa překrývat vzdálenost i čas.

### 3. Upozornění na druhy

Oznámení ve stylu push, která se spustí během survey, když je detekováno něco pozoruhodného. Vyberte jedno z:

- **Vypnuto** — žádná upozornění (výchozí).
- **První v session** — jedno upozornění při prvním zaznamenání každého druhu během této survey.
- **Vůbec poprvé** — upozornění pouze tehdy, když aplikace narazí na druh úplně poprvé napříč všemi vašimi sessions (upozornění na „lifera“). Vychází z celoživotní historie druhů, která se při prvním spuštění automaticky naplní z vašich stávajících sessions.
- **Vzácný pro toto místo** — upozornění, když je pravděpodobnost geomodelu pro aktuální polohu pod nastavitelným prahem. Živý údaj pod posuvníkem přesně vysvětluje, na co se aktuální hodnota spustí (např. *„Upozorňuje na druhy s pravděpodobností pod 5 % na tomto místě.“*).
- **Sledovaný seznam** — upozornění pouze na druhy, které jste přidali do uloženého vlastního seznamu. Samotný krok průvodce umožňuje vytvářet nové sledované seznamy, upravovat stávající ve vyhrazeném celoobrazovkovém editoru s prohledávatelnou taxonomií a *Importovat ze souboru* (jakýkoli prostý `.txt`/`.csv` s vědeckými jmény) a mazat seznamy, které už nepotřebujete.

Pod výběrem režimu je posuvník *Minimální spolehlivost*, který se automaticky omezuje zdola na práh spolehlivosti session (upozornění nikdy nejsou citlivější než samotné detekce). Sekce **Řízení frekvence** odkrývá ovládací prvky omezení — úvodní pauzu po startu, pevný minimální interval mezi libovolnými dvěma upozorněními a klouzavý limit za minutu s volitelným sloučením upozornění nad limit do jediného souhrnného oznámení — vše s výběrem pomocí čipů na jedno klepnutí. Při prvním přepnutí na jiný režim než Vypnuto za vás průvodce vyžádá oprávnění k oznámením v Androidu.

### 4. Terénní tipy

Krátký kontrolní seznam před spuštěním v rámci postupu nastavení.

### 5. Připraveno

Obrazovka připravenosti shrnuje aktivní konfiguraci survey, než začnete pomocí :material-play:.

## Živý panel Survey

Živá obrazovka Survey má tři hlavní karty a seznam nedávných detekcí.

### Horní lišta

- :material-stop: — ukončit survey
- :material-timer: — uplynulý čas
- :material-help-circle-outline: — otevřít panel nápovědy Survey
- :material-tune: — otevřít nastavení Survey

### Karty

- :material-map-outline: — mapa trasy a detekce na mapě
- :material-equalizer: — spektrogram
- ikona grafu — souhrnné statistiky a rozdělení druhů

### Statistiky a detekce

Pod obsahem karty zobrazuje panel Survey lištu statistik a seznam nedávných detekcí. Klepnutím na detekci otevřete překryvný panel s podrobnostmi o druhu.

Každý řádek detekce také nabízí stejné akce u jednotlivých detekcí jako [Přehled Session](session-review.md): zaškrtnutí :material-check: **Potvrdit** jedním klepnutím a nabídku dalších akcí :material-dots-vertical: **Více** s položkami **Sdílet detekci** a **Smazat detekci** (s vrácením přes SnackBar) — takže můžete hlučnou detekci ověřit, sdílet nebo odebrat už během snímání, místo abyste čekali na kontrolu po session.

Stejné akce jsou dostupné z **živé mapy trasy**: klepnutím na značku detekce otevřete panel přehrávače klipu s potvrzením, sdílením a smazáním. Sdílení během survey funguje i tehdy, když jste zvolili jedno souvislé nahrávání WAV místo klipů u jednotlivých detekcí — příslušné zvukové okno se za běhu vyřízne z právě nahrávaného souboru. Podrobnosti viz [Přehled Session → Sdílení jedné detekce](session-review.md#sdileni-jedne-detekce).

### Zaznamenání pozorování

Tlačítko :material-plus-circle-outline: v živém Survey otevře malou nabídku s položkami **Přidat druh** a **Přidat poznámku**. **Přidat druh** otevře stejné vyhledávání jako [Session Review](session-review.md#rucni-pridani-druhu), vyberte druh, poté v potvrzovacím panelu zaškrtněte :material-ear-hearing: **Slyšeno** a/nebo :material-eye: **Viděno** a klepněte na **Přidat**. Záznam dostane časové razítko daného okamžiku, aktuální GPS pozici a ihned se objeví v seznamu detekcí i na mapě trasy s odznakem ručního zadání a odpovídajícími ikonami ucha / oka.

Hlasové poznámky zde záměrně chybí: mikrofon je zaneprázdněn vlastním nahráváním Survey. Připojte je v Session Review po skončení Survey.

## Provoz na pozadí

Režim Survey udržuje během nahrávání viditelné trvalé oznámení na popředí, aby Android nepozastavil audio pipeline. Oznámení se rozbalí a zobrazí:

- uplynulý čas, počet detekcí, počet druhů a ujetou vzdálenost a
- **tři poslední jedinečné druhy** s jejich spolehlivostí a relativní časovou značkou (`právě teď`, `před 42 s`, `před 5 min`, `před 2 h`).

Oznámení — název, nedávné detekce i zápatí se statistikami — je plně přeloženo do zvoleného jazyka aplikace a používá stejné nastavení jazyka názvů druhů a předvolbu *Zobrazit vědecké názvy* jako karty v aplikaci.

Upozornění na druhy (jsou-li zapnutá) se zobrazují na samostatném oznamovacím kanálu Androidu, takže je můžete ztlumit nezávisle na tichém oznámení o probíhajícím nahrávání. Ikona upozornění odpovídá ikoně oznámení na popředí (jednobarevný pták) a text upozornění ukazuje jen *důvod* — *„První detekce v této survey“*, *„Na vašem sledovaném seznamu“*, *„Zde detekováno s pravděpodobností pod 4 %“* — přičemž název druhu zůstává v tučném názvu oznámení, kde jej Android vykresluje největší.

Když nedokončenou survey **obnovíte** z Knihovny Sessions, systém upozornění se znovu nastaví podle vašich *aktuálních* předvoleb oznámení — nikoli podle toho, co jste měli nastaveno v den, kdy jste survey začali. Vypněte upozornění (nebo změňte režim, sledovaný seznam či řízení frekvence) před klepnutím na Obnovit a obnovená survey nová nastavení okamžitě respektuje.

## Kontrola na mapě

Celoobrazovkové zobrazení mapy Survey (tlačítko :material-fullscreen: v Přehledu Session) otevře přehrávač klipu, když klepnete na značku. Řádek ovládání přehrávání má tlačítka přeskočit na předchozí a další po stranách ovládání přehrávání — procházejí detekce v chronologickém pořadí, ale **jen ty, které jsou právě viditelné na mapě**, takže jakýkoli aktivní filtr druhu, konfidence nebo čipu režimu seznam k přehrání odpovídajícím způsobem zúží. Tlačítka zešednou u první/poslední detekce v odfiltrovaném seznamu.

## Po zastavení

BirdNET Live uloží dokončenou survey a otevře [Přehled Session](session-review.md).
