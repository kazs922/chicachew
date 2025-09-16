// 📍 lib/features/brush_guide/presentation/brush_result_page.dart
// (파일 전체를 이 코드로 교체하세요)

import 'package:flutter/material.dart';
import 'radar_overlay.dart'; // 같은 폴더라 상대경로로 import

const List<String> kBrushZoneLabelsKo = [
  '왼쪽\n바깥니',
  '앞니\n바깥니',
  '오른쪽\n바깥니',
  '오른쪽\n안쪽니',
  '앞니\n안쪽니',
  '왼쪽\n안쪽니',
  '왼쪽\n혀쪽니',
  '앞니\n혀쪽니',
  '오른쪽\n혀쪽니',
  '오른쪽 위\n씹는면',
  '왼쪽 위\n씹는면',
  '왼쪽 아래\n씹는면',
  '오른쪽 아래\n씹는면',
];

String toPercentString(double v) =>
    '${(v.clamp(0.0, 1.0) * 100).toStringAsFixed(0)}%';

class BrushResultPage extends StatelessWidget {
  final List<double> scores01;
  final double threshold;
  final VoidCallback? onDone;

  const BrushResultPage({
    super.key,
    required this.scores01,
    this.threshold = 0.6,
    this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final weakIndices = <int>[];
    for (int i = 0; i < scores01.length; i++) {
      if ((scores01[i]).clamp(0.0, 1.0) < threshold) weakIndices.add(i);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('오늘의 양치 결과'),
        centerTitle: true,
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
                  scores: scores01.map((v) => v.clamp(0.0, 1.0)).toList(),
                  activeIndex: _minIndex(scores01),
                  expand: true,
                  fallbackDemoIfEmpty: false,
                  fx: RadarFx.none,
                  showHighlight: false,
                  labels: kBrushZoneLabelsKo, // ✅ 여기에 라벨 목록을 전달합니다.
                ),
              ),
            ),

            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                '전체 평균: ${toPercentString(_avg(scores01))}  /  최소: ${toPercentString(scores01.reduce((a, b) => a < b ? a : b))}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: (weakIndices.isEmpty)
                    ? const _CongratsView()
                // ✅ 라벨이 길어져도 UI가 깨지지 않도록 수정
                    : _WeakList(weakIndices: weakIndices, scores01: scores01),
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
                  onPressed: () {
                    onDone?.call();
                    Navigator.pop(context);
                  },
                  child: const Text('완료', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static int _minIndex(List<double> v) {
    var idx = 0;
    var minV = 999.0;
    for (int i = 0; i < v.length; i++) {
      final x = v[i];
      if (x < minV) { minV = x; idx = i; }
    }
    return idx;
  }

  static double _avg(List<double> v) =>
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
        // ✅ 줄바꿈 문자를 공백으로 바꿔서 한 줄로 보이게 함
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