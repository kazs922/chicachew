import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:chicachew/core/storage/local_store.dart';

class IntroStep2Page extends StatefulWidget {
  const IntroStep2Page({super.key});

  @override
  State<IntroStep2Page> createState() => _IntroStep2PageState();
}

class _IntroStep2PageState extends State<IntroStep2Page>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      lowerBound: 0.9,
      upperBound: 1.1,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// "게임 시작" 버튼 눌렀을 때 → 프로필 유무 확인 후 이동
  Future<void> _onGameStart() async {
    final hasProfile = await LocalStore().hasProfiles();
    if (hasProfile) {
      context.pushReplacement('/home'); // 프로필 있으면 홈
    } else {
      context.pushReplacement('/profile/add'); // 없으면 프로필 등록
    }
  }

  void _onDataLoad() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('데이터 이어받기 실행!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final imgSize = size.width * 0.32;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // 중앙 묶음 (캐릭터 + 로고)
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Image.asset("assets/images/intro/ban_can.png", width: imgSize),
                    Image.asset("assets/images/intro/ban_lower.png", width: imgSize),
                  ],
                ),
                const SizedBox(height: 12),
                Image.asset(
                  "assets/images/intro/name.png",
                  width: size.width * 0.55,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Image.asset("assets/images/intro/ban_upper.png", width: imgSize),
                    Image.asset("assets/images/intro/ban_mol.png", width: imgSize),
                  ],
                ),
              ],
            ),

            const Spacer(flex: 3),

            // "게임 시작" 텍스트
            GestureDetector(
              onTap: _onGameStart,
              child: ScaleTransition(
                scale: _controller,
                child: const Text(
                  "게임 시작",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // "데이터 이어받기" 버튼
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: FilledButton(
                onPressed: _onDataLoad,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.lightBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("데이터 이어받기"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
