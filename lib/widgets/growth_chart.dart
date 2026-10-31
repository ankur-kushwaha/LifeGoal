import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../constants.dart';
import '../models/goal_model.dart';

/// Line chart of recorded savings, future growth with no new SIP, and target.
class GrowthChart extends StatefulWidget {
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
  State<GrowthChart> createState() => _GrowthChartState();
}

class _GrowthChartState extends State<GrowthChart> {
  static const double _hitRadius = 22;

  GrowthChartPoint? _activePoint;
  Offset? _activeOffset;

  List<GrowthChartPoint> get _actualPoints =>
      widget.points.where((p) => !p.isProjected).toList();

  String _compact(double value) {
    if (value >= 10000000) return '₹${(value / 10000000).toStringAsFixed(1)}Cr';
    if (value >= 100000) return '₹${(value / 100000).toStringAsFixed(1)}L';
    return widget.currencyFormatter.format(value);
  }

  void _setActive(GrowthChartPoint? point, Offset? offset) {
    if (identical(_activePoint, point) && _activeOffset == offset) return;
    if (_activePoint != null &&
        point != null &&
        GoalModel.isSameCalendarDay(_activePoint!.date, point.date) &&
        (_activePoint!.amount - point.amount).abs() < 0.01 &&
        _activeOffset == offset) {
      return;
    }
    setState(() {
      _activePoint = point;
      _activeOffset = offset;
    });
  }

  void _updateFromLocalPosition(
    Offset local,
    Size size, {
    required bool clearIfMiss,
  }) {
    if (size.isEmpty) return;

    final layout = _ChartLayout.from(
      size: size,
      points: widget.points,
      targetAmount: widget.targetAmount,
      today: widget.today,
    );
    if (layout == null) {
      if (clearIfMiss) _setActive(null, null);
      return;
    }

    GrowthChartPoint? best;
    Offset? bestOffset;
    var bestDist = _hitRadius;

    for (final point in _actualPoints) {
      final offset = layout.toOffset(point.date, point.amount);
      final dist = (offset - local).distance;
      if (dist <= bestDist) {
        bestDist = dist;
        best = point;
        bestOffset = offset;
      }
    }

    if (best != null) {
      _setActive(best, bestOffset);
    } else if (clearIfMiss) {
      _setActive(null, null);
    }
  }

  @override
  void didUpdateWidget(covariant GrowthChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points) {
      if (_activePoint != null &&
          !widget.points.any((p) =>
              GoalModel.isSameCalendarDay(p.date, _activePoint!.date) &&
              (p.amount - _activePoint!.amount).abs() < 0.01)) {
        _activePoint = null;
        _activeOffset = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Text('No growth data yet', style: TextStyle(color: Colors.black38, fontSize: 12)),
        ),
      );
    }

    final hasProjected = widget.points.any((p) => p.isProjected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 200,
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final chartSize = Size(constraints.maxWidth, constraints.maxHeight);
              return MouseRegion(
                opaque: false,
                onHover: (event) => _updateFromLocalPosition(
                  event.localPosition,
                  chartSize,
                  clearIfMiss: true,
                ),
                onExit: (_) => _setActive(null, null),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) => _updateFromLocalPosition(
                    details.localPosition,
                    chartSize,
                    clearIfMiss: true,
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CustomPaint(
                        size: chartSize,
                        painter: _GrowthChartPainter(
                          points: widget.points,
                          targetAmount: widget.targetAmount,
                          today: widget.today,
                          activePoint: _activePoint,
                        ),
                      ),
                      if (_activePoint != null && _activeOffset != null)
                        _PointTooltip(
                          point: _activePoint!,
                          anchor: _activeOffset!,
                          chartSize: chartSize,
                          amountLabel: widget.currencyFormatter
                              .format(_activePoint!.amount),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            _legendDot(kMoneyGreen, 'Recorded'),
            if (hasProjected)
              _legendDash(kMoneyGreen.withOpacity(0.7), 'Projected (no new SIP)'),
            _legendDash(Colors.orangeAccent, 'Target ${_compact(widget.targetAmount)}'),
          ],
        ),
      ],
    );
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

