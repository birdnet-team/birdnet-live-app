# Przesyłanie

Przesyłanie wysyła zakończone Sessions z wielu telefonów do jednego folderu projektu. Osoba prowadząca projekt konfiguruje folder raz i rozdaje link lub kod QR; każdy uczestnik wkleja go lub skanuje, a od tej chwili dowolną Session można wysłać do tego folderu dwoma dotknięciami z okna dialogowego Udostępnij. Wdrożenia ARU mogą samodzielnie wysyłać każdą zakończoną Session.

Przesyłanie działa w jedną stronę. Aplikacja zapisuje pliki w folderze projektu i nigdy niczego tam nie odczytuje, nie wyświetla ani nie usuwa. Usunięcie Session na telefonie nie dotyka przesłanej kopii, a nic nigdy nie zostanie przesłane, jeśli nie zaznaczysz miejsca docelowego lub nie włączysz automatycznego przesyłania ARU.

## Jak to działa

**Miejsce docelowe** to folder WebDAV, do którego aplikacja może zapisywać. Od razu działają trzy rodzaje:

- udostępnienie **Nextcloud File Drop**, zalecany wybór dla większości projektów;
- dowolny **adres WebDAV** z nazwą użytkownika i hasłem, na przykład folder na własnym koncie w chmurze lub serwer instytucji;
- **referencyjny serwer drop** dostarczany z BirdNET Live, dla osób prowadzących, które chcą tokenów dla poszczególnych uczestników i gotowego eksportu CSV (zobacz [Developer Guide](../developer/upload-drop-server.md)).

Każde przesłanie to **jeden plik ZIP na Session**, nazwany jak eksport Udostępniania, na przykład `BirdNET_Live_2026-05-14_06-30-00_#13.zip`. Zawsze zawiera rekord JSON Session oraz, w zależności od tego, co zaznaczysz, dźwięk, tabele wykryć, raport HTML i plik metadanych aplikacji. ZIP trafia do folderu nazwanego Twoim **identyfikatorem przesyłania**, ośmioznakowym kodem, który aplikacja wyprowadza z losowej tożsamości przechowywanej dla tej instalacji. Folder osoby prowadzącej projekt wygląda więc tak:

```
4ee91c8f/BirdNET_Live_2026-05-14_06-30-00_#13.zip
4ee91c8f/BirdNET_Live_2026-05-14_07-02-10_#14.zip
b27c0e51/BirdNET_Live_2026-05-14_06-45-00_#3.zip
.birdnet-live/4ee91c8f.json
.birdnet-live/b27c0e51.json
```

Folder `.birdnet-live` zawiera po jednym małym pliku rejestracji na urządzenie, zapisywanym przez test połączenia. Nextcloud ukrywa go, chyba że włączono „Pokaż ukryte pliki”. Plik zawiera identyfikator przesyłania, wersję aplikacji, platformę i opcjonalny **identyfikator uczestnika** (imię, e-mail lub numer uczestnika), który wprowadził uczestnik, dzięki czemu osoba prowadząca wie, kto stoi za każdym kodem, a żadne imię nigdy nie staje się nazwą folderu. Ten sam identyfikator jest zapisywany w rekordzie JSON każdej przesłanej Session.

## Dla osób prowadzących projekt

### Opcja A: Nextcloud File Drop

1. W Nextcloud utwórz folder dla projektu, na przykład `Spring Survey 2027`.
2. Otwórz jego panel udostępniania, utwórz **link udostępnienia** i ustaw jego uprawnienia na **File drop (tylko przesyłanie)**. Uczestnicy mogą wtedy dodawać pliki, ale nigdy nie widzą, co wysłali inni.
3. Ustaw na linku **hasło**. Bez niego każdy, kto znajdzie link, może przesyłać do folderu. File Drop nawet wtedy nie da się odczytać, więc brak hasła to wybór, który aplikacja akceptuje bez sprzeciwu.
4. Opcjonalnie ustaw datę wygaśnięcia na koniec projektu.
5. Skopiuj link udostępnienia. Wygląda on tak: `https://cloud.example.org/s/AbCdEf123456`.

Aplikacja sama zamienia ten link na punkt końcowy WebDAV udostępnienia; uczestnicy nigdy nie widzą adresu WebDAV. File Drop nigdy nie nadpisuje: gdy uczestnik przesyła tę samą Session ponownie, Nextcloud zachowuje starszą kopię pod numerowaną nazwą, więc najnowszy plik to ten bez numeru.

