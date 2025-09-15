import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class IntroStep1Page extends StatefulWidget {
  const IntroStep1Page({super.key});
  @override
  State<IntroStep1Page> createState() => _IntroStep1PageState();
}

class _IntroStep1PageState extends State<IntroStep1Page>
    with TickerProviderStateMixin {
  late final AnimationController _ac;

  // 위치 애니메이션
  late final Animation<Alignment> _aUpperR;
  late final Animation<Alignment> _aLowerR;
  late final Animation<Alignment> _aLowerL;
  late final Animation<Alignment> _aUpperL;

  // 시간 스태거
  late final Animation<double> _t1, _t2, _t3, _t4;

  @override
  void initState() {
    super.initState();

    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3600));

    _t1 = CurvedAnimation(
        parent: _ac,
        curve: const Interval(0.00, 0.40, curve: Curves.easeOutBack));
    _t2 = CurvedAnimation(
        parent: _ac,
        curve: const Interval(0.20, 0.55, curve: Curves.easeOutBack));
    _t3 = CurvedAnimation(
        parent: _ac,
        curve: const Interval(0.40, 0.75, curve: Curves.easeOutBack));
    _t4 = CurvedAnimation(
        parent: _ac,
        curve: const Interval(0.60, 1.00, curve: Curves.easeOutBack));

    // 화면 바깥 → 안쪽 자리 (더 멀리서 시작하도록 값 -2.5, 2.5)
    _aUpperR = AlignmentTween(
        begin: const Alignment(2.5, -2.5), end: const Alignment(1.7, -0.9))
        .animate(_t1);
    _aLowerR = AlignmentTween(
        begin: const Alignment(2.5, 2.5), end: const Alignment(1.5, 0.5))
        .animate(_t2);
    _aLowerL = AlignmentTween(
        begin: const Alignment(-2.5, 2.5), end: const Alignment(-2.2, 0.5))
        .animate(_t3);
    _aUpperL = AlignmentTween(
        begin: const Alignment(-2.5, -2.5), end: const Alignment(-1.6, -0.9))
        .animate(_t4);

    _ac.forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shortest = MediaQuery.of(context).size.shortestSide;
    final imgBase = shortest * 0.7; // 크기 크게 (기본 70%)

    return Scaffold(
      backgroundColor: const Color(0xFFF0FFFF),
      body: SafeArea(
        child: Stack(
          children: [
            // 오른쪽 위 (int_lower)
            _CharAlignPop(
              img: 'assets/images/intro/int_lower.png',
              align: _aUpperR,
              t: _t1,
              size: imgBase,
              angleDeg: 0,
            ),
            // 오른쪽 아래 (int_molar)
            _CharAlignPop(
              img: 'assets/images/intro/int_molar.png',
              align: _aLowerR,
              t: _t2,
              size: imgBase,
              angleDeg: -5,
            ),
            // 왼쪽 아래 (int_upper)
            _CharAlignPop(
              img: 'assets/images/intro/int_upper.png',
              align: _aLowerL,
              t: _t3,
              size: imgBase,
              angleDeg: 0,
            ),
            // 왼쪽 위 (int_can)
            _CharAlignPop(
              img: 'assets/images/intro/int_can.png',
              align: _aUpperL,
              t: _t4,
              size: imgBase,
              angleDeg: 0,
            ),

            // 중앙 텍스트
            Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  '안녕!\n너 양치하러 왔구나!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.5,
                  ),
                ),
              ),
            ),

            // 하단 버튼
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: 180,
                  height: 50,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26)),
                    ),
                    onPressed: () => context.go('/intro2'),
                    child: const Text('그럼!'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 캐릭터 애니메이션 위젯
class _CharAlignPop extends StatelessWidget {
  final String img;
  final Animation<Alignment> align;
  final Animation<double> t;
  final double size;
  final double angleDeg;

  const _CharAlignPop({
    required this.img,
    required this.align,
    required this.t,
    required this.size,
    this.angleDeg = 0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: t,
      builder: (_, __) {
        final v = t.value.clamp(0.0, 1.0);
        final scale = 0.5 + 0.7 * v; // 0.5배 → 1.2배
        final angle = angleDeg * (3.141592 / 180); // degree → radian

        return Align(
          alignment: align.value,
          child: Opacity(
            opacity: v,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..scale(scale, scale)
                ..rotateZ(angle),
              child: Image.asset(
                img,
                width: size,
                height: size,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }
}
