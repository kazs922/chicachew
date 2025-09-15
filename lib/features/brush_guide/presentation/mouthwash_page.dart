// lib/features/mouthwash/presentation/mouthwash_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MouthwashPage extends StatefulWidget {
  const MouthwashPage({super.key, this.onDone, this.totalSeconds = 30});

  /// 완료 시 외부로 알리고 싶으면 콜백 주입, 아니면 null이면 pop 처리
  final VoidCallback? onDone;

  /// 카운트다운 길이(기본 30초)
  final int totalSeconds;

  @override
  State<MouthwashPage> createState() => _MouthwashPageState();
}

class _MouthwashPageState extends State<MouthwashPage> {
  Timer? _tm;
  late int _remain;     // 남은 초
  bool _running = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _remain = widget.totalSeconds;
    _start(); // 진입 시 바로 시작 (원하면 주석 처리)
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
        setState(() {
          _remain--;
        });
        // 10초 단위 & 마지막 3초 카운트에 가벼운 햅틱
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

  void _reset() {
    _tm?.cancel();
    _running = false;
    _finished = false;
    _remain = widget.totalSeconds;
    setState(() {});
  }

  void _skip() {
    _tm?.cancel();
    _running = false;
    _remain = 0;
    _finish();
  }

  void _finish() async {
    if (_finished) return;
    _finished = true;
    setState(() {});
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    if (widget.onDone != null) {
      widget.onDone!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  String _mmss(int secs) {
    final m = (secs ~/ 60).toString().padLeft(1, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final progress = (_finished || widget.totalSeconds == 0)
        ? 1.0
        : 1.0 - (_remain / widget.totalSeconds);

    return Scaffold(
      backgroundColor: const Color(0xFFF5FFF8),
      body: SafeArea(
        child: Stack(
          children: [
            // 상단 스킵/리셋 액션
            Positioned(
              right: 12,
              top: 8,
              child: Row(
                children: [
                  TextButton(
                    onPressed: _reset,
                    child: const Text('처음부터'),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: _skip,
                    child: const Text('건너뛰기'),
                  ),
                ],
              ),
            ),

            // 본문
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                children: [
                  const Spacer(),
                  const Text('가글 타임', style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    '입안을 천천히 헹궈요 · 거품은 삼키지 않기',
                    style: TextStyle(
                        fontSize: 14, color: Colors.black.withOpacity(0.55)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // 원형 진행바 + 남은 시간
                  SizedBox(
                    width: 220, height: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 220, height: 220,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 14,
                            backgroundColor: const Color(0xFFB2DFDB),
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          transitionBuilder: (child, anim) =>
                              ScaleTransition(scale: anim, child: child),
                          child: _finished
                              ? const Icon(Icons.check_circle,
                              key: ValueKey('done'),
                              size: 88, color: Color(0xFF2E7D32))
                              : Text(
                            _mmss(_remain),
                            key: ValueKey('time_${_remain}'),
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  // 간단 팁 3줄
                  const _TipRow('볼·혀 사이까지 천천히 헹구기'),
                  const _TipRow('좌우, 위아래 골고루 30초'),
                  const _TipRow('삼키지 말고 뱉기'),

                  const Spacer(),

                  if (!_finished)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _running ? _pause : _start,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              side: const BorderSide(color: Color(0xFF2E7D32)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(_running ? '일시정지' : '시작'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _skip,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              backgroundColor: const Color(0xFF2E7D32),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('바로 완료'),
                          ),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _finish, // 콜백/Pop 처리
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('양치하러 가기'),
                      ),
                    ),

                  SizedBox(height: bottom + 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('✅', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