Udostępnienia Nextcloud z uprawnieniem **przesyłanie i edycja** również działają, ale aplikacja ostrzeże uczestników, że dane logowania pozwalają wyświetlić zawartość folderu, bo każdy z linkiem może wtedy czytać dane wszystkich innych. Udostępnienia tylko do odczytu są odrzucane przez test połączenia.

### Opcja B: własny folder WebDAV

Działa każdy serwer WebDAV: folder na prywatnym koncie w chmurze, serwer plików instytucji, ownCloud lub Nextcloud ze zwykłym kontem. Uczestnicy wprowadzają adres oraz nazwę użytkownika i hasło w sekcji **Zaawansowane** podczas dołączania. W przypadku konta Nextcloud lub ownCloud użyj **hasła aplikacji** z ustawień bezpieczeństwa konta, nigdy hasła logowania; gdy podano tylko nazwę hosta, aplikacja próbuje też zwykłych lokalizacji Nextcloud i ownCloud na tym hoście.

Takie dane logowania zwykle pozwalają odczytać folder, więc test połączenia pokazuje ostrzeżenie. Jeśli uczestnicy nie należą wszyscy do jednego zespołu, wybierz konfigurację tylko do zapisu.

### Opcja C: referencyjny serwer drop

`tools/webdav_drop_server` w repozytorium źródłowym to mały serwer w Pythonie z tokenami dla poszczególnych uczestników, które możesz unieważnić, poleceniem `collect`, które łączy każdy przesłany rekord JSON w `sessions.csv`, `detections.csv` i `species_summary.csv`, oraz poleceniem `invite`, które drukuje link dołączenia i kod QR. Konfiguracja i wdrożenie są opisane w [Developer Guide](../developer/upload-drop-server.md).

### Tworzenie linku dołączenia i kodu QR

Link dołączenia zawiera w jednym kawałku wszystko, czego potrzebuje uczestnik: miejsce docelowe, dane logowania, nazwę projektu i sugerowane przez Ciebie ustawienia domyślne. Otwórz [stronę dołączania](../join.md) w tym serwisie i wypełnij:

- **Share link or WebDAV address**: link udostępnienia Nextcloud z powyższych kroków lub adres folderu WebDAV.
- **User name**: zostaw puste dla linku udostępnienia Nextcloud.
- **Share password or token**: hasło udostępnienia albo sekret konta lub tokenu.
- **Project name shown in the app**: to, co uczestnicy zobaczą jako nazwę miejsca docelowego. Mogą ją zmienić, ale to jest wartość domyślna.
- **Suggest including audio** i **Suggest Wi-Fi only**: wartości domyślne przełączników miejsca docelowego.

Naciśnij **Build link and QR code**. Wszystko dzieje się w Twojej przeglądarce; nic nie jest nigdzie wysyłane. Sekret znajduje się w części linku po `#`, której przeglądarki nigdy nie przesyłają do serwera WWW hostującego stronę.

Możesz też najpierw dołączyć do miejsca docelowego na własnym telefonie (zobacz poniżej), a następnie otworzyć miejsce docelowe w **Ustawienia → Eksport i synchronizacja → Miejsca docelowe przesyłania** i dotknąć **Pokaż kod dołączenia**. Aplikacja pokazuje ten sam rodzaj kodu QR z przyciskiem **Kopiuj link**.

### Rozdawanie

Wydrukuj kod QR na karcie terenowej, pokaż go na ekranie podczas odprawy lub wyślij link wiadomością. **Traktuj link i kod jak hasło**: każdy, kto go ma, może przesyłać do Twojego projektu. Jeśli wycieknie, zmień hasło udostępnienia lub unieważnij token i rozdaj nowy kod.

Gdy uczestnik zeskanuje kod aparatem telefonu, przeglądarka otwiera małą stronę docelową z przyciskiem **Open in BirdNET Live**, który prowadzi do ekranu Dodaj miejsce docelowe w aplikacji z już wypełnionym linkiem. Wklejenie linku bezpośrednio na tym ekranie działa tak samo.

### Co zobaczysz

