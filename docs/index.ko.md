# BirdNET Live

**주머니 속의 전문 생물음향학.**

BirdNET Live는 현장에서 신뢰할 수 있는 음향 증거가 필요한 현장 연구자, 보전 활동가, 탐조인을 위해 만들어진 Flutter 앱입니다. BirdNET+ 오디오 분류기와 지리 모델을 기기에서 직접 실행하므로, 설치 후에는 종 동정이 완전히 오프라인으로 작동합니다.

<p align="center">
  <img src="https://img.shields.io/badge/latest-v1.2.1-orange.svg" alt="Latest release: v1.2.1">
  <img src="https://img.shields.io/badge/species-9%2C789-brightgreen.svg" alt="Species: 9,789">
  <img src="https://img.shields.io/badge/platforms-Android%20%7C%20iOS%20%7C%20Windows-green.svg" alt="Platforms">
</p>

## 기능

- **Live Mode** - 실시간 스크롤 스펙트로그램과 종 동정
- **Point Count 모드** - 카운트다운 타이머와 조사 지점 메타데이터를 갖춘 시간 제한 조사 Session
- **Survey 모드** - GPS 추적, 백그라운드 모니터링, 감지 샘플링을 지원하는 장시간 조사 경로(transect) 조사
- **파일 분석** - 기존 녹음(WAV, FLAC, MP3, OGG 등)의 오프라인 분석
- **ARU 모드** - 기기를 여러 날에 걸친 운용을 위한 자동 녹음 장치로 전환
- **탐색** - BirdNET 지리 모델을 사용하여 사용자의 위치에서 예상되는 종 둘러보기
- **Session 목록** - 지난 Session 검토, 편집, 내보내기 및 오디오 재생
- **내보내기** - Raven Pro, CSV, JSON, GPX 및 출처 메타데이터가 포함된 ZIP 번들 형식
- **기기 내 추론** - 9,789종을 지원하는 BirdNET+ 모델, 인터넷 연결 불필요
- **FLAC 녹음** - 장시간 조사를 위해 더 작은 파일로 저장되는 압축 오디오 캡처
- **접근성** - 스크린 리더 레이블, 툴팁, 선택 가능한 감지 음성 안내
- **반응형 레이아웃** - 휴대폰, 태블릿, 세로 및 가로 방향에 맞춰 조정되는 인터페이스
- **현지화** - 11개 언어로 제공되는 인터페이스와 음성 안내

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

## 빠른 시작

먼저 [사용자 가이드](user/index.md)에서 전체 개요를 확인한 다음, [시작하기](user/getting-started.md)를 열어 BirdNET Live를 설치하고 실행하세요.

## 설치

BirdNET Live는 [Google Play 스토어](https://play.google.com/store/apps/details?id=de.tu_chemnitz.mi.kahst.birdnet_live)와 [App Store](https://apps.apple.com/us/app/birdnet-live/id6776168518)에서 받을 수 있습니다.

Android에서는 서명된 APK를 직접 설치(사이드로드)할 수도 있습니다: [GitHub 릴리스 페이지](https://github.com/birdnet-team/birdnet-live-app/releases/latest)에서 최신 릴리스를 다운로드하고 `.apk` 파일을 휴대폰으로 옮긴 뒤 열어서 설치하세요. 먼저 기기 설정에서 출처를 알 수 없는 앱 설치를 허용해야 할 수도 있습니다.

> **참고:** APK는 오프라인 사용을 위한 BirdNET+ 모델 에셋과 모든 종 이미지를 포함하므로 약 260 MB입니다.

## 개발자를 위한 안내

아키텍처, 빌드, 기여 방법은 [Developer Guide](developer/index.md)를 참조하세요. 개발자 문서는 영어로만 제공됩니다.

## 라이선스

BirdNET Live 소스 코드는 [MIT 라이선스](https://github.com/birdnet-team/birdnet-live-app/blob/main/LICENSE)에 따라 오픈 소스로 공개됩니다. 번들로 포함된 BirdNET 모델 가중치는 [Apache License 2.0](https://github.com/birdnet-team/birdnet-live-app/blob/main/MODEL_LICENSE)에 따라 라이선스됩니다.
