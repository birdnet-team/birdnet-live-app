# Polityka prywatności BirdNET Live

**Ostatnia aktualizacja:** 6 sierpnia 2026 r.

Niniejsza Polityka prywatności dotyczy **BirdNET Live** (dalej **aplikacja**). Aplikacja jest rozwijana i oferowana przez **BirdNET-Team** (dalej **deweloper** lub **my**).

## Tożsamość aplikacji i dewelopera

| | |
|---|---|
| **Nazwa aplikacji** | BirdNET Live |
| **Nazwa dewelopera** | BirdNET-Team |
| **Kontakt w sprawach prywatności** | [ccb-birdnet@cornell.edu](mailto:ccb-birdnet@cornell.edu) |

BirdNET-Team udostępnia tę politykę we własnym imieniu. Wyjaśnia ona, jak BirdNET Live chroni i przetwarza dane osobowe.

## Przetwarzanie na urządzeniu

Cała analiza dźwięku i identyfikacja gatunków ptaków odbywają się **w całości na Twoim urządzeniu**. Aplikacja korzysta z dwóch modeli sieci neuronowych działających lokalnie:

- **Klasyfikator dźwięku BirdNET+** — analizuje dźwięk z mikrofonu, aby identyfikować gatunki ptaków.
- **Geomodel BirdNET** — przewiduje, które gatunki są prawdopodobne w Twojej lokalizacji i porze roku.

Żadne dane dźwiękowe nigdy nie są przesyłane na zewnętrzne serwery.

## Przetwarzanie danych osobowych

BirdNET-Team nie prowadzi zaplecza serwerowego aplikacji i nie otrzymuje za pośrednictwem BirdNET Live Twoich nagrań, lokalizacji, danych Session ani innych danych osobowych. Aplikacja nie ma kont użytkowników, reklam, analityki, śledzenia ani telemetrii. Przetwarza jednak dźwięk i lokalizację na Twoim urządzeniu, a tylko po włączeniu opcjonalnej funkcji sieciowej wysyła informacje opisane w sekcji **Zasoby zewnętrzne** bezpośrednio do wskazanego dostawcy zewnętrznego.

### Dane przechowywane lokalnie na Twoim urządzeniu:

| Rodzaj danych | Cel | Miejsce przechowywania |
|---------------|-----|------------------------|
| Nagrania audio | Identyfikacja ptaków, odtwarzanie, eksport | Pliki lokalne |
| Wyniki detekcji | Gatunki, pewność, znaczniki czasu | Lokalne pliki JSON sesji |
| Współrzędne GPS | Geotagowanie detekcji, trasy Survey, przewidywania geomodelu | Lokalne pliki JSON sesji |
| Metadane sesji | Historia sesji, przegląd, eksport | Lokalne pliki JSON sesji |
| Migawka pogody (opcjonalnie) | Jednorazowy zapis temperatury, opadów, wiatru, zachmurzenia i kodu pogody na sesję, gdy **Zezwalaj na wyszukiwanie pogody** jest włączone | Lokalne pliki JSON sesji |
| Ustawienia aplikacji | Preferencje użytkownika | SharedPreferences |

### Dołączone dane offline

Zdjęcia gatunków, opisy i dane taksonomiczne są **dołączone do aplikacji** i ładowane z lokalnych zasobów. Nie są wykonywane żadne żądania sieciowe w celu pobrania informacji o gatunkach.

## Zasoby zewnętrzne

Aplikacja może uzyskiwać dostęp do następujących zasobów zewnętrznych. Każdy zasób jest kontrolowany przez niezależny przełącznik w **Ustawienia → Prywatność**, a **wszystkie trzy są domyślnie wyłączone** przy nowej instalacji. Nic nie opuszcza Twojego urządzenia, dopóki nie wyrazisz zgody.

| Zasób | Cel | Kontrolowany przez | Wysyłane w każdym żądaniu |
|-------|-----|--------------------|---------------------------|
| Kafelki mapy (OpenStreetMap Foundation) | Mapa podkładowa dla wyboru lokalizacji, mapy na żywo Survey i mapy Session | **Ustawienia → Prywatność → Zezwalaj na kafelki mapy** | Współrzędne kafelka `(z, x, y)`, Twój adres IP jako część połączenia sieciowego i user-agent BirdNET Live |
| Odwrotne geokodowanie (Nominatim fundacji OpenStreetMap Foundation) | Zamiana współrzędnych GPS na czytelną nazwę miejsca (np. „Berlin, Niemcy”) do wyświetlenia Session | **Ustawienia → Prywatność → Zezwalaj na wyszukiwanie nazw miejsc** | Szerokość/długość geograficzna Session, Twój adres IP jako część połączenia sieciowego i user-agent BirdNET Live |
| Migawka pogody (OpenMeteo GmbH) | Jednorazowy zapis lokalnych warunków (temperatura, opady, wiatr, zachmurzenie, kod WMO) we współrzędnych nagrania i czasie zakończenia | **Ustawienia → Prywatność → Zezwalaj na wyszukiwanie pogody** | Szerokość/długość geograficzna i czas zakończenia Session, Twój adres IP jako część połączenia sieciowego i user-agent BirdNET Live |

Żądania kafelków mapy to żądania HTTPS GET do `tile.openstreetmap.org`. Współrzędne kafelka określają oglądany obszar mapy. Jak każde bezpośrednie żądanie internetowe ujawniają też dostawcy Twój adres IP.

