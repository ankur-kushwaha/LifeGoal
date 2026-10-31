import 'dart:math';

/// A recorded savings balance on a calendar date.
class SavingsSnapshot {
  final DateTime date;
  final double amount;

  const SavingsSnapshot({required this.date, required this.amount});

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'amount': amount,
      };

  factory SavingsSnapshot.fromJson(Map<String, dynamic> json) {
    return SavingsSnapshot(
      date: DateTime.parse(json['date'] as String),
      amount: (json['amount'] as num).toDouble(),
    );
  }
}

/// One point on the growth chart (actual recorded balance or future projection).
class GrowthChartPoint {
  final DateTime date;
  final double amount;
  final bool isProjected;

  const GrowthChartPoint({
    required this.date,
    required this.amount,
    required this.isProjected,
  });
}

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
  /// True when the user entered the future target amount directly
  /// (vs today's cost, which we inflate to a future target).
  final bool knowsTargetAmount;
  /// Dated savings balances. Latest entry should match [currentSavings].
  final List<SavingsSnapshot> savingsHistory;

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
    this.knowsTargetAmount = false,
    List<SavingsSnapshot>? savingsHistory,
  }) : savingsHistory = List.unmodifiable(savingsHistory ?? const []);

  static DateTime calendarDay(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool isSameCalendarDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Updates [currentSavings] and upserts a snapshot for [onDate]'s calendar day.
  ///
  /// When [retainBalanceOn] is before [onDate] and that day has no snapshot yet,
  /// the previous [currentSavings] is stored there first. This keeps the chart's
  /// prior starting balance when planning "today" advances (instead of relocating
  /// the single recorded point).
  GoalModel recordSavings(
    double amount,
    DateTime onDate, {
    DateTime? retainBalanceOn,
  }) {
    final day = calendarDay(onDate);
    final updated = List<SavingsSnapshot>.from(savingsHistory);

    if (retainBalanceOn != null) {
      final retainDay = calendarDay(retainBalanceOn);
      if (day.isAfter(retainDay) &&
          !updated.any((s) => isSameCalendarDay(s.date, retainDay))) {
        updated.add(SavingsSnapshot(date: retainDay, amount: currentSavings));
      }
    }

    final idx = updated.indexWhere((s) => isSameCalendarDay(s.date, day));
    final snap = SavingsSnapshot(date: day, amount: amount);
    if (idx >= 0) {
      updated[idx] = snap;
    } else {
      updated.add(snap);
    }
    updated.sort((a, b) => a.date.compareTo(b.date));
    return copyWith(currentSavings: amount, savingsHistory: updated);
  }

  /// Historical balances plus month-by-month growth to the target date (no new SIP).
  ///
  /// The series always begins at [startDate] with amount 0 (goal creation), then
  /// recorded balances, then projected growth with no new SIP.
  List<GrowthChartPoint> getGrowthChartSeries(DateTime today, double globalReturn) {
    final todayDay = calendarDay(today);
    final startDay = calendarDay(startDate);
    final points = <GrowthChartPoint>[
      GrowthChartPoint(date: startDay, amount: 0, isProjected: false),
    ];

    final history = List<SavingsSnapshot>.from(savingsHistory)
      ..sort((a, b) => a.date.compareTo(b.date));

    for (final snap in history) {
      final day = calendarDay(snap.date);
      // Origin is always zero at creation; skip any snapshot on/before start day.
      if (!day.isAfter(startDay)) continue;
      points.add(GrowthChartPoint(date: day, amount: snap.amount, isProjected: false));
    }

    // Ensure the latest planning "today" is represented with the live balance.
    // Creation day stays at zero even when today equals startDate.
    if (!isSameCalendarDay(todayDay, startDay)) {
      final hasToday = points.any((p) => isSameCalendarDay(p.date, todayDay));
      if (hasToday) {
        final idx = points.indexWhere((p) => isSameCalendarDay(p.date, todayDay));
        points[idx] = GrowthChartPoint(
          date: todayDay,
          amount: currentSavings,
          isProjected: false,
        );
      } else {
        points.add(GrowthChartPoint(
          date: todayDay,
          amount: currentSavings,
          isProjected: false,
        ));
      }
    }

    // Keep actual points chronological; drop duplicate dates preferring the last write,
    // but never replace the creation-day zero origin.
    points.sort((a, b) => a.date.compareTo(b.date));
    final deduped = <GrowthChartPoint>[];
    for (final p in points) {
      if (deduped.isNotEmpty && isSameCalendarDay(deduped.last.date, p.date)) {
        if (isSameCalendarDay(p.date, startDay)) {
          deduped[deduped.length - 1] = GrowthChartPoint(
            date: startDay,
            amount: 0,
            isProjected: false,
          );
        } else {
          deduped[deduped.length - 1] = p;
        }
      } else {
        deduped.add(p);
      }
    }
    points
      ..clear()
      ..addAll(deduped);

    final remainingMonths = getRemainingMonths(today);
    for (var m = 1; m <= remainingMonths; m++) {
      final date = calendarDay(dateAfterMonths(todayDay, m));
      final amount = getSavingsAfterMonths(today, globalReturn, m);
      points.add(GrowthChartPoint(date: date, amount: amount, isProjected: true));
    }

    return points;
  }

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
    return getRequiredSIPAfterMonths(
      today,
      globalInflation,
      globalReturn,
      0,
    );
  }

  /// One-time amount to invest today so current savings + this lump sum
  /// grow to the inflation-adjusted target by the target date (no further SIP).
  double getRequiredLumpSumToday(DateTime today, double globalInflation, double globalReturn) {
    final target = getInflationAdjustedTarget(globalInflation);
    final remainingMonths = getRemainingMonths(today);
    if (remainingMonths <= 0) {
      final gap = target - currentSavings;
      return gap < 0 ? 0.0 : gap;
    }

    final annualRate = getEffectiveReturnRate(globalReturn);
    final presentValueOfTarget = target / pow(1 + annualRate, remainingMonths / 12.0);
    final lumpSum = presentValueOfTarget - currentSavings;
    return lumpSum < 0 ? 0.0 : lumpSum;
  }

  // Required monthly SIP if you wait N months (growth only), then start SIP for the rest.
  double getRequiredSIPAfterMonths(
    DateTime today,
    double globalInflation,
    double globalReturn,
    int monthsFromToday,
  ) {
    final totalRemainingMonths = getRemainingMonths(today);
    final monthsLeft = totalRemainingMonths - monthsFromToday;
    if (monthsLeft <= 0) return 0.0;

    final annualRate = getEffectiveReturnRate(globalReturn);
    final savingsAtOffset = monthsFromToday <= 0
        ? currentSavings
        : getSavingsAfterMonths(today, globalReturn, monthsFromToday);
    final projectedWithoutSip =
        savingsAtOffset * pow(1 + annualRate, monthsLeft / 12.0);

    final target = getInflationAdjustedTarget(globalInflation);
    final needed = target - projectedWithoutSip;
    if (needed <= 0) return 0.0;

    final r = annualRate / 12.0;
    if (r == 0) {
      return needed / monthsLeft;
    }

    return needed * r / (pow(1 + r, monthsLeft) - 1);
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
      // Always write so merge:true clears a previous per-goal override.
      'inflationRate': inflationRate,
      'knowsTargetAmount': knowsTargetAmount,
      'savingsHistory': savingsHistory.map((s) => s.toJson()).toList(),
    };
  }

  factory GoalModel.fromJson(Map<String, dynamic> json) {
    final historyRaw = json['savingsHistory'];
    final history = historyRaw is List
        ? historyRaw
            .whereType<Map>()
            .map((e) => SavingsSnapshot.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <SavingsSnapshot>[];

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
      knowsTargetAmount: json['knowsTargetAmount'] as bool? ?? false,
      savingsHistory: history,
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
    bool? knowsTargetAmount,
    List<SavingsSnapshot>? savingsHistory,
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
      knowsTargetAmount: knowsTargetAmount ?? this.knowsTargetAmount,
      savingsHistory: savingsHistory ?? this.savingsHistory,
    );
  }
}

enum GoalHealth {
  onTrack,
  needsAttention,
  behindSchedule,
}
