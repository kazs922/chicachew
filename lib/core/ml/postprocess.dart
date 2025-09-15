import 'dart:math' as math;

/// 단일 존 확률/점수
class ZoneProb {
  final int index;
  final double prob; // softmax 후 확률 혹은 점수(logit)
  const ZoneProb(this.index, this.prob);
}

/// ⚠️ 모델 학습 라벨 순서와 정확히 일치해야 합니다 (길이 13).
const List<String> kZoneLabels = <String>[
  '오른쪽-구개측','오른쪽-설측','오른쪽-아래-씹는면',
  '오른쪽-위-씹는면','오른쪽-협측','왼쪽-구개측',
  '왼쪽-설측','왼쪽-아래-씹는면','왼쪽-위-씹는면',
  '왼쪽-협측','중앙-구개측','중앙-설측',
  '중앙-협측',
];

/// 인덱스로 라벨을 안전하게 가져오기
String zoneLabel(int index) {
  if (index >= 0 && index < kZoneLabels.length) return kZoneLabels[index];
  return 'unknown($index)';
}

/// 가장 큰 값(top-1) 반환
ZoneProb top1(List<double> v) {
  if (v.isEmpty) return const ZoneProb(0, 0.0);
  var idx = 0;
  var mv = v[0];
  for (var i = 1; i < v.length; i++) {
    final vi = v[i];
    if (vi > mv) {
      mv = vi;
      idx = i;
    }
  }
  return ZoneProb(idx, mv);
}

/// 수치적으로 안정적인 softmax (log-sum-exp)
List<double> softmax(List<double> x) {
  if (x.isEmpty) return const <double>[];
  final m = x.reduce((a, b) => a > b ? a : b);
  var sum = 0.0;
  final exps = List<double>.filled(x.length, 0.0);
  for (var i = 0; i < x.length; i++) {
    final e = math.exp(x[i] - m);
    exps[i] = e;
    sum += e;
  }
  if (sum <= 0.0 || !sum.isFinite) {
    // 비정상 값 방어: 균등분포로 대체
    final p = 1.0 / x.length;
    return List<double>.filled(x.length, p);
  }
  for (var i = 0; i < exps.length; i++) {
    exps[i] = exps[i] / sum;
  }
  return exps;
}

/// logits(마지막에 softmax가 없는 출력)에서 top-1 확률 구하기
ZoneProb top1FromLogits(List<double> logits) {
  final probs = softmax(logits);
  return top1(probs);
}

/// ─────────────────────────────────────────────────────────────────
/// LSTM/GRU 호환: 다양한 출력 형태를 [C] 벡터로 축소
/// raw 예시:
/// - List<double>            : [C] (이미 클래스 벡터)
/// - List<num> / Float32List : [C] (타입 혼합 대응)
/// - List<List<double>>      : [T, C] (시퀀스 전체)
/// - List<List<List>>        : [1, T, C] 또는 [B, T, C]에서 B=1
/// mode: 'last' | 'mean' | 'max'
/// ─────────────────────────────────────────────────────────────────
List<double> collapseToLogits(dynamic raw, {String mode = 'last'}) {
  // [C] : 숫자 리스트를 double로 강제 변환
  if (raw is List && raw.isNotEmpty && raw.first is num) {
    return List<double>.from(raw.map((e) => (e as num).toDouble()));
  }

  // [T, C]
  if (raw is List && raw.isNotEmpty && raw.first is List) {
    final first = raw.first as List?;
    if (first != null && first.isNotEmpty && first.first is num) {
      final seq = raw.cast<List>(); // List<List<num>>
      // 'last' : 마지막 스텝
      if (mode == 'last') {
        final last = seq.last.cast<num>();
        return List<double>.from(last.map((e) => e.toDouble()));
      }
      // 'mean' : 시간 평균
      if (mode == 'mean') {
        final c = (seq.first as List).length;
        final out = List<double>.filled(c, 0.0);
        for (final stepDyn in seq) {
          final step = stepDyn.cast<num>();
          for (var i = 0; i < c; i++) out[i] += step[i].toDouble();
        }
        for (var i = 0; i < c; i++) out[i] /= seq.length;
        return out;
      }
      // 'max' : 시간 차원 최대
      if (mode == 'max') {
        final c = (seq.first as List).length;
        final out = List<double>.filled(c, double.negativeInfinity);
        for (final stepDyn in seq) {
          final step = stepDyn.cast<num>();
          for (var i = 0; i < c; i++) {
            final v = step[i].toDouble();
            if (v > out[i]) out[i] = v;
          }
        }
        return out;
      }
    }

    // [1, T, C] 또는 [B, T, C] (B==1 가정) → 첫 배치 꺼내 재귀
    if (first != null && first.isNotEmpty && first.first is List) {
      final level1 = raw.first; // [T, C]
      return collapseToLogits(level1, mode: mode);
    }
  }

  throw StateError('예상치 못한 출력 형태: ${raw.runtimeType}');
}

