// 📍 lib/features/brush_guide/application/story_director.dart (데모 속도/분포 + 실전 코칭 멘트)

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

  /// 한 구역을 가득 채우는 데 필요한 '칸' 수(=초). 10이면 1초당 1칸 × 10초 = 100%
  final int ticksTargetPerZone;

  /// 실전 총 러닝타임(데모에는 직접적 영향 없음)
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
  final _completedOnce = <int>{};

  // ── 코칭 멘트 관련 상태
  DateTime _lastCoachMsgAt = DateTime.fromMillisecondsSinceEpoch(0);
  final Duration coachCooldown = const Duration(seconds: 8);
  final Map<int, int> _lastBucketByZone = {}; // zoneIndex -> last bucket (-1:없음)

  // 진행도 버킷별 멘트(랜덤 선택)
  final List<String> _msgsLow = const [
    '{zone}, 아직 부족해! 이 부위를 좀 더 닦아 볼까?',
    '{zone}, 구석구석 더 꼼꼼하게!',
  ];
  final List<String> _msgsMid = const [
    '{zone} 잘하고 있어! 조금만 더 해볼까?',
    '{zone} 좋아! 지금처럼만 계속!',
  ];
  final List<String> _msgsHigh = const [
    '{zone} 정말 잘했어! 다른 부위를 닦아볼까?',
    '{zone} 반짝반짝! 다음으로 넘어가자!',
  ];

  bool _finaleEmitted = false;

  void start() {
    if (_ticker != null) return;
    _phase = StoryPhase.intro;
    _sw..reset()..start();

    _storyController.add(const ShowMessage(
      '왔구나! 치카치카 용사!',
      duration: Duration(seconds: 4),
      speaker: Speaker.chikachu,
    ));

    Future.delayed(const Duration(seconds: 4), () {
      if (_phase == StoryPhase.intro && !_finaleEmitted) {
        _storyController.add(const ShowMessage(
          '이 몸의 캐비티 공격을 막아낼 수 있을까?',
          duration: Duration(seconds: 4),
          speaker: Speaker.cavitymon,
        ));
      }
    });

    // 실전용 틱커(보스 HUD 등만 갱신)
    _ticker = Timer.periodic(const Duration(milliseconds: 1000), (_) => _onTick());
  }

  /// ─────────────────────────────────────────────────────────────────
  /// 데모 시퀀스: 1초당 1칸씩 채움
  /// - 7개 구역: 100%까지 차오름
  /// - 2개 구역: 50%에서 멈춤
  /// - 나머지: 0.2~0.4 사이 랜덤 값
  /// - 구역별로 대사를 출력하면서 진행
  /// ─────────────────────────────────────────────────────────────────
  Future<void> startDemoSequence() async {
    // 친절한 첫 멘트
    _storyController.add(const ShowMessage(
      '치카치카 용사! 나와 함께 캐비티몬을 물리치자!',
      duration: Duration(seconds: 4),
      speaker: Speaker.chikachu,
    ));
    await Future.delayed(const Duration(seconds: 4));
    if (_storyController.isClosed) return;

    // 1) 구역 샘플링: 7개 full, 2개 half
    final all = List<int>.generate(kBrushZoneCount, (i) => i)..shuffle(_rand);
    final fullZones = all.take(7).toList();
    final halfZones = all.skip(7).take(2).toList();
    final restZones = all.skip(9).toList();

    // 2) FULL 구역들: 100%까지 채우며 가끔 멘트/완료 이벤트
    for (final zi in fullZones) {
      if (_storyController.isClosed) return;

      final name = (zi >= 0 && zi < kBrushZoneNames.length) ? kBrushZoneNames[zi] : 'Zone ${zi + 1}';
      _storyController.add(ShowMessage(
        '$name부터 꼼꼼하게!',
        duration: const Duration(seconds: 3),
        speaker: Speaker.chikachu,
      ));
      await Future.delayed(const Duration(milliseconds: 600));

      await _fillZoneTo(zi, 1.0); // 1초 × ticksTargetPerZone

      // 완료 표시
      _completedOnce.add(zi);
      _storyController.add(ShowCompleteZone(zi, name));
      await Future.delayed(const Duration(milliseconds: 400));
    }

    // 3) HALF 구역들: 50%까지만 채우고 힌트 멘트
    for (final zi in halfZones) {
      if (_storyController.isClosed) return;

      final name = (zi >= 0 && zi < kBrushZoneNames.length) ? kBrushZoneNames[zi] : 'Zone ${zi + 1}';
      _storyController.add(ShowMessage(
        '$name 조금만 더! 절반까지 가보자!',
        duration: const Duration(seconds: 2),
        speaker: Speaker.chikachu,
      ));
      await Future.delayed(const Duration(milliseconds: 400));

      await _fillZoneTo(zi, 0.5);

      _storyController.add(ShowHintForZone(zi, name, duration: const Duration(seconds: 2)));
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // 4) 나머지 구역: 살짝만 채워 넣기(0.2~0.4)
    for (final zi in restZones) {
      _scores[zi] = 0.2 + _rand.nextDouble() * 0.2;
    }
    _emitProgress();

    // 5) 마무리 멘트 & 피날레(무승부)
    _storyController.add(const ShowMessage(
      '앗! 시간이 부족해! 서두르자!',
      duration: Duration(seconds: 3),
      speaker: Speaker.chikachu,
    ));
    await Future.delayed(const Duration(seconds: 3));
    if (_storyController.isClosed) return;

    _storyController.add(const ShowMessage(
      '그래도 잘했어! 결과를 확인해볼까?',
      duration: Duration(seconds: 2),
      speaker: Speaker.narrator,
    ));
    await Future.delayed(const Duration(seconds: 2));
    if (_storyController.isClosed) return;

    _storyController.add(const FinaleEvent(FinaleResult.draw));
  }

  /// 구역을 target(0.0~1.0)까지 '1초당 1칸' 규칙으로 채움
  Future<void> _fillZoneTo(int zoneIndex, double target01) async {
    final steps = max(1, (ticksTargetPerZone * target01).round());
    for (int i = 1; i <= steps; i++) {
      if (_storyController.isClosed) return;
      _scores[zoneIndex] = (i / ticksTargetPerZone).clamp(0.0, target01);
      _emitProgress();
      await Future.delayed(const Duration(seconds: 1)); // 1초에 1칸
    }
  }

  void _emitProgress() {
    if (!_progressController.isClosed) {
      _progressController.add(List<double>.from(_scores));
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // 실전 진행 업데이트(모델/엔진에서 들어오는 진행률 반영)
  void updateProgress(List<double> p) {
    if (p.length != kBrushZoneCount) return;

    for (int i = 0; i < kBrushZoneCount; i++) {
      final newScore = p[i].clamp(0.0, 1.0);
      if (newScore > _scores[i]) {
        _scores[i] = newScore;

        // ✅ 진행도 버킷이 상승할 때 코칭 멘트 출력
        _maybeCoach(i, newScore);

        if (newScore >= 1.0 && !_completedOnce.contains(i)) {
          _completedOnce.add(i);
          final name = (i >= 0 && i < kBrushZoneNames.length) ? kBrushZoneNames[i] : 'Zone ${i + 1}';
          _storyController.add(ShowCompleteZone(i, name));
          if (_completedOnce.length == kBrushZoneCount) {
            _emitFinaleOnce(FinaleResult.win);
          }
          return;
        }
      }
    }
  }

  // ── 버킷 계산(0:0~49, 1:50~99, 2:100)
  int _bucketFor(double v) {
    if (v >= 1.0) return 2;
    if (v >= 0.5) return 1;
    return 0;
  }

  void _maybeCoach(int zoneIndex, double v) {
    if (_finaleEmitted) return;

    // 쿨다운 체크
    final now = DateTime.now();
    if (now.difference(_lastCoachMsgAt) < coachCooldown) return;

    final b = _bucketFor(v);
    final prev = _lastBucketByZone[zoneIndex] ?? -1;

    // 같은/낮은 버킷이면 멘트 생략(상승할 때만)
    if (b <= prev) return;
    _lastBucketByZone[zoneIndex] = b;

    final zone = (zoneIndex >= 0 && zoneIndex < kBrushZoneNames.length)
        ? kBrushZoneNames[zoneIndex]
        : '해당 부위';

    String pick(List<String> list) =>
        list[_rand.nextInt(list.length)].replaceAll('{zone}', zone);

    final text = switch (b) {
      0 => pick(_msgsLow),
      1 => pick(_msgsMid),
      _ => pick(_msgsHigh),
    };

    _storyController.add(ShowMessage(
      text,
      duration: const Duration(seconds: 3),
      speaker: Speaker.chikachu,
    ));
    _lastCoachMsgAt = now;
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
        _storyController.add(const ShowMessage(
          '좋아! 구석구석 깨끗하게 닦아보자!',
          duration: Duration(seconds: 3),
          speaker: Speaker.chikachu,
        ));
      }
    } else {
      if (_phase != StoryPhase.finale) {
        _phase = StoryPhase.finale;
        final avg = _scores.reduce((a, b) => a + b) / _scores.length;
        if (avg >= 0.9) {
          _emitFinaleOnce(FinaleResult.win);
        } else if (avg >= 0.6) {
          _emitFinaleOnce(FinaleResult.draw);
        } else {
          _emitFinaleOnce(FinaleResult.lose);
        }
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
