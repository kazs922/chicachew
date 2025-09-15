import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProfileSelectPage extends StatelessWidget {
  const ProfileSelectPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("프로필 등록"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),

            // 타이틀
            const Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: "자녀의 프로필을 ",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: "등록해주세요. (선택)",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF00A693), // 민트색 포인트
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 설명
            const Text(
              "다른 보호자가 이미 등록한 자녀는\n새로 등록할 필요 없이 가족 공유로 확인할 수 있어요.",
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 28),

            // 자녀 추가 버튼 (임시)
            InkWell(
              onTap: () {
                context.push('/profile/add'); // → profile_add_page.dart 로 이동
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF9F6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    "자녀 추가 +",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF00A693),
                    ),
                  ),
                ),
              ),
            ),

            const Spacer(),

            // 하단 계속하기 버튼
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  // TODO: 프로필 등록을 건너뛰고 홈으로 이동
                  context.go('/home');
                },
                child: const Text(
                  "계속하기",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
