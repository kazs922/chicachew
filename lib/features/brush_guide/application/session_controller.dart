import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:chicachew/core/ml/postprocess.dart';

/// 세션 상태 스냅샷
class BrushSessionState {
  final int secondsLeft;        // 남은 시간(초)
  final List<double> zone;      // 13구역 점수(0.0 ~ 1.0)
  final bool isRunning;
  const BrushSessionState({
    required this.secondsLeft,
    required this.zone,
    required this.isRunning,
  });
}

/// 타이머/점수 상태 관리
class SessionController extends ChangeNotifier {
  final int totalSec;
  late int _left;
  final _scores = List<double>.filled(13, 0.0);
  Timer? _timer;
  bool _running = false;

  SessionController({this.totalSec = 210}) {
    _left = totalSec;
  }

  BrushSessionState get state => BrushSessionState(
    secondsLeft: _left,
    zone: List.unmodifiable(_scores),
    isRunning: _running,
  );

  void start() {
    if (_running) return;
    _running = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _left = _left > 0 ? _left - 1 : 0;
      if (_left == 0) stop();
      notifyListeners();
    });
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  /// 특정 구역 점수 증가 (0.0 ~ 1.0)
  void addScore(int zoneIndex, double delta) {
    if (!_running || zoneIndex < 0 || zoneIndex >= _scores.length) return;
    _scores[zoneIndex] = (_scores[zoneIndex] + delta).clamp(0.0, 1.0);
    notifyListeners();
  }

  /// 특정 구역 점수를 0.1씩 증가 (10단계 → 최종 1.0)
  void incrementZone(int index) {
    if (!_running || index < 0 || index >= _scores.length) return;
    if (_scores[index] < 1.0) {
      _scores[index] = (_scores[index] + 0.1).clamp(0.0, 1.0);
      notifyListeners();
    }
  }
}