/// 벡터가 확률처럼 보이는지(0~1, 합≈1) 점검
bool _looksLikeProb(List<double> v) {
  if (v.isEmpty) return false;
  // 값 범위 체크
  for (final x in v) {
    if (x.isNaN || !x.isFinite) return false;
    if (x < -1e-6 || x > 1.0 + 1e-6) return false;
  }
  // 합이 1에 가깝다면 확률로 간주
  final s = v.fold<double>(0.0, (a, b) => a + b);
  return (s > 0.98 && s < 1.02);
}

/// 확률 벡터로 정규화:
/// - 이미 확률처럼 보이면(합≈1) 정규화해서 반환
/// - 아니면 softmax(logits) 적용
List<double> collapseToProbs(dynamic raw, {String mode = 'last'}) {
  final vec = collapseToLogits(raw, mode: mode);
  if (_looksLikeProb(vec)) {
    final sum = vec.fold<double>(0.0, (a, b) => a + b);
    if (sum <= 0.0 || !sum.isFinite) {
      final p = 1.0 / vec.length;
      return List<double>.filled(vec.length, p);
    }
    return vec.map((e) => e / sum).toList(growable: false);
  }
  return softmax(vec);
}

/// 어떤 형태의 모델 출력이 와도 Top-1 반환:
/// - CNN+GRU/LSTM의 [C], [T, C], [1, T, C] 모두 지원
/// - mode: 'last'|'mean'|'max' (시퀀스 축소 전략)
ZoneProb top1FromAnyOutput(dynamic raw, {String mode = 'last'}) {
  final probs = collapseToProbs(raw, mode: mode);
  return top1(probs);
}

/// 지수이동평균(EMA) 기반 존 스무딩으로 튐 방지
class ZoneSmoother {
  /// EMA 계수(0~1). 클수록 반응 빠르고, 작을수록 안정적.
  final double alpha;

  /// 현재 존으로 전환을 허용하는 신뢰도 임계값.
  final double switchThreshold;

  int? _z;          // 현재 존
  double _conf = 0; // 현재 존의 누적 신뢰도

  ZoneSmoother({
    this.alpha = 0.25,
    this.switchThreshold = 0.20,
  });

  /// 새 예측을 반영하고 스무딩된 결과를 반환
  ZoneProb push(ZoneProb p) {
    if (_z == null) {
      _z = p.index;
      _conf = p.prob;
      return ZoneProb(_z!, _conf);
    }
    if (p.index == _z) {
      // 같은 존이면 신뢰도를 올려줌
      _conf = _conf * (1 - alpha) + p.prob * alpha;
    } else {
      // 다른 존이 나오면 현재 신뢰도 서서히 감소
      _conf = _conf * (1 - alpha);
      // 충분히 낮아지면 새 존으로 스위치
      if (_conf < switchThreshold) {
        _z = p.index;
        _conf = p.prob * 0.5; // 전환 직후 약하게 시작
      }
    }
    return ZoneProb(_z!, _conf.clamp(0.0, 1.0));
  }

  /// 현재 상태 초기화
  void reset() {
    _z = null;
    _conf = 0.0;
  }
}
