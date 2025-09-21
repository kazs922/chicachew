// 📍 lib/features/brush_guide/application/story_director.dart (데모 속도 조절 완료)

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
  final _completedOnce = Set<int>();
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
    final script = [
      {'zoneIndex': 1, 'text': '먼저 앞니 바깥쪽을 닦아볼까?'},
      {'zoneIndex': 0, 'text': '좋아! 이제 왼쪽 바깥쪽을 닦아보자.'},
      {'zoneIndex': 2, 'text': '잘했어! 이번엔 오른쪽 바깥쪽이야.'},
      {'zoneIndex': 10, 'text': '왼쪽 위 씹는 면도 꼼꼼하게!'},
      {'zoneIndex': 9, 'text': '좋아, 반대쪽도 닦아줘!'},
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

      _storyController.add(ShowMessage(
          text,
          duration: const Duration(seconds: 3),
          speaker: Speaker.chikachu
      ));

      await Future.delayed(const Duration(milliseconds: 2000));

      // ✅ [수정] 10초에 걸쳐 1칸씩 차도록 시간 로직 변경
      for (int i = 1; i <= 10; i++) {
        await Future.delayed(const Duration(seconds: 1)); // 1초에 1칸씩
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
        _scores[i] = 0.3 + random.nextDouble() * 0.4;
      }
    }
    if(!_storyController.isClosed) _progressController.add(List.from(_scores));

    _storyController.add(ShowMessage(
        '앗! 시간이 부족해! 서두르자!',
        duration: const Duration(seconds: 3),
        speaker: Speaker.chikachu
    ));
    await Future.delayed(const Duration(seconds: 4));

    if(!_storyController.isClosed) _storyController.add(FinaleEvent(FinaleResult.draw));
  }

  void updateProgress(List<double> p) {
    if (p.length != kBrushZoneCount) return;

    for (int i = 0; i < kBrushZoneCount; i++) {
      final newScore = p[i].clamp(0.0, 1.0);

      if (newScore > _scores[i]) {
        _scores[i] = newScore;

        if (newScore >= 1.0 && !_completedOnce.contains(i)) {
          _completedOnce.add(i);
          _storyController.add(ShowCompleteZone(i, kBrushZoneNames[i]));
          if (_completedOnce.length == kBrushZoneCount) {
            _emitFinaleOnce(FinaleResult.win);
          }
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