# 🪥 치카츄 (ChicaChew)
### 딥러닝 기반 어린이 양치 코치 앱
---
<p align="center">
  <img width="240" height="360" alt="Gemini_Generated_Image_p9unsp9unsp9unsp" src="https://github.com/user-attachments/assets/c43c5723-7853-4542-bb28-8523ed4a9d77" />
</p>

</p>
<p align="center">
  <strong>딥러닝 기반의 어린이 맞춤형 구강 관리 교육 AI 솔루션</strong>
</p>

<h2>🍀 Our Team</h2>

<table align="center">
  <tr>
    <th style="padding: 10px; font-size: 16px;">👨‍💻 성태희</th>
    <th style="padding: 10px; font-size: 16px;">👨‍💻 장동민</th>
    <th style="padding: 10px; font-size: 16px;">📱 양동현</th>
    <th style="padding: 10px; font-size: 16px;">💡 이태영</th>
    <th style="padding: 10px; font-size: 16px;">💡 김예은</th>
  </tr>
  <tr>
    <td align="center" style="padding: 10px; font-size: 14px;"><strong>모델 개발 구현</strong></td>
    <td align="center" style="padding: 10px; font-size: 14px;"><strong>데이터 전처리 &<br> 모델 성능 개선</strong></td>
    <td align="center" style="padding: 10px; font-size: 14px;"><strong>APP 개발 & <br>UI 디자인</strong></td>
    <td align="center" style="padding: 10px; font-size: 14px;"><strong>기획 & <br>자료 조사</strong></td>
    <td align="center" style="padding: 10px; font-size: 14px;"><strong>기획 & <br>데이터 수집</strong></td>
  </tr>
</table>


## ⚙️ 기술 스택

<table>
  <tr>
    <th align="left">데이터 수집 · 라벨링</th>
    <td>
      <img src="https://img.shields.io/badge/Custom%20Recorder-따라츄-6A5ACD"/>
      <img src="https://img.shields.io/badge/MediaPipe-Tasks-14A0C4?logo=google"/>
      <img src="https://img.shields.io/badge/OpenCV-Tooling-5C3EE8?logo=opencv&logoColor=white"/>
      <img src="https://img.shields.io/badge/LOSO-CV%20Protocol-2E7D32"/>
    </td>
  </tr>
  <tr>
    <th align="left">데이터 처리 / EDA</th>
    <td>
      <img src="https://img.shields.io/badge/Pandas-2.2.3-150458?logo=pandas&logoColor=white"/>
      <img src="https://img.shields.io/badge/NumPy-2.2.5-013243?logo=numpy&logoColor=white"/>
      <img src="https://img.shields.io/badge/scikit--learn-1.6.1-F7931E?logo=scikitlearn"/>
      <img src="https://img.shields.io/badge/Matplotlib-Plotting-11557C?logo=matplotlib"/>
      <img src="https://img.shields.io/badge/RapidFuzz-3.13.0-820AD1"/>
      <img src="https://img.shields.io/badge/KoNLPy-0.6.0-00CED1"/>
      <img src="https://img.shields.io/badge/jamo-0.4.1-FF69B4"/>
    </td>
  </tr>
  <tr>
    <th align="left">모델링 · 최적화</th>
    <td>
      <img src="https://img.shields.io/badge/TensorFlow-Training-FF6F00?logo=tensorflow&logoColor=white"/>
      <img src="https://img.shields.io/badge/CNN+GRU-Sequence%20Model-009688"/>
      <img src="https://img.shields.io/badge/Optuna-HPO-792EE5"/>
      <img src="https://img.shields.io/badge/Time%20Features-Velocity%20%7C%20Angles-455A64"/>
      <img src="https://img.shields.io/badge/Feature%20Set-Hand%2021%20%2B%20Face%20Cues-37474F"/>
    </td>
  </tr>
  <tr>
    <th align="left">온디바이스 추론</th>
    <td>
      <img src="https://img.shields.io/badge/TFLite-Interpreter-34A853?logo=tensorflow&logoColor=white"/>
      <img src="https://img.shields.io/badge/tflite_flutter-FF6F00"/>
      <img src="https://img.shields.io/badge/SELECT_TF_OPS/Unroll-GRU%20Export-546E7A"/>
      <img src="https://img.shields.io/badge/Latency-~ms%20Level-757575"/>
    </td>
  </tr>
  <tr>
    <th align="left">앱 개발</th>
    <td>
      <!-- ⬇️ 고정 항목 -->
      <img src="https://img.shields.io/badge/Flutter-3.35.3-02569B?logo=flutter"/>
      <img src="https://img.shields.io/badge/Dart-3.9.2-0175C2?logo=dart"/>
      <img src="https://img.shields.io/badge/Android_Studio-Narwhal%203-3DDC84?logo=androidstudio"/>
    </td>
  </tr>
  <tr>
    <th align="left">실험 · 재현 / 협업</th>
    <td>
      <img src="https://img.shields.io/badge/Jupyter-Notebooks-F37626?logo=jupyter&logoColor=white"/>
      <img src="https://img.shields.io/badge/Weights%20%26%20Artifacts-Tracked-455A64"/>
      <img src="https://img.shields.io/badge/Bootstrap%20CI-Stats-607D8B"/>
      <img src="https://img.shields.io/badge/Git-GitHub-181717?logo=github"/>
    </td>
  </tr>
