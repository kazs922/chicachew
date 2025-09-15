// lib/core/ml/brush_model_engine.dart
// 통합 BrushModelEngine (tflite_flutter 버전 호환 수정)
// - 입력 자동 판별: [1, T, D] 시퀀스 / [1, T, H, W, C] 또는 [1, C, T, H, W] 프레임 시퀀스 / [1, H, W, C] 또는 [1, C, H, W] 이미지
// - 백엔드 폴백: CPU(fromBuffer) → (옵션) GPU/NNAPI/XNN → CPU(fromAsset)
// - 멀티 아웃풋 휴리스틱: 길이 13 우선 → 12~16 → 비스칼라 중 최소 길이
// - 양자화 대응: INT8 in/out 자동 처리 (meta.json 불필요; 런타임에서 직접 읽음)

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

/// 백엔드 스위치
const bool kUseGpu   = false; // GPU delegate 사용 (gradle: tensorflow-lite-gpu 필요)
const bool kUseNnapi = false; // 안드로이드 NNAPI
const bool kUseXnn   = false; // XNNPACK 스레드 지정

class BrushModelEngine {
  BrushModelEngine._();
  static final BrushModelEngine I = BrushModelEngine._();

  Interpreter? _itp;
  bool get isReady => _itp != null;
  String backend = 'none';

  // ── 입력 메타(이미지/시퀀스 자동 판별) ────────────────────────────────
  List<int> _inputShape = const [];
  int _inputRank = 0;

  // 이미지 모드
  bool _isImage = false;
  bool _isNHWC = true;
  int _inH = 224, _inW = 224, _inC = 3;

  // 시퀀스 모드
  bool _isSeq = false;          // 모든 시퀀스 공통 플래그
  bool _isSeqFrames = false;    // 5D 프레임 시퀀스 여부
  // [1, T, D]
  int _seqT = 0, _seqD = 0;
  // [1, T, H, W, C] (NHWC) / [1, C, T, H, W] (NCHW)
  int _seqH = 0, _seqW = 0, _seqC = 0;

  // 외부 조회용
  int  get inputH => _inH;
  int  get inputW => _inW;
  int  get inputC => _inC;
  bool get isNHWC => _isNHWC;

  bool get isSequenceModel    => _isSeq;
  bool get isSeqFramesModel   => _isSeq && _isSeqFrames;

  int  get seqT => _seqT;
  int  get seqD => _seqD; // (5D 모델에는 의미 없음)
  int  get seqH => _seqH;
  int  get seqW => _seqW;
  int  get seqC => _seqC;

  // ── 양자화(quant) 메타 ───────────────────────────────────────────────
  bool _inIsInt8 = false, _outIsInt8 = false;
  double _inScale = 1.0, _outScale = 1.0;
  int _inZero = 0, _outZero = 0;

