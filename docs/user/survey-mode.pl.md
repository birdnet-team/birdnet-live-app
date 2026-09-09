# Tryb Survey

Tryb Survey to sposób pracy oparty na trasie, przeznaczony do długich liczeń w ruchu.

## Jak go otworzyć

Na ekranie startowym dotknij karty **Tryb Survey** z ikoną :material-routes:.

## Konfiguracja

Konfiguracja Survey to kreator złożony z pięciu kroków.

### 1. Szczegóły

Możesz tu wprowadzić:

- nazwę Survey
- identyfikator transektu
- nazwę obserwatora
- GPS, współrzędne ręczne albo brak lokalizacji początkowej

Ten krok udostępnia także wybór na mapie, odświeża GPS po powrocie z
systemowych ekranów uprawnień i w razie potrzeby pokazuje przypomnienie o
uprawnieniu do GPS w tle. W tym samym obszarze lokalizacji dostępna jest karta
pogody. Jeśli dostęp do danych pogodowych jest wyłączony, karta prosi o zgodę
**Zezwalaj na sprawdzanie pogody**; po włączeniu pokazuje podgląd miejsca z
ikoną pogody, temperaturą i wiatrem. Ten sam zapisany w pamięci podręcznej
odczyt z Open-Meteo zostanie użyty przy zapisie Survey.

### 2. Parametry

Ten krok zawiera parametry właściwe dla Survey, takie jak:

- wybór mikrofonu
- częstość wnioskowania
- próg pewności
- interwał GPS
- maksymalny czas trwania
- tryb nagrywania
- kontekst fragmentu przy nagrywaniu samych wykryć
- tryb próbkowania wykryć
- limit top-N na gatunek, gdy próbkowanie jest ograniczone

Nowe ustawienia Survey domyślnie używają wnioskowania **0,70 Hz**. Zachowuje
to więcej krótkich odgłosów niż wybory o niższej częstości oszczędzające
baterię, a model i tak działa rzadziej niż przy 1,00 Hz. Survey i tryb Live
mają wspólny harmonogram wnioskowania i wspólną definicję wykrycia, więc przy
tych samych ustawieniach wnioskowania oba zgłaszają dla tego samego dźwięku te
same gatunki, oceny i zakresy wykryć. Niższe częstości celowo zostawiają
szersze przerwy między nakładającymi się oknami analizy i mogą przez to
pominąć krótkie dźwięki; 0,30 Hz pozostaje dostępne, gdy priorytetem jest czas
pracy baterii.

#### Próbkowanie wykryć

Długi Survey może dać tysiące wykryć, a zapisywanie fragmentu dźwiękowego do każdego z nich szybko zapełnia pamięć. Próbkowanie wykryć decyduje o tym, **które fragmenty zostają na dysku** — *same zapisy wykryć są zawsze zachowywane*, więc pełny dziennik Session pozostaje nienaruszony niezależnie od trybu. Zapisy, których dźwięk odrzucono, po prostu nie mają odtwarzalnego fragmentu w Przeglądzie Session.

Dostępne są trzy tryby:

| Tryb | Co robi |
|---|---|
| **Wszystko** | Zachowuje każdy fragment. Największe zużycie dysku. Zalecany przy krótkich Surveys lub gdy chcesz mieć dźwięk każdego wykrycia do późniejszej analizy. |
| **Top N** | Zachowuje tylko **N fragmentów o najwyższej pewności dla każdego gatunku**. Pozostałe fragmenty są usuwane w trakcie Survey. Domyślne N to 10, z możliwością ustawienia od 1 do 50. |
| **Smart** | Ten sam limit N na gatunek co w Top N, **plus** rozkład przestrzenny: jeśli nowe wykrycie trafi w to samo „miejsce” co już zachowany fragment (w promieniu około 500 m i w odstępie około 2 minut), fragment zachowuje tylko to o wyższej pewności. Dzięki temu jeden śpiewający w miejscu osobnik nie zajmie wszystkich N miejsc, a zachowane fragmenty lepiej pokrywają cały transekt. |

Limit N obowiązuje **na gatunek, nie łącznie** — jeśli nagrasz 10 rudzików i 10 zięb, zachowasz 20 fragmentów. Nie ma ogólnego limitu liczby fragmentów, jakie może dać jeden Survey.

