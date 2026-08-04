# Ustawienia

BirdNET Live używa jednego ekranu ustawień dla wielu sposobów pracy. Przycisk :material-tune: otwiera sekcje istotne dla ekranu, z którego przyszedłeś.

## Jak działa zakres ustawień

- Otwarcie ustawień z ekranu startowego pokazuje pełny ekran.
- Otwarcie ustawień z trybu Live, Survey, Point Count lub Analizy plików zawęża ekran do istotnych sekcji.

## Ogólne

### Motyw

Wybierz **Ciemny**, **Jasny** lub **Systemowy**.

Jeśli włączysz **Kolory dynamiczne**, BirdNET Live spróbuje też dopasować się do systemowej palety barw Twojego urządzenia z Androidem. Działa to tylko na obsługiwanych urządzeniach z Androidem; na iPhonie i iPadzie aplikacja nadal używa standardowego motywu BirdNET Live, więc włączenie przełącznika niczego tam nie zmieni.

Włącz **Motyw o wysokim kontraście**, aby korzystać z czarno-białej jasnej lub ciemnej palety interfejsu z grubszym tekstem i obramowanymi powierzchniami zamiast barwionych kart. Podąża on za wyborem **Ciemny**, **Jasny** lub **Systemowy**, ma pierwszeństwo przed Kolorami dynamicznymi, dopóki jest włączony, i zachowuje kolory ostrzeżeń, zagrożeń, walidacji, trybów, ocen i spektrogramu.

### Język aplikacji

Ustawia język interfejsu.

### Nazwy gatunków

Steruje językiem nazw gatunków. **Systemowy** używa preferowanego języka telefonu, gdy dana nazwa jest dostępna, nawet jeśli interfejs wraca do angielskiego. **Zgodnie z aplikacją** używa zamiast tego języka interfejsu.

### Pokazuj nazwy naukowe

Pokazuje w całej aplikacji nazwy naukowe pod nazwami zwyczajowymi.

### Pokazuj wszystkie wykryte gatunki

Tylko tryb Live i Point Count. Domyślnie wyłączone, więc ekrany te pokazują wyłącznie gatunki wykryte w ostatnim cyklu wnioskowania: w praktyce te, które właśnie się odzywają. Włącz tę opcję, aby każdy gatunek wykryty w trakcie trwającej Session pozostał widoczny na liście, nawet gdy przestanie się odzywać albo spadnie poniżej progu pewności.

Po włączeniu pojawia się **Sortowanie listy gatunków**. **Najnowsze najpierw** pokazuje najpierw gatunki odzywające się teraz, uporządkowane według bieżącej pewności, a potem gatunki zachowane, według najnowszego wykrycia. **Pewność** sortuje według najwyższej pewności osiągniętej przez dany gatunek w trakcie Session, **Alfabetycznie** według przetłumaczonej nazwy zwyczajowej, a **Wystąpienia** według liczby wykryć. W każdym trybie sortowania odsetek i pasek pewności pojawiają się tylko wtedy, gdy dany gatunek właśnie się odzywa (zachowane wiersze gatunków, które umilkły, są przygaszone), a powtarzające się wykrycia mają na końcu wiersza z nazwą zwyczajową odznakę z licznikiem.

### Nazwa obserwatora

Konfiguracja Survey, Point Count i ARU zapamiętuje ostatnio wprowadzoną, niepustą nazwę obserwatora z któregokolwiek z tych trybów i wypełnia ją przy kolejnym przygotowywaniu Session terenowej. Dzięki temu wielokrotne użycie na prywatnym telefonie terenowym pozostaje szybkie, a mimo to możesz zmienić lub wyczyścić obserwatora przed rozpoczęciem Session.

### Identyfikator ARU/stanowiska

Konfiguracja ARU zapamiętuje ostatni niepusty identyfikator ARU/stanowiska i wypełnia go przy kolejnym wdrożeniu. Gdy jest obecny, identyfikator trafia do nazwy Session ARU i nazw plików eksportu, dzięki czemu powtarzane wdrożenia w stałych miejscach pozostają rozpoznawalne również poza aplikacją.

### Wyświetlanie znaczników czasu

Steruje tym, jak czasy poszczególnych wykryć pojawiają się w Przeglądzie Session.

- **Względne** pokazuje przesunięcie od początku nagrania, na przykład `00:12:34`. Najlepsze przy przeglądaniu jednej Session i dopasowywaniu do wskaźnika odtwarzania na spektrogramie.
- **Bezwzględne** pokazuje lokalny czas zegarowy zarejestrowania wykrycia, na przykład `08:42:17`. Najlepsze przy zestawianiu z notatkami terenowymi, dziennikami pogody lub równoległymi nagraniami.

Jeśli wykrycie przypada na inny dzień kalendarzowy niż początek Session (na przykład przy nocnym Survey), czas bezwzględny otrzymuje przyrostek `+1d`, aby nikt nie wziął jutrzejszego porannego chóru za dzisiejszy.

Gdy wybrane jest **Bezwzględne**, pojawia się dodatkowy przełącznik **Pokazuj sekundy w znacznikach czasu**. Wyłącz go, jeśli wolisz zwięźlejsze `08:42` niż `08:42:17` — przydaje się przy przeglądaniu długich list wykryć. Czasy względne zawsze pokazują sekundy, bo przy przeglądaniu potrzebna jest dokładność poniżej minuty, aby zgrać się ze wskaźnikiem odtwarzania na spektrogramie.

