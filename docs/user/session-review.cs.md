# Recenze relace

Session Review je místo, kde BirdNET Live promění detekce na upravitelný záznam.

## Jak toho dosáhnete

BirdNET Live otevře Session Review automaticky po dokončení:

- Živá relace
- počet bodů
- Průzkum
- Spuštění analýzy souborů

Můžete také znovu otevřít jakoukoli uloženou relaci z [Knihovny relací](session-library.md).

## Hlavní oblasti

### Shrnutí a přehrávání

Session Review kombinuje přehrávání, navigaci spektrogramem a seznam druhů. U průzkumných relací může také zobrazit mapovaný kontext.

### Seznam druhů

Druhy jsou seskupeny do rozbalitelných řad. Detekce můžete prohlížet podle druhů a procházet záznamem při jejich prohlížení.

### Mapa trasy průzkumu

Průzkumné relace zobrazují malou inline mapu trasy GPS a detekční značky. Klepnutím na něj otevřete **mapu na celou obrazovku** se stejnými údaji.

Lišta aplikací mapy na celou obrazovku má tlačítko :material-filter-list-outlined: **filtr**, které otevírá list pro omezení, které značky se mají zobrazovat. Dostupné filtry:

- **Všechny detekce** (výchozí).
- **Se zvukovým klipem** – pouze detekce, jejichž klip je stále na disku a lze jej přehrát.
- **Vysoká spolehlivost** – pouze detekce s spolehlivostí 80 % nebo vyšší.
- **Ruční přidání** – pouze detekce, které jste přidali v relace Review (kromě automaticky zjištěných).

Pod výběrem režimu je výběr **Limit to species**, který vám umožní sbalit mapu na jeden druh – užitečné při otázce „kde přesně na trase jsem slyšel drozda lesního?“. Položka *Všechny druhy* ruší omezení druhu. Oba filtry se kombinují: např. *Se zvukovým klipem* + *Wood Thrush* zobrazuje pouze hratelné značky drozda lesního.

Když je filtr aktivní, název lišty aplikace získá titulek s počtem shod (např. *"7 detekcí"*) a na tlačítku filtru se zobrazí malá tečka. *Reset* v listu se vrátí na výchozí.

## Ikony lišty nástrojů

Panel nástrojů používá stejný význam ikon, jaký je popsán v [Ikony a ovládací prvky](icons-and-controls.md):

- :material-plus-circle-outline: — přidat obsah
- :material-undo-variant: / :material-redo-variant: — procházet úpravami
- :material-content-cut: — režim trimování
- :material-content-save: — uložit úpravy
- :material-share-variant: — export nebo podíl
- :material-delete-outline: — vyřazení relace
- :material-play: — pokračovat v průzkumu, když je tato akce k dispozici
- :material-help-circle-outline: — otevřete list nápovědy Session Review
- :material-tune: — otevřete Nastavení

## Typické kontrolní úkoly

- kontrola detekcí proti přehrávání a kontextu spektrogramu
- přidat druh nebo anotaci
- ořízněte záznam na užitečný interval
- exportovat zkontrolovanou sadu výsledků

## Export

Chování exportu závisí na možnostech vybraných v [Nastavení](settings.md). Aplikace může zabalit detekce a volitelně i zvuk do zvoleného formátu exportu. Každý export se nyní dodává s úplnými metadaty provenience – verzí aplikace, názvem a verzí modelu, národním prostředím, časovým razítkem exportu a snímkem všech nastavení v době exportu – zapsanými do postranního souboru „<prefix>.metadata.json“ (ZIP) nebo do bloku „meta“ nejvyšší úrovně (JSON), takže exporty jsou samy popisovatelné a reprodukovatelné.