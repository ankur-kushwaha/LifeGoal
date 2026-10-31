import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:lifegoal_app/models/goal_model.dart';
import 'package:lifegoal_app/providers/goal_provider.dart';
import 'package:lifegoal_app/screens/goal_detail_screen.dart';
import 'package:lifegoal_app/widgets/app_logo.dart';

void main() {
  testWidgets('App logo asset loads', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: AppLogo(size: 64)),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('GoalDetailScreen renders Investment Changes table and removes Scenario Simulator',
      (WidgetTester tester) async {
    final goal = GoalModel(
      id: 'test-goal',
      name: 'Dream Home',
      account: 'Ankur',
      targetCost: 1000000,
      startDate: DateTime(2024, 1, 1),
      targetDate: DateTime(2028, 1, 1),
      currentSavings: 500000,
      savingsHistory: [
        SavingsSnapshot(date: DateTime(2025, 1, 1), amount: 300000),
        SavingsSnapshot(date: DateTime(2026, 7, 1), amount: 500000),
      ],
    );

    final provider = GoalProvider.forTesting(
      goals: [goal],
      today: DateTime(2026, 7, 1),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<GoalProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: GoalDetailScreen(goalId: 'test-goal'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Scenario Simulator is completely removed
    expect(find.text('Scenario Simulator (AI Engine)'), findsNothing);
    expect(find.text('SIMULATED REQUIRED SIP'), findsNothing);
    expect(find.text('SIMULATED TARGET COST'), findsNothing);

    // Verify Investment Changes section is present
    expect(find.text('Investment Changes'), findsOneWidget);
    expect(find.text('Record Change'), findsOneWidget);

    // Verify table headers are visible
    expect(find.text('DATE'), findsOneWidget);
    expect(find.text('RECORDED BALANCE'), findsOneWidget);
    expect(find.text('INVESTMENT CHANGE'), findsOneWidget);
    expect(find.text('ACTIONS'), findsOneWidget);

    // Verify recorded balances and start baseline are rendered
    expect(find.text('01-Jan-2024'), findsOneWidget); // Start date
    expect(find.text('01-Jan-2025'), findsOneWidget); // Snapshot 1
    expect(find.text('01-Jul-2026'), findsOneWidget); // Snapshot 2 / Today
  });
}
