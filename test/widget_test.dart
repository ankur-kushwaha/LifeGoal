import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:lifegoal_app/main.dart';
import 'package:lifegoal_app/providers/goal_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App loads dashboard smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => GoalProvider(),
        child: const MyApp(),
      ),
    );

    // Let async loading finish and settle
    await tester.pumpAndSettle();

    // Verify that our app text "LifeGoal AI" is shown.
    expect(find.text('LifeGoal AI'), findsOneWidget);
  });
}