Jeden folder na urządzenie, jeden ZIP na Session i ukryte rejestracje `.birdnet-live`. Otwórz ZIP, aby znaleźć rekord JSON (zawsze obecny) oraz tabele, raport i dźwięk, które uczestnik zdecydował się dołączyć. Aby dowiedzieć się, kto stoi za identyfikatorem przesyłania, odczytaj plik rejestracji dla tego kodu lub pole `meta.participant` w dowolnym z jego rekordów JSON. W referencyjnym serwerze drop robi to za Ciebie polecenie `collect`, zapisując kolumnę `participant`.

## Dla uczestników

### Dołączanie do miejsca docelowego

1. Otwórz **Ustawienia → Eksport i synchronizacja → Miejsca docelowe przesyłania** i dotknij **Dodaj miejsce docelowe**. Zeskanowanie kodu QR projektu aparatem lub dotknięcie otrzymanego linku dołączenia prowadzi do tego samego ekranu z już wypełnionym linkiem.
2. Wklej link dołączenia, link udostępnienia Nextcloud lub adres WebDAV w pole **Link dołączenia lub adres serwera**. Przycisk **Wklej** pobiera go ze schowka.
3. Opcjonalnie wprowadź **Identyfikator uczestnika, imię lub e-mail**. Jest zapisywany z każdym przesłaniem, aby osoba prowadząca projekt wiedziała, kto je wysłał, i nigdy nie pojawia się w nazwach folderów. Pod polem aplikacja pokazuje **Twój identyfikator przesyłania**, czyli folder, do którego trafią Twoje przesłania.
4. W przypadku zwykłego adresu WebDAV otwórz **Zaawansowane** i wprowadź **Nazwa użytkownika** oraz **Hasło lub token**. Link udostępnienia Nextcloud nie potrzebuje żadnego z nich; jeśli udostępnienie ma hasło, wpisz je jako hasło.
5. Dotknij **Testuj połączenie**. Aplikacja łączy się z serwerem, tworzy ukryty folder rejestracji, sprawdza, czy dane logowania pozwalają wyświetlić zawartość folderu, i zapisuje Twój plik rejestracji. Wynik to jedno zdanie: **Połączenie działa**, ostrzeżenie, które warto przeczytać, albo błąd z prawdopodobnym rozwiązaniem.
6. Nadaj miejscu docelowemu **Nazwa miejsca docelowego** (wypełnioną wstępnie z linku dołączenia), zdecyduj, czy **Przesyłaj tylko przez Wi-Fi**, i dotknij **Zapisz miejsce docelowe**.

Nic nie zostanie zapisane, dopóki test się nie powiedzie. Dane logowania trafiają do pęku kluczy urządzenia, nigdy do eksportowanych danych.

Ostrzeżenia, które warto rozumieć:

- **Te dane logowania pozwalają wyświetlić zawartość miejsca docelowego** oznacza, że udostępnienie lub konto może odczytać dane innych uczestników. Przesyłanie działa, ale jeśli w projekcie biorą udział osoby spoza Twojego zespołu, poproś osobę prowadzącą o File Drop lub token tylko do zapisu.
- **To udostępnienie nie ma hasła i pozwala wyświetlić zawartość** łączy oba ryzyka: każdy z linkiem może czytać wszystko. Poproś osobę prowadzącą o ustawienie hasła lub użycie File Drop.
- **Ten serwer nie pozwala tworzyć folderów** ma charakter informacyjny: przesyłane pliki mają płaskie nazwy, takie jak `4ee91c8f__BirdNET_Live_….zip`, zamiast folderu.

### Ekran miejsca docelowego

Dotknięcie miejsca docelowego na liście otwiera jego ekran z adresem serwera, datą dodania i ostatniego użycia oraz tymi elementami sterującymi:

- **Zmień nazwę** (ołówek na pasku aplikacji) zmienia nazwę pokazywaną w aplikacji.
- **Przesyłaj tylko przez Wi-Fi** wstrzymuje przesyłanie, gdy telefon korzysta z sieci komórkowej.
- **Przesyłaj wszystkie Sessions automatycznie** dodaje każdą zakończoną Session z dowolnego trybu do kolejki tego miejsca docelowego bez pytania, z domyślnymi ustawieniami Dźwięku i Metadanych z Eksportu i synchronizacji. Gdy ta opcja jest włączona, włączona pozostaje też **Przesyłaj Sessions ARU automatycznie**. Odrzucenie Session później w Session Review anuluje przesyłanie, które się jeszcze nie rozpoczęło, ale to, co już wysłano, pozostaje na serwerze.
- **Przesyłaj Sessions ARU automatycznie** dodaje każdą zakończoną ARU Session do kolejki tego miejsca docelowego bez pytania (zobacz poniżej).
- **Testuj połączenie** powtarza test połączenia, na przykład po tym, jak osoba prowadząca zmieniła hasło.
- **Pokaż kod dołączenia** wyświetla kod QR oraz **Kopiuj link**, aby drugi telefon mógł dołączyć do tego samego miejsca docelowego.
- **Usuń miejsce docelowe** zapomina miejsce docelowe i jego dane logowania oraz porzuca oczekujące przesłania do niego. Już przesłane Sessions pozostają na serwerze.

