// lib/core/guide/brush_session_controller.dart
import 'dart:collection';
// ✅ 패키지 경로(권장) — pubspec.yaml의 name이 chicachew일 때
import 'package:chicachew/core/ml/postprocess.dart';
// 또는 상대 경로로 쓰고 싶으면: import '../ml/postprocess.dart';

/// 13개 존 각각 목표 초(예: 10초)
class BrushSessionController {
  final int targetSecPerZone;
  final Map<int, int> doneSec = HashMap<int, int>();
  int currentZone = 0; // 화면 표시용

  BrushSessionController({this.targetSecPerZone = 10}) {
    for (int i = 0; i < 13; i++) { doneSec[i] = 0; }
  }

  bool get isCompleted => doneSec.values.every((v) => v >= targetSecPerZone);
  int get totalDoneSec => doneSec.values.fold(0, (a, b) => a + b); // fold가 안전

  /// 1초마다 현재 존에 1초 적립(확신도 조건 만족 시)
  void tick(ZoneProb z) {
    currentZone = z.index;
    if (z.prob >= 0.5) {
      doneSec[z.index] = (doneSec[z.index] ?? 0) + 1;
    }
  }
}