class _PointTooltip extends StatelessWidget {
  final GrowthChartPoint point;
  final Offset anchor;
  final Size chartSize;
  final String amountLabel;

  const _PointTooltip({
    required this.point,
    required this.anchor,
    required this.chartSize,
    required this.amountLabel,
  });

  @override
  Widget build(BuildContext context) {
    const tooltipWidth = 148.0;
    const tooltipHeight = 52.0;
    const gap = 12.0;

    var left = anchor.dx - tooltipWidth / 2;
    left = left.clamp(4.0, math.max(4.0, chartSize.width - tooltipWidth - 4));

    final showAbove = anchor.dy - tooltipHeight - gap >= 4;
    final top = showAbove
        ? anchor.dy - tooltipHeight - gap
        : (anchor.dy + gap).clamp(4.0, chartSize.height - tooltipHeight - 4);

    return Positioned(
      left: left,
      top: top,
      width: tooltipWidth,
      child: IgnorePointer(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('dd MMM yyyy').format(point.date),
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  amountLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChartLayout {
  static const leftPad = 44.0;
  static const rightPad = 12.0;
  static const topPad = 16.0;
  static const bottomPad = 28.0;

  final double chartWidth;
  final double chartHeight;
  final DateTime minDate;
  final DateTime maxDate;
  final int dateSpan;
  final double yMin;
  final double yMax;

  const _ChartLayout({
    required this.chartWidth,
    required this.chartHeight,
    required this.minDate,
    required this.maxDate,
    required this.dateSpan,
    required this.yMin,
    required this.yMax,
  });

  static _ChartLayout? from({
    required Size size,
    required List<GrowthChartPoint> points,
    required double targetAmount,
    required DateTime today,
  }) {
    final chartWidth = size.width - leftPad - rightPad;
    final chartHeight = size.height - topPad - bottomPad;
    if (chartWidth <= 0 || chartHeight <= 0 || points.isEmpty) return null;

    final minDate = points.first.date;
    final maxDate = points.last.date.isAfter(today) ? points.last.date : today;
    final dateSpan = math.max(1, maxDate.difference(minDate).inDays);

    final minPointAmount = points
        .map((p) => p.amount)
        .fold<double>(double.infinity, math.min);
    final maxPointAmount = points
        .map((p) => p.amount)
        .fold<double>(0.0, math.max);

    final hasProjected = points.any((p) => p.isProjected);

    // In ALL mode (or when target is within 2.5x of current savings), include target in the scale.
    // If target is massive compared to short timeframe savings, focus on visible points so movement isn't flattened.
    final bool includeTarget = targetAmount > 0 &&
        (hasProjected || maxPointAmount <= 0 || targetAmount <= maxPointAmount * 2.5);

    final double effectiveMax = includeTarget
        ? math.max(targetAmount, maxPointAmount)
        : maxPointAmount;

    final double rawMin = minPointAmount.isFinite ? minPointAmount : 0.0;
    final double rawMax = effectiveMax <= 0 ? 1.0 : effectiveMax;

    final double rawSpan = rawMax - rawMin;
    final double pad = rawSpan > 0 ? rawSpan * 0.08 : rawMax * 0.1;

    // The chart doesn't need to start from 0 if the data is well above 0.
    // If min point is close to 0 (<= 15% of span or <= 0), start from 0.
    final double yMin;
    if (rawMin <= 0 || (rawSpan > 0 && rawMin <= rawSpan * 0.15)) {
      yMin = 0.0;
    } else {
      yMin = math.max(0.0, rawMin - pad);
    }

    final double yMax = rawMax + pad;

    return _ChartLayout(
      chartWidth: chartWidth,
      chartHeight: chartHeight,
      minDate: minDate,
      maxDate: maxDate,
      dateSpan: dateSpan,
      yMin: yMin,
      yMax: yMax,
    );
  }

  Offset toOffset(DateTime date, double amount) {
    final x = leftPad + (date.difference(minDate).inDays / dateSpan) * chartWidth;
    final ySpan = yMax - yMin;
    final normalized = ySpan <= 0
        ? 0.5
        : ((amount - yMin) / ySpan).clamp(0.0, 1.0);
    final y = topPad + chartHeight * (1.0 - normalized);
    return Offset(x, y);
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
  final GrowthChartPoint? activePoint;

  _GrowthChartPainter({
    required this.points,
    required this.targetAmount,
    required this.today,
    this.activePoint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final layout = _ChartLayout.from(
      size: size,
      points: points,
      targetAmount: targetAmount,
      today: today,
    );
    if (layout == null) return;

    final minDate = layout.minDate;
    final maxDate = layout.maxDate;
    final chartWidth = layout.chartWidth;
    final chartHeight = layout.chartHeight;
    final leftPad = _ChartLayout.leftPad;
    final topPad = _ChartLayout.topPad;

    Offset toOffset(DateTime date, double amount) => layout.toOffset(date, amount);

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
      final value = layout.yMax - (layout.yMax - layout.yMin) * (i / 3);
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
    if (targetAmount > 0 && targetAmount >= layout.yMin && targetAmount <= layout.yMax) {
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
      final path = Path()
        ..moveTo(
          toOffset(bridge.first.date, bridge.first.amount).dx,
          toOffset(bridge.first.date, bridge.first.amount).dy,
        );
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
      final isActive = activePoint != null &&
          GoalModel.isSameCalendarDay(activePoint!.date, p.date) &&
          (activePoint!.amount - p.amount).abs() < 0.01;
      if (isActive) {
        canvas.drawCircle(
          o,
          9,
          Paint()
            ..color = kMoneyGreen.withOpacity(0.18)
            ..style = PaintingStyle.fill,
        );
      }
      canvas.drawCircle(o, isActive ? 5.5 : 4.5, ringPaint);
      canvas.drawCircle(o, isActive ? 4.0 : 3.2, dotPaint);
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
      final isActive = activePoint != null &&
          GoalModel.isSameCalendarDay(activePoint!.date, todayPoint.date);
      if (!isActive) {
        canvas.drawCircle(
          o,
          6,
          Paint()
            ..color = kMoneyGreen.withOpacity(0.2)
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(o, 3.5, dotPaint);
      }
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
      tp.paint(
        canvas,
        Offset(
          x.clamp(leftPad, size.width - tp.width),
          topPad + chartHeight + 8,
        ),
      );
    }

    final isSingleDate = GoalModel.isSameCalendarDay(minDate, maxDate);
    final isEndsAtToday = GoalModel.isSameCalendarDay(today, maxDate);

    if (isSingleDate) {
      paintDateLabel(minDate, leftPad, center: false);
    } else if (isEndsAtToday) {
      paintDateLabel(minDate, leftPad, center: false);
      if (maxDate.difference(minDate).inDays >= 60) {
        final midDays = maxDate.difference(minDate).inDays ~/ 2;
        final midDate = minDate.add(Duration(days: midDays));
        final midX = toOffset(GoalModel.calendarDay(midDate), 0).dx;
        paintDateLabel(GoalModel.calendarDay(midDate), midX);
      }
      paintDateLabel(maxDate, leftPad + chartWidth - 1);
    } else {
      paintDateLabel(minDate, leftPad, center: false);
      final todayX = toOffset(GoalModel.calendarDay(today), 0).dx;
      final minRight = leftPad + 55.0;
      final maxLeft = leftPad + chartWidth - 55.0;
      if (todayX > minRight && todayX < maxLeft) {
        paintDateLabel(GoalModel.calendarDay(today), todayX);
      }
      paintDateLabel(maxDate, leftPad + chartWidth - 1);
    }
  }

  String _axisLabel(double value) {
    if (value.abs() < 0.01) return '0';
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
        oldDelegate.today != today ||
        oldDelegate.activePoint != activePoint;
  }
}
