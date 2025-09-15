import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class GuidePage extends StatelessWidget {
  const GuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("양치 튜토리얼 가이드"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "여기서 양치 방법 가이드를 보여줄 수 있어요!",
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () {
                // 가이드 완료 후 실전으로 이동
                context.pushReplacement('/live');
              },
              child: const Text("가이드 완료 → 실전으로"),
            ),
          ],
        ),
      ),
    );
  }
}