W trybie Smart, jeśli przy wykryciu brakuje pozycji GPS, sprawdzenie tego samego miejsca opiera się wyłącznie na oknie czasowym (około 2 minut). Gdy GPS jest dostępny, aby uznać dwa wykrycia za to samo miejsce, muszą pokrywać się zarówno odległość, jak i czas.

### 3. Alerty gatunkowe

Powiadomienia w stylu push, które pojawiają się w trakcie Survey, gdy zostanie wykryte coś godnego uwagi. Wybierz jedną z opcji:

- **Wyłączone** — brak alertów (domyślnie).
- **Pierwszy raz w Session** — jeden alert przy pierwszym usłyszeniu każdego gatunku podczas tego Survey.
- **Pierwszy raz w ogóle** — alert tylko wtedy, gdy aplikacja napotka gatunek po raz pierwszy we wszystkich Twoich Sessions (alert typu „lifer”). Opiera się na historii gatunków z całego okresu użytkowania, uzupełnianej automatycznie z istniejących Sessions przy pierwszym uruchomieniu.
- **Rzadki dla tej lokalizacji** — alert, gdy prawdopodobieństwo według geomodelu dla bieżącej lokalizacji jest niższe od konfigurowalnego progu. Odczyt na żywo pod suwakiem wyjaśnia dokładnie, co wywoła bieżąca wartość (na przykład *„Alerty dla gatunków o prawdopodobieństwie poniżej 5% w tej lokalizacji.”*).
- **Lista obserwacyjna** — alert tylko dla gatunków dodanych do zapisanej własnej listy. W tym kroku kreatora możesz tworzyć nowe listy obserwacyjne, edytować istniejące w osobnym pełnoekranowym edytorze z przeszukiwalną taksonomią i opcją *Importuj z pliku* (dowolny zwykły plik `.txt` lub `.csv` z nazwami naukowymi) oraz usuwać listy, których już nie potrzebujesz.

Pod selektorem trybu znajduje się suwak *Minimalna pewność*, którego dolna granica jest automatycznie ustawiana na próg pewności Session (alerty nigdy nie są czulsze niż same wykrycia). Sekcja **Zaawansowane** udostępnia sterowanie ograniczaniem — okno karencji po starcie, twardy minimalny odstęp między dwoma alertami oraz przesuwny limit na minutę z opcją łączenia alertów ponad limit w jedno powiadomienie zbiorcze — wszystko z wyborem odznak jednym dotknięciem. Przy pierwszym przełączeniu na tryb inny niż Wyłączone kreator poprosi za Ciebie o uprawnienie do powiadomień na Androidzie.

### 4. Wskazówki terenowe

Krótka lista kontrolna przed startem, w ramach konfiguracji.

### 5. Gotowe

Ekran gotowości podsumowuje aktywną konfigurację Survey, zanim rozpoczniesz przyciskiem :material-play:.

## Panel Survey na żywo

Ekran trwającego Survey ma trzy główne zakładki oraz listę ostatnich wykryć.

### Górny pasek

- :material-stop: — zakończ Survey
- :material-timer: — czas, który upłynął
- :material-help-circle-outline: — otwórz panel pomocy Survey
- :material-tune: — otwórz ustawienia Survey

### Zakładki

- :material-map-outline: — mapa trasy i wykrycia na mapie
- :material-equalizer: — spektrogram
- ikona wykresu — statystyki podsumowujące i rozkład gatunków

### Statystyki i wykrycia

Pod treścią zakładki panel Survey pokazuje pasek statystyk i listę ostatnich wykryć. Dotknięcie wykrycia otwiera nakładkę ze szczegółami gatunku.

Każdy wiersz wykrycia udostępnia też te same działania co w [Przeglądzie Session](session-review.md): znacznik :material-check: **Potwierdź** dodawany jednym dotknięciem oraz menu :material-dots-vertical: **Więcej** z opcjami **Udostępnij wykrycie** i **Usuń wykrycie** (z możliwością cofnięcia przez SnackBar) — dzięki temu możesz zweryfikować, udostępnić lub usunąć zakłócone trafienie już w trakcie rejestracji, zamiast czekać na przegląd po zakończeniu.

