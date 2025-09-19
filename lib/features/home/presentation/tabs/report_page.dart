// 📍 lib/features/home/presentation/tabs/report_page.dart (수정 완료된 전체 파일)

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:chicachew/app/app_theme.dart';

import 'package:chicachew/core/storage/active_profile_store.dart';
import 'package:chicachew/core/storage/local_store.dart';
import 'package:chicachew/core/storage/profile.dart';
import 'package:chicachew/core/records/brush_record_store.dart';

// ✨ [추가] 새로 만든 상세 리포트 페이지를 import 합니다.
import 'daily_report_page.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});
  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  List<Profile> _profiles = [];
  int _activeIndex = -1;
  List<BrushRecord> _records = [];
  bool _isLoading = true;

  String get _userKey => _activeIndex >= 0 ? 'idx$_activeIndex' : 'idx-1';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final store = LocalStore();
    final profiles = await store.getProfiles();
    final activeIndex = await ActiveProfileStore.getIndex() ?? (profiles.isNotEmpty ? 0 : -1);

    List<BrushRecord> records = [];
    if (activeIndex != -1) {
      records = await BrushRecordStore.getRecords('idx$activeIndex');
    }

    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _activeIndex = activeIndex;
      _records = records;
      _isLoading = false;
    });
  }

  Future<void> _onProfileSelected(int index) async {
    if (index < 0 || index >= _profiles.length) return;
    await ActiveProfileStore.setIndex(index);
    await _loadData();
  }

  Future<void> _changeMonth(int delta) async {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  int _daysInMonth(DateTime m) => DateUtils.getDaysInMonth(m.year, m.month);
  int _leadingEmpty(DateTime m) {
    final w = DateTime(m.year, m.month, 1).weekday;
    return w % 7;
  }

  List<DateTime> _currentWeekDays() {
    final now = DateTime.now();
    final sunStart = now.subtract(Duration(days: now.weekday % 7));
    return List.generate(7, (i) => DateTime(sunStart.year, sunStart.month, sunStart.day + i));
  }

  int _getBrushCountForDay(DateTime date) {
    final dayKey = BrushRecordStore.dayKey(date);
    return _records.where((r) => BrushRecordStore.dayKey(r.timestamp) == dayKey).length;
  }

  List<BrushRecord> _getRecordsForDay(DateTime date) {
    final dayKey = BrushRecordStore.dayKey(date);
    return _records.where((r) => BrushRecordStore.dayKey(r.timestamp) == dayKey).toList();
  }

  List<BrushSlot> _getSlotsForDay(DateTime date) {
    final dayKey = BrushRecordStore.dayKey(date);
    return _records
        .where((r) => BrushRecordStore.dayKey(r.timestamp) == dayKey)
        .map((r) => r.slot)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeProfile = (_activeIndex >= 0 && _activeIndex < _profiles.length)
        ? _profiles[_activeIndex]
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('리포트'),
        actions: [
          if (_profiles.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: PopupMenuButton<int>(
                onSelected: _onProfileSelected,
                itemBuilder: (context) => [
                  for (int i = 0; i < _profiles.length; i++)
                    PopupMenuItem(
                      value: i,
                      child: Text(_profiles[i].name),
                    ),
                ],
                child: Chip(
                  avatar: const Icon(Icons.person_outline, size: 18),
                  label: Text(activeProfile?.name ?? '프로필 선택'),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _activeIndex == -1
            ? const Center(child: Text('표시할 프로필이 없습니다.'))
            : Builder(builder: (context) {
          final days = _daysInMonth(_month);
          final leading = _leadingEmpty(_month);
          final totalCells = leading + days;
          final trailing = (totalCells % 7 == 0) ? 0 : 7 - (totalCells % 7);

          final success3 = List.generate(days, (i) {
            final d = DateTime(_month.year, _month.month, i + 1);
            return _getBrushCountForDay(d) >= 3 ? 1 : 0;
          }).fold<int>(0, (a, b) => a + b);

          final today = DateTime.now();
          final todayCount = _getBrushCountForDay(today);
          final weekDays = _currentWeekDays();
          final weekCounts = weekDays.map((d) => _getBrushCountForDay(d)).toList();
          final weekTotal = weekCounts.fold<int>(0, (a, b) => a + b);
          final weekFullDays = weekCounts.where((c) => c >= 3).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                child: Column(
                  children: [
                    // ... (상단 요약, 월 이동 바, 요일 헤더는 기존과 동일하게 유지) ...
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: leading + days + trailing,
                      itemBuilder: (context, index) {
                        if (index < leading || index >= leading + days) {
                          return const SizedBox.shrink();
                        }
                        final dayNum = index - leading + 1;
                        final date = DateTime(_month.year, _month.month, dayNum);
                        final slots = _getSlotsForDay(date);

                        // ✨ [수정] DayChip을 GestureDetector로 감싸서 클릭 이벤트를 추가합니다.
                        return GestureDetector(
                          onTap: () {
                            final recordsForDay = _getRecordsForDay(date);
                            // 기록이 있는 날짜만 상세 페이지로 이동
                            if (recordsForDay.isNotEmpty) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => DailyReportPage(
                                    date: date,
                                    records: recordsForDay,
                                  ),
                                ),
                              );
                            }
                          },
                          child: _DayChip(
                            day: dayNum,
                            isToday: BrushRecordStore.dayKey(date) == BrushRecordStore.dayKey(DateTime.now()),
                            filled: [
                              slots.contains(BrushSlot.morning),
                              slots.contains(BrushSlot.noon),
                              slots.contains(BrushSlot.night),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _TodayCard(count: todayCount),
              const SizedBox(height: 12),
              _WeeklyCard(
                days: weekDays,
                counts: weekCounts,
                totalSessions: weekTotal,
                fullDays: weekFullDays,
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  final int count; // 오늘 완료 횟수(0~3)
  const _TodayCard({required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = count / 3.0;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("오늘의 양치",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              )),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: _Ring3(
                  filled: [count >= 1, count >= 2, count >= 3],
                  ringWidth: 5,
                  color: cs.primary,
                  trackColor: cs.primary.withOpacity(.25),
                  borderColor: cs.outlineVariant,
                  gapDeg: 8,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: pct,
                      backgroundColor: cs.primary.withOpacity(.18),
                      color: cs.primary,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    const SizedBox(height: 6),
                    Text("$count/3 완료",
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        )),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyCard extends StatelessWidget {
  final List<DateTime> days; // 7일(일~토)
  final List<int> counts; // 각 일자 0~3
  final int totalSessions; // 합계(최대 21)
  final int fullDays; // 3/3 달성 일수
  const _WeeklyCard({
    required this.days,
    required this.counts,
    required this.totalSessions,
    required this.fullDays,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final labels = const ['일', '월', '화', '수', '목', '금', '토'];

    final start = days.first;
    final end = days.last;
    final rangeTxt = "${start.month}/${start.day} ~ ${end.month}/${end.day}";

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("주간 기록",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              )),
          const SizedBox(height: 6),
          Text(rangeTxt,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 12.5,
              )),
          const SizedBox(height: 12),
          Row(
            children: List.generate(7, (i) {
              final cnt = counts[i];
              return Expanded(
                child: Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cs.primary.withOpacity(0.06),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        padding: const EdgeInsets.all(5),
                        child: _Ring3(
                          filled: [cnt >= 1, cnt >= 2, cnt >= 3],
                          ringWidth: 3.2,
                          color: cs.primary,
                          trackColor: cs.primary.withOpacity(.25),
                          borderColor: cs.outlineVariant,
                          gapDeg: 8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(labels[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurfaceVariant,
                        )),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  title: "완전 달성",
                  value: "$fullDays일",
                  icon: Icons.verified_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  title: "총 횟수",
                  value: "$totalSessions/21",
                  icon: Icons.check_circle_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const _StatTile({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.primary.darken(.12)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                )),
          ),
          Text(value,
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w800,
              )),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final int day;
  final bool isToday;
  final List<bool> filled; // [morning, noon, night]
  const _DayChip({required this.day, required this.isToday, required this.filled});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bool isDone = filled.any((b) => b);

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // 양치 기록이 있는 날은 배경색을 살짝 추가
          color: isDone ? cs.primaryContainer.withOpacity(0.4) : Colors.transparent,
          border: Border.all(
            color: isToday ? cs.primary : cs.outlineVariant.withOpacity(0.3),
            width: isToday ? 2.0 : 1.0,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 링 UI
            LayoutBuilder(
              builder: (context, cons) {
                final size = math.min(cons.maxWidth, cons.maxHeight);
                return SizedBox(
                  width: size,
                  height: size,
                  child: _Ring3(
                    filled: filled,
                  ),
                );
              },
            ),
            // 날짜 텍스트
            Text(
              "$day",
              style: TextStyle(
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =================================================================
// ✅ [수정] 아래 두 클래스(_Ring3, _Ring3Painter)가 수정되었습니다.
// =================================================================

class _Ring3 extends StatelessWidget {
  final List<bool> filled;
  final double? ringWidth;
  final double? gapDeg;
  final Color? color;
  final Color? trackColor;
  final Color? borderColor;

  const _Ring3({
    super.key,
    required this.filled,
    this.ringWidth,
    this.gapDeg,
    this.color,
    this.trackColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _Ring3Painter(
        filled: filled,
        // 외부에서 전달된 값이 있으면 그 값을 사용하고, 없으면 테마나 기본값을 사용합니다.
        ringWidth: ringWidth ?? 5.0,
        gapDeg: gapDeg ?? 8.0,
        color: color ?? cs.primary,
        trackColor: trackColor ?? cs.surfaceVariant,
        borderColor: borderColor ?? cs.outlineVariant.withOpacity(0.5),
      ),
    );
  }
}

class _Ring3Painter extends CustomPainter {
  final List<bool> filled;
  final Color color, trackColor, borderColor;
  final double ringWidth;
  final double gapDeg;

  _Ring3Painter({
    required this.filled,
    required this.color,
    required this.trackColor,
    required this.borderColor,
    required this.ringWidth,
    required this.gapDeg,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2;

    // 트랙 (링의 배경)
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..color = trackColor;
    canvas.drawCircle(c, r - ringWidth / 2, track);

    // 채워진 부분
    final seg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..strokeCap = StrokeCap.round // 끝 부분을 둥글게
      ..color = color;

    final sweep = (120.0 - gapDeg) * math.pi / 180.0;
    final baseAngles = [-90.0, 30.0, 150.0]; // 12시, 4시, 8시 방향

    for (int i = 0; i < 3; i++) {
      if (i < filled.length && filled[i]) {
        final startDeg = baseAngles[i] + gapDeg / 2;
        final startRad = startDeg * math.pi / 180.0;
        canvas.drawArc(
            Rect.fromCircle(center: c, radius: r - ringWidth / 2), startRad, sweep, false, seg);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Ring3Painter old) =>
      old.filled != filled ||
          old.color != color ||
          old.trackColor != trackColor ||
          old.borderColor != borderColor ||
          old.ringWidth != ringWidth ||
          old.gapDeg != gapDeg;
}