  /// 모델 로드 (기본: assets/models/brush_zone.tflite)
  Future<void> load({
    String asset = 'assets/models/brush_zone.tflite',
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (_itp != null) return;

    // .tflite 바이트 로드
    final raw = await rootBundle.load(asset);
    final bytes = raw.buffer.asUint8List();
    debugPrint('[BrushEngine] asset ok: $asset (${bytes.length} bytes)');

    // 1) CPU fromBuffer
    if (await _tryLoadBuffer('CPU', bytes, timeout, (o) {})) {
      await _afterLoaded();
      return;
    }

    // 2) (옵션) 다른 백엔드 시도
    if (kUseGpu &&
        await _tryLoadBuffer('GPU', bytes, timeout, (o) {
          if (Platform.isAndroid) o.addDelegate(GpuDelegateV2());
        })) {
      await _afterLoaded();
      return;
    }

    if (kUseNnapi &&
        await _tryLoadBuffer('NNAPI', bytes, timeout, (o) {
          if (Platform.isAndroid) o.useNnApiForAndroid = true;
        })) {
      await _afterLoaded();
      return;
    }

    if (kUseXnn &&
        await _tryLoadBuffer('XNNPACK', bytes, timeout, (o) {
          o.threads = Platform.isAndroid ? 4 : 2;
        })) {
      await _afterLoaded();
      return;
    }

    // 3) 최종 폴백: fromAsset (일부 기기 호환 이슈 대응)
    if (await _tryLoadAsset('CPU(ASSET)', asset, timeout, (o) {})) {
      await _afterLoaded();
      return;
    }

    throw StateError('Failed to create TFLite Interpreter (all backends)');
  }

  // 로드 성공 후 공통 후처리
  Future<void> _afterLoaded() async {
    final itp = _itp!;
    itp.allocateTensors();
    _inspectInput(itp);
    await _inspectQuantization(itp);

    if (_isSeq && _isSeqFrames) {
      debugPrint(
        '[BrushEngine] ready($backend) input=$_inputShape  SEQ5D[NHWC=$_isNHWC T=$_seqT H=$_seqH W=$_seqW C=$_seqC]  '
            'qIn=${_inIsInt8? 'int8' : 'f32'} qOut=${_outIsInt8? 'int8':'f32'}',
      );
    } else if (_isSeq) {
      debugPrint(
        '[BrushEngine] ready($backend) input=$_inputShape  SEQ[T=$_seqT,D=$_seqD]  '
            'qIn=${_inIsInt8? 'int8' : 'f32'} qOut=${_outIsInt8? 'int8':'f32'}',
      );
    } else if (_isImage) {
      debugPrint(
        '[BrushEngine] ready($backend) input=$_inputShape  IMG[NHWC=$_isNHWC C=$_inC H=$_inH W=$_inW]  '
            'qIn=${_inIsInt8? 'int8' : 'f32'} qOut=${_outIsInt8? 'int8':'f32'}',
      );
    }
  }

  Future<bool> _tryLoadBuffer(
      String name,
      Uint8List model,
      Duration timeout,
      void Function(InterpreterOptions) cfg,
      ) async {
    try {
      final opt = InterpreterOptions()..threads = 2;
      cfg(opt);
      final itp = await _withTimeout(
            () => Interpreter.fromBuffer(model, options: opt),
        timeout: timeout,
      );
      _swapIn(itp, name);
      return true;
    } catch (e, st) {
      debugPrint('[BrushEngine] $name failed (buffer): $e\n$st');
      return false;
    }
  }

  Future<bool> _tryLoadAsset(
      String name,
      String asset,
      Duration timeout,
      void Function(InterpreterOptions) cfg,
      ) async {
    try {
      final opt = InterpreterOptions()..threads = 2;
      cfg(opt);
      final itp = await _withTimeout(
            () => Interpreter.fromAsset(asset, options: opt),
        timeout: timeout,
      );
      _swapIn(itp, name);
      return true;
    } catch (e, st) {
      debugPrint('[BrushEngine] $name failed (asset): $e\n$st');
      return false;
    }
  }

  void _swapIn(Interpreter itp, String name) {
    _itp?.close();
    _itp = itp;
    backend = name;
  }

  void _inspectInput(Interpreter itp) {
    final inputs = itp.getInputTensors();
    if (inputs.isEmpty) throw StateError('No input tensors');
    final shape = inputs.first.shape; // [N, ...]
    _inputShape = shape;
    _inputRank = shape.length;

    if (shape.isEmpty || shape[0] != 1) {
      throw StateError('Unsupported input shape (batch!=1): $shape');
    }

    // 시퀀스: [1, T, D]
    if (shape.length == 3) {
      _isSeq = true;
      _isSeqFrames = false;
      _isImage = false;
      _seqT = shape[1];
      _seqD = shape[2];
      debugPrint('[BrushEngine] INPUT seq T=$_seqT D=$_seqD elems=${_seqT * _seqD}');
      return;
    }

    // 프레임 시퀀스: [1, T, H, W, C] (NHWC) 또는 [1, C, T, H, W] (NCHW)
    if (shape.length == 5) {
      _isSeq = true;
      _isSeqFrames = true;
      _isImage = false;
      // NHWC?
      if (shape[4] == 1 || shape[4] == 3 || shape[4] == 4) {
        _isNHWC = true;
        _seqT = shape[1];
        _seqH = shape[2];
        _seqW = shape[3];
        _seqC = shape[4];
      } else if (shape[1] == 1 || shape[1] == 3 || shape[1] == 4) {
        _isNHWC = false; // NCHW
        _seqC = shape[1];
        _seqT = shape[2];
        _seqH = shape[3];
        _seqW = shape[4];
      } else {
        throw StateError('Unsupported 5D layout: $shape');
      }
      debugPrint('[BrushEngine] INPUT seq5D NHWC=$_isNHWC T=$_seqT H=$_seqH W=$_seqW C=$_seqC '
          'elems=${_seqT * _seqH * _seqW * _seqC}');
      return;
    }

    // 이미지: [1, H, W, C] or [1, C, H, W]
    if (shape.length == 4) {
      _isSeq = false;
      _isSeqFrames = false;
      _isImage = true;
      if (shape[3] == 3 || shape[3] == 1) {
        _isNHWC = true;
        _inH = shape[1];
        _inW = shape[2];
        _inC = shape[3];
      } else if (shape[1] == 3 || shape[1] == 1) {
        _isNHWC = false;
        _inH = shape[2];
        _inW = shape[3];
        _inC = shape[1];
      } else {
        throw StateError('Unsupported image layout: $shape');
      }
      debugPrint('[BrushEngine] INPUT image H=$_inH W=$_inW C=$_inC NHWC=$_isNHWC elems=${_inH * _inW * _inC}');
      return;
    }

    throw StateError('Unsupported input rank: $shape');
  }

  // meta.json 없이 인터프리터에서 직접 양자화 파라미터를 읽는다.
  Future<void> _inspectQuantization(Interpreter itp) async {
    final inT = itp.getInputTensors().first;
    final outT = itp.getOutputTensors().first;

    // 버전 호환: enum 비교 대신 문자열 체크
    String _typeStr(dynamic t) => t?.toString()?.toLowerCase() ?? '';
    _inIsInt8  = _typeStr(inT.type).contains('int8');
    _outIsInt8 = _typeStr(outT.type).contains('int8');

    // 동적 접근으로 다양한 버전 지원:
    // - quantizationParameters.scales / zeroPoints (신버전)
    // - params.scale / zeroPoint (구버전)
    double _readScale(dynamic qp) {
      try {
        final s = qp?.scales;
        if (s is List && s.isNotEmpty) return (s.first as num).toDouble();
      } catch (_) {}
      try {
        final s = qp?.scale;
        if (s != null) return (s as num).toDouble();
      } catch (_) {}
      return 1.0;
    }

    int _readZero(dynamic qp) {
      try {
        final z = qp?.zeroPoints;
        if (z is List && z.isNotEmpty) return (z.first as num).toInt();
      } catch (_) {}
      try {
        final z = qp?.zeroPoint;
        if (z != null) return (z as num).toInt();
      } catch (_) {}
      return 0;
    }

    dynamic inQP;
    dynamic outQP;
    try { inQP  = (inT as dynamic).quantizationParameters; } catch (_) {}
    try { outQP = (outT as dynamic).quantizationParameters; } catch (_) {}
    // 구버전 fallback
    inQP  ??= (inT as dynamic).params;
    outQP ??= (outT as dynamic).params;

    _inScale = _readScale(inQP);
    _inZero  = _readZero(inQP);
    _outScale = _readScale(outQP);
    _outZero  = _readZero(outQP);

    debugPrint('[BrushEngine] quant: in(${_inIsInt8 ? "int8" : "f32"}) '
        'scale=$_inScale zero=$_inZero | '
        'out(${_outIsInt8 ? "int8" : "f32"}) '
        'scale=$_outScale zero=$_outZero');
  }

  Future<T> _withTimeout<T>(FutureOr<T> Function() job, {required Duration timeout}) {
    final t = Future<T>.sync(job);
    final lim = Future<T>.delayed(timeout, () => throw TimeoutException('timeout after $timeout'));
    return Future.any([t, lim]);
  }

  // ────────────────────────────────────────────────────────────────────
  // 공용 추론 API
  //  - 입력이 Float32 기준일 때 사용(전처리 완료된 특징/이미지/프레임시퀀스)
  //  - INT8 모델이면 내부에서 양자화하여 넣고, 출력도 디퀀타이즈하여 float로 돌려줌
  List<double> inferFloat32(Float32List inputBuf) {
    final itp = _itp;
    if (itp == null) throw StateError('Interpreter not ready');

    if (_isSeq) {
      // 프레임 시퀀스 (5D)
      if (_isSeqFrames) {
        final expected = _seqT * _seqH * _seqW * _seqC;
        final fixed = _padOrTrimF32(inputBuf, expected);

        final Object packedInput = _inIsInt8
            ? _reshape5DInt8(_quantizeF32ToI8(fixed), nhwc: _isNHWC, n:1, t:_seqT, h:_seqH, w:_seqW, c:_seqC)
            : _reshape5D(fixed, nhwc: _isNHWC, n:1, t:_seqT, h:_seqH, w:_seqW, c:_seqC);

        final out = _runAndPickVector(itp, packedInput);
        return _outIsInt8 ? _dequantizeI8ToF32(out as Int8List) : (out as Float32List).toList(growable: false);
      }

      // (기존) [1,T,D] 시퀀스
      final expected = _seqT * _seqD;
      final fixed = _padOrTrimF32(inputBuf, expected);

      final Object packedInput = _inIsInt8
          ? _reshape3DInt8(_quantizeF32ToI8(fixed), 1, _seqT, _seqD)
          : _reshape3D(fixed, 1, _seqT, _seqD);

      final out = _runAndPickVector(itp, packedInput);
      return _outIsInt8 ? _dequantizeI8ToF32(out as Int8List) : (out as Float32List).toList(growable: false);
    }

    if (_isImage) {
      final expected = (_inC == 1) ? (_inH * _inW) : (_inH * _inW * 3);
      final fixed = _padOrTrimF32(inputBuf, expected);

      final Object packedInput = _inIsInt8
          ? _packImageInputInt8(_quantizeF32ToI8(fixed))
          : _packImageInput(fixed);

      final out = _runAndPickVector(itp, packedInput);
      return _outIsInt8 ? _dequantizeI8ToF32(out as Int8List) : (out as Float32List).toList(growable: false);
    }

    throw StateError('Unknown model input mode');
  }

  /// 원시 바이트 입력(Uint8List)을 안전하게 Float32로 해석해 추론
  List<double> inferBytes(Uint8List bytes) {
    final itp = _itp;
    if (itp == null) { throw StateError('Interpreter not ready'); }

    if (_isSeq) {
      // 프레임 시퀀스 (5D)
      if (_isSeqFrames) {
        final expected = _seqT * _seqH * _seqW * _seqC;
        final f32 = _safeBytesToF32(bytes, targetElems: expected);

        final Object packedInput = _inIsInt8
            ? _reshape5DInt8(_quantizeF32ToI8(f32), nhwc: _isNHWC, n:1, t:_seqT, h:_seqH, w:_seqW, c:_seqC)
            : _reshape5D(f32, nhwc: _isNHWC, n:1, t:_seqT, h:_seqH, w:_seqW, c:_seqC);

        final out = _runAndPickVector(itp, packedInput);
        return _outIsInt8 ? _dequantizeI8ToF32(out as Int8List) : (out as Float32List).toList(growable: false);
      }

      // (기존) [1,T,D] 시퀀스
      final expected = _seqT * _seqD;
      final f32 = _safeBytesToF32(bytes, targetElems: expected);

      final Object packedInput = _inIsInt8
          ? _reshape3DInt8(_quantizeF32ToI8(f32), 1, _seqT, _seqD)
          : _reshape3D(f32, 1, _seqT, _seqD);

      final out = _runAndPickVector(itp, packedInput);
      return _outIsInt8 ? _dequantizeI8ToF32(out as Int8List) : (out as Float32List).toList(growable: false);
    }

    if (_isImage) {
      final expected = (_inC == 1) ? (_inH * _inW) : (_inH * _inW * 3);
      final f32 = _safeBytesToF32(bytes, targetElems: expected);

      final Object packedInput = _inIsInt8
          ? _packImageInputInt8(_quantizeF32ToI8(f32))
          : _packImageInput(f32);

      final out = _runAndPickVector(itp, packedInput);
      return _outIsInt8 ? _dequantizeI8ToF32(out as Int8List) : (out as Float32List).toList(growable: false);
    }

    throw StateError('Unknown model input mode');
  }

  // ── 실행 + 멀티 아웃풋 중 '벡터'를 하나 골라서 1D(Int8/Float32)로 반환 ──
  Object _runAndPickVector(Interpreter itp, Object packedInput) {
    final outs = itp.getOutputTensors();

    // 단일 출력
    if (outs.length == 1) {
      final t = outs.first;
      final outObj = _allocZeroForTensor(t);   // shape [1,13]이면 [[..]] 생성
      itp.run(packedInput, outObj);
      return _firstVector1D(outObj);           // → 길이 13 벡터로 반환
    }

    // 다중 출력: 각 텐서 모양대로 그릇 만들고 실행
    final outObjs = <Object>[];
    for (final t in outs) {
      outObjs.add(_allocZeroForTensor(t));
    }

    try {
      final inputs = <Object>[packedInput];
      final outputs = <int, Object>{};
      for (int i = 0; i < outObjs.length; i++) {
        outputs[i] = outObjs[i];
      }
      itp.runForMultipleInputs(inputs, outputs);
    } catch (_) {
      // 구버전 fallback: 첫 출력만 run
      itp.run(packedInput, outObjs.first);
    }

    // 각 출력에서 1D 벡터만 추출
    final vecs = outObjs.map(_firstVector1D).toList();

    // 휴리스틱: ① 길이 13 → ② 12~16 → ③ 비스칼라 중 최소 길이
    Object? pick;
    for (final v in vecs) { if (_vecLen(v) == 13) { pick = v; break; } }
    if (pick == null) {
      for (final len in [12, 13, 14, 15, 16]) {
        final hit = vecs.firstWhere((v) => _vecLen(v) == len, orElse: () => []);
        if (_vecLen(hit) == len) { pick = hit; break; }
      }
    }
    if (pick == null) {
      final nonScalar = vecs.where((v) => _vecLen(v) > 1).toList()
        ..sort((a,b) => _vecLen(a).compareTo(_vecLen(b)));
      pick = nonScalar.isNotEmpty ? nonScalar.first : vecs.first;
    }
    return pick!;
  }

  // ── 출력 텐서 shape에 맞는 '0 버퍼' 생성 (최대 rank=4 지원) ────────────
  Object _allocZeroForTensor(Tensor t) {
    final shape = t.shape;
    final isInt8 = t.type.toString().toLowerCase().contains('int8');

    Object make1(int n) => isInt8 ? Int8List(n) : Float32List(n);

    if (shape.length == 1) return make1(shape[0]);
    if (shape.length == 2) return List.generate(shape[0], (_) => make1(shape[1]));
    if (shape.length == 3) {
      return List.generate(shape[0], (_) =>
          List.generate(shape[1], (_) => make1(shape[2])));
    }
    if (shape.length == 4) {
      return List.generate(shape[0], (_) =>
          List.generate(shape[1], (_) =>
              List.generate(shape[2], (_) => make1(shape[3]))));
    }
    // fallback: 평탄화
    final size = shape.fold<int>(1, (a,b) => a*b);
    return make1(size);
  }

  // 중첩 구조에서 '첫 번째 1D 벡터'만 뽑기 (e.g., [1,13] → 길이 13)
  Object _firstVector1D(Object obj) {
    var cur = obj;
    while (cur is List && cur.isNotEmpty) {
      final first = cur.first;
      if (first is List || first is Float32List || first is Int8List) {
        cur = first;
      } else {
        break;
      }
    }
    if (cur is Float32List || cur is Int8List) return cur;
    if (cur is List) {
      // 숫자 리스트면 float으로 복사
      final l = cur.cast<num>().map((e) => e.toDouble()).toList();
      return Float32List.fromList(l);
    }
    return Float32List(0);
  }

  // 벡터 길이 구하기 (형에 상관없이)
  int _vecLen(Object v) {
    if (v is Float32List) return v.length;
    if (v is Int8List) return v.length;
    if (v is List) return v.length;
    return 0;
  }

  // ── 양자화 유틸 ──────────────────────────────────────────────────────
  Int8List _quantizeF32ToI8(Float32List x) {
    final out = Int8List(x.length);
    final s = (_inScale == 0.0) ? 1.0 : _inScale; // scale=0 방지
    for (int i = 0; i < x.length; i++) {
      final v = (x[i] / s + _inZero).round().clamp(-128, 127);
      out[i] = v;
    }
    return out;
  }

  List<double> _dequantizeI8ToF32(Int8List q) {
    final s = (_outScale == 0.0) ? 1.0 : _outScale;
    return List<double>.generate(q.length, (i) => (q[i] - _outZero) * s, growable: false);
    // ※ argmax만 필요하면 디퀀타이즈 전/후 동일
  }

  // ── 입력 패킹(이미지) ────────────────────────────────────────────────
  Object _packImageInput(Float32List src) {
    if (_inC == 1) {
      // GRAY: [1, H, W, 1] 또는 [1, 1, H, W]로 해석됨. 평탄화로 충분.
      return Float32List.fromList(src);
    }
    if (_isNHWC) {
      // src는 채널별 평면이 연속으로 있다고 가정(R, G, B 각각 H*W)
      final hwc = Float32List(_inH * _inW * 3);
      int idx = 0;
      for (int h = 0; h < _inH; h++) {
        for (int w = 0; w < _inW; w++) {
          hwc[idx++] = src[(0 * _inH + h) * _inW + w];
          hwc[idx++] = src[(1 * _inH + h) * _inW + w];
          hwc[idx++] = src[(2 * _inH + h) * _inW + w];
        }
      }
      return hwc;
    } else {
      // NCHW 기대: CHW 그대로
      return Float32List.fromList(src);
    }
  }

  Object _packImageInputInt8(Int8List src) {
    if (_inC == 1) return Int8List.fromList(src);
    if (_isNHWC) {
      final hwc = Int8List(_inH * _inW * 3);
      int idx = 0;
      for (int h = 0; h < _inH; h++) {
        for (int w = 0; w < _inW; w++) {
          hwc[idx++] = src[(0 * _inH + h) * _inW + w];
          hwc[idx++] = src[(1 * _inH + h) * _inW + w];
          hwc[idx++] = src[(2 * _inH + h) * _inW + w];
        }
      }
      return hwc;
    } else {
      return Int8List.fromList(src);
    }
  }

  // ── 보조: 1D → 3D nested List ───────────────────────────────────────
  List<List<List<double>>> _reshape3D(Float32List flat, int n, int t, int d) {
    if (flat.length != n * t * d) {
      throw ArgumentError('reshape3D length mismatch: ${flat.length} != ${n * t * d}');
    }
    final out = List.generate(n, (_) => List.generate(t, (_) => List.filled(d, 0.0)));
    int idx = 0;
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < t; j++) {
        for (int k = 0; k < d; k++) {
          out[i][j][k] = flat[idx++];
        }
      }
    }
    return out;
  }

  List<List<List<int>>> _reshape3DInt8(Int8List flat, int n, int t, int d) {
    if (flat.length != n * t * d) {
      throw ArgumentError('reshape3DInt8 length mismatch: ${flat.length} != ${n * t * d}');
    }
    final out = List.generate(n, (_) => List.generate(t, (_) => List.filled(d, 0)));
    int idx = 0;
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < t; j++) {
        for (int k = 0; k < d; k++) {
          out[i][j][k] = flat[idx++];
        }
      }
    }
    return out;
  }

  // ── 보조: 1D → 5D nested List (프레임 시퀀스) ───────────────────────
  /// NHWC: [1, T, H, W, C]  /  NCHW: [1, C, T, H, W]
  Object _reshape5D(Float32List flat, {required bool nhwc, required int n, required int t, required int h, required int w, required int c}) {
    if (nhwc) {
      final need = n * t * h * w * c;
      if (flat.length != need) {
        throw ArgumentError('reshape5D(NHWC) length mismatch: ${flat.length} != $need');
      }
      return List.generate(n, (_) =>
          List.generate(t, (_) =>
              List.generate(h, (_) =>
                  List.generate(w, (_) => Float32List(c)))));
      // 위에서 그릇만 만들고 값 채우기
    } else {
      final need = n * c * t * h * w;
      if (flat.length != need) {
        throw ArgumentError('reshape5D(NCHW) length mismatch: ${flat.length} != $need');
      }
      return List.generate(n, (_) =>
          List.generate(c, (_) =>
              List.generate(t, (_) =>
                  List.generate(h, (_) => Float32List(w)))));
    }
  }

  Object _reshape5DInt8(Int8List flat, {required bool nhwc, required int n, required int t, required int h, required int w, required int c}) {
    if (nhwc) {
      final need = n * t * h * w * c;
      if (flat.length != need) {
        throw ArgumentError('reshape5DInt8(NHWC) length mismatch: ${flat.length} != $need');
      }
      // [1][T][H][W][C]
      int idx = 0;
      final out = List.generate(n, (_) =>
          List.generate(t, (_) =>
              List.generate(h, (_) =>
                  List.generate(w, (_) {
                    final row = Int8List(c);
                    for (int cc = 0; cc < c; cc++) row[cc] = flat[idx++];
                    return row;
                  }))));
      return out;
    } else {
      final need = n * c * t * h * w;
      if (flat.length != need) {
        throw ArgumentError('reshape5DInt8(NCHW) length mismatch: ${flat.length} != $need');
      }
      // [1][C][T][H][W]
      int idx = 0;
      final out = List.generate(n, (_) =>
          List.generate(c, (_) =>
              List.generate(t, (_) =>
                  List.generate(h, (_) {
                    final row = Int8List(w);
                    for (int x = 0; x < w; x++) row[x] = flat[idx++];
                    return row;
                  }))));
      return out;
    }
  }

  // 위 Float32 버전(값 채워 넣기)
  Object fillReshaped5D(Float32List flat, {required bool nhwc, required int n, required int t, required int h, required int w, required int c}) {
    if (nhwc) {
      final need = n * t * h * w * c;
      if (flat.length != need) {
        throw ArgumentError('fillReshaped5D(NHWC) length mismatch: ${flat.length} != $need');
      }
      int idx = 0;
      final out = List.generate(n, (_) =>
          List.generate(t, (_) =>
              List.generate(h, (_) =>
                  List.generate(w, (_) {
                    final row = Float32List(c);
                    for (int cc = 0; cc < c; cc++) row[cc] = flat[idx++];
                    return row;
                  }))));
      return out;
    } else {
      final need = n * c * t * h * w;
      if (flat.length != need) {
        throw ArgumentError('fillReshaped5D(NCHW) length mismatch: ${flat.length} != $need');
      }
      int idx = 0;
      final out = List.generate(n, (_) =>
          List.generate(c, (_) =>
              List.generate(t, (_) =>
                  List.generate(h, (_) {
                    final row = Float32List(w);
                    for (int x = 0; x < w; x++) row[x] = flat[idx++];
                    return row;
                  }))));
      return out;
    }
  }

  /// 길이 보정 유틸: 요소 수 기준 pad/trim
  Float32List _padOrTrimF32(Float32List x, int target) {
    if (x.length == target) return x;
    final out = Float32List(target);
    final n = x.length < target ? x.length : target;
    for (int i = 0; i < n; i++) { out[i] = x[i]; }
    if (x.length != target) {
      debugPrint('[BrushEngine] pad/trim input: got=${x.length}, want=$target');
    }
    return out;
  }

  /// Uint8List → Float32List 안전 변환
  Float32List _safeBytesToF32(Uint8List bytes, {required int targetElems}) {
    Uint8List u = bytes;
    if (u.offsetInBytes % 4 != 0) {
      final aligned = Uint8List(u.lengthInBytes);
      aligned.setAll(0, u);
      u = aligned; // offsetInBytes = 0 보장
    }
    int lenBytes = u.lengthInBytes - (u.lengthInBytes % 4);
    if (lenBytes != u.lengthInBytes) {
      debugPrint('[BrushEngine] trim ${u.lengthInBytes - lenBytes} trailing bytes (not %4)');
    }
    final start = u.offsetInBytes;
    final f32 = u.buffer.asFloat32List(start, lenBytes ~/ 4);
    return _padOrTrimF32(f32, targetElems);
  }

  void close() {
    _itp?.close();
    _itp = null;
    backend = 'none';
  }
}