</table>


# ✨ 프로젝트 주요 기능

<!-- 1행(3탭): 홈 화면 · 브러쉬 타임 · 교육 자료  -->
<table align="center" style="border-collapse:collapse; table-layout:fixed; width:100%; max-width:960px;">
  <!-- 제목(Row 1) -->
  <tr>
    <th style="border:1px solid #e5e7eb; padding:10px; width:33%;">홈 화면</th>
    <th style="border:1px solid #e5e7eb; padding:10px; width:33%;">브러쉬 타임</th>
    <th style="border:1px solid #e5e7eb; padding:10px; width:33%;">교육 자료</th>
  </tr>
  <!-- 화면(이미지, Row 2) -->
  <tr>
    <td style="border:1px solid #e5e7eb; padding:14px; text-align:center;">
      <img src="https://github.com/user-attachments/assets/ea8f5204-37c3-4d15-8c87-e975d76a2274"
           alt="홈 화면" width="240"
           style="display:block; margin:0 auto;"/>
    </td>
    <td style="border:1px solid #e5e7eb; padding:14px; text-align:center;">
      <img src="https://github.com/user-attachments/assets/d47c0f81-3e40-4d00-bb9d-34804b459765"
           alt="브러쉬 타임" width="240"
           style="display:block; margin:0 auto;"/>
    </td>
    <td style="border:1px solid #e5e7eb; padding:14px; text-align:center;">
      <img src="https://github.com/user-attachments/assets/3ed02c72-8129-45b9-979d-3dd9d4d1cdf8"
           alt="교육 자료" width="240"
           style="display:block; margin:0 auto;"/>
    </td>
  </tr>
  <!-- 설명(Row 3) -->
  <tr>
    <td style="border:1px solid #e5e7eb; padding:14px;">
      <div style="background:#F7FAF9; border:1px solid #DDEAE4; border-radius:10px; padding:12px;">
        <strong style="display:block; margin-bottom:6px;">📌 요약</strong>
        <span style="font-size:13px; line-height:1.6; color:#1f2937;">
          오늘의 미션 · BP · 스트릭을 한 화면에서 확인
        </span>
      </div>
    </td>
    <td style="border:1px solid #e5e7eb; padding:14px;">
      <div style="background:#F7FAF9; border:1px solid #DDEAE4; border-radius:10px; padding:12px;">
        <strong style="display:block; margin-bottom:6px;">🪥 진행</strong>
        <span style="font-size:13px; line-height:1.6; color:#1f2937;">
          얼굴 정렬 · 라이브 안내(TTS/진동) · 13구역 레이더
        </span>
      </div>
    </td>
    <td style="border:1px solid #e5e7eb; padding:14px;">
      <div style="background:#F7FAF9; border:1px solid #DDEAE4; border-radius:10px; padding:12px;">
        <strong style="display:block; margin-bottom:6px;">🎓 가이드</strong>
        <span style="font-size:13px; line-height:1.6; color:#1f2937;">
          양치 튜토리얼 · 올바른 자세 · 단계별 학습
        </span>
      </div>
    </td>
  </tr>
