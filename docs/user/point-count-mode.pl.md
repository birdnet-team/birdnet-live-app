# Tryb Point Count

Tryb Point Count to stacjonarny sposób pracy na czas w BirdNET Live.

## Jak go otworzyć

Na ekranie startowym dotknij karty **Tryb Point Count** z ikoną :material-map-marker:.

## Konfiguracja

Konfiguracja liczenia punktowego składa się z czterech kroków.

### 1. Czas trwania i lokalizacja

Wybierz:

- jedną z dostępnych odznak czasu trwania
- bieżącą pozycję GPS przyciskiem :material-crosshairs-gps:
- współrzędne ręczne przyciskiem :material-map-marker-plus:
- brak lokalizacji przyciskiem :material-map-marker-off:
- wybór na mapie przyciskiem :material-map:

Ekran konfiguracji odświeża GPS po powrocie z systemowego okna uprawnień lub
z ustawień aplikacji, więc świeżo przyznane uprawnienie do lokalizacji
powinno zaktualizować współrzędne bez ponownego uruchamiania kreatora. W tej
samej sekcji znajduje się także karta pogody. Jeśli dostęp do danych
pogodowych jest wyłączony, karta prosi o zgodę **Zezwalaj na sprawdzanie
pogody**; po włączeniu pokazuje podgląd miejsca z ikoną pogody, temperaturą i
wiatrem. Ten sam zapisany w pamięci podręcznej odczyt z Open-Meteo zostanie
użyty przy zapisie liczenia punktowego.

### 2. Parametry wnioskowania

Wybierz ustawienia analizy dla tej Session, takie jak czas trwania okna,
częstość wnioskowania, próg pewności i tryb filtra gatunków. Wychodzą one od
Twoich ustawień globalnych, ale możesz je dostosować na potrzeby tego
liczenia bez zmiany wartości domyślnych.

### 3. Wskazówki terenowe

Ten ekran przedstawia krótką listę kontrolną do przejrzenia przed startem.

### 4. Gotowe

Ekran gotowości podsumowuje wybrany czas trwania i pozwala rozpocząć przyciskiem :material-play:.

## Ekran liczenia punktowego na żywo

Ekran trwającego liczenia punktowego skupia się na panelu z odliczaniem.

### Górny pasek

- :material-stop: — zakończ liczenie punktowe wcześniej
- :material-timer: — pokaż pozostały czas
- :material-tune: — otwórz ustawienia trybu Point Count

### Główne wskaźniki

- pasek postępu odliczania
- zwięzły pasek informacji z bieżącymi wykryciami, liczbą unikalnych gatunków i łączną liczbą wykryć
- widok spektrogramu
- lista wykryć

## Po zakończeniu liczenia

Gdy liczenie punktowe dobiegnie końca, BirdNET Live zapisuje Session i otwiera [Przegląd Session](session-review.md).
