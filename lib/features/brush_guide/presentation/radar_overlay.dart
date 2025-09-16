// 📍 lib/features/brush_guide/presentation/radar_overlay.dart
// (파일 전체를 이 코드로 교체하세요)

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum RadarFx { none, radialPulse }

// ✅ StatelessWidget -> StatefulWidget 으로 올바르게 수정했습니다.
class RadarOverlay extends StatefulWidget {
  final List<double>? scores;
  final int activeIndex;
  final double size;
  final bool expand;
  final bool fallbackDemoIfEmpty;
  final RadarFx fx;
  final Duration fxPeriod;
  final bool showHighlight;
  final List<String>? labels;

  const RadarOverlay({
    super.key,
    required this.scores,
    required this.activeIndex,
    this.size = 280,
    this.expand = true,
    this.fallbackDemoIfEmpty = true,
    this.fx = RadarFx.none,
    this.fxPeriod = const Duration(milliseconds: 1400),
    this.showHighlight = true,
    this.labels,
  });

  @override
  State<RadarOverlay> createState() => _RadarOverlayState();
}

class _RadarOverlayState extends State<RadarOverlay>
    with SingleTickerProviderStateMixin {
  AnimationController? _ac;

  @override
  void initState() {
    super.initState();
    _maybeInitAnim();
  }

  @override
  void didUpdateWidget(covariant RadarOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fx != widget.fx || oldWidget.fxPeriod != widget.fxPeriod) {
      _disposeAnim();
      _maybeInitAnim();
    }
  }

  void _maybeInitAnim() {
    if (widget.fx == RadarFx.none) return;
    _ac = AnimationController(vsync: this, duration: widget.fxPeriod)..repeat();
  }

  void _disposeAnim() {
    _ac?.dispose();
    _ac = null;
  }

  @override
  void dispose() {
    _disposeAnim();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final painterBuilder = () => _RadarOverlayPainter(
      scores: widget.scores,
      activeIndex: widget.activeIndex,
      t: _ac?.value ?? 0.0,
      fx: widget.fx,
      showHighlight: widget.showHighlight,
      fallbackDemoIfEmpty: widget.fallbackDemoIfEmpty,
      labels: widget.labels,
      labelStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
        fontSize: 12,
      ),
    );

    final child = (_ac == null)
        ? CustomPaint(painter: painterBuilder())
        : AnimatedBuilder(
      animation: _ac!,
      builder: (_, __) => CustomPaint(painter: painterBuilder()),
    );

    if (widget.expand) {
      return LayoutBuilder(
        builder: (_, c) => SizedBox(width: c.maxWidth, height: c.maxHeight, child: child),
      );
    } else {
      return SizedBox(width: widget.size, height: widget.size, child: child);
    }
  }
}

class _RadarOverlayPainter extends CustomPainter {
  final List<double>? scores;
  final int activeIndex;
  final double t;
  final RadarFx fx;
  final bool showHighlight;
  final bool fallbackDemoIfEmpty;
  final List<String>? labels;
  final TextStyle labelStyle;

  _RadarOverlayPainter({
    required this.scores,
    required this.activeIndex,
    required this.t,
    required this.fx,
    required this.showHighlight,
    required this.fallbackDemoIfEmpty,
    this.labels,
    required this.labelStyle,
  });

  List<double> _safe13(List<double>? src) {
    if (src == null || src.length != 13) {
      if (!fallbackDemoIfEmpty) return List.filled(13, 0.0);
      final rnd = Random(13);
      return List<double>.generate(13, (_) => 0.3 + rnd.nextDouble() * 0.6);
    }
    return src.map((v) => v.clamp(0.0, 1.0)).toList();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final vals = _safe13(scores);

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) * 0.35;
    const int n = 13;
    const int levels = 5;
    final start = -pi / 2;
    final sweep = 2 * pi / n;

