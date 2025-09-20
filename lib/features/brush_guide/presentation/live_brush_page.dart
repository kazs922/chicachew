// 📍 lib/features/brush_guide/presentation/live_brush_page.dart (최종 완성본)

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// 앱 내부 의존
import 'package:chicachew/core/ml/brush_model_engine.dart';
import 'package:chicachew/core/ml/postprocess.dart';
import 'package:chicachew/core/ml/brush_predictor.dart';
import 'package:chicachew/core/landmarks/mediapipe_tasks.dart';
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

const int kSequenceLength = 30;
const int kFeatureDimension = 108;

// ✅ 데모 모드 <-> 실사용 모드 전환 스위치
const bool kDemoMode = false; // 시연 시 true, 실제 카메라 사용 시 false

const bool kUseMpTasks = true;
const bool kShowFaceGuide = true; // 가이드 멘트를 위해 true 유지
const double kMinRelFace = 0.25;
const double kMaxRelFace = 0.70;
const double kMinLuma = 0.12;
const double kCenterJumpTol = 0.12;
const double kFeatEmaAlpha = 0.15; // 스무딩 강도 (낮을수록 부드러움)
const double kPosTol = 0.15;
const int kOkFlashMs = 1200;
const int kMpSendIntervalMs = 120;
const bool kLogLandmarks = false;
const Duration kLmLogInterval = Duration(milliseconds: 800);
String chicachuAssetOf(String variant) => 'assets/images/$variant.png';
const String kCavityAsset = 'assets/images/cavity.png';
enum _CamState { idle, requesting, denied, noCamera, initError, ready }

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

class LiveBrushPage extends ConsumerStatefulWidget {
  final String chicachuVariant;
  const LiveBrushPage({super.key, this.chicachuVariant = 'molar'});

  @override
  ConsumerState<LiveBrushPage> createState() => _LiveBrushPageState();
}

