# Tryb ARU

!!! note "Wczesna implementacja"
    Tryb ARU zapisuje obecnie punkty kontrolne zaplanowanego wdrożenia, nagrywa zaplanowane cykle, prowadzi wnioskowanie na żywo w trakcie aktywnych cykli, zapisuje zachowane fragmenty wykryć, gdy wybrano ten tryb nagrywania, i pokazuje sterowanie w powiadomieniu pierwszoplanowym na Androidzie. Zachowanie w tle na iOS wymaga jeszcze weryfikacji w terenie.

Tryb ARU (Autonomous Recording Unit) to sposób pracy w stałej lokalizacji, przeznaczony do zaplanowanych wdrożeń akustycznych.

## Obecny przebieg konfiguracji

- **Szczegóły i ustawienia analizy**:
    - **Metadane**: wprowadź nazwę wdrożenia, identyfikator ARU/stanowiska i nazwę obserwatora.
    - **Lokalizacja**: podaj współrzędne miejsca przez automatyczne ustalenie pozycji GPS, ręczne wpisanie szerokości i długości geograficznej albo pomiń ustawianie lokalizacji. Szerokość i długość geograficzna są wymagane, jeśli korzystasz z harmonogramu powiązanego z pozycją słońca. Ikony: GPS :app-myLocation:, współrzędne ręczne :app-editLocationAlt:, pominięcie lokalizacji :app-locationOff: i wybór na mapie :app-mapSheet:.
    - **Analiza**: Wybierz mikrofon, częstość wnioskowania, próg pewności i czułość.
    - **Format nagrania**: wybierz FLAC (skompresowany bezstratnie) albo WAV (nieskompresowany).
    - **Tryb nagrywania**:
        - *Pełny*: nagrywa cały czas trwania każdego aktywnego cyklu.
        - *Tylko wykrycia*: zapisuje krótkie fragmenty dźwięku wokół wykrytych odgłosów ptaków. Możesz dostosować kontekst fragmentu (od 0 do 5 sekund bufora przed wykryciem i po nim) oraz wybrać metodę próbkowania (*Wszystko*, *Top N* lub *Smart*, aby ograniczyć zużycie pamięci).
        - *Wyłączony*: prowadzi wnioskowanie w czasie rzeczywistym w trakcie cykli i zapisuje wykrycia, ale nie zapisuje plików dźwiękowych.
- **Harmonogram**:
    - **Czas trwania i powtarzanie**: wybierz, jak długo trwa każdy aktywny cykl nagrywania i jak często się powtarza.
    - **Okno nagrywania (rytm dobowy)**: wybierz nagrywanie przez całą dobę (*Dowolna pora*) albo ogranicz cykle do *Tylko w dzień*, *Tylko w nocy* lub do okien *Wokół wschodu słońca*, *Wokół zachodu słońca* czy *Wokół wschodu i zachodu słońca*. Okna wschodu i zachodu obliczane są dynamicznie na podstawie współrzędnych wdrożenia.
    - **Koniec harmonogramu**: wybierz, czy zatrzymać wdrożenie ręcznie, po ustalonej liczbie ukończonych cykli, czy automatycznie o określonej dacie i godzinie.
    - **Zarządzanie baterią**: ustaw próg zatrzymania przy niskim poziomie baterii (0-50%), aby wstrzymać wdrożenie i nie dopuścić do całkowitego rozładowania. Jeśli go ustawisz, możesz też podać próg wznowienia, aby cykle nagrywania ruszyły automatycznie, gdy poziom baterii wzrośnie (na przykład dzięki ładowaniu słonecznemu).
    - **Przebieg testowy**: opcjonalny jednominutowy cykl testowy jest domyślnie włączony, aby zaraz po starcie sprawdzić wejście mikrofonowe i wnioskowanie, bez wliczania do zaplanowanej liczby cykli.
    - **Grupowanie Sessions**: ustal, czy każdy cykl ma być zapisywany jako osobna Session (zalecane ze względu na szybsze wczytywanie i modułowy podgląd), czy wszystkie cykle mają trafić do jednej Session z wieloma segmentami.
- **Gotowe**: sprawdź harmonogram, szacowane zużycie pamięci na dźwięk i ograniczenia dobowe, a następnie rozpocznij wdrożenie.

Elementy konfiguracji używają tych samych ikon co pozostałe kreatory: :app-micRounded: mikrofon, :app-speedRounded: częstość wnioskowania, :app-verifiedRounded: pewność, :app-hearing: czułość, :app-fiberManualRecordRounded: tryb nagrywania, :app-timerOutlined: kontekst fragmentu i czas trwania cyklu, :app-filterAltRounded: próbkowanie wykryć oraz :app-formatListNumberedRounded: limit fragmentów na gatunek. Interwał powtarzania używa :app-repeatRounded:, ustawienia niskiego poziomu baterii :app-batteryAlert: i :app-batteryChargingFull:, a przebieg testowy i grupowanie Session :app-scienceRounded: i :app-libraryBooks:. Stuknij przycisk :app-helpOutline: obok elementu, aby zobaczyć wyjaśnienie.

Rozpoczęcie wdrożenia od razu zapisuje Session typu `SessionType.aru` z metadanymi harmonogramu ARU. Cykle nagrywania są też zapisywane co 30 sekund, również te bez wykryć. Po awarii lub utracie zasilania ostatnio zapisane wdrożenie pojawia się w Bibliotece Sessions jako zakończona Session; nagrywanie nie wznawia się samo. Dane od ostatniego zapisu mogą zostać utracone.

Eksporty JSON i ZIP zawierają metadane wdrożenia ARU. Eksporty ZIP grupują zapisane pliki nagrań poszczególnych cykli w katalogu `aru_cycles/`.

## Ekran aktywnego wdrożenia

Ekran aktywnego wdrożenia ARU pokazuje, czy wdrożenie czeka, nagrywa czy zostało ukończone. Układ opiera się na czterech zakładkach:
- **Stan**: pokazuje bieżący stan wdrożenia, licznik aktywnego harmonogramu i listę wykryć w czasie rzeczywistym.
- **Dźwięk**: pokazuje przewijany spektrogram na żywo, aby sprawdzić sygnał wejściowy, z wykryciami widocznymi poniżej.
- **Harmonogram**: wypisuje 10 najbliższych zaplanowanych godzin cykli i zaznacza powiązanie ze wschodem lub zachodem słońca, jeśli obowiązują ograniczenia dobowe.
- **Podsumowanie**: podsumowuje czas, który upłynął, łączny czas nagranego dźwięku i statystyki wykryć.

Na Androidzie aktywne wdrożenia wyświetlają powiadomienie pierwszoplanowe z działaniami Zatrzymaj i Otwórz.

Zatrzymanie wdrożenia otwiera Przegląd Session. Jeśli cykle zostały zgrupowane w jednej Session, otwiera się ta połączona Session; jeśli zapisano je jako osobne Sessions, otwiera się Session ostatniego ukończonego cyklu.

Na iOS traktuj tę wczesną implementację jako pracę na pierwszym planie, dopóki zaplanowane nagrywanie i zachowanie w tle nie zostaną zweryfikowane na tej platformie.

## Wciąż planowane

- Weryfikacja zachowania w tle na iOS.
- Pełna obsługa odtwarzania i spektrogramu w Przeglądzie Session dla nagrań ARU podzielonych na wiele plików.