Pierwszy wpis na liście miejsc docelowych to **Twój identyfikator przesyłania** z identyfikatorem uczestnika pod nim; dotknij go, aby zmienić identyfikator. Zmiana nie przenosi nic na serwerze, ponieważ foldery są nazywane identyfikatorem.

### Przesyłanie Session

Przesyłanie zaczyna się od tej samej akcji **Udostępnij**, której już używasz, w trzech miejscach:

- **menu z trzema kropkami** (:app-moreVert:) karty Session w Bibliotece Sessions;
- przycisk **Udostępnij** po zaznaczeniu kilku Sessions w Bibliotece Sessions;
- ikona **Udostępnij** (:app-share:) na pasku narzędzi Przeglądu Session.

Gdy istnieje co najmniej jedno miejsce docelowe, okno dialogowe Udostępnij ma dwie karty:

- **Zawartość** określa, co zawiera eksport: **Dźwięk** (pełne nagranie lub fragmenty wykryć, gdy zachowano tylko fragmenty) i **Metadane** (tabele, raport i plik metadanych aplikacji włączone w Eksport i synchronizacja). Pola na początku odpowiadają Twoim ustawieniom i dotyczą tylko tego udostępnienia.
- **Wyślij do** wyświetla **Arkusz udostępniania** (inne aplikacje, pliki, wiadomości) i jedno pole na każde miejsce docelowe. Plakietka na karcie zlicza zaznaczone miejsca docelowe. Miejsca docelowe zaznaczone ostatnio są zaznaczone z góry, z wyjątkiem tych, do których ta Session już trafiła: zaczynają odznaczone i pokazują **Przesłano** z datą oraz **Zaznacz, aby przesłać ponownie**. Po otwarciu okna aplikacja po cichu sprawdza każde miejsce docelowe; jeśli serwer oświadcza, że odrzuciłby przesłanie, na przykład z powodu zmiany hasła lub usunięcia udostępnienia, wiersz zmienia kolor na czerwony i pokazuje powód.

Odznacz **Arkusz udostępniania**, a przycisk będzie brzmieć **Prześlij**; gdy zaznaczone są oba, brzmi **Udostępnij i prześlij**. Pasek powiadomienia potwierdza, ile Sessions dodano do kolejki. Session zawsze trafia najpierw do kolejki i jest przesyłana w tle, więc możesz dalej pracować.

### Śledzenie przesyłania

Karta Session w Bibliotece Sessions pokazuje stan jako pierwszy wiersz pod tytułem Session: **W kolejce**, **Oczekiwanie na Wi-Fi**, **Oczekiwanie na sieć**, **Przesyłanie…**, **Przesłano** z datą lub błąd. Dotknij wiersza, aby zobaczyć listę według miejsc docelowych z **Ponów teraz** i **Usuń z kolejki**. Przegląd Session pokazuje ten sam stan jako ikonę chmury na pasku aplikacji; dotknięcie jej otwiera tę samą listę.

Nieudane przesłania ponawiają się samoczynnie z rosnącymi odstępami, do sześciu godzin, przez maksymalnie trzydzieści prób. **Nie powiodło się, ponowna próba później** oznacza, że aplikacja spróbuje ponownie. **Przesyłanie nie powiodło się. Sprawdź ustawienia miejsca docelowego.** oznacza, że serwer odmówił i ponowna próba nie pomoże: zmieniono hasło, wyłączono przesyłanie lub usunięto udostępnienie. Otwórz miejsce docelowe, uruchom **Testuj połączenie**, a jeśli zmieniły się dane logowania, usuń je i dodaj ponownie.

