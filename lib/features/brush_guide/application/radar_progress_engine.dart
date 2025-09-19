// 📍 lib/features/brush_guide/application/radar_progress_engine.dart
// (100% 도달 시 측정 중단 로직이 적용된 전체 파일)

import 'dart:async';
import 'dart:collection';
import 'dart:math';

class RadarProgressEngine {
  final Duration tickInterval;
  final int ticksTargetPerZone;
  final int zoneCount;

  RadarProgressEngine({
    this.tickInterval = const Duration(seconds: 1),
    this.ticksTargetPerZone = 10,
    this.zoneCount = 13, // 13개 구역을 기본값으로 설정
  });

  Timer? _timer;
  late final List<double> _scores;

  // 1초 동안 인식된 모든 구역 인덱스를 저장할 리스트
  final List<int> _reportedIndicesThisSecond = [];

  final _controller = StreamController<List<double>>.broadcast();
  Stream<List<double>> get progressStream => _controller.stream;

  void start() {
    _scores = List<double>.filled(zoneCount, 0.0);
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
      if (idx >= 0 && idx < zoneCount) {
        // ✅ [수정] 점수를 올리기 전, 현재 점수가 100%(1.0) 미만인지 확인합니다.
        // 이 조건문 때문에 100%에 도달한 구역은 더 이상 점수가 오르지 않습니다.
        final currentScore = _scores[idx];
        if (currentScore < 1.0) {
          final newScore = currentScore + (1.0 / ticksTargetPerZone);
          _scores[idx] = newScore.clamp(0.0, 1.0); // 최종값이 1.0을 넘지 않도록 보정
        }
      }
    }

    _reportedIndicesThisSecond.clear();
    _controller.add(List.from(_scores));
  }

  /// 모델이 구역을 인식할 때마다 이 함수가 호출되어 리스트에 추가합니다.
  void reportZoneIndex(int? zoneIndex) {
    if (zoneIndex != null && zoneIndex >= 0 && zoneIndex < zoneCount) {
      _reportedIndicesThisSecond.add(zoneIndex);
    }
  }

  /// 확률 기반 점수 시스템은 현재 로직과 충돌하므로 비활성화합니다.
  void reportZoneProbs(List<double> probs, {double threshold = 0.2}) {
    // 이 함수는 현재 점수 시스템에서 사용되지 않습니다.
  }
}