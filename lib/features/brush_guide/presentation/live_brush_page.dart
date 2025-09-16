// 📍 lib/features/brush_guide/presentation/live_brush_page.dart (파일 전체를 복사해서 붙여넣으세요)

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // (+) Riverpod import 추가
import 'package:go_router/go_router.dart';

// 앱 내부 의존
import 'package:chicachew/core/ml/brush_model_engine.dart';
import 'package:chicachew/core/ml/postprocess.dart';
import 'package:chicachew/core/tts/tts_manager.dart';
import 'package:chicachew/core/ml/brush_predictor.dart';
import 'package:chicachew/core/landmarks/mediapipe_tasks.dart';
//import 'package:chicachew/core/ml/model_provider.dart'; // (+) 방금 만든 Provider import
import '../../brush_guide/application/story_director.dart';
import '../../brush_guide/application/radar_progress_engine.dart';
import '../../brush_guide/presentation/radar_overlay.dart';
import 'package:chicachew/features/brush_guide/presentation/brush_result_page.dart';

final brushPredictorProvider = FutureProvider<BrushPredictor>((ref) async {
  await BrushModelEngine.I.load();
  final predictor = BrushPredictor();
  await predictor.init();
  return predictor;
});

// (이하 모든 상수는 그대로 유지)
// ────────────────────────────────────────────────────────────────────
const int kBrushZoneCount = 13;
const int kSequenceLength = 30;
const int kFeatureDimension = 108;
const bool kDemoMode = false;
const bool kUseMpTasks = true;
const bool kShowFaceGuide = false;
const double kMinRelFace = 0.30;
const double kMaxRelFace = 0.60;
const double kMinLuma = 0.12;
const double kCenterJumpTol = 0.12;
const double kFeatEmaAlpha = 0.25 ;
const double kPosTol = 0.08;
const int kOkFlashMs = 1200;
const int kMpSendIntervalMs = 120;
const bool kLogLandmarks = true;
const Duration kLmLogInterval = Duration(milliseconds: 800);
String chicachuAssetOf(String variant) => 'assets/images/$variant.png';
const String kCavityAsset = 'assets/images/cavity.png';
enum _CamState { idle, requesting, denied, granted, noCamera, initError, ready }
// ────────────────────────────────────────────────────────────────────

class _FaceAnchors {
  final Offset leftEye;
  final Offset rightEye;
  final Offset nose;
  final Offset chin;
  final Offset mouthLeft;
  final Offset mouthRight;
  const _FaceAnchors({
    required this.leftEye,
    required this.rightEye,
    required this.nose,
    required this.chin,
    required this.mouthLeft,
    required this.mouthRight,
  });
}

// 1. StatefulWidget -> ConsumerStatefulWidget 으로 변경
class LiveBrushPage extends ConsumerStatefulWidget {
  final String chicachuVariant;
  const LiveBrushPage({super.key, this.chicachuVariant = 'molar'});

  @override
  // 2. State -> ConsumerState 로 변경
  ConsumerState<LiveBrushPage> createState() => _LiveBrushPageState();
}

