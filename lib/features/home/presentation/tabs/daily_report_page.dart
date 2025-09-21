// 📍 lib/features/home/presentation/tabs/daily_report_page.dart (전체 파일)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:chicachew/core/records/brush_record_store.dart';
import 'package:chicachew/features/brush_guide/presentation/brush_result_page.dart';
import 'package:chicachew/features/brush_guide/presentation/radar_overlay.dart';


class DailyReportPage extends StatelessWidget {
  final DateTime date;
  final List<BrushRecord> records;

  const DailyReportPage({
    super.key,
    required this.date,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    final morningRecord = records.where((r) => r.slot == BrushSlot.morning).firstOrNull;
    final noonRecord = records.where((r) => r.slot == BrushSlot.noon).firstOrNull;
    final nightRecord = records.where((r) => r.slot == BrushSlot.night).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('M월 d일 (E)', 'ko_KR').format(date)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _ReportSection(
            title: '아침',
            icon: Icons.wb_sunny_outlined,
            record: morningRecord,
          ),
          _ReportSection(
            title: '점심',
            icon: Icons.fastfood_outlined,
            record: noonRecord,
          ),
          _ReportSection(
            title: '저녁',
            icon: Icons.nightlight_outlined,
            record: nightRecord,
          ),
        ],
      ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final BrushRecord? record;

  const _ReportSection({
    required this.title,
    required this.icon,
    this.record,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          record == null ? '양치 기록이 없어요' : '평균 ${toPercentString(record!.avgScore)} · ${DateFormat('a h:mm', 'ko_KR').format(record!.timestamp)}',
        ),
        children: [
          if (record != null)
            _ResultDetailView(record: record!),
        ],
      ),
    );
  }
}

class _ResultDetailView extends StatelessWidget {
  final BrushRecord record;
  final double threshold = 0.6;

  const _ResultDetailView({required this.record});

  int _minIndex(List<double> v) {
    if (v.isEmpty) return 0;
    var idx = 0;
    var minV = v[0];
    for (int i = 1; i < v.length; i++) {
      if (v[i] < minV) {
        minV = v[i];
        idx = i;
      }
    }
    return idx;
  }

  @override
  Widget build(BuildContext context) {
    final weakIndices = <int>[];
    for (int i = 0; i < record.scores.length; i++) {
      if (record.scores[i] < threshold) {
        weakIndices.add(i);
      }
    }

    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1.5,
            child: RadarOverlay(
              scores: record.scores,
              labels: kBrushZoneLabelsKo,
              expand: true,
              activeIndex: _minIndex(record.scores),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '조금 더 신경 써야 할 부분',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Divider(height: 24),
          if (weakIndices.isEmpty)
            const Text('모든 구역을 완벽하게 닦았어요! ✨')
          else
            ...weakIndices.map((idx) => ListTile(
              dense: true,
              leading: const Icon(Icons.info_outline, size: 20),
              title: Text(kBrushZoneLabelsKo[idx].replaceAll('\n', ' ')),
              trailing: Text(toPercentString(record.scores[idx])),
            )),
        ],
      ),
    );
  }
}