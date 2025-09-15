// lib/features/splash/presentation/intro_page.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:chicachew/core/storage/local_store.dart';

class IntroPage extends StatefulWidget {
  const IntroPage({super.key});
  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage>
    with SingleTickerProviderStateMixin {
  // 시작 버튼 펄스
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> _scale =
  Tween(begin: 1.0, end: 1.15).animate(
    CurvedAnimation(parent: _ac, curve: Curves.easeInOut),
  );

  // 인트로 이미지의 고정 비율(세로/가로) — 360x640 기준
  static const double _imgAspectHOverW = 640 / 360; // 1.777...

  @override
  void initState() {
    super.initState();
    // 첫 프레임 잔상 줄이기
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage('assets/images/kingdom.png'), context);
    });
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  // 시작: 프로필 유무 분기
  Future<void> _onStart() async {
    HapticFeedback.lightImpact();
    final hasProfile = await LocalStore().hasProfiles();
    if (!mounted) return;
    if (hasProfile) {
      context.go('/home');
    } else {
      context.go('/profile/add');
    }
  }

  void _onDataLoad() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('데이터 이어받기 실행!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dpr  = MediaQuery.of(context).devicePixelRatio;

    // 디바이스 비율(세로/가로)
    final devAspectHOverW = size.height / size.width;

    // 디바이스가 더 '길다면' → fitHeight, 아니면 fitWidth
    final bool useFitHeight = devAspectHOverW >= _imgAspectHOverW;
    final BoxFit fgFit = useFitHeight ? BoxFit.fitHeight : BoxFit.fitWidth;

    // 선명도: 사용하는 축 기준으로 cache값 전달
    final cacheW = (size.width  * dpr).round();
    final cacheH = (size.height * dpr).round();

    return Scaffold(
      body: Stack(
        children: [
          // ① 블러 배경: 빈 공간 없이 채움 (cover)
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Image.asset(
                'assets/images/kingdom.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                cacheWidth: cacheW,
              ),
            ),
          ),

          // ② 전경: 화면 비율에 따라 fitHeight/fitWidth 자동 선택
          Positioned.fill(
            child: Image.asset(
              'assets/images/kingdom.png',
              fit: fgFit,
              // 성/로고가 위에 있어 살짝 위로 정렬. 필요 시 -0.12~0.12 내에서 조정
              alignment: const Alignment(0, -0.08),
              filterQuality: FilterQuality.high,
              cacheHeight: useFitHeight ? cacheH : null,
              cacheWidth:  useFitHeight ? null    : cacheW,
            ),
          ),

          // ③ 하단 가독성 그라데이션
          Positioned(
            left: 0, right: 0, bottom: 0, height: 180,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.38), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),

          // ④ 하단 컨트롤: 시작(펄스) + 데이터 이어받기
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTransition(
                      scale: _scale,
                      child: Material(
                        color: Colors.black.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(28),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: _onStart,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                            child: Text(
                              '시작',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 1.2,
                                shadows: [
                                  Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _onDataLoad,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.lightBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('데이터 이어받기'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
