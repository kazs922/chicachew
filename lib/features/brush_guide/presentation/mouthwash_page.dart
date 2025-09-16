// 📍 lib/features/mouthwash/presentation/mouthwash_page.dart
// (파일 전체를 이 코드로 교체하세요)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class MouthwashPage extends StatefulWidget {
  // ✅ 1. 양치 점수 데이터를 받을 수 있도록 scores 변수를 추가합니다.
  final List<double> scores;
  final int totalSeconds;

  const MouthwashPage({
    super.key,
    required this.scores,
    this.totalSeconds = 30,
  });

  @override
  State<MouthwashPage> createState() => _MouthwashPageState();
}

class _MouthwashPageState extends State<MouthwashPage> {
  Timer? _tm;
  late int _remain;
  bool _running = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _remain = widget.totalSeconds;
    _start();
  }

  @override
  void dispose() {
    _tm?.cancel();
    super.dispose();
  }

  void _start() {
    if (_running || _finished) return;
    _running = true;
    _tm?.cancel();
    _tm = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_remain <= 1) {
        t.cancel();
        _running = false;
        _remain = 0;
        _finish();
      } else {
        setState(() => _remain--);
        if (_remain % 10 == 0 || _remain <= 3) {
          HapticFeedback.lightImpact();
        }
      }
    });
    setState(() {});
  }

  void _pause() {
    if (!_running || _finished) return;
    _tm?.cancel();
    _running = false;
    setState(() {});
  }

  void _finish() async {
    if (_finished) return;
    _finished = true;
    setState(() {});
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    // ✅ 2. onDone 콜백 대신, GoRouter를 사용해 결과 페이지로 이동합니다.
    // 이때, 받아온 scores 데이터를 그대로 전달합니다.
    context.go('/brush-result', extra: widget.scores);
  }

  // (나머지 _reset, _skip, _mmss 함수는 기존과 동일)
  void _reset() {
    _tm?.cancel();
    _running = false;
    _finished = false;
    _remain = widget.totalSeconds;
    setState(() {});
  }

  void _skip() {
    if (_finished) return;
    _tm?.cancel();
    _running = false;
    _remain = 0;
    _finish();
  }

  String _mmss(int secs) {
    final m = (secs ~/ 60).toString().padLeft(1, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final progress = (_finished || widget.totalSeconds == 0)
        ? 1.0
        : 1.0 - (_remain / widget.totalSeconds);

    return Scaffold(
      // ✅ 3. UI 개선: 다른 페이지와 통일성을 위해 그라데이션 배경을 추가합니다.
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.primaryContainer.withOpacity(0.5),
              colorScheme.surface,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // ✅ 4. UI 개선: 건너뛰기 버튼을 더 명확하게 변경합니다.
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton.icon(
                    onPressed: _skip,
                    icon: const Icon(Icons.fast_forward),
                    label: const Text('건너뛰기'),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ),
                const Spacer(),

                // ✅ 5. UI 개선: 꾸미기용 이미지를 추가합니다.
                Image.asset('assets/images/intro/int_clo.png', height: 120),
                const SizedBox(height: 24),

                Text(
                  _finished ? '완벽해요!' : '가글 타임',
                  style: textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _finished ? '이제 결과를 확인해볼까요?' : '입안을 천천히 헹궈주세요 · 거품은 삼키지 않기',
                  style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: 180, height: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 180, height: 180,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 12,
                          backgroundColor: colorScheme.surfaceVariant,
                          color: colorScheme.primary,
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                        child: _finished
                            ? Icon(Icons.check_circle,
                            key: const ValueKey('done'),
                            size: 80, color: colorScheme.primary)
                            : Text(
                          _mmss(_remain),
                          key: ValueKey('time_$_remain'),
                          style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),
                const Spacer(),

                // ✅ 6. UI 개선: 시작/일시정지 버튼을 하나로 통일하고 디자인을 개선합니다.
                if (!_finished)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _running ? _pause : _start,
                      icon: Icon(_running ? Icons.pause_circle : Icons.play_circle),
                      label: Text(_running ? '일시정지' : '다시 시작'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _finish,
                      child: const Text('결과 보기'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}