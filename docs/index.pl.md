# BirdNET Live

**Profesjonalna bioakustyka w Twojej kieszeni.**

BirdNET Live to aplikacja napisana we Flutterze, przeznaczona dla badaczy terenowych, osób zajmujących się ochroną przyrody i ornitologów, którzy potrzebują wiarygodnych dowodów akustycznych w terenie. Klasyfikator dźwięku BirdNET+ i geomodel działają bezpośrednio na Twoim urządzeniu, więc po instalacji rozpoznawanie gatunków działa całkowicie bez internetu.

<p align="center">
  <img src="https://img.shields.io/badge/latest-v1.1.2-orange.svg" alt="Latest release: v1.1.2">
  <img src="https://img.shields.io/badge/species-9%2C789-brightgreen.svg" alt="Species: 9,789">
  <img src="https://img.shields.io/badge/platforms-Android%20%7C%20iOS%20%7C%20Windows-green.svg" alt="Platforms">
</p>

## Funkcje

- **Tryb Live** - przewijany spektrogram w czasie rzeczywistym z rozpoznawaniem gatunków
- **Tryb Point Count** - Sessions na czas z odliczaniem i metadanymi punktu
- **Tryb Survey** - długie liczenia transektowe ze śledzeniem GPS, monitorowaniem w tle i próbkowaniem wykryć
- **Analiza plików** - analiza istniejących nagrań offline (WAV, FLAC, MP3, OGG i inne)
- **Tryb ARU** - zamień urządzenie w autonomiczną jednostkę nagrywającą do wielodniowych wdrożeń
- **Przeglądaj** - przeglądaj gatunki spodziewane w Twojej lokalizacji według geomodelu BirdNET
- **Biblioteka Sessions** - przeglądaj, edytuj i eksportuj wcześniejsze Sessions wraz z odtwarzaniem dźwięku
- **Eksport** - formaty Raven Pro, CSV, JSON, GPX i paczki ZIP z metadanymi pochodzenia
- **Wnioskowanie na urządzeniu** - model BirdNET+ obejmuje 9789 gatunków, bez internetu
- **Nagrywanie FLAC** - skompresowany dźwięk i mniejsze pliki przy długich liczeniach
- **Dostępność** - etykiety dla czytników ekranu, podpowiedzi i opcjonalne komunikaty głosowe o wykryciach
- **Układy responsywne** - interfejs dopasowany do telefonu, tabletu, orientacji pionowej i poziomej
- **Lokalizacja** - interfejs i komunikaty głosowe w 11 językach

<p align="center">
  <img src="../assets/screenshots/live-mode.png" alt="Live Mode" width="150">
  <img src="../assets/screenshots/session-review.png" alt="Session Review" width="150">
  <img src="../assets/screenshots/explore.png" alt="Explore" width="150">
  <img src="../assets/screenshots/species.png" alt="Species Overlay" width="150">
  <img src="../assets/screenshots/file-analysis.png" alt="File Analysis" width="150">
</p>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=de.tu_chemnitz.mi.kahst.birdnet_live"><b>Google Play</b></a>
  &nbsp;·&nbsp;
  <a href="https://apps.apple.com/us/app/birdnet-live/id6776168518"><b>App Store</b></a>
  &nbsp;·&nbsp;
  <a href="https://github.com/birdnet-team/birdnet-live-app/releases/latest"><b>Download APK</b></a>
  &nbsp;·&nbsp;
  <a href="https://github.com/birdnet-team/birdnet-live-app"><b>GitHub</b></a>
  &nbsp;·&nbsp;
  <a href="https://github.com/birdnet-team/birdnet-live-app/releases"><b>All Releases</b></a>
</p>

## Szybki start

Zajrzyj do [Podręcznika użytkownika](user/index.md), aby zobaczyć przegląd, a następnie otwórz [Pierwsze kroki](user/getting-started.md), aby zainstalować i uruchomić BirdNET Live.

## Instalacja

BirdNET Live jest dostępny w [Google Play](https://play.google.com/store/apps/details?id=de.tu_chemnitz.mi.kahst.birdnet_live) oraz w [App Store](https://apps.apple.com/us/app/birdnet-live/id6776168518).

Na Androidzie możesz też zainstalować aplikację ręcznie jako podpisany plik APK: pobierz najnowsze wydanie ze [strony wydań na GitHubie](https://github.com/birdnet-team/birdnet-live-app/releases/latest), przenieś plik `.apk` na telefon i otwórz go, aby zainstalować. Być może trzeba będzie najpierw zezwolić w ustawieniach urządzenia na instalację z nieznanych źródeł.

> **Uwaga:** plik APK zajmuje około 260 MB, ponieważ zawiera zasoby modelu BirdNET+ oraz wszystkie zdjęcia gatunków do użytku offline.

## Dla programistów

Zajrzyj do [Developer Guide](developer/index.md) po informacje o architekturze, budowaniu i współtworzeniu. Dokumentacja dla programistów jest dostępna wyłącznie po angielsku.

## Licencja

Kod źródłowy BirdNET Live jest udostępniany na [licencji MIT](https://github.com/birdnet-team/birdnet-live-app/blob/main/LICENSE). Dołączone wagi modelu BirdNET są objęte [licencją Apache 2.0](https://github.com/birdnet-team/birdnet-live-app/blob/main/MODEL_LICENSE).
