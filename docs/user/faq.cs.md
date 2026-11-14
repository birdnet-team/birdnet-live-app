# FAQ

Často kladené otázky.

## Obecné

**Otázka: Vyžaduje BirdNET Live připojení k internetu?**
Odpověď: Ne. Veškerá inference běží v zařízení pomocí modelu ONNX. Jediné síťové funkce jsou volitelné a ve výchozím nastavení vypnuté: mapové dlaždice a vyhledávání názvů míst z OpenStreetMap, snímky počasí z Open-Meteo a načítání obrázků a popisů druhů z API taxonomie. Viz [Nastavení → Soukromí](settings.md#soukromí).

**Otázka: Kolik druhů dokáže identifikovat?**
Odpověď: Model BirdNET+ V3.0 identifikuje 10 048 druhů po celém světě – ptáky, obojživelníky, savce a hmyz (ořezaný průnik zvukového klasifikátoru a geomodelu). Rozpozná také 16 jiných než zvířecích zvuků, například motory, sirény a hudbu; ty jsou vypnuté, dokud nezapnete volbu [Jiné než zvířecí zvuky](settings.md#jiné-než-zvířecí-zvuky).

**Otázka: Druh ve starší Session má nový název nebo už není detekován. Ztratilo se něco?**
Odpověď: Ne. Aktualizace modelu může druhy přejmenovat podle aktuální taxonomie a vypustit druhy, které nový model nepokrývá. Uložené Sessions se nemění: starší detekce se zobrazí pod aktuálním názvem druhu, s obrázkem, překladem a odkazy, a druhy, které model už nedetekuje, zůstávají ve vašich Sessions a exportech přesně tak, jak byly zaznamenány.

**Otázka: Jaké platformy jsou podporovány?**
Odpověď: Android (8.0+), iOS (15.0+) a Windows (experimentální).

## Přesnost

**Otázka: Proč se zobrazuje málo detekcí nebo jen nízká skóre?**
Odpověď: Snižte práh spolehlivosti v Nastavení, abyste viděli více detekcí. Hluk na pozadí, vítr a vzdálenost ovlivňují přesnost.

**Otázka: Co dělá filtr druhů?**
Odpověď: Geomodel předpovídá, které druhy se pravděpodobně vyskytují ve vaší poloze GPS a ročním období. Zapněte **Geografický filtr**, chcete-li skrýt nepravděpodobné druhy, **Adaptivní geografický filtr**, chcete-li z nich skrýt jen ty, u kterých si není jistý ani zvukový model, nebo **Geografické vážení**, chcete-li výsledky vážit geografickou pravděpodobností.

**Otázka: Jak přesná je identifikace?**
Odpověď: Přesnost závisí na kvalitě nahrávky, vzdálenosti, hluku na pozadí a druhu. Detekce s vysokou spolehlivostí (>70 %) jsou obecně spolehlivé. Vzácné druhy vždy ověřujte vizuálně.

## Nahrávání

**Otázka: Kde se ukládají nahrávky?**
Odpověď: V adresáři dokumentů aplikace pod `recordings/<session-id>/`. Ukládají se jako WAV nebo FLAC podle **Nastavení → Zvuk a nahrávání → Formát nahrávek**.

**Otázka: Mohu analyzovat existující nahrávky?**
Odpověď: Ano. Otevřete Analýzu souborů z domovské obrazovky, vyberte zvukový soubor, nastavte místo a parametry a spusťte analýzu. Mezi podporované formáty patří WAV, FLAC, MP3, OGG, Opus, M4A, AAC, WMA a AMR.

## Point Count

**Otázka: Co je režim Point Count?**
Odpověď: Časovaný režim pro standardizované bodové sčítání ptáků. Nastavíte pevnou dobu trvání (3–30 minut) a polohu, poté aplikace běží nepřetržitě a automaticky se zastaví, když časovač dosáhne nuly.

**Otázka: Mohu Point Count pozastavit?**
Odpověď: Ne. Soulad s protokolem vyžaduje nepřerušované nahrávání. Sčítání ale můžete předčasně ukončit tlačítkem Stop.

**Otázka: Kde najdu výsledky Point Count?**
Odpověď: Zobrazují se v knihovně Sessions jako „Point Count #1“, „#2“ atd. Můžete je procházet, upravovat a exportovat jako kteroukoli jinou Session.

## Výkon

**Otázka: Proč se telefon zahřívá a aplikace vybíjí baterii?**
Odpověď: Inference modelu ONNX je výpočetně náročná a během živých Sessions navíc zůstává zapnutá obrazovka. Při zpracování neuronovou sítí v reálném čase je to normální.

**Otázka: Spektrogram vypadá jako zamrzlý.**
Odpověď: Ujistěte se, že je uděleno oprávnění k mikrofonu a že je aktivní snímání zvuku. Zkontrolujte, zda mikrofon nepoužívá žádná jiná aplikace.