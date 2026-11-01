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

/// Timeframe selector for the growth chart.
enum GoalTimeframe {
  oneMonth,
  threeMonths,
  sixMonths,
  oneYear,
  all,
}

extension GoalTimeframeExtension on GoalTimeframe {
  String get label {
    switch (this) {
      case GoalTimeframe.oneMonth:
        return '1M';
      case GoalTimeframe.threeMonths:
        return '3M';
      case GoalTimeframe.sixMonths:
        return '6M';
      case GoalTimeframe.oneYear:
        return '1Y';
      case GoalTimeframe.all:
        return 'ALL';
    }
  }

  int? get months {
    switch (this) {
      case GoalTimeframe.oneMonth:
        return 1;
      case GoalTimeframe.threeMonths:
        return 3;
      case GoalTimeframe.sixMonths:
        return 6;
      case GoalTimeframe.oneYear:
        return 12;
      case GoalTimeframe.all:
        return null;
    }
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

  /// Deletes a recorded savings snapshot on [onDate].
  ///
  /// Updates [currentSavings] to the latest remaining snapshot amount, or 0.0 if empty.
  GoalModel deleteSavingsSnapshot(DateTime onDate) {
    final day = calendarDay(onDate);
    final updated = savingsHistory.where((s) => !isSameCalendarDay(s.date, day)).toList();
    updated.sort((a, b) => a.date.compareTo(b.date));
    final newCurrent = updated.isNotEmpty ? updated.last.amount : 0.0;
    return copyWith(currentSavings: newCurrent, savingsHistory: updated);
  }

  /// Edits an existing snapshot or updates its date and amount.
  GoalModel editSavingsSnapshot({
    required DateTime oldDate,
    required DateTime newDate,
    required double newAmount,
  }) {
    final oldDay = calendarDay(oldDate);
    final newDay = calendarDay(newDate);
    final updated = savingsHistory.where((s) => !isSameCalendarDay(s.date, oldDay)).toList();
    final existingIdx = updated.indexWhere((s) => isSameCalendarDay(s.date, newDay));
    final newSnap = SavingsSnapshot(date: newDay, amount: newAmount);
    if (existingIdx >= 0) {
      updated[existingIdx] = newSnap;
    } else {
      updated.add(newSnap);
    }
    updated.sort((a, b) => a.date.compareTo(b.date));
    final newCurrent = updated.isNotEmpty ? updated.last.amount : newAmount;
    return copyWith(currentSavings: newCurrent, savingsHistory: updated);
  }

  /// Historical balances plus month-by-month growth to the target date (no new SIP).
  ///
  /// When [timeframe] is [GoalTimeframe.all], the series begins at [startDate] with
  /// amount 0 (goal creation), then recorded balances, then projected growth to target date.
  /// When [timeframe] is a specific period (1M, 3M, 6M, 1Y), it returns recorded history
  /// within that past period up to [today].
  List<GrowthChartPoint> getGrowthChartSeries(
    DateTime today,
    double globalReturn, {
    GoalTimeframe timeframe = GoalTimeframe.all,
  }) {
    final todayDay = calendarDay(today);
    final startDay = calendarDay(startDate);
    final history = List<SavingsSnapshot>.from(savingsHistory)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Determine initial amount on startDay: if there is a snapshot on or before startDay,
    // use it; otherwise if today equals startDay, use currentSavings; otherwise 0.
    double initialAmount = 0.0;
    for (final snap in history) {
      if (!calendarDay(snap.date).isAfter(startDay)) {
        initialAmount = snap.amount;
      }
    }
    if (initialAmount == 0.0 && isSameCalendarDay(todayDay, startDay)) {
      initialAmount = currentSavings;
    }

    final points = <GrowthChartPoint>[
      GrowthChartPoint(date: startDay, amount: initialAmount, isProjected: false),
    ];

    for (final snap in history) {
      final day = calendarDay(snap.date);
      // Origin is captured by initialAmount; skip any snapshot on/before start day.
      if (!day.isAfter(startDay)) continue;
      points.add(GrowthChartPoint(date: day, amount: snap.amount, isProjected: false));
    }

    // Ensure the latest planning "today" is represented with the live balance.
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

    // Keep actual points chronological; drop duplicate dates preferring the last write.
    points.sort((a, b) => a.date.compareTo(b.date));
    final deduped = <GrowthChartPoint>[];
    for (final p in points) {
      if (deduped.isNotEmpty && isSameCalendarDay(deduped.last.date, p.date)) {
        if (isSameCalendarDay(p.date, startDay)) {
          deduped[deduped.length - 1] = GrowthChartPoint(
            date: startDay,
            amount: initialAmount,
            isProjected: false,
          );
        } else {
          deduped[deduped.length - 1] = p;
        }
      } else {
        deduped.add(p);
      }
    }

    if (timeframe == GoalTimeframe.all) {
      final allPoints = List<GrowthChartPoint>.from(deduped);
      final remainingMonths = getRemainingMonths(today);
      for (var m = 1; m <= remainingMonths; m++) {
        final date = calendarDay(dateAfterMonths(todayDay, m));
        final amount = getSavingsAfterMonths(today, globalReturn, m);
        allPoints.add(GrowthChartPoint(date: date, amount: amount, isProjected: true));
      }
      return allPoints;
    }

    final months = timeframe.months!;
    final rawCutoff = calendarDay(subtractMonths(todayDay, months));
    final cutoffDate = rawCutoff.isBefore(startDay) ? startDay : rawCutoff;

    if (deduped.isEmpty) return [];

    if (isSameCalendarDay(cutoffDate, todayDay)) {
      return deduped;
    }

    if (!cutoffDate.isAfter(deduped.first.date)) {
      return deduped;
    }

    GrowthChartPoint prev = deduped.first;
    GrowthChartPoint next = deduped.last;
    for (final p in deduped) {
      if (!p.date.isAfter(cutoffDate)) {
        prev = p;
      }
      if (p.date.isAfter(cutoffDate)) {
        next = p;
        break;
      }
    }

    final double cutoffAmount;
    if (isSameCalendarDay(prev.date, cutoffDate)) {
      cutoffAmount = prev.amount;
    } else {
      final totalDays = next.date.difference(prev.date).inDays;
      final elapsed = cutoffDate.difference(prev.date).inDays;
      final fraction = totalDays > 0 ? (elapsed / totalDays) : 0.0;
      cutoffAmount = prev.amount + (next.amount - prev.amount) * fraction;
    }

    final filtered = <GrowthChartPoint>[
      GrowthChartPoint(date: cutoffDate, amount: cutoffAmount, isProjected: false),
      ...deduped.where((p) => p.date.isAfter(cutoffDate)),
    ];

    if (filtered.length == 1) {
      filtered.insert(0, GrowthChartPoint(date: cutoffDate, amount: filtered.first.amount, isProjected: false));
    }

    return filtered;
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

  static DateTime subtractMonths(DateTime from, int months) {
    var year = from.year;
    var month = from.month - months;
    while (month <= 0) {
      month += 12;
      year -= 1;
    }
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final day = min(from.day, daysInMonth);
    return DateTime(year, month, day);
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

  /// Returns the scheduled accumulated savings benchmark by [today],
  /// assuming disciplined monthly SIP investment from [startDate] to [targetDate].
  double getScheduledAccumulatedSavings(
    DateTime today,
    double globalInflation,
    double globalReturn,
  ) {
    final totalMonths = monthsBetween(startDate, targetDate);
    if (totalMonths <= 0) return 0.0;

    final elapsedMonths = monthsBetween(startDate, today);
    if (elapsedMonths <= 0) return 0.0;

    final target = getInflationAdjustedTarget(globalInflation);
    if (target <= 0) return 0.0;

    final annualRate = getEffectiveReturnRate(globalReturn);
    final r = annualRate / 12.0;

    // Initial savings at start date (if any recorded on or before startDate)
    final startDay = calendarDay(startDate);
    double initialAmount = 0.0;
    for (final snap in savingsHistory) {
      if (!calendarDay(snap.date).isAfter(startDay)) {
        initialAmount = snap.amount;
      }
    }

    // Future value of initial savings at target date
    final initialAtTarget = r > 0
        ? initialAmount * pow(1 + r, totalMonths)
        : initialAmount;

    final gapAtStart = target - initialAtTarget;

    // If already fully funded by initial savings alone:
    if (gapAtStart <= 0) {
      final monthsToCompound = min(elapsedMonths, totalMonths);
      return r > 0
          ? initialAmount * pow(1 + r, monthsToCompound)
          : initialAmount;
    }

    // Disciplined monthly SIP needed from start date
    final scheduledSIP = r > 0
        ? (gapAtStart * r) / (pow(1 + r, totalMonths) - 1)
        : (gapAtStart / totalMonths);

    final monthsElapsedClamped = min(elapsedMonths, totalMonths);

    // Accumulated expected savings up to today:
    final initialAccumulated = r > 0
        ? initialAmount * pow(1 + r, monthsElapsedClamped)
        : initialAmount;

    final sipAccumulated = r > 0
        ? scheduledSIP * (pow(1 + r, monthsElapsedClamped) - 1) / r
        : scheduledSIP * monthsElapsedClamped;

    return initialAccumulated + sipAccumulated;
  }

  /// Returns the investment discipline ratio (current savings / scheduled accumulated savings).
  /// A ratio >= 1.0 means the investor has met or exceeded the disciplined savings plan.
  double getInvestmentDisciplineRatio(
    DateTime today,
    double globalInflation,
    double globalReturn,
  ) {
    final scheduled = getScheduledAccumulatedSavings(today, globalInflation, globalReturn);
    if (scheduled <= 0) {
      return currentSavings >= 0 ? 1.0 : 0.0;
    }
    return currentSavings / scheduled;
  }

  /// Returns the change in savings balance between the most recent recorded snapshot
  /// and the previous recorded snapshot in [savingsHistory].
  /// Returns null if fewer than 2 snapshots exist.
  double? getLastInvestmentDiff(DateTime today, double globalReturn) {
    if (savingsHistory.length < 2) return null;
    final sorted = List<SavingsSnapshot>.from(savingsHistory)
      ..sort((a, b) => a.date.compareTo(b.date));
    return sorted.last.amount - sorted[sorted.length - 2].amount;
  }

  /// Returns true if the most recent recorded investment addition is approximately equal
  /// to the required monthly SIP amount (e.g. within ±25% tolerance).
  bool isLastInvestmentApproxSIP(
    DateTime today,
    double globalInflation,
    double globalReturn, {
    double tolerance = 0.25,
  }) {
    final reqSip = getRequiredSIP(today, globalInflation, globalReturn);
    if (reqSip <= 0) return true;

    final diff = getLastInvestmentDiff(today, globalReturn);
    if (diff == null || diff <= 0) return false;

    final minSip = reqSip * (1.0 - tolerance);
    final maxSip = reqSip * (1.0 + tolerance + 0.10);
    return diff >= minSip && diff <= maxSip;
  }

  // Get Goal Health Status based on investment discipline
  GoalHealth getHealth(DateTime today, double globalInflation, double globalReturn) {
    final needed = getRemainingAmountNeeded(today, globalInflation, globalReturn);
    if (needed <= 0) return GoalHealth.onTrack;

    final totalMonths = monthsBetween(startDate, targetDate);
    if (totalMonths <= 0) return GoalHealth.onTrack;

    // Months elapsed from start date to today
    final elapsedMonths = monthsBetween(startDate, today);
    if (elapsedMonths <= 0) return GoalHealth.onTrack; // Just started!

    final remainingMonths = getRemainingMonths(today);
    final target = getInflationAdjustedTarget(globalInflation);

    if (remainingMonths <= 0) {
      if (target <= 0 || currentSavings >= target) return GoalHealth.onTrack;
      if (currentSavings >= target * 0.8) return GoalHealth.needsAttention;
      return GoalHealth.behindSchedule;
    }

    final discipline = getInvestmentDisciplineRatio(today, globalInflation, globalReturn);
    final addedRecentSip = isLastInvestmentApproxSIP(today, globalInflation, globalReturn);

    if (discipline >= 1.0) {
      return GoalHealth.onTrack;
    } else if (discipline >= 0.8) {
      // In the 80%-99% range, but user actively added their monthly SIP installment
      if (addedRecentSip) {
        return GoalHealth.onTrack;
      }
      return GoalHealth.needsAttention;
    } else {
      // Lagging behind (<80%), but actively began disciplined SIP contributions
      if (addedRecentSip && discipline >= 0.6) {
        return GoalHealth.needsAttention;
      }
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
