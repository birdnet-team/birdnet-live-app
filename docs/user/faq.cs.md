# FAQ

Často kladené otázky.

## Generál

**Otázka: Vyžaduje BirdNET Live připojení k internetu?**
Odpověď: Ne. Veškeré odvození běží na zařízení pomocí modelu ONNX. Jediné síťové funkce jsou volitelné a ve výchozím nastavení vypnuté: mapové dlaždice a vyhledávání názvů míst z OpenStreetMap, snímky počasí z Open-Meteo a načítání obrázků a popisů druhů z API taxonomie. Viz [Nastavení → Soukromí](settings.md#soukromí).

**Otázka: Kolik druhů dokáže identifikovat?**
Odpověď: Model BirdNET+ V3.0 identifikuje 9 789 druhů po celém světě – ptáky, obojživelníky, savce a hmyz (ořezaný průnik zvukového klasifikátoru a geomodelu).

**Otázka: Jaké platformy jsou podporovány?**
Odpověď: Android (8.0+), iOS (15.0+) a Windows (experimentální).

## Přesnost

**Otázka: Proč můj práh spolehlivosti ukazuje nízké skóre?**
Odpověď: Snižte práh spolehlivosti v Nastavení, abyste viděli více detekcí. Šum na pozadí, vítr a vzdálenost ovlivňují přesnost.

**Otázka: Co dělá druhový filtr?**
Odpověď: Geografický model předpovídá, které druhy se pravděpodobně vyskytují ve vaší poloze GPS a ročním období. Zapněte **Filtr podle polohy**, chcete-li skrýt nepravděpodobné druhy, **Adaptivní filtr podle polohy**, chcete-li z nich skrýt jen ty, u kterých si není jistý ani zvukový model, nebo **Vážení podle polohy**, chcete-li vážit výsledky zeměpisnou pravděpodobností.

**Otázka: Jak přesná je identifikace?**
Odpověď: Přesnost závisí na kvalitě záznamu, vzdálenosti, šumu v pozadí a druhu. Detekce s vysokou spolehlivostí (>70 %) jsou obecně spolehlivé. Vzácné druhy vždy ověřujte vizuálně.

## Nahrávání

**Otázka: Kde se ukládají nahrávky?**
Odpověď: V adresáři dokumentů aplikace pod `recordings/<session-id>/`. Ukládají se jako WAV nebo FLAC podle **Nastavení → Nahrávání → Formát**.

**Otázka: Mohu analyzovat existující nahrávky?**
A: Ano. Otevřete Analýzu souborů z domovské obrazovky, vyberte zvukový soubor, nastavte umístění a parametry a klepněte na Analyzovat. Mezi podporované formáty patří WAV, FLAC, MP3, OGG, Opus, M4A, AAC, WMA a AMR.

## Počet bodů

**Otázka: Co je režim počítání bodů?**
A: Časovaný režim pro formální bodové sčítání ptáků (point count). Nastavíte pevnou dobu trvání (3–20 minut) a umístění, poté aplikace běží nepřetržitě a automaticky se zastaví, když časovač dosáhne nuly.

**Otázka: Mohu pozastavit počítání bodů?**
Odpověď: Ne. Soulad s protokolem vyžaduje nepřerušované nahrávání. Předčasně můžete ukončit pomocí tlačítka stop.

**Otázka: Kam jdou výsledky počítání bodů?**
Odpověď: Zobrazují se v knihovně relací jako "Počet bodů #1", "#2" atd. Můžete je kontrolovat, upravovat a exportovat jako kteroukoli jinou relaci.

## Výkon

**Otázka: Proč je aplikace teplá / používá baterii?**
Odpověď: Odvozování modelu ONNX je výpočetně náročné. Obrazovka také zůstane zapnutá během živých relací. To je normální pro zpracování neuronové sítě v reálném čase.

**Otázka: Spektrogram vypadá zmrazený.**
Odpověď: Ujistěte se, že je uděleno oprávnění k mikrofonu a že je aktivní nahrávání zvuku. Zkontrolujte, zda mikrofon nepoužívá žádná jiná aplikace.