// 3. State -> ConsumerState 로 변경
class _LiveBrushPageState extends ConsumerState<LiveBrushPage>
    with WidgetsBindingObserver {
  // (모든 변수 선언은 그대로 유지됩니다)
  late final StoryDirector _director;
  late final RadarProgressEngine _progress;
  final TtsManager _ttsMgr = TtsManager.instance;
  ShowMessage? _dialogue;
  DateTime _dialogueUntil = DateTime.fromMillisecondsSinceEpoch(0);
  FinaleResult? _finale;
  double _advantage = 0.0;
  final Set<int> _spokenCompleteZoneIdxs = {};
  bool _finaleTriggered = false;
  List<double> _lastScores = List.filled(kBrushZoneCount, 0.0);
  CameraController? _cam;
  bool _busy = false;
  int _throttle = 0;
  bool _streamOn = false;
  bool _camDisposing = false;
  _CamState _camState = _CamState.idle;
  String _camError = '';

  // (-) 이 변수들은 이제 Provider가 관리하므로 필요 없습니다.
  // bool _modelReady = false;
  // String _modelError = '';

  int _t = kSequenceLength;
  int _d = kFeatureDimension;
  late Float32List _seqBuf;
  int _seqCount = 0;
  int _seqWrite = 0;

  // (-) predictor 인스턴스는 Provider를 통해 받습니다.
  // late final BrushPredictor _pred;
  InferenceResult? _last;

  StreamSubscription<MpEvent>? _mpSub;
  DateTime _lastFaceUpdateAt = DateTime.fromMillisecondsSinceEpoch(0);
  Rect? _faceRectInPreview;
  double? _yawDeg, _pitchDeg, _rollDeg;
  double? _lastRel;
  bool _inRange = true;
  double _lastLuma = 1;
  bool _lastStable = true;
  Offset? _prevFaceCenter;
  bool _feedThisFrame = false;
  Float32List? _lastFeatD;
  Float32List? _prevPositionalFeat;
  String? _gateMsg;
  DateTime _okMsgUntil = DateTime(0);
  List<Offset>? _lastFaceLandmarks2D;
  List<List<double>>? _lastHandLandmarks;
  Rect? _lastFaceBoxNorm;
  DateTime _lastFaceLmLogAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastHandLmLogAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _mpSending = false;
  int _mpLastSentMs = 0;
  bool _swapUV = false;
  int? _forceRotDeg;
  bool _previewEnabled = true;
  int _framesSent = 0;

  bool _isCameraInitializing = false;

  String get _chicachuAvatarPath => chicachuAssetOf(widget.chicachuVariant);

  String _avatarForSpeaker(Speaker s) {
    switch (s) {
      case Speaker.cavitymon:
        return kCavityAsset;
      case Speaker.chikachu:
      case Speaker.narrator:
        return _chicachuAvatarPath;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 진행/스토리 (그대로 유지)
    _progress = RadarProgressEngine(
      tickInterval: const Duration(seconds: 1),
      ticksTargetPerZone: 10,
    );
    _director = StoryDirector(ticksTargetPerZone: 10);
    _progress.progressStream.listen((p) {
      _director.updateProgress(p);
      _lastScores = p;
      if (!_finaleTriggered && _allFull(p)) {
        _triggerFinaleOnce(source: 'progress');
      }
    });
    _director.stream.listen(_onStoryEvent);
    _progress.start();
    _director.start();
    _ttsMgr.init();

    // (-) 모델 래퍼 초기화는 Provider가 담당
    // _pred = BrushPredictor();

    if (kUseMpTasks) {
      _initMpTasks();
    }

    // 4. 모델 로딩은 Provider에 맡기고, 카메라 부팅만 호출
  }

  // (모든 함수는 그대로 유지됩니다)
  Future<void> _initMpTasks() async {
    // ... (기존 코드와 동일)
    try {
      final mp = MpTasksBridge.instance;
      try {
        await mp.start(face: true, hands: true, useNativeCamera: false);
      } on MissingPluginException {
        const mc = MethodChannel('mp_tasks');
        await mc.invokeMethod('init', {
          'face': true,
          'hands': true,
          'useNativeCamera': false,
        });
      }

      _mpSub?.cancel();
      _mpSub = mp.events.listen((e) {
        if (e is MpFaceEvent) {
          _onMpFace(e.landmarks); // [[nx,ny,nz]...], 0..1 정규화
          _lastFaceUpdateAt = DateTime.now();
        } else if (e is MpHandEvent) {
          _lastHandLandmarks = e.landmarks; // List<List<double>>
          _logHandLmSample([e.landmarks]);
        }
      });
    } catch (e) {
      debugPrint('[MP] start/listen error: $e');
    }
  }

  void _onMpFace(List<List> landmarks) {
    // ... (기존 코드와 동일)
    if (landmarks.isEmpty) return;
    final ptsNorm = <Offset>[];
    double minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9;
    for (final p in landmarks) {
      if (p.length < 2) continue;
      final double nx = (p[0] as num).toDouble().clamp(0.0, 1.0);
      final double ny = (p[1] as num).toDouble().clamp(0.0, 1.0);
      ptsNorm.add(Offset(nx, ny));
      if (nx < minX) minX = nx;
      if (ny < minY) minY = ny;
      if (nx > maxX) maxX = nx;
      if (ny > maxY) maxY = ny;
    }
    if (ptsNorm.isEmpty) return;
    final faceBoxNorm = Rect.fromLTRB(minX, minY, maxX, maxY);
    final preview = MediaQuery.of(context).size;
    final mapped = _mapNormRectToPreview(
      normRect: faceBoxNorm,
      previewSize: preview,
      mirror: true,
    );
    final center = mapped.center;
    bool stable = true;
    if (_prevFaceCenter != null) {
      final dx = (center.dx - _prevFaceCenter!.dx).abs() / preview.width;
      final dy = (center.dy - _prevFaceCenter!.dy).abs() / preview.height;
      stable = max(dx, dy) <= kCenterJumpTol;
    }
    _prevFaceCenter = center;
    _lastStable = stable;
    final rel = faceBoxNorm.height.clamp(0.0, 1.0);
    _lastRel = rel;
    _inRange = (rel >= kMinRelFace) && (rel <= kMaxRelFace);
    _logFaceLmSampleNorm(
      faceBoxNorm: faceBoxNorm,
      ptsNorm: ptsNorm,
      rel: rel,
    );
    String? msg;
    if (!_inRange) {
      msg = (rel < kMinRelFace) ? '조금 더 가까이 와주세요' : '조금만 멀리 떨어져 주세요';
    } else {
      final target = _targetRect(preview);
      final ndx = (mapped.center.dx - target.center.dx) / target.width;
      final ndy = (mapped.center.dy - target.center.dy) / target.height;
      if (ndx > kPosTol)
        msg = '얼굴을 조금 왼쪽으로 이동해 주세요';
      else if (ndx < -kPosTol)
        msg = '얼굴을 조금 오른쪽으로 이동해 주세요';
      else if (ndy > kPosTol)
        msg = '얼굴을 조금 위로 올려주세요';
      else if (ndy < -kPosTol)
        msg = '얼굴을 조금 아래로 내려주세요';
      else
        msg = null;
    }
    setState(() {
      _faceRectInPreview = mapped;
      _yawDeg = _pitchDeg = _rollDeg = null;
      if (msg == null) {
        _okMsgUntil = DateTime.now().add(const Duration(milliseconds: kOkFlashMs));
        _gateMsg = null;
      } else {
        _gateMsg = msg;
        _okMsgUntil = DateTime(0);
      }
    });
    _lastFaceLandmarks2D = ptsNorm;
    _lastFaceBoxNorm = _emaRect(_lastFaceBoxNorm, faceBoxNorm, 0.2);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPipelines();
    _progress.stop();
    _director.dispose();
    _ttsMgr.dispose();
    _mpSub?.cancel();
    super.dispose();
  }

  // 5. _boot() -> _bootCamera()로 이름 변경, 모델 로딩 로직 제거
  Future<void> _bootCamera() async {
    if (kDemoMode) {
      if (mounted) setState(() => _camState = _CamState.ready);
      _startDemo();
      return;
    }

    if (mounted) {
      setState(() {
        _camState = _CamState.requesting;
        _camError = '';
      });
    }

    var status = await Permission.camera.status;
    if (!status.isGranted) status = await Permission.camera.request();
    if (!mounted) return;

    if (status.isPermanentlyDenied || !status.isGranted) {
      setState(() => _camState = _CamState.denied);
      return;
    }

    setState(() => _camState = _CamState.granted);

    // (-) 모델 로딩은 Provider가 하므로 카메라 초기화만 진행

    // (+) 모델이 준비된 후에 스트림 시작 (build 메서드에서 처리)
  }

  Future<void> _initializeCameraAfterModel() async {
    if (_isCameraInitializing || _cam != null) return;
    _isCameraInitializing = true;

    if (mounted) setState(() => _camState = _CamState.requesting);
    var status = await Permission.camera.status;
    if (!status.isGranted) status = await Permission.camera.request();
    if (!mounted) return;

    if (status.isPermanentlyDenied || !status.isGranted) {
      if (mounted) setState(() => _camState = _CamState.denied);
      return;
    }
    if (mounted) setState(() => _camState = _CamState.granted);

    await _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        if (mounted) setState(() { _camState = _CamState.noCamera; _camError = '카메라 장치를 찾을 수 없습니다.'; });
        return;
      }
      final front = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cams.first);

      await _disposeCamSafely();

      final controller = CameraController(front, ResolutionPreset.low, enableAudio: false, imageFormatGroup: ImageFormatGroup.yuv420);
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }
      _cam = controller;

      await _startStream();

      if (mounted) setState(() => _camState = _CamState.ready);

    } catch (e, st) {
      debugPrint('Camera init error: $e\n$st');
      if (mounted) setState(() { _camState = _CamState.initError; _camError = '$e'; });
    }
  }

  // (-) _loadModel() 함수는 Provider로 이전되었으므로 전체 삭제
  // Future<void> _loadModel() async { ... }

  Future<void> _startStream() async {
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized || _streamOn) return;

    // 6. (+) 스트림 시작 시 시퀀스 버퍼 초기화 로직 추가
    if (BrushModelEngine.I.isSequenceModel) {
      _t = BrushModelEngine.I.seqT;
      _d = BrushModelEngine.I.seqD;
      _seqBuf = Float32List(_t * _d);
      _seqCount = 0;
      _seqWrite = 0;
    }

    try {
      _streamOn = true;
      await cam.startImageStream(_onImage);
    } catch (e) {
      _streamOn = false;
      rethrow;
    }
  }

  Future<void> _disposeCamSafely() async {
    // ... (기존 코드와 동일)
    final oldController = _cam;
    if (oldController == null) return;
    _streamOn = false;
    _camDisposing = true;
    _cam = null;
    if (mounted) setState(() {});
    await Future.delayed(const Duration(milliseconds: 150));
    try {
      await oldController.stopImageStream();
    } catch (_) {}
    try {
      await oldController.dispose();
    } catch (_) {}
    if (mounted) _camDisposing = false;
  }

  void _stopPipelines() {
    _disposeCamSafely();
    try {
      MpTasksBridge.instance.stop();
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    // ... (기존 코드와 동일)
    if (_cam == null && state != AppLifecycleState.resumed) {
      return;
    }
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      await _disposeCamSafely();
      try {
        MpTasksBridge.instance.stop();
      } catch (_) {}
    } else if (state == AppLifecycleState.resumed) {
      if (_cam == null) {
        await _bootCamera(); // 7. _boot() -> _bootCamera()
        if (kUseMpTasks) {
          try {
            await MpTasksBridge.instance.start(face: true, hands: true, useNativeCamera: false);
          } on MissingPluginException {
            const mc = MethodChannel('mp_tasks');
            try {
              await mc.invokeMethod('init', {
                'face': true,
                'hands': true,
                'useNativeCamera': false,
              });
            } catch (_) {}
          }
        }
      }
    }
  }

  int _computeRotationDegrees() {
    // ... (기존 코드와 동일)
    if (_cam == null) return 0;
    final sensor = _cam!.description.sensorOrientation;
    final isFront = _cam!.description.lensDirection == CameraLensDirection.front;
    final dev = _cam!.value.deviceOrientation;
    int device = switch (dev) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
      _ => 0,
    };
    return isFront ? (sensor + device) % 360 : (sensor - device + 360) % 360;
  }

  Future<void> _sendFrameToMp(CameraImage img) async {
    // ... (기존 코드와 동일)
    if (!kUseMpTasks || !Platform.isAndroid) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_mpSending || now - _mpLastSentMs < kMpSendIntervalMs) return;
    final c = _cam;
    if (c == null) return;
    final rot = _forceRotDeg ?? _computeRotationDegrees();
    _mpSending = true;
    _mpLastSentMs = now;
    try {
      if (img.planes.length < 3) return;
      final y = img.planes[0];
      final u = _swapUV ? img.planes[2] : img.planes[1];
      final v = _swapUV ? img.planes[1] : img.planes[2];
      _framesSent++;
      if (_framesSent == 1) {
        debugPrint(
            '[MP] first frame rot=$rot wh=${img.width}x${img.height} '
                'Yrow=${y.bytesPerRow}, Urow=${u.bytesPerRow}(ps=${u.bytesPerPixel}), '
                'Vrow=${v.bytesPerRow}(ps=${v.bytesPerPixel}), swapUV=$_swapUV');
      }
      await MpTasksBridge.instance.processYuv420Planes(
        y: y.bytes, u: u.bytes, v: v.bytes,
        width: img.width, height: img.height,
        yRowStride: y.bytesPerRow, uRowStride: u.bytesPerRow, vRowStride: v.bytesPerRow,
        uPixelStride: u.bytesPerPixel ?? 1, vPixelStride: v.bytesPerPixel ?? 1,
        rotationDeg: rot, timestampMs: now,
      );
    } catch (e) {
      debugPrint('[MP] processYuv420Planes error: $e');
    } finally {
      _mpSending = false;
    }
  }

  // (모든 유틸리티 함수들은 그대로 유지됩니다)
  Float32List _resizeCHWNearest(Float32List src, int srcH, int srcW, int dstH, int dstW) {
    // ... (기존 코드와 동일)
    if (srcH == dstH && srcW == dstW) return src;
    final out = Float32List(3 * dstH * dstW);
    for (int c = 0; c < 3; c++) {
      for (int y = 0; y < dstH; y++) {
        final sy = (y * srcH) ~/ dstH;
        for (int x = 0; x < dstW; x++) {
          final sx = (x * srcW) ~/ dstW;
          out[(c * dstH + y) * dstW + x] = src[(c * srcH + sy) * srcW + sx];
        }
      }
    }
    return out;
  }
  Float32List _chw224ToGrayHW(Float32List chw224) {
    // ... (기존 코드와 동일)
    const H = 224, W = 224;
    final out = Float32List(H * W);
    for (int y = 0; y < H; y++) {
      for (int x = 0; x < W; x++) {
        final r = chw224[(0 * H + y) * W + x];
        final g = chw224[(1 * H + y) * W + x];
        final b = chw224[(2 * H + y) * W + x];
        out[y * W + x] = 0.2989 * r + 0.5870 * g + 0.1140 * b;
      }
    }
    return out;
  }
  Float32List _resizeGRAYNearest(Float32List src, int srcH, int srcW, int dstH, int dstW) {
    // ... (기존 코드와 동일)
    if (srcH == dstH && srcW == dstW) return src;
    final out = Float32List(dstH * dstW);
    for (int y = 0; y < dstH; y++) {
      final sy = (y * srcH) ~/ dstH;
      for (int x = 0; x < dstW; x++) {
        final sx = (x * srcW) ~/ dstW;
        out[y * dstW + x] = src[sy * srcW + sx];
      }
    }
    return out;
  }
  List<double> _yuv420ToCHW224Safe(CameraImage img, {bool mirror = true}) {
    // ... (기존 코드와 동일)
    const int D = 224;
    final int srcW = img.width;
    final int srcH = img.height;
    final pY = img.planes[0], pU = img.planes[1], pV = img.planes[2];
    final yBytes = pY.bytes, uBytes = pU.bytes, vBytes = pV.bytes;
    final yRow = pY.bytesPerRow, uRow = pU.bytesPerRow, vRow = pV.bytesPerRow;
    final uPix = pU.bytesPerPixel ?? 1, vPix = pV.bytesPerPixel ?? 1;
    final out = List<double>.filled(3 * D * D, 0.0);
    int idxR = 0, idxG = D * D, idxB = 2 * D * D;
    for (int y = 0; y < D; y++) {
      final double syf = (y + 0.5) * srcH / D;
      final int sy = syf.floor().clamp(0, srcH - 1);
      final int sy2 = (sy >> 1).clamp(0, (srcH >> 1) - 1);
      for (int x = 0; x < D; x++) {
        final int dx = mirror ? (D - 1 - x) : x;
        final double sxf = (dx + 0.5) * srcW / D;
        final int sx = sxf.floor().clamp(0, srcW - 1);
        final int sx2 = (sx >> 1).clamp(0, (srcW >> 1) - 1);
        final int yi = sy * yRow + sx;
        final int ui = sy2 * uRow + sx2 * uPix;
        final int vi = sy2 * vRow + sx2 * vPix;
        final int Y = yBytes[yi], U = uBytes[ui], V = vBytes[vi];
        final double c = (Y - 16).toDouble();
        final double d = (U - 128).toDouble();
        final double e = (V - 128).toDouble();
        double r = (1.164 * c + 1.596 * e) / 255.0;
        double g = (1.164 * c - 0.392 * d - 0.813 * e) / 255.0;
        double b = (1.164 * c + 2.017 * d) / 255.0;
        out[idxR++] = r.clamp(0.0, 1.0);
        out[idxG++] = g.clamp(0.0, 1.0);
        out[idxB++] = b.clamp(0.0, 1.0);
      }
    }
    return out;
  }
  double _estimateLuma01(CameraImage img) {
    // ... (기존 코드와 동일)
    final pY = img.planes.first;
    final y = pY.bytes;
    if (y.isEmpty) return 1.0;
    int sum = 0, cnt = 0;
    final step = 16;
    for (int i = 0; i < y.length; i += step) {
      sum += y[i];
      cnt++;
    }
    return (sum / (cnt * 255.0)).clamp(0.0, 1.0);
  }
  Float32List _emaFeature(Float32List cur) {
    // ... (기존 코드와 동일)
    if (_lastFeatD == null || _lastFeatD!.length != cur.length) {
      _lastFeatD = Float32List.fromList(cur);
      return cur;
    }
    final out = Float32List(cur.length);
    for (int i = 0; i < cur.length; i++) {
      final prev = _lastFeatD![i];
      final v = prev * (1 - kFeatEmaAlpha) + cur[i] * kFeatEmaAlpha;
      out[i] = v;
      _lastFeatD![i] = v;
    }
    return out;
  }
  Rect _targetRect(Size size) {
    // ... (기존 코드와 동일)
    final w = size.width * 0.72;
    final h = size.height * 0.58;
    final cx = size.width * 0.5;
    final cy = size.height * 0.52;
    return Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);
  }

  Future<void> _onImage(CameraImage img) async {
    // 8. (+) Provider로부터 predictor 인스턴스를 안전하게 가져옴
    final pred = ref.read(brushPredictorProvider).value;

    if (!mounted) return;
    await _sendFrameToMp(img);
    _lastLuma = _estimateLuma01(img);

    final nowT = DateTime.now();
    final stale = nowT.difference(_lastFaceUpdateAt) > const Duration(milliseconds: 800);
    if (stale) {
      setState(() {
        _faceRectInPreview = null;
        _gateMsg = '얼굴이 보이도록 카메라 중앙에 맞춰주세요';
        _okMsgUntil = DateTime(0);
      });
      final gapMs = nowT.difference(_lastFaceUpdateAt).inMilliseconds;
      if (gapMs > 1800 && _forceRotDeg == null) {
        setState(() => _forceRotDeg = 270);
        debugPrint('[MP][AutoFix] no face >1.8s → forceRotDeg=270');
      } else if (gapMs > 3200 && !_swapUV) {
        setState(() => _swapUV = true);
        debugPrint('[MP][AutoFix] no face >3.2s → swapUV=true');
      } else if (gapMs > 4600 && _previewEnabled) {
        setState(() => _previewEnabled = false);
        debugPrint('[MP][AutoFix] no face >4.6s → disable preview');
      }
    }

    // 9. (+) 모델 준비 상태를 pred의 null 여부로 확인
    if (_busy || pred == null || !BrushModelEngine.I.isReady) return;

    _throttle = (_throttle + 1) % 2;
    if (_throttle != 0) return;

    _busy = true;
    try {
      final allowByDist = (_lastRel == null) ? true : _inRange;
      final allowByLuma = _lastLuma >= kMinLuma;
      final allowByStable = _lastStable;
      final allow = allowByDist && allowByLuma && allowByStable;
      _feedThisFrame = allow;

      if (!allow) return;

      if (BrushModelEngine.I.isSequenceModel) {
        final featD = _buildCoordFeatureD();
        if (featD == null || featD.length != _d) return;
        _pushFeature(featD);

        // 10. (+) pred.isReady -> pred != null 로 변경
        if (_seqCount >= _t && pred != null) {
          final window2D = _windowAs2D();
          // 11. _pred -> pred 로 변경
          final res = pred.inferFromWindow(window2D);
          _last = res;
          onModelProbsUpdate(res.probs);
          onModelZoneUpdate(res.index);
        }
      } else {
        // ... (이미지 모델 경로는 기존과 동일)
      }
    } catch (e) {
      debugPrint('infer error: $e');
    } finally {
      _busy = false;
    }
  }

  // (이하 모든 함수는 기존 코드와 동일하게 유지됩니다)
  Rect _mapNormRectToPreview({ required Rect normRect, required Size previewSize, bool mirror = true,}) {
    // ...
    double l = normRect.left;
    double r = normRect.right;
    final t = normRect.top;
    final b = normRect.bottom;
    if (mirror) {
      final nl = 1.0 - r;
      final nr = 1.0 - l;
      l = nl;
      r = nr;
    }
    final left = l * previewSize.width;
    final top = t * previewSize.height;
    final width = (r - l) * previewSize.width;
    final height = (b - t) * previewSize.height;
    return Rect.fromLTWH(left, top, width, height);
  }
  void _pushFeature(Float32List f) {
    // ...
    final base = _seqWrite * _d;
    final n = (f.length < _d) ? f.length : _d;
    for (int i = 0; i < n; i++) {
      _seqBuf[base + i] = f[i];
    }
    for (int i = n; i < _d; i++) {
      _seqBuf[base + i] = 0.0;
    }
    _seqWrite = (_seqWrite + 1) % _t;
    if (_seqCount < _t) _seqCount++;
  }
  List<List<double>> _windowAs2D() {
    // ...
    final out = List.generate(_t, (_) => List.filled(_d, 0.0));
    final start = (_seqCount < _t) ? 0 : _seqWrite;
    for (int j = 0; j < _t; j++) {
      final frame = (start + j) % _t;
      final off = frame * _d;
      for (int k = 0; k < _d; k++) {
        out[j][k] = _seqBuf[off + k];
      }
    }
    return out;
  }
  Float32List _linearizeSeq() {
    // ...
    final out = Float32List(_t * _d);
    int outOff = 0;
    final start = (_seqCount < _t) ? 0 : _seqWrite;
    for (int j = 0; j < _t; j++) {
      final frame = (start + j) % _t;
      final off = frame * _d;
      for (int k = 0; k < _d; k++) {
        out[outOff + k] = _seqBuf[off + k];
      }
      outOff += _d;
    }
    return out;
  }
  void onModelZoneUpdate(int? zoneIndex) => _progress.reportZoneIndex(zoneIndex);
  void onModelProbsUpdate(List<double> probs) => _progress.reportZoneProbs(probs, threshold: 0.25);
  void _onStoryEvent(StoryEvent e) async {
    // ...
    if (!mounted) return;
    if (e is ShowMessage) {
      _showDialogue(e, e.duration);
      await _ttsMgr.speak(e.text, speaker: e.speaker);
      HapticFeedback.lightImpact();
    } else if (e is ShowHintForZone) {
      final text = '${e.zoneName}를 닦아볼까?';
      _showDialogue(
        ShowMessage(text, duration: e.duration, speaker: Speaker.chikachu),
        e.duration,
      );
      await _ttsMgr.speak(text, speaker: Speaker.chikachu);
      HapticFeedback.mediumImpact();
    } else if (e is ShowCompleteZone) {
      if (_spokenCompleteZoneIdxs.contains(e.zoneIndex)) return;
      _spokenCompleteZoneIdxs.add(e.zoneIndex);
      final text = '${e.zoneName} 완료! 다른 부분도 닦아보자!';
      _showDialogue(
        ShowMessage(text, duration: e.duration, speaker: Speaker.chikachu),
        e.duration,
      );
      HapticFeedback.selectionClick();
      await _ttsMgr.speak(text, speaker: Speaker.chikachu);
      if (!_finaleTriggered && _spokenCompleteZoneIdxs.length >= kBrushZoneCount) {
        _triggerFinaleOnce(source: 'zones-complete');
      }
    } else if (e is BossHudUpdate) {
      setState(() => _advantage = e.advantage);
    } else if (e is FinaleEvent) {
      if (!_finaleTriggered) {
        _triggerFinaleOnce(source: 'director-event', result: e.result);
      }
    }
  }
  void _showDialogue(ShowMessage msg, Duration d) {
    // ...
    if (!mounted) return;
    setState(() {
      _dialogue = msg;
      _dialogueUntil = DateTime.now().add(d);
    });
  }
  List<double> _normalizedScores(List<double> scores) {
    // ...
    if (scores.any((v) => v > 1.0)) {
      return scores.map((v) => (v / 100.0).clamp(0.0, 1.0)).toList();
    }
    return scores.map((v) => v.clamp(0.0, 1.0)).toList();
  }
  bool _allFull(List<double> src) {
    // ...
    final vals = (src.any((v) => v > 1.0))
        ? src.map((v) => v / 100.0).toList()
        : src;
    return vals.length == kBrushZoneCount && vals.every((v) => v >= 0.999);
  }
  int _suggestActiveIndex(List<double> scores) {
    // ...
    var idx = 0;
    var minVal = 999.0;
    final vals = scores;
    for (int i = 0; i < vals.length; i++) {
      if (vals[i] < minVal) {
        minVal = vals[i];
        idx = i;
      }
    }
    return idx;
  }
  void _triggerFinaleOnce({String source = 'unknown', FinaleResult? result}) async {
    if (_finaleTriggered || !mounted) return;
    _finaleTriggered = true;

    await _disposeCamSafely();
    _progress.stop();

    setState(() => _finale = result ?? FinaleResult.win);

    final line = (result == FinaleResult.lose)
        ? '오늘은 아쉽지만, 내일은 꼭 이겨보자!'
        : '모든 구역 반짝반짝! 오늘 미션 완벽 클리어! ✨';
    _showDialogue(
      ShowMessage(line, duration: const Duration(seconds: 3), speaker: Speaker.chikachu),
      const Duration(seconds: 3),
    );
    await _ttsMgr.speak(line, speaker: Speaker.chikachu);
    HapticFeedback.heavyImpact();

    if (!mounted) return;
    await Future.delayed(const Duration(seconds: 5));

    if (!mounted) return;
    final scores01 = _normalizedScores(_lastScores);

    context.push('/mouthwash', extra: scores01);
  }
  Timer? _demoTm;
  int _demoZone = 0, _demoTicks = 0;
  final _rnd = Random();
  void _startDemo() {
    // ...
    _demoTm = Timer.periodic(const Duration(milliseconds: 200), (t) {
      _demoTicks++;
      if (_demoTicks >= 4 + _rnd.nextInt(3)) {
        _demoTicks = 0;
        _demoZone = (_demoZone + 1) % kBrushZoneCount;
      }
      final probs = List<double>.filled(kBrushZoneCount, 0.02);
      probs[_demoZone] = 0.9;
      probs[(_demoZone + kBrushZoneCount - 1) % kBrushZoneCount] = 0.3;
      probs[(_demoZone + 1) % kBrushZoneCount] = 0.3;
      onModelProbsUpdate(probs);
      onModelZoneUpdate(_demoZone);
    });
  }
  void _stopDemo() {
    // ...
    _demoTm?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final modelAsyncValue = ref.watch(brushPredictorProvider);

    return Scaffold(
      body: modelAsyncValue.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('양치질 분석 모델을 준비 중입니다...'),
            ],
          ),
        ),
        error: (err, stack) => Center(child: Text('모델 로딩 실패: $err')),
        data: (predictor) {
          if (_camState == _CamState.idle) {
            Future.microtask(() => _initializeCameraAfterModel());
          }

          switch (_camState) {
            case _CamState.ready:
              final cam = _cam;
              final showPreview = !kDemoMode && !_camDisposing && cam != null && cam.value.isInitialized && _previewEnabled;
              if (showPreview) {
                return Stack(
                  children: [
                    Positioned.fill(child: CameraPreview(cam)),
                    if (kShowFaceGuide)
                      Positioned.fill(
                        child: LayoutBuilder(
                          builder: (context, c) {
                            final previewSize = Size(c.maxWidth, c.maxHeight);
                            return FaceAlignOverlay(
                              previewSize: previewSize,
                              faceBoxInPreview: _faceRectInPreview,
                              yawDeg: _yawDeg,
                              pitchDeg: _pitchDeg,
                              rollDeg: _rollDeg,
                            );
                          },
                        ),
                      ),
                    Positioned.fill(
                      child: StreamBuilder<List<double>>(
                        stream: _progress.progressStream,
                        initialData: List.filled(kBrushZoneCount, 0.0),
                        builder: (context, snapshot) {
                          final scores01 = _normalizedScores(snapshot.data ?? []);
                          final activeIdx = _suggestActiveIndex(scores01);
                          return RadarOverlay(
                            scores: scores01,
                            activeIndex: activeIdx,
                            expand: true,
                            fallbackDemoIfEmpty: false,
                            fx: RadarFx.radialPulse,
                            showHighlight: true,
                          );
                        },
                      ),
                    ),
                    if ((_gateMsg != null && _gateMsg!.isNotEmpty) || DateTime.now().isBefore(_okMsgUntil))
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: MediaQuery.of(context).padding.bottom + 32,
                        child: AnimatedOpacity(
                          opacity: 1.0,
                          duration: const Duration(milliseconds: 150),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: DateTime.now().isBefore(_okMsgUntil)
                                  ? const Color(0xFF2E7D32)
                                  : Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: const [
                                BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 8,
                                    offset: Offset(0, 3))
                              ],
                            ),
                            child: Center(
                              child: Text(
                                DateTime.now().isBefore(_okMsgUntil)
                                    ? '범위 내에 들어왔습니다!'
                                    : _gateMsg!,
                                textAlign: TextAlign.center,
                                softWrap: true,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_dialogue != null && DateTime.now().isBefore(_dialogueUntil))
                      Positioned(
                        left: 12, right: 12,
                        bottom: MediaQuery.of(context).padding.bottom + 120,
                        child: _DialogueOverlay(
                          text: _dialogue!.text,
                          avatarPath: _avatarForSpeaker(_dialogue!.speaker),
                          alignLeft: _dialogue!.speaker != Speaker.cavitymon,
                        ),
                      ),
                    Positioned(
                      left: 16, right: 16,
                      bottom: MediaQuery.of(context).padding.bottom + 16,
                      child: _BossHud(advantage: _advantage),
                    ),
                    if (_finale != null)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.55),
                          alignment: Alignment.center,
                          child: _FinaleView(result: _finale!),
                        ),
                      ),
                  ],
                );
              }
              return const Center(child: CircularProgressIndicator());

            case _CamState.denied:
              return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('카메라 권한이 필요합니다.'),
                      const SizedBox(height: 8),
                      TextButton(onPressed: openAppSettings, child: const Text('설정에서 권한 열기')),
                    ],
                  )
              );

            case _CamState.initError:
              return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text('카메라 초기화 실패\n$_camError'), TextButton(onPressed: _initializeCameraAfterModel, child: const Text('다시 시도'))]));

            default:
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('카메라를 준비 중입니다...'),
                  ],
                ),
              );
          }
        },
      ),
    );
  }

  // (이하 모든 함수는 기존 코드와 동일하게 유지됩니다)
  Rect _emaRect(Rect? prev, Rect cur, double alpha) {
    if (prev == null) return cur;
    double lerp(double a, double b) => a * (1 - alpha) + b * alpha;
    return Rect.fromLTRB( lerp(prev.left, cur.left), lerp(prev.top, cur.top), lerp(prev.right, cur.right), lerp(prev.bottom, cur.bottom),);
  }
  _FaceAnchors? _getFaceAnchors() {
    final faceLms = _lastFaceLandmarks2D;
    final boxNorm = _lastFaceBoxNorm;
    if (faceLms != null && faceLms.length >= 300) {
      Offset? getMP(int i) => (i >= 0 && i < faceLms.length) ? faceLms[i] : null;
      final leftEye = getMP(33);
      final rightEye = getMP(263);
      final nose = getMP(1);
      final chin = getMP(152);
      final mouthLeft = getMP(61);
      final mouthRight = getMP(291);
      if ([leftEye, rightEye, nose, chin, mouthLeft, mouthRight].every((e) => e != null)) {
        return _FaceAnchors(
          leftEye: leftEye!, rightEye: rightEye!, nose: nose!,
          chin: chin!, mouthLeft: mouthLeft!, mouthRight: mouthRight!,
        );
      }
    }
    if (boxNorm != null) {
      final cx = boxNorm.center.dx, cy = boxNorm.center.dy;
      final w = boxNorm.width, h = boxNorm.height;
      return _FaceAnchors(
        leftEye: Offset(boxNorm.left + w * 0.35, boxNorm.top + h * 0.35),
        rightEye: Offset(boxNorm.left + w * 0.65, boxNorm.top + h * 0.35),
        nose: Offset(cx, boxNorm.top + h * 0.52),
        chin: Offset(cx, boxNorm.bottom),
        mouthLeft: Offset(boxNorm.left + w * 0.40, boxNorm.top + h * 0.75),
        mouthRight: Offset(boxNorm.left + w * 0.60, boxNorm.top + h * 0.75),
      );
    }
    return null;
  }
  Float32List? _buildCoordFeatureD() {
    final anchors = _getFaceAnchors();
    if (anchors == null) {
      if (kLogLandmarks) {
        debugPrint('[FeatureBuild] SKIP: face anchors=null, hand=${_lastHandLandmarks?.length}');
      }
      return null;
    }
    final handLmsNorm = _lastHandLandmarks;
    final List<Offset> handPts = (handLmsNorm == null || handLmsNorm.length < 21)
        ? List<Offset>.filled(21, Offset.zero)
        : handLmsNorm.map((p) => Offset( (p[0] as num).toDouble().clamp(0.0, 1.0), (p[1] as num).toDouble().clamp(0.0, 1.0),)).toList();
    final List<Offset> pts = [ ...handPts, anchors.leftEye, anchors.rightEye, anchors.nose, anchors.chin, anchors.mouthLeft, anchors.mouthRight,];
    final nose = anchors.nose, leftEye = anchors.leftEye, rightEye = anchors.rightEye, chin = anchors.chin;
    final translated = pts.map((p) => p - nose).toList();
    final eyeVec = rightEye - leftEye;
    final scale = eyeVec.distance;
    if (scale < 1e-6) return null;
    final roll = -atan2(eyeVec.dy, eyeVec.dx);
    final cr = cos(roll), sr = sin(roll);
    final List<Offset> rolled = translated.map((p) => Offset((p.dx * cr - p.dy * sr) / scale, (p.dx * sr + p.dy * cr) / scale)).toList();
    final chinT = chin - nose;
    final chinRx = (chinT.dx * cr - chinT.dy * sr) / scale;
    final chinRy = (chinT.dx * sr + chinT.dy * cr) / scale;
    final pitch = -(atan2(chinRy, chinRx) - (pi / 2));
    final cp = cos(pitch), sp = sin(pitch);
    final List<Offset> norm = rolled.map((p) => Offset(p.dx * cp - p.dy * sp, p.dx * sp + p.dy * cp)).toList();
    final posD = _d ~/ 2;
    final positional = Float32List(posD);
    int k = 0;
    for (int i = 0; i < 21 && k + 1 < posD; i++) {
      positional[k++] = norm[i].dx;
      positional[k++] = norm[i].dy;
    }
    final base = norm.length - 6;
    for (int i = 0; i < 6 && k + 1 < posD; i++) {
      positional[k++] = norm[base + i].dx;
      positional[k++] = norm[base + i].dy;
    }
    while (k < posD) positional[k++] = 0.0;
    final Float32List out;
    if (_prevPositionalFeat == null || _prevPositionalFeat!.length != posD) {
      out = Float32List.fromList([...positional, ...Float32List(posD)]);
    } else {
      final vel = Float32List(posD);
      for (int i = 0; i < posD; i++) {
        vel[i] = positional[i] - _prevPositionalFeat![i];
      }
      out = Float32List.fromList([...positional, ...vel]);
    }
    _prevPositionalFeat = positional;
    return _emaFeature(out);
  }
  void _logFaceLmSampleNorm({ required Rect faceBoxNorm, required List<Offset> ptsNorm, required double rel,}) {
    // ...
    if (!kLogLandmarks) return;
    final now = DateTime.now();
    if (now.isBefore(_lastFaceLmLogAt.add(kLmLogInterval))) return;
    _lastFaceLmLogAt = now;
    final n = ptsNorm.length;
    final picks = <int>[ 0, (n * 0.25).floor(), (n * 0.5).floor(), (n * 0.75).floor(), n - 1,].where((i) => i >= 0 && i < n).toList();
    final samples = picks.map((i) {
      final p = ptsNorm[i];
      return '#$i(${p.dx.toStringAsFixed(3)}, ${p.dy.toStringAsFixed(3)})';
    }).join(', ');
    debugPrint(
      '[MP:FACE] boxN=[L${faceBoxNorm.left.toStringAsFixed(3)},'
          'T${faceBoxNorm.top.toStringAsFixed(3)},'
          'W${faceBoxNorm.width.toStringAsFixed(3)},'
          'H${faceBoxNorm.height.toStringAsFixed(3)}] '
          'rel=${(rel * 100).toStringAsFixed(0)}% '
          'pts=$n samples: $samples',
    );
  }
  void _logHandLmSample(List<List> hands) {
    // ...
    if (!kLogLandmarks) return;
    final now = DateTime.now();
    if (now.isBefore(_lastHandLmLogAt.add(kLmLogInterval))) return;
    _lastHandLmLogAt = now;
    final handCount = hands.length;
    final head = StringBuffer('[MP:HAND] hands=$handCount ');
    for (int h = 0; h < handCount; h++) {
      final pts = hands[h].cast<List>();
      if (pts.isEmpty) continue;
      final n = pts.length;
      final picks = <int>[0, n - 1].where((i) => i >= 0 && i < n).toList();
      final samples = picks.map((i) {
        final p = pts[i];
        final nx = (p[0] as num).toDouble();
        final ny = (p[1] as num).toDouble();
        final nz = (p.length >= 3) ? (p[2] as num).toDouble() : double.nan;
        return '#$i(${nx.toStringAsFixed(3)}, ${ny.toStringAsFixed(3)}, z=${nz.isNaN ? "n/a" : nz.toStringAsFixed(4)})';
      }).join(', ');
      head.write(' | H$h pts=$n samples: $samples');
    }
    debugPrint(head.toString());
  }
}
// (이하 모든 위젯 클래스는 기존 코드와 동일하게 유지됩니다)
class FaceAlignOverlay extends StatelessWidget {
  // ...
  final Size previewSize;
  final Rect? faceBoxInPreview;
  final double? yawDeg, pitchDeg, rollDeg;
  const FaceAlignOverlay({ super.key, required this.previewSize, required this.faceBoxInPreview, this.yawDeg, this.pitchDeg, this.rollDeg,});
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          CustomPaint(
            size: previewSize,
            painter: _GuidePainter(
              targetRect: _targetRect(previewSize),
            ),
          ),
          if (faceBoxInPreview != null)
            CustomPaint(
              size: previewSize,
              painter: _FaceBoxPainter(
                faceRect: faceBoxInPreview!,
                ok: true,
              ),
            ),
        ],
      ),
    );
  }
  Rect _targetRect(Size size) {
    final w = size.width * 0.72;
    final h = size.height * 0.58;
    final cx = size.width * 0.5;
    final cy = size.height * 0.52;
    return Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);
  }
}
class _GuidePainter extends CustomPainter {
  // ...
  final Rect targetRect;
  const _GuidePainter({required this.targetRect});
  @override
  void paint(Canvas canvas, Size size) {}
  @override
  bool shouldRepaint(covariant _GuidePainter oldDelegate) => oldDelegate.targetRect != targetRect;
}
class _FaceBoxPainter extends CustomPainter {
  // ...
  final Rect faceRect;
  final bool ok;
  const _FaceBoxPainter({ required this.faceRect, required this.ok,});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = ok ? const Color(0xFF00E676) : const Color(0xFFFF7043);
    final rrect = RRect.fromRectAndRadius(faceRect, const Radius.circular(12));
    canvas.drawRRect(rrect, p);
  }
  @override
  bool shouldRepaint(covariant _FaceBoxPainter oldDelegate) {
    return oldDelegate.faceRect != faceRect || oldDelegate.ok != ok;
  }
}
class _BossHud extends StatelessWidget {
  // ...
  final double advantage;
  const _BossHud({required this.advantage});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('치카츄 vs 캐비티몬', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: advantage, minHeight: 10,
            backgroundColor: Colors.red.withOpacity(0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.lightBlueAccent),
          ),
        ),
      ],
    );
  }
}
class _FinaleView extends StatelessWidget {
  // ...
  final FinaleResult result;
  const _FinaleView({required this.result});
  @override
  Widget build(BuildContext context) {
    String text;
    if (result == FinaleResult.win) {
      text = '캐비티몬이 쓰러졌다!\n치카츄 승리!';
    } else if (result == FinaleResult.draw) {
      text = '“이걸로는 내가 쓰러지지 않는다… 다음에 다시 찾아오겠다!”';
    } else {
      text = '캐비티몬 승리!\n더 꼼꼼히 닦아서 다시 도전!';
    }
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle( color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
      ),
    );
  }
}
class _DialogueOverlay extends StatelessWidget {
  // ...
  final String text;
  final String avatarPath;
  final bool alignLeft;
  const _DialogueOverlay({ required this.text, required this.avatarPath, required this.alignLeft,});
  @override
  Widget build(BuildContext context) {
    final bubble = _SpeechBubble(text: text, tailOnLeft: alignLeft);
    final avatar = Container(
      width: 64, height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle, color: Colors.white,
        image: DecorationImage(image: AssetImage(avatarPath), fit: BoxFit.cover),
        boxShadow: const [ BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))],
      ),
    );
    return Row(
      mainAxisAlignment: alignLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: alignLeft
          ? [avatar, const SizedBox(width: 10), Expanded(child: bubble)]
          : [Expanded(child: bubble), const SizedBox(width: 10), avatar],
    );
  }
}
class _SpeechBubble extends StatelessWidget {
  // ...
  final String text;
  final bool tailOnLeft;
  const _SpeechBubble({required this.text, required this.tailOnLeft});
  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Text( text, softWrap: true, overflow: TextOverflow.ellipsis, maxLines: 3,
        style: const TextStyle( fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
      ),
    );
    final tail = CustomPaint(
      size: const Size(16, 10),
      painter: _TailPainter(color: Colors.white, isLeft: tailOnLeft),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        box,
        Positioned( bottom: -8, left: tailOnLeft ? 16 : null, right: tailOnLeft ? null : 16, child: tail,),
      ],
    );
  }
}
class _TailPainter extends CustomPainter {
  // ...
  final Color color;
  final bool isLeft;
  const _TailPainter({required this.color, required this.isLeft});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..style = PaintingStyle.fill;
    final path = Path();
    if (isLeft) {
      path ..moveTo(0, size.height) ..lineTo(size.width, size.height) ..lineTo(size.width * 0.45, 0);
    } else {
      path ..moveTo(size.width, size.height) ..lineTo(0, size.height) ..lineTo(size.width * 0.55, 0);
    }
    path.close();
    canvas.drawPath(path, p);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}