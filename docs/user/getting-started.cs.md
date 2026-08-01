# Začínáme

## Instalace

BirdNET Live je k dispozici pro Android, iOS a Windows.

### Požadavky

- **Android**: 8.0 (API 26) nebo novější
- **iOS**: 15.0 nebo novější
- **Windows**: 10 nebo novější (experimentální)
- ~300 MB úložiště pro aplikaci a modely

### Stažení

- **Android** – [Obchod Google Play](https://play.google.com/store/apps/details?id=de.tu_chemnitz.mi.kahst.birdnet_live), nebo si stáhněte podepsaný APK ze [stránky GitHub Releases](https://github.com/birdnet-team/birdnet-live-app/releases/latest).
- **iOS** – [App Store](https://apps.apple.com/us/app/birdnet-live/id6776168518).
- **Windows** – sestavte ze zdrojového kódu; viz [Příručka pro vývojáře](../developer/building.md).

## První spuštění aplikace

Když BirdNET Live otevřete poprvé, aplikace vás provede krátkým úvodem a nastavením oprávnění.

1. Přečtěte si úvodní obrazovky.
2. Přečtěte si Zásady přijatelného použití a Zásady ochrany osobních údajů.
3. Udělte oprávnění k mikrofonu, aby BirdNET Live mohl zpracovávat zvuk.
4. Volitelně povolte oprávnění k poloze pro geotagging, Prozkoumat, Point Count a Survey.
5. Volitelně povolte oznámení pro dlouhotrvající surveye.

## První spuštění

1. **Úvod** — rychlé seznámení s funkcemi a oprávněními
2. **Přijatelné použití a soukromí** — přečtěte si Zásady přijatelného použití a Zásady ochrany osobních údajů
3. **Oprávnění** — udělení přístupu k mikrofonu (vyžadováno pro všechny režimy)
4. **Připraveno** — začněte určovat ptáky!

## Přehled domovské obrazovky

Domovská obrazovka je hlavní rozcestník.

### Karty hlavních režimů

- :material-microphone: **Režim Live**
- :material-map-marker: **Režim Point Count**
- :material-routes: **Režim Survey**
- :material-file-music: **Analýza souborů**

### Tlačítka v zápatí

- :material-tune: **Nastavení**
- :material-magnify: **Prozkoumat**
- :material-music-box-multiple-outline: **Knihovna Sessions**
- :material-help-circle-outline: **Nápověda**
- :material-information-outline: **O aplikaci**

## Co se ukládá

BirdNET Live automaticky uloží každou dokončenou session a po zastavení zpracování ji otevře v Přehledu Session.

- Live sessions ukládají detekce a podle vašeho nastavení také nahrávky nebo klipy.
- Sessions Point Count se ukládají jako časované sčítací sessions.
- Sessions Survey ukládají trasu, detekce a související metadata.
- Výsledky Analýzy souborů se převedou na session, kterou lze zkontrolovat.

## Doporučené další stránky

- Přečtěte si [Ikony a ovládací prvky](icons-and-controls.md), pokud chcete rychlé vysvětlení opakujících se symbolů rozhraní.
- Před změnou prahů, filtrů, chování nahrávání nebo zobrazení spektrogramu si přečtěte [Nastavení](settings.md).
- Otevřete průvodce pro pracovní postup, který používáte nejčastěji: [Režim Live](live-mode.md), [Režim Point Count](point-count-mode.md), [Režim Survey](survey-mode.md) nebo [Analýza souborů](file-analysis.md).

## Oprávnění

| Oprávnění | Vyžadováno pro | Volitelné? |
|------------|-------------|-----------|
| Mikrofon | Všechny režimy nahrávání | Povinné |
| Poloha | GPS značení, Survey/Point Count | Volitelné pro Live |
| Úložiště | Ukládání nahrávek, exporty | Vyžadováno pro nahrávání |
| Oznámení | Upozornění Survey na pozadí | Volitelné |
