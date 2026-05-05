# Režim průzkumu

Režim průzkumu je pracovní postup založený na trase pro dlouhotrvající pohyblivé průzkumy.

## Jak to otevřít

Na domovské stránce klepněte na kartu **Režim průzkumu** s ikonou :material-routes:.

## Nastavení toku

Nastavení průzkumu je pětikrokový průvodce.

### 1. Podrobnosti

Můžete zadat:

- název průzkumu
- ID transektu
- jméno pozorovatele
- GPS, manuální souřadnice nebo žádná výchozí poloha

Tento krok také v případě potřeby zpřístupní nástroj pro výběr mapy a připomenutí povolení GPS na pozadí.

### 2. Parametry

Tento krok obsahuje parametry specifické pro průzkum, například:

- výběr mikrofonu
- míra inference
- práh spolehlivosti
- interval GPS
- maximální doba trvání
- režim nahrávání
- kontext klipu pro záznam pouze pro detekci
- režim vzorkování detekce
- horní limit N na druh, když je odběr vzorků omezen

#### Vzorkování detekce

Dlouhý průzkum může produkovat tisíce detekcí a uložení zvukového klipu pro každý z nich rychle zaplní úložiště. Kontroluje vzorkování detekce **které klipy jsou uchovávány na disku** — *záznamy detekce samotné jsou vždy uchovávány*, takže váš úplný protokol relace zůstane nedotčen bez ohledu na režim. Záznamy, jejichž zvuk byl vynechán, jednoduše nemají žádný klip, který by bylo možné přehrát v relace Review.

K dispozici jsou tři režimy:

| Režim | Co to dělá |
|---|---|
| **Vše** | Uschovejte každý klip. Nejvíce využití disku. Doporučeno pro krátké průzkumy nebo když chcete zvuk každé detekce pro pozdější analýzu. |
| **Top N** | Uchovávejte pouze **N nejspolehlivějších klipů na druh**. Ostatní klipy se během průzkumu vymažou. Výchozí N je 10, konfigurovatelné od 1 do 50. |
| **Chytrý** | Stejná čepice N podle druhu jako Top N, **plus** prostorová distribuce: pokud nová detekce přistane na stejném „místě“ jako již uchovávaný klip (v rozmezí ~500 m a ~2 min od sebe), pouze ten s vyšší spolehlivostí si svůj klip zachová. To zabraňuje jednomu stacionárnímu zpěvákovi v monopolizaci všech N slotů a předpojuje uchovávané klipy tak, aby pokrývaly celý transekt. |

Limit N je **na druh, nikoli globální** — pokud zaznamenáte 10 červenek a 10 pěnkav, ponecháte si 20 klipů. Neexistuje žádné celkové omezení počtu klipů, které může průzkum vytvořit.

Pokud v chytrém režimu při detekci chybí GPS, kontrola na stejném místě se vrátí zpět do časového okna (~2 minuty). Pokud je k dispozici GPS, musí se vzdálenost i čas překrývat, aby se dvě detekce počítaly jako stejné místo.

### 3. Upozornění na druhy

Oznámení ve stylu push, která se spustí uprostřed průzkumu, když je zjištěno něco pozoruhodného. Vyberte si jednu z:

- **Vypnuto** — žádná upozornění (výchozí).
- **First in session** – jedno upozornění při prvním slyšení každého druhu během tohoto průzkumu.
- **První v historii** – upozornění pouze tehdy, když se aplikace setká s druhem úplně poprvé ve všech vašich relacích (upozornění na „doživotí“). Podporováno celoživotní druhovou historií, která se automaticky vyplní z vašich stávajících relací při prvním spuštění.
- **Vzácné pro toto umístění** – upozornění, když je pravděpodobnost geografického modelu pro aktuální polohu pod konfigurovatelným prahem. Živý údaj pod posuvníkem přesně vysvětluje, při čem se aktuální hodnota spustí (např. *"Upozornění na druhy s pravděpodobností nižší než 5 % na tomto místě."*).
- **Seznam ke zhlédnutí** – upozornění pouze na druhy, které jste přidali do uloženého vlastního seznamu. Samotný krok průvodce vám umožňuje vytvářet nové seznamy sledovaných položek, upravovat stávající ve vyhrazeném celoobrazovkovém editoru s prohledávatelnou taxonomií a *Importovat ze souboru* (jakýkoli prostý `.txt`/`.csv` vědeckých jmen) a mazat seznamy, které již nepotřebujete.

Posuvník *Minimální spolehlivost* se nachází pod výběrem režimu a je automaticky nastaven na prahovou hodnotu spolehlivosti relace (výstrahy nejsou nikdy citlivější než samotné detekce). Sekce **Pokročilé** odkrývá ovládací prvky omezení – okno odkladu spouštění, pevný minimální interval mezi libovolnými dvěma výstrahami a posuvný limit za minutu s volitelným sloučením výstrah s překročením limitu do jediného souhrnného oznámení – to vše s voliči čipů jediným klepnutím. Když poprvé přepnete do režimu, který není vypnutý, průvodce vás požádá o povolení oznámení systému Android.

### 4. Tipy v terénu

Krátký kontrolní seznam před spuštěním v procesu nastavení.

### 5. Připraveno

Připravená obrazovka shrnuje aktivní konfiguraci průzkumu, než začnete s :material-play:.

## Panel živého průzkumu

Obrazovka živého průzkumu má tři hlavní karty a seznam posledních zjištění.

### Horní lišta

- :material-stop: — ukončit průzkum
- :material-timer: — uplynulý čas
- :material-help-circle-outline: — otevřete list nápovědy k průzkumu
- :material-tune: — otevřete Nastavení průzkumu

### Karty

- :material-map-outline: — mapa trasy a mapované detekce
- :materiál-ekvalizér: — spektrogram
- ikona grafu — souhrnné statistiky a rozdělení druhů

### Statistiky a detekce

Pod obsahem karty se na řídicím panelu průzkumu zobrazuje panel statistik a seznam posledních zjištění. Klepnutím na detekci se otevře překrytí podrobností o druhu.

## Operace na pozadí

Režim průzkumu udržuje trvalé upozornění na popředí viditelné během nahrávání, takže Android nepřeruší audio potrubí. Oznámení se rozbalí a zobrazí:

- uplynulý čas, počet detekcí, počet druhů a ušlou vzdálenost a
- **tři poslední unikátní druhy** s jejich sebevědomím a relativním časovým razítkem ("právě teď", "před 42 lety", "před 5 m", "před 2 hodinami").

Oznámení – název, poslední detekce a zápatí statistik – je plně přeloženo do vybraného jazyka aplikace a používá stejné druhové prostředí a preference *Zobrazit vědecká jména* jako karty v aplikaci.

Upozornění na druhy (pokud je povoleno) se zobrazují na samostatném kanálu oznámení systému Android, takže můžete výstrahy ztlumit nezávisle na oznámení o tichém probíhajícím nahrávání. Ikona výstrahy se shoduje s ikonou oznámení v popředí (jednobarevný pták) a těla výstrah zobrazují pouze *důvod* — *„První zjištění tohoto průzkumu“*, *„Na vašem seznamu sledovaných“*, *„Zjištěno na tomto místě s pravděpodobností nižší než 4 %“* – ponechejte název druhu v nadpisu oznámení tučně tam, kde je Android vykresluje největší.

## Po zastavení

BirdNET Live uloží hotový průzkum a otevře [Přehled relace](session-review.md).