// 📍 lib/features/brush_guide/presentation/brush_result_page.dart (버킷별 피드백 적용)

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'radar_overlay.dart';

import 'package:chicachew/core/storage/active_profile_store.dart';
import 'package:chicachew/core/records/brush_record_store.dart';
import 'package:chicachew/core/bp/user_bp_store.dart';
import 'package:chicachew/core/bp/user_streak_store.dart';
import 'package:chicachew/core/progress/daily_brush_provider.dart';

const List<String> kBrushZoneLabelsKo = [
  '왼쪽 바깥쪽 \n치아', '앞니 바깥쪽 \n치아', '오른쪽 바깥쪽 \n치아',
  '오른쪽 입천장쪽 \n치아', '앞니 입천장쪽 \n치아', '왼쪽 입천장쪽 \n치아',
  '왼쪽 혀쪽 \n치아', '앞니 혀쪽 \n치아', '오른쪽 혀쪽 \n치아',
  '오른쪽 위 \n씹는면', '왼쪽 위 \n씹는면', '왼쪽 아래 \n씹는면', '오른쪽 아래 \n씹는면',
];

String toPercentString(double v) =>
    '${(v.clamp(0.0, 1.0) * 100).toStringAsFixed(0)}%';

class BrushResultPage extends ConsumerStatefulWidget {
  final List<double> scores01;
  final double threshold;

  const BrushResultPage({
    super.key,
    required this.scores01,
    this.threshold = 0.6, // (보존) 평균 등 부가 계산에만 사용, "완벽" 판정엔 쓰지 않음
  });

  @override
  ConsumerState<BrushResultPage> createState() => _BrushResultPageState();
}

class _BrushResultPageState extends ConsumerState<BrushResultPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processBrushCompletion();
    });
  }

  Future<void> _processBrushCompletion() async {
    final dailyBrushNotifier = ref.read(dailyBrushProvider.notifier);
    final currentBrushCount = dailyBrushNotifier.count;

    if (currentBrushCount < 3) {
      final activeIndex = await ActiveProfileStore.getIndex();
      if (activeIndex == null || activeIndex < 0) return;

      final userKey = 'idx$activeIndex';
      final now = DateTime.now();

      final record = BrushRecord(
        timestamp: now,
        scores: widget.scores01,
        durationSec: 120,
      );
      await BrushRecordStore.addRecord(userKey, record);
      await UserBpStore.add(userKey, 5, note: '양치 완료 보상');
      await dailyBrushNotifier.increment();
      await UserStreakStore.markToday(userKey);

      final (streakDays, _) = await UserStreakStore.info(userKey);
      if (!mounted) return;

      final currentStreak = streakDays ?? 0;
      final streakMsg = currentStreak > 1 ? '$currentStreak일 연속!' : '첫 스트릭 시작!';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('잘했어요! +5 BP 적립! ($streakMsg)')),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('오늘의 양치 3번을 모두 완료했어요! 대단해요!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final allIndices = List<int>.generate(widget.scores01.length, (i) => i);

    // ✅ 모든 구역이 "정확히 100%"일 때만 축하 뷰 (약간의 부동소수 허용)
    final bool allPerfect = widget.scores01.every((score) => score >= 0.999);

    return Scaffold(
      appBar: AppBar(
        title: const Text('오늘의 양치 결과'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: AspectRatio(
                aspectRatio: 1,
                child: RadarOverlay(
                  scores: widget.scores01.map((v) => v.clamp(0.0, 1.0)).toList(),
                  activeIndex: _minIndex(widget.scores01),
                  expand: true,
                  fallbackDemoIfEmpty: false,
                  fx: RadarFx.none,
                  showHighlight: false,
                  labels: kBrushZoneLabelsKo,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                '전체 평균: ${toPercentString(_avg(widget.scores01))} / 최소: ${toPercentString(widget.scores01.reduce((a, b) => a < b ? a : b))}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: allPerfect
                    ? const _CongratsView()
                    : _ResultList(allIndices: allIndices, scores01: widget.scores01),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => context.go('/home'),
                  child: const Text('완료', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _minIndex(List<double> v) {
    var idx = 0;
    var minV = 999.0;
    for (int i = 0; i < v.length; i++) {
      final x = v[i];
      if (x < minV) {
        minV = x;
        idx = i;
      }
    }
    return idx;
  }

  double _avg(List<double> v) =>
      v.isEmpty ? 0.0 : v.reduce((a, b) => a + b) / v.length;
}

class _CongratsView extends StatelessWidget {
  const _CongratsView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.emoji_events, color: Colors.amber, size: 56),
          SizedBox(height: 10),
          Text('모든 구역이 훌륭해요!\n내일도 이렇게만 닦아줘요 ✨',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ResultList extends StatelessWidget {
  final List<int> allIndices;
  final List<double> scores01;

  const _ResultList({
    required this.allIndices,
    required this.scores01,
  });

  int _bucket(double v) {
    final x = v.clamp(0.0, 1.0);
    if (x >= 1.0) return 2;       // 100%
    if (x >= 0.5) return 1;       // 50~99%
    return 0;                     // 0~49%
  }

  (IconData icon, Color color, String subtitle) _feedbackFor(double v) {
    switch (_bucket(v)) {
      case 0:
        return (Icons.priority_high_outlined, Colors.orange,
        '더 노력하자! 다음엔 이 부위 집중!');
      case 1:
        return (Icons.water_drop_outlined, Colors.blueAccent,
        '거의 다 왔어! 조금만 더 하면 완벽해요!');
      default:
        return (Icons.check_circle, Colors.green,
        '완벽해요!');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: allIndices.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final idx = allIndices[i];
        final score = scores01[idx];
        final label = (idx >= 0 && idx < kBrushZoneLabelsKo.length)
            ? kBrushZoneLabelsKo[idx].replaceAll('\n', ' ')
            : '구역 ${idx + 1}';
        final percent = toPercentString(score);

        final (icon, color, subtitle) = _feedbackFor(score);

        return ListTile(
          leading: Icon(icon, color: color),
          title: Text(label),
          subtitle: Text(subtitle),
          trailing: Text(percent, style: const TextStyle(fontWeight: FontWeight.w800)),
        );
      },
    );
  }
}
