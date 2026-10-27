# 시작하기

## 설치

BirdNET Live는 Android, iOS, Windows에서 사용할 수 있습니다.

### 요구 사항

- **Android**: 8.0(API 26) 이상
- **iOS**: 15.0 이상
- **Windows**: 10 이상(실험적)
- 앱과 모델에 약 300MB의 저장 공간

### 다운로드

- **Android** — [Google Play 스토어](https://play.google.com/store/apps/details?id=de.tu_chemnitz.mi.kahst.birdnet_live)에서 설치하거나, [GitHub 릴리스 페이지](https://github.com/birdnet-team/birdnet-live-app/releases/latest)에서 서명된 APK를 받아 직접 설치합니다.
- **iOS** — [App Store](https://apps.apple.com/us/app/birdnet-live/id6776168518).
- **Windows** — 소스에서 직접 빌드합니다. [Developer Guide](../developer/building.md)를 참고하세요.

## 첫 사용 흐름

BirdNET Live를 처음 열면 앱이 짧은 온보딩 과정과 권한 설정을 안내합니다.

1. 온보딩 화면을 읽습니다.
2. 허용 사용 정책과 개인정보 처리방침을 확인합니다.
3. BirdNET Live가 오디오를 처리할 수 있도록 마이크 권한을 허용합니다.
4. 선택 사항: 위치 태그, 탐색, Point Count, Survey에 사용할 위치 권한을 허용합니다.
5. 선택 사항: 장시간 Survey를 위한 알림을 허용합니다.

## 첫 실행

1. **온보딩** — 기능과 권한에 대한 간단한 소개
2. **허용 사용 및 개인정보** — 허용 사용 정책과 개인정보 처리방침 확인
3. **권한** — 마이크 접근 허용(모든 모드에 필요)
4. **준비 완료** — 새 동정을 시작하세요!

## 홈 화면 개요

홈 화면은 앱의 중심입니다.

### 주요 모드 카드

- :app-micRounded: **Live Mode**
- :app-locationOnRounded: **Point Count 모드**
- :app-routeRounded: **Survey 모드**
- :app-audioFileRounded: **파일 분석**
- :app-timerRounded: **ARU 모드**
- :app-sdStorage: **일괄 분석** (준비 중)

### 하단 버튼

- :app-tuneRounded: **설정**
- :app-searchRounded: **탐색**
- :app-libraryMusic: **Session 목록**
- :app-helpOutlineRounded: **도움말**
- :app-infoOutline: **정보**

## 저장되는 내용

BirdNET Live는 완료된 Session을 자동으로 저장하고, 처리가 끝나면 Session 검토에서 엽니다.

- Live Mode Session은 감지 결과를 저장하며, 설정에 따라 녹음 전체 또는 클립도 함께 저장합니다.
- Point Count Session은 시간이 정해진 Point Count Session으로 저장됩니다.
- Survey Session은 경로, 감지 결과, 관련 메타데이터를 저장합니다.
- 파일 분석 결과는 검토할 수 있는 Session으로 변환됩니다.

## 다음에 읽을 페이지

- 반복해서 등장하는 UI 기호를 빠르게 알아보려면 [아이콘과 컨트롤](icons-and-controls.md)을 읽어 보세요.
- 임계값, 필터, 녹음 동작, 스펙트로그램 표시를 바꾸기 전에 [설정](settings.md)을 읽어 보세요.
- 가장 자주 사용하는 작업 방식의 가이드를 여세요: [Live Mode](live-mode.md), [Point Count 모드](point-count-mode.md), [Survey 모드](survey-mode.md) 또는 [파일 분석](file-analysis.md).

## 권한

| 권한 | 용도 | 선택 여부 |
|------------|-------------|-----------|
| 마이크 | 모든 녹음 모드 | 필수 |
| 위치 | GPS 태그, Survey/Point Count | Live Mode에서는 선택 |
| 저장공간 | 녹음 및 내보내기 파일 저장 | 녹음 시 필수 |
| 알림 | 백그라운드 Survey 알림 | 선택 |
