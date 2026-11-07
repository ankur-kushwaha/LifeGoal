import '../models/goal_model.dart';
import '../models/notification_model.dart';
import '../models/profile_model.dart';

/// Pure mathematical financial computation engine for notifications.
/// Calculates inflation-adjusted goals, required SIPs, surplus vs deficit,
/// loan EMI load, and milestone dates. Zero AI or external LLM dependencies.
class FinancialMathService {
  AppNotification generate({
    required List<GoalModel> goals,
    FamilyProfile? familyProfile,
    required List<AppNotification> recentNotifications,
    required NotificationTrigger trigger,
    String? eventName,
    String? relatedGoalId,
    required DateTime today,
    required double globalInflation,
    required double globalReturn,
  }) {
    if (goals.isEmpty) {
      return _build(
        title: 'Add your first financial goal',
        body: 'Track your milestones with inflation-adjusted targets and monthly SIP math. Add your first goal to get started.',
        suggestedAction: 'Tap + to create a goal with target date and cost.',
        trigger: trigger,
        eventName: eventName,
        relatedGoalId: relatedGoalId,
        suggestionType: SuggestionType.addNewGoal,
      );
    }

    final fp = familyProfile ?? const FamilyProfile();
    final monthlyIncome = fp.monthlyHouseholdIncome;
    final monthlyExpenses = fp.monthlyHouseholdExpenses;
    final totalEmi = fp.totalMonthlyEmi;
    final monthlySurplus = fp.monthlySurplus;

    // Compute total required SIP across all active goals
    final totalRequiredSip = goals.fold(
      0.0,
      (sum, g) => sum + g.getRequiredSIP(today, globalInflation, globalReturn),
    );

    final candidates = <_MathCandidate>[];

    // ==========================================
    // 1. Deficit Alert: SIP Exceeds Monthly Surplus
    // ==========================================
    if (monthlySurplus != null && totalRequiredSip > monthlySurplus && monthlySurplus > 0) {
      final deficit = totalRequiredSip - monthlySurplus;
      candidates.add(_MathCandidate(
        priority: 150,
        title: 'Required SIP exceeds surplus by ₹${_formatAmount(deficit)}',
        body:
            'Your goals require ₹${_formatAmount(totalRequiredSip)}/mo in total SIP. '
            'After salary (₹${_formatAmount(monthlyIncome ?? 0)}), expenses (₹${_formatAmount(monthlyExpenses ?? 0)}), '
            'and EMIs (₹${_formatAmount(totalEmi)}), your surplus is ₹${_formatAmount(monthlySurplus)}/mo.',
        suggestedAction:
            'Extend goal target dates or trim expenses to bridge the ₹${_formatAmount(deficit)}/mo shortfall.',
        suggestionType: SuggestionType.portfolioReview,
      ));
    }

    // ==========================================
    // 2. High Debt-to-Income / EMI Burden (> 40%)
    // ==========================================
    if (monthlyIncome != null && monthlyIncome > 0 && totalEmi > 0) {
      final emiRatio = totalEmi / monthlyIncome;
      if (emiRatio >= 0.40) {
        candidates.add(_MathCandidate(
          priority: 140,
          title: 'High EMI load: ${(emiRatio * 100).toStringAsFixed(0)}% of monthly salary',
          body:
              'Monthly EMIs total ₹${_formatAmount(totalEmi)} against ₹${_formatAmount(monthlyIncome)} salary. '
              'Financial guidelines suggest keeping total EMIs under 40% of income.',
          suggestedAction:
              'Focus excess cash on clearing high-cost loans to free up monthly investment capacity.',
          suggestionType: SuggestionType.portfolioReview,
        ));
      }
    }

    // ==========================================
    // 3. Approaching Loan Payoff Milestone (<= 6 months)
    // ==========================================
    final maturingLoans = fp.loans.where(
      (l) => l.remainingMonths > 0 && l.remainingMonths <= 6 && l.emi > 0,
    );
    if (maturingLoans.isNotEmpty) {
      final loan = maturingLoans.first;
      candidates.add(_MathCandidate(
        priority: 135,
        title: '${loan.type.label} EMI ending in ${loan.remainingMonths} months!',
        body:
            'Your monthly EMI of ₹${_formatAmount(loan.emi)} will finish in ${loan.remainingMonths} months. '
            'This will liberate ₹${_formatAmount(loan.emi)}/mo in monthly cash flow.',
        suggestedAction:
            'Plan to redirect this ₹${_formatAmount(loan.emi)}/mo into your priority goals once paid off.',
        suggestionType: SuggestionType.portfolioReview,
      ));
    }

    // ==========================================
    // 4. Goals Behind Schedule
    // ==========================================
    for (final goal in goals) {
      final health = goal.getHealth(today, globalInflation, globalReturn);
      final sip = goal.getRequiredSIP(today, globalInflation, globalReturn);
      final progress = goal.getPercentDone(today, globalInflation, globalReturn);
      final remaining = goal.getRemainingMonths(today);
      final adjustedTarget = goal.getInflationAdjustedTarget(globalInflation);

      if (health == GoalHealth.behindSchedule) {
        candidates.add(_MathCandidate(
          priority: 120,
          title: '${goal.name} needs attention',
          body:
              '${goal.name} has $remaining months left to target date. '
              'Current savings ₹${_formatAmount(goal.currentSavings)} vs adjusted target ₹${_formatAmount(adjustedTarget)}. '
              'You need ₹${_formatAmount(sip)}/month SIP to catch up.',
          suggestedAction:
              'Increase monthly SIP for "${goal.name}" to ₹${_formatAmount(sip)} or contribute a lump sum.',
          relatedGoalId: goal.id,
          suggestionType: SuggestionType.actionOnGoal,
        ));
      } else if (health == GoalHealth.needsAttention) {
        candidates.add(_MathCandidate(
          priority: 105,
          title: 'Review ${goal.name}',
          body:
              '${goal.name} is slightly behind with $remaining months remaining (${progress.toStringAsFixed(0)}% funded). '
              'Required SIP: ₹${_formatAmount(sip)}/mo.',
          suggestedAction:
              'Open "${goal.name}" and check if you can bump your monthly contribution.',
          relatedGoalId: goal.id,
          suggestionType: SuggestionType.actionOnGoal,
        ));
      }

      // ==========================================
      // 5. Goal Deadlines Approaching (<= 12 months)
      // ==========================================
      if (remaining <= 12 && remaining > 0 && progress < 95) {
        candidates.add(_MathCandidate(
          priority: 110,
          title: '${goal.name} target date in $remaining months',
          body:
              'Only $remaining months left for ${goal.name}. Progress is ${progress.toStringAsFixed(0)}%. '
              'Required monthly SIP to reach target: ₹${_formatAmount(sip)}/mo.',
          suggestedAction:
              'Verify latest balance for "${goal.name}" and top up to reach ₹${_formatAmount(adjustedTarget)}.',
          relatedGoalId: goal.id,
          suggestionType: SuggestionType.actionOnGoal,
        ));
      }

      // ==========================================
      // 6. Goals Fully Funded
      // ==========================================
      if (sip <= 0 && (goal.currentSavings > 0 || progress >= 99)) {
        candidates.add(_MathCandidate(
          priority: 85,
          title: '${goal.name} is fully funded!',
          body:
              'Current savings of ₹${_formatAmount(goal.currentSavings)} will grow to reach '
              'the ₹${_formatAmount(adjustedTarget)} target by its target date.',
          suggestedAction:
              'Consider gradually shifting "${goal.name}" to conservative instruments as deadline nears.',
          relatedGoalId: goal.id,
          suggestionType: SuggestionType.actionOnGoal,
        ));
      }
    }

    // ==========================================
    // 7. Unallocated Monthly Cash Surplus
    // ==========================================
    if (monthlySurplus != null && monthlySurplus > totalRequiredSip + 3000) {
      final unallocated = monthlySurplus - totalRequiredSip;
      candidates.add(_MathCandidate(
        priority: 100,
        title: '₹${_formatAmount(unallocated)}/mo unallocated surplus available',
        body:
            'After expenses (₹${_formatAmount(monthlyExpenses ?? 0)}), EMIs (₹${_formatAmount(totalEmi)}), '
            'and goal SIPs (₹${_formatAmount(totalRequiredSip)}), you have ₹${_formatAmount(unallocated)}/mo extra surplus.',
        suggestedAction:
            'Allocate extra surplus towards long-term compounding goals or accelerate debt clearance.',
        suggestionType: SuggestionType.portfolioReview,
      ));
    }

    // ==========================================
    // 8. Emergency Fund Check
    // ==========================================
    if (monthlyExpenses != null && monthlyExpenses > 0) {
      final emTarget = fp.emergencyFundTarget ?? (monthlyExpenses * 6);
      final hasEmergencyGoal = goals.any(
        (g) => g.name.toLowerCase().contains('emergency') || g.name.toLowerCase().contains('contingency'),
      );
      if (!hasEmergencyGoal) {
        candidates.add(_MathCandidate(
          priority: 95,
          title: 'Build an Emergency Buffer (₹${_formatAmount(emTarget)})',
          body:
              'With monthly expenses of ₹${_formatAmount(monthlyExpenses)}, '
              'a ${fp.emergencyFundMonths}-month safety net requires ₹${_formatAmount(emTarget)} kept liquid.',
          suggestedAction:
              'Create a dedicated Emergency Fund goal to protect your family from unexpected financial shocks.',
          suggestionType: SuggestionType.addNewGoal,
          suggestedNewGoalName: 'Emergency Fund',
          suggestedNewGoalTargetCost: emTarget,
          suggestedNewGoalMonths: 12,
        ));
      }
    }

    // ==========================================
    // 9. Weekly Financial Check-in Summary
    // ==========================================
    String summaryBody =
        'Your family has ${goals.length} active goals with total required monthly SIP of ₹${_formatAmount(totalRequiredSip)}.';
    if (monthlySurplus != null) {
      summaryBody += ' Estimated monthly surplus after expenses & EMIs is ₹${_formatAmount(monthlySurplus)}.';
    }

    candidates.add(_MathCandidate(
      priority: 50,
      title: 'Weekly financial goals check-in',
      body: summaryBody,
      suggestedAction: 'Take 2 minutes to review current balances and ensure contributions are up to date.',
      suggestionType: SuggestionType.portfolioReview,
    ));

    // Boost priority if a specific goal was requested
    if (relatedGoalId != null) {
      for (final c in candidates) {
        if (c.relatedGoalId == relatedGoalId) {
          c.priority += 200;
        }
      }
    }

    candidates.sort((a, b) => b.priority.compareTo(a.priority));

    // Deduplicate against recent notifications
    final recentTitles = recentNotifications.map((n) => n.title.toLowerCase().trim()).toSet();
    final recentGoalIds = recentNotifications
        .map((n) => n.relatedGoalId)
        .whereType<String>()
        .toSet();

    for (final candidate in candidates) {
      final titleKey = candidate.title.toLowerCase().trim();
      if (recentTitles.contains(titleKey)) continue;
      if (candidate.relatedGoalId != null &&
          recentGoalIds.contains(candidate.relatedGoalId) &&
          candidates.length > 2) {
        continue;
      }
      return _buildCandidate(candidate, trigger, eventName, relatedGoalId);
    }

    final fallback = candidates.first;
    return _buildCandidate(fallback, trigger, eventName, relatedGoalId);
  }

