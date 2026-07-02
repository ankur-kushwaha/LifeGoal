import 'package:flutter/material.dart';
import '../constants.dart';

/// Progress bar scaled to the inflation-adjusted target, with markers for
/// original budget, projected savings at target date, and current savings fill.
class MultipointProgressBar extends StatelessWidget {
  final double actualTarget;
  final double inflationAdjustedTarget;
  final double currentSavings;
  final double projectedSavings;
  final double returnRatePct;
  final String targetDateLabel;
  final Color fillColor;
  final String Function(double) formatCurrency;

  static const Color _originalColor = Color(0xFF90A4AE);

  const MultipointProgressBar({
    super.key,
    required this.actualTarget,
    required this.inflationAdjustedTarget,
    required this.currentSavings,
    required this.projectedSavings,
    required this.returnRatePct,
    required this.targetDateLabel,
    required this.fillColor,
    required this.formatCurrency,
  });

  double get progressPercent {
    if (inflationAdjustedTarget <= 0) return 100.0;
    return (currentSavings / inflationAdjustedTarget * 100).clamp(0.0, 100.0);
  }

  double _fraction(double value) {
    if (inflationAdjustedTarget <= 0) return 0;
    return (value / inflationAdjustedTarget).clamp(0.0, 1.0);
  }

  Widget _buildPointLabel({
    required String label,
    required double fraction,
    required Color color,
    required bool aboveBar,
  }) {
    final clampedFraction = fraction.clamp(0.04, 0.96);
    final alignmentX = (clampedFraction * 2) - 1;

    return Positioned.fill(
      child: Align(
        alignment: Alignment(alignmentX, aboveBar ? -1 : 1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryPanel() {
    final achievementPct = inflationAdjustedTarget > 0
        ? (projectedSavings / inflationAdjustedTarget * 100)
        : 100.0;
    final gap = projectedSavings - inflationAdjustedTarget;
    final hasSurplus = gap >= 0;
    final gapAmount = gap.abs();

    final outcomeText = gapAmount < 1
        ? 'You will exactly meet your inflated goal on the target date.'
        : hasSurplus
            ? 'You will achieve ${achievementPct.toStringAsFixed(0)}% of your inflated goal, with a surplus of ${formatCurrency(gapAmount)}.'
            : 'You will achieve ${achievementPct.toStringAsFixed(0)}% of your inflated goal, with a shortfall of ${formatCurrency(gapAmount)}.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Text(
        'Your current savings of ${formatCurrency(currentSavings)}, with ${returnRatePct.toStringAsFixed(0)}% interest, will reach ${formatCurrency(projectedSavings)} on $targetDateLabel. $outcomeText',
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 11,
          height: 1.45,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SizedBox(
                    height: 52,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Top labels: Interest, Inflation
                        
                        _buildPointLabel(
                          label: 'Inflated Goal',
                          fraction: 1.0,
                          color: kMoneyGreen,
                          aboveBar: true,
                        ),
                        _buildPointLabel(
                          label: 'With Interest',
                          fraction: _fraction(projectedSavings),
                          color: kMoneyGreen,
                          aboveBar: true,
                        ),
                        // Bar
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 16,
                          height: 20,
                          child: CustomPaint(
                            painter: _MultipointProgressPainter(
                              scaleMax: inflationAdjustedTarget,
                              currentSavings: currentSavings,
                              actualTarget: actualTarget,
                              projectedSavings: projectedSavings,
                              fillColor: fillColor,
                            ),
                            size: Size(constraints.maxWidth, 20),
                          ),
                        ),
                        // Bottom labels: Savings, Goal
                        _buildPointLabel(
                          label: 'Savings',
                          fraction: _fraction(currentSavings),
                          color: fillColor,
                          aboveBar: false,
                        ),
                        _buildPointLabel(
                          label: 'Goal',
                          fraction: _fraction(actualTarget),
                          color: _originalColor,
                          aboveBar: false,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${progressPercent.toStringAsFixed(0)}%',
              style: TextStyle(
                color: fillColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '${formatCurrency(currentSavings)} saved of ${formatCurrency(inflationAdjustedTarget)}',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        _buildSummaryPanel(),
      ],
    );
  }
}

class _MultipointProgressPainter extends CustomPainter {
  final double scaleMax;
  final double currentSavings;
  final double actualTarget;
  final double projectedSavings;
  final Color fillColor;

  static const Color _originalColor = Color(0xFF90A4AE);
  static const Color _interestColor = Color(0xFF9ADFC8);

  _MultipointProgressPainter({
    required this.scaleMax,
    required this.currentSavings,
    required this.actualTarget,
    required this.projectedSavings,
    required this.fillColor,
  });

  double _fraction(double value) {
    if (scaleMax <= 0) return 0;
    return (value / scaleMax).clamp(0.0, 1.0);
  }

  void _drawDot(
    Canvas canvas,
    double x,
    double centerY,
    Color color, {
    bool filled = false,
    double radius = 5,
  }) {
    final paint = Paint()
      ..color = filled ? color : Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(x, centerY), radius, paint);

    canvas.drawCircle(
      Offset(x, centerY),
      radius,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    const barHeight = 6.0;
    final barTop = size.height / 2 - barHeight / 2;
    final barWidth = size.width;
    final centerY = barTop + barHeight / 2;

    // Track
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, barTop, barWidth, barHeight),
      const Radius.circular(3),
    );
    canvas.drawRRect(trackRect, Paint()..color = const Color(0xFFE8ECF0));

    // Inflation zone tint (original → inflation adjusted)
    final originalX = barWidth * _fraction(actualTarget);
    if (actualTarget > 0 && actualTarget < scaleMax) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(originalX, barTop, barWidth - originalX, barHeight),
          const Radius.circular(3),
        ),
        Paint()..color = kMoneyGreen.withValues(alpha: 0.08),
      );
    }

    // With-interest segment (current savings → projected)
    final currentX = barWidth * _fraction(currentSavings);
    final projectedX = barWidth * _fraction(projectedSavings);
    if (projectedSavings > currentSavings && projectedX > currentX) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(currentX, barTop, projectedX - currentX, barHeight),
          const Radius.circular(3),
        ),
        Paint()..color = _interestColor,
      );
    }

    // Current savings fill
    final fillWidth = currentX;
    if (fillWidth > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, barTop, fillWidth, barHeight),
          const Radius.circular(3),
        ),
        Paint()..color = fillColor,
      );
    }

    // Original budget tick
    if (actualTarget > 0 && actualTarget < scaleMax) {
      final x = barWidth * _fraction(actualTarget);
      canvas.drawLine(
        Offset(x, barTop - 2),
        Offset(x, barTop + barHeight + 2),
        Paint()
          ..color = _originalColor
          ..strokeWidth = 1.5,
      );
      _drawDot(canvas, x, centerY, _originalColor);
    }

    // Projected at target date (with interest)
    if (projectedSavings > 0) {
      final x = projectedX;
      _drawDot(canvas, x, centerY, _interestColor, filled: true);
    }

    // Goal end cap
    if (scaleMax > 0) {
      final x = barWidth;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 3, barTop - 1, 3, barHeight + 2),
          const Radius.circular(1.5),
        ),
        Paint()..color = kMoneyGreen,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MultipointProgressPainter oldDelegate) {
    return oldDelegate.scaleMax != scaleMax ||
        oldDelegate.currentSavings != currentSavings ||
        oldDelegate.actualTarget != actualTarget ||
        oldDelegate.projectedSavings != projectedSavings ||
        oldDelegate.fillColor != fillColor;
  }
}
