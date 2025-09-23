// 📍 lib/features/brush_guide/application/story_director.dart (수정 완료)

import 'dart:async';
import 'dart:math';
import 'package:chicachew/core/ml/brush_predictor.dart';


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

class StoryDirector {
  StoryDirector({this.ticksTargetPerZone = 10});

  final int ticksTargetPerZone;
  final Duration total = const Duration(minutes: 2);

  final _storyController = StreamController<StoryEvent>.broadcast();
  Stream<StoryEvent> get stream => _storyController.stream;

  final _progressController = StreamController<List<double>>.broadcast();
  Stream<List<double>> get progressStream => _progressController.stream;

  StoryPhase _phase = StoryPhase.intro;
  final Stopwatch _sw = Stopwatch();
  Timer? _ticker;
  final _rand = Random();

  List<double> _scores = List.filled(kBrushZoneCount, 0.0);
  final _ticksOnCurrentZone = List<int>.filled(kBrushZoneCount, 0);
  final _neglectedTicks = List<int>.filled(kBrushZoneCount, 0);

  final Set<int> _spoken50pct = {};
  final Set<int> _completedOnce = {};
  DateTime _lastCoachMsgAt = DateTime.fromMillisecondsSinceEpoch(0);
  final Duration coachCooldown = const Duration(seconds: 8);
  bool _finaleEmitted = false;


  void start() {
    if (_ticker != null) return;
    _phase = StoryPhase.intro;
    _sw..reset()..start();
    _storyController.add(const ShowMessage('왔구나! 치카치카 용사!',
        duration: Duration(seconds: 4), speaker: Speaker.chikachu));
    Future.delayed(const Duration(seconds: 4), () {
      if (_phase == StoryPhase.intro && !_finaleEmitted) {
        _storyController.add(const ShowMessage('이 몸의 캐비티 공격을 막아낼 수 있을까?',
            duration: Duration(seconds: 4), speaker: Speaker.cavitymon));
      }
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) => _onTick());
  }

  Future<void> startDemoSequence() async {
    // ✅ [수정] 5개 구역만 완벽하게 닦도록 스크립트를 줄입니다.
    final script = [
      {'zoneIndex': 1, 'text': '먼저 앞니 바깥쪽을 닦아볼까?', 'duration': 5},
      {'zoneIndex': 0, 'text': '좋아! 이제 왼쪽 바깥쪽을 닦아보자.', 'duration': 5},
      {'zoneIndex': 2, 'text': '잘했어! 이번엔 오른쪽 바깥쪽이야.', 'duration': 5},
      {'zoneIndex': 10, 'text': '왼쪽 위 씹는 면도 꼼꼼하게!', 'duration': 6},
      {'zoneIndex': 9, 'text': '좋아, 반대쪽도 닦아줘!', 'duration': 6},
    ];

    _storyController.add(ShowMessage(
      '치카치카 용사! 나와 함께 캐비티몬을 물리치자!',
      duration: const Duration(seconds: 4),
      speaker: Speaker.chikachu,
    ));
    await Future.delayed(const Duration(seconds: 4));

    for (var step in script) {
      if (_storyController.isClosed) return;
      final zoneIndex = step['zoneIndex'] as int;
      final text = step['text'] as String;
      final duration = step['duration'] as int;

      _storyController.add(ShowMessage(
          text,
          duration: const Duration(seconds: 2),
          speaker: Speaker.chikachu
      ));

      await Future.delayed(const Duration(milliseconds: 1500));

      for (int i = 1; i <= 10; i++) {
        await Future.delayed(Duration(milliseconds: duration * 1000 ~/ 10));
        if(!_storyController.isClosed) {
          _scores[zoneIndex] = i / 10.0;
          _progressController.add(List.from(_scores));
        }
      }
      _completedOnce.add(zoneIndex);
    }

    final random = Random();
    for (int i = 0; i < kBrushZoneCount; i++) {
      if (!_completedOnce.contains(i)) {
        _scores[i] = 0.3 + random.nextDouble() * 0.4; // 30% ~ 70%
      }
    }
    if(!_storyController.isClosed) _progressController.add(List.from(_scores));

    _storyController.add(ShowMessage(
        '앗! 시간이 부족해! 서두르자!',
        duration: const Duration(seconds: 3),
        speaker: Speaker.chikachu
    ));
    await Future.delayed(const Duration(seconds: 4));

    // ✅ [수정] 최종 결과를 '무승부(draw)'로 변경하여 아쉬운 느낌을 줍니다.
    if(!_storyController.isClosed) _storyController.add(FinaleEvent(FinaleResult.draw));
  }

