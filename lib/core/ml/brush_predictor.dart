// 📍 lib/core/ml/brush_predictor.dart (파일 전체를 이 코드로 교체하세요)

import 'dart:typed_data';

import 'package:chicachew/core/ml/brush_model_engine.dart';
import 'package:chicachew/core/ml/postprocess.dart';
import 'package:flutter/services.dart' show rootBundle;

class InferenceResult {
  final int index;
  final String label;
  final List<double> probs;
  const InferenceResult(
      {required this.index, required this.label, required this.probs});
}

class BrushPredictor {
  bool isReady = false;
  final List<String> _labels = [];

  Future<void> init({String labelsPath = 'assets/brush_zone.txt'}) async {
    final content = await rootBundle.loadString(labelsPath);
    _labels.addAll(
        content.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty));
    isReady = true;
  }

  InferenceResult inferFromWindow(List<List<double>> window) {
    final flat = window.expand((f) => f).toList();
    final buf = Float32List.fromList(flat);

    // ✅ 존재하지 않는 'infer' 대신, 실제 존재하는 'inferFloat32' 함수를 호출하도록 최종 수정했습니다.
    final logits = BrushModelEngine.I.inferFloat32(buf);

    final probs = softmax(logits);
    final top = top1(probs);

    return InferenceResult(
      index: top.index,
      label: _labels.elementAtOrNull(top.index) ?? '?',
      probs: probs,
    );
  }
}