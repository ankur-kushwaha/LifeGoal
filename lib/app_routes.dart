import 'package:flutter/material.dart';
import 'auth_gate.dart';
import 'screens/privacy_policy_screen.dart';

class AppRoutes {
  static const String home = '/';
  static const String privacy = '/privacy';

  static String resolveInitialRoute() {
    final path = Uri.base.path;
    if (path == privacy || path == '$privacy/') {
      return privacy;
    }
    return home;
  }

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case privacy:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => const PrivacyPolicyScreen(),
        );
      case home:
      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => const AuthGate(),
        );
    }
  }
}
