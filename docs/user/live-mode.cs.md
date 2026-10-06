# Režim Live

Režim Live je nejrychlejší způsob, jak poslouchat přes mikrofon telefonu a sledovat detekce v reálném čase, jak se objevují.

## Jak jej otevřít

Na domovské obrazovce klepněte na kartu **Live** s ikonou :app-micRounded:.

## Widget „Rychlý poslech“

**Pouze Android.** Widget na domovské obrazovce spustí poslech jediným klepnutím, aniž byste museli nejprve otevřít aplikaci a proklikat se do režimu — hodí se, když uslyšíte něco, co chcete určit dřív, než to přestane zpívat.

Přidáte jej stejně jako kterýkoli jiný widget: podržte prst na prázdném místě domovské obrazovky, klepněte na **Widgety**, najděte **BirdNET Live** a přetáhněte na plochu jednu ze dvou dlaždic.

- **Rychlý poslech** (2×1) — ikona s popiskem **Spustit poslech**
- **Rychlý poslech (kompaktní)** (1×1) — pouze ikona

Obě dělají totéž. Klepnutí na kteroukoli z nich otevře režim Live a okamžitě začne poslouchat, bez ohledu na nastavení **Automaticky spustit nahrávání**. Widget toto nastavení nemění.

Pokud je režim Live již otevřený, widget se vrátí na stejnou obrazovku, místo aby ji vytvořil znovu. Běžící nebo pozastavená Session pokračuje beze změny; pokud je zastavená, spustí se poslech na stávající obrazovce.

Rychlý poslech nikdy nenahrazuje jiný běžící režim. Pokud běží nebo se spouští Session Point Count, Survey, File Analysis nebo [režimu ARU](aru-mode.md), aplikace se přesune do popředí a vyzve vás, abyste tuto Session nejprve zastavili. Její obrazovka i práce zůstanou dostupné a nepřerušené.

## Horní lišta

Horní lišta obsahuje tři prvky:

- :app-arrowBackRounded: — opuštění režimu Live
- středový text stavu — `Inicializace`, `Načítání modelu`, `Připraveno`, `Identifikace druhů`, `Pozastaveno` nebo `Chyba`
- :app-tuneRounded: — otevření zobrazení Nastavení specifického pro Live

## Hlavní akční tlačítko

Velké kruhové tlačítko dole uprostřed mění stav:

- :app-mic: — spustit poslech
- :app-stopRounded: — zastavit aktivní session
- :app-playArrowRounded: — pokračovat ze stavu pozastaveno-připraveno

## Co vidíte při poslechu

### Spektrogram

Spektrogram se nepřetržitě posouvá, dokud je snímání aktivní. Zobrazuje frekvenční obsah v čase a používá barevnou paletu, velikost FFT, frekvenční rozsah a dobu trvání nastavené v Nastavení.

### Seznam detekcí

Nedávné detekce se objevují pod spektrogramem. Každý řádek může zobrazovat:

- obrázek druhu
- běžný název
- volitelný vědecký název
- hodnotu spolehlivosti

Klepnutím na řádek druhu otevřete překryvný panel s podrobnostmi o druhu.

### Informační lišta session

Kompaktní informační řádek pod spektrogramem shrnuje aktuální session, například:

- aktuálně zobrazené detekce
- počet jedinečných druhů (`spp`)
- celkový počet detekcí (`det`)
- uplynulou dobu
- odhadovanou velikost nahrávky, je-li nahrávání zapnuté

## Chování nahrávání

Nahrávání se ovládá v [Nastavení](settings.md).

- **Úplný** zaznamená celou session.
- **Jen detekce** zaznamenává klipy kolem detekcí.
- **Vypnuto** nahrávání zakáže.

Když režim Live zastavíte, BirdNET Live session uloží a otevře [Přehled Session](session-review.md).

Když je zapnuté automatické ukládání Sessions, režim Live navíc ukládá rozpracovanou Session při spuštění, každých 30 sekund a při přechodu aplikace do pozadí. Po pádu aplikace nebo výpadku napájení najdete poslední uložený stav v Knihovně Sessions. Změny od tohoto uložení mohou být ztraceny. Vypnutím automatického ukládání vypnete i tato průběžná ukládání.

## Poslech s vypnutou obrazovkou

Live Mode se běžně pozastaví při zamknutí obrazovky nebo opuštění aplikace a po návratu pokračuje ve stejné Session. Při prvním návratu dialog nabídne omezený poslech na pozadí. V [nastavení nahrávání](settings.md) zapněte **Pokračovat při vypnuté obrazovce** a vyberte maximum 15, 30, 60 nebo 120 minut (výchozí: 30 minut). Limit platí pro každý pobyt mimo aplikaci a po jeho dosažení Session skončí. Android zobrazuje trvalé oznámení s akcemi Otevřít a Zastavit. Ve Windows Live Mode poslouchá i při minimalizovaném okně.
