# Najczęstsze pytania

Najczęściej zadawane pytania.

## Ogólne

**P: Czy BirdNET Live wymaga połączenia z internetem?**
O: Nie. Całe wnioskowanie działa na urządzeniu z użyciem modelu ONNX. Jedyne funkcje sieciowe są opcjonalne i domyślnie wyłączone: kafelki map i wyszukiwanie nazw miejsc z OpenStreetMap, dane pogodowe z Open-Meteo oraz pobieranie zdjęć i opisów gatunków z API taksonomii. Zobacz [Ustawienia → Prywatność](settings.md#prywatność).

**P: Ile gatunków potrafi rozpoznać?**
O: Model BirdNET+ V3.0 rozpoznaje 9789 gatunków na świecie — ptaki, płazy, ssaki i owady (dopasowany taksonomicznie, ograniczony przekrój klasyfikatora dźwięku i geomodelu).

**P: Jakie platformy są obsługiwane?**
O: Android (8.0+), iOS (15.0+) i Windows (eksperymentalnie).

## Dokładność

**P: Dlaczego przy moim progu pewności widzę niskie wyniki?**
O: Obniż próg pewności w ustawieniach, aby zobaczyć więcej wykryć. Na dokładność wpływają hałas otoczenia, wiatr i odległość.

**P: Co robi filtr gatunków?**
O: Geomodel przewiduje, które gatunki są prawdopodobne w Twojej lokalizacji GPS i o danej porze roku. Włącz **Filtr lokalizacji**, aby ukryć mało prawdopodobne gatunki, albo **Ważenie lokalizacją**, aby ważyć wyniki prawdopodobieństwem geograficznym.

**P: Jak dokładne jest rozpoznawanie?**
O: Dokładność zależy od jakości nagrania, odległości, hałasu otoczenia i samego gatunku. Wykrycia o wysokiej pewności (>70%) są zwykle wiarygodne. Rzadkie gatunki zawsze potwierdzaj wzrokowo.

## Nagrywanie

**P: Gdzie zapisywane są nagrania?**
O: W katalogu dokumentów aplikacji, w `recordings/<session-id>/`, jako WAV lub FLAC, zależnie od **Ustawienia → Nagrywanie → Format**.

**P: Czy mogę analizować istniejące nagrania?**
O: Tak. Otwórz Analizę plików z ekranu startowego, wybierz plik dźwiękowy, ustaw lokalizację i parametry, a następnie dotknij Analizuj. Obsługiwane formaty to między innymi WAV, FLAC, MP3, OGG, Opus, M4A, AAC, WMA i AMR.

## Point Count

**P: Czym jest tryb Point Count?**
O: To tryb liczenia na czas, przeznaczony do formalnych liczeń punktowych ptaków. Ustawiasz stały czas trwania (3–20 minut) i lokalizację, a aplikacja pracuje nieprzerwanie i zatrzymuje się automatycznie, gdy licznik dojdzie do zera.

**P: Czy mogę wstrzymać liczenie punktowe?**
O: Nie. Zgodność z protokołem wymaga nieprzerwanego nagrywania. Możesz natomiast zakończyć liczenie wcześniej przyciskiem stop.

**P: Gdzie trafiają wyniki liczenia punktowego?**
O: Pojawiają się w Bibliotece Sessions jako „Point Count #1”, „#2” i tak dalej. Możesz je przeglądać, edytować i eksportować jak każdą inną Session.

## Wydajność

**P: Dlaczego aplikacja się nagrzewa i zużywa baterię?**
O: Wnioskowanie modelu ONNX jest wymagające obliczeniowo, a ekran pozostaje włączony podczas Sessions na żywo. To normalne przy przetwarzaniu sieci neuronowej w czasie rzeczywistym.

**P: Spektrogram wygląda na zamrożony.**
O: Sprawdź, czy przyznano uprawnienie do mikrofonu i czy rejestracja dźwięku jest aktywna. Upewnij się, że żadna inna aplikacja nie korzysta z mikrofonu.
