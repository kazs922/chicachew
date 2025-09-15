// lib/features/brush_guide/presentation/live_brush_page.dart
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // HapticFeedback, MissingPluginException, MethodChannel
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

// 앱 내부 의존
import 'package:chicachew/core/ml/brush_model_engine.dart';
import 'package:chicachew/core/ml/postprocess.dart';
import 'package:chicachew/core/tts/tts_manager.dart';
import 'package:chicachew/core/ml/brush_predictor.dart';
import 'package:chicachew/core/landmarks/mediapipe_tasks.dart'; // ✅ MediaPipe Tasks 브리지 (싱글턴)
import '../../brush_guide/application/story_director.dart';
import '../../brush_guide/application/radar_progress_engine.dart';
import '../../brush_guide/presentation/radar_overlay.dart';

// ✅ 결과 페이지
import 'package:chicachew/features/brush_guide/presentation/brush_result_page.dart';

// ────────────────────────────────────────────────────────────────────
// 상수
// ────────────────────────────────────────────────────────────────────
const int kBrushZoneCount = 13;
const int kSequenceLength = 30;    // 엔진 로드시 덮어씀
const int kFeatureDimension = 108; // 엔진 로드시 덮어씀

const bool kDemoMode = false;

// MediaPipe 사용 여부 (true: MediaPipe Tasks)
const bool kUseMpTasks = true;

// 화면 오버레이 라인/박스 숨김(텍스트 배너만 노출)
const bool kShowFaceGuide = false;

// 안정화/게이트 파라미터
// ▼ 버퍼 에러/얼굴 인식 빈도 안정화를 위해 범위 조금 타이트하게
const double kMinRelFace   = 0.30;  // 얼굴 높이 / 프레임 높이 (정규화 하한)
const double kMaxRelFace   = 0.60;  // (정규화 상한)
const double kMinLuma      = 0.12;  // Y 평균 밝기(0~1) 하한
const double kCenterJumpTol = 0.12; // 직전 프레임 대비 중심 이동 허용치(프리뷰 비율)
const double kFeatEmaAlpha  = 0.60; // 특징 EMA 알파
const double kPosTol        = 0.08; // 중앙 정렬 허용치(비율)
const int    kOkFlashMs     = 1200; // “범위 내에” 배지 노출 시간(ms)

// MediaPipe 프레임 전송 쓰로틀 (전송량 낮춰 안정화)
const int kMpSendIntervalMs = 120;  // ≈8~12fps

// 좌표 로깅 옵션
const bool kLogLandmarks = true;
const Duration kLmLogInterval = Duration(milliseconds: 800);

String chicachuAssetOf(String variant) => 'assets/images/$variant.png';
const String kCavityAsset = 'assets/images/cavity.png';

enum _CamState { idle, requesting, denied, granted, noCamera, initError, ready }

// ────────────────────────────────────────────────────────────────────
// 얼굴 앵커 컨테이너
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

class LiveBrushPage extends StatefulWidget {
  final String chicachuVariant;
  const LiveBrushPage({super.key, this.chicachuVariant = 'molar'});

  @override
  State<LiveBrushPage> createState() => _LiveBrushPageState();
}

