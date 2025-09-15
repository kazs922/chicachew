import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:chicachew/core/ml/brush_model_engine.dart';

class InferenceResult {
  final int index;
  final String label;
  final double prob;
  final List<double> probs;
  InferenceResult(this.index, this.label, this.prob, this.probs);
}

class BrushPredictor {
  final _eng = BrushModelEngine.I;
  List<String> _labels = [];

  bool get isReady => _eng.isReady && _labels.isNotEmpty;

  Future<void> init() async {
    await _eng.load(); // 엔진 준비
    final s = await rootBundle.loadString('assets/brush_zone.txt');
    _labels = s.split('\n').map((e)=>e.trim()).where((e)=>e.isNotEmpty).toList();
  }

  /// window: [T][D] (예: [30][450])
  InferenceResult inferFromWindow(List<List<double>> window) {
    final t = window.length;
    final d = window.isNotEmpty ? window[0].length : 0;
    final flat = Float32List(t*d);
    var k = 0;
    for (final row in window) {
      for (final v in row) flat[k++] = v.toDouble();
    }
    final logits = _eng.inferFloat32(flat);   // 엔진 호출
    final probs  = _softmax(logits);
    final idx    = _argmax(probs);
    final label  = (idx >= 0 && idx < _labels.length) ? _labels[idx] : 'class_$idx';
    return InferenceResult(idx, label, probs[idx], probs);
  }

  // -------- utils --------
  List<double> _softmax(List<double> v) {
    if (v.isEmpty) return const [];
    final m = v.reduce(math.max);
    final exps = v.map((e) => math.exp(e - m)).toList();
    final s = exps.fold<double>(0.0, (a,b) => a+b);
    return s == 0 ? List.filled(v.length, 1.0/v.length) : exps.map((e)=>e/s).toList();
  }
  int _argmax(List<double> v) {
    var idx = 0; var mv = -1e18;
    for (var i=0;i<v.length;i++) { if (v[i] > mv) { mv = v[i]; idx = i; } }
    return idx;
  }
}
