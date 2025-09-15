import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:chicachew/core/records/brush_record_store.dart'; // ✅ 연결

class BrushTimePage extends StatelessWidget {
  const BrushTimePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("브러쉬 타임"),
        centerTitle: true,
        // 홈 화면 톤 맞추기: 테마 사용(파란 배경 제거)
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 안내 문구
                const Text(
                  "양치 습관을 재미있게!\n어떤 모드로 시작할까요?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 40),

                // 튜토리얼 버튼
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push("/guide"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.menu_book_rounded),
                    label: const Text(
                      "튜토리얼 가이드",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 실전 버튼 (성공 시 기록 1칸 증가)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      // ✔ go() 대신 push()로 이동해서 결과를 기다림
                      final ok = await context.push<bool>("/face-check");
                      if (ok == true) {
                        // 라이브브러쉬에서 성공으로 pop(true)하면 여기서 반영
                        BrushRecordStore.instance.completeNow();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("오늘 기록이 1칸 채워졌어요!")),
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 1.5,
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text(
                      "양치 시작!",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
