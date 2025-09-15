// lib/features/report/presentation/report_page.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:chicachew/core/records/brush_record_store.dart';
import 'package:chicachew/app/app_theme.dart'; // ColorShadeX 확장

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});
  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    BrushRecordStore.instance.loadMonth(_month);
  }

  Future<void> _changeMonth(int delta) async {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    await BrushRecordStore.instance.loadMonth(_month);
  }

  int _daysInMonth(DateTime m) => DateUtils.getDaysInMonth(m.year, m.month);
  int _leadingEmpty(DateTime m) {
    final w = DateTime(m.year, m.month, 1).weekday; // 1~7(월~일)
    return w % 7; // 일요일 시작 기준
  }

  // 이번 주(일~토) 날짜 리스트
  List<DateTime> _currentWeekDays() {
    final now = DateTime.now();
    final sunStart = now.subtract(Duration(days: now.weekday % 7));
    return List.generate(7, (i) => DateTime(sunStart.year, sunStart.month, sunStart.day + i));
  }

  @override
  Widget build(BuildContext context) {
    final store = BrushRecordStore.instance;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('리포트')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: store,
          builder: (context, _) {
            final days = _daysInMonth(_month);
            final leading = _leadingEmpty(_month);
            final totalCells = leading + days;
            final trailing = (totalCells % 7 == 0) ? 0 : 7 - (totalCells % 7);

            final success3 = List.generate(days, (i) {
              final d = DateTime(_month.year, _month.month, i + 1);
              return store.slotsOn(d).length == 3 ? 1 : 0;
            }).fold<int>(0, (a, b) => a + b);

            // 오늘/주간 데이터
            final today = DateTime.now();
            final todaySlots = store.slotsOn(today);
            final todayCount = todaySlots.length;
            final weekDays = _currentWeekDays();
            final weekCounts = weekDays.map((d) => store.slotsOn(d).length).toList();
            final weekTotal = weekCounts.fold<int>(0, (a, b) => a + b); // (최대 21)
            final weekFullDays = weekCounts.where((c) => c == 3).length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                // ===== 월간 달력 카드 =====
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
                      // 상단 요약
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.event_available_outlined,
                                size: 22, color: cs.primary.darken(.1)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "${_month.month}월 중 $success3일간 하루 세 번씩 양치에 성공했어요!",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.5,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 월 이동 바
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => _changeMonth(-1),
                            icon: Icon(Icons.chevron_left_rounded,
                                color: cs.onSurfaceVariant),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                "${_month.year}년 ${_month.month}월",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _changeMonth(1),
                            icon: Icon(Icons.chevron_right_rounded,
                                color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // 요일 헤더
                      Row(
                        children: List.generate(7, (i) {
                          final labels = ['일','월','화','수','목','금','토'];
                          final base = cs.onSurfaceVariant;
                          final color = (i == 0 || i == 6) ? base.darken(.15) : base;
                          return Expanded(
                            child: Center(
                              child: Text(labels[i],
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: color,
                                  )),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 8),

                      // 동그란 칩 달력
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
                          final slots = store.slotsOn(date);
                          final filled = [
                            slots.contains(BrushSlot.morning),
                            slots.contains(BrushSlot.noon),
                            slots.contains(BrushSlot.night),
                          ];
                          final isToday =
                              BrushRecordStore.dayKey(date) ==
                                  BrushRecordStore.dayKey(DateTime.now());

                          return _DayChip(
                            day: dayNum,
                            isToday: isToday,
                            filled: filled,
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ===== 오늘 요약 카드 =====
                _TodayCard(count: todayCount),

                const SizedBox(height: 12),

                // ===== 주간 기록 카드 =====
                _WeeklyCard(
                  days: weekDays,
                  counts: weekCounts,
                  totalSessions: weekTotal,
                  fullDays: weekFullDays,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 오늘 카드: "오늘의 양치" + 진행도
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
              // 원형 진행도 (3분할)
              SizedBox(
                width: 44, height: 44,
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

/// 주간 기록 카드: 일~토 칩 + 총합
class _WeeklyCard extends StatelessWidget {
  final List<DateTime> days;   // 7일(일~토)
  final List<int> counts;      // 각 일자 0~3
  final int totalSessions;     // 합계(최대 21)
  final int fullDays;          // 3/3 달성 일수
  const _WeeklyCard({
    required this.days,
    required this.counts,
    required this.totalSessions,
    required this.fullDays,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final labels = const ['일','월','화','수','목','금','토'];

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

          // 7칸 칩 (요일 라벨 + 링)
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
          // 요약 수치
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

/// ===== 공용 위젯들 (월간 달력에서 사용) =====

class _DayChip extends StatelessWidget {
  final int day;
  final bool isToday;
  final List<bool> filled; // [morning, noon, night]
  const _DayChip({required this.day, required this.isToday, required this.filled});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.primary.withOpacity(0.08),
            border: Border.all(
              color: isToday ? cs.primary.darken(.18) : cs.outlineVariant,
              width: isToday ? 1.4 : 1,
            ),
          ),
          padding: const EdgeInsets.all(6),
          child: Stack(
            alignment: Alignment.center,
            children: [
              LayoutBuilder(
                builder: (context, cons) {
                  final size = math.min(cons.maxWidth, cons.maxHeight);
                  return SizedBox(
                    width: size, height: size,
                    child: _Ring3(
                      filled: filled,
                      ringWidth: 3.6,
                      color: cs.primary,
                      trackColor: cs.primary.withOpacity(.25),
                      borderColor: cs.outlineVariant,
                      gapDeg: 8,
                    ),
                  );
                },
              ),
              Text("$day",
                  style: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurface)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 3분할 도넛 링(테두리 채움)
class _Ring3 extends StatelessWidget {
  final List<bool> filled;
  final double ringWidth;
  final Color color, trackColor, borderColor;
  final double gapDeg;
  const _Ring3({
    super.key,
    required this.filled,
    required this.ringWidth,
    required this.color,
    required this.trackColor,
    required this.borderColor,
    this.gapDeg = 6,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _Ring3Painter(
        filled: filled,
        ringWidth: ringWidth,
        color: color,
        trackColor: trackColor,
        borderColor: borderColor,
        gapDeg: gapDeg,
      ),
    );
  }
}

class _Ring3Painter extends CustomPainter {
  final List<bool> filled;
  final double ringWidth;
  final Color color, trackColor, borderColor;
  final double gapDeg;
  _Ring3Painter({
    required this.filled,
    required this.ringWidth,
    required this.color,
    required this.trackColor,
    required this.borderColor,
    required this.gapDeg,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - ringWidth / 2;

    // 트랙
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..color = trackColor.withOpacity(0.7);
    canvas.drawCircle(c, r, track);

    // 채움
    final seg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..strokeCap = StrokeCap.round
      ..color = color;

    // 외곽 가이드
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = borderColor;

    final base = [-90.0, 30.0, 150.0];
    final sweep = (120.0 - gapDeg) * math.pi / 180.0;

    for (int i = 0; i < 3; i++) {
      if (i < filled.length && filled[i]) {
        final startDeg = base[i] + gapDeg / 2;
        final start = startDeg * math.pi / 180.0;
        canvas.drawArc(Rect.fromCircle(center: c, radius: r), start, sweep, false, seg);
      }
    }
    canvas.drawCircle(c, r, outline);
  }

  @override
  bool shouldRepaint(covariant _Ring3Painter old) =>
      old.filled != filled || old.ringWidth != ringWidth ||
          old.color != color || old.trackColor != trackColor || old.gapDeg != gapDeg;
}
