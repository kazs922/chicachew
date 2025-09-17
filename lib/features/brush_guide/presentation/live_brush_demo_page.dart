// // 📍 lib/features/brush_guide/presentation/live_brush_demo_page.dart
// // (파일 전체를 이 코드로 교체하세요)
//
// import 'dart:async';
// import 'dart:math'; // ✅ 'dart.math' -> 'dart:math' 으로 오타를 수정했습니다.
//
// import 'package:camera/camera.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:permission_handler/permission_handler.dart';
//
// // LiveBrushPage에서 사용하는 의존성들을 그대로 가져옵니다.
// import 'package:chicachew/core/tts/tts_manager.dart';
// import '../../brush_guide/application/story_director.dart';
// import '../../brush_guide/application/radar_progress_engine.dart';
// import '../../brush_guide/presentation/radar_overlay.dart';
// import 'package:chicachew/features/brush_guide/presentation/brush_result_page.dart';
//
// // LiveBrushPage의 상수와 enum을 가져옵니다.
// const int kBrushZoneCount = 13;
// String chicachuAssetOf(String variant) => 'assets/images/$variant.png';
// const String kCavityAsset = 'assets/images/cavity.png';
// enum _CamState { idle, requesting, denied, granted, noCamera, initError, ready }
//
//
// class LiveBrushDemoPage extends StatefulWidget {
//   final String chicachuVariant;
//   const LiveBrushDemoPage({super.key, this.chicachuVariant = 'molar'});
//
//   @override
//   State<LiveBrushDemoPage> createState() => _LiveBrushDemoPageState();
// }
//
// class _LiveBrushDemoPageState extends State<LiveBrushDemoPage>
//     with WidgetsBindingObserver {
//   // ── 게임/스토리/진행 ───────────────────────────────────────────
//   late final StoryDirector _director;
//   late final RadarProgressEngine _progress;
//   final TtsManager _ttsMgr = TtsManager.instance;
//
//   ShowMessage? _dialogue;
//   DateTime _dialogueUntil = DateTime.fromMillisecondsSinceEpoch(0);
//
//   FinaleResult? _finale;
//   double _advantage = 0.0;
//   final Set<int> _spokenCompleteZoneIdxs = {};
//   bool _finaleTriggered = false;
//   List<double> _lastScores = List.filled(kBrushZoneCount, 0.0);
//
//   // ── 카메라 (프리뷰 기능만 사용) ────────────────────────────────
//   CameraController? _cam;
//   bool _camDisposing = false;
//   _CamState _camState = _CamState.idle;
//   String _camError = '';
//
//   // ── 시뮬레이션 타이머 및 Random 객체 ──────────────────────────
//   Timer? _simulationTimer;
//   int _currentDemoZone = 0;
//   final _random = Random(); // 이제 Random()이 정상적으로 인식됩니다.
//
//   String get _chicachuAvatarPath => chicachuAssetOf(widget.chicachuVariant);
//
//   String _avatarForSpeaker(Speaker s) {
//     switch (s) {
//       case Speaker.cavitymon: return kCavityAsset;
//       case Speaker.chikachu:
//       case Speaker.narrator: return _chicachuAvatarPath;
//     }
//   }
//
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//
//     _initializeGameLogic();
//     _bootCamera();
//     _startSimulation();
//   }
//
//   void _initializeGameLogic() {
//     _progress = RadarProgressEngine(
//       tickInterval: const Duration(seconds: 1),
//       ticksTargetPerZone: 10,
//     );
//     _director = StoryDirector(ticksTargetPerZone: 10);
//     _progress.progressStream.listen((p) {
//       _director.updateProgress(p);
//       _lastScores = p;
//       if (!_finaleTriggered && _allFull(p)) {
//         _triggerFinaleOnce(source: 'progress');
//       }
//     });
//     _director.stream.listen(_onStoryEvent);
//     _progress.start();
//     _director.start();
//     _ttsMgr.init();
//   }
//
//   /// 매번 다른 순서로 양치질 데이터를 생성하도록 수정된 함수
//   void _startSimulation() {
//     _simulationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       if (_finaleTriggered || !mounted) {
//         timer.cancel();
//         return;
//       }
//
//       // 0부터 12 사이의 정수를 무작위로 선택
//       _currentDemoZone = _random.nextInt(kBrushZoneCount);
//
//       _progress.reportZoneIndex(_currentDemoZone);
//
//       // UI 갱신
//       setState(() {});
//     });
//   }
//
//   Future<void> _bootCamera() async {
//     if (mounted) {
//       setState(() {
//         _camState = _CamState.requesting;
//         _camError = '';
//       });
//     }
//
//     var status = await Permission.camera.status;
//     if (!status.isGranted) status = await Permission.camera.request();
//     if (!mounted) return;
//
//     if (status.isPermanentlyDenied || !status.isGranted) {
//       setState(() => _camState = _CamState.denied);
//       return;
//     }
//     setState(() => _camState = _CamState.granted);
//     await _initCamera();
//   }
//
//   Future<void> _initCamera() async {
//     try {
//       final cams = await availableCameras();
//       if (cams.isEmpty) {
//         if (mounted) setState(() { _camState = _CamState.noCamera; _camError = '카메라 장치를 찾을 수 없습니다.'; });
//         return;
//       }
//       final front = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cams.first);
//       await _disposeCamSafely();
//       final controller = CameraController(front, ResolutionPreset.low, enableAudio: false);
//       await controller.initialize();
//       if (!mounted) {
//         await controller.dispose();
//         return;
//       }
//       _cam = controller;
//       setState(() => _camState = _CamState.ready);
//     } catch (e, st) {
//       debugPrint('Camera init error: $e\n$st');
//       if (mounted) setState(() { _camState = _CamState.initError; _camError = '$e'; });
//     }
//   }
//
//   Future<void> _disposeCamSafely() async {
//     final oldController = _cam;
//     if (oldController == null) return;
//     _camDisposing = true;
//     _cam = null;
//     if (mounted) setState(() {});
//     await Future.delayed(const Duration(milliseconds: 150));
//     try { await oldController.dispose(); } catch (_) {}
//     if (mounted) _camDisposing = false;
//   }
//
//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     if (_cam == null && state != AppLifecycleState.resumed) return;
//     if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
//       _disposeCamSafely();
//     } else if (state == AppLifecycleState.resumed) {
//       if (_cam == null) _bootCamera();
//     }
//   }
//
//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     _simulationTimer?.cancel();
//     _disposeCamSafely();
//     _progress.stop();
//     _director.dispose();
//     _ttsMgr.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final now = DateTime.now();
//     final showDialogue = now.isBefore(_dialogueUntil) && _dialogue != null;
//     final cam = _cam;
//     final showPreview = !_camDisposing && cam != null && cam.value.isInitialized;
//
//     return Scaffold(
//       body: Stack(
//         children: [
//           Container(
//             decoration: const BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [Color(0xFFBFEAD6), Color(0xFFA5E1B2), Color(0xFFE8FCD8)],
//                 begin: Alignment.topCenter,
//                 end: Alignment.bottomCenter,
//               ),
//             ),
//           ),
//
//           if (showPreview)
//             Positioned.fill(child: CameraPreview(cam)),
//
//           if (!showPreview)
//             Positioned.fill(
//               child: Center(
//                 child: (_camState == _CamState.requesting || _camState == _CamState.granted)
//                     ? const CircularProgressIndicator()
//                     : Text(_camError.isNotEmpty ? _camError : '카메라 권한을 확인해주세요.'),
//               ),
//             ),
//
//           Positioned.fill(
//             child: StreamBuilder<List<double>>(
//               stream: _progress.progressStream,
//               initialData: List.filled(kBrushZoneCount, 0.0),
//               builder: (context, snapshot) {
//                 final scores01 = _normalizedScores(snapshot.data ?? []);
//                 final activeIdx = _suggestActiveIndex(scores01);
//                 return RadarOverlay(
//                   scores: scores01, activeIndex: activeIdx, expand: true,
//                   fallbackDemoIfEmpty: false, fx: RadarFx.radialPulse, showHighlight: true,
//                 );
//               },
//             ),
//           ),
//
//           Positioned(
//             left: 12, right: 12, top: MediaQuery.of(context).padding.top + 8,
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
//               color: Colors.black54,
//               child: Text(
//                 'DEMO MODE: 현재 시뮬레이션 중인 구역 #${_currentDemoZone}',
//                 style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//               ),
//             ),
//           ),
//
//           if (showDialogue)
//             Positioned(
//               left: 12, right: 12, bottom: MediaQuery.of(context).padding.bottom + 120,
//               child: _DialogueOverlay(
//                 text: _dialogue!.text, avatarPath: _avatarForSpeaker(_dialogue!.speaker),
//                 alignLeft: _dialogue!.speaker != Speaker.cavitymon,
//               ),
//             ),
//
//           Positioned(
//             left: 16, right: 16, bottom: MediaQuery.of(context).padding.bottom + 16,
//             child: _BossHud(advantage: _advantage),
//           ),
//
//           if (_finale != null)
//             Positioned.fill(
//               child: Container(
//                 color: Colors.black.withOpacity(0.55),
//                 alignment: Alignment.center,
//                 child: _FinaleView(result: _finale!),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//   void _onStoryEvent(StoryEvent e) async {
//     if (!mounted) return;
//     if (e is ShowMessage) {
//       _showDialogue(e, e.duration);
//       await _ttsMgr.speak(e.text, speaker: e.speaker);
//       HapticFeedback.lightImpact();
//     } else if (e is ShowHintForZone) {
//       final text = '${e.zoneName}를 닦아볼까?';
//       _showDialogue(ShowMessage(text, duration: e.duration, speaker: Speaker.chikachu), e.duration);
//       await _ttsMgr.speak(text, speaker: Speaker.chikachu);
//       HapticFeedback.mediumImpact();
//     } else if (e is ShowCompleteZone) {
//       if (_spokenCompleteZoneIdxs.contains(e.zoneIndex)) return;
//       _spokenCompleteZoneIdxs.add(e.zoneIndex);
//       final text = '${e.zoneName} 완료! 다른 부분도 닦아보자!';
//       _showDialogue(ShowMessage(text, duration: e.duration, speaker: Speaker.chikachu), e.duration);
//       HapticFeedback.selectionClick();
//       await _ttsMgr.speak(text, speaker: Speaker.chikachu);
//       if (!_finaleTriggered && _spokenCompleteZoneIdxs.length >= kBrushZoneCount) {
//         _triggerFinaleOnce(source: 'zones-complete');
//       }
//     } else if (e is BossHudUpdate) {
//       setState(() => _advantage = e.advantage);
//     } else if (e is FinaleEvent) {
//       if (!_finaleTriggered) {
//         _triggerFinaleOnce(source: 'director-event', result: e.result);
//       }
//     }
//   }
//
//   void _showDialogue(ShowMessage msg, Duration d) {
//     if (!mounted) return;
//     setState(() { _dialogue = msg; _dialogueUntil = DateTime.now().add(d); });
//   }
//
//   void _triggerFinaleOnce({String source = 'unknown', FinaleResult? result}) async {
//     if (_finaleTriggered || !mounted) return;
//     _finaleTriggered = true;
//     await _disposeCamSafely();
//     _progress.stop();
//     setState(() => _finale = result ?? FinaleResult.win);
//     final line = (result == FinaleResult.lose) ? '오늘은 아쉽지만, 내일은 꼭 이겨보자!' : '모든 구역 반짝반짝! 오늘 미션 완벽 클리어! ✨';
//     _showDialogue(ShowMessage(line, duration: const Duration(seconds: 3), speaker: Speaker.chikachu), const Duration(seconds: 3));
//     await _ttsMgr.speak(line, speaker: Speaker.chikachu);
//     HapticFeedback.heavyImpact();
//     if (!mounted) return;
//     final scores01 = _normalizedScores(_lastScores);
//     await Navigator.of(context).push(
//       MaterialPageRoute(builder: (_) => BrushResultPage(scores01: scores01, threshold: 0.60, onDone: () {})),
//     );
//   }
//
//   List<double> _normalizedScores(List<double> scores) {
//     if (scores.any((v) => v > 1.0)) {
//       return scores.map((v) => (v / 100.0).clamp(0.0, 1.0)).toList();
//     }
//     return scores.map((v) => v.clamp(0.0, 1.0)).toList();
//   }
//
//   bool _allFull(List<double> src) {
//     final scores = _normalizedScores(src);
//     return scores.length == kBrushZoneCount && scores.every((v) => v >= 0.999);
//   }
//
//   int _suggestActiveIndex(List<double> scores) {
//     var idx = 0;
//     var minVal = 999.0;
//     for (int i = 0; i < scores.length; i++) {
//       if (scores[i] < minVal) {
//         minVal = scores[i];
//         idx = i;
//       }
//     }
//     return idx;
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────
// // 아래는 LiveBrushPage에서 사용하는 UI 위젯들입니다.
// // ─────────────────────────────────────────────────────────────────
//
// class _BossHud extends StatelessWidget {
//   final double advantage;
//   const _BossHud({required this.advantage});
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         const Text('치카츄 vs 캐비티몬',
//             style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
//         const SizedBox(height: 6),
//         ClipRRect(
//           borderRadius: BorderRadius.circular(8),
//           child: LinearProgressIndicator(
//             value: advantage,
//             minHeight: 10,
//             backgroundColor: Colors.red.withOpacity(0.3),
//             valueColor:
//             const AlwaysStoppedAnimation<Color>(Colors.lightBlueAccent),
//           ),
//         ),
//       ],
//     );
//   }
// }
//
// class _FinaleView extends StatelessWidget {
//   final FinaleResult result;
//   const _FinaleView({required this.result});
//
//   @override
//   Widget build(BuildContext context) {
//     String text;
//     if (result == FinaleResult.win) {
//       text = '캐비티몬이 쓰러졌다!\n치카츄 승리!';
//     } else if (result == FinaleResult.draw) {
//       text = '“이걸로는 내가 쓰러지지 않는다… 다음에 다시 찾아오겠다!”';
//     } else {
//       text = '캐비티몬 승리!\n더 꼼꼼히 닦아서 다시 도전!';
//     }
//     return Padding(
//       padding: const EdgeInsets.all(20),
//       child: Text(
//         text,
//         textAlign: TextAlign.center,
//         style: const TextStyle(
//             color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
//       ),
//     );
//   }
// }
//
// class _DialogueOverlay extends StatelessWidget {
//   final String text;
//   final String avatarPath;
//   final bool alignLeft;
//   const _DialogueOverlay({
//     required this.text,
//     required this.avatarPath,
//     required this.alignLeft,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final bubble = _SpeechBubble(text: text, tailOnLeft: alignLeft);
//     final avatar = Container(
//       width: 64,
//       height: 64,
//       decoration: BoxDecoration(
//         shape: BoxShape.circle,
//         color: Colors.white,
//         image:
//         DecorationImage(image: AssetImage(avatarPath), fit: BoxFit.cover),
//         boxShadow: const [
//           BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))
//         ],
//       ),
//     );
//
//     return Row(
//       mainAxisAlignment:
//       alignLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
//       crossAxisAlignment: CrossAxisAlignment.end,
//       children: alignLeft
//           ? [avatar, const SizedBox(width: 10), Expanded(child: bubble)]
//           : [Expanded(child: bubble), const SizedBox(width: 10), avatar],
//     );
//   }
// }
//
// class _SpeechBubble extends StatelessWidget {
//   final String text;
//   final bool tailOnLeft;
//   const _SpeechBubble({required this.text, required this.tailOnLeft});
//
//   @override
//   Widget build(BuildContext context) {
//     final box = Container(
//       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(14),
//         boxShadow: const [
//           BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))
//         ],
//       ),
//       child: Text(
//         text,
//         softWrap: true,
//         overflow: TextOverflow.ellipsis,
//         maxLines: 3,
//         style: const TextStyle(
//             fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
//       ),
//     );
//
//     final tail = CustomPaint(
//       size: const Size(16, 10),
//       painter: _TailPainter(color: Colors.white, isLeft: tailOnLeft),
//     );
//
//     return Stack(
//       clipBehavior: Clip.none,
//       children: [
//         box,
//         Positioned(
//           bottom: -8,
//           left: tailOnLeft ? 16 : null,
//           right: tailOnLeft ? null : 16,
//           child: tail,
//         ),
//       ],
//     );
//   }
// }
//
// class _TailPainter extends CustomPainter {
//   final Color color;
//   final bool isLeft;
//   const _TailPainter({required this.color, required this.isLeft});
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     final p = Paint()..color = color..style = PaintingStyle.fill;
//     final path = Path();
//     if (isLeft) {
//       path
//         ..moveTo(0, size.height)
//         ..lineTo(size.width, size.height)
//         ..lineTo(size.width * 0.45, 0);
//     } else {
//       path
//         ..moveTo(size.width, size.height)
//         ..lineTo(0, size.height)
//         ..lineTo(size.width * 0.55, 0);
//     }
//     path.close();
//     canvas.drawPath(path, p);
//   }
//
//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
// }