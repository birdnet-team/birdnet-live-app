# Analiza plików

Analiza plików przetwarza istniejące nagranie tym samym potokiem BirdNET, który napędza tryby pracy na żywo.

## Jak ją otworzyć

Na ekranie startowym dotknij karty **Analiza plików** z ikoną :app-audioFileRounded:.

### Z innej aplikacji

Nagranie możesz też przekazać z innej aplikacji. W systemie Android udostępnienie pliku dźwiękowego aplikacji **BirdNET Live** lub wybranie opcji **Otwórz za pomocą** natychmiast otwiera Analizę plików. W systemie iOS opcja **Otwórz za pomocą** również działa natychmiast; po użyciu menu udostępniania otwórz BirdNET Live lub wróć do aplikacji, a oczekujące nagranie zostanie wybrane automatycznie. Przed analizą aplikacja kopiuje nagranie do własnej pamięci tymczasowej.

## Pasek aplikacji

- :app-tuneRounded: — otwórz ustawienia analizy plików
- :app-helpOutlineRounded: — otwórz pomoc analizy plików
- :app-close: — anuluj trwającą analizę

## Obsługiwane pliki wejściowe

Obecny selektor plików przyjmuje:

- WAV / WAVE
- FLAC
- MP3
- OGG / OGA / Opus
- M4A / AAC / MP4
- WMA / AMR

## Kreator w czterech krokach

### 1. Wybór pliku

Wybierz plik i sprawdź jego kartę metadanych:

- nazwa pliku
- format
- czas trwania
- rozmiar pliku
- częstotliwość próbkowania

### 2. Lokalizacja i data

Możesz:

- użyć bieżącej pozycji GPS :app-myLocation:
- wprowadzić współrzędne ręcznie :app-editLocationAlt:
- pominąć lokalizację :app-locationOff:
- wskazać punkt na mapie :app-mapSheet:
- opcjonalnie ustawić datę nagrania :app-calendarTodayRounded:

### 3. Parametry

Kreator udostępnia:

- czas trwania okna
- nakładanie
- czułość
- próg pewności
- tryb filtra gatunków

| Element konfiguracji | Ikona |
|---|---|
| Czas trwania okna | :app-timerOutlined: |
| Nakładanie | :app-swapHoriz: |
| Czułość | :app-hearing: |
| Próg pewności | :app-verifiedRounded: |
| Filtr gatunków | :app-filterAltRounded: |

Stuknij przycisk :app-helpOutline: obok elementu konfiguracji, aby zobaczyć wyjaśnienie. Kroki pliku, lokalizacji i daty nagrania także mają przyciski pomocy.

Nakładanie określa, o ile przesuwa się każde okno analizy, i jest właściwe dla
analizy plików: cały plik jest zawsze przeglądany, a większe nakładanie
przegląda go po prostu drobiazgowiej. Tryby na żywo używają zamiast tego
częstości wnioskowania, ponieważ muszą decydować, jak często uruchamiać model
na napływającym dźwięku, a nie jak drobiazgowo pokryć gotowe nagranie.

Niezależnie od tego, jak analiza plików dochodzi do swoich okien, zamienia je
na wykrycia według tych samych reguł co tryb Live, Point Count i Survey:
wykrycie zaczyna się w najwcześniejszym oknie potwierdzającym, niesie
najwyższą potwierdzoną ocenę i kończy się na końcu ostatniego okna
potwierdzającego.

### 4. Analiza

Ekran postępu pokazuje:

- przetworzone okna
- znalezione wykrycia
- znalezione gatunki
- przycisk anulowania

## Wynik

Po zakończeniu analizy BirdNET Live zamienia wynik w zapisaną Session i otwiera [Przegląd Session](session-review.md).