Zapis i eksporty niezależnie od tego ustawienia zawsze używają momentów w UTC, więc wybór nigdy nie wpływa na dane — tylko na sposób ich wyświetlania.

## Dźwięk

Te elementy pojawiają się w trybach pracy na żywo opartych na dźwięku.

### Źródło dźwięku

Jeden panel z dwoma niezależnymi elementami: **Mikrofon** — z którego wejścia nagrywać — oraz **Przetwarzanie** — na ile telefon może zmieniać sygnał po drodze. Można je swobodnie łączyć, więc mikrofon USB nagrywany *bez przetwarzania* to całkowicie poprawna konfiguracja. Twój wybór jest zapamiętywany między uruchomieniami aplikacji, a ten sam selektor pojawia się na ekranach konfiguracji Survey, Point Count i ARU. Zmiany działają natychmiast — nawet w trakcie nagrywania aplikacja podmienia mikrofon pod trwającą Session, zamiast czekać na kolejną.

**Mikrofon** wymienia z nazwy każde wejście udostępniane przez telefon: mikrofony USB, przewodowe i Bluetooth, a w wielu telefonach także poszczególne mikrofony wbudowane (na przykład *dolny* i *tylny*). Bezprzewodowe zestawy mikrofonowe, takie jak Rode Wireless GO czy DJI Mic, łączą się przez odbiornik USB-C, więc widnieją tu jako zwykłe urządzenia audio USB w pełnej jakości.

**Przetwarzanie** to najważniejsza część i dotyczy **wyłącznie Androida**. Telefony domyślnie stosują do dźwięku z mikrofonu przetwarzanie dostrojone do mowy — redukcję szumów, kształtowanie widma i automatyczne wzmocnienie — bo mikrofon służy przede wszystkim do rozmów. To przetwarzanie traktuje śpiew ptaków jak szum do stłumienia i żadne zwykłe ustawienie go nie wyłącza. Jedynym wyjściem jest poproszenie Androida o inne *źródło dźwięku*:

| Opcja | Co robi |
|---|---|
| **Domyślne telefonu** | To, co Twój telefon robi zwykle, łącznie z przetwarzaniem mowy. Pierwotne zachowanie i nadal domyślne, aby nic nie zmieniało się istniejącym użytkownikom. |
| **Bez przetwarzania** | Surowy sygnał z mikrofonu — bez redukcji szumów i automatycznego wzmocnienia. Zwykle najlepszy wybór dla ptaków. |
| **Rozpoznawanie mowy** | Również wyłącza redukcję szumów i automatyczne wzmocnienie, a działa na niemal każdym telefonie. |

**Wypróbuj je i porównaj.** To, która wypada najlepiej, naprawdę zależy od urządzenia. *Bez przetwarzania* to ideał, ale Android honoruje je tylko na telefonach, których producent zadeklarował obsługę — na pozostałych po cichu wraca do ustawień domyślnych i brzmi identycznie jak *Domyślne systemu*. Właśnie do tego służy *Rozpoznawanie mowy*: reguły zgodności Androida **wymagają**, aby automatyczne wzmocnienie i redukcja szumów były przy nim wyłączone, więc niezawodnie dostarcza nieprzetworzony dźwięk nawet na telefonach, które ignorują *Bez przetwarzania*. Jeśli przełączenie na *Bez przetwarzania* niczego nie zmienia, przełącz na *Rozpoznawanie mowy*.

Spodziewaj się, że opcje bez przetwarzania będą brzmieć **ciszej** — to brak automatycznego wzmocnienia, a nie usterka. Zwiększ **Wzmocnienie**, aby to nadrobić, jeśli wskaźnik poziomu wygląda nisko.

**Na iOS** element Przetwarzanie jest ukryty, a panel to po prostu lista mikrofonów. iOS przekazuje aplikacji zasadniczo nieprzetworzony dźwięk, więc nie ma tu odpowiednika do wyboru.

### Wzmocnienie

Liniowy wzmacniacz stosowany do przychodzącego dźwięku, zanim trafi do spektrogramu i klasyfikatora. Zostaw wartość **1,0×**, chyba że sygnał wejściowy jest stale zbyt cichy — na przykład mikrofon krawatowy o wysokiej impedancji podłączony do telefonu albo interfejs USB ze zbyt nisko ustawionym przedwzmacniaczem. Podniesienie wzmocnienia powyżej 1,0 nie wyczaruje odgłosów, których mikrofon nigdy nie zarejestrował; jedynie przeskalowuje to, co mikrofon dostarczył, więc głośne dźwięki z bliska mogą się przesterować. Wartości poniżej 1,0 przydają się w rzadkim przypadku, gdy zbyt mocny sygnał nasyca spektrogram.

### Filtr górnoprzepustowy (Hz)

Odcina niskie częstotliwości przed wnioskowaniem za pomocą filtru Butterwortha 24 dB/oktawę — wartość suwaka to częstotliwość odcięcia −3 dB. **0 Hz go wyłącza.** Odcięcie 100–200 Hz usuwa wiatr, dudnienie ruchu ulicznego i odgłosy trzymania urządzenia, nie naruszając większości gatunków; przy 500–1000 Hz zaczynają znikać niskie pohukiwania, sowy, kuraki i buczenie bąka, więc idź tak wysoko tylko wtedy, gdy świadomie pomijasz te gatunki w zamian za znacznie czystszy spektrogram w hałaśliwym środowisku miejskim. Wybrane odcięcie powinno być widoczne jako ostra pozioma linia na spektrogramie na żywo.

