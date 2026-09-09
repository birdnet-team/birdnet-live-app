# Przegląd Session

W Przeglądzie Session BirdNET Live zamienia surowe wykrycia w zapis, który możesz edytować.

## Jak się tam dostać

BirdNET Live otwiera Przegląd Session automatycznie po zakończeniu:

- Session trybu Live
- liczenia punktowego
- Survey
- analizy pliku

Możesz też otworzyć ponownie dowolną zapisaną Session z [Biblioteki Sessions](session-library.md).

## Główne obszary

### Podsumowanie i odtwarzanie

Przegląd Session łączy odtwarzanie, poruszanie się po spektrogramie i listę gatunków. Przy Sessions trybu Survey może też pokazywać kontekst na mapie.

Nagłówek podsumowania u góry ekranu zawiera datę, odznakę lokalizacji (szerokość i długość geograficzną oraz opcjonalnie ustaloną nazwę miejsca, gdy włączone jest **Ustawienia → Prywatność → Zezwalaj na wyszukiwanie nazw miejsc**) oraz — gdy w chwili nagrywania włączone było **Ustawienia → Prywatność → Zezwalaj na sprawdzanie pogody** — **wiersz pogody** pod lokalizacją, pokazujący warunki zarejestrowane na koniec Session: jednowierszowy zapis w rodzaju *„20,1 °C · Słaby deszcz · 3,2 m/s SW”* poprzedzony ikoną pogody. Dotknij wiersza, aby rozwinąć mały panel z temperaturą, wiatrem, opadami i zachmurzeniem oraz informacją o źródle Open-Meteo. Ten sam odczyt trafia również do eksportu JSON, bloku metadanych Session i raportu HTML.

Pasek spektrogramu nad odtwarzaczem jest interaktywny: dotknij, aby przeskoczyć, przeciągnij jednym palcem, aby przewijać oś czasu, i **rozsuń dwa palce, aby przybliżyć** wąskie okno czasowe — przydaje się, gdy chcesz sprawdzić rozkład nakładających się odgłosów albo rozłożyć na czynniki szybki tryl. Zsuń palce z powrotem, aby wrócić do domyślnego widoku 10 sekund. Przycisk odtwarzania w nagłówku gatunku zawsze wybiera pierwszy klaster, który faktycznie ma nagrany fragment, więc przycisk jest dostępny zawsze, gdy któreś z wykryć tego gatunku da się odtworzyć.

### Lista gatunków

Gatunki są pogrupowane w rozwijane wiersze. Możesz przeglądać wykrycia według gatunków i poruszać się po nagraniu w trakcie ich sprawdzania. Wiersze klastrów pod rozwiniętym gatunkiem są wcięte, dzięki czemu karta gatunku nadrzędnego pozostaje wizualnie odrębna od podrzędnych.

Pole wyszukiwania nad listą filtruje gatunki po nazwie zwyczajowej lub naukowej, więc odnalezienie jednego konkretnego ptaka w Session ze stoma gatunkami to kilka znaków zamiast długiego przewijania. Przycisk :material-sort: obok zmienia kolejność gatunków:

- **Najwyższa pewność** (domyślnie) — najpierw gatunki o najwyższej pewności pojedynczego wykrycia. Dobre do przesiewania najpewniejszych oznaczeń. Gdy w tym trybie rozwiniesz gatunek, wykrycia z odtwarzalnymi fragmentami pojawią się przed tymi bez fragmentu, a dalej według pewności.
- **Najwięcej wykryć** — najpierw gatunki o największej liczbie wykryć. Dobre do wychwycenia dominujących śpiewaków.
- **A → Z** — alfabetycznie według nazwy zwyczajowej. Przewidywalne, zgodne z językiem i łatwe do przejrzenia, gdy Session zawiera wiele gatunków.
- **Kolejność wykrycia** — chronologicznie według czasu pierwszego wykrycia. Historyczne ustawienie domyślne; przydatne przy przeglądaniu razem z osią czasu spektrogramu.

Wybrane sortowanie jest zapamiętywane między Sessions.

### Dodawanie gatunku ręcznie

Przycisk :material-plus-circle-outline: na pasku narzędzi otwiera selektor gatunków dla ptaków, które BirdNET pominął. Wybranie wyniku wyszukiwania nie dodaje go od razu — najpierw wysuwa się panel potwierdzenia z wybranym gatunkiem i dwoma polami wyboru:

