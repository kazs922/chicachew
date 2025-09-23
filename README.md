# 🪥 치카츄 (ChicaChew)
### AI 기반 어린이 양치 코치 앱 (Flutter)
---
<p align="center">
  <img src="docs/cover.png" width="240" height="120" alt="ChicaChew Logo"/>
</p>

<p align="center">
  아이의 양치, **재미**와 **데이터**로 코칭합니다.
</p>
<p align="center">
  <strong>13구역 실시간 가이드 · 얼굴 정렬 체크 · 레이더 진행률 · 스토리·보상 루프</strong>
</p>

<p align="center">
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter" /></a>
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart" />
  <img src="https://img.shields.io/badge/Platform-Android-success" />
  <img src="https://img.shields.io/badge/License-MIT-green" />
  <img src="https://img.shields.io/badge/Status-Alpha-orange" />
</p>

---

## ⚙️ 기술 스택

<table>
  <tr>
    <th align="left">앱</th>
    <td>
      <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter"/>
      <img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart"/>
      <img src="https://img.shields.io/badge/camera-Plugin-4a4a4a"/>
      <img src="https://img.shields.io/badge/permission__handler-Plugin-4a4a4a"/>
      <img src="https://img.shields.io/badge/flutter__tts-Plugin-4a4a4a"/>
    </td>
  </tr>
  <tr>
    <th align="left">온디바이스 ML</th>
    <td>
      <img src="https://img.shields.io/badge/TensorFlow%20Lite-tflite__flutter-FF6F00?logo=tensorflow"/>
      <img src="https://img.shields.io/badge/Model-CNN%2BLSTM-FF6F00"/>
      <img src="https://img.shields.io/badge/MediaPipe-Tasks%20Bridge-00C853"/>
    </td>
  </tr>
  <tr>
    <th align="left">스토리지</th>
    <td>
      <img src="https://img.shields.io/badge/SharedPreferences-Local-4a4a4a"/>
      <img src="https://img.shields.io/badge/Firebase-Optional-FFCA28?logo=firebase"/>
      <img src="https://img.shields.io/badge/FastAPI-Optional-009688?logo=fastapi"/>
    </td>
  </tr>
</table>

---

## ✨ 주요 기능

### 🔎 FaceCheck (얼굴 정렬 가이드)  
> 카메라에서 얼굴 위치/각도를 파악해 "가까이/멀리/정면" 등을 실시간 안내합니다.

<div align="center">
  
<table>
  <tr>
    <th>정렬 안내</th>
    <th>거리 가이드</th>
    <th>각도 가이드</th>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshots/face_check_align.png" width="200"/></td>
    <td align="center"><img src="docs/screenshots/face_check_distance.png" width="200"/></td>
    <td align="center"><img src="docs/screenshots/face_check_angle.png" width="200"/></td>
  </tr>
</table>

</div>

### 🪥 LiveBrush (실시간 13구역 양치 가이드)
> TFLite 모델로 구역/자세를 분류하고 **레이더 오버레이**로 진행률을 시각화합니다.

<div align="center">

<table>
  <tr>
    <th>13구역 예측</th>
    <th>레이더 진행률</th>
    <th>TTS 스토리</th>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshots/live_predict.png" width="200"/></td>
    <td align="center"><img src="docs/screenshots/live_radar.png" width="200"/></td>
    <td align="center"><img src="docs/screenshots/live_tts.png" width="200"/></td>
  </tr>
</table>

</div>

### 🫗 가글 권장 화면 (30초 타이머)
> 양치 종료 후 **Lottie 애니메이션 + 원형 타이머**로 가글 습관을 형성합니다. 완료 시 자동으로 결과 화면으로 이동합니다.

<div align="center">
  <img src="docs/screenshots/mouthwash_timer.png" width="280"/>
</div>

### 🎯 게임화 & 보상
- **미션/포인트/스트릭** 시스템으로 꾸준함을 유도
- 어린이 친화적인 **캐릭터 스토리**와 대사(TTS)

