# Pierwsze kroki

## Instalacja

BirdNET Live jest dostępny na Androida, iOS i Windows.

### Wymagania

- **Android**: 8.0 (API 26) lub nowszy
- **iOS**: 15.0 lub nowszy
- **Windows**: 10 lub nowszy (eksperymentalnie)
- ~300 MB miejsca na aplikację i modele

### Pobieranie

- **Android** — [Google Play](https://play.google.com/store/apps/details?id=de.tu_chemnitz.mi.kahst.birdnet_live) lub zainstaluj ręcznie podpisany plik APK ze [strony wydań na GitHubie](https://github.com/birdnet-team/birdnet-live-app/releases/latest).
- **iOS** — [App Store](https://apps.apple.com/us/app/birdnet-live/id6776168518).
- **Windows** — zbuduj ze źródeł; zobacz [Developer Guide](../developer/building.md).

## Przebieg pierwszego uruchomienia

Gdy otworzysz BirdNET Live po raz pierwszy, aplikacja przeprowadzi Cię przez krótkie wprowadzenie i konfigurację uprawnień.

1. Przeczytaj ekrany wprowadzenia.
2. Zapoznaj się z Polityką dopuszczalnego użycia i Polityką prywatności.
3. Przyznaj uprawnienie do mikrofonu, aby BirdNET Live mógł przetwarzać dźwięk.
4. Opcjonalnie zezwól na dostęp do lokalizacji na potrzeby geotagowania, trybu Przeglądaj, Point Count i Survey.
5. Opcjonalnie zezwól na powiadomienia przy długich liczeniach.

## Pierwsze uruchomienie

1. **Wprowadzenie** — krótkie przedstawienie funkcji i uprawnień
2. **Dopuszczalne użycie i prywatność** — zapoznaj się z Polityką dopuszczalnego użycia i Polityką prywatności
3. **Uprawnienia** — przyznaj dostęp do mikrofonu (wymagany we wszystkich trybach)
4. **Gotowe** — zacznij rozpoznawać ptaki!

## Przegląd ekranu startowego

Ekran startowy to główny punkt wyjścia.

### Karty głównych trybów

- :material-microphone: **Tryb Live**
- :material-map-marker: **Tryb Point Count**
- :material-routes: **Tryb Survey**
- :material-file-music: **Analiza plików**

### Przyciski na dole

- :material-tune: **Ustawienia**
- :material-magnify: **Przeglądaj**
- :material-music-box-multiple-outline: **Biblioteka Sessions**
- :material-help-circle-outline: **Pomoc**
- :material-information-outline: **O aplikacji**

## Co jest zapisywane

BirdNET Live automatycznie zapisuje każdą zakończoną Session i otwiera ją w Przeglądzie Session, gdy przetwarzanie się zakończy.

- Sessions trybu Live zapisują wykrycia oraz — zależnie od ustawień — nagrania lub fragmenty.
- Sessions trybu Point Count zapisywane są jako liczenia punktowe na czas.
- Sessions trybu Survey zapisują trasę, wykrycia i powiązane metadane.
- Wyniki analizy plików są zamieniane w Session gotową do przeglądu.

## Polecane kolejne strony

- Przeczytaj [Ikony i elementy sterujące](icons-and-controls.md), jeśli chcesz szybko poznać powtarzające się symbole interfejsu.
- Przeczytaj [Ustawienia](settings.md), zanim zmienisz progi, filtry, sposób nagrywania lub wygląd spektrogramu.
- Otwórz przewodnik po sposobie pracy, którego używasz najczęściej: [Tryb Live](live-mode.md), [Tryb Point Count](point-count-mode.md), [Tryb Survey](survey-mode.md) lub [Analiza plików](file-analysis.md).

## Uprawnienia

| Uprawnienie | Potrzebne do | Opcjonalne? |
|------------|-------------|-----------|
| Mikrofon | Wszystkie tryby nagrywania | Wymagane |
| Lokalizacja | Znaczniki GPS, Survey/Point Count | Opcjonalne w trybie Live |
| Pamięć | Zapisywanie nagrań i eksportów | Wymagane do nagrywania |
| Powiadomienia | Alerty przy Survey w tle | Opcjonalne |