    final gridPaint = Paint()..color = Colors.grey.shade500.withOpacity(0.9)..style = PaintingStyle.stroke..strokeWidth = 1.2..isAntiAlias = true;
    final axisPaint = Paint()..color = Colors.grey.shade500.withOpacity(0.6)..style = PaintingStyle.stroke..strokeWidth = 1..isAntiAlias = true;
    final dataFill = Paint()..color = const Color(0xFFFF6B6B).withOpacity(0.28)..style = PaintingStyle.fill..isAntiAlias = true;
    final dataStroke = Paint()..color = const Color(0xFFE53935)..style = PaintingStyle.stroke..strokeWidth = 2..isAntiAlias = true;
    final highlightFill = Paint()..color = Colors.amber.withOpacity(0.18)..style = PaintingStyle.fill..isAntiAlias = true;
    final highlightStroke = Paint()..color = Colors.amber.withOpacity(0.8)..style = PaintingStyle.stroke..strokeWidth = 2..isAntiAlias = true;

    Path _polyOf(double r) {
      final p = Path();
      for (int i = 0; i < n; i++) {
        final a = start + i * sweep;
        final v = Offset(center.dx + r * cos(a), center.dy + r * sin(a));
        i == 0 ? p.moveTo(v.dx, v.dy) : p.lineTo(v.dx, v.dy);
      }
      p.close();
      return p;
    }

    for (int l = 1; l <= levels; l++) {
      canvas.drawPath(_polyOf(radius * l / levels), gridPaint);
    }
    for (int i = 0; i < n; i++) {
      final a = start + i * sweep;
      final end = Offset(center.dx + radius * cos(a), center.dy + radius * sin(a));
      canvas.drawLine(center, end, axisPaint);
    }

    final dataPath = Path();
    for (int i = 0; i < n; i++) {
      final a = start + i * sweep;
      final r = radius * vals[i];
      final pt = Offset(center.dx + r * cos(a), center.dy + r * sin(a));
      i == 0 ? dataPath.moveTo(pt.dx, pt.dy) : dataPath.lineTo(pt.dx, pt.dy);
    }
    dataPath.close();
    canvas.drawPath(dataPath, dataFill);
    canvas.drawPath(dataPath, dataStroke);

    // (이하 방사형 이펙트 및 하이라이트 로직)
    if (fx != RadarFx.none) {
      canvas.save();
      canvas.clipPath(dataPath);
      switch (fx) {
        case RadarFx.radialPulse:
          const int waves = 3;
          final lineW = max(1.5, radius * 0.05);
          for (int k = 0; k < waves; k++) {
            final phase = (t + k / waves) % 1.0;
            final rr = radius * (0.18 + 0.82 * phase);
            final fade = (1.0 - phase).clamp(0.0, 1.0);
            canvas.drawCircle(center, rr, Paint()..style = PaintingStyle.stroke..strokeWidth = lineW..isAntiAlias = true..color = const Color(0xFFE53935).withOpacity(0.35 * fade));
          }
          break;
        default:
          break;
      }
      canvas.restore();
    }
    if (showHighlight && activeIndex >= 0 && activeIndex < 13) {
      final a0 = start + activeIndex * sweep;
      final a1 = start + ((activeIndex + 1) % 13) * sweep;
      final v0 = Offset(center.dx + radius * cos(a0), center.dy + radius * sin(a0));
      final v1 = Offset(center.dx + radius * cos(a1), center.dy + radius * sin(a1));
      final wedge = Path()..moveTo(center.dx, center.dy)..lineTo(v0.dx, v0.dy)..lineTo(v1.dx, v1.dy)..close();
      canvas.drawPath(wedge, highlightFill);
      canvas.drawPath(wedge, highlightStroke);
    }

    // 라벨을 그리는 로직
    if (labels != null && labels!.length == n) {
      final labelRadius = radius * 1.25;
      for (int i = 0; i < n; i++) {
        final angle = start + (2 * pi * i) / n;
        final x = center.dx + labelRadius * cos(angle);
        final y = center.dy + labelRadius * sin(angle);
        final textSpan = TextSpan(text: labels![i], style: labelStyle);
        final textPainter = TextPainter(
          text: textSpan,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout(minWidth: 0, maxWidth: size.width * 0.4);
        final offset = Offset(x - textPainter.width / 2, y - textPainter.height / 2);
        textPainter.paint(canvas, offset);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RadarOverlayPainter old) {
    return activeIndex != old.activeIndex ||
        !listEquals(old.scores, scores) ||
        old.t != t ||
        old.fx != fx ||
        old.showHighlight != old.showHighlight ||
        old.fallbackDemoIfEmpty != old.fallbackDemoIfEmpty ||
        !listEquals(old.labels, labels);
  }
}