- :material-ear-hearing: **Słyszany** — usłyszałeś ptaka.
- :material-eye: **Widziany** — zobaczyłeś ptaka.

Zaznacz jedno, oba albo żadne, a następnie dotknij **Dodaj**. **Anuluj** — albo przesunięcie w dół — wraca do wyszukiwania, więc pomyłka nic nie kosztuje. **Słyszany** jest zaznaczone domyślnie, a Twój wybór przenosi się na kolejny dodawany gatunek, więc zapisując serię ptaków, które tylko widziałeś, wystarczy raz zaznaczyć **Widziany**. Pozostawienie obu niezaznaczonych zapisuje wpis bez typu obserwacji, a nie jako „żadne”.

Wybór jest przechowywany przy wykryciu i pokazywany jako mały symbol ucha lub oka obok odznaki wpisu ręcznego wszędzie tam, gdzie to wykrycie się pojawia — w nagłówkach gatunków, wierszach klastrów, panelu odtwarzacza fragmentów i na liście podczas Survey na żywo. Trafia też do eksportów: kolumna `Evidence` w tabelach CSV i Raven, pole `evidence` w JSON oraz odznaka w raporcie HTML. Ten sam panel pojawia się przy **Zamień gatunek**, wstępnie wypełniony tym, co dany zapis już zawierał.

### Działania na pojedynczym wykryciu

Wszędzie, gdzie pojawia się wykrycie — na liście gatunków, w panelu odtwarzacza fragmentów, na liście podczas Survey na żywo i na znacznikach mapy Survey — obowiązuje ten sam zestaw działań:

- :material-check: **Potwierdź** — znacznik dodawany jednym dotknięciem, który oznacza wykrycie jako zweryfikowane wzrokowo lub słuchowo. Potwierdzone klastry i znaczniki mapy otrzymują mały zielony znacznik, aby od razu rzucały się w oczy, a oznaczenie trafia do każdego formatu eksportu.
- :material-dots-vertical: **Więcej** — otwiera menu z opcjami:
    - :material-share-variant: **Udostępnij wykrycie** — zobacz *Udostępnianie* poniżej.
    - :material-swap-horizontal: **Zamień gatunek** — wybierz inny gatunek dla tego wykrycia.
    - :material-delete-outline: **Usuń wykrycie** — natychmiast usuwa wiersz. Na kilka sekund pojawia się pasek SnackBar z opcją cofnięcia, więc pomyłki da się odwrócić. Bez okna potwierdzenia.
    - :material-delete-sweep-outline: **Usuń gatunek** — usuwa z Session wszystkie wykrycia danego gatunku naraz, z tą samą możliwością cofnięcia. Przydatne, gdy chcesz jednym ruchem usunąć błędnie oznaczone źródło hałasu, zamiast rozwijać gatunek i kasować klastry po kolei.

#### Skróty gestami na wierszach przeglądu

Na liście gatunków możesz też zadziałać na wykryciu, przesuwając wiersz w poziomie:

- przesuń w **prawo** → usuń (z możliwością cofnięcia)
- przesuń w **lewo** → otwórz nakładkę zamiany gatunku

Oba tła mają własne kolory (czerwień błędu i błękit podstawowy), więc efekt gestu jest oczywisty, zanim go dokończysz.

Przesunięcie wiersza z **nagłówkiem gatunku** (w lewo lub w prawo) usuwa naraz wszystkie wykrycia tego gatunku, z tą samą możliwością cofnięcia. Przydatne przy porządkowaniu Session pełnej błędnie oznaczonego hałasu.

### Udostępnianie pojedynczego wykrycia

Pozycja :material-share-variant: **Udostępnij wykrycie** używa tych samych opcji co **Ustawienia → Eksport i synchronizacja**. Eksportuje tylko to wykrycie w wybranych artefaktach Raven, CSV, JSON, GPX, HTML i metadanych aplikacji. Gdy włączona jest opcja **Dołącz pliki audio**, pakiet zawiera też dźwięk wykrycia; opcja **Zawsze udostępniaj dźwięk jako WAV** jest respektowana. Gdy wszystkie formaty towarzyszące, HTML i metadane aplikacji są wyłączone, systemowy panel udostępniania otrzymuje surowy fragment dźwięku zamiast ZIP.

