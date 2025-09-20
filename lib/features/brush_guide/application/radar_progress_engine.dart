// 📍 lib/features/brush_guide/application/radar_progress_engine.dart
// (점수 이전 로직이 적용된 최종 버전)

import 'dart:async';
import 'dart:collection';
import 'dart:math';

// ✅ [추가] kBrushZoneCount를 사용하기 위해 import 합니다.
import 'package:chicachew/core/ml/brush_predictor.dart';

class RadarProgressEngine {
  final Duration tickInterval;
  final int ticksTargetPerZone;

  RadarProgressEngine({
    this.tickInterval = const Duration(seconds: 1),
    this.ticksTargetPerZone = 10,
  });

  Timer? _timer;
  late final List<double> _scores;
  final List<int> _reportedIndicesThisSecond = [];

  final _controller = StreamController<List<double>>.broadcast();
  Stream<List<double>> get progressStream => _controller.stream;

  void start() {
    _scores = List<double>.filled(kBrushZoneCount, 0.0);
    _timer?.cancel();
    _timer = Timer.periodic(tickInterval, (_) => _onTick());
  }

  void stop() {
    _timer?.cancel();
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }

  /// 1초마다 실행되는 핵심 로직
  void _onTick() {
    if (_reportedIndicesThisSecond.isEmpty) {
      _controller.add(List.from(_scores));
      return;
    }

    final counts = HashMap<int, int>();
    for (final index in _reportedIndicesThisSecond) {
      counts[index] = (counts[index] ?? 0) + 1;
    }

    int? mostFrequentIndex;
    int maxCount = 0;
    counts.forEach((index, count) {
      if (count > maxCount) {
        maxCount = count;
        mostFrequentIndex = index;
      }
    });

    if (mostFrequentIndex != null) {
      final idx = mostFrequentIndex!;
      if (idx >= 0 && idx < kBrushZoneCount) {
        final currentScore = _scores[idx];
        final scoreToAdd = (1.0 / ticksTargetPerZone);

        if (currentScore < 1.0) {
          // ✅ [기존 로직] 아직 100%가 아니라면, 현재 구역의 점수를 올립니다.
          final newScore = currentScore + scoreToAdd;
          _scores[idx] = newScore.clamp(0.0, 1.0);
        } else {
          // ✅ [새로운 로직] 현재 구역이 100%라면, 가장 덜 닦인 다른 구역을 찾아 점수를 더해줍니다.
          int? spilloverTargetIndex;
          double minScore = 1.0;

          for (int i = 0; i < kBrushZoneCount; i++) {
            if (_scores[i] < minScore) {
              minScore = _scores[i];
              spilloverTargetIndex = i;
            }
          }

          if (spilloverTargetIndex != null) {
            final newScore = _scores[spilloverTargetIndex] + scoreToAdd;
            _scores[spilloverTargetIndex] = newScore.clamp(0.0, 1.0);
          }
        }
      }
    }

    _reportedIndicesThisSecond.clear();
    _controller.add(List.from(_scores));
  }

  /// 모델이 구역을 인식할 때마다 이 함수가 호출되어 리스트에 추가합니다.
  void reportZoneIndex(int? zoneIndex) {
    if (zoneIndex != null && zoneIndex >= 0 && zoneIndex < kBrushZoneCount) {
      _reportedIndicesThisSecond.add(zoneIndex);
    }
  }

  /// 확률 기반 점수 시스템은 현재 로직과 충돌하므로 비활성화합니다.
  void reportZoneProbs(List<double> probs, {double threshold = 0.2}) {
    // 이 함수는 현재 점수 시스템에서 사용되지 않습니다.
  }
}