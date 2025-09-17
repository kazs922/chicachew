// 📍 lib/features/brush_guide/presentation/brush_result_page.dart (전체 파일)

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'radar_overlay.dart';

import 'package:chicachew/core/storage/active_profile_store.dart';
import 'package:chicachew/core/records/brush_record_store.dart';
import 'package:chicachew/core/bp/user_bp_store.dart';
import 'package:chicachew/core/bp/user_streak_store.dart';

const List<String> kBrushZoneLabelsKo = [
  '왼쪽 바깥쪽 \n치아', '앞니 바깥쪽 \n치아', '오른쪽 바깥쪽 \n치아',
  '오른쪽 입천장쪽 \n치아', '앞니 입천장쪽 \n치아', '왼쪽 입천장쪽 \n치아',
  '왼쪽 혀쪽 \n치아', '앞니 혀쪽 \n치아', '오른쪽 혀쪽 \n치아',
  '오른쪽 위 \n씹는면', '왼쪽 위 \n씹는면', '왼쪽 아래 \n씹는면', '오른쪽 아래 \n씹는면',
];

String toPercentString(double v) =>
    '${(v.clamp(0.0, 1.0) * 100).toStringAsFixed(0)}%';

class BrushResultPage extends StatefulWidget {
  final List<double> scores01;
  final double threshold;

  const BrushResultPage({
    super.key,
    required this.scores01,
    this.threshold = 0.6,
  });

  @override
  State<BrushResultPage> createState() => _BrushResultPageState();
}

class _BrushResultPageState extends State<BrushResultPage> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processBrushCompletion();
    });
  }

  Future<void> _processBrushCompletion() async {
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

    // ✅ [수정] 1. 먼저 오늘 날짜를 기록합니다 (반환값 없음)
    await UserStreakStore.markToday(userKey);
    // ✅ [수정] 2. 그 다음에 업데이트된 스트릭 정보를 조회합니다.
    final (streakDays, _) = await UserStreakStore.info(userKey);

    if (!mounted) return;

    final currentStreak = streakDays ?? 0;
    final streakMsg = currentStreak > 1 ? '$currentStreak일 연속!' : '첫 스트릭 시작!';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('잘했어요! +5 BP 적립! ($streakMsg)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final weakIndices = <int>[];
    for (int i = 0; i < widget.scores01.length; i++) {
      if ((widget.scores01[i]).clamp(0.0, 1.0) < widget.threshold) {
        weakIndices.add(i);
      }
    }

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
                child: (weakIndices.isEmpty)
                    ? const _CongratsView()
                    : _WeakList(weakIndices: weakIndices, scores01: widget.scores01),
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

class _WeakList extends StatelessWidget {
  final List<int> weakIndices;
  final List<double> scores01;

  const _WeakList({required this.weakIndices, required this.scores01});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: weakIndices.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final idx = weakIndices[i];
        final label = (idx >= 0 && idx < kBrushZoneLabelsKo.length)
            ? kBrushZoneLabelsKo[idx].replaceAll('\n', ' ')
            : '구역 ${idx + 1}';
        final percent = toPercentString(scores01[idx]);

        return ListTile(
          leading: const Icon(Icons.brush_outlined),
          title: Text(label),
          subtitle: const Text('다음엔 여기도 꼼꼼히!'),
          trailing: Text(percent, style: const TextStyle(fontWeight: FontWeight.w800)),
        );
      },
    );
  }
}