## Wnioskowanie

### Czas trwania okna

Steruje długością okna analizy. Dostępne wartości to **1**, **3**, **5**, **7**, **10** i **15** sekund.

### Próg pewności

Określa, jak zachowawcze mają być wykrycia. Domyślnie **35%**, co utrzymuje listę na żywo skupioną na mocniejszych dopasowaniach, a jednocześnie pozostawia miejsce dla odgłosów odległych lub częściowo zamaskowanych. Obniż go, jeśli inwentaryzujesz gatunki rzadkie lub ciche i planujesz przejrzeć więcej kandydatów później; podnieś, gdy hałas otoczenia lub częste fałszywe trafienia zapychają Session.

### Czułość

Przesunięcie na osi x stosowane do surowych ocen prawdopodobieństwa modelu przed score-poolingiem, filtrowaniem geograficznym i progiem pewności. Model dźwiękowy BirdNET zawiera już aktywację sigmoidalną, więc BirdNET Live najpierw przelicza każde prawdopodobieństwo z powrotem do przestrzeni logitów, dodaje przesunięcie czułości, a następnie przelicza je z powrotem na prawdopodobieństwo. Wyższe wartości czynią detektor bardziej pobłażliwym — słabsze lub bardziej niejednoznaczne odgłosy przekraczają próg, kosztem większej liczby fałszywych trafień. Niższe wartości są surowsze i przepuszczają tylko pewne wykrycia. Domyślna wartość **1,0** nie stosuje żadnego przesunięcia i odpowiada wzorcowi BirdNET. Spróbuj **1,25**, jeśli podejrzewasz, że model pomija odległe odgłosy; zejdź do **0,75**, jeśli zalewają Cię niskiej jakości wykrycia pospolitych gatunków. Czułość jest stosowana od razu: zmiana w trakcie Session zadziała od następnego okna wnioskowania.

### Częstość wnioskowania

Steruje tym, jak często BirdNET wykonuje wnioskowanie. Suwak używa tych samych kroków **0,10–1,00 Hz** co konfiguracja Survey i ARU.

BirdNET Live wewnętrznie wygładza oceny w ostatnich oknach wnioskowania, aby
ograniczyć jednorazowe fałszywe trafienia. Ten pooling nie jest dostępny jako
ustawienie użytkownika; domyślnie stosowany jest tryb adaptacyjny z pięcioma
ostatnimi oknami i limitem wieku 10 sekund w czasie rzeczywistym. Przy dużych
częstościach wnioskowania używa poolingu średniej, aby decyzje na żywo były
stabilne; przy wolniejszym rytmie Survey i ARU używa poolingu LME, aby
utrzymać wysoką precyzję przy dłuższych przebiegach. Zaakceptowane wykrycia
pokazują najwyższą niedawną potwierdzoną pewność modelu, dzięki czemu wyraźne
odgłosy mogą nadal osiągać wysoką pewność, zamiast zostać spłaszczone przez
wygładzanie.

## Spektrogram

### Rozmiar FFT

Steruje rozdzielczością częstotliwościową spektrogramu.

### Paleta kolorów

Wybierz **Viridis**, **Magma**, **Plasma**, **Cividis**, **Jet**, **Turbo**, **Odcienie szarości** lub **BirdNET**. **Turbo** to nowoczesna opcja tęczowa, podobna do Jet.

### Czas trwania (szybkość przewijania)

Steruje tym, ile czasu jest widoczne w oknie spektrogramu.

### Zakres częstotliwości

Ustawia górną wyświetlaną częstotliwość.

### Amplituda logarytmiczna

Stosuje skalowanie logarytmiczne do spektrogramu, aby łatwiej było go odczytać.

### Jakość

Steruje tym, jak gładko skalowany jest obraz spektrogramu. **Średnia** to domyślny kompromis. Wybierz **Niską** na starszych telefonach, gdy przewijanie się zacina lub urządzenie się nagrzewa; wybierz **Wysoką**, gdy wolisz płynniejszy obraz, a Twoje urządzenie ma zapas mocy GPU. Intuicja: zmienia to wyłącznie koszt renderowania, a nie analizę dźwięku ani wyniki wykryć.

## Komunikaty głosowe

Ta sekcja decyduje, czy BirdNET Live ma **odczytywać wykrycia na głos przez słuchawki lub głośnik telefonu**, gdy trwa nagrywanie Session. Cała funkcja jest **domyślnie wyłączona**, ponieważ zmienia warunki akustyczne wokół mikrofonu — jej włączenie to świadomy kompromis. Nie ma kreatora konfiguracji: selektory rozwlekłości × częstości poniżej *są* całą konfiguracją, więc w dowolnej chwili możesz dotknąć innego ustawienia i od razu usłyszeć różnicę. Intuicja: przy długich liczeniach nie da się ciągle zerkać na ekran; dyskretny głos w uchu pozwala nie odrywać wzroku od siedliska i wciąż wiedzieć, co przed chwilą było słychać.

### Odczytuj wykrycia na głos (przełącznik główny)