class _LiveBrushPageState extends ConsumerState<LiveBrushPage>
    with WidgetsBindingObserver {

  final double _coordOffsetX = -0.02;
  final double _coordOffsetY = 0.0;
  final double _coordScaleX = 1.20;
  final double _coordScaleY = 1.0;

  late final StoryDirector _director;
  late final RadarProgressEngine _progress;
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
  int _t = kSequenceLength;
  int _d = kFeatureDimension;
  late Float32List _seqBuf;
  int _seqCount = 0;
  int _seqWrite = 0;
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

  List<double>? _debugProbs;
  List<String> _zoneLabels = [];

  Timer? _timer;
  int _elapsedSeconds = 0;

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

    _progress = RadarProgressEngine();
    _director = StoryDirector();
    _director.stream.listen(_onStoryEvent);
    _loadZoneLabels();
    _startTimer();

    // ✅ [수정] 모드와 관계없이 항상 카메라를 켜고, MediaPipe를 시작합니다.
    _initMpTasks();

    if (kDemoMode) {
      _director.progressStream.listen((scores) {
        if (mounted) setState(() => _lastScores = scores);
      });
      _director.startDemoSequence();
    } else {
      _progress.progressStream.listen((p) {
        _director.updateProgress(p);
        _lastScores = p;
        if (!_finaleTriggered && _allFull(p)) {
          _triggerFinaleOnce(source: 'progress');
        }
      });
      _progress.start();
      _director.start();
    }
  }

  Future<void> _loadZoneLabels() async {
    try {
      final labelsString = await rootBundle.loadString('assets/brush_zone.txt');
      setState(() {
        _zoneLabels = labelsString.split('\n').where((s) => s.isNotEmpty).toList();
      });
    } catch (e) {
      //
    }
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
          _onMpFace(e.landmarks);
          _lastFaceUpdateAt = DateTime.now();
        } else if (e is MpHandEvent) {
          _lastHandLandmarks = e.landmarks;
        }
      });
    } catch (e) {
      //
    }
  }

  void _onMpFace(List<List> landmarks) {
    if (landmarks.isEmpty || !mounted) return;

    final ptsNormUncorrected = <Offset>[];
    for (final p in landmarks) {
      if (p.length < 2) continue;
      final double nx = (p[0] as num).toDouble().clamp(0.0, 1.0);
      final double ny = (p[1] as num).toDouble().clamp(0.0, 1.0);
      ptsNormUncorrected.add(Offset(nx, ny));
    }
    if (ptsNormUncorrected.isEmpty) return;

    final ptsNorm = ptsNormUncorrected.map((p) {
      return Offset((p.dx * _coordScaleX) + _coordOffsetX, (p.dy * _coordScaleY) + _coordOffsetY);
    }).toList();

    double minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9;
    for (final p in ptsNorm) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }

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
    if (!kDemoMode) _progress.stop();
    _director.dispose();
    _mpSub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }


  Future<void> _bootCamera() async {
    if (_camState != _CamState.idle || !mounted) return;

    try {
      setState(() => _camState = _CamState.requesting);
      var camStatus = await Permission.camera.status;
      if (!camStatus.isGranted) camStatus = await Permission.camera.request();

      var micStatus = await Permission.microphone.status;
      if (!micStatus.isGranted) micStatus = await Permission.microphone.request();

      if (!mounted) return;

      if (!camStatus.isGranted || !micStatus.isGranted) {
        setState(() => _camState = _CamState.denied);
        return;
      }

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
      await _disposeCamSafely();
      final controller = CameraController(
        front,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _cam = controller;
      await _startStream();
      if (mounted) {
        setState(() => _camState = _CamState.ready);
      }
    } catch (e, st) {
      //
      if (mounted) {
        String errorMessage = '$e';
        if (e is CameraException) {
          if (e.code == 'CameraAccessDenied') {
            errorMessage =
            '카메라 접근 권한이 거부되었습니다. 기기 설정에서 권한을 허용해주세요.';
          }
        }
        setState(() {
          _camState = _CamState.initError;
          _camError = errorMessage;
        });
      }
    }
  }

  Future<void> _startStream() async {
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized || _streamOn) return;
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
      //
    }
  }

  Future<void> _disposeCamSafely() async {
    final oldController = _cam;
    if (oldController == null) return;
    _streamOn = false;
    _camDisposing = true;
    _cam = null;
    if (mounted) setState(() {});
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
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _stopPipelines();
      _stopTimer();
    } else if (state == AppLifecycleState.resumed) {
      final modelReady = kDemoMode || ref.read(brushPredictorProvider).hasValue;
      if (modelReady && _cam == null) {
        _bootCamera();
      } else if (_cam != null) {
        _startTimer();
      }
      if (!kDemoMode && kUseMpTasks) {
        try {
          await MpTasksBridge.instance
              .start(face: true, hands: true, useNativeCamera: false);
        } catch (_) {}
      }
    }
  }

  int _computeRotationDegrees() {
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
      await MpTasksBridge.instance.processYuv420Planes(
        y: y.bytes, u: u.bytes, v: v.bytes,
        width: img.width, height: img.height,
        yRowStride: y.bytesPerRow, uRowStride: u.bytesPerRow, vRowStride: v.bytesPerRow,
        uPixelStride: u.bytesPerPixel ?? 1, vPixelStride: v.bytesPerPixel ?? 1,
        rotationDeg: rot, timestampMs: now,
      );
    } catch (e) {
      //
    } finally {
      _mpSending = false;
    }
  }

  // ✅ [추가] 스무딩(EMA) 필터 함수 추가
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
    final cy = size.height * 0.52;
    return Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);
  }

  Future<void> _onImage(CameraImage img) async {
    if (kDemoMode || _busy || !mounted) return;
    _busy = true;

    try {
      final pred = ref.read(brushPredictorProvider).value;
      await _sendFrameToMp(img);
      if (!mounted) return;

      final nowT = DateTime.now();
      final stale = nowT.difference(_lastFaceUpdateAt) > const Duration(milliseconds: 800);
      if (stale) {
        setState(() {
          _faceRectInPreview = null;
          _gateMsg = '얼굴이 보이도록 카메라 중앙에 맞춰주세요';
          _okMsgUntil = DateTime(0);
        });
      }

      if (pred != null && BrushModelEngine.I.isReady) {
        _throttle = (_throttle + 1) % 2;
        if (_throttle == 0) {
          final allowByDist = (_lastRel == null) ? true : _inRange;
          final allowByLuma = _estimateLuma01(img) >= kMinLuma;
          final allowByStable = _lastStable;
          final allow = allowByDist && allowByLuma && allowByStable;
          _feedThisFrame = allow;

          if (allow) {
            if (BrushModelEngine.I.isSequenceModel) {
              final featD = _buildCoordFeatureD();
              if (featD != null && featD.length == _d) {
                _pushFeature(featD);
                if (_seqCount >= _t) {
                  final window2D = _windowAs2D();
                  final res = pred.inferFromWindow(window2D);
                  _last = res;
                  onModelProbsUpdate(res.probs);
                  onModelZoneUpdate(res.index);
                }
              }
            }
          }
        }
      }
    } catch (e) {
      //
    } finally {
      _busy = false;
    }
  }

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

  void onModelZoneUpdate(int? zoneIndex) =>
      _progress.reportZoneIndex(zoneIndex);

  void onModelProbsUpdate(List<double> probs) {
    if (!kDemoMode) _progress.reportZoneProbs(probs, threshold: 0.25);
    if (mounted) {
      setState(() {
        _debugProbs = probs;
      });
    }
  }


  void _onStoryEvent(StoryEvent e) {
    if (!mounted) return;
    if (e is ShowMessage) {
      _showDialogue(e, e.duration);
      HapticFeedback.lightImpact();
    } else if (e is ShowHintForZone) {
      final text = '${e.zoneName}를 닦아볼까?';
      _showDialogue(
        ShowMessage(text, duration: e.duration, speaker: Speaker.chikachu),
        e.duration,
      );
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
      if (!kDemoMode && !_finaleTriggered &&
          _spokenCompleteZoneIdxs.length >= kBrushZoneCount) {
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
    final vals =
    (src.any((v) => v > 1.0)) ? src.map((v) => v / 100.0).toList() : src;
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

  void _triggerFinaleOnce(
      {String source = 'unknown', FinaleResult? result}) async {
    if (_finaleTriggered || !mounted) return;
    _finaleTriggered = true;

    _stopTimer();

    if (!kDemoMode) {
      await _disposeCamSafely();
      _progress.stop();
    }

    setState(() => _finale = result ?? FinaleResult.win);
    final line = (result == FinaleResult.lose)
        ? '오늘은 아쉽지만, 내일은 꼭 이겨보자!'
        : '모든 구역 반짝반짝! 오늘 미션 완벽 클리어! ✨';
    _showDialogue(
      ShowMessage(line,
          duration: const Duration(seconds: 3), speaker: Speaker.chikachu),
      const Duration(seconds: 3),
    );
    HapticFeedback.heavyImpact();
    if (!mounted) return;
    await Future.delayed(const Duration(seconds: 5));
    if (!mounted) return;
    final scores01 = _normalizedScores(_lastScores);
    context.push('/mouthwash', extra: scores01);
  }

  @override
  Widget build(BuildContext context) {
    final modelAsyncValue = ref.watch(brushPredictorProvider);

    if (_camState == _CamState.idle) {
      _bootCamera();
    }

    if (kDemoMode) {
      return Scaffold(body: _buildCameraPreview());
    }

    ref.listen(brushPredictorProvider, (_, state) {
      if (state.hasValue && _camState == _CamState.idle) {
        _bootCamera();
      }
    });

    return Scaffold(
      body: modelAsyncValue.when(
        loading: () => _buildStatusView('양치질 분석 모델을 준비 중입니다...'),
        error: (err, stack) => _buildStatusView('모델 로딩 실패: $err'),
        data: (predictor) {
          switch (_camState) {
            case _CamState.ready:
              return _buildCameraPreview();
            case _CamState.denied:
              return _buildPermissionDeniedView();
            case _CamState.initError:
              return _buildCameraErrorView();
            case _CamState.noCamera:
              return _buildStatusView('카메라 장치를 찾을 수 없습니다.', showRetry: true);
            default:
              return _buildStatusView('카메라를 준비 중입니다...');
          }
        },
      ),
    );
  }

  Widget _buildStatusView(String message, {bool showRetry = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!showRetry) const CircularProgressIndicator(),
          if (showRetry) const Icon(Icons.videocam_off, size: 48, color: Colors.black45),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(fontSize: 16)),
          if (showRetry) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _bootCamera,
              child: const Text('다시 시도'),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildPermissionDeniedView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('카메라와 마이크 권한이 필요합니다.'),
          const SizedBox(height: 8),
          TextButton(
              onPressed: openAppSettings,
              child: const Text('설정에서 권한 열기')),
        ],
      ),
    );
  }

  Widget _buildCameraErrorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('카메라 초기화 실패\n$_camError'),
          TextButton(onPressed: _bootCamera, child: const Text('다시 시도'))
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized) {
      return _buildStatusView('카메라를 준비 중입니다...');
    }

    final now = DateTime.now();
    final showDialogue = now.isBefore(_dialogueUntil) && _dialogue != null;
    final showOk = now.isBefore(_okMsgUntil);
    final showGuide = _gateMsg != null && _gateMsg!.isNotEmpty;

    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    final timerText = '$minutes:$seconds';

    return Stack(
      children: [
        Positioned.fill(child: CameraPreview(cam)),

        Positioned.fill(
          child: StreamBuilder<List<double>>(
            stream: kDemoMode ? _director.progressStream : _progress.progressStream,
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

        if (showGuide || showOk)
          Positioned(
            left: 20, right: 20,
            bottom: MediaQuery.of(context).padding.bottom + 32,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: showOk ? const Color(0xFF2E7D32) : Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  showOk ? '범위 내에 들어왔습니다!' : _gateMsg!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),

        if (!kDemoMode && _debugProbs != null && _zoneLabels.isNotEmpty)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < _debugProbs!.length; i++)
                    Text(
                      '${_zoneLabels.length > i ? _zoneLabels[i] : 'Zone $i'}: ${(_debugProbs![i] * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: _debugProbs![i] > 0.5 ? Colors.greenAccent : Colors.white,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),

        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              timerText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        if (showDialogue)
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

  Rect _emaRect(Rect? prev, Rect cur, double alpha) {
    if (prev == null) return cur;
    double lerp(double a, double b) => a * (1 - alpha) + b * alpha;
    return Rect.fromLTRB(lerp(prev.left, cur.left), lerp(prev.top, cur.top),
        lerp(prev.right, cur.right), lerp(prev.bottom, cur.bottom));
  }
  double _estimateLuma01(CameraImage img) {
    final pY = img.planes.first;
    final y = pY.bytes;
    if (y.isEmpty) return 1.0;
    int sum = 0, cnt = 0;
    for (int i = 0; i < y.length; i += 16) {
      sum += y[i];
      cnt++;
    }
    return (sum / (cnt * 255.0)).clamp(0.0, 1.0);
  }
  _FaceAnchors? _getFaceAnchors() {
    final faceLms = _lastFaceLandmarks2D;
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
    return null;
  }
  Float32List? _buildCoordFeatureD() {
    final anchors = _getFaceAnchors();
    if (anchors == null) {
      return null;
    }

    final handLmsNormCorrected = _lastHandLandmarks?.map((p) {
      final nx = (p[0] as num).toDouble().clamp(0.0, 1.0);
      final ny = (p[1] as num).toDouble().clamp(0.0, 1.0);
      return Offset((nx * _coordScaleX) + _coordOffsetX, (ny * _coordScaleY) + _coordOffsetY);
    }).toList();

    final List<Offset> handPts = (handLmsNormCorrected == null || handLmsNormCorrected.length < 21)
        ? List<Offset>.filled(21, Offset.zero)
        : handLmsNormCorrected.map((p) => Offset(1.0 - p.dx, p.dy)).toList();

    final List<Offset> facePts = [
      Offset(1.0 - anchors.leftEye.dx, anchors.leftEye.dy),
      Offset(1.0 - anchors.rightEye.dx, anchors.rightEye.dy),
      Offset(1.0 - anchors.nose.dx, anchors.nose.dy),
      Offset(1.0 - anchors.chin.dx, anchors.chin.dy),
      Offset(1.0 - anchors.mouthLeft.dx, anchors.mouthLeft.dy),
      Offset(1.0 - anchors.mouthRight.dx, anchors.mouthRight.dy),
    ];

    final List<Offset> pts = [...handPts, ...facePts];
    final nose = facePts[2];
    final leftEye = facePts[0];
    final rightEye = facePts[1];
    final chin = facePts[3];

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
}

// (이하 위젯 클래스들은 기존과 동일)
class _BossHud extends StatelessWidget {
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