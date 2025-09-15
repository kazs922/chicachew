import 'dart:async';
import 'dart:math';

enum StoryPhase { intro, coaching, finale }
enum FinaleResult { win, draw, lose }

// 화자
enum Speaker { chikachu, cavitymon, narrator }

abstract class StoryEvent { const StoryEvent(); }

class ShowMessage extends StoryEvent {
  final String text;
  final Duration duration;
  final String? voice;
  final Speaker speaker;
  const ShowMessage(
      this.text, {
        this.duration = const Duration(seconds: 10),
        this.voice,
        this.speaker = Speaker.narrator,
      });
}

class ShowHintForZone extends StoryEvent {
  final int zoneIndex;
  final String zoneName;
  final Duration duration;
  const ShowHintForZone(this.zoneIndex, this.zoneName,
      {this.duration = const Duration(seconds: 10)});
}

class ShowCompleteZone extends StoryEvent {
  final int zoneIndex;
  final String zoneName;
  final Duration duration;
  const ShowCompleteZone(this.zoneIndex, this.zoneName,
      {this.duration = const Duration(seconds: 2)});
}

class FinaleEvent extends StoryEvent {
  final FinaleResult result;
  const FinaleEvent(this.result);
}

class BossHudUpdate extends StoryEvent {
  final double advantage; // 0.0~1.0
  const BossHudUpdate(this.advantage);
}

/// ─────────────────────────────────────────────────────────
/// 13구역 (네가 준 기술 용어 순서를 유지하되, 어린이 말로 표시)
/// 기술용어 → 어린이 라벨 매핑:
/// 1. 왼쪽-협측        → 왼쪽 바깥쪽
/// 2. 중앙-협측        → 가운데 바깥쪽
/// 3. 오른쪽-협측      → 오른쪽 바깥쪽
/// 4. 오른쪽-구개측    → 오른쪽 위 안쪽
/// 5. 중앙-구개측      → 가운데 위 안쪽
/// 6. 왼쪽-구개측      → 왼쪽 위 안쪽
/// 7. 왼쪽-설측        → 왼쪽 아래 안쪽
/// 8. 중앙-설측        → 가운데 아래 안쪽
/// 9. 오른쪽-설측      → 오른쪽 아래 안쪽
/// 10. 오른쪽-위-씹는면 → 오른쪽 위 씹는면
/// 11. 왼쪽-위-씹는면   → 왼쪽  위 씹는면
/// 12. 왼쪽-아래-씹는면 → 왼쪽  아래 씹는면
/// 13. 오른쪽-아래-씹는면→ 오른쪽 아래 씹는면
/// ─────────────────────────────────────────────────────────
const List<String> kZoneNames = [
  '왼쪽 바깥쪽',     // 왼쪽-협측
  '가운데 바깥쪽',   // 중앙-협측
  '오른쪽 바깥쪽',   // 오른쪽-협측
  '오른쪽 위 안쪽',  // 오른쪽-구개측
  '가운데 위 안쪽',  // 중앙-구개측
  '왼쪽 위 안쪽',    // 왼쪽-구개측
  '왼쪽 아래 안쪽',  // 왼쪽-설측
  '가운데 아래 안쪽',// 중앙-설측
  '오른쪽 아래 안쪽',// 오른쪽-설측
  '오른쪽 위 씹는면',// 오른쪽-위-씹는면
  '왼쪽 위 씹는면',  // 왼쪽-위-씹는면
  '왼쪽 아래 씹는면',// 왼쪽-아래-씹는면
  '오른쪽 아래 씹는면', // 오른쪽-아래-씹는면
];

class StoryDirector {
  StoryDirector({this.ticksTargetPerZone = 10});

  final int ticksTargetPerZone;
  final Duration total = const Duration(minutes: 3);

  final StreamController<StoryEvent> _ctrl = StreamController.broadcast();
  Stream<StoryEvent> get stream => _ctrl.stream;

  StoryPhase _phase = StoryPhase.intro;
  final Stopwatch _sw = Stopwatch();

  // 진행률(0~100 기대, 길이 13)
  List<double> _p = List.filled(13, 0.0);

  DateTime _lastCoachMsgAt = DateTime.fromMillisecondsSinceEpoch(0);
  final Duration coachCooldown = const Duration(seconds: 10);

  // 완료 대사 1회만
  final Set<int> _completedOnce = {};

  bool _balanceWarned = false;

  Timer? _ticker;
  final _rand = Random();

  // 엔딩 한번만
  bool _finaleEmitted = false;

  void start() {
    if (_ticker != null) return;
    _phase = StoryPhase.intro;
    _sw..reset()..start();

    // 인트로(화자 지정)
    _ctrl.add(const ShowMessage('하하! 이런 양치로 날 이길 수 있을까?',
        duration: Duration(seconds: 5), speaker: Speaker.cavitymon));
    _ctrl.add(const ShowMessage('그만! 캐비티몬을 무찌르기 위해 양치를 시작하자!',
        duration: Duration(seconds: 5), speaker: Speaker.chikachu));

    _ticker = Timer.periodic(const Duration(milliseconds: 300), (_) => _onTick());
  }