Załącznik dźwiękowy jest ustalany w tej kolejności:

1. **Dla Sessions nagrywających jeden ciągły plik**: dźwięk od znacznika początku do końca wykrycia jest wycinany bezpośrednio z nagrania. Obsługiwane są ciągłe nagrania WAV i FLAC; skompresowane źródła z File Analysis są dekodowane jako WAV.
2. W przeciwnym razie używany jest zapisany własny fragment wykrycia, jeśli znajduje się na dysku.
3. Jeśli nie ma źródła dźwięku ani wybranego artefaktu eksportu, udostępniany jest krótki tekst z gatunkiem, pewnością, znacznikiem czasu UTC i lokalizacją.

### Notatki głosowe

Do poszczególnych zapisów wykryć możesz dołączyć krótkie komentarze głosowe:

- **Nagrywanie**: dotknij przycisku :material-dots-vertical: przy klastrze wykrycia i wybierz **Nagraj notatkę głosową**, aby otworzyć okno notatki głosowej. Dotknij dużego przycisku mikrofonu, aby rozpocząć nagrywanie. Przebieg fali na żywo odzwierciedla Twój głos w czasie rzeczywistym. Po zakończeniu dotknij przycisku stop.
- **Odsłuch**: po nagraniu możesz odsłuchać notatkę we wbudowanym odtwarzaczu. Aby ją zastąpić, dotknij przycisku **Nagraj ponownie**. Aby ją zachować, dotknij przycisku **Zapisz**.
- **Usuwanie**: jeśli wykrycie ma już dołączoną notatkę głosową, możesz ją usunąć z menu albo z okna notatki głosowej.
- **Formaty zależne od platformy**: na Androidzie i innych platformach notatki głosowe są nagrywane w mocno skompresowanym formacie AAC (`.m4a`) przy 16 kHz. Na iOS automatycznie używany jest format WAV/PCM16 (`.wav`), aby uniknąć problemów zgodności CoreAudio z aktywnymi sesjami dźwiękowymi aplikacji. Oba formaty są w pełni obsługiwane przez pakowanie do eksportu ZIP.
- **Eksport**: przy eksporcie Session do ZIP notatki głosowe trafiają do katalogu `memos/`, a ich ścieżki względne są zapisywane w metadanych JSON i CSV.

### Mapa trasy Survey

Sessions trybu Survey pokazują małą wbudowaną mapę śladu GPS i znaczników wykryć. Dotknij znacznika na tej mapie, aby wskazać wykrycie — mapa wyśrodkuje się na nim. Dotknij przycisku :material-fullscreen: **rozwiń** (u góry po prawej stronie mapy), aby otworzyć **mapę pełnoekranową**; jeśli wcześniej wskazano wykrycie, mapa pełnoekranowa otworzy się wyśrodkowana i przybliżona na tym wykryciu, więc nie stracisz miejsca.

#### Znaczenie znaczników

- **Pewność jest kodowana kolorem** za pomocą skali bezpiecznej dla osób z zaburzeniami widzenia barw: od niskiej do wysokiej pewności biegnie od fioletowo-niebieskiego przez turkus i żółć aż po czerwień. Jasność skali zmienia się monotonicznie, więc pozostaje czytelna w skali szarości i przy zaburzeniu widzenia czerwieni i zieleni.
- **Wykrycia z dźwiękiem** mają kolorowy pierścień wokół zdjęcia gatunku oraz odznakę odtwarzania w rogu — dotknij ich, aby otworzyć ten sam panel odtwarzacza fragmentów co gdzie indziej, z potwierdzaniem, udostępnianiem, zamianą i usuwaniem.
- **Wykrycia bez dźwięku** (brak fragmentu na dysku) są mniejsze, przygaszone i mają neutralnie szary pierścień, dzięki czemu wykrycia z dźwiękiem zawsze czytają się jako treść główna.
- **Nakładające się znaczniki w tym samym miejscu** są układane według ważności: wyróżnione > z dźwiękiem > wyższa pewność, więc cichy znacznik o niskiej pewności nigdy nie zasłoni silnego wykrycia z dźwiękiem.
- **Poniżej przybliżenia 14,5** sylwetki zamieniają się w kolorowe kropki, których wielkość odpowiada pewności, a gęste skupiska zwijają się w bąbelek z liczbą (grupowanie wyłącza się przy przybliżeniu 15).

