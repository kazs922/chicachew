// 📍 lib/features/brush_guide/application/story_director.dart (오류 수정 완료)

import 'dart:async';
import 'dart:math';

// --- (이벤트/열거형 클래스는 새로 주신 파일 기준으로 유지) ---
enum StoryPhase { intro, coaching, finale }
enum FinaleResult { win, draw, lose }
enum Speaker { chikachu, cavitymon, narrator }

abstract class StoryEvent { const StoryEvent(); }

class ShowMessage extends StoryEvent {
  final String text;
  final Duration duration;
  final Speaker speaker;
  const ShowMessage(
      this.text, {
        this.duration = const Duration(seconds: 4),
        this.speaker = Speaker.narrator,
      });
}

class ShowHintForZone extends StoryEvent {
  final int zoneIndex;
  final String zoneName;
  final Duration duration;
  const ShowHintForZone(this.zoneIndex, this.zoneName, {this.duration = const Duration(seconds: 4)});
}

class ShowCompleteZone extends StoryEvent {
  final int zoneIndex;
  final String zoneName;
  final Duration duration;
  const ShowCompleteZone(this.zoneIndex, this.zoneName, {this.duration = const Duration(seconds: 3)});
}

class FinaleEvent extends StoryEvent {
  final FinaleResult result;
  const FinaleEvent(this.result);
}

class BossHudUpdate extends StoryEvent {
  final double advantage; // 0.0~1.0
  const BossHudUpdate(this.advantage);
}

const List<String> kZoneNames = [
  '왼쪽 바깥쪽 치아',
  '앞니 바깥쪽 치아',
  '오른쪽 바깥쪽 치아',
  '오른쪽 입천장쪽 치아',
  '앞니 입천장쪽 치아',
  '왼쪽 입천장쪽 치아',
  '왼쪽 혀쪽 치아',
  '앞니 혀쪽 치아',
  '오른쪽 혀쪽 치아',
  '오른쪽 위 씹는면',
  '왼쪽 위 씹는면',
  '왼쪽 아래 씹는면',
  '오른쪽 아래 씹는면',
];

class StoryDirector {
  StoryDirector({this.ticksTargetPerZone = 5}); // 0.5초 * 5칸 = 2.5초 기준

  final int ticksTargetPerZone;
  final Duration total = const Duration(minutes: 2); // 총 양치 시간 2분

  final StreamController<StoryEvent> _ctrl = StreamController.broadcast();
  Stream<StoryEvent> get stream => _ctrl.stream;

  StoryPhase _phase = StoryPhase.intro;
  final Stopwatch _sw = Stopwatch();
  Timer? _ticker;
  final _rand = Random();

  // --- 상태 관리 변수 ---
  List<double> _scores = List.filled(13, 0.0);
  final _ticksOnCurrentZone = List<int>.filled(13, 0);
  final _neglectedTicks = List<int>.filled(13, 0);

  // 대사 중복 방지
  final Set<int> _spoken50pct = {};
  final Set<int> _completedOnce = {};
  DateTime _lastCoachMsgAt = DateTime.fromMillisecondsSinceEpoch(0);
  final Duration coachCooldown = const Duration(seconds: 8); // 코칭 대사 쿨타임
  bool _finaleEmitted = false;