class _LiveBrushPageState extends State<LiveBrushPage>
    with WidgetsBindingObserver {
  // ── 게임/스토리/진행 ───────────────────────────────────────────
  late final StoryDirector _director;
  late final RadarProgressEngine _progress;
  final TtsManager _ttsMgr = TtsManager.instance;

  ShowMessage? _dialogue;
  DateTime _dialogueUntil = DateTime.fromMillisecondsSinceEpoch(0);

  FinaleResult? _finale;
  double _advantage = 0.0;
  final Set<int> _spokenCompleteZoneIdxs = {};
  bool _finaleTriggered = false;

  // ✅ 결과페이지용 최근 점수 스냅샷(0..1)
  List<double> _lastScores = List.filled(kBrushZoneCount, 0.0);

  // ── 카메라 ────────────────────────────────────────────────────
  CameraController? _cam;
  bool _busy = false;         // 모델 추론 루프 busy
  int _throttle = 0;          // 모델 추론 쓰로틀
  bool _streamOn = false;
  bool _camDisposing = false;

  _CamState _camState = _CamState.idle;
  String _camError = '';

  // ── 모델 ──────────────────────────────────────────────────────
  bool _modelReady = false;
  String _modelError = '';

  // 시퀀스 링버퍼
  int _t = kSequenceLength;
  int _d = kFeatureDimension;
  late Float32List _seqBuf;
  int _seqCount = 0;
  int _seqWrite = 0;

  // Predictor (softmax/argmax/라벨 매핑)
  late final BrushPredictor _pred;
  InferenceResult? _last; // 최근 예측(라벨/확률)

  // ── MediaPipe Tasks 브리지 ─────────────────────────────────────
  StreamSubscription<MpEvent>? _mpSub;
  DateTime _lastFaceUpdateAt = DateTime.fromMillisecondsSinceEpoch(0);

  // 프리뷰 좌표의 얼굴 박스
  Rect? _faceRectInPreview;
  double? _yawDeg, _pitchDeg, _rollDeg;

  // 게이트/안정화 상태값
  double? _lastRel;            // 얼굴 상대 크기 (정규화 높이)
  bool _inRange = true;        // 거리 게이트 통과 여부
  double _lastLuma = 1;        // 최근 밝기(0~1)
  bool _lastStable = true;     // 얼굴 중심 급격 이동 여부
  Offset? _prevFaceCenter;     // 프리뷰 기준 이전 얼굴 중심
  bool _feedThisFrame = false; // 이 프레임 특징을 시퀀스에 넣었는지

  // 특징 EMA
  Float32List? _lastFeatD;

  // 이전 프레임의 '위치' 특징 벡터 (54차원)
  Float32List? _prevPositionalFeat;

  // 사용자 안내 텍스트 배너
  String? _gateMsg;                       // “가까이/멀리/중앙” 안내
  DateTime _okMsgUntil = DateTime(0);     // 성공 배지 노출 만료 시각

  // 얼굴/손 랜드마크 (모두 정규화 좌표 0..1 로 저장)
  List<Offset>? _lastFaceLandmarks2D;      // 얼굴 랜드마크 (nx, ny)
  List<List<double>>? _lastHandLandmarks;  // 손 랜드마크 (nx, ny, nz?)

  // 얼굴 박스(정규화 좌표계)
  Rect? _lastFaceBoxNorm;

  // 로깅 타임스탬프
  DateTime _lastFaceLmLogAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastHandLmLogAt = DateTime.fromMillisecondsSinceEpoch(0);

  // ── MediaPipe 전송 상태 ───────────────────────────────────────
  bool _mpSending = false;
  int _mpLastSentMs = 0;

  // ✅ 자동 보정/진단 토글들
  bool _swapUV = false;        // U/V 뒤바뀜 보정
  int? _forceRotDeg;           // 0/90/180/270 강제 회전
  bool _previewEnabled = true; // 프리뷰 임시 off용
  int _framesSent = 0;         // 진단 로그용

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

    // 진행/스토리
    _progress = RadarProgressEngine(
      tickInterval: const Duration(seconds: 1),
      ticksTargetPerZone: 10,
    );
    _director = StoryDirector(ticksTargetPerZone: 10);

    _progress.progressStream.listen((p) {
      _director.updateProgress(p);
      _lastScores = p; // ✅ 결과 스냅샷 저장
      if (!_finaleTriggered && _allFull(p)) {
        _triggerFinaleOnce(source: 'progress');
      }
    });
    _director.stream.listen(_onStoryEvent);

    _progress.start();
    _director.start();
    _ttsMgr.init();

    // 모델 래퍼
    _pred = BrushPredictor();

    // MediaPipe Tasks 초기화(이벤트 구독 시작)
    if (kUseMpTasks) {
      _initMpTasks();
    }

    _boot();
  }

  Future<void> _initMpTasks() async {
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
    if (landmarks.isEmpty) return;

    // 정규화 좌표(0..1)를 그대로 사용
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

    // 프리뷰 좌표계로 매핑 + 중심 이동 안정화 체크
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

    // 거리 게이트 (정규화 기준)
    final rel = faceBoxNorm.height.clamp(0.0, 1.0);
    _lastRel = rel;
    _inRange = (rel >= kMinRelFace) && (rel <= kMaxRelFace);

    // 좌표 샘플 로그 (주기 제한)
    _logFaceLmSampleNorm(
      faceBoxNorm: faceBoxNorm,
      ptsNorm: ptsNorm,
      rel: rel,
    );

    // 안내 메시지 (거리 → 중앙)
    String? msg;
    if (!_inRange) {
      msg = (rel < kMinRelFace) ? '조금 더 가까이 와주세요' : '조금만 멀리 떨어져 주세요';
    } else {
      final target = _targetRect(preview);
      final ndx = (mapped.center.dx - target.center.dx) / target.width;
      final ndy = (mapped.center.dy - target.center.dy) / target.height;

      if (ndx > kPosTol)       msg = '얼굴을 조금 왼쪽으로 이동해 주세요';
      else if (ndx < -kPosTol) msg = '얼굴을 조금 오른쪽으로 이동해 주세요';
      else if (ndy > kPosTol)  msg = '얼굴을 조금 위로 올려주세요';
      else if (ndy < -kPosTol) msg = '얼굴을 조금 아래로 내려주세요';
      else                     msg = null;
    }

    setState(() {
      _faceRectInPreview = mapped;
      _yawDeg = _pitchDeg = _rollDeg = null; // (원하면 추가 구현)
      if (msg == null) {
        _okMsgUntil = DateTime.now().add(const Duration(milliseconds: kOkFlashMs));
        _gateMsg = null;
      } else {
        _gateMsg = msg;
        _okMsgUntil = DateTime(0);
      }
    });

    // 얼굴 랜드마크/박스 저장(정규화 좌표)
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
    _mpSub?.cancel(); // ✅ 브릿지 구독만 해제
    super.dispose();
  }

  Future<void> _boot() async {
    if (kDemoMode) {
      if (mounted) setState(() => _camState = _CamState.ready);
      _startDemo();
      return;
    }

    if (mounted) {
      setState(() {
        _camState = _CamState.requesting;
        _camError = '';
        _modelError = '';
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

    // 모델/카메라 병렬 초기화
    await Future.wait([_initCamera(), _loadModel()]);

    if (mounted && _cam?.value.isInitialized == true && _modelReady) {
      await _startStream();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        if (mounted) {
          setState(() {
            _camState = _CamState.noCamera;
            _camError = '카메라 장치를 찾을 수 없습니다.';
          });
        }
        return;
      }

      final front = cams.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );

      await _disposeCamSafely(); // 기존 컨트롤러 정리

      final controller = CameraController(
        front,
        ResolutionPreset.low, // ▼ 버퍼 여유 확보 (필요시 low로 상향)
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      _cam = controller;
      setState(() => _camState = _CamState.ready);
    } catch (e, st) {
      debugPrint('Camera init error: $e\n$st');
      if (mounted) {
        setState(() {
          _camState = _CamState.initError;
          _camError = '$e';
        });
      }
    }
  }

  Future<void> _loadModel() async {
    try {
      await BrushModelEngine.I.load(); // 기본: assets/models/brush_zone.tflite

      if (BrushModelEngine.I.isSequenceModel) {
        _t = BrushModelEngine.I.seqT;
        _d = BrushModelEngine.I.seqD;

        _seqBuf   = Float32List(_t * _d);
        _seqCount = 0;
        _seqWrite = 0;
      }

      await _pred.init(); // 라벨 로드 등
      if (!mounted) return;
      setState(() { _modelReady = true; _modelError = ''; });
    } catch (e, st) {
      debugPrint('Model load error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _modelReady = false;
        _modelError = '$e';
      });
    }
  }

  Future<void> _startStream() async {
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized || _streamOn) return;
    try {
      _streamOn = true;
      await cam.startImageStream(_onImage);
    } catch (e) {
      _streamOn = false;
      rethrow;
    }
  }

  Future<void> _disposeCamSafely() async {
    final oldController = _cam;
    if (oldController == null) return;

    _streamOn = false;
    _camDisposing = true;
    _cam = null;

    if (mounted) setState(() {}); // 프리뷰 제거
    await Future.delayed(const Duration(milliseconds: 150));

    try { await oldController.stopImageStream(); } catch (_) {}
    try { await oldController.dispose(); } catch (_) {}

    if (mounted) _camDisposing = false;
  }

  void _stopPipelines() {
    _disposeCamSafely();
    try { MpTasksBridge.instance.stop(); } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (_cam == null && state != AppLifecycleState.resumed) {
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      await _disposeCamSafely();
      try { MpTasksBridge.instance.stop(); } catch (_) {}
    } else if (state == AppLifecycleState.resumed) {
      if (_cam == null) {
        await _boot();
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
    if (_cam == null) return 0;
    final sensor = _cam!.description.sensorOrientation;
    final isFront = _cam!.description.lensDirection == CameraLensDirection.front;
    final dev = _cam!.value.deviceOrientation; // ✅ 플러그인 값
    int device = switch (dev) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
      _ => 0,
    };

    return isFront ? (sensor + device) % 360 : (sensor - device + 360) % 360;
  }

  // ── MediaPipe로 프레임 전송 (Android: YUV_420_888 planes) ──────────────────
  Future<void> _sendFrameToMp(CameraImage img) async {
    if (!kUseMpTasks) return;
    if (!Platform.isAndroid) return; // iOS는 별도 경로 사용

    final now = DateTime.now().millisecondsSinceEpoch;
    if (_mpSending || now - _mpLastSentMs < kMpSendIntervalMs) return;

    final c = _cam;
    if (c == null) return;

    final rot = _forceRotDeg ?? _computeRotationDegrees(); // ✅ 강제 회전 우선

    _mpSending = true;
    _mpLastSentMs = now;
    try {
      if (img.planes.length < 3) return;

      // ✅ U/V 스왑 보정
      final y = img.planes[0];
      final u = _swapUV ? img.planes[2] : img.planes[1];
      final v = _swapUV ? img.planes[1] : img.planes[2];

      _framesSent++;
      if (_framesSent == 1) {
        debugPrint('[MP] first frame rot=$rot wh=${img.width}x${img.height} '
            'Yrow=${y.bytesPerRow}, Urow=${u.bytesPerRow}(ps=${u.bytesPerPixel}), '
            'Vrow=${v.bytesPerRow}(ps=${v.bytesPerPixel}), swapUV=$_swapUV');
      }

      await MpTasksBridge.instance.processYuv420Planes(
        y: y.bytes,
        u: u.bytes,
        v: v.bytes,
        width: img.width,
        height: img.height,
        yRowStride: y.bytesPerRow,
        uRowStride: u.bytesPerRow,
        vRowStride: v.bytesPerRow,
        uPixelStride: u.bytesPerPixel ?? 1,
        vPixelStride: v.bytesPerPixel ?? 1,
        rotationDeg: rot,     // 0/90/180/270
        timestampMs: now,
      );
    } catch (e) {
      debugPrint('[MP] processYuv420Planes error: $e');
    } finally {
      _mpSending = false;
    }
  }

  // ── 유틸 ───────────────────────────────────────────────────────
  Float32List _resizeCHWNearest(
      Float32List src, int srcH, int srcW, int dstH, int dstW) {
    if (srcH == dstH && srcW == dstW) return src;
    final out = Float32List(3 * dstH * dstW);
    for (int c = 0; c < 3; c++) {
      for (int y = 0; y < dstH; y++) {
        final sy = (y * srcH) ~/ dstH;
        for (int x = 0; x < dstW; x++) {
          final sx = (x * srcW) ~/ dstW;
          out[(c * dstH + y) * dstW + x] =
          src[(c * srcH + sy) * srcW + sx];
        }
      }
    }
    return out;
  }

  Float32List _chw224ToGrayHW(Float32List chw224) {
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

  Float32List _resizeGRAYNearest(
      Float32List src, int srcH, int srcW, int dstH, int dstW) {
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
    const int D = 224;
    final int srcW = img.width;
    final int srcH = img.height;

    final pY = img.planes[0];
    final pU = img.planes[1];
    final pV = img.planes[2];
    final yBytes = pY.bytes;
    final uBytes = pU.bytes;
    final vBytes = pV.bytes;
    final yRow = pY.bytesPerRow;
    final uRow = pU.bytesPerRow;
    final vRow = pV.bytesPerRow;
    final uPix = pU.bytesPerPixel ?? 1;
    final vPix = pV.bytesPerPixel ?? 1;

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

        final int Y = yBytes[yi];
        final int U = uBytes[ui];
        final int V = vBytes[vi];

        final double c = (Y - 16).toDouble();
        final double d = (U - 128).toDouble();
        final double e = (V - 128).toDouble();

        double r = 1.164 * c + 1.596 * e;
        double g = 1.164 * c - 0.392 * d - 0.813 * e;
        double b = 1.164 * c + 2.017 * d;

        r = (r / 255.0).clamp(0.0, 1.0);
        g = (g / 255.0).clamp(0.0, 1.0);
        b = (b / 255.0).clamp(0.0, 1.0);

        out[idxR++] = r;
        out[idxG++] = g;
        out[idxB++] = b;
      }
    }
    return out;
  }

  double _estimateLuma01(CameraImage img) {
    final pY = img.planes.first;
    final y = pY.bytes;
    if (y.isEmpty) return 1.0;
    int sum = 0, cnt = 0;
    final step = 16; // 샘플 간격(큰 값일수록 가벼움)
    for (int i = 0; i < y.length; i += step) {
      sum += y[i];
      cnt++;
    }
    final avg = sum / (cnt * 255.0);
    return avg.clamp(0.0, 1.0);
  }

  Float32List _emaFeature(Float32List cur) {
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
    final w = size.width * 0.72;
    final h = size.height * 0.58;
    final cx = size.width * 0.5;
    final cy = size.height * 0.52; // 중앙보다 약간 아래
    return Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);
  }

  Future<void> _onImage(CameraImage img) async {
    if (!mounted) return;

    // ✅ MediaPipe에 프레임 전송 (얼굴/손 이벤트용)
    await _sendFrameToMp(img);

    // 조명 추정
    _lastLuma = _estimateLuma01(img);

    // 얼굴 신호가 오래 끊겼으면 사용자 배너만 갱신
    final nowT = DateTime.now();
    final stale = nowT.difference(_lastFaceUpdateAt) > const Duration(milliseconds: 800);
    if (stale) {
      setState(() {
        _faceRectInPreview = null;
        _gateMsg = '얼굴이 보이도록 카메라 중앙에 맞춰주세요';
        _okMsgUntil = DateTime(0);
      });

      // ✅ 자동 보정 워치독: 얼굴 이벤트가 한동안 안 오면 단계적으로 보정
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

    // 모델 추론 쓰로틀 (2프레임에 1회)
    if (_busy || !_modelReady || !BrushModelEngine.I.isReady) return;
    _throttle = (_throttle + 1) % 2;
    if (_throttle != 0) return;

    _busy = true;
    try {
      // 게이트 판단: 거리/조명/얼굴 안정성
      final allowByDist = (_lastRel == null) ? true : _inRange;
      final allowByLuma = _lastLuma >= kMinLuma;
      final allowByStable = _lastStable;
      final allow = allowByDist && allowByLuma && allowByStable;
      _feedThisFrame = allow;

      if (!allow) return; // 특징을 시퀀스에 넣지 않음

      if (BrushModelEngine.I.isSequenceModel) {
        // 1) 특징 벡터 생성 (얼굴 필수, 손은 선택)
        final featD = _buildCoordFeatureD(); // 수정된 함수 호출
        if (featD == null || featD.length != _d) return;

        // 2) 시퀀스 버퍼에 푸시
        _pushFeature(featD);

        // 3) 시퀀스가 충분히 차면 추론 실행
        if (_seqCount >= _t && _pred.isReady) {
          final window2D = _windowAs2D();
          final res = _pred.inferFromWindow(window2D);
          _last = res;
          onModelProbsUpdate(res.probs);
          onModelZoneUpdate(res.index);
        }
      } else {
        // ===== 이미지 모델 경로 =====
        final Float32List chw224 = Float32List.fromList(
          _yuv420ToCHW224Safe(img, mirror: true),
        );

        final needH = BrushModelEngine.I.inputH;
        final needW = BrushModelEngine.I.inputW;
        final needC = BrushModelEngine.I.inputC;

        late final Float32List inputBuf;
        if (needC == 3) {
          inputBuf = _resizeCHWNearest(chw224, 224, 224, needH, needW);
        } else {
          final gray224 = _chw224ToGrayHW(chw224);
          inputBuf = _resizeGRAYNearest(gray224, 224, 224, needH, needW);
        }

        final logits = BrushModelEngine.I.inferFloat32(inputBuf);
        final probs = softmax(logits);
        final topIdx = top1(probs).index;
        onModelProbsUpdate(probs);
        onModelZoneUpdate(topIdx);
      }
    } catch (e) {
      debugPrint('infer error: $e');
    } finally {
      _busy = false;
    }
  }

  // 정규화 얼굴 박스(0..1) → 프리뷰 좌표
  Rect _mapNormRectToPreview({
    required Rect normRect,
    required Size previewSize,
    bool mirror = true,
  }) {
    double l = normRect.left;
    double r = normRect.right;
    final t = normRect.top;
    final b = normRect.bottom;

    if (mirror) {
      final nl = 1.0 - r;
      final nr = 1.0 - l;
      l = nl; r = nr;
    }

    final left   = l * previewSize.width;
    final top    = t * previewSize.height;
    final width  = (r - l) * previewSize.width;
    final height = (b - t) * previewSize.height;

    return Rect.fromLTWH(left, top, width, height);
  }

  void _pushFeature(Float32List f) {
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
    final out = List.generate(_t, (_) => List.filled(_d, 0.0));
    final start = (_seqCount < _t) ? 0 : _seqWrite; // 가장 오래된 프레임부터
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

  void onModelProbsUpdate(List<double> probs) =>
      _progress.reportZoneProbs(probs, threshold: 0.25);

  void _onStoryEvent(StoryEvent e) async {
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
    if (!mounted) return;
    setState(() {
      _dialogue = msg;
      _dialogueUntil = DateTime.now().add(d);
    });
  }

  List<double> _normalizedScores(List<double> scores) {
    if (scores.any((v) => v > 1.0)) {
      return scores.map((v) => (v / 100.0).clamp(0.0, 1.0)).toList();
    }
    return scores.map((v) => v.clamp(0.0, 1.0)).toList();
  }

  bool _allFull(List<double> src) {
    final vals = (src.any((v) => v > 1.0))
        ? src.map((v) => v / 100.0).toList()
        : src;
    return vals.length == kBrushZoneCount && vals.every((v) => v >= 0.999);
  }

  int _suggestActiveIndex(List<double> scores) {
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

    if (kDemoMode) {
      _stopDemo();
    } else {
      await _disposeCamSafely();
    }
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

    // ✅ 결과 페이지로 이동
    if (!mounted) return;
    final scores01 = _normalizedScores(_lastScores); // 0..1로 정규화
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BrushResultPage(
          scores01: scores01,
          threshold: 0.60, // 필요시 조정
          onDone: () {
            // TODO: 완료 후 홈 배지 채우기/상태 갱신이 필요하면 여기 연결
          },
        ),
      ),
    );

    // (선택) 결과에서 돌아온 뒤 동작이 필요하면 여기서 처리
  }

  Timer? _demoTm;
  int _demoZone = 0, _demoTicks = 0;
  final _rnd = Random();

  void _startDemo() {
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
    _demoTm?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final showDialogue = now.isBefore(_dialogueUntil) && _dialogue != null;

    final cam = _cam;
    final showPreview = !kDemoMode &&
        !_camDisposing &&
        cam != null &&
        cam.value.isInitialized &&
        _previewEnabled; // ✅ 프리뷰 토글 반영

    final debugInStr = BrushModelEngine.I.isSequenceModel
        ? 'SEQ:${BrushModelEngine.I.seqT}x${BrushModelEngine.I.seqD}'
        : 'in:${BrushModelEngine.I.inputH}x${BrushModelEngine.I.inputW}  C:${BrushModelEngine.I.inputC}${BrushModelEngine.I.isNHWC ? " NHWC" : " NCHW"}';

    final showOk = now.isBefore(_okMsgUntil);
    final showGuide = _gateMsg != null && _gateMsg!.isNotEmpty;

    return Scaffold(
      body: Stack(
        children: [
          // 배경
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFBFEAD6), Color(0xFFA5E1B2), Color(0xFFE8FCD8)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // 카메라 프리뷰
          if (showPreview)
            Positioned.fill(
              child: Builder(
                builder: (_) => CameraPreview(
                  cam!,
                  key: ValueKey(cam),
                ),
              ),
            ),

          if (showPreview && kShowFaceGuide)
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

          // 안내 배지
          if (showOk || showGuide)
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
                    color: showOk ? const Color(0xFF2E7D32) : Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))],
                  ),
                  child: Center(
                    child: Text(
                      showOk ? '범위 내에 들어왔습니다!' : _gateMsg!,
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

          // 카메라 준비 전/권한/오류 상태
          if (!kDemoMode && !showPreview)
            Positioned.fill(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam_off, size: 48, color: Colors.black45),
                      const SizedBox(height: 10),
                      Text(
                        _camState == _CamState.denied
                            ? '카메라 권한이 필요합니다'
                            : _camState == _CamState.noCamera
                            ? '카메라 장치를 찾을 수 없습니다'
                            : _camState == _CamState.initError
                            ? '카메라 초기화 실패'
                            : (_camDisposing ? '카메라 정리 중…' : '카메라 초기화 중…'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.black54, fontWeight: FontWeight.w600),
                      ),
                      if (_camState == _CamState.denied) ...[
                        const SizedBox(height: 8),
                        TextButton(
                            onPressed: openAppSettings,
                            child: const Text('설정에서 권한 열기')),
                      ],
                      if (_camState == _CamState.initError ||
                          _camState == _CamState.noCamera) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _boot,
                          child: const Text('다시 시도'),
                        ),
                      ],
                      if (_camError.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          _camError,
                          textAlign: TextAlign.center,
                          style:
                          const TextStyle(color: Colors.black45, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

          // 진행 HUD(레이더)
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

          // 좌상단 디버그 뱃지
          Positioned(
            left: 12,
            right: 12,
            top: MediaQuery.of(context).padding.top + 8,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                color: Colors.black54,
                child: Text(
                  kDemoMode
                      ? 'DEMO MODE'
                      : 'cam:${showPreview ? "ready" : (_camDisposing ? "disposing" : "init...")}  '
                      'state:${_camState.name}  '
                      'model:${_modelReady ? "ready" : "loading"}(${BrushModelEngine.I.backend})  '
                      'stream:${_streamOn ? "on" : "off"}  '
                      '$debugInStr  '
                      'dist:${_lastRel==null ? "n/a" : "${_inRange ? "ok" : "bad"} ${((_lastRel??0)*100).toStringAsFixed(0)}%"}  '
                      'luma:${(_lastLuma*100).toStringAsFixed(0)}%  '
                      'stab:${_lastStable ? "ok" : "shaky"}  '
                      'feed:${_feedThisFrame ? "on" : "skip"}  '
                      'rot:${_forceRotDeg ?? _computeRotationDegrees()}  '
                      'uv:${_swapUV ? "swapped" : "normal"}  '
                      'preview:${_previewEnabled ? "on" : "off"}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                  softWrap: true,
                  overflow: TextOverflow.fade,
                  maxLines: 4,
                ),
              ),
            ),
          ),

          // 모델 로드 에러 패널
          if (!_modelReady && _modelError.isNotEmpty)
            Positioned(
              right: 12,
              top: MediaQuery.of(context).padding.top + 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                ),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.redAccent, size: 18),
                    const Text('모델 로드 실패',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    TextButton(
                      onPressed: () async {
                        setState(() => _modelError = '');
                        await _loadModel();
                        if (mounted &&
                            _cam?.value.isInitialized == true &&
                            _modelReady &&
                            !_streamOn) {
                          await _startStream();
                          setState(() {});
                        }
                      },
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
            ),

          // 말풍선 대화
          if (showDialogue)
            Positioned(
              left: 12,
              right: 12,
              bottom: MediaQuery.of(context).padding.bottom + 120,
              child: _DialogueOverlay(
                text: _dialogue!.text,
                avatarPath: _avatarForSpeaker(_dialogue!.speaker),
                alignLeft: _dialogue!.speaker != Speaker.cavitymon,
              ),
            ),

          // 보스 HUD
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: _BossHud(advantage: _advantage),
          ),

          // 피날레 오버레이(시각적 효과용)
          if (_finale != null)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.55),
                alignment: Alignment.center,
                child: _FinaleView(result: _finale!),
              ),
            ),
        ],
      ),
    );
  }

  // ✅ =============================================================
  // ✅ 얼굴 앵커 + 좌표→특징D 빌더 (손은 선택, 얼굴은 필수) — 정규화 좌표 기반
  // ✅ =============================================================

  Rect _emaRect(Rect? prev, Rect cur, double alpha) {
    if (prev == null) return cur;
    double lerp(double a, double b) => a * (1 - alpha) + b * alpha;
    return Rect.fromLTRB(
      lerp(prev.left,   cur.left),
      lerp(prev.top,    cur.top),
      lerp(prev.right,  cur.right),
      lerp(prev.bottom, cur.bottom),
    );
  }

  _FaceAnchors? _getFaceAnchors() {
    final faceLms = _lastFaceLandmarks2D; // 정규화 좌표
    final boxNorm = _lastFaceBoxNorm;     // 정규화 박스

    // (A) MediaPipe 랜드마크로 정확한 6점
    if (faceLms != null && faceLms.length >= 300) {
      Offset? getMP(int i) => (i >= 0 && i < faceLms.length) ? faceLms[i] : null;
      final leftEye   = getMP(33);
      final rightEye  = getMP(263);
      final nose      = getMP(1);
      final chin      = getMP(152);
      final mouthLeft = getMP(61);
      final mouthRight= getMP(291);
      if ([leftEye, rightEye, nose, chin, mouthLeft, mouthRight].every((e) => e != null)) {
        return _FaceAnchors(
          leftEye: leftEye!, rightEye: rightEye!, nose: nose!,
          chin: chin!, mouthLeft: mouthLeft!, mouthRight: mouthRight!,
        );
      }
    }

    // (B) 박스만으로 근사
    if (boxNorm != null) {
      final cx = boxNorm.center.dx;
      final cy = boxNorm.center.dy;
      final w = boxNorm.width;
      final h = boxNorm.height;

      final leftEye   = Offset(boxNorm.left  + w * 0.35, boxNorm.top + h * 0.35);
      final rightEye  = Offset(boxNorm.left  + w * 0.65, boxNorm.top + h * 0.35);
      final nose      = Offset(cx,                boxNorm.top + h * 0.52);
      final chin      = Offset(cx,                boxNorm.bottom);
      final mouthLeft = Offset(boxNorm.left  + w * 0.40, boxNorm.top + h * 0.75);
      final mouthRight= Offset(boxNorm.left  + w * 0.60, boxNorm.top + h * 0.75);

      return _FaceAnchors(
        leftEye: leftEye,
        rightEye: rightEye,
        nose: nose,
        chin: chin,
        mouthLeft: mouthLeft,
        mouthRight: mouthRight,
      );
    }

    return null;
  }

  // 108D 특징 벡터 생성: 위치54(손42+얼굴12) + 속도54 — 모두 정규화 좌표(0..1)로 연산
  Float32List? _buildCoordFeatureD() {
    // 얼굴 anchor 6점 확보(필수)
    final anchors = _getFaceAnchors();
    if (anchors == null) {
      if (kLogLandmarks) {
        debugPrint('[FeatureBuild] SKIP: face anchors=null, hand=${_lastHandLandmarks?.length}');
      }
      return null;
    }

    // 손 21점 (정규화 좌표). 없으면 0으로 채움
    final handLmsNorm = _lastHandLandmarks;
    final List<Offset> handPts = (handLmsNorm == null || handLmsNorm.length < 21)
        ? List<Offset>.filled(21, Offset.zero)
        : handLmsNorm.map((p) => Offset(
      (p[0] as num).toDouble().clamp(0.0, 1.0),
      (p[1] as num).toDouble().clamp(0.0, 1.0),
    )).toList();

    // 변환 대상 포인트: 손 21 + 얼굴 6 = 총 27개
    final List<Offset> pts = [
      ...handPts,
      anchors.leftEye,
      anchors.rightEye,
      anchors.nose,
      anchors.chin,
      anchors.mouthLeft,
      anchors.mouthRight,
    ];

    // ── 정규화(원점=코, 스케일=눈간 거리, 롤=눈 수평, 피치=턱 수직) ──
    final nose = anchors.nose;
    final leftEye = anchors.leftEye;
    final rightEye = anchors.rightEye;
    final chin = anchors.chin;

    // 원점 이동
    final translated = pts.map((p) => p - nose).toList();

    // 스케일(눈간 거리)
    final eyeVec = rightEye - leftEye;
    final scale = eyeVec.distance;
    if (scale < 1e-6) return null;

    // 롤 보정 (눈 수평)
    final roll = -atan2(eyeVec.dy, eyeVec.dx);
    final cr = cos(roll), sr = sin(roll);
    final List<Offset> rolled = translated.map((p) {
      final x = (p.dx * cr - p.dy * sr) / scale;
      final y = (p.dx * sr + p.dy * cr) / scale;
      return Offset(x, y);
    }).toList();

    // 피치 보정 (턱이 수직 아래)
    final chinT = chin - nose;
    final chinRx = (chinT.dx * cr - chinT.dy * sr) / scale;
    final chinRy = (chinT.dx * sr + chinT.dy * cr) / scale;
    final pitch = -(atan2(chinRy, chinRx) - (pi / 2));
    final cp = cos(pitch), sp = sin(pitch);
    final List<Offset> norm = rolled.map((p) {
      final x = p.dx * cp - p.dy * sp;
      final y = p.dx * sp + p.dy * cp;
      return Offset(x, y);
    }).toList();

    // ── 위치 54D = 손(21*2=42) + 얼굴6점(12) ──
    final posD = _d ~/ 2; // 54
    final positional = Float32List(posD);
    int k = 0;

    // 손 21점
    for (int i = 0; i < 21 && k + 1 < posD; i++) {
      positional[k++] = norm[i].dx;
      positional[k++] = norm[i].dy;
    }

    // 얼굴 6점(pts 끝 6개 순서: LEye, REye, Nose, Chin, MouthL, MouthR)
    final base = norm.length - 6;
    for (int i = 0; i < 6 && k + 1 < posD; i++) {
      positional[k++] = norm[base + i].dx;
      positional[k++] = norm[base + i].dy;
    }

    while (k < posD) positional[k++] = 0.0;

    // ── 속도 54D ──
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

    // EMA로 한 번 더 부드럽게
    return _emaFeature(out);
  }

  // 좌표 로깅(정규화)
  void _logFaceLmSampleNorm({
    required Rect faceBoxNorm,
    required List<Offset> ptsNorm,
    required double rel,
  }) {
    if (!kLogLandmarks) return;
    final now = DateTime.now();
    if (now.isBefore(_lastFaceLmLogAt.add(kLmLogInterval))) return;
    _lastFaceLmLogAt = now;

    final n = ptsNorm.length;
    final picks = <int>[
      0,
      (n * 0.25).floor(),
      (n * 0.5).floor(),
      (n * 0.75).floor(),
      n - 1,
    ].where((i) => i >= 0 && i < n).toList();

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

// ─────────────────────────────────────────────────────────────────
// Face Align Overlay (가이드 + 힌트)
// ─────────────────────────────────────────────────────────────────

class FaceAlignOverlay extends StatelessWidget {
  final Size previewSize;          // 프리뷰(위젯) 크기
  final Rect? faceBoxInPreview;    // 프리뷰 좌표계의 얼굴 박스 (없으면 null)
  final double? yawDeg;            // (선택) 좌우 회전 각도
  final double? pitchDeg;          // (선택) 상하 회전 각도
  final double? rollDeg;           // (선택) 기울임 각도

  const FaceAlignOverlay({
    super.key,
    required this.previewSize,
    required this.faceBoxInPreview,
    this.yawDeg,
    this.pitchDeg,
    this.rollDeg,
  });

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
                ok: true, // 로직 단순화
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
  final Rect targetRect;
  const _GuidePainter({required this.targetRect});

  @override
  void paint(Canvas canvas, Size size) {
    // kShowFaceGuide=false 이면 렌더되지 않음
  }

  @override
  bool shouldRepaint(covariant _GuidePainter oldDelegate) =>
      oldDelegate.targetRect != targetRect;
}

class _FaceBoxPainter extends CustomPainter {
  final Rect faceRect;
  final bool ok;

  const _FaceBoxPainter({
    required this.faceRect,
    required this.ok,
  });

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



// ─────────────────────────────────────────────────────────────────
// 아래는 기존 HUD/말풍선/엔딩 뷰
// ─────────────────────────────────────────────────────────────────

class _BossHud extends StatelessWidget {
  final double advantage;
  const _BossHud({required this.advantage});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('치카츄 vs 캐비티몬',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: advantage,
            minHeight: 10,
            backgroundColor: Colors.red.withOpacity(0.3),
            valueColor:
            const AlwaysStoppedAnimation<Color>(Colors.lightBlueAccent),
          ),
        ),
      ],
    );
  }
}

