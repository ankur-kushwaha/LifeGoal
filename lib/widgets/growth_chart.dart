import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../constants.dart';
import '../models/goal_model.dart';

/// Line chart of recorded savings, future growth with no new SIP, and target.
class GrowthChart extends StatelessWidget {
  final List<GrowthChartPoint> points;
  final double targetAmount;
  final DateTime today;
  final NumberFormat currencyFormatter;

  const GrowthChart({
    super.key,
    required this.points,
    required this.targetAmount,
    required this.today,
    required this.currencyFormatter,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Text('No growth data yet', style: TextStyle(color: Colors.black38, fontSize: 12)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 200,
          width: double.infinity,
          child: CustomPaint(
            painter: _GrowthChartPainter(
              points: points,
              targetAmount: targetAmount,
              today: today,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            _legendDot(kMoneyGreen, 'Recorded'),
            _legendDash(kMoneyGreen.withOpacity(0.7), 'Projected (no new SIP)'),
            _legendDash(Colors.orangeAccent, 'Target ${_compact(targetAmount)}'),
          ],
        ),
      ],
    );
  }

  String _compact(double value) {
    if (value >= 10000000) return '₹${(value / 10000000).toStringAsFixed(1)}Cr';
    if (value >= 100000) return '₹${(value / 100000).toStringAsFixed(1)}L';
    return currencyFormatter.format(value);
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 11)),
      ],
    );
  }

  Widget _legendDash(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(16, 8),
          painter: _DashLegendPainter(color),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 11)),
      ],
    );
  }
}

class _DashLegendPainter extends CustomPainter {
  final Color color;
  _DashLegendPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const dash = 3.0;
    const gap = 2.0;
    double x = 0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + dash, size.width), y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashLegendPainter oldDelegate) => oldDelegate.color != color;
}

class _GrowthChartPainter extends CustomPainter {
  final List<GrowthChartPoint> points;
  final double targetAmount;
  final DateTime today;

