import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../constants.dart';

/// Constrains the app to a readable width on desktop web while keeping full width on mobile.
class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  static const double _maxContentWidth = 960;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    return ColoredBox(
      color: kScaffoldBg,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: kScaffoldBg,
              border: Border.symmetric(
                vertical: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 24,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
