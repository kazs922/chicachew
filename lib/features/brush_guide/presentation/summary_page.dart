import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:chicachew/features/brush_guide/application/summary_args.dart';

class SummaryPage extends StatelessWidget {
  final SummaryArgs args;

  const SummaryPage({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    // ✅ 구역 이름 정의
    const List<String> zoneLabels = [
      '왼쪽-협측',
      '중앙-협측',
      '오른쪽-협측',
      '오른쪽-구개측',
      '중앙-구개측',
      '왼쪽-구개측',
      '왼쪽-설측',
      '중앙-설측',
      '오른쪽-설측',
      '오른쪽-위-씹는면',
      '왼쪽-위-씹는면',
      '왼쪽-아래-씹는면',
      '오른쪽-아래-씹는면',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("양치 요약"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // ✅ 뒤로가기 → BrushTimePage 탭이 포함된 Home으로 이동
            context.go('/home');
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "총 양치 시간: ${args.durationSec}초",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text("구역별 점수", style: TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: args.scores.length,
                itemBuilder: (_, i) {
                  final score = args.scores[i];
                  final label = i < zoneLabels.length
                      ? zoneLabels[i]
                      : "구역 ${i + 1}";
                  return ListTile(
                    leading: Text(label),
                    title: LinearProgressIndicator(
                      value: score,
                      minHeight: 10,
                      backgroundColor: Colors.grey[300],
                      color: Colors.teal,
                    ),
                    trailing: Text("${(score * 100).toInt()}%"),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