Wiersz i ikona pojawiają się tylko wtedy, gdy co najmniej jedno miejsce docelowe, do którego wysłano Session, nadal istnieje w Ustawieniach. Usuń miejsce docelowe, a znikną, ponieważ „przesłano” nie jest już faktem dotyczącym żadnego miejsca docelowego, które masz.

### Co działa w tle

Przesłania z kolejki są realizowane, gdy aplikacja jest otwarta i za każdym razem, gdy wraca na pierwszy plan. Na Androidzie działają także przy zamkniętej aplikacji: system uruchamia je, gdy tylko dostępna jest odpowiednia sieć, Wi-Fi, jeśli miejsce docelowe tego wymaga, i ponawia próby, aż kolejka będzie pusta. Na iOS przesyłanie działa, gdy aplikacja jest otwarta.

### Ponowne przesyłanie Session

Ponowne przesłanie tej samej Session, na przykład po poprawieniu wykryć w Przeglądzie Session, zapisuje tę samą nazwę pliku w tym samym folderze. Serwery, które na to pozwalają, zastępują plik; Nextcloud File Drop zachowuje natomiast starszą kopię pod numerowaną nazwą. W obu przypadkach osoba prowadząca projekt otrzymuje najnowszą wersję, a nic nie jest usuwane.

## Tryb ARU

Wdrożenia terenowe tworzą wiele Sessions, często gdy nikogo nie ma przy telefonie. Włącz **Przesyłaj Sessions ARU automatycznie** w miejscu docelowym, a każda zakończona ARU Session zostanie dodana do jego kolejki bez okna dialogowego, z domyślnymi ustawieniami Dźwięku i Metadanych z Eksport i synchronizacja. Wdrożenie, które zapisuje każdy cykl jako osobną Session, przesyła cykl po cyklu; połączona Session wdrożenia nie jest przesyłana drugi raz.

Zostaw włączone **Przesyłaj tylko przez Wi-Fi** dla stacji na planie komórkowym, chyba że plan udźwignie dźwięk, i rozważ nagrywanie w trybie **Tylko wykrycia** lub **Wyłączony**, gdy dźwięk byłby zbyt duży do wysłania. Przesłania wypływają wtedy, gdy tylko telefon zobaczy odpowiednią sieć, także gdy aplikacja jest w tle na Androidzie.

## Dwa przykłady z praktyki

### Weekendowy Survey z Nextcloud File Drop

Osoba prowadząca tworzy folder `Birdathon 2027` w uniwersyteckim Nextcloud, udostępnia go jako File Drop z hasłem, wkleja link udostępnienia i hasło na stronie dołączania, nadaje nazwę projektowi i drukuje kod QR na karcie odprawy. Dwadzieścioro wolontariuszy skanuje go w sobotni poranek, wpisuje swoje imię jako identyfikator uczestnika, przechodzi test połączenia i zapisuje.

W niedzielny wieczór każdy wolontariusz otwiera Bibliotekę Sessions, zaznacza Sessions z weekendu, dotyka Udostępnij, zostawia projekt zaznaczony w Wyślij do i dotyka **Prześlij**. Przesłania czekają na domowe Wi-Fi i kończą się w nocy. W poniedziałek osoba prowadząca znajduje dwadzieścia folderów nazwanych identyfikatorami przesyłania, każdy z kilkoma plikami ZIP, i odczytuje imiona wolontariuszy z ukrytych plików rejestracji lub pola `meta.participant` w rekordach JSON.

### Poprawki w Przeglądzie Session, a potem stacja ARU

Uczestnik przegląda Session, usuwa dwa fałszywe wykrycia, dodaje gatunek ręcznie i zapisuje. Ikona chmury na pasku aplikacji Przeglądu Session pokazuje, że Session została przesłana w sobotę. Dotyka ikony Udostępnij na pasku narzędzi, zaznacza projekt w Wyślij do, gdzie zaczyna on odznaczony i pokazuje **Przesłano** z datą, i naciska **Prześlij**. Poprawiony ZIP zastępuje wcześniejszy albo ląduje obok niego pod numerowaną nazwą w File Drop.

Ten sam uczestnik zostawia telefon jako stację ARU przy trzcinowisku z hotspotem Wi-Fi w szałasie. Dołącza do miejsca docelowego projektu na tym telefonie, włącza **Przesyłaj Sessions ARU automatycznie** i zostawia włączone **Przesyłaj tylko przez Wi-Fi**. Każdego ranka zakończone nocne cykle są dodawane do kolejki i przesyłane, gdy stacja jest bezczynna; osoba prowadząca widzi, jak nowe pliki ZIP pojawiają się pod identyfikatorem przesyłania tego telefonu, choć nikt go nie dotyka.

