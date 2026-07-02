import '../models/goal_model.dart';

/// Goals from the LifeGoal planning spreadsheet (reference date: 1 Jul 2026).
class SpreadsheetGoals {
  SpreadsheetGoals._();

  static const double globalReturn = 14.0;

  static final List<GoalModel> all = [
    GoalModel(
      id: 'spreadsheet-home-loan',
      name: 'Home loan',
      account: 'Ankur',
      targetCost: 700000,
      startDate: DateTime(2023, 10, 4),
      targetDate: DateTime(2027, 3, 30),
      currentSavings: 780795,
      expectedReturn: globalReturn,
    ),
    GoalModel(
      id: 'spreadsheet-bali',
      name: 'Bali',
      account: 'Ankur',
      targetCost: 300000,
      startDate: DateTime(2024, 10, 4),
      targetDate: DateTime(2026, 12, 12),
      currentSavings: 108452,
      expectedReturn: globalReturn,
    ),
    GoalModel(
      id: 'spreadsheet-shree-shadi',
      name: 'Shree ki shadi',
      account: 'Ankur',
      targetCost: 2000000,
      startDate: DateTime(2024, 10, 4),
      targetDate: DateTime(2050, 6, 3),
      currentSavings: 418674,
      expectedReturn: globalReturn,
    ),
    GoalModel(
      id: 'spreadsheet-shree-education',
      name: 'Shree ki education',
      account: 'Ankur',
      targetCost: 2000000,
      startDate: DateTime(2024, 10, 4),
      targetDate: DateTime(2042, 6, 4),
      currentSavings: 343087,
      expectedReturn: globalReturn,
    ),
    GoalModel(
      id: 'spreadsheet-dream-home',
      name: 'DreamHome',
      account: 'Neha',
      targetCost: 3000000,
      startDate: DateTime(2024, 10, 4),
      targetDate: DateTime(2028, 8, 13),
      currentSavings: 1343000,
      expectedReturn: globalReturn,
    ),
    GoalModel(
      id: 'spreadsheet-miscellaneous',
      name: 'Miscellaneous',
      account: 'Neha',
      targetCost: 100000,
      startDate: DateTime(2024, 10, 4),
      targetDate: DateTime(2026, 12, 14),
      currentSavings: 29920,
      expectedReturn: globalReturn,
    ),
    GoalModel(
      id: 'spreadsheet-emergency',
      name: 'Emergency',
      account: 'Neha',
      targetCost: 300000,
      startDate: DateTime(2024, 10, 4),
      targetDate: DateTime(2026, 12, 14),
      currentSavings: 367000,
      expectedReturn: globalReturn,
    ),
  ];
}
