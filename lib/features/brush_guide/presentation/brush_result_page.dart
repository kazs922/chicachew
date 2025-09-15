// lib/features/brush_guide/presentation/brush_result_page.dart
import 'package:flutter/material.dart';
import 'radar_overlay.dart'; // 같은 폴더라 상대경로로 import

/// (로컬) 13개 양치 구역 라벨 — core/widgets/constants.dart 없이도 동작하도록 준비
const List<String> kBrushZoneLabelsKo = [
  '왼쪽 바깥니',           // 0
  '앞니 바깥니',           // 1
  '오른쪽 바깥니',         // 2
  '오른쪽 안쪽니',         // 3
  '앞니 안쪽니',           // 4
  '왼쪽 안쪽니',           // 5
  '왼쪽 혀쪽니',           // 6
  '앞니 혀쪽니',           // 7
  '오른쪽 혀쪽니',         // 8
  '오른쪽 윗 어금니 씹는면', // 9
  '왼쪽 윗 어금니 씹는면',   // 10
  '왼쪽 아래 어금니 씹는면', // 11
  '오른쪽 아래 어금니 씹는면',// 12
];

/// (로컬) 0..1 → "NN%"
String toPercentString(double v) =>
    '${(v.clamp(0.0, 1.0) * 100).toStringAsFixed(0)}%';

/// 라이브 브러쉬 종료 후 결과 페이지.
/// - 상단 레이더 차트: 13구역 진행도(scores01: 0..1)
/// - 하단 피드백: threshold 미만인 구역 리스트업
/// - 완료 버튼: onDone 콜백 호출 (예: 일일 3칸 중 1칸 채우기)
class BrushResultPage extends StatelessWidget {
  final List<double> scores01; // 길이 13, 각 0..1
  final double threshold;      // 미달 기준 (기본 0.6 권장)
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

            // 레이더 차트
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
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 간단 요약
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                '전체 평균: ${toPercentString(_avg(scores01))}  /  최소: ${toPercentString(scores01.reduce((a, b) => a < b ? a : b))}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),

            const SizedBox(height: 8),

            // 부족 구역 피드백
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: (weakIndices.isEmpty)
                    ? const _CongratsView()
                    : _WeakList(weakIndices: weakIndices, scores01: scores01),
              ),
            ),

            // 완료 버튼
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
                    onDone?.call();          // 외부 상태 갱신(예: 일일 1칸 채우기)
                    Navigator.pop(context);  // 결과 닫기
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
            ? kBrushZoneLabelsKo[idx]
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