## Prywatność i odpowiedzialność

Miejsca docelowe przesyłania są prowadzone przez organizatorów projektów, nie przez zespół BirdNET. Folder, serwer, kto może go odczytać i jak długo dane są przechowywane, podlegają własnym zasadom prywatności i bezpieczeństwa organizatora; zapytaj go o szczegóły, zanim dołączysz. BirdNET Live zapisuje tylko to, co zdecydujesz się wysłać, i przechowuje dane logowania w pęku kluczy Twojego urządzenia.

Przesłanie zawiera to, co zawierałoby Udostępnienie: rekord JSON Session z wykryciami, czasami, współrzędnymi, nazwą obserwatora i nazwą miejsca, jeśli je ustawiono, identyfikator przesyłania urządzenia, wprowadzony przez Ciebie identyfikator uczestnika i wersję aplikacji; plus zaznaczone przez Ciebie dźwięk, tabele i raport. Przed wysłaniem przejrzyj kartę Zawartość i pomiń dźwięk, gdy nagranie może zawierać głosy lub cokolwiek innego, czego nie chcesz przekazywać projektowi. **Odpowiadasz za to, co przesyłasz.** Nie przesyłaj ani nie udostępniaj danych, które uważasz za prywatne lub poufne, i nie przesyłaj nagrań, których nie możesz przekazywać dalej.

## Rozwiązywanie problemów

| Komunikat | Co oznacza | Co zrobić |
| --- | --- | --- |
| To nie wygląda na link ani adres serwera. | Tekst nie jest adresem URL. | Wklej cały link dołączenia, link udostępnienia lub adres `https://`. |
| Serwer odrzucił dane logowania. | Błędne lub brakujące hasło albo usunięte udostępnienie. Nextcloud odpowiada tak również w przypadku usuniętych udostępnień. | Użyj hasła udostępnienia lub hasła aplikacji; zapytaj osobę prowadzącą, czy udostępnienie nadal istnieje. |
| Ten adres nie jest punktem końcowym WebDAV. | Wklejony tekst to strona internetowa folderu, a nie link udostępnienia lub adres WebDAV. | Wklej link udostępnienia (`…/s/…`) lub adres WebDAV. |
| Przesyłanie nie jest tutaj dozwolone. | Udostępnienie jest tylko do odczytu. | Poproś osobę prowadzącą o File Drop lub uprawnienie do przesyłania. |
| Folder nie istnieje na serwerze. | Adres wskazuje na nic albo folder został usunięty. | Sprawdź adres z osobą prowadzącą. |
| Nie udało się zweryfikować certyfikatu serwera. | Certyfikat z podpisem własnym lub uszkodzony TLS. | Poproś osobę prowadzącą o adres z ważnym certyfikatem. |
| Ten adres używa nieszyfrowanego HTTP. | Nieszyfrowane połączenie poza Twoją sieścią lokalną. | Użyj adresu `https://`. |
| Oczekiwanie na Wi-Fi | Miejsce docelowe jest ustawione na tylko Wi-Fi, a telefon korzysta z sieci komórkowej. | Poczekaj lub wyłącz przełącznik tylko Wi-Fi w miejscu docelowym. |
| Nie powiodło się, ponowna próba później | Tymczasowy problem, taki jak zerwane połączenie lub błąd serwera. | Nic; aplikacja ponawia próbę samoczynnie. **Ponów teraz** wymusza próbę. |
| Przesyłanie nie powiodło się. Sprawdź ustawienia miejsca docelowego. | Serwer odmówił z powodu, którego ponowna próba nie naprawi. | Otwórz miejsce docelowe, uruchom **Testuj połączenie**, a jeśli zmieniły się dane logowania, usuń je i dodaj ponownie. |
| W pęku kluczy urządzenia brakuje danych logowania do tego miejsca docelowego. | Wpis w pęku kluczy został utracony, na przykład po przywróceniu na nowym telefonie. | Usuń miejsce docelowe i dodaj je ponownie. |

Zobacz też ustawienie [Miejsca docelowe przesyłania](settings.md#miejsca-docelowe-przesyłania) oraz przewodniki [Biblioteka Sessions](session-library.md) i [Przegląd Session](session-review.md).