Żądania odwrotnego geokodowania wysyłają szerokość i długość geograficzną sesji do `nominatim.openstreetmap.org` przez HTTPS, wraz z user-agentem BirdNET Live zgodnie z [Zasadami korzystania z Nominatim](https://operations.osmfoundation.org/policies/nominatim/). Rozpoznana nazwa miejsca jest zapisywana lokalnie z sesją, więc każda sesja jest geokodowana tylko raz. Żadne żądanie nie jest wysyłane, jeśli sesja nie ma współrzędnych GPS lub urządzenie jest offline.

Żądania pogody wysyłają szerokość/długość geograficzną sesji i znacznik czasu zakończenia do `api.open-meteo.com` przez HTTPS, wraz z user-agentem BirdNET Live. [Open-Meteo](https://open-meteo.com/) to bezpłatna usługa, która nie wymaga konta ani klucza API. Zwrócona migawka pogody jest zapisywana lokalnie z sesją, a także zapisywana w eksporcie JSON, bloku `metadata.json` sesji oraz raporcie HTML.

**Przetwarzanie i przechowywanie przez strony trzecie:** BirdNET-Team nie obsługuje tych usług ani nie otrzymuje danych z ich żądań. OpenStreetMap Foundation może przetwarzać dane dostępu do sieci i szczegóły żądań zgodnie ze swoją [Polityką prywatności](https://osmfoundation.org/wiki/Privacy_Policy). Open-Meteo podaje, że logi bezpłatnego API mogą zawierać adresy IP i współrzędne geograficzne i są usuwane po 90 dniach; zobacz [Warunki i Prywatność](https://open-meteo.com/en/terms). Dostawcy mogą przetwarzać dane w innych krajach. Zwrócone wartości są zapisywane lokalnie w Session i trafiają do eksportu tylko wtedy, gdy go utworzysz.

**Wycofanie zgody:** każdą z trzech usług możesz wyłączyć w dowolnym momencie w **Ustawienia → Prywatność**. Zapisane już lokalnie nazwy miejsc i migawki pogody pozostają dołączone do sesji, w których zostały zarejestrowane; usuń te sesje z Biblioteki sesji lub użyj **Ustawienia → Strefa zagrożenia → Wyczyść wszystkie dane**, aby usunąć te dane historyczne.

**Nie są wykonywane żadne inne żądania sieciowe.** Aplikacja działa w pełni offline.

## Linki zewnętrzne

BirdNET Live zawiera linki do witryn stron trzecich, które możesz otworzyć — na przykład strony **eBird**, **iNaturalist** i **Wikipedia** danego gatunku oraz link audio *„Posłuchaj tego gatunku na eBird”* w widoku gatunku, a także linki do witryny projektu BirdNET, kodu źródłowego, przewodnika użytkownika i strony darowizn na ekranie **O aplikacji**. Linki, które opuszczają aplikację, są oznaczone ikoną linku zewnętrznego (↗), abyś rozpoznał je przed dotknięciem.

Dopóki link jest tylko wyświetlany, nic nie jest wysyłane, i żaden link zewnętrzny nigdy nie otwiera się automatycznie — przeglądarka otwiera się dopiero, gdy go dotkniesz. Link otwiera się wtedy w domyślnej przeglądarce Twojego urządzenia i opuszczasz BirdNET Live. Miejsce docelowe jest prowadzone przez stronę trzecią i podlega **jej własnej** polityce prywatności i regulaminowi, a nie niniejszym. Takie witryny mogą niezależnie zbierać informacje o Twojej wizycie — na przykład Twój adres IP, dane urządzenia lub przeglądarki oraz sposób, w jaki korzystasz z ich stron — i ustawiać własne pliki cookie. Nie kontrolujemy treści ani praktyk dotyczących danych witryn zewnętrznych i nie ponosimy za nie odpowiedzialności; zapoznaj się z polityką prywatności każdej witryny.

## GPS i lokalizacja

Aplikacja używa lokalizacji GPS do:

- **Filtrowania gatunków** — przewidywania, które gatunki są prawdopodobne w Twojej lokalizacji.
- **Trybu Survey** — rejestrowania tras GPS i geotagowania detekcji wzdłuż transektu.
- **Trybu Point Count** — oznaczania miejsca obserwacji.

Dane GPS są przechowywane lokalnie i dołączane do eksportów tylko wtedy, gdy jawnie udostępnisz lub wyeksportujesz sesję. Dostęp do lokalizacji wymaga Twojej zgody i można go cofnąć w dowolnym momencie w ustawieniach systemu.

## Eksport danych

Dane sesji możesz eksportować w wielu formatach (Raven Selection Tables, CSV, JSON, GPX) i w **Ustawienia → Eksportuj → Formaty** zaznaczyć dowolną kombinację formatów naraz; wybrane formaty są pakowane razem do jednego pliku ZIP obok klipów audio i opcjonalnego samodzielnego raportu HTML. Eksporty są generowane lokalnie i udostępniane przez systemowy panel udostępniania. Aplikacja nie przesyła danych eksportu na żaden serwer.

## Usuwanie danych

Pojedyncze sesje i ich nagrania można usunąć z Biblioteki sesji. Aby z poziomu aplikacji wymazać lokalne sesje, nagrania, notatki głosowe, niestandardowe listy gatunków, preferencje i pamięci podręczne BirdNET Live, użyj **Ustawienia → Strefa zagrożenia → Wyczyść wszystkie dane**. Możesz też wyczyścić pamięć aplikacji BirdNET Live w ustawieniach systemu operacyjnego lub odinstalować aplikację.

## Kontakt

W sprawach dotyczących prywatności: [ccb-birdnet@cornell.edu](mailto:ccb-birdnet@cornell.edu)