Domyślnie wyłączony. Po włączeniu aplikacja wypowiada każde zaakceptowane wykrycie za pomocą wbudowanej syntezy mowy urządzenia. **Zdecydowanie zalecane są słuchawki** — przy korzystaniu z głośnika telefonu komunikat może zostać wychwycony przez mikrofon i ponownie wykryty, dlatego aplikacja na chwilę wycisza nagrywanie wokół każdej wypowiedzi, aby zapobiec tej pętli (zobacz *Wyciszaj mikrofon podczas mówienia* poniżej).

### Ustawienie rozwlekłości

Ile aplikacja mówi o każdym wykryciu. **Minimalne** wypowiada samą nazwę gatunku (najlepsze przy bardzo długich liczeniach, gdy chcesz tylko sygnału). **Zrównoważone** to ustawienie domyślne — krótkie, zmienne zwroty w rodzaju *„Rudzik”*, *„Słychać rudzika”*, *„Znowu rudzik”*. **Rozmowne** dodaje nieco więcej kontekstu i bardziej przypomina kogoś, kto komentuje obok Ciebie. **Własne** pojawia się automatycznie, gdy ręcznie zmienisz wartości liczbowe w sekcji Zaawansowane. Intuicja: te same ustawienia ograniczania mogą sprawiać wrażenie zbyt cichych albo zbyt gadatliwych zależnie od sformułowań — rozwlekłość pozwala zachować rytm i regulować samą liczbę słów.

### Ustawienie częstości

Jak często aplikacja w ogóle może się odzywać. Pięć stopni od najcichszego do najbardziej rozmownego. **Rzadko** i **Oszczędnie** długo czekają między komunikatami i ograniczają ich tempo — dobrze sprawdzają się przy wielogodzinnych liczeniach, gdy chcesz mieć poczucie aktywności bez ciągłego komentarza. **Normalnie** to domyślny, konwersacyjny rytm. **Często** skraca przerwy i podnosi limit; pasuje do krótkich Sessions trybu Live albo gdy chcesz informacji zwrotnej bliżej czasu rzeczywistego. **Stale** całkowicie usuwa opóźnienie startowe i pozwala aplikacji odzywać się niemal w każdym cyklu wykrywania — przydatne przy pokazach, dla dostępności albo gdy przerwa przed pierwszym komunikatem przy ustawieniu *Często* wydaje Ci się za długa. **Własne** pojawia się, gdy zmienisz pola czasowe w sekcji Zaawansowane. Intuicja: to jedyne pokrętło decydujące o tym, czy aplikacja pozostaje w tle, czy staje się obecna — dotknij innego ustawienia, a nowy rytm usłyszysz w kolejnym cyklu wykrywania, bez przycisku zapisu.

### Głos

Dotknij wiersza głosu, aby wybrać spośród głosów syntezy mowy zainstalowanych dla języka komunikatów, albo zostaw **Głos domyślny**, aby wybór pozostawić urządzeniu. Dostępność i jakość głosów zależą od systemu operacyjnego i zainstalowanych pakietów mowy; dodatkowe głosy możesz zainstalować w ustawieniach syntezy mowy urządzenia.

**Prędkość** obejmuje zakres 0,5×–1,5×; domyślne 1,0× to „normalne” tempo platformy. **Wysokość** obejmuje zakres 0,7×–1,3×. Niewielkie obniżenie wysokości i lekkie spowolnienie mogą ułatwić zrozumienie komunikatów na zewnątrz przy wietrze lub szumie płynącej wody. *Wypowiedz próbkę* pozwala usłyszeć wybrany głos, bieżący styl sformułowań, prędkość i wysokość bez wychodzenia z ustawień. Zmiany obowiązują od następnego komunikatu.

### Zaawansowane

Rozwijana sekcja z kilkoma przełącznikami kierowania dźwiękiem oraz selektorem trybu wyzwalania. Zwykle nie musisz jej otwierać — ustawienia rozwlekłości i częstości powyżej to jedyne pokrętła, które liczą się na co dzień. Wartości liczbowe ograniczania (karencja po starcie, minimalny odstęp, maksimum na minutę, cisza przy serii, reset świeżości) są zebrane w suwaku **Częstość**, więc jest jedno oczywiste miejsce, aby przyspieszyć lub spowolnić rytm.

- **Zezwalaj na głośnik telefonu** — Gdy wyłączone, komunikaty są po cichu pomijane, jeśli nie podłączono słuchawek ani głośnika zewnętrznego. Gdy włączone, głośnik telefonu służy jako rozwiązanie zapasowe. Włącz to do swobodnego słuchania w domu; zostaw wyłączone w terenie, aby wykluczyć sprzężenie akustyczne do mikrofonu.
- **Wyciszaj mikrofon podczas mówienia** — Zastępuje przychodzący dźwięk ciszą, gdy aplikacja mówi, aby dźwięk z głośnika nie mógł zostać wychwycony przez mikrofon i ponownie wykryty. Zdecydowanie zalecane (i domyślne). Wyłącz tylko wtedy, gdy Twój mikrofon jest akustycznie odseparowany od głośnika telefonu — na przykład mikrofon przypinany na osobnym kablu albo zestaw słuchawkowy Bluetooth.
- **Ścisz inny dźwięk** — Na czas komunikatu chwilowo obniża głośność muzyki lub podcastów z innych aplikacji, a potem ją przywraca. Domyślnie włączone. Wyłączone odtwarza z pełną głośnością.
- **Sygnał przed wypowiedzią** — Odtwarza przed każdą wypowiedzią krótki, cichy sygnał, aby ucho miało chwilę na przejście z biernego słuchania do skupienia się na głosie. Domyślnie włączone. Szczególnie pomocne, gdy komunikaty są rzadkie albo gdy w tle gra muzyka.
- **Co ogłaszać** — Wybiera, które wykrycia w ogóle kwalifikują się do komunikatu. *Każde wykrycie* (domyślnie) pozostawia decyzję ograniczaniu. *Pierwszy raz w Session* ogłasza gatunek tylko przy jego pierwszym wystąpieniu w bieżącej Session. *Tylko lista obserwacyjna* ogranicza komunikaty do gatunków z Twojej listy obserwacyjnej (przydatne przy ukierunkowanych liczeniach, gdy chcesz słyszeć wyłącznie o priorytetowych taksonach).

