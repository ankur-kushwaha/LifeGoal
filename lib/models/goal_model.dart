import 'dart:math';

class GoalModel {
  final String id;
  final String name;
  final String account;
  final double targetCost; // today's cost
  final DateTime startDate;
  final DateTime targetDate;
  final double currentSavings;
  final double? expectedReturn; // custom expected return for this goal (null = use global)
  final double? inflationRate;  // custom inflation rate for this goal (null = use global)

  GoalModel({
    required this.id,
    required this.name,
    required this.account,
    required this.targetCost,
    required this.startDate,
    required this.targetDate,
    required this.currentSavings,
    this.expectedReturn,
    this.inflationRate,
  });

  // Calculate total months between two dates (calendar months)
  static int monthsBetween(DateTime start, DateTime end) {
    return (end.year - start.year) * 12 + end.month - start.month;
  }

  // Calculate years between start and target date (for inflation)
  double getYearsFromStartToTarget() {
    final months = monthsBetween(startDate, targetDate);
    return months / 12.0;
  }

  // Calculate remaining months from Today to Target Date
  int getRemainingMonths(DateTime today) {
    if (targetDate.isBefore(today)) return 0;
    
    // We add +1 because payments are made monthly, including the current month (e.g. Jul to Dec is 6 months)
    final diff = monthsBetween(today, targetDate) + 1;
    return diff < 0 ? 0 : diff;
  }

  // Get Inflation Rate to use (goal-specific or global default)
  double getEffectiveInflationRate(double globalInflation) {
    return (inflationRate ?? globalInflation) / 100.0;
  }

  // Get Return Rate to use (goal-specific or global default)
  double getEffectiveReturnRate(double globalReturn) {
    return (expectedReturn ?? globalReturn) / 100.0;
  }

  // Calculate Inflation Adjusted Target Cost
  double getInflationAdjustedTarget(double globalInflation) {
    final rate = getEffectiveInflationRate(globalInflation);
    final years = getYearsFromStartToTarget();
    return targetCost * pow(1 + rate, years);
  }

  // Calculate Projected Value of Current Savings at Target Date
  double getProjectedSavings(DateTime today, double globalReturn) {
    final remainingMonths = getRemainingMonths(today);
    return getSavingsAfterMonths(today, globalReturn, remainingMonths);
  }

  // Project current savings with compound growth only (no further SIP).
  double getSavingsAfterMonths(DateTime today, double globalReturn, int monthsFromToday) {
    if (monthsFromToday <= 0) return currentSavings;
    final rate = getEffectiveReturnRate(globalReturn);
    return currentSavings * pow(1 + rate, monthsFromToday / 12.0);
  }

  static DateTime dateAfterMonths(DateTime from, int months) {
    return DateTime(from.year, from.month + months, from.day);
  }

  // Calculate Remaining Target Amount to be accumulated
  double getRemainingAmountNeeded(DateTime today, double globalInflation, double globalReturn) {
    final target = getInflationAdjustedTarget(globalInflation);
    final projected = getProjectedSavings(today, globalReturn);
    final needed = target - projected;
    return needed < 0 ? 0.0 : needed;
  }

  // Calculate Required Monthly SIP
  double getRequiredSIP(DateTime today, double globalInflation, double globalReturn) {
    final remainingMonths = getRemainingMonths(today);
    if (remainingMonths <= 0) return 0.0;

    final needed = getRemainingAmountNeeded(today, globalInflation, globalReturn);
    if (needed <= 0) return 0.0;

    final annualRate = getEffectiveReturnRate(globalReturn);
    final r = annualRate / 12.0; // monthly return rate

    if (r == 0) {
      return needed / remainingMonths;
    }

    // PMT formula: PMT = FV * r / ((1 + r)^n - 1)
    return needed * r / (pow(1 + r, remainingMonths) - 1);
  }

  // Get percentage completed (Grown Savings / Inflation Adjusted Target)
  double getPercentDone(DateTime today, double globalInflation, double globalReturn) {
    final target = getInflationAdjustedTarget(globalInflation);
    if (target <= 0) return 100.0;

    final projected = getProjectedSavings(today, globalReturn);
    final pct = (projected / target) * 100.0;
    return pct > 100.0 ? 100.0 : pct;
  }

  // Get Goal Health Status based on timeline and savings progress
  GoalHealth getHealth(DateTime today, double globalInflation, double globalReturn) {
    final needed = getRemainingAmountNeeded(today, globalInflation, globalReturn);
    if (needed <= 0) return GoalHealth.onTrack;

    final totalMonths = monthsBetween(startDate, targetDate);
    if (totalMonths <= 0) return GoalHealth.onTrack;

    // Months elapsed from start date to today
    final elapsedMonths = monthsBetween(startDate, today);
    if (elapsedMonths <= 0) return GoalHealth.onTrack; // Just started!

    final expectedProgress = elapsedMonths / totalMonths;
    final actualProgress = getPercentDone(today, globalInflation, globalReturn) / 100.0;

    if (actualProgress >= expectedProgress) {
      return GoalHealth.onTrack;
    } else if (actualProgress >= expectedProgress * 0.8) {
      return GoalHealth.needsAttention;
    } else {
      return GoalHealth.behindSchedule;
    }
  }

  // JSON Serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'account': account,
      'targetCost': targetCost,
      'startDate': startDate.toIso8601String(),
      'targetDate': targetDate.toIso8601String(),
      'currentSavings': currentSavings,
      if (expectedReturn != null) 'expectedReturn': expectedReturn,
      if (inflationRate != null) 'inflationRate': inflationRate,
    };
  }

  factory GoalModel.fromJson(Map<String, dynamic> json) {
    return GoalModel(
      id: json['id'] as String,
      name: json['name'] as String,
      account: json['account'] as String,
      targetCost: (json['targetCost'] as num).toDouble(),
      startDate: DateTime.parse(json['startDate'] as String),
      targetDate: DateTime.parse(json['targetDate'] as String),
      currentSavings: (json['currentSavings'] as num).toDouble(),
      expectedReturn: json['expectedReturn'] != null ? (json['expectedReturn'] as num).toDouble() : null,
      inflationRate: json['inflationRate'] != null ? (json['inflationRate'] as num).toDouble() : null,
    );
  }

  // CopyWith for editing
  GoalModel copyWith({
    String? id,
    String? name,
    String? account,
    double? targetCost,
    DateTime? startDate,
    DateTime? targetDate,
    double? currentSavings,
    double? expectedReturn,
    double? inflationRate,
  }) {
    return GoalModel(
      id: id ?? this.id,
      name: name ?? this.name,
      account: account ?? this.account,
      targetCost: targetCost ?? this.targetCost,
      startDate: startDate ?? this.startDate,
      targetDate: targetDate ?? this.targetDate,
      currentSavings: currentSavings ?? this.currentSavings,
      expectedReturn: expectedReturn ?? this.expectedReturn,
      inflationRate: inflationRate ?? this.inflationRate,
    );
  }
}

enum GoalHealth {
  onTrack,
  needsAttention,
  behindSchedule,
}
