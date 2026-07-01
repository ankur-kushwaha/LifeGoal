import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'constants.dart';
import 'firebase_options.dart';
import 'providers/goal_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    if (DefaultFirebaseOptions.isConfigured) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('Failed to initialize Firebase on startup: $e');
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => GoalProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LifeGoal AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: kMoneyGreen,
        scaffoldBackgroundColor: kScaffoldBg,
        colorScheme: const ColorScheme.light(
          primary: kMoneyGreen,
          secondary: Color(0xFF059669),
          surface: kCardBg,
          onSurface: Colors.black87,
        ),
        cardTheme: CardThemeData(
          color: kCardBg,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: kMoneyGreen,
          thumbColor: kMoneyGreen,
          overlayColor: Colors.black26,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

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
