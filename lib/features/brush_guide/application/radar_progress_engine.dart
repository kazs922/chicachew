// 📍 lib/features/brush_guide/application/radar_progress_engine.dart
// (파일 전체를 이 코드로 교체하세요)

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
    // 1초 동안 수집된 인식 기록이 없으면 아무것도 하지 않고 현재 점수만 보냅니다.
    if (_reportedIndicesThisSecond.isEmpty) {
      _controller.add(List.from(_scores));
      return;
    }

    // 수집된 기록 중에서 가장 많이 나타난 구역(최빈값)을 찾습니다.
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

    // 가장 많이 인식된 구역의 점수를 1칸 올립니다.
    if (mostFrequentIndex != null) {
      final idx = mostFrequentIndex!;
      if (idx >= 0 && idx < zoneCount) {
        final current = _scores[idx];
        if (current < 1.0) {
          _scores[idx] = (current + 1.0 / ticksTargetPerZone).clamp(0.0, 1.0);
        }
      }
    }

    // 다음 1초를 위해 수집 리스트를 비웁니다.
    _reportedIndicesThisSecond.clear();

    // UI에 변경된 점수를 알립니다.
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