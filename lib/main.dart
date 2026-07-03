import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app_routes.dart';
import 'constants.dart';
import 'firebase_options.dart';
import 'providers/goal_provider.dart';
import 'providers/notification_provider.dart';
import 'widgets/app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    usePathUrlStrategy();
  }
  
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
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GoalProvider()),
        ChangeNotifierProxyProvider<GoalProvider, NotificationProvider>(
          create: (_) => NotificationProvider(),
          update: (_, goalProvider, notificationProvider) {
            notificationProvider!.attachToGoalProvider(goalProvider);
            return notificationProvider;
          },
        ),
      ],
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
      builder: (context, child) => AppShell(child: child ?? const SizedBox.shrink()),
      initialRoute: AppRoutes.resolveInitialRoute(),
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