## Nagrywanie

### Tryb

- **Pełne** — zapisz całe nagranie
- **Tylko wykrycia** — zapisz fragmenty wokół wykryć
- **Wyłączone** — bez nagrywania dźwięku

### Kontekst fragmentu

Gdy aktywne jest **Tylko wykrycia**, aplikacja pokazuje jeden suwak **Kontekst fragmentu** (0–5 s), który ustala, ile dźwięku zostaje zachowane po **obu stronach** każdego wykrycia. Każdy fragment trwa `okno analizy + 2 × kontekst fragmentu`, więc przy oknie analizy 3 s i domyślnym kontekście 1 s zapisany fragment ma 5 s. Ustawienie kontekstu na 2 s daje fragment 7 s (2 s przed + 3 s analizowanego dźwięku + 2 s po). Większe wartości dają więcej miejsca na oględziny wzrokowe lub zewnętrzne narzędzia oceny kosztem miejsca na dysku; wartość 0 zapisuje wyłącznie samo analizowane okno.

### Format

Wybierz **WAV** albo **FLAC**. WAV jest większy, ale powszechnie zgodny i szybki w podglądzie. FLAC zachowuje tę samą bezstratną jakość dźwięku, zajmując mniej miejsca, co zwykle lepiej sprawdza się przy długich Sessions.

To ustawienie dotyczy dźwięku nagrywanego przez BirdNET Live. **Analiza plików** zachowuje zarządzaną przez aplikację kopię zaimportowanego pliku w jego oryginalnym formacie, dzięki czemu pliki MP3, AAC, WAV i FLAC pozostają możliwe do przejrzenia bez dodatkowego kroku konwersji.

### Automatyczne rozpoczynanie nagrywania (tylko tryb Live)

Po włączeniu tryb Live zaczyna nagrywać, gdy tylko ekran się otworzy, a model zakończy wczytywanie — bez dotykania przycisku mikrofonu. Przydatne przy stanowiskach typu kiosk, pracy bez rąk (na przykład urządzenie zamontowane w terenie) albo w każdym sposobie pracy, w którym otwarcie trybu Live i tak oznacza „zaczynamy teraz”. Domyślnie wyłączone, aby przypadkowe dotknięcie kafelka Live na ekranie startowym nie rozpoczęło po cichu Session. Automatyczny start uruchamia się tylko raz na jedno wejście na ekran, więc zatrzymanie Session i ponowne dotknięcie mikrofonu nadal działa jako ręczne wznowienie.

To ustawienie dotyczy otwierania trybu Live wewnątrz aplikacji. [Widżet Quick Listen](live-mode.md) po dotknięciu zaczyna nasłuchiwać niezależnie od tego ustawienia i go nie zmienia. Jeśli trwa lub właśnie się rozpoczyna Session trybu Point Count, Survey, Analizy plików albo ARU, tamta Session zostaje zachowana, a aplikacja poprosi o jej wcześniejsze zatrzymanie.

### Automatyczne zapisywanie Sessions (Live i Point Count)

Po włączeniu (domyślnie) zakończona Session trybu Live lub Point Count jest dodawana do biblioteki automatycznie w chwili jej zakończenia. Po wyłączeniu zakończona Session otwiera się w przeglądzie z oznaczeniem **niezapisana**: ikona zapisu jest podświetlona i musisz jej dotknąć, aby zachować Session. Wyjście z przeglądu bez zapisania odrzuca Session i jej nagrania. Pasuje to do krótkiego nasłuchiwania, gdy chcesz zachować jedynie sporadyczny ciekawy wynik, zamiast gromadzić każde krótkie nagranie. Wdrożenia Survey i ARU zawsze zapisują się automatycznie — długi, bezobsługowy przebieg jest zbyt cenny, aby stracić go przez zapomnienie o zapisie — więc ten przełącznik tam nie obowiązuje.

## Odtwarzanie

### Nakładka odtwarzania w przeglądzie

Po włączeniu (domyślnie) odsłuchanie fragmentu dźwiękowego w Przeglądzie Session złożonej wyłącznie z fragmentów (gdzie nie ma pełnego nagrania ani spektrogramu) otwiera osobną modalną nakładkę odtwarzacza ze sterowaniem odtwarzaniem i podglądem spektrogramu, zamiast odtwarzać fragment w tle. Jeśli Session ma pełny dźwięk, ustawienie to jest pomijane, a nakładka odtwarzania nigdy się nie pojawia.

### Automatyczne odtwarzanie notatek głosowych

