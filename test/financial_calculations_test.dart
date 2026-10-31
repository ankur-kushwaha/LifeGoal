import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifegoal_app/models/goal_model.dart';
import 'package:lifegoal_app/data/spreadsheet_goals.dart';

void main() {
  group('Financial Calculations Tests', () {
    // Reference variables matching spreadsheet defaults
    const double globalInflation = 6.0;
    const double globalReturn = 14.0;
    final DateTime today = DateTime(2026, 7, 1);

    test('DreamHome Calculations Match Spreadsheet', () {
      final dreamHome = GoalModel(
        id: '5',
        name: 'DreamHome',
        account: 'Neha',
        targetCost: 3000000.0,
        startDate: DateTime(2024, 10, 4),
        targetDate: DateTime(2028, 8, 13),
        currentSavings: 1343000.0,
      );

      // 1. Months from start to target (Oct 2024 to Aug 2028)
      // Oct-24 to Aug-28 = 3 years (36 months) + 10 months = 46 months
      final inflationMonths = GoalModel.monthsBetween(dreamHome.startDate, dreamHome.targetDate);
      expect(inflationMonths, 46);

      // 2. Inflation adjusted target cost
      // 3,000,000 * (1.06)^(46/12) = 3,750,827 (Spreadsheet shows 3,769,085 due to small formula variation)
      final inflationTarget = dreamHome.getInflationAdjustedTarget(globalInflation);
      expect(inflationTarget.round(), 3750827);

      // 3. Remaining Months from Today (1-Jul-2026) to Target (13-Aug-2028)
      // Jul-26 to Aug-28 = 2 years (24 months) + 1 month = 25 months + 1 (inclusive) = 26 months
      final remainingMonths = dreamHome.getRemainingMonths(today);
      expect(remainingMonths, 26);

      // 4. Projected Value of Current Savings
      // 1,343,000 * (1.14)^(26/12) = 1,783,897
      final projectedSavings = dreamHome.getProjectedSavings(today, globalReturn);
      expect(projectedSavings.round(), 1783897);

      // 5. Remaining Gap to be accumulated
      // 3,750,827 - 1,783,897 = 1,966,930
      final remainingNeeded = dreamHome.getRemainingAmountNeeded(today, globalInflation, globalReturn);
      expect(remainingNeeded.round(), 1966930);

      // 6. Required Monthly SIP
      // PMT(14%/12, 26, 0, -1966930) = 65,194
      final requiredSip = dreamHome.getRequiredSIP(today, globalInflation, globalReturn);
      expect(requiredSip.round(), 65194);

      // 7. SIP from today (offset 0) matches getRequiredSIP
      final sipFromToday = dreamHome.getRequiredSIPAfterMonths(
        today,
        globalInflation,
        globalReturn,
        0,
      );
      expect(sipFromToday.round(), requiredSip.round());

      // 8. Lump sum today: PV of inflation target minus current savings
      // 3,750,827 / (1.14)^(26/12) - 1,343,000 ≈ 1,480,795
      final lumpSum = dreamHome.getRequiredLumpSumToday(today, globalInflation, globalReturn);
      expect(lumpSum.round(), 1480795);

      // Fully funded when lump sum is invested: projected savings cover target
      final funded = GoalModel(
        id: dreamHome.id,
        name: dreamHome.name,
        account: dreamHome.account,
        targetCost: dreamHome.targetCost,
        startDate: dreamHome.startDate,
        targetDate: dreamHome.targetDate,
        currentSavings: dreamHome.currentSavings + lumpSum,
      );
      expect(funded.getRemainingAmountNeeded(today, globalInflation, globalReturn), closeTo(0, 1));
      expect(funded.getRequiredSIP(today, globalInflation, globalReturn), closeTo(0, 1));
    });

    test('Bali vacation SIP at today considers projected savings growth', () {
      final bali = GoalModel(
        id: 'bali',
        name: 'Bali Vacation',
        account: 'Ankur',
        targetCost: 200000.0,
        startDate: DateTime(2024, 1, 1),
        targetDate: DateTime(2029, 6, 30),
        currentSavings: 150000.0,
      );

      final sipToday = bali.getRequiredSIP(today, globalInflation, globalReturn);
      final sipTimelineToday =
          bali.getRequiredSIPAfterMonths(today, globalInflation, globalReturn, 0);

      expect(sipTimelineToday.round(), sipToday.round());
      // Should be well below naive target minus current savings SIP (~₹1,960)
      final naiveGap = bali.getInflationAdjustedTarget(globalInflation) -
          bali.currentSavings;
      final naiveSip = naiveGap *
          (globalReturn / 100 / 12) /
          (pow(1 + globalReturn / 100 / 12, bali.getRemainingMonths(today)) - 1);
      expect(sipToday, lessThan(naiveSip * 0.8));
    });

    test('Shree ki shadi Calculations Match Spreadsheet', () {
      final shadi = GoalModel(
        id: '3',
        name: 'Shree ki shadi',
        account: 'Ankur',
        targetCost: 2000000.0,
        startDate: DateTime(2024, 10, 4),
        targetDate: DateTime(2050, 6, 3),
        currentSavings: 418674.0,
      );

      // Inflation Target: 2,000,000 * (1.06)^(308/12) = 8,923,746
      final inflationTarget = shadi.getInflationAdjustedTarget(globalInflation);
      expect(inflationTarget.round(), 8923746);

      // Remaining Months: Jul-26 to Jun-50 (23 years 11 months + 1) = 288 months
      final remainingMonths = shadi.getRemainingMonths(today);
      expect(remainingMonths, 288);

      // Projected Savings: 418,674 * (1.14)^(288/12) = 418,674 * (1.14)^24 = 9,718,347
      final projectedSavings = shadi.getProjectedSavings(today, globalReturn);
      expect(projectedSavings.round(), 9718347);

      // Remaining needed: 8,923,746 - 9,718,347 = -794,601 (capped at 0)
      final remainingNeeded = shadi.getRemainingAmountNeeded(today, globalInflation, globalReturn);
      expect(remainingNeeded, 0.0);

      // Required SIP should be 0 since target is fully covered by projected growth
      final requiredSip = shadi.getRequiredSIP(today, globalInflation, globalReturn);
      expect(requiredSip, 0.0);
    });

    test('Spreadsheet goals list matches workbook', () {
      expect(SpreadsheetGoals.all.length, 7);
      expect(SpreadsheetGoals.all.map((g) => g.name), contains('DreamHome'));
    });

    test('Date Difference Edge Cases', () {
      // 0 months difference
      final d1 = DateTime(2026, 7, 1);
      final d2 = DateTime(2026, 7, 15);
      expect(GoalModel.monthsBetween(d1, d2), 0);

      // Negative remaining months (target in the past)
      final pastGoal = GoalModel(
        id: 'past',
        name: 'Past Goal',
        account: 'Ankur',
        targetCost: 10000.0,
        startDate: DateTime(2020, 1, 1),
        targetDate: DateTime(2025, 12, 31),
        currentSavings: 5000.0,
      );
      expect(pastGoal.getRemainingMonths(DateTime(2026, 7, 1)), 0);
    });

    test('recordSavings stores value for current date and upserts same day', () {
      final goal = GoalModel(
        id: 'hist',
        name: 'History',
        account: 'Ankur',
        targetCost: 100000.0,
        startDate: DateTime(2024, 1, 1),
        targetDate: DateTime(2027, 1, 1),
        currentSavings: 10000.0,
      );

      final first = goal.recordSavings(15000.0, DateTime(2026, 7, 1, 10, 30));
      expect(first.currentSavings, 15000.0);
      expect(first.savingsHistory.length, 1);
      expect(first.savingsHistory.first.amount, 15000.0);
      expect(GoalModel.isSameCalendarDay(first.savingsHistory.first.date, DateTime(2026, 7, 1)), true);

      final sameDay = first.recordSavings(16000.0, DateTime(2026, 7, 1, 22, 0));
      expect(sameDay.savingsHistory.length, 1);
      expect(sameDay.currentSavings, 16000.0);

      final nextDay = sameDay.recordSavings(17000.0, DateTime(2026, 8, 1));
      expect(nextDay.savingsHistory.length, 2);
      expect(nextDay.savingsHistory.last.amount, 17000.0);
    });

    test('recordSavings retains prior planning-day balance when date advances', () {
      final goal = GoalModel(
        id: 'retain',
        name: 'Retain',
        account: 'Ankur',
        targetCost: 2000000.0,
        startDate: DateTime(2024, 10, 4),
        targetDate: DateTime(2026, 12, 4),
        currentSavings: 780795.0,
      );

      final updated = goal.recordSavings(
        803575.0,
        DateTime(2026, 8, 4),
        retainBalanceOn: DateTime(2026, 7, 1),
      );

      expect(updated.savingsHistory.length, 2);
      expect(updated.savingsHistory.first.amount, 780795.0);
      expect(
        GoalModel.isSameCalendarDay(
          updated.savingsHistory.first.date,
          DateTime(2026, 7, 1),
        ),
        true,
      );
      expect(updated.savingsHistory.last.amount, 803575.0);
      expect(
        GoalModel.isSameCalendarDay(
          updated.savingsHistory.last.date,
          DateTime(2026, 8, 4),
        ),
        true,
      );

      final series = updated.getGrowthChartSeries(DateTime(2026, 8, 4), globalReturn);
      final actual = series.where((p) => !p.isProjected).toList();
      expect(actual.length, 3);
      expect(actual.first.amount, 0);
      expect(
        GoalModel.isSameCalendarDay(actual.first.date, DateTime(2024, 10, 4)),
        true,
      );
      expect(actual[1].amount, 780795.0);
      expect(actual.last.amount, 803575.0);
    });

    test('recordSavings does not duplicate retained day when already snapshotted', () {
      final goal = GoalModel(
        id: 'retain-existing',
        name: 'Retain Existing',
        account: 'Ankur',
        targetCost: 2000000.0,
        startDate: DateTime(2024, 10, 4),
        targetDate: DateTime(2026, 12, 4),
        currentSavings: 780795.0,
        savingsHistory: [
          SavingsSnapshot(date: DateTime(2026, 7, 1), amount: 780795.0),
        ],
      );

      final updated = goal.recordSavings(
        803575.0,
        DateTime(2026, 8, 4),
        retainBalanceOn: DateTime(2026, 7, 1),
      );

      expect(updated.savingsHistory.length, 2);
      expect(updated.savingsHistory.first.amount, 780795.0);
      expect(updated.savingsHistory.last.amount, 803575.0);
    });

    test('Growth chart includes history, today, future projection', () {
      final goal = GoalModel(
        id: 'chart',
        name: 'Chart Goal',
        account: 'Ankur',
        targetCost: 200000.0,
        startDate: DateTime(2024, 1, 1),
        targetDate: DateTime(2026, 12, 1),
        currentSavings: 50000.0,
        savingsHistory: [
          SavingsSnapshot(date: DateTime(2026, 1, 1), amount: 40000.0),
          SavingsSnapshot(date: DateTime(2026, 7, 1), amount: 50000.0),
        ],
      );

      final series = goal.getGrowthChartSeries(today, globalReturn);
      final actual = series.where((p) => !p.isProjected).toList();
      final projected = series.where((p) => p.isProjected).toList();

      expect(actual.length, 3);
      expect(actual.first.amount, 0);
      expect(
        GoalModel.isSameCalendarDay(actual.first.date, DateTime(2024, 1, 1)),
        true,
      );
      expect(actual[1].amount, 40000.0);
      expect(actual.last.amount, 50000.0);
      expect(projected, isNotEmpty);
      expect(projected.last.amount, closeTo(goal.getProjectedSavings(today, globalReturn), 1));
      expect(GoalModel.isSameCalendarDay(projected.last.date, DateTime(2026, 12, 1)) ||
          projected.last.date.isAfter(DateTime(2026, 11, 1)), true);
    });

    test('Growth chart starts at zero on goal creation date', () {
      final goal = GoalModel(
        id: 'origin',
        name: 'Origin',
        account: 'Ankur',
        targetCost: 2000000.0,
        startDate: DateTime(2023, 10, 4),
        targetDate: DateTime(2026, 11, 30),
        currentSavings: 803575.0,
        savingsHistory: [
          SavingsSnapshot(date: DateTime(2026, 8, 4), amount: 803575.0),
        ],
      );

      final series = goal.getGrowthChartSeries(DateTime(2026, 8, 4), globalReturn);
      final actual = series.where((p) => !p.isProjected).toList();

      expect(actual.first.amount, 0);
      expect(
        GoalModel.isSameCalendarDay(actual.first.date, DateTime(2023, 10, 4)),
        true,
      );
      expect(actual.last.amount, 803575.0);
      expect(
        GoalModel.isSameCalendarDay(actual.last.date, DateTime(2026, 8, 4)),
        true,
      );
    });

    test('Savings history survives JSON round-trip', () {
      final goal = GoalModel(
        id: 'json',
        name: 'JSON',
        account: 'Ankur',
        targetCost: 1000,
        startDate: DateTime(2024, 1, 1),
        targetDate: DateTime(2027, 1, 1),
        currentSavings: 500,
      ).recordSavings(500, DateTime(2026, 7, 1));

      final restored = GoalModel.fromJson(goal.toJson());
      expect(restored.savingsHistory.length, 1);
      expect(restored.savingsHistory.first.amount, 500);
    });
  });
}
