# Tryb Point Count

Tryb Point Count to stacjonarny sposób pracy na czas w BirdNET Live.

## Jak go otworzyć

Na ekranie startowym dotknij karty **Tryb Point Count** z ikoną :app-locationOnRounded:.

## Konfiguracja

Konfiguracja liczenia punktowego składa się z czterech kroków.

### 1. Czas trwania i lokalizacja

Wybierz:

- jeden z dostępnych czasów: 3, 5, 10, 15, 20, 25 lub 30 minut
- czy liczenie trwa przy wyłączonym ekranie (domyślnie włączone)
- bieżącą pozycję GPS przyciskiem :app-myLocation:
- współrzędne ręczne przyciskiem :app-editLocationAlt:
- brak lokalizacji przyciskiem :app-locationOff:
- wybór na mapie przyciskiem :app-mapSheet:

Ekran konfiguracji odświeża GPS po powrocie z systemowego okna uprawnień lub
z ustawień aplikacji, więc świeżo przyznane uprawnienie do lokalizacji
powinno zaktualizować współrzędne bez ponownego uruchamiania kreatora. W tej
samej sekcji znajduje się także karta pogody. Jeśli dostęp do danych
pogodowych jest wyłączony, karta prosi o zgodę **Zezwalaj na sprawdzanie
pogody**; po włączeniu pokazuje podgląd miejsca z ikoną pogody, temperaturą i
wiatrem. Ten sam zapisany w pamięci podręcznej odczyt z Open-Meteo zostanie
użyty przy zapisie liczenia punktowego.

### 2. Parametry wnioskowania

Wybierz ustawienia analizy dla tej Session, takie jak częstość wnioskowania, próg pewności i tryb filtra gatunków. Wychodzą one od
Twoich ustawień globalnych, ale możesz je dostosować na potrzeby tego
liczenia bez zmiany wartości domyślnych.

| Element konfiguracji | Ikona |
|---|---|
| Mikrofon | :app-micRounded: |
| Tryb nagrywania | :app-fiberManualRecordRounded: |
| Kontekst fragmentu | :app-timerOutlined: |
| Częstość wnioskowania | :app-speedRounded: |
| Próg pewności | :app-verifiedRounded: |
| Czułość | :app-hearing: |
| Filtr gatunków | :app-filterAltRounded: |

Przycisk :app-helpOutline: obok każdego elementu wyjaśnia jego działanie. Wybór czasu trwania :app-timerRounded: i wybór lokalizacji mają w pierwszym kroku ten sam przycisk pomocy.

Wybierz **Pełny**, aby zapisywać ciągły dźwięk (domyślnie), **Klipy**, aby zapisywać fragment każdej wykrytej wokalizacji, lub **Wyłączony**, aby nie zapisywać dźwięku. Ten wybór jest niezależny od nagrywania w Live Mode i jest zapamiętywany dla kolejnego Point Count. Fragmenty używają tego samego wyboru okna z najwyższym wynikiem i kontekstu co Live Mode, bez ograniczania według lokalizacji. Przy opcji **Klipy** suwak **Kontekst klipu** ustala liczbę sekund zachowanych przed i po każdym analizowanym oknie; aktualizuje też kontekst Live Mode.

### 3. Wskazówki terenowe

Ten ekran przedstawia krótką listę kontrolną do przejrzenia przed startem.

### 4. Gotowe

Ekran gotowości podsumowuje czas, wybór nagrywania i zachowanie przy wyłączonym ekranie. Rozpocznij przyciskiem :app-playArrowRounded:.

## Ekran liczenia punktowego na żywo

Ekran trwającego liczenia punktowego skupia się na panelu z odliczaniem.

### Górny pasek

- :app-stopRounded: — zakończ liczenie punktowe wcześniej
- :app-timerRounded: — pokaż pozostały czas
- :app-helpOutlineRounded: — otwórz pomoc trybu Point Count
- :app-tuneRounded: — otwórz ustawienia trybu Point Count

### Główne wskaźniki

- pasek postępu odliczania
- zwięzły pasek informacji z bieżącymi wykryciami, liczbą unikalnych gatunków i łączną liczbą wykryć
- widok spektrogramu
- lista wykryć

## Po zakończeniu liczenia

Przy włączonym **Kontynuuj przy wyłączonym ekranie** w konfiguracji Point Count liczenie trwa po zablokowaniu ekranu lub przejściu do innej aplikacji, również gdy ekran pozostaje włączony. Kończy się po wybranym czasie; odliczanie używa faktycznie upływającego czasu, więc zawieszony ekran nie wydłuża liczenia. Android pokazuje stałe powiadomienie z Otwórz i Zatrzymaj. Wyłącz przełącznik, aby te działania kończyły liczenie wcześniej. Point Count nie jest wstrzymywany i wznawiany, ponieważ przerwałoby to liczenie na czas. Opuszczenie aplikacji podczas uruchamiania anuluje liczenie z komunikatem; skonfiguruj je ponownie. W Windows minimalizacja okna nie kończy liczenia.

Po zakończeniu Point Count BirdNET Live otwiera [Przegląd Session](session-review.md). Przy włączonym automatycznym zapisie Session zostaje zapisana automatycznie; w przeciwnym razie zapisz ją z przeglądu, jeśli chcesz ją zachować.

Przy włączonym automatycznym zapisywaniu niedokończone liczenie jest też zapisywane na starcie, co 30 sekund i gdy aplikacja opuszcza pierwszy plan. Po awarii lub utracie zasilania ostatnie częściowe liczenie jest dostępne w Bibliotece Sessions.