Domyślnie wyłączone. Po włączeniu notatka głosowa dołączona do adnotacji ze znacznikiem czasu odtwarza się automatycznie podczas Przeglądu Session, gdy wskaźnik odtwarzania minie zapisaną pozycję. Notatka jest miksowana na nagraniu, zamiast je wstrzymywać, więc słyszysz swoją wypowiedź w kontekście, razem z oryginalnym dźwiękiem. Zostaw wyłączone, jeśli wolisz uruchamiać notatki ręcznie, dotykając ich odznaki adnotacji.

### Ściszanie przy notatkach głosowych

Pokazywane tylko wtedy, gdy włączone jest **Automatyczne odtwarzanie notatek głosowych**. Określa, jak mocno ściszane jest główne nagranie w czasie odtwarzania automatycznej notatki głosowej. Wyższe wartości ułatwiają zrozumienie notatek; niższe pozostawiają więcej słyszalnego nagrania oryginalnego pod notatką.

## Lokalizacja

### Używaj GPS

Używaj GPS urządzenia zamiast współrzędnych wprowadzanych ręcznie. Na Androidzie
pozycje pochodzą z systemowego dostawcy lokalizacji, a nie z Usług Google Play,
więc aplikacja nie wywołuje okna Google dotyczącego dokładności lokalizacji.
Gdy ta opcja jest wyłączona, aplikacja nigdy sama nie odczytuje GPS ani nie
prosi o uprawnienie do lokalizacji: kreatory konfiguracji Survey, Point Count i
ARU otwierają się na ręcznym wprowadzaniu zapisanych współrzędnych, śledzenie
GPS podczas Survey nie działa, a przygotowanie map offline również centruje się
na tych współrzędnych.

### Współrzędne ręczne

Współrzędne używane, gdy **Używaj GPS** jest wyłączone. Zarówno szerokość, jak i długość geograficzna to edytowalne pola tekstowe, więc możesz **wpisać** dokładną wartość albo **wkleić** skopiowaną z innej aplikacji — znacznie precyzyjniej niż przeciąganie suwaka po ekranie dotykowym. Wprowadź stopnie dziesiętne (na przykład `52.5200` i `13.4050`). Możesz też wkleić połączony ciąg `szerokość, długość` (rozdzielony przecinkiem, średnikiem lub spacją) do *dowolnego* z pól, a oba wypełnią się naraz — to odpowiada temu, co większość map i witryn umieszcza w schowku. Wartości spoza zakresu lub nieliczbowe są od razu oznaczane i nie są zapisywane; poprawne wartości utrzymują się w trakcie pisania. Intuicja: najczęstszym powodem ręcznego ustawienia lokalizacji jest oznaczenie dźwięku nagranego gdzie indziej, a ta lokalizacja zwykle przychodzi jako tekst z zewnątrz — pisanie i wklejanie zamieniają to w jeden dokładny krok. Jeśli wolisz wskazać miejsce, niż wpisywać liczby, **Wybierz na mapie** otwiera ten sam pełnoekranowy selektor map co ekrany konfiguracji, z bieżącymi współrzędnymi jako punktem wyjścia, i wypełnia oba pola miejscem, którego dotkniesz.

### Odśwież GPS teraz

Wymusza świeże ustalenie pozycji zamiast ponownego użycia ostatniej zapamiętanej wartości. Intuicja: odczyty GPS są buforowane osobno dla każdego ekranu, aby ekran konfiguracji nie musiał przy każdym otwarciu czekać na sygnał z satelitów, ale ten bufor może być nieaktualny o kilometry, jeśli od poprzedniej Session przejechałeś w nowe miejsce. Dotknij tego, gdy się przemieściłeś i chcesz, aby filtr geograficzny użył pozycji *tutaj*, a nie tej, w której zaczynałeś poranek. Bieżące zapamiętane współrzędne widnieją w podtytule, więc możesz sprawdzić, gdzie aplikacja Cię umieszcza. Jeśli w ciągu około 10 sekund nie uda się ustalić pozycji, aplikacja wróci do ostatniej znanej lokalizacji z systemu i ostrzeże Cię paskiem SnackBar, abyś wiedział, że wartość jest nieaktualna.

### Pobieranie map offline

Pobieranie map offline jest obecnie ukryte, dopóki BirdNET Live korzysta z publicznej usługi kafelków OpenStreetMap. OpenStreetMap dopuszcza zwykłe interaktywne przeglądanie map z podaniem źródła, czytelnym identyfikatorem klienta i lokalnym buforowaniem, ale nie zezwala na masowe pobieranie z wyprzedzeniem ani funkcje pobierania map offline z `tile.openstreetmap.org`. Implementacja modułu pobierania jest zachowana na potrzeby przyszłego źródła kafelków, które wyraźnie dopuszcza pakiety offline.

### Filtr gatunków

- **Wyłączony** — bez filtrowania geograficznego
- **Filtr lokalizacji** — wyklucza gatunki poniżej progu geograficznego
- **Ważenie lokalizacją** — używa geomodelu jako dodatkowego sygnału ważącego

### Próg filtra geograficznego

Pojawia się, gdy aktywny jest tryb filtrowania oparty na lokalizacji.

## Eksport i synchronizacja

### Formaty

