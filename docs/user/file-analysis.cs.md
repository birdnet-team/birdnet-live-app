# Analýza souborů

Analýza souborů zpracovává existující nahrávku prostřednictvím stejného kanálu BirdNET, který používají živé pracovní postupy.

## Jak to otevřít

Na domovské stránce klepněte na kartu **Analýza souborů** s ikonou :app-audioFileRounded:.

### Z jiné aplikace

Nahrávku můžete předat i odjinud. V systému Android se po sdílení zvukového souboru s aplikací **BirdNET Live** nebo volbě **Otevřít v** ihned otevře Analýza souborů. V systému iOS funguje volba **Otevřít v** také okamžitě; po použití nabídky sdílení otevřete BirdNET Live nebo se do aplikace vraťte a čekající nahrávka se vybere automaticky. Před analýzou aplikace zkopíruje nahrávku do vlastního dočasného úložiště.

## Lišta aplikací

- :app-tuneRounded: — otevřete nastavení analýzy souborů
- :app-helpOutlineRounded: — otevření nápovědy k analýze souborů
- :app-close: — zrušení aktivního běhu analýzy

## Podporované vstupy

Aktuální výběr souboru přijímá:

- WAV / WAVE
- FLAC
- MP3
- OGG / OGA / Opus
- M4A / AAC / MP4
- WMA / AMR

## Čtyřkrokový průvodce

### 1. Vyberte soubor

Vyberte soubor a zkontrolujte jeho kartu metadat:

- název souboru
- formát
- trvání
- velikost souboru
- vzorkovací frekvence

### 2. Místo a datum

Můžete:

- použít aktuální GPS :app-myLocation:
- zadejte souřadnice ručně :app-editLocationAlt:
- přeskočit umístění :app-locationOff:
- vyberte bod na mapě :app-mapSheet:
- nastavit volitelné datum záznamu :app-calendarTodayRounded:

### 3. Parametry

Průvodce odhalí:

- trvání okna
- překrývání
- citlivost
- práh spolehlivosti
- režim filtrování druhů

| Ovládací prvek nastavení | Ikona |
|---|---|
| Trvání okna | :app-timerOutlined: |
| Překrývání | :app-swapHoriz: |
| Citlivost | :app-hearing: |
| Práh spolehlivosti | :app-verifiedRounded: |
| Filtr druhů | :app-filterAltRounded: |

Klepnutím na tlačítko :app-helpOutline: vedle ovládacího prvku zobrazíte jeho vysvětlení. Tlačítka nápovědy mají také kroky pro soubor, polohu a datum záznamu.

Překryv určuje, o kolik se posune každé analytické okno, a je specifický pro
analýzu souborů: celý soubor se prochází vždy, více překryvu jej jen prochází
jemněji. Živé režimy místo toho používají frekvenci odvozování, protože musí
rozhodovat, jak často spouštět model na přicházející zvuk, nikoli jak jemně
pokrýt hotovou nahrávku.

Ať už analýza souborů dojde ke svým oknům jakkoli, převádí je na detekce
stejnými pravidly jako režim Live, Point Count a Survey: detekce začíná v
nejstarším podpůrném okně, nese nejvyšší podložené skóre a končí na konci
posledního podpůrného okna.

### 4. Analyzujte

Na obrazovce průběhu se zobrazí:

- okna zpracována
- nalezené detekce
- nalezený druh
- tlačítko pro zrušení

## Výsledek

Po dokončení analýzy BirdNET Live převede výstup na uloženou session a otevře [Session Review](session-review.md).
