# 🪥 **ChicaChew** — AI 기반 어린이 양치 코치 앱 (Flutter)

<p align="center">
  <img src="docs/cover.png" alt="ChicaChew Cover" width="820">
</p>

<p align="center">
  <a href="https://flutter.dev">
    <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.x-blue.svg">
  </a>
  <img alt="Platform" src="https://img.shields.io/badge/Platform-Android-success">
  <img alt="License" src="https://img.shields.io/badge/License-MIT-green">
  <img alt="State" src="https://img.shields.io/badge/Status-Alpha-orange">
  <img alt="CI" src="https://img.shields.io/badge/Build-GitHub%20Actions-lightgrey">
</p>

> **한 줄 요약**: 실시간 13구역 양치 가이드 + 얼굴 정렬 체크 + 레이더 진행률 + TTS 스토리로 아이의 올바른 양치 습관을 만들어주는 Flutter 앱입니다.

---

## 📑 목차
- [주요 기능](#-주요-기능)
- [스샷 & 데모](#-스샷--데모)
- [빠른 시작](#-빠른-시작)
- [권한 & 에셋 설정](#-권한--에셋-설정)
- [폴더 구조](#-폴더-구조)
- [아키텍처 다이어그램](#-아키텍처-다이어그램)
- [개발 노트](#-개발-노트)
- [로드맵](#-로드맵)
- [기여 가이드](#-기여-가이드)
- [라이선스](#-라이선스)
- [문의](#-문의)

---

## ✨ 주요 기능
| 카테고리 | 설명 |
|---|---|
| **라이브 양치 가이드(13구역)** | on‑device TFLite로 브러싱 구역/자세 추정 → 레이더 오버레이로 진행률 시각화 |
| **얼굴 정렬 체크** | 카메라 프레임 기준 정렬/거리/각도 가이드 제공 (FaceCheck) |
| **스토리** | 캐릭터와 대화하며 미션/보상 루프 제공 (StoryDirector) |
| **오프라인 우선** | 프로필/기록은 로컬 저장|
| **아동 친화 UI** | 큰 버튼, 애니메이션, 깔끔한 색감, 직관적 피드백 |
| **가글 권장 화면** | 양치 직후 30초 타이머 + 애니/이미지로 가글 습관 형성 (To‑Do) |

---

## 🎥 스샷 & 데모
- 데모 GIF: `docs/demo_live_brush.gif`
- 스크린샷:
  <p>
    <img src="docs/screenshots/home.png" width="30%">
    <img src="docs/screenshots/face_check.png" width="30%">
    <img src="docs/screenshots/live_brush.png" width="30%">
  </p>

> **Tip**: GIF는 6~10초로 짧게, 핵심 흐름만 보여주세요.

---

## ⚡ 빠른 시작
```bash
# 0) 환경
# - Flutter 3.x (stable), Android Studio, 실기기 권장

# 1) 의존성 설치
flutter pub get

# 2) 필수 에셋/모델 배치 후 pubspec.yaml 등록
#   - assets/models/brush_zone.tflite
#   - assets/images/*
#   - Android 권한 선언(Manifest) 필수

# 3) 실행 (실기기 권장)
flutter run --release
```

**실행 전 필수 체크**
- Android 10+ 실기기 권장(카메라/마이크 퍼포먼스)
- `camera`, `permission_handler`, `tflite_flutter`, `flutter_tts` 등 플러그인 설치
- 모델 파일 크기 및 ABI 대응(arm64-v8a)

---

## 🔐 권한 & 에셋 설정
**`android/app/src/main/AndroidManifest.xml`**
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

**`pubspec.yaml`**
```yaml
flutter:
  assets:
    - assets/models/brush_zone.tflite
    - assets/images/
```

**런타임 권한 요청 예시**
```dart
import 'package:permission_handler/permission_handler.dart';
await [Permission.camera, Permission.microphone].request();
```

---

## 🗂 폴더 구조
> 상위 1~2 레벨만 요약 표기
```
lib/
  app/
    app_router.dart
  core/
    bp/                 # 포인트/스트릭 저장소
    landmarks/          # Face/Hands 브리지
    ml/                 # TFLite 로딩, 전/후처리
    storage/            # 로컬 스토어
    tts/                # TTS 매니저
  features/
    brush_guide/        # FaceCheck, LiveBrush, 결과
    profile/            # 프로필 추가/선택
    home/               # 홈 대시보드
    splash/             # 인트로/튜토리얼
    education/          # 교육 콘텐츠
assets/
  images/
  lottie/
  models/
docs/
  cover.png
  screenshots/
```

<details>
  <summary>참고: 업로드된 예시 파일</summary>

- `intro_page.dart`
- `profile_select_page.dart`, `profile_add_page.dart`
- `home_page.dart`
</details>

---

## 🧠 아키텍처 다이어그램
```

```

---

## 🗒 개발 노트
- **성능**: XNNPACK/NNAPI 토글, 프레임 드롭 방지(스로틀링/버퍼링) 적용 권장  
- **정확도**: 레이블 순서 고정, softmax/argmax 후 smoothing 윈도우 적용  
- **카메라**: 에뮬 대신 실기기 테스트 권장(미디어파이프/카메라 지연 최소화)  
- **UI**: 라이트/다크 대비, 배경과 레이더 채움색 대비 확보  
- **가글 화면(30s)**: Lottie + 원형 타이머 + Skip 버튼, 종료시 결과화면 자동 이동

---

## 🗺 로드맵
- [x] 레이더 진행률 / FaceCheck 기본 동작
- [x] 스토리 & TTS 루프
- [ ] **가글 권장 화면(30초 타이머)**
- [ ] 결과/리포트 리디자인
- [ ] 모델 경량화 & 정확도 향상
- [ ] i18n (ko/en) 지원
- [ ] 원격 설정(모델 버전 토글)

---

## 🤝 기여 가이드
- 이슈/PR 환영합니다. 간단 규칙:
  - **커밋 메시지**: Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:` …)
  - **PR 템플릿**: 변경 요약 + 스샷/GIF + 테스트 방법
  - **코드 스타일**: `dart fix --apply` / `dart format` 준수

---

## 📄 라이선스
MIT © 2025 ChicaChew Team

---
