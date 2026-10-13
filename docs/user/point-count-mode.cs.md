# Režim Point Count

Režim Point Count je časovaný stacionární pracovní postup v BirdNET Live.

## Jak jej otevřít

Na domovské obrazovce klepněte na kartu **Point Count** s ikonou :app-locationOnRounded:.

## Postup nastavení

Nastavení Point Count má čtyři kroky.

### 1. Doba trvání a poloha

Vyberte:

- jednu z dostupných dob trvání: 3, 5, 10, 15, 20, 25 nebo 30 minut
- zda sčítání pokračuje při vypnuté obrazovce (ve výchozím nastavení zapnuto)
- aktuální GPS pomocí :app-myLocation:
- ruční souřadnice pomocí :app-editLocationAlt:
- žádnou polohu pomocí :app-locationOff:
- výběr na mapě pomocí :app-mapSheet:

Obrazovka nastavení obnoví GPS, když se vrátíte ze systémového dialogu oprávnění nebo z nastavení aplikace, takže nově udělené oprávnění k poloze by mělo souřadnice aktualizovat bez restartu průvodce. Tatáž sekce obsahuje i kartu počasí. Pokud je přístup k počasí vypnutý, karta požádá o souhlas **Povolit vyhledání počasí**; po zapnutí zobrazí náhled místa s ikonou počasí, teplotou a pouze větrem. Stejný uložený snímek z Open-Meteo se znovu použije při uložení point countu.

### 2. Parametry inference

Zvolte nastavení analýzy pro tuto session, například rychlost inference, práh spolehlivosti a režim filtru druhů. Vycházejí z vašich globálních nastavení, ale lze je pro tento count upravit beze změny výchozích hodnot.

| Ovládací prvek nastavení | Ikona |
|---|---|
| Mikrofon | :app-micRounded: |
| Režim nahrávání | :app-fiberManualRecordRounded: |
| Kontext klipu | :app-timerOutlined: |
| Rychlost inference | :app-speedRounded: |
| Práh spolehlivosti | :app-verifiedRounded: |
| Citlivost | :app-hearing: |
| Filtr druhů | :app-filterAltRounded: |

Tlačítko :app-helpOutline: vedle každého ovládacího prvku vysvětluje jeho účinek. Ovládání délky :app-timerRounded: a výběr polohy mají v prvním kroku stejné tlačítko nápovědy.

Vyberte **Úplné** pro nepřetržité nahrávání (výchozí), **Jen klipy** pro klip každého zjištěného hlasového projevu nebo **Vypnuto**, pokud nechcete ukládat zvuk. Volba je nezávislá na nahrávání v Live Mode a pamatuje se pro příští Point Count. Klipy používají stejný výběr okna s nejvyšším skóre a kontext jako Live Mode, bez omezení podle polohy. Při volbě **Jen klipy** posuvník **Kontext klipu** určuje počet sekund zachovaných před a po každém analyzovaném okně; aktualizuje také kontext klipů v Live Mode.

### 3. Terénní tipy

Tato obrazovka nabízí krátký kontrolní seznam v aplikaci, který je dobré projít před spuštěním.

### 4. Připraveno

Obrazovka připravenosti shrnuje dobu trvání, volbu nahrávání a chování při vypnuté obrazovce. Spusťte pomocí :app-playArrowRounded:.

## Živá obrazovka Point Count

Živá obrazovka point countu se soustředí na časovaný panel.

### Horní lišta

- :app-stopRounded: — předčasné ukončení point countu
- :app-timerRounded: — zobrazení zbývajícího času
- :app-helpOutlineRounded: — otevření nápovědy k Point Count
- :app-tuneRounded: — otevření nastavení Point Count

### Hlavní ukazatele

- ukazatel průběhu odpočtu
- kompaktní informační lišta s aktuálními detekcemi, počtem jedinečných druhů a celkovým počtem detekcí
- zobrazení spektrogramu
- seznam detekcí

## Po sčítání

Při zapnuté volbě **Pokračovat při vypnuté obrazovce** v nastavení Point Count sčítání pokračuje při zamknutí obrazovky i přepnutí do jiné aplikace se zapnutou obrazovkou. Končí po zvolené době; odpočet používá skutečně uplynulý čas, takže pozastavená obrazovka sčítání neprodlouží. Android zobrazuje trvalé oznámení s akcemi Otevřít a Zastavit. Vypnutím přepínače tyto akce ukončí sčítání předčasně. Point Count se nepozastavuje a neobnovuje, protože by to přerušilo časované sčítání. Pokud aplikaci opustíte během spouštění, sčítání se zruší se zprávou; nastavte je znovu. Ve Windows minimalizace okna sčítání neukončí.

Po skončení Point Count otevře BirdNET Live [Přehled Session](session-review.md). Při zapnutém automatickém ukládání uloží Session automaticky; jinak ji můžete uložit z přehledu.

Při zapnutém automatickém ukládání se rozpracované sčítání ukládá také při spuštění, každých 30 sekund a když aplikace opustí popředí. Po pádu aplikace nebo výpadku napájení najdete poslední uložené částečné sčítání v Knihovně Sessions.