</table>


</div>



<!-- 빠른 이동 링크 -->
<p align="center">
  <a href="#-브러쉬-타임--핵심-기능">브러쉬 타임 자세히 보기</a> ·
  <a href="#-리포트--핵심-기능">리포트 자세히 보기</a>
</p>



## 🔧 아키텍처 다이어그램

<p align="center">
  <img src="https://github.com/user-attachments/assets/0a12bfff-dec4-4a52-bad2-9afc72c52353" alt="architecture-diagram" width="700"/>
</p>

> 전체 시스템은 **3-Tier 구조 기반의 경량 아키텍처**입니다.  
 - 빠른 응답성과 구조 단순화를 위해 3-Tier를 개조하여 경량화했습니다.  
 - 별도의 Service Layer 없이, API 내부에서 모든 로직을 직접 처리하도록 구성했습니다.

> **Firebase**를 데이터 저장소로, **FastAPI**를 중심으로 검색 / 분류 / 추천 기능을 제공합니다.  
 - 제품 데이터는 Firebase에 상세 필드를 모두 포함한 형태로 업로드되어 있습니다.  
 - 데이터베이스는 복잡한 관계형 구조를 지양하고, 단순성과 명확성을 우선했습니다.

> 앱은 **Flutter + Dart**로 개발되어 사용자 인터페이스를 담당합니다.

## 🛠️ My Work

### APP 구현
- **제품 검색 기능**:
사용자는 제품명, 브랜드, 카테고리 등을 기준으로 원하는 식품을 검색할 수 있습니다. 검색 결과는 실시간으로 반영되며, 직관적인 UI를 통해 쉽게 탐색할 수 있도록 구성되어 있습니다.

- **성분 안전도 분석**:
각 식품의 전성분을 분석하여 Safe, Warning, Caution, Etc의 4가지 등급으로 분류하고, 이를 시각적으로 한눈에 볼 수 있게 제공합니다. 이를 통해 사용자들이 어떤 성분이 건강에 안전한지 쉽게 확인할 수 있습니다.


- **카테고리 및 브랜드별 탐색**:
제품은 다양한 식품 카테고리와 브랜드 기준으로 분류되어 있어, 사용자가 원하는 범주 내에서 제품을 빠르게 찾아볼 수 있습니다.

- **로딩 애니메이션 적용**:
앱의 여러 화면에는 Lottie 기반의 로딩 애니메이션이 적용되어 있어, 로딩 중에도 사용자에게 시각적 피드백을 제공하여 UX를 향상시킵니다.

- **공통 사이드바 및 바텀 네비게이션**:
모든 화면에서 동일한 사이드 메뉴와 하단 네비게이션 바를 제공하여 앱 내 어디서든 쉽게 원하는 기능으로 이동할 수 있도록 구성되어 있습니다.

- **오늘의 혈당 상식 배너**:
홈 화면에는 매번 랜덤하게 변경되는 혈당 상식 배너가 표시되어, 사용자에게 유용한 건강 정보를 자연스럽게 제공합니다.

- **추천 상품 탭**:
제품 상세 화면에는 ‘전성분’, ‘영양성분’ 탭 외에도 ‘추천상품’ 탭이 추가되어, 해당 제품과 관련 있는 다른 제로슈거 식품을 함께 소개합니다. 이로써 더 많은 제품을 탐색할 수 있는 기회를 제공합니다.


## 📄 라이선스
MIT © 2025 ChicaChew Team
