// lib/features/brush_guide/presentation/face_check_page.dart
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MissingPluginException; // ← 추가
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:chicachew/core/landmarks/mediapipe_tasks.dart';

// ===== 브랜드 팔레트 =====
const kBrand = Color(0xFFBFEAD6);
const kBrandMid = Color(0xFFA5E1B2);
const kBrandLight = Color(0xFFE8FCD8);
const kBrandOn = Color(0xFF2B4F42);

// ===== 옵션 =====
const bool kAllowSkip = true;          // 개발/에뮬 스킵
const bool kShowDebugBadge = true;     // 디버그 배지
const bool kDebugLogs = true;          // 로그
const int  kWarmupMs = 500;            // 시작 워밍업
const int  kSendIntervalMs = 60;       // 프레임 전송 간격(≈16~20fps)
const int  kStableFramesToGo = 3;      // 연속 감지 프레임 수 (필요시 8~10으로)
const bool kTrySwapUV = false;         // (보관) U/V 반전 테스트용

// ===== 빌드 태그(지표) =====
const _BUILD_TAG = 'FaceCheck/Android: processYuv420Planes · r3';

class FaceCheckPage extends StatefulWidget {
  final String nextRoute;
  const FaceCheckPage({super.key, required this.nextRoute});

  @override
  State<FaceCheckPage> createState() => _FaceCheckPageState();
}