Te same działania są dostępne z **mapy trasy na żywo**: dotknij znacznika wykrycia, aby otworzyć panel odtwarzacza fragmentów z potwierdzaniem, udostępnianiem i usuwaniem. Udostępnianie w trakcie Survey działa nawet wtedy, gdy wybrano jedno ciągłe nagranie WAV zamiast fragmentów dla poszczególnych wykryć — odpowiednie okno dźwiękowe jest wycinane z trwającego pliku w locie. Szczegóły znajdziesz w [Przeglądzie Session → Udostępnianie pojedynczego wykrycia](session-review.md#udostępnianie-pojedynczego-wykrycia).

### Zapisywanie obserwacji

Przycisk :material-plus-circle-outline: podczas Survey na żywo otwiera małe menu z opcjami **Dodaj gatunek** i **Dodaj notatkę**. **Dodaj gatunek** otwiera ten sam selektor co w [Przeglądzie Session](session-review.md#dodawanie-gatunku-ręcznie): wybierz gatunek, następnie zaznacz :material-ear-hearing: **Słyszany** lub :material-eye: **Widziany** w panelu potwierdzenia i dotknij **Dodaj**. Wpis otrzymuje znacznik czasu z tej chwili, jest wiązany z bieżącą pozycją GPS i pojawia się natychmiast na liście wykryć oraz na mapie trasy z odznaką wpisu ręcznego i odpowiednimi symbolami ucha i oka.

Notatek głosowych celowo tu nie ma: mikrofon jest zajęty rejestracją samego Survey. Dodaj je w Przeglądzie Session po zakończeniu Survey.

## Praca w tle

Tryb Survey utrzymuje w trakcie nagrywania stałe powiadomienie pierwszoplanowe, aby Android nie wstrzymał potoku dźwiękowego. Rozwinięte powiadomienie pokazuje:

- czas, który upłynął, liczbę wykryć, liczbę gatunków i przebyty dystans, oraz
- **trzy ostatnie unikalne gatunki** wraz z ich pewnością i względnym znacznikiem czasu (`przed chwilą`, `42 s temu`, `5 min temu`, `2 godz. temu`).

Powiadomienie — tytuł, ostatnie wykrycia i stopka ze statystykami — jest w pełni przetłumaczone na wybrany język aplikacji i korzysta z tych samych ustawień języka nazw gatunków i *Pokazuj nazwy naukowe* co karty w aplikacji.

Alerty gatunkowe (jeśli są włączone) pojawiają się na osobnym kanale powiadomień Androida, dzięki czemu możesz wyciszyć alerty niezależnie od cichego, trwającego powiadomienia o nagrywaniu. Ikona alertu odpowiada ikonie powiadomienia pierwszoplanowego (monochromatyczny ptak), a treść alertu pokazuje wyłącznie *powód* — *„Pierwsze wykrycie w tym Survey”*, *„Na Twojej liście obserwacyjnej”*, *„Wykryty w tej lokalizacji z prawdopodobieństwem poniżej 4%”* — pozostawiając nazwę gatunku w pogrubionym tytule powiadomienia, gdzie Android wyświetla ją największą czcionką.

Gdy **wznawiasz** niedokończony Survey z Biblioteki Sessions, potok alertów jest konfigurowany na nowo według Twoich *bieżących* preferencji powiadomień — a nie tych, które obowiązywały w dniu rozpoczęcia Survey. Wyłącz alerty (albo zmień tryb, listę obserwacyjną lub ograniczanie) przed dotknięciem Wznów, a wznowiony Survey od razu zastosuje nowe ustawienia.

## Przeglądanie na mapie

Pełnoekranowy widok mapy Survey (przycisk :material-fullscreen: w Przeglądzie Session) otwiera odtwarzacz fragmentów po dotknięciu znacznika. W wierszu sterowania obok przycisku odtwarzania znajdują się przyciski poprzedni i następny — przechodzą przez wykrycia w kolejności chronologicznej, ale **tylko przez te widoczne aktualnie na mapie**, więc każdy aktywny filtr gatunku, pewności lub odznaki trybu odpowiednio zawęża listę odtwarzania. Przyciski szarzeją przy pierwszym i ostatnim wykryciu na przefiltrowanej liście.

## Po zatrzymaniu

BirdNET Live zapisuje zakończony Survey i otwiera [Przegląd Session](session-review.md).
