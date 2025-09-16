// 📍 lib/features/home/presentation/tabs/brush_time_page.dart
// (파일 전체를 이 코드로 교체하세요)

import 'package:chicachew/core/progress/daily_brush_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ✅ 실제 DailyBrushProvider 클래스에 맞는 Provider를 생성합니다.
// 이 Provider는 앱이 시작될 때 load() 함수를 호출하여 오늘 양치 횟수를 불러옵니다.
final dailyBrushProvider = ChangeNotifierProvider<DailyBrushProvider>((ref) {
  return DailyBrushProvider()..load();
});


class BrushTimePage extends ConsumerWidget {
  const BrushTimePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    // ✅ 위에서 생성한 provider를 사용하여 양치 횟수(count)를 가져옵니다.
    final dailyBrush = ref.watch(dailyBrushProvider);
    final brushCount = dailyBrush.count;

    return Scaffold(
      appBar: AppBar(
        title: const Text('양치 시간'),
        centerTitle: false,
        backgroundColor: colorScheme.surface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // (상단 배너 카드와 '실전 시작' 버튼은 이전과 동일합니다)
            Card(
              color: colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '오늘도 즐겁게',
                            style: textTheme.headlineMedium?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '양치해볼까요? 🦷✨',
                            style: textTheme.headlineMedium?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Image.asset(
                      'assets/images/canine.png',
                      width: 80,
                      height: 80,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: () {
                context.go('/live');
              },
              icon: const Icon(Icons.play_circle_fill, size: 28),
              label: const Text(
                '실전 시작',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
              ),
            ),
            const SizedBox(height: 24),

            // ✅ '오늘의 양치 기록' 카드 UI
            Card(
              color: colorScheme.surfaceVariant.withOpacity(0.5),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '오늘의 양치 기록 (${brushCount} / 3)', // 오늘 닦은 횟수 표시
                      style: textTheme.titleLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // ✅ count 값을 기준으로 양치 완료 여부를 표시하도록 수정
                        _BrushRecordItem(
                          time: '아침',
                          icon: Icons.light_mode,
                          isDone: brushCount >= 1, // 1번 이상 닦았으면 완료
                        ),
                        _BrushRecordItem(
                          time: '점심',
                          icon: Icons.restaurant,
                          isDone: brushCount >= 2, // 2번 이상 닦았으면 완료
                        ),
                        _BrushRecordItem(
                          time: '저녁',
                          icon: Icons.dark_mode,
                          isDone: brushCount >= 3, // 3번 이상 닦았으면 완료
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrushRecordItem extends StatelessWidget {
  const _BrushRecordItem({
    required this.time,
    required this.icon,
    required this.isDone,
  });

  final String time;
  final IconData icon;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isDone ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.4);
    final iconData = isDone ? Icons.check_circle : Icons.radio_button_unchecked;

    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(time, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Icon(iconData, color: color, size: 24),
      ],
    );
  }
}