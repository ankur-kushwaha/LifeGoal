import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';
import '../models/goal_model.dart';
import '../models/notification_model.dart';
import '../models/profile_model.dart';
import 'financial_math_service.dart';

class NotificationGenerationResult {
  final AppNotification notification;
  final bool savedRemotely;

  const NotificationGenerationResult({
    required this.notification,
    required this.savedRemotely,
  });
}

// Backward-compatible typedef
typedef AIGenerationResult = NotificationGenerationResult;

/// Service that delegates notification generation to Cloud Functions or local FinancialMathService.
class NotificationGeneratorService {
  final FinancialMathService _mathService = FinancialMathService();

  Future<NotificationGenerationResult> generate({
    required String familyId,
    required List<GoalModel> goals,
    FamilyProfile? familyProfile,
    required List<AppNotification> recentNotifications,
    required NotificationTrigger trigger,
    String? eventName,
    String? relatedGoalId,
    required DateTime today,
    required double globalInflation,
    required double globalReturn,
    bool useCloud = true,
  }) async {
    if (useCloud && DefaultFirebaseOptions.isConfigured) {
      try {
        final functions = FirebaseFunctions.instanceFor(
          app: Firebase.app(),
          region: 'asia-south1',
        );
        final callable = functions.httpsCallable(
          'generateNotification',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
        );
        final result = await callable.call<Map<String, dynamic>>({
          'familyId': familyId,
          'trigger': trigger.toJson(),
          if (eventName != null) 'eventName': eventName,
          if (relatedGoalId != null) 'relatedGoalId': relatedGoalId,
        });
        final data = Map<String, dynamic>.from(result.data);
        if (data['notification'] != null) {
          return NotificationGenerationResult(
            notification: AppNotification.fromJson(
              Map<String, dynamic>.from(data['notification'] as Map),
            ),
            savedRemotely: true,
          );
        }
      } catch (e) {
        debugPrint('Cloud notification computation failed, using local math engine: $e');
      }
    }

    return NotificationGenerationResult(
      notification: _mathService.generate(
        goals: goals,
        familyProfile: familyProfile,
        recentNotifications: recentNotifications,
        trigger: trigger,
        eventName: eventName,
        relatedGoalId: relatedGoalId,
        today: today,
        globalInflation: globalInflation,
        globalReturn: globalReturn,
      ),
      savedRemotely: false,
    );
  }
}

// Backward-compatible alias
class AINotificationService extends NotificationGeneratorService {}
