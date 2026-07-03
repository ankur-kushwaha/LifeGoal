import 'dart:math';
import '../models/goal_model.dart';
import '../models/notification_model.dart';

/// Rule-based AI fallback when Cloud Functions are unavailable.
class LocalAIService {
  AppNotification generate({
    required List<GoalModel> goals,
    required List<AppNotification> recentNotifications,
    required NotificationTrigger trigger,
    String? eventName,
    String? relatedGoalId,
    required DateTime today,
    required double globalInflation,
    required double globalReturn,
  }) {
    final recentBodies = recentNotifications.map((n) => n.body.toLowerCase()).toSet();
    final recentActions = recentNotifications.map((n) => n.suggestedAction.toLowerCase()).toSet();

    if (goals.isEmpty) {
      return _build(
        title: 'Add your first goal',
        body: 'You have no financial goals yet. Start by adding a goal to get personalized SIP recommendations.',
        suggestedAction: 'Tap + to create your first goal and set a target date.',
        trigger: trigger,
        eventName: eventName,
        relatedGoalId: relatedGoalId,
      );
    }

    final candidates = <_SuggestionCandidate>[];

    for (final goal in goals) {
      final health = goal.getHealth(today, globalInflation, globalReturn);
      final sip = goal.getRequiredSIP(today, globalInflation, globalReturn);
      final progress = goal.getPercentDone(today, globalInflation, globalReturn);
      final remaining = goal.getRemainingMonths(today);

      if (health == GoalHealth.behindSchedule) {
        candidates.add(_SuggestionCandidate(
          priority: 100,
          title: '${goal.name} needs attention',
          body:
              '${goal.name} is behind schedule at ${progress.toStringAsFixed(0)}% progress. '
              'You need ₹${_formatAmount(sip)}/month SIP to stay on track.',
          suggestedAction: 'Increase monthly SIP for "${goal.name}" or update current savings.',
          relatedGoalId: goal.id,
        ));
      } else if (health == GoalHealth.needsAttention) {
        candidates.add(_SuggestionCandidate(
          priority: 80,
          title: 'Review ${goal.name}',
          body:
              '${goal.name} is slightly behind with ${remaining} months left. '
              'Required SIP: ₹${_formatAmount(sip)}/month.',
          suggestedAction: 'Open "${goal.name}" and check if you can bump savings this month.',
          relatedGoalId: goal.id,
        ));
      }

      if (remaining <= 6 && remaining > 0 && progress < 90) {
        candidates.add(_SuggestionCandidate(
          priority: 70,
          title: '${goal.name} deadline approaching',
          body: 'Only $remaining months left for ${goal.name}. You are at ${progress.toStringAsFixed(0)}% of target.',
          suggestedAction: 'Consider a one-time top-up to "${goal.name}" to close the gap faster.',
          relatedGoalId: goal.id,
        ));
      }

      if (sip <= 0 && progress >= 99) {
        candidates.add(_SuggestionCandidate(
          priority: 50,
          title: '${goal.name} is fully funded!',
          body: 'Great news — ${goal.name} is on track without additional SIP needed.',
          suggestedAction: 'Review your portfolio allocation or redirect SIP to another goal.',
          relatedGoalId: goal.id,
        ));
      }
    }

    final totalSip = goals.fold(0.0, (sum, g) => sum + g.getRequiredSIP(today, globalInflation, globalReturn));
    candidates.add(_SuggestionCandidate(
      priority: 40,
      title: 'Monthly SIP overview',
      body:
          'Your family has ${goals.length} active goals. Total required monthly SIP: ₹${_formatAmount(totalSip)}.',
      suggestedAction: 'Review the dashboard and ensure all goals have up-to-date savings amounts.',
    ));

    candidates.add(_SuggestionCandidate(
      priority: 30,
      title: 'Weekly check-in',
      body: 'Take 2 minutes to update current savings across your goals for accurate projections.',
      suggestedAction: 'Open each goal and refresh the "Current Savings" field with latest balances.',
    ));

    candidates.sort((a, b) => b.priority.compareTo(a.priority));

    for (final candidate in candidates) {
      final bodyKey = candidate.body.toLowerCase();
      final actionKey = candidate.suggestedAction.toLowerCase();
      if (!recentBodies.contains(bodyKey) && !recentActions.contains(actionKey)) {
        return _build(
          title: candidate.title,
          body: candidate.body,
          suggestedAction: candidate.suggestedAction,
          trigger: trigger,
          eventName: eventName,
          relatedGoalId: candidate.relatedGoalId ?? relatedGoalId,
        );
      }
    }

    final fallback = candidates[Random().nextInt(min(3, candidates.length))];
    return _build(
      title: fallback.title,
      body: fallback.body,
      suggestedAction: fallback.suggestedAction,
      trigger: trigger,
      eventName: eventName,
      relatedGoalId: fallback.relatedGoalId ?? relatedGoalId,
    );
  }

  AppNotification _build({
    required String title,
    required String body,
    required String suggestedAction,
    required NotificationTrigger trigger,
    String? eventName,
    String? relatedGoalId,
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
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }
}

class _SuggestionCandidate {
  final int priority;
  final String title;
  final String body;
  final String suggestedAction;
  final String? relatedGoalId;

  _SuggestionCandidate({
    required this.priority,
    required this.title,
    required this.body,
    required this.suggestedAction,
    this.relatedGoalId,
  });
}
