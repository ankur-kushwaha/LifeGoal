import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';
import '../models/goal_model.dart';
import '../models/notification_model.dart';
import 'local_ai_service.dart';

class AIGenerationResult {
  final AppNotification notification;
  final bool savedRemotely;

  const AIGenerationResult({
    required this.notification,
    required this.savedRemotely,
  });
}

class AINotificationService {
  final LocalAIService _localAI = LocalAIService();

  Future<AIGenerationResult> generate({
    required String familyId,
    required List<GoalModel> goals,
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
          options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
        );
        final result = await callable.call<Map<String, dynamic>>({
          'familyId': familyId,
          'trigger': trigger.toJson(),
          if (eventName != null) 'eventName': eventName,
          if (relatedGoalId != null) 'relatedGoalId': relatedGoalId,
        });
        final data = Map<String, dynamic>.from(result.data);
        if (data['notification'] != null) {
          return AIGenerationResult(
            notification: AppNotification.fromJson(
              Map<String, dynamic>.from(data['notification'] as Map),
            ),
            savedRemotely: true,
          );
        }
        throw FirebaseFunctionsException(
          code: 'internal',
          message: 'Cloud function returned no notification',
        );
      } on FirebaseFunctionsException {
        rethrow;
      } catch (e) {
        debugPrint('Cloud AI notification failed: $e');
        rethrow;
      }
    }

    return AIGenerationResult(
      notification: _localAI.generate(
        goals: goals,
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
