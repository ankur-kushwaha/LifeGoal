import 'package:flutter/material.dart';
import '../constants.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 64,
    this.showBackground = true,
  });

  final double size;
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        'assets/icon/app_icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );

    if (!showBackground) return image;

    return Container(
      padding: EdgeInsets.all(size * 0.12),
      decoration: BoxDecoration(
        color: kMoneyGreen.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: image,
    );
  }
}