class _FaceCheckPageState extends State<FaceCheckPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  CameraController? _cam;

  late final AnimationController _pulse =
  AnimationController(vsync: this, duration: const Duration(seconds: 2))
    ..repeat(reverse: true);

  StreamSubscription<MpEvent>? _mpSub;

  // 전송/시간
  bool _sending = false;
  int _lastSentMs = 0;
  int _tsMs = 0; // 디버그용(실제 전달은 now)

  // 상태
  bool _warmup = true;
  Timer? _warmupTimer;
  bool _readyToNavigate = false;

  // 디버그
  String? _camInitError;
  int _facePts = 0;
  String _debugNote = '-';
  int _frameCount = 0;
  int _stableCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    _readyToNavigate = false;
    _camInitError = null;
    _stableCount = 0;
    _tsMs = 0;
    _frameCount = 0;

    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (!mounted) return;
        setState(() => _camInitError = '카메라 권한이 거부되었습니다.');
        return;
      }

      final cams = await availableCameras();
      if (cams.isEmpty) {
        if (!mounted) return;
        setState(() => _camInitError = '사용 가능한 카메라가 없습니다.');
        return;
      }

      final front = cams.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );

      _cam = CameraController(
        front,
        ResolutionPreset.medium, // 필요 시 .high
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.yuv420 // 대부분의 실기기 기본
            : ImageFormatGroup.bgra8888,
      );

      await _cam!.initialize();
      if (!mounted) return;

      // 브릿지 시작 (네이티브 카메라 X, Flutter가 푸시)
      await _startBridge();

      // 초기 프레임 유실 방지용 작은 지연
      await Future.delayed(const Duration(milliseconds: 200));

      // 이미지 스트림 시작
      await _cam!.startImageStream(_onImage);

      // 워밍업
      _warmup = true;
      _warmupTimer?.cancel();
      _warmupTimer = Timer(const Duration(milliseconds: kWarmupMs), () {
        _warmup = false;
      });

      setState(() {});
    } catch (e) {
      if (kDebugLogs) debugPrint('camera init error: $e');
      if (!mounted) return;
      setState(() => _camInitError = '카메라 초기화에 실패했습니다.\n$e');
    }
  }

  Future<void> _startBridge() async {
    try {
      await MpTasksBridge.instance.start(
        face: true,
        hands: false,
        useNativeCamera: false,
      );

      _mpSub?.cancel();
      _mpSub = MpTasksBridge.instance.events.listen((e) {
        if (e is MpFaceEvent) {
          final detected = e.landmarks.isNotEmpty;
          if (kDebugLogs) debugPrint('MpFaceEvent: pts=${e.landmarks.length}');
          setState(() {
            _facePts = detected ? e.landmarks.length : 0;
            _debugNote = 'face';
            if (!_warmup && detected) {
              _stableCount = (_stableCount + 1).clamp(0, 1000);
            } else {
              _stableCount = 0;
            }
          });

          if (!_warmup && !_readyToNavigate && _stableCount >= kStableFramesToGo) {
            _readyToNavigate = true;
            _goNext();
          }
        } else if (e is MpHandEvent) {
          if (kDebugLogs) debugPrint('MpHandEvent: ${e.handedness}, pts=${e.landmarks.length}');
          setState(() => _debugNote = 'hand');
        } else {
          setState(() => _debugNote = 'unknown');
        }
      });
    } catch (e) {
      if (kDebugLogs) debugPrint('MpTasksBridge start/listen error: $e');
      setState(() => _debugNote = 'mp:error');
    }
  }

  // === Flutter 카메라 → 브릿지로 프레임 전달 ===
  Future<void> _onImage(CameraImage img) async {
    _frameCount++;
    if (_frameCount % 30 == 0 && kDebugLogs) {
      debugPrint('frames: $_frameCount');
    }

    if (!mounted || _sending) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastSentMs < kSendIntervalMs) return; // 스로틀
    _lastSentMs = now;
    _tsMs = now; // 디버그 표시에만 사용

    _sending = true;
    try {
      final controller = _cam;
      if (controller == null) return;

      final rotationDegrees = controller.description.sensorOrientation;
      final isFront =
          controller.description.lensDirection == CameraLensDirection.front;

      if (Platform.isAndroid) {
        // ✅ Android: YUV420 평면과 stride 그대로 전달
        if (img.planes.length < 3) {
          if (kDebugLogs) debugPrint('Unexpected planes: ${img.planes.length}');
          return;
        }
        final y = img.planes[0];
        final u = img.planes[1];
        final v = img.planes[2];

        try {
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
            rotationDeg: rotationDegrees, // 0/90/180/270
            timestampMs: now,
          );
        } on MissingPluginException catch (_) {
          // ◀ 폴백: NV21로 변환해 pushFrame 사용
          if (kDebugLogs) debugPrint('processYuv420Planes not implemented → pushFrame NV21 fallback');
          final nv21 = _yuv420ToNv21(img, swapUV: kTrySwapUV);
          await MpTasksBridge.instance.pushFrame(
            bytes: nv21,
            width: img.width,
            height: img.height,
            rotationDegrees: rotationDegrees,
            timestampMs: now,
            pixelFormat: 'nv21',
            isFrontCamera: isFront,
          );
        } catch (e) {
          if (kDebugLogs) debugPrint('Android frame send error: $e');
        }
      } else {
        // iOS: BGRA8888 (행 stride 제거 후 전송)
        final bytes = _packBGRA(img);
        try {
          await MpTasksBridge.instance.pushFrame(
            bytes: bytes,
            width: img.width,
            height: img.height,
            rotationDegrees: rotationDegrees,
            timestampMs: now,
            pixelFormat: 'bgra8888',
            isFrontCamera: isFront,
          );
        } catch (e) {
          if (kDebugLogs) debugPrint('iOS pushFrame error: $e');
        }
      }
    } catch (e) {
      if (kDebugLogs) debugPrint('frame send error: $e');
    } finally {
      _sending = false;
    }
  }

  // --- Android: (보관) YUV_420_888 → NV21 변환 함수 (폴백용) ---
  Uint8List _yuv420ToNv21(CameraImage img, {bool swapUV = false}) {
    final int w = img.width;
    final int h = img.height;

    final yPlane = img.planes[0];
    final uPlane = img.planes[1];
    final vPlane = img.planes[2];

    final out = Uint8List(w * h + (w * h) ~/ 2);
    int offset = 0;

    // Y: rowStride 고려
    final yRowStride = yPlane.bytesPerRow;
    final yBytes = yPlane.bytes;
    for (int row = 0; row < h; row++) {
      final start = row * yRowStride;
      out.setRange(offset, offset + w, yBytes.sublist(start, start + w));
      offset += w;
    }

    // UV: stride/pixelStride 고려, NV21(VU interleaved)
    final uBytes = uPlane.bytes;
    final vBytes = vPlane.bytes;
    final uRowStride = uPlane.bytesPerRow;
    final vRowStride = vPlane.bytesPerRow;
    final uPixelStride = uPlane.bytesPerPixel ?? 1;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;

    final chromaH = h ~/ 2;
    final chromaW = w ~/ 2;

    for (int row = 0; row < chromaH; row++) {
      final uRow = row * uRowStride;
      final vRow = row * vRowStride;
      for (int col = 0; col < chromaW; col++) {
        final uIdx = uRow + col * uPixelStride;
        final vIdx = vRow + col * vPixelStride;
        if (swapUV) {
          out[offset++] = uBytes[uIdx]; // U
          out[offset++] = vBytes[vIdx]; // V
        } else {
          out[offset++] = vBytes[vIdx]; // V
          out[offset++] = uBytes[uIdx]; // U
        }
      }
    }
    return out;
  }

  // --- iOS: BGRA8888 tight 패킹 ---
  Uint8List _packBGRA(CameraImage img) {
    final plane = img.planes.first;
    final src = plane.bytes;
    final rowStride = plane.bytesPerRow;
    final out = Uint8List(img.width * img.height * 4);
    int dst = 0;
    for (int row = 0; row < img.height; row++) {
      final start = row * rowStride;
      out.setRange(dst, dst + img.width * 4, src.sublist(start, start + img.width * 4));
      dst += img.width * 4;
    }
    return out;
  }

  Future<void> _goNext() async {
    try { await _cam?.stopImageStream(); } catch (_) {}
    try { await _cam?.dispose(); } catch (_) {}
    try { await MpTasksBridge.instance.stop(); } catch (_) {}
    _warmupTimer?.cancel();
    if (!mounted) return;
    context.replace(widget.nextRoute);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    final cam = _cam;
    if (cam == null) return;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      try { await cam.stopImageStream(); } catch (_) {}
      try { await cam.dispose(); } catch (_) {}
      try { await MpTasksBridge.instance.stop(); } catch (_) {}
    } else if (state == AppLifecycleState.resumed) {
      _init();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _warmupTimer?.cancel();
    _mpSub?.cancel();
    try { _cam?.stopImageStream(); } catch (_) {}
    try { MpTasksBridge.instance.stop(); } catch (_) {}
    _cam?.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camReady = _cam != null && _cam!.value.isInitialized;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _BrandBackground(),
          if (camReady)
            Positioned.fill(child: _CameraCoverPreview(controller: _cam!))
          else
            Positioned.fill(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam_off_rounded, size: 64, color: kBrandOn),
                    const SizedBox(height: 12),
                    Text(
                      _camInitError ?? '카메라 준비 중입니다…',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: kBrandOn, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => CustomPaint(painter: _BrandMaskPainter(pulse: _pulse.value)),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.94),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                ),
                child: Text(
                  '카메라에 빵긋! 😀  얼굴을 원 안에 맞춰주세요\n$_BUILD_TAG',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kBrandOn),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: kBrandOn),
                onPressed: () => context.pop(),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (kAllowSkip)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _goNext,
                          icon: const Icon(Icons.skip_next_rounded),
                          label: const Text('바로 넘어가기 (개발/에뮬)'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    const Text(
                      '안경/마스크를 벗으면 더 잘 인식돼요',
                      style: TextStyle(
                        color: kBrandOn,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(color: Colors.black26, blurRadius: 6)],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const _LaterButton(),
                  ],
                ),
              ),
            ),
          ),
          if (kShowDebugBadge)
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Container(
                  margin: const EdgeInsets.all(10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'mp:${_debugNote}  pts:${_facePts}  ts:${_tsMs}  rot:${_cam?.description.sensorOrientation ?? -1}  f:${_frameCount}  stable:${_stableCount}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ===== UI 보조 위젯/페인터 =====
class _BrandBackground extends StatelessWidget {
  const _BrandBackground();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [kBrand, kBrandMid, kBrandLight],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: const _SoftDots(color: kBrandOn),
    );
  }
}