#### Filtrowanie

Mapa pełnoekranowa ma stałą **odznakę filtra** zakotwiczoną u góry po prawej stronie. Dotknij jej, aby otworzyć panel filtrów; etykieta odznaki zawsze pokazuje, co obecnie obowiązuje (*„Wszystkie gatunki”*, *„Z dźwiękiem”*, *„≥ 80%”* albo nazwa jednego gatunku). Dostępne filtry:

- **Wszystkie wykrycia** (domyślnie).
- **Z fragmentem dźwiękowym** — tylko wykrycia, których fragment nadal jest na dysku i da się odtworzyć.
- **Dodane ręcznie** — tylko wykrycia dodane przez Ciebie w Przeglądzie Session (bez wykrytych automatycznie).

Możesz też ograniczyć wykrycia według poziomu pewności. Suwak ustawia dolną granicę pewności (zaczyna się od 10%).

Pod suwakiem pewności znajduje się selektor **Ogranicz do gatunku**, który pozwala zawęzić mapę do jednego gatunku — przydatne przy pytaniu „gdzie dokładnie na trasie słyszałem drozda?”. Pozycja *Wszystkie gatunki* usuwa ograniczenie. Filtry łączą się ze sobą: na przykład *Z fragmentem dźwiękowym* + *Drozd śpiewak* + *> 80%* pokaże tylko odtwarzalne znaczniki drozda śpiewaka z wynikiem powyżej 80%.

Gdy filtr jest aktywny, tytuł na pasku aplikacji zyskuje podtytuł z liczbą dopasowań (na przykład *„7 wykryć”*). *Resetuj* w panelu przywraca ustawienie domyślne.

## Ikony paska narzędzi

Pasek narzędzi używa tych samych znaczeń ikon, które opisano w [Ikonach i elementach sterujących](icons-and-controls.md):

- :material-plus-circle-outline: — dodaj treść
- :material-undo-variant: / :material-redo-variant: — przechodź przez zmiany
- :material-content-cut: — tryb przycinania
- :material-content-save: — zapisz zmiany
- :material-share-variant: — wyeksportuj lub udostępnij
- :material-delete-outline: — odrzuć Session
- :material-play: — kontynuuj Survey, gdy ta akcja jest dostępna
- :material-help-circle-outline: — otwórz panel pomocy Przeglądu Session
- :material-tune: — otwórz ustawienia

## Typowe zadania podczas przeglądu

- sprawdzenie wykryć w zestawieniu z odtwarzaniem i kontekstem spektrogramu
- dodanie gatunku lub adnotacji
- przycięcie nagrania do użytecznego fragmentu
- eksport przejrzanego zestawu wyników

## Eksport

Sposób eksportu zależy od opcji wybranych w [Ustawieniach](settings.md). Aplikacja potrafi spakować wykrycia oraz opcjonalnie dźwięk do wybranego formatu eksportu. Każdy eksport zawiera metadane pochodzenia — wersję aplikacji, nazwę i wersję modelu, język nazw gatunków, znacznik czasu eksportu, ustawienia zachowane wraz z Session oraz odpowiednie opcje eksportu — zapisane w pliku towarzyszącym `<prefix>.metadata.json` (ZIP) albo w bloku `meta` na najwyższym poziomie (JSON), dzięki czemu eksporty same się opisują i są odtwarzalne.

Blok `settings` w eksporcie JSON zapisuje wartości, które *faktycznie zastosowano do tej Session* — czułość, tryb i liczbę okien score-poolingu, wzmocnienie mikrofonu oraz częstotliwość odcięcia filtra górnoprzepustowego — a nie to, co akurat jest ustawione teraz. Dzięki temu możesz odtworzyć wynik po miesiącach albo porównać dwa Surveys, nie pamiętając, gdzie stały wtedy suwaki.

Wszystkie znaczniki czasu w nazwach eksportowanych plików (`BirdNET_Live_<date>_<time>_…`) oraz wewnątrz treści CSV i JSON są zapisywane w *bieżącym* czasie lokalnym Twojego telefonu. Same zapisy są przechowywane w UTC i przeliczane przy eksporcie.