  _GrowthChartPainter({
    required this.points,
    required this.targetAmount,
    required this.today,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 44.0;
    const rightPad = 12.0;
    const topPad = 16.0;
    const bottomPad = 28.0;

    final chartWidth = size.width - leftPad - rightPad;
    final chartHeight = size.height - topPad - bottomPad;
    if (chartWidth <= 0 || chartHeight <= 0 || points.isEmpty) return;

    final minDate = points.first.date;
    final maxDate = points.last.date.isAfter(today) ? points.last.date : today;
    final dateSpan = math.max(1, maxDate.difference(minDate).inDays);

    final maxValue = math.max(
      targetAmount,
      points.map((p) => p.amount).fold<double>(0, math.max),
    );
    final yMax = maxValue <= 0 ? 1.0 : maxValue * 1.08;

    Offset toOffset(DateTime date, double amount) {
      final x = leftPad + (date.difference(minDate).inDays / dateSpan) * chartWidth;
      final y = topPad + chartHeight * (1 - (amount / yMax).clamp(0.0, 1.0));
      return Offset(x, y);
    }

    // Grid + axis
    final gridPaint = Paint()
      ..color = Colors.black.withOpacity(0.06)
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;

    for (var i = 0; i <= 3; i++) {
      final y = topPad + chartHeight * (i / 3);
      canvas.drawLine(Offset(leftPad, y), Offset(leftPad + chartWidth, y), gridPaint);
      final value = yMax * (1 - i / 3);
      final label = _axisLabel(value);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(color: Colors.black38, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: leftPad - 4);
      tp.paint(canvas, Offset(leftPad - tp.width - 4, y - tp.height / 2));
    }

    canvas.drawLine(
      Offset(leftPad, topPad + chartHeight),
      Offset(leftPad + chartWidth, topPad + chartHeight),
      axisPaint,
    );

    // Target line
    if (targetAmount > 0) {
      final targetY = toOffset(minDate, targetAmount).dy;
      _drawDashedLine(
        canvas,
        Offset(leftPad, targetY),
        Offset(leftPad + chartWidth, targetY),
        Paint()
          ..color = Colors.orangeAccent
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
      final targetLabel = TextPainter(
        text: const TextSpan(
          text: 'Target',
          style: TextStyle(
            color: Colors.orangeAccent,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      targetLabel.paint(canvas, Offset(leftPad + 4, targetY - targetLabel.height - 2));
    }

    final actual = points.where((p) => !p.isProjected).toList();
    final projected = points.where((p) => p.isProjected).toList();

    // Bridge from last actual to first projected
    final bridge = <GrowthChartPoint>[
      if (actual.isNotEmpty) actual.last,
      ...projected,
    ];

    if (bridge.length >= 2) {
      final path = Path()..moveTo(toOffset(bridge.first.date, bridge.first.amount).dx, toOffset(bridge.first.date, bridge.first.amount).dy);
      for (var i = 1; i < bridge.length; i++) {
        final o = toOffset(bridge[i].date, bridge[i].amount);
        path.lineTo(o.dx, o.dy);
      }
      _drawDashedPath(
        canvas,
        path,
        Paint()
          ..color = kMoneyGreen.withOpacity(0.75)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }

    if (actual.length >= 2) {
      final path = Path();
      for (var i = 0; i < actual.length; i++) {
        final o = toOffset(actual[i].date, actual[i].amount);
        if (i == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = kMoneyGreen
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Actual dots
    final dotPaint = Paint()..color = kMoneyGreen;
    final ringPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    for (final p in actual) {
      final o = toOffset(p.date, p.amount);
      canvas.drawCircle(o, 4.5, ringPaint);
      canvas.drawCircle(o, 3.2, dotPaint);
    }

    // Today marker
    GrowthChartPoint? todayPoint;
    for (final p in actual) {
      if (GoalModel.isSameCalendarDay(p.date, today)) {
        todayPoint = p;
        break;
      }
    }
    todayPoint ??= actual.isNotEmpty ? actual.last : null;
    if (todayPoint != null) {
      final o = toOffset(todayPoint.date, todayPoint.amount);
      canvas.drawCircle(
        o,
        6,
        Paint()
          ..color = kMoneyGreen.withOpacity(0.2)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(o, 3.5, dotPaint);
    }

    // X labels: start, today, end
    final labelStyle = const TextStyle(color: Colors.black38, fontSize: 9);
    void paintDateLabel(DateTime date, double anchorX, {bool center = true}) {
      final text = DateFormat('dd MMM yy').format(date);
      final tp = TextPainter(
        text: TextSpan(text: text, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = center ? anchorX - tp.width / 2 : anchorX;
      tp.paint(canvas, Offset(x.clamp(leftPad, size.width - tp.width), topPad + chartHeight + 8));
    }

    paintDateLabel(minDate, leftPad, center: false);
    final todayX = toOffset(GoalModel.calendarDay(today), 0).dx;
    paintDateLabel(GoalModel.calendarDay(today), todayX);
    paintDateLabel(maxDate, leftPad + chartWidth - 1);
  }

  String _axisLabel(double value) {
    if (value >= 10000000) return '${(value / 10000000).toStringAsFixed(1)}Cr';
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
    return value.toStringAsFixed(0);
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dash = 5.0;
    const gap = 4.0;
    final total = (end - start).distance;
    if (total <= 0) return;
    final direction = (end - start) / total;
    double drawn = 0;
    while (drawn < total) {
      final from = start + direction * drawn;
      final to = start + direction * math.min(drawn + dash, total);
      canvas.drawLine(from, to, paint);
      drawn += dash + gap;
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      const dash = 5.0;
      const gap = 4.0;
      while (distance < metric.length) {
        final next = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GrowthChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.targetAmount != targetAmount ||
        oldDelegate.today != today;
  }
}
