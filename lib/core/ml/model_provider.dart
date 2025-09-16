// 📍 lib/core/ml/model_provider.dart (새로운 파일을 생성하고 아래 코드를 붙여넣으세요)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'brush_model_engine.dart';
import 'brush_predictor.dart';

/// 앱 전체에서 BrushPredictor 인스턴스를 제공하는 프로바이더입니다.
/// FutureProvider를 사용하면 앱 시작 시 단 한 번만 모델을 로드하고 초기화합니다.
final brushPredictorProvider = FutureProvider<BrushPredictor>((ref) async {
  // 1. TFLite 모델 엔진을 로드합니다. (기존 _loadModel 함수의 로직)
  await BrushModelEngine.I.load();

  // 2. 모델 예측기(라벨 로드 등)를 초기화합니다.
  final predictor = BrushPredictor();
  await predictor.init();

  // 3. 초기화가 완료된 predictor 인스턴스를 반환합니다.
  // 이제 앱의 다른 모든 곳에서는 이 인스턴스를 공유해서 사용하게 됩니다.
  return predictor;
});