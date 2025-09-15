// lib/features/brush_guide/application/radar_progress_engine.dart
import 'dart:async';
import 'dart:math';

/// 레이더 진행 엔진
/// - 프레임 확률을 바로 누적하지 않고, '활성 존'을 안정적으로 확정한 뒤 tick 단위로 누적
/// - 전환시 hold, 완료 후 cooldown, top1-vs-top2 margin 등으로 붙박이/플리커 방지
class RadarProgressEngine {
  final Duration tickInterval;
  final int ticksTargetPerZone; // 한 존을 100%로 채우는 데 필요한 tick 개수

  final int zoneCount;

  // 안정화 파라미터
  final double minTop1;     // top1 확률 최소
  final double minMargin;   // (top1 - top2) 최소 간격
  final Duration holdTime;  // 존이 바뀌었을 때 누적 시작 전 대기
  final Duration cooldown;  // 100% 가까운 누적 후 잠깐 쉬기
  final double stepPerTick; // tick 당 가산치 (기본: 1/ticksTargetPerZone)

  // 내부 상태
  final _ctrl = StreamController<List<double>>.broadcast();
  late final List<double> _scores; // 0..1
  Timer? _tm;

  int? _activeZone;                // 현재 인정된 활성 존
  int? _candidateZone;             // hold 중인 후보 존
  DateTime _candidateSince = DateTime.fromMillisecondsSinceEpoch(0);

  // 존별 쿨다운 종료시각
  late final List<DateTime> _cooldownUntil;

  // 외부에서 보기 위한 스트림
  Stream<List<double>> get progressStream => _ctrl.stream;

  RadarProgressEngine({
    required this.tickInterval,
    required this.ticksTargetPerZone,
    this.zoneCount = 13,
    this.minTop1 = 0.25,
    this.minMargin = 0.15,
    this.holdTime = const Duration(milliseconds: 400),
    this.cooldown = const Duration(milliseconds: 800),
    double? customStepPerTick,
  }) : stepPerTick = customStepPerTick ?? (1.0 / max(1, ticksTargetPerZone)) {
    _scores = List<double>.filled(zoneCount, 0.0);
    _cooldownUntil = List<DateTime>.filled(
      zoneCount,
      DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  void start() {
    _tm?.cancel();
    _tm = Timer.periodic(tickInterval, (_) => _onTick());
  }

  void stop() {
    _tm?.cancel();
    _tm = null;
  }

  void dispose() {
    stop();
    _ctrl.close();
  }

  /// 모델에서 top-1 인덱스만 줄 때 사용(옵션)
  void reportZoneIndex(int? zoneIndex) {
    if (zoneIndex == null || zoneIndex < 0 || zoneIndex >= zoneCount) return;
    _updateCandidate(zoneIndex);
  }

  /// 모델 확률 벡터 입력(권장)
  void reportZoneProbs(List<double> probs, {double? threshold}) {
    if (probs.isEmpty) return;
    // 길이가 부족하면 앞쪽만 사용, 길이가 많으면 앞쪽 zoneCount만 사용
    final n = min(zoneCount, probs.length);
    double top1 = -1, top2 = -1;
    int i1 = -1, i2 = -1;

    for (int i = 0; i < n; i++) {
      final p = probs[i];
      if (p > top1) { top2 = top1; i2 = i1; top1 = p; i1 = i; }
      else if (p > top2) { top2 = p; i2 = i; }
    }

    if (i1 < 0) return;

    final thr = threshold ?? minTop1;
    final goodTop1 = top1 >= thr;
    final goodMargin = (top1 - (top2 < 0 ? 0.0 : top2)) >= minMargin;

    if (goodTop1 && goodMargin) {
      _updateCandidate(i1);
    }
    // 조건이 나빠지면 누적은 일시 정지되지만, 즉시 activeZone을 날리지는 않음
    // (플리커 방지). 누적은 tick에서 cooldown/hold와 함께 결정됨.
  }

  /// 외부에서 강제로 진행 상황을 업데이트하고 싶을 때(대체로 내부에서만 사용)
  void updateProgress(List<double> newScores) {
    for (int i = 0; i < min(zoneCount, newScores.length); i++) {
      _scores[i] = newScores[i].clamp(0.0, 1.0);
    }
    _emit();
  }

  // ──────────────────────────────────────────────────────────────
  // 내부 로직
  // ──────────────────────────────────────────────────────────────

  void _emit() {
    _ctrl.add(List<double>.from(_scores));
  }

  void _updateCandidate(int zone) {
    // 쿨다운 중이면 후보조차 안받음
    if (_isInCooldown(zone)) return;

    if (_candidateZone != zone) {
      _candidateZone = zone;
      _candidateSince = DateTime.now();
    } else {
      // 같은 후보 계속 유지 중
      final held = DateTime.now().difference(_candidateSince);
      if (held >= holdTime) {
        // hold 충족 → 활성 존 교체
        _activeZone = zone;
      }
    }
  }

  bool _isInCooldown(int zone) {
    return DateTime.now().isBefore(_cooldownUntil[zone]);
  }

  void _onTick() {
    if (_activeZone == null) {
      _emit();
      return;
    }

    final z = _activeZone!;
    if (_isInCooldown(z)) {
      _emit();
      return;
    }

    // 가산
    final before = _scores[z];
    final after = (before + stepPerTick).clamp(0.0, 1.0);
    _scores[z] = after;

    // 거의 찼으면 쿨다운 걸고 활성 해제
    if (after >= 0.999) {
      _cooldownUntil[z] = DateTime.now().add(cooldown);
      _activeZone = null; // 다음 존을 기다림
      _candidateZone = null;
    }

    _emit();
  }
}