Zaznacz dowolną kombinację formatów eksportu — przy każdym zapisie i udostępnieniu wszystkie wybrane formaty trafią razem do jednego pliku ZIP. Wybór jednego formatu bez fragmentów dźwiękowych i bez raportu HTML da Ci, dla zgodności wstecznej, surowy plik (na przykład `session.csv`) zamiast ZIP:

- Raven Selection Table — do użycia w Cornell Raven Pro.
- CSV — otwiera się w każdym arkuszu kalkulacyjnym.
- JSON — najwygodniejszy do przetwarzania programowego; zawiera pełne metadane Session.
- GPX — ślad i punkty do użycia w narzędziach mapowych (ma sens tylko wtedy, gdy GPS był włączony).

Intuicja: wiele sposobów pracy wymaga jednocześnie więcej niż jednego formatu — CSV do arkusza, tabeli Raven dla osoby pracującej na komputerze i JSON dla skryptu analitycznego. Rozplątywanie tego przełącznikiem jednego formatu oznaczało dawniej eksportowanie tej samej Session trzy razy. Teraz zaznaczasz wszystkie trzy raz i jadą razem w pliku ZIP.

### Dołącz pliki dźwiękowe

Dołącz zapisany dźwięk obok eksportowanych tabel lub metadanych, jeśli dany sposób eksportu to obsługuje. Udostępnianie pojedynczego wykrycia także korzysta z tego ustawienia: pełne nagranie Session jest przycinane do dokładnych znaczników początku i końca tego wykrycia, a Session zawierająca tylko wykrycia używa zachowanego fragmentu.

### Zawsze udostępniaj dźwięk jako WAV

Pokazywane tylko wtedy, gdy włączone jest **Dołącz pliki dźwiękowe**. Po włączeniu nagrania FLAC są konwertowane do WAV przed udostępnieniem lub eksportem. WAV jest zgodny ze wszystkim, ale znacznie większy niż FLAC, więc zostaw tę opcję wyłączoną, chyba że narzędzie po drugiej stronie nie potrafi odczytać FLAC — część starszego oprogramowania analitycznego na komputery i nieliczne formularze przesyłania wciąż tego nie potrafią.

### Dołącz metadane aplikacji

Po włączeniu plik ZIP eksportu zawiera plik towarzyszący `*.metadata.json` opisujący, jak powstała Session: wersję BirdNET Live, tożsamość modelu, zapis pogody wykonany na początku Session oraz wszelkie ostrzeżenia o spójności dźwięku wykryte w trakcie nagrywania. Intuicja: właśnie te informacje o pochodzeniu pozwalają Tobie (albo osobie sprawdzającej) odtworzyć lub zweryfikować Session po miesiącach. Wyłącz je, gdy chcesz czysto udostępnić sam dźwięk i wybrane formaty — na przykład wrzucić pojedynczy plik WAV do iNaturalist lub eBird bez plików charakterystycznych dla aplikacji.

### Dołącz raport HTML

Po włączeniu każdy plik ZIP eksportu zawiera dodatkowo plik `<session>_report.html` obok tabeli, fragmentów dźwiękowych i pliku GPX. Otwórz go w dowolnej przeglądarce, a otrzymasz gotowe do druku podsumowanie Session: kartę nagłówkową z datą, lokalizacją, obserwatorem i sumami; interaktywną mapę śladu GPS i znaczników wykryć; kartę dla każdego wykrycia z miniaturą z taksonomii Cornell, nazwami, odznaką oceny, Twoim potwierdzeniem, ewentualną wpisaną notatką i oryginalnym fragmentem dźwiękowym jako wbudowanym odtwarzaczem; a także użyte ustawienia analizy. Intuicja: CSV świetnie nadaje się do potoków analitycznych, ale nie do udostępnienia osobie nietechnicznej ani do wydrukowania krótkiego podsumowania terenowego — raport HTML wypełnia tę lukę jednym dotknięciem. Miniatury gatunków i kafelki map wymagają połączenia przy pierwszym otwarciu pliku (są pobierane na żywo z API taksonomii BirdNET i z OpenStreetMap), ale cała reszta — tekst, układ, odtwarzanie dźwięku, odnośniki — działa całkowicie offline. Wyłącz to, jeśli potrzebujesz tylko surowych danych i chcesz, aby plik ZIP był o kilka KB mniejszy.

### Udostępnianie samego dźwięku

Odznacz każdy format **oraz** raport HTML **oraz** pole metadanych aplikacji, zostawiając tylko **Dołącz pliki dźwiękowe**, a Udostępnij przekaże systemowemu panelowi surowe nagranie (na przykład `BirdNET_Live_…flac`) zamiast pliku ZIP. To najprostsza droga, aby wysłać Session prosto do iNaturalist, eBird albo dowolnej innej aplikacji oczekującej nieopakowanego pliku dźwiękowego. Sessions z wieloma fragmentami wykryć nadal dają ZIP; przy udostępnianiu pojedynczego wykrycia przekazywany jest ten jeden surowy fragment.

## Prywatność

Ta sekcja decyduje, **z jakimi usługami zewnętrznymi BirdNET Live może kontaktować się w Twoim imieniu**. Samo wnioskowanie działa w całości na Twoim urządzeniu — te przełączniki dotyczą wyłącznie opcjonalnych funkcji sieciowych, które wzbogacają korzystanie z aplikacji. Wszystkie trzy przełączniki są przy nowej instalacji **domyślnie wyłączone**; nic nie wychodzi na zewnątrz, dopóki na to nie pozwolisz. Intuicja: każdy przełącznik obejmuje jedną konkretną usługę i jedną konkretną korzyść, więc możesz włączyć dokładnie to, co przydaje się w Twojej pracy, i nic ponadto.

