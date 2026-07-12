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
    required double stackWidth,
    required String label,
    required double fraction,
    required Color color,
    required bool aboveBar,
  }) {
    final clampedFraction = fraction.clamp(0.0, 1.0);
    final leftPosition = clampedFraction * stackWidth;

    return Positioned(
      left: leftPosition,
      top: aboveBar ? 0 : null,
      bottom: aboveBar ? null : 0,
      child: FractionalTranslation(
        // Shift left to center the label exactly on the point
        // Smoothly adjust alignment near the edges to prevent text overflow
        translation: Offset(
          clampedFraction < 0.15
              ? -clampedFraction / 0.3
              : clampedFraction > 0.85
                  ? -0.5 - (clampedFraction - 0.85) / 0.3
                  : -0.5,
          0.0,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withOpacity(0.15), width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 3,
                offset: const Offset(0, 1),
              )
            ],
          ),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 7.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final projectedFraction = _fraction(projectedSavings);
    final savingsFraction = _fraction(currentSavings);
    final goalFraction = _fraction(actualTarget);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
    );
  }
}

class _MultipointProgressPainter extends CustomPainter {
  final double scaleMax;
  final double currentSavings;
  final double actualTarget;
  final double projectedSavings;
  final Color fillColor;

  static const Color _originalColor = Color(0xFF94A3B8); // slate-400
  static const Color _interestColor = Color(0xFF6EE7B7); // emerald-300

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
    double radius = 4.0,
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
    const barHeight = 4.0;
    final barTop = size.height / 2 - barHeight / 2;
    final barWidth = size.width;
    final centerY = barTop + barHeight / 2;

    // Track
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, barTop, barWidth, barHeight),
      const Radius.circular(2),
    );
    canvas.drawRRect(trackRect, Paint()..color = const Color(0xFFE2E8F0)); // slate-200

    // Inflation zone tint (original -> inflation adjusted)
    final originalX = barWidth * _fraction(actualTarget);
    if (actualTarget > 0 && actualTarget < scaleMax) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(originalX, barTop, barWidth - originalX, barHeight),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFFCBD5E1).withOpacity(0.3), // slate-300 tint
      );
    }

    // With-interest segment (current savings -> projected)
    final currentX = barWidth * _fraction(currentSavings);
    final projectedX = barWidth * _fraction(projectedSavings);
    if (projectedSavings > currentSavings && projectedX > currentX) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(currentX, barTop, projectedX - currentX, barHeight),
          const Radius.circular(2),
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
          const Radius.circular(2),
        ),
        Paint()..color = fillColor,
      );
    }

    // Original budget tick
    if (actualTarget > 0 && actualTarget < scaleMax) {
      final x = barWidth * _fraction(actualTarget);
      canvas.drawLine(
        Offset(x, barTop - 3),
        Offset(x, barTop + barHeight + 3),
        Paint()
          ..color = _originalColor
          ..strokeWidth = 1.5,
      );
      _drawDot(canvas, x, centerY, _originalColor, radius: 3.5);
    }

    // Current savings dot
    if (currentSavings > 0) {
      _drawDot(canvas, currentX, centerY, fillColor, filled: true, radius: 4.5);
    }

    // Projected at target date (with interest)
    if (projectedSavings > currentSavings && projectedSavings > 0) {
      _drawDot(canvas, projectedX, centerY, _interestColor, filled: true, radius: 4.5);
    }

    // Goal end cap
    if (scaleMax > 0) {
      final x = barWidth;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 3, barTop - 2, 3, barHeight + 4),
          const Radius.circular(1.5),
        ),
        Paint()..color = const Color(0xFF0F172A), // slate-900 end cap
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
