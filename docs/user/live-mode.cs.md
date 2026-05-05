# Živý režim

Živý režim je nejrychlejší způsob, jak poslouchat prostřednictvím mikrofonu telefonu a kontrolovat detekce, jakmile se objeví.

## Jak to otevřít

Na domovské obrazovce klepněte na kartu **Živý režim** s ikonou :material-microphone:.

## Horní lišta

Horní lišta obsahuje tři prvky:

- :material-arrow-left: — opustit živý režim
- středový text stavu — `Inicializace`, `Načítání modelu`, `Připraveno`, `Identifikace druhů`, `Pozastaveno` nebo `Chyba`
- :material-tune: — otevření zobrazení Nastavení specifické pro živé vysílání

## Tlačítko hlavní akce

Velké kruhové tlačítko uprostřed dole změní stav:

- :material-mikrofon: — začít poslouchat
- :material-stop: — zastavení aktivní relace
- :material-play: — obnovení ze stavu pozastaveno-připraven

## Co vidíte při poslechu

### Spektrogram

Spektrogram se nepřetržitě posouvá, když je aktivní snímání. Zobrazuje frekvenční obsah v průběhu času a používá barevnou mapu, velikost FFT, frekvenční rozsah a dobu trvání z Nastavení.

### Seznam detekcí

Nedávné detekce se objevují pod spektrogramem. Každý řádek může zobrazovat:

- druhový obraz
- běžné jméno
- nepovinný vědecký název
- hodnota spolehlivosti

Klepnutím na řádek druhu otevřete překrytí podrobností o druhu.

### Informační lišta relace

Kompaktní informační čára pod spektrogramem shrnuje aktuální relaci, například:

- aktuální detekce zobrazené nyní
- počet unikátních druhů (`spp`)
- celkový počet detekcí (`det`)
- uplynulá doba trvání
- odhadovaná velikost záznamu, když je záznam povolen

## Chování při nahrávání

Nahrávání se ovládá v [Nastavení](settings.md).

- **Full** zaznamená celou relaci.
- **Pouze detekce** zaznamenává klipy kolem detekcí.
- **Vypnuto** zakáže nahrávání.

Když zastavíte Živý režim, BirdNET Live relaci uloží a otevře [Přehled relace](session-review.md).