  AppNotification _buildCandidate(
    _MathCandidate candidate,
    NotificationTrigger trigger,
    String? eventName,
    String? relatedGoalId,
  ) {
    return _build(
      title: candidate.title,
      body: candidate.body,
      suggestedAction: candidate.suggestedAction,
      trigger: trigger,
      eventName: eventName,
      relatedGoalId: candidate.relatedGoalId ?? relatedGoalId,
      suggestionType: candidate.suggestionType,
      suggestedNewGoalName: candidate.suggestedNewGoalName,
      suggestedNewGoalTargetCost: candidate.suggestedNewGoalTargetCost,
      suggestedNewGoalMonths: candidate.suggestedNewGoalMonths,
    );
  }

  AppNotification _build({
    required String title,
    required String body,
    required String suggestedAction,
    required NotificationTrigger trigger,
    String? eventName,
    String? relatedGoalId,
    SuggestionType suggestionType = SuggestionType.actionOnGoal,
    String? suggestedNewGoalName,
    double? suggestedNewGoalTargetCost,
    int? suggestedNewGoalMonths,
  }) {
    return AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      suggestedAction: suggestedAction,
      trigger: trigger,
      eventName: eventName,
      relatedGoalId: relatedGoalId,
      createdAt: DateTime.now(),
      isAiGenerated: false,
      suggestionType: suggestionType,
      suggestedNewGoalName: suggestedNewGoalName,
      suggestedNewGoalTargetCost: suggestedNewGoalTargetCost,
      suggestedNewGoalMonths: suggestedNewGoalMonths,
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(2)}Cr';
    }
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }
}

class _MathCandidate {
  int priority;
  final String title;
  final String body;
  final String suggestedAction;
  final String? relatedGoalId;
  final SuggestionType suggestionType;
  final String? suggestedNewGoalName;
  final double? suggestedNewGoalTargetCost;
  final int? suggestedNewGoalMonths;

  _MathCandidate({
    required this.priority,
    required this.title,
    required this.body,
    required this.suggestedAction,
    this.relatedGoalId,
    this.suggestionType = SuggestionType.actionOnGoal,
    this.suggestedNewGoalName,
    this.suggestedNewGoalTargetCost,
    this.suggestedNewGoalMonths,
  });
}
