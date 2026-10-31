import '../models/goal_model.dart';

/// Goals from the LifeGoal planning spreadsheet (reference date: 1 Jul 2026).
class SpreadsheetGoals {
  SpreadsheetGoals._();

  static const double globalReturn = 14.0;
  static final DateTime referenceDate = DateTime(2026, 7, 1);

  static GoalModel _goal({
    required String id,
    required String name,
    required String account,
    required double targetCost,
    required DateTime startDate,
    required DateTime targetDate,
    required double currentSavings,
  }) {
    return GoalModel(
      id: id,
      name: name,
      account: account,
      targetCost: targetCost,
      startDate: startDate,
      targetDate: targetDate,
      currentSavings: currentSavings,
      expectedReturn: globalReturn,
      savingsHistory: [
        SavingsSnapshot(date: referenceDate, amount: currentSavings),
      ],
    );
  }

  static final List<GoalModel> all = [
    _goal(
      id: 'spreadsheet-home-loan',
      name: 'Home loan',
      account: 'Ankur',
      targetCost: 700000,
      startDate: DateTime(2023, 10, 4),
      targetDate: DateTime(2027, 3, 30),
      currentSavings: 780795,
    ),
    _goal(
      id: 'spreadsheet-bali',
      name: 'Bali',
      account: 'Ankur',
      targetCost: 300000,
      startDate: DateTime(2024, 10, 4),
      targetDate: DateTime(2026, 12, 12),
      currentSavings: 108452,
    ),
    _goal(
      id: 'spreadsheet-shree-shadi',
      name: 'Shree ki shadi',
      account: 'Ankur',
      targetCost: 2000000,
      startDate: DateTime(2024, 10, 4),
      targetDate: DateTime(2050, 6, 3),
      currentSavings: 418674,
    ),
    _goal(
      id: 'spreadsheet-shree-education',
      name: 'Shree ki education',
      account: 'Ankur',
      targetCost: 2000000,
      startDate: DateTime(2024, 10, 4),
      targetDate: DateTime(2042, 6, 4),
      currentSavings: 343087,
    ),
    _goal(
      id: 'spreadsheet-dream-home',
      name: 'DreamHome',
      account: 'Neha',
      targetCost: 3000000,
      startDate: DateTime(2024, 10, 4),
      targetDate: DateTime(2028, 8, 13),
      currentSavings: 1343000,
    ),
    _goal(
      id: 'spreadsheet-miscellaneous',
      name: 'Miscellaneous',
      account: 'Neha',
      targetCost: 100000,
      startDate: DateTime(2024, 10, 4),
      targetDate: DateTime(2026, 12, 14),
      currentSavings: 29920,
    ),
    _goal(
      id: 'spreadsheet-emergency',
      name: 'Emergency',
      account: 'Neha',
      targetCost: 300000,
      startDate: DateTime(2024, 10, 4),
      targetDate: DateTime(2026, 12, 14),
      currentSavings: 367000,
    ),
  ];
}