class _FinaleView extends StatelessWidget {
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
        style: const TextStyle(
            color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _DialogueOverlay extends StatelessWidget {
  final String text;
  final String avatarPath;
  final bool alignLeft;
  const _DialogueOverlay({
    required this.text,
    required this.avatarPath,
    required this.alignLeft,
  });

  @override
  Widget build(BuildContext context) {
    final bubble = _SpeechBubble(text: text, tailOnLeft: alignLeft);
    final avatar = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        image:
        DecorationImage(image: AssetImage(avatarPath), fit: BoxFit.cover),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))
        ],
      ),
    );

    return Row(
      mainAxisAlignment:
      alignLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: alignLeft
          ? [avatar, const SizedBox(width: 10), Expanded(child: bubble)]
          : [Expanded(child: bubble), const SizedBox(width: 10), avatar],
    );
  }
}

class _SpeechBubble extends StatelessWidget {
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
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))
        ],
      ),
      child: Text(
        text,
        softWrap: true,
        overflow: TextOverflow.ellipsis,
        maxLines: 3,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
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
        Positioned(
          bottom: -8,
          left: tailOnLeft ? 16 : null,
          right: tailOnLeft ? null : 16,
          child: tail,
        ),
      ],
    );
  }
}

class _TailPainter extends CustomPainter {
  final Color color;
  final bool isLeft;
  const _TailPainter({required this.color, required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..style = PaintingStyle.fill;
    final path = Path();
    if (isLeft) {
      path
        ..moveTo(0, size.height)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width * 0.45, 0);
    } else {
      path
        ..moveTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..lineTo(size.width * 0.55, 0);
    }
    path.close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
