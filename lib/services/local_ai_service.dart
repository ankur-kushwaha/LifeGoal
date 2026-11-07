import '../models/goal_model.dart';
import '../models/notification_model.dart';
import '../models/profile_model.dart';
import 'financial_math_service.dart';

/// Legacy alias for FinancialMathService during AI removal cleanup.
class LocalAIService {
  final FinancialMathService _mathService = FinancialMathService();

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
    return _mathService.generate(
      goals: goals,
      familyProfile: familyProfile,
      recentNotifications: recentNotifications,
      trigger: trigger,
      eventName: eventName,
      relatedGoalId: relatedGoalId,
      today: today,
      globalInflation: globalInflation,
      globalReturn: globalReturn,
    );
  }
}