  void updateProgress(List<double> p) {
    if (p.length != kBrushZoneCount) return;

    for (int i = 0; i < kBrushZoneCount; i++) {
      final oldScore = _scores[i];
      final newScore = p[i].clamp(0.0, 1.0);
      _scores[i] = newScore;

      if (newScore > oldScore) {
        if (newScore >= 1.0 && !_completedOnce.contains(i)) {
          _completedOnce.add(i);
          _lastCoachMsgAt = DateTime.now();
          _storyController.add(ShowCompleteZone(i, kBrushZoneNames[i]));
          if (_completedOnce.length == kBrushZoneCount) {
            _emitFinaleOnce(FinaleResult.win);
          }
          return;
        }
        else if (newScore >= 0.5 && !_spoken50pct.contains(i) && !_completedOnce.contains(i)) {
          _spoken50pct.add(i);
          _lastCoachMsgAt = DateTime.now();
          _storyController.add(ShowMessage('좋아! ${kBrushZoneNames[i]} 쪽을 계속 닦아보자!', speaker: Speaker.chikachu));
          return;
        }
        else if (newScore > 0 && oldScore == 0.0) {
          _lastCoachMsgAt = DateTime.now();
          _storyController.add(ShowMessage('${kBrushZoneNames[i]} 쪽을 닦아볼까?', speaker: Speaker.chikachu));
          return;
        }
      }
    }
  }

  void _onTick() {
    if (_finaleEmitted) return;

    final elapsed = _sw.elapsed;
    final completedCount = _completedOnce.length;
    _storyController.add(BossHudUpdate(completedCount / kBrushZoneCount.toDouble()));

    if (elapsed < const Duration(seconds: 10)) {
      _phase = StoryPhase.intro;
      return;
    }

    if (elapsed < total - const Duration(seconds: 10)) {
      if (_phase != StoryPhase.coaching) {
        _phase = StoryPhase.coaching;
        _storyController.add(const ShowMessage('좋아! 구석구석 깨끗하게 닦아보자!',
            duration: Duration(seconds: 3), speaker: Speaker.chikachu));
      }
      _runCoachingRules();
    }

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

    if (activeZone != -1) {
      _ticksOnCurrentZone[activeZone]++;
      for(int i=0; i < kBrushZoneCount; i++) {
        if (i != activeZone) _ticksOnCurrentZone[i] = 0;
      }

      if (_ticksOnCurrentZone[activeZone] > 16) {
        int hintZone = _findLeastBrushedUncompletedZone();
        if (hintZone != -1) {
          _lastCoachMsgAt = now;
          _storyController.add(ShowHintForZone(hintZone, kBrushZoneNames[hintZone]));
          _ticksOnCurrentZone[activeZone] = 0;
          return;
        }
      }
    }

    for (int i = 0; i < kBrushZoneCount; i++) {
      if (i != activeZone && !_completedOnce.contains(i)) {
        _neglectedTicks[i]++;
        if (_neglectedTicks[i] > 30) {
          _lastCoachMsgAt = now;
          _storyController.add(ShowMessage('크하하! ${kBrushZoneNames[i]} 쪽은 안 닦는군! 내 차지다!',
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
    final uncompleted = <int>[];
    for (int i=0; i < kBrushZoneCount; i++) {
      if (!_completedOnce.contains(i)) uncompleted.add(i);
    }
    if (uncompleted.isEmpty) return -1;

    return uncompleted[_rand.nextInt(uncompleted.length)];
  }

  void _emitFinaleOnce(FinaleResult result) {
    if (_finaleEmitted) return;
    _finaleEmitted = true;
    _phase = StoryPhase.finale;
    _storyController.add(FinaleEvent(result));
    _ticker?.cancel();
    _sw.stop();
  }

  void dispose() {
    _ticker?.cancel();
    _sw.stop();
    _storyController.close();
    _progressController.close();
  }
}