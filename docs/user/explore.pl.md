# Przeglądaj

Tryb Przeglądaj pokazuje gatunki przewidywane dla bieżącej lokalizacji i pory roku na podstawie geomodelu BirdNET.

## Jak go otworzyć

Otwórz **Przeglądaj** ze stopki ekranu startowego przyciskiem :material-magnify:.

## Pasek aplikacji i nagłówek

### Pasek aplikacji

- :material-refresh: — odśwież lokalizację i zbuduj od nowa listę przewidywanych gatunków

### Nagłówek lokalizacji

Nagłówek pokazuje:

- bieżącą nazwę miejsca uzyskaną z geokodowania odwrotnego, jeśli jest dostępna
- współrzędne pod nazwą miejsca
- :material-help-circle-outline: — otwarcie panelu pomocy trybu Przeglądaj

## Lista gatunków

Każda karta gatunku może zawierać:

- dołączone zdjęcie gatunku
- nazwę zwyczajową
- opcjonalnie nazwę naukową
- odznakę klasy liczebności

Dotknij karty, aby otworzyć nakładkę ze szczegółami gatunku.

### Klasy liczebności

Zamiast surowego odsetka każda karta pokazuje **klasę liczebności** dla bieżącego miejsca i pory roku. Odznaka łączy dwie wskazówki:

- **okrąg**, który wypełnia się od ⅙ do pełna wraz ze wzrostem prawdopodobieństwa gatunku
- **pierwszą literę** nazwy klasy (pełną nazwę odczytują czytniki ekranu i widać ją w nakładce ze szczegółami gatunku)

Kolor odznaki podąża za wspólną skalą ocen aplikacji i przechodzi od czerwonego (mniej prawdopodobne) do zielonego (bardziej prawdopodobne) wraz ze wzrostem klasy.

Jest sześć klas, od najbardziej do najmniej prawdopodobnej:

| Klasa | Znaczenie |
| --- | --- |
| **Bardzo liczny** | Jedno z najsilniejszych przewidywań w tym miejscu |
| **Liczny** | Bardzo prawdopodobny |
| **Częsty** | Prawdopodobny |
| **Nieliczny** | Możliwy |
| **Skąpy** | Mało prawdopodobny |
| **Rzadki** | Jedno z najsłabszych przewidywań w tym miejscu |

Klasy są **względne wobec bieżącej lokalizacji**. Dostosowują się do tego, jak silnie geomodel przewiduje gatunki na danym obszarze, więc granice przesuwają się wraz z lokalnym rozkładem ocen: w miejscu z wieloma pewnymi przewidywaniami gatunek potrzebuje bardzo wysokiej oceny, aby trafić do klasy **Bardzo liczny**, natomiast na obszarze ze słabszymi przewidywaniami ta sama klasa jest osiągana przy niższej ocenie. Ta sama ocena może więc w różnych miejscach należeć do różnych klas, dzięki czemu ranking wszędzie pozostaje sensowny.

## Nakładka ze szczegółami gatunku

Nakładka może pokazywać:

- większe zdjęcie
- informację o autorze zdjęcia
- nazwę zwyczajową i naukową
- dołączony opis, jeśli jest dostępny
- wykres spodziewanej częstości tygodniowej
- odnośniki zewnętrzne, na przykład do eBird, iNaturalist lub Wikipedii, jeśli są dostępne dla danego gatunku

## Do czego służy tryb Przeglądaj

Przeglądaj to widok informacyjny w aplikacji, uwzględniający lokalizację. Pomaga porównać bieżący kontekst lokalizacji z gatunkami, które możesz napotkać.

Sam z siebie **nie** zmienia zapisanych danych Session. Filtrowaniem wykryć sterujesz osobno w [Ustawieniach](settings.md).
