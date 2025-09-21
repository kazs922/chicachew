// 📍 lib/features/brush_guide/presentation/brush_result_page.dart (피드백 로직 수정 완료)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chicachew/core/bp/user_bp_store.dart';
import 'package:chicachew/core/bp/user_streak_store.dart';

class BrushResultPage extends ConsumerWidget {
  final List<double> scores;

  const BrushResultPage({
    super.key,
    required this.scores,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    // 전체 점수 평균 계산
    final avg = scores.isNotEmpty ? scores.reduce((a, b) => a + b) / scores.length : 0.0;
    final int scorePct = (avg * 100).round();
    final int bpGained = (scorePct * 0.3).round(); // 100점 만점에 30 BP

    // ✅ [수정] 점수대별 피드백 로직 변경
    String title;
    String subtitle;
    if (scorePct == 100) {
      title = '🎉 완벽해요! 🎉';
      subtitle = '모든 치아를 아주 깨끗하게 닦았어요!';
    } else if (scorePct >= 50) {
      title = '✨ 잘했어요! ✨';
      subtitle = '조금만 더 신경 쓰면 완벽할 거예요!';
    } else { // 0~49%
      title = '더 분발해볼까요? 💪';
      subtitle = '아직 캐비티몬이 숨어있어요!\n다음엔 꼭 물리쳐봐요!';
    }

    // // BP 및 스트릭 업데이트 (결과 페이지가 처음 보일 때 한 번만 실행)
    // Future.microtask(() {
    //   ref.read(userBpProvider.notifier).addBp(bpGained);
    //   ref.read(userStreakProvider.notifier).recordBrushingSession();
    // });

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '양치 결과',
                style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // --- 결과 요약 ---
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(title, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '$scorePct점',
                      style: textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '+ $bpGained BP 획득!',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // --- 확인 버튼 ---
              FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                onPressed: () => context.go('/'),
                child: const Text('확인'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}