# Biblioteka Sessions

Biblioteka Sessions to archiwum zapisanych Sessions i przetworzonych plików.

## Jak ją otworzyć

Użyj przycisku :material-music-box-multiple-outline: w stopce ekranu startowego.

## Co pokazuje biblioteka

Każdy wpis podsumowuje zapisany zestaw wyników wraz z typem, datą, czasem trwania, liczbą gatunków i liczbą wykryć.

Typy Sessions używają tych samych ikon co ekran startowy:

- :material-microphone: — Session trybu Live
- :material-file-music: — Session analizy plików
- :material-map-marker: — Session trybu Point Count
- :material-routes: — Session trybu Survey

## Elementy paska aplikacji

- :material-magnify: — wyszukiwanie po dacie, typie Session, nazwie miejsca, współrzędnych, nazwie zwyczajowej lub naukowej
- menu trybu widoku — przełączanie między **Szczegółowym**, **Zwartym** i **Według gatunków**
- :material-swap-vertical: — zmiana kolejności sortowania

## Tryby widoku

### Szczegółowy

Pokazuje pełne karty Sessions z większą liczbą metadanych.

### Zwarty

Pokazuje ciaśniejsze wiersze, aby szybciej przeglądać. Każdy wiersz ma po prawej przycisk :material-chevron-down:, który rozwija go w miejscu do pełnej treści karty z widoku szczegółowego — przydatne, gdy chcesz szybko podejrzeć statystyki jednej konkretnej Session bez utraty pozycji przewijania.

### Według gatunków

Grupuje Sessions według gatunków i rozwija je do Sessions, które zawierają dany gatunek.

## Sortowanie

Sortuj Sessions według **daty** (od najnowszych lub najstarszych), **nazwy** (A–Z lub Z–A) albo **czasu trwania** (od najdłuższych lub najkrótszych). Sortowanie po czasie trwania przydaje się, gdy chcesz znaleźć najdłuższy Survey w tygodniu albo najkrótszy trzydziestosekundowy test, który przypadkiem zapisałeś.

Gdy Sessions są pogrupowane według dni, każdy wiersz nagłówka dnia pokazuje najpierw menu (:material-dots-vertical:) z działaniami dla całego dnia, a strzałkę rozwijania i zwijania na końcu wiersza. Strzałka jest *ostatnim* elementem — tak samo jak w każdej innej rozwijanej liście w aplikacji — więc dotknięcie przy prawej krawędzi zawsze rozwija lub zwija grupę.

## Czas lokalny

Każdy znacznik czasu w Bibliotece Sessions — wiersze listy, nagłówki grup dziennych, odznaki „rozpoczęto” i „zakończono” — jest pokazywany w *bieżącej* strefie czasowej Twojego telefonu. Znaczniki czasu samej Session są zapisywane w UTC, więc Session nagrana w Berlinie i otwarta potem w Nowym Jorku po prostu wyświetli się pięć (lub sześć) godzin wcześniej — dane na dysku pozostają bez zmian. Jeśli podróżujesz podczas długiego Survey, wyświetlany zegar podąża za urządzeniem.

## Działania na wierszu

Na każdym wierszu Session możesz działać na dwa sposoby:

- **Menu z trzema kropkami** (:material-dots-vertical:) po prawej stronie każdej karty otwiera małe menu z opcjami **Otwórz**, **Udostępnij** i **Usuń**. Udostępnianie korzysta z bieżących preferencji z Ustawienia → Eksport (format i „dołącz dźwięk”) i otwiera systemowy panel udostępniania od razu — nie trzeba najpierw otwierać Przeglądu Session, aby wysłać Session do współpracownika.
- **Przesuń** wiersz w lewo lub w prawo, aby go usunąć. Przed usunięciem i tak pojawia się okno potwierdzenia, więc przypadkowe przesunięcie da się odwrócić.

## Co dalej

Dotknij dowolnej Session, aby otworzyć [Przegląd Session](session-review.md).