---

## 🧭 사용자 시나리오
1. **FaceCheck**에서 얼굴 정렬을 맞춘다.  
2. **LiveBrush**로 13구역 양치 미션을 수행한다.  
3. **가글 화면**에서 30초 타이머를 완료한다.  
4. **결과/리포트**에서 보상과 기록을 확인한다.

---

## 🧩 화면 미리보기

<p align="center">
  <img src="docs/screenshots/home.png" width="26%"/>
  <img src="docs/screenshots/face_check.png" width="26%"/>
  <img src="docs/screenshots/live_brush.png" width="26%"/>
</p>

> 스크린샷은 `docs/screenshots/`에 저장해 상대 경로로 연결하세요.

---

## 🔧 아키텍처 다이어그램

<p align="center">
  <img src="docs/architecture.png" alt="architecture-diagram" width="720"/>
</p>

<details>
<summary>Mermaid로 대체 사용</summary>

```mermaid
flowchart LR
  A[Camera Stream] --> B[Preprocess]
  B --> C[TFLite (13 zones)]
  C --> D[Postprocess & Smoothing]
  D --> E[Radar Overlay UI]
  A --> F[Face Alignment Check]
  E --> G[Story/TTS & Rewards]
  subgraph Storage
    H[Local Stores: Profiles/BP/Streak/Records]
  end
  G --> H
```
</details>

---

## 🗂 폴더 구조 (요약)
```
lib/
  app/
    app_router.dart
  core/
    bp/                 # 포인트/스트릭 저장소
    landmarks/          # Face/Hands 브리지 (MpTasks)
    ml/                 # 모델 로딩·전처리·후처리
    storage/            # 로컬 스토어 (프로필/기록)
    tts/                # TTS 매니저
  features/
    splash/             # 인트로/튜토리얼 (intro_step1/2)
    profile/            # 프로필 추가/선택
    home/               # 홈 대시보드
    brush_guide/        # FaceCheck, LiveBrush, 결과
    education/          # 튜토리얼 콘텐츠
assets/
  images/ lottie/ models/
docs/
  cover.png
  screenshots/
```

---

## 🏁 빠른 시작
```bash
# 의존성 설치
flutter pub get

# (필수) 에셋/모델 등록 - pubspec.yaml
# assets/models/brush_zone.tflite
# assets/images/*, assets/lottie/*

# 실기기 실행 (권장)
flutter run --release
```

**Android 권한 (`android/app/src/main/AndroidManifest.xml`)**
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

**런타임 권한 예시**
```dart
import 'package:permission_handler/permission_handler.dart';
await [Permission.camera, Permission.microphone].request();
```

---

## 🗺 로드맵
- [x] FaceCheck 기본 정렬 가이드
- [x] 13구역 분류 & 레이더 시각화
- [x] 스토리·TTS 보상 루프
- [ ] **가글 권장 화면(30초 타이머)**
- [ ] 결과/리포트 고도화
- [ ] 모델 경량화 & 정확도 향상
- [ ] i18n(ko/en)
- [ ] 원격 설정(모델 버전 토글)

---

## 🙋 My Work (핵심 기여)
- **실시간 카메라 파이프라인** 구축: 프레임 스로틀링/버퍼링, 디바이스 최적화
- **TFLite 엔진(BrushModelEngine)**: 입력 자동 판별, XNNPACK/NNAPI 토글, 다중 출력 핸들링
- **후처리 & smoothing**: softmax → argmax → 구간별 가중 이동평균
- **레이더 오버레이**: 13각형 폴리곤 채움/외곽선 대비 최적화
- **FaceCheck**: MpTasks 브리지, 정렬/거리/각도 힌트 UI
- **스토리·TTS 루프**: TtsManager + StoryDirector, 보상/미션 시스템
- **공통 네비게이션/사이드바**: 모든 페이지에서 동일 동작

---

## 📄 라이선스
MIT © 2025 ChicaChew Team
