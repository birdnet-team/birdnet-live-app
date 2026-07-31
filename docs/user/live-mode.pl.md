# Tryb Live

Tryb Live to najszybszy sposób, aby nasłuchiwać przez mikrofon telefonu i oglądać wykrycia w czasie rzeczywistym.

## Jak go otworzyć

Na ekranie startowym dotknij karty **Tryb Live** z ikoną :material-microphone:.

## Widżet Quick Listen

**Tylko Android.** Widżet na ekranie głównym zaczyna nasłuchiwać po jednym dotknięciu, bez otwierania aplikacji i przechodzenia przez menu — przydaje się, gdy usłyszysz coś, co chcesz rozpoznać, zanim przestanie się odzywać.

Dodaj go tak jak każdy inny widżet: przytrzymaj puste miejsce na ekranie głównym, dotknij **Widżety**, znajdź **BirdNET Live** i przeciągnij jeden z dwóch kafelków.

- **Quick Listen** (2×1) — ikona z etykietą **Start Listening**
- **Quick Listen (compact)** (1×1) — sama ikona

Oba robią to samo. Dotknięcie któregokolwiek otwiera tryb Live i od razu rozpoczyna nasłuchiwanie, niezależnie od ustawienia **Automatyczne rozpoczynanie nagrywania**. Widżet nie zmienia tego ustawienia.

Jeśli tryb Live jest już otwarty, widżet wraca do tego samego ekranu, zamiast budować go od nowa. Trwająca lub wstrzymana Session jest kontynuowana bez zmian; jeśli została zatrzymana, nasłuchiwanie rusza na istniejącym ekranie.

Quick Listen nigdy nie zastępuje innego działającego trybu. Jeśli trwa lub właśnie się rozpoczyna Session trybu Point Count, Survey, Analizy plików albo [trybu ARU](aru-mode.md), aplikacja przechodzi na pierwszy plan i prosi o wcześniejsze zatrzymanie tamtej Session. Jej ekran i praca pozostają dostępne i nie zostają przerwane.

## Górny pasek

Górny pasek zawiera trzy elementy:

- :material-arrow-left: — wyjście z trybu Live
- tekst stanu na środku — `Inicjowanie`, `Wczytywanie modelu`, `Gotowe`, `Rozpoznawanie gatunków`, `Wstrzymano` lub `Błąd`
- :material-tune: — otwarcie ustawień dotyczących trybu Live

## Główny przycisk

Duży okrągły przycisk na dole pośrodku zmienia stan:

- :material-microphone: — rozpocznij nasłuchiwanie
- :material-stop: — zatrzymaj aktywną Session
- :material-play: — wznów ze stanu wstrzymanego i gotowego

## Co widzisz podczas nasłuchiwania

### Spektrogram

Spektrogram przewija się nieprzerwanie, dopóki trwa rejestracja. Pokazuje zawartość częstotliwościową w czasie, używając palety kolorów, rozmiaru FFT, zakresu częstotliwości i czasu trwania skonfigurowanych w ustawieniach.

### Lista wykryć

Ostatnie wykrycia pojawiają się pod spektrogramem. Każdy wiersz może pokazywać:

- zdjęcie gatunku
- nazwę zwyczajową
- opcjonalnie nazwę naukową
- wartość pewności

Dotknij wiersza gatunku, aby otworzyć nakładkę ze szczegółami gatunku.

### Pasek informacji o Session

Zwięzły wiersz informacji pod spektrogramem podsumowuje bieżącą Session, na przykład:

- wykrycia pokazywane w tej chwili
- liczbę unikalnych gatunków (`spp`)
- łączną liczbę wykryć (`det`)
- czas, który upłynął
- szacowany rozmiar nagrania, gdy nagrywanie jest włączone

## Sposób nagrywania

Nagrywaniem sterujesz w [Ustawieniach](settings.md).

- **Pełne** nagrywa całą Session.
- **Tylko wykrycia** nagrywa fragmenty wokół wykryć.
- **Wyłączone** wyłącza nagrywanie.

Gdy zatrzymasz tryb Live, BirdNET Live zapisuje Session i otwiera [Przegląd Session](session-review.md).
