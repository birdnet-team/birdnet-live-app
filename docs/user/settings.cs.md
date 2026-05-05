# Nastavení

BirdNET Live opakovaně používá jednu obrazovku Nastavení pro více pracovních postupů. Tlačítko :material-tune: otevírá sekce, které jsou relevantní pro obrazovku, ze které jste přišli.

## Jak funguje rozsah nastavení

- Otevřením Nastavení z plochy se zobrazí celá obrazovka.
- Otevřením Nastavení ze Živě, Transektu, Bodového sčítání nebo Analýzy souborů filtruje obrazovku na příslušné sekce.

## Generál

### Téma

Vyberte **Tmavý**, **Světlý** nebo **Systém**.

### Jazyk aplikace

Nastaví jazyk rozhraní.

### Názvy druhů

Řídí jazyk používaný pro názvy druhů. **Následovat jazyk aplikace** používá stejný jazyk jako rozhraní, pokud je tento název k dispozici.

### Zobrazit vědecká jména

Zobrazuje vědecká jména pod běžnými názvy v celé aplikaci.

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

### Formát

Vyberte jeden cíl exportu:

- Tabulka výběru Raven
- CSV
- JSON
- GPX (trať + trasové body)

### Zahrnout zvukové soubory

Zahrňte uložený zvuk vedle exportovaných tabulek nebo metadat, pokud to pracovní postup exportu podporuje.

## O

Řádek **O aplikaci** otevře obrazovku O aplikaci v aplikaci.

## Nebezpečná zóna

### Resetovat registraci

Při příštím spuštění aplikace znovu zobrazí vstupní sekvenci.

### Vymazat všechna data

Otevře tok potvrzení pro trvalé odstranění uložených dat aplikace.

## Parametry specifické pro pracovní postup mimo nastavení

Některé parametry se konfigurují na vlastních obrazovkách nastavení, nikoli na obrazovce sdílených nastavení.

- [Bodové sčítání](point-count-mode.md) má své vlastní nastavení doby trvání a umístění.
- [Transekt](survey-mode.md) má vlastní obrazovku s parametry průzkumu.
- [Analýza souborů](file-analysis.md) má svůj vlastní krok analýzy parametrů.