class _CameraCoverPreview extends StatelessWidget {
  final CameraController controller;
  const _CameraCoverPreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    if (controller.value.previewSize == null) return const SizedBox.shrink();
    final previewSize = controller.value.previewSize!;
    final previewAspect = previewSize.height / previewSize.width;

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: AspectRatio(
          aspectRatio: previewAspect,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

class _BrandMaskPainter extends CustomPainter {
  final double pulse; // 0~1
  _BrandMaskPainter({required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = min(size.width, size.height) * 0.36;

    canvas.saveLayer(rect, Paint());

    final grad = const LinearGradient(
      colors: [kBrand, kBrandMid, kBrandLight],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(rect);
    final bg = Paint()..shader = grad;
    canvas.drawRect(rect, bg);

    final hole = Path()..addOval(Rect.fromCircle(center: center, radius: baseRadius));
    canvas.drawPath(hole, Paint()..blendMode = BlendMode.clear);

    final auraR = baseRadius + 8 + sin(pulse * pi) * 6;
    final aura = Paint()
      ..shader = RadialGradient(
        colors: [kBrand.withOpacity(0.55), kBrand.withOpacity(0.0)],
        stops: const [0.08, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: auraR));
    canvas.drawCircle(center, auraR, aura);

    final ring = Paint()
      ..color = kBrandOn.withOpacity(0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawCircle(center, baseRadius, ring);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BrandMaskPainter old) => old.pulse != pulse;
}

class _SoftDots extends StatelessWidget {
  final Color color;
  const _SoftDots({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DotsPainter(dotColor: color.withOpacity(0.10)),
      child: const SizedBox.expand(),
    );
  }
}

class _DotsPainter extends CustomPainter {
  final Color dotColor;
  _DotsPainter({required this.dotColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = dotColor;
    final rnd = Random(42);
    for (int i = 0; i < 60; i++) {
      final r = 2.0 + rnd.nextDouble() * 2.0;
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LaterButton extends StatelessWidget {
  const _LaterButton();

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => context.pop(),
      icon: const Icon(Icons.fast_forward_rounded, color: kBrandOn),
      label: const Text('나중에 할래요', style: TextStyle(color: kBrandOn)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        backgroundColor: kBrandOn.withOpacity(0.10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
