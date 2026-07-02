import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'constants.dart';
import 'providers/goal_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GoalProvider>(context);

    if (provider.isLoading) {
      return const Scaffold(
        backgroundColor: kScaffoldBg,
        body: Center(
          child: CircularProgressIndicator(color: kMoneyGreen),
        ),
      );
    }

    if (provider.isAuthenticated) {
      return const DashboardScreen();
    }

    return const AuthScreen();
  }
}