  void dispose() {
    _ticker?.cancel();
    _ctrl.close();
  }

  void updateProgress(List<double> p) {
    if (p.length == 13) {
      _p = p.map((v) => v.clamp(0.0, 100.0)).toList();
      // 진행 업데이트 시에도 전구역 100%면 즉시 엔딩
      if (!_finaleEmitted && _allFull(_p)) {
        _emitFinaleOnce(FinaleResult.win);
      }
    }
  }

  void _onTick() {
    if (_finaleEmitted) return;

    final elapsed = _sw.elapsed;

    // HUD(보스 게이지) 갱신
    final avg = _p.reduce((a, b) => a + b) / _p.length;
    _ctrl.add(BossHudUpdate((avg / 100.0).clamp(0.0, 1.0)));

    // 어느 타이밍이든 전구역 100%면 즉시 엔딩
    if (_allFull(_p)) {
      _emitFinaleOnce(FinaleResult.win);
      return;
    }

    // 인트로 타임
    if (elapsed <= const Duration(seconds: 25)) {
      _phase = StoryPhase.intro;
      return;
    }

    // 코칭 타임
    if (elapsed < const Duration(minutes: 2, seconds: 36)) {
      if (_phase != StoryPhase.coaching) {
        _phase = StoryPhase.coaching;
        _ctrl.add(const ShowMessage('좋아! 안내를 보면서 천천히 따라 해보자.',
            duration: Duration(seconds: 3), speaker: Speaker.chikachu));
      }
      _runCoachingRules();

      // 밸런스 경고(한 번만)
      if (!_balanceWarned && elapsed >= const Duration(minutes: 1, seconds: 50)) {
        final step = 100.0 / ticksTargetPerZone;  // 예: 10칸
        int toTicks(double v) => (v / step).round();
        final minTick = (ticksTargetPerZone * 0.5).round(); // 5칸
        final maxTick = (ticksTargetPerZone * 0.6).round(); // 6칸

        final cntMid = _p.where((v) {
          final t = toTicks(v);
          return t >= minTick && t <= maxTick;
        }).length;

        if (cntMid >= 10) {
          _ctrl.add(const ShowMessage('너무 비슷한 곳만 닦는 중! 더 고루고루 닦아보자!',
              duration: Duration(seconds: 4), speaker: Speaker.chikachu));
        }
        _balanceWarned = true;
      }
      return;
    }

    // 파이널 타임(시간 종료 기준) — FinaleEvent만 발행
    if (_phase != StoryPhase.finale) {
      _phase = StoryPhase.finale;
      if (avg >= 90.0) {
        _emitFinaleOnce(FinaleResult.win);
      } else if (avg >= 60.0) {
        _emitFinaleOnce(FinaleResult.draw);
      } else {
        _emitFinaleOnce(FinaleResult.lose);
      }
    }

    if (elapsed >= total) _ticker?.cancel();
  }

  void _runCoachingRules() {
    final now = DateTime.now();

    // 각 구역 100% → 완료 대사 "한 번만"
    for (var i = 0; i < 13; i++) {
      final v = _p[i];
      if (v >= 100.0 && !_completedOnce.contains(i)) {
        _completedOnce.add(i);
        _ctrl.add(ShowCompleteZone(i, kZoneNames[i],
            duration: const Duration(seconds: 2)));

        // 모두 완료면 즉시 엔딩
        if (_completedOnce.length == 13 && !_finaleEmitted) {
          _emitFinaleOnce(FinaleResult.win);
        }
        return; // 한 틱에 한 이벤트만
      }
    }

    // 코칭 쿨다운
    if (now.difference(_lastCoachMsgAt) < coachCooldown) return;

    // 부족한 구역 힌트
    final poor = <int>[];
    for (var i = 0; i < 13; i++) {
      if (_p[i] < 50.0) poor.add(i);
    }
    if (poor.isNotEmpty) {
      final idx = poor[_rand.nextInt(poor.length)];
      _lastCoachMsgAt = now;
      _ctrl.add(ShowHintForZone(idx, kZoneNames[idx],
          duration: const Duration(seconds: 10)));
      return;
    }

    // 격려 멘트
    final anyGood = _p.any((v) => v >= 50.0 && v < 100.0);
    if (anyGood) {
      _lastCoachMsgAt = now;
      _ctrl.add(const ShowMessage('잘하고 있어! 조금만 더 하면 성공이야!',
          duration: const Duration(seconds: 10), speaker: Speaker.chikachu));
    }
  }

  // ===== 헬퍼 =====
  bool _allFull(List<double> src) {
    if (src.length != 13) return false;
    // 부동소수 보정: 99.9% 이상이면 완료로 간주
    return src.every((v) => v >= 99.9);
  }

  void _emitFinaleOnce(FinaleResult result) {
    if (_finaleEmitted) return;
    _finaleEmitted = true;

    _phase = StoryPhase.finale;
    _ctrl.add(FinaleEvent(result));

    _ticker?.cancel();
  }
}