  void start() {
    if (_ticker != null) return;
    _phase = StoryPhase.intro;
    _sw..reset()..start();

    // 인트로 대사
    _ctrl.add(const ShowMessage('왔구나! 치카치카 용사!',
        duration: Duration(seconds: 4), speaker: Speaker.chikachu));

    Future.delayed(const Duration(seconds: 4), () {
      if (_phase == StoryPhase.intro) {
        _ctrl.add(const ShowMessage('이 몸의 캐비티 공격을 막아낼 수 있을까?',
            duration: Duration(seconds: 4), speaker: Speaker.cavitymon));
      }
    });

    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) => _onTick());
  }

  void dispose() {
    _ticker?.cancel();
    _sw.stop();
    _ctrl.close();
  }

  // ✅ [결합] 실시간 진행도 기반 대사 로직
  void updateProgress(List<double> p) {
    if (p.length != 13) return;

    for (int i = 0; i < 13; i++) {
      final oldScore = _scores[i];
      final newScore = p[i].clamp(0.0, 1.0); // 점수를 0.0 ~ 1.0으로 정규화
      _scores[i] = newScore;

      // 100% 완료
      if (newScore >= 1.0 && !_completedOnce.contains(i)) {
        _completedOnce.add(i);
        _lastCoachMsgAt = DateTime.now();
        // ✅ [수정] _zoneNames -> kZoneNames
        _ctrl.add(ShowCompleteZone(i, kZoneNames[i]));
        if (_completedOnce.length == 13) {
          _emitFinaleOnce(FinaleResult.win);
        }
        return; // 한 번에 하나의 완료 메시지만
      }
      // 50% 달성 (최초 1회)
      else if (newScore >= 0.5 && !_spoken50pct.contains(i) && !_completedOnce.contains(i)) {
        _spoken50pct.add(i);
        _lastCoachMsgAt = DateTime.now();
        // ✅ [수정] _zoneNames -> kZoneNames
        _ctrl.add(ShowMessage('좋아! ${kZoneNames[i]} 쪽을 계속 닦아보자!', speaker: Speaker.chikachu));
        return;
      }
      // 0% -> 닦기 시작 (최초 1회)
      else if (newScore > 0 && oldScore == 0.0) {
        _lastCoachMsgAt = DateTime.now();
        // ✅ [수정] _zoneNames -> kZoneNames
        _ctrl.add(ShowMessage('${kZoneNames[i]} 쪽을 닦아볼까?', speaker: Speaker.chikachu));
        return;
      }
    }
  }

  // ✅ [결합] 시간의 흐름 + 실시간 행동 감지 로직
  void _onTick() {
    if (_finaleEmitted) return;

    final elapsed = _sw.elapsed;

    // HUD 업데이트
    final completedCount = _completedOnce.length;
    _ctrl.add(BossHudUpdate(completedCount / 13.0));

    // --- 시간대별 로직 ---
    // 1. 인트로 (10초)
    if (elapsed < const Duration(seconds: 10)) {
      _phase = StoryPhase.intro;
      return;
    }

    // 2. 코칭 (10초 ~ 1분 50초)
    if (elapsed < total - const Duration(seconds: 10)) {
      if (_phase != StoryPhase.coaching) {
        _phase = StoryPhase.coaching;
        _ctrl.add(const ShowMessage('좋아! 구석구석 깨끗하게 닦아보자!',
            duration: Duration(seconds: 3), speaker: Speaker.chikachu));
      }
      _runCoachingRules();
    }

    // 3. 피날레 (시간 종료 또는 모든 구역 완료 시)
    else {
      if (_phase != StoryPhase.finale) {
        _phase = StoryPhase.finale;
        final avg = _scores.reduce((a, b) => a + b) / _scores.length;
        if (avg >= 0.9) _emitFinaleOnce(FinaleResult.win);
        else if (avg >= 0.6) _emitFinaleOnce(FinaleResult.draw);
        else _emitFinaleOnce(FinaleResult.lose);
      }
    }
  }

  void _runCoachingRules() {
    final now = DateTime.now();
    if (now.difference(_lastCoachMsgAt) < coachCooldown) return;

    int activeZone = -1;
    double maxScore = -1.0;
    for (int i = 0; i < _scores.length; i++) {
      if (_scores[i] > maxScore && !_completedOnce.contains(i)) {
        maxScore = _scores[i];
        activeZone = i;
      }
    }

    // --- 행동 기반 코칭 ---
    // 1. 한 곳만 너무 오래 닦을 때 (8초)
    if (activeZone != -1) {
      _ticksOnCurrentZone[activeZone]++;
      if (_ticksOnCurrentZone[activeZone] > 16) { // 0.5초 * 16 = 8초
        int hintZone = _findLeastBrushedUncompletedZone();
        if (hintZone != -1) {
          _lastCoachMsgAt = now;
          _ctrl.add(ShowHintForZone(hintZone, kZoneNames[hintZone]));
          _ticksOnCurrentZone[activeZone] = 0;
          return;
        }
      }
    }

    // 2. 특정 구역을 너무 오래 방치할 때 (15초)
    for (int i = 0; i < _scores.length; i++) {
      if (i != activeZone && !_completedOnce.contains(i)) {
        _neglectedTicks[i]++;
        if (_neglectedTicks[i] > 30) { // 0.5초 * 30 = 15초
          _lastCoachMsgAt = now;
          _ctrl.add(ShowMessage('크하하! ${kZoneNames[i]} 쪽은 안 닦는군! 내 차지다!',
              speaker: Speaker.cavitymon));
          _neglectedTicks[i] = 0;
          return;
        }
      } else {
        _neglectedTicks[i] = 0;
      }
    }
  }

  int _findLeastBrushedUncompletedZone() {
    double minScore = 2.0;
    int targetZone = -1;
    final uncompleted = <int>[];
    for (int i=0; i < 13; i++) {
      if (!_completedOnce.contains(i)) uncompleted.add(i);
    }
    if (uncompleted.isEmpty) return -1;

    // 덜 닦은 구역들 중에서 무작위로 하나 선택
    return uncompleted[_rand.nextInt(uncompleted.length)];
  }

  void _emitFinaleOnce(FinaleResult result) {
    if (_finaleEmitted) return;
    _finaleEmitted = true;
    _phase = StoryPhase.finale;
    _ctrl.add(FinaleEvent(result));
    _ticker?.cancel();
    _sw.stop();
  }
}