### Zezwalaj na kafelki map

Wymagane dla każdej interaktywnej mapy w aplikacji (selektora lokalizacji, mapy Survey na żywo i mapy Session). Po włączeniu widżety map pobierają kafelki rastrowe z publicznych serwerów **OpenStreetMap**; zapytania o współrzędne kafelków ujawniają, jaki obszar świata oglądasz. Kafelki są buforowane lokalnie do sześciu miesięcy, z limitem 6000 kafelków, aby powtarzane podglądy map pozostały wydajne i nie rosły w nieskończoność. Włączenie tej opcji włącza także **Zezwalaj na wyszukiwanie nazw miejsc**, ponieważ większość osób wczytujących mapy oczekuje, że Sessions pokażą również czytelne nazwy miejsc. Wyszukiwanie nazw miejsc możesz potem wyłączyć osobno. Gdy kafelki map są wyłączone, każdy ekran z mapą pokazuje kartę zastępczą, więc reszta aplikacji działa bez wycieku do sieci.

### Zezwalaj na wyszukiwanie nazw miejsc

Po włączeniu aplikacja wysyła zarejestrowane współrzędne do usługi **Nominatim od OpenStreetMap**, aby ustalić krótką nazwę miejsca (na przykład *„Berlin, Niemcy”*), pokazywaną obok Session w Bibliotece Sessions i w Przeglądzie Session. Intuicja: współrzędne liczbowe są dokładne, ale trudno je ogarnąć wzrokiem przy przewijaniu długiej listy Sessions — nazwa miejsca sprawia, że listę da się czytać od razu. Po wyłączeniu Sessions pokazują tylko surową szerokość i długość geograficzną, a Nominatim nie jest w ogóle odpytywany.

### Zezwalaj na sprawdzanie pogody

Po włączeniu każda zapisana Session rejestruje przez **Open-Meteo** jednorazowy zapis lokalnych warunków (temperatura, opady, wiatr, zachmurzenie) dla współrzędnych nagrania i czasu zakończenia. Zapis trafia do Przeglądu Session pod wierszem lokalizacji i jest powielany w eksporcie JSON, bloku metadanych Session i raporcie HTML. Intuicja: pogoda to jeden z najsilniejszych czynników wpływających na aktywność ptaków, a jej automatyczne rejestrowanie — bez konieczności pamiętania o sprawdzeniu osobnej aplikacji — czyni każdą Session pełniejszym zapisem. Open-Meteo jest usługą bezpłatną i nie wymaga ani konta, ani klucza API. Po wyłączeniu żadne dane pogodowe nie są pobierane ani zapisywane. Konfiguracja Point Count i Survey pokazuje też zwartą kartę pogody przy elementach lokalizacji: prosi o tę zgodę tylko wtedy, gdy jest potrzebna, po włączeniu pokazuje podgląd w postaci ikony + temperatury + wiatru i przy zapisie Session ponownie używa tego samego zapisu z pamięci podręcznej.

## O aplikacji

Wiersz **O aplikacji** otwiera ekran informacyjny w aplikacji.

## Strefa zagrożenia

### Resetuj wprowadzenie

Pokazuje sekwencję wprowadzenia ponownie przy następnym uruchomieniu aplikacji.

### Resetuj wszystkie ustawienia

Przywraca każdą preferencję na tym ekranie do wartości domyślnej. Sessions, nagrania, notatki głosowe, eksporty i kafelki map w pamięci podręcznej pozostają nietknięte — kasowane są wyłącznie zapisane preferencje (suwaki, przełączniki, wybory w selektorach). Po potwierdzeniu aplikacja się zamyka, aby nowe wartości domyślne zadziałały przy kolejnym uruchomieniu.

Przydatne, gdy nie masz pewności, który suwak poruszyłeś i coś przez to przestało działać, albo gdy przekazujesz urządzenie komuś innemu i chcesz czystej konfiguracji bez utraty zebranych danych.

### Wyczyść wszystkie dane

Trwale usuwa Sessions, wykrycia, nagrania, notatki głosowe, własne listy gatunków, zapisane preferencje oraz dane w pamięci podręcznej dotyczące map, nazw miejsc, pogody, odtwarzania, przeglądu i udostępniania. Okno potwierdzenia wymaga wpisania `DELETE`, a następnie zamyka aplikację, aby kolejne uruchomienie zaczęło się od czystego stanu lokalnego.

Użyj tego, zanim przekażesz urządzenie innemu obserwatorowi, wycofasz telefon terenowy z użycia albo usuniesz z aplikacji historię powiązaną z lokalizacją. Najpierw wyeksportuj wszystko, czego potrzebujesz; tej operacji nie da się cofnąć.

## Parametry poszczególnych trybów poza ustawieniami

Niektóre parametry konfiguruje się na własnych ekranach konfiguracji, a nie na wspólnym ekranie ustawień.

- [Tryb Point Count](point-count-mode.md) ma własną konfigurację czasu trwania i lokalizacji.
- [Tryb Survey](survey-mode.md) ma własny ekran parametrów Survey.
- [Analiza plików](file-analysis.md) ma własny krok z parametrami analizy.
