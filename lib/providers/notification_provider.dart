import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../firebase_options.dart';
import '../models/notification_model.dart';
import '../services/ai_notification_service.dart';
import '../services/local_notification_scheduler.dart';
import '../services/notification_service.dart';
import 'goal_provider.dart';

class NotificationProvider extends ChangeNotifier {
  List<AppNotification> _notifications = [];
  bool _isGenerating = false;
  String? _familyId;
  String? _error;

  late BaseNotificationService _notificationService;
  final AINotificationService _aiService = AINotificationService();
  final LocalNotificationScheduler _scheduler = LocalNotificationScheduler();

  GoalProvider? _goalProvider;
  StreamSubscription<List<AppNotification>>? _subscription;
  DateTime? _lastGeneratedAt;
  static const _generationCooldown = Duration(minutes: 2);

  List<AppNotification> get notifications => _notifications;
  bool get isGenerating => _isGenerating;
  String? get error => _error;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  NotificationProvider() {
    _notificationService = DefaultFirebaseOptions.isConfigured
        ? FirestoreNotificationService()
        : SharedPreferencesNotificationService();
    _initScheduler();
  }

  Future<void> _initScheduler() async {
    await _scheduler.initialize(
      onTap: (payload) {
        if (payload == 'scheduled') {
          triggerScheduled();
        }
      },
    );
    await _scheduler.scheduleDailyAt10AM();
  }

  void attachToGoalProvider(GoalProvider goalProvider) {
    final newFamilyId = goalProvider.currentFamilyId;
    if (_goalProvider == goalProvider && _familyId == newFamilyId) return;
    _goalProvider = goalProvider;
    _onFamilyChanged(newFamilyId);
  }

  void _onFamilyChanged(String? familyId) {
    _subscription?.cancel();
    _familyId = familyId;
    _notifications = [];
    _error = null;

    if (familyId == null) {
      notifyListeners();
      return;
    }

    _subscription = _notificationService.streamNotifications(familyId).listen(
      (list) {
        _notifications = _sortedNewestFirst(list);
        notifyListeners();
      },
      onError: (e) {
        debugPrint('Notification stream error: $e');
      },
    );

    _maybeRunScheduledGeneration();
  }

  Future<void> _maybeRunScheduledGeneration() async {
    if (_familyId == null || _goalProvider == null || _isGenerating) return;

    final recent = await _notificationService.getRecentNotifications(_familyId!, limit: 10);
    final now = DateTime.now();
    final today10AM = DateTime(now.year, now.month, now.day, 10);
    if (now.isBefore(today10AM)) return;

    final lastScheduled = recent
        .where((n) => n.trigger == NotificationTrigger.scheduled)
        .fold<DateTime?>(null, (latest, n) {
      if (latest == null || n.createdAt.isAfter(latest)) return n.createdAt;
      return latest;
    });

    if (lastScheduled != null && !lastScheduled.isBefore(today10AM)) return;

    await triggerScheduled(silent: true);
  }

  Future<AppNotification?> triggerScheduled({bool silent = false}) {
    return _generate(
      trigger: NotificationTrigger.scheduled,
      eventName: 'scheduled_10am',
      silent: silent,
    );
  }

  Future<AppNotification?> triggerCustom() {
    return _generate(
      trigger: NotificationTrigger.custom,
      eventName: 'manual',
    );
  }

  Future<AppNotification?> triggerEvent({
    required String eventName,
    String? relatedGoalId,
  }) {
    return _generate(
      trigger: NotificationTrigger.event,
      eventName: eventName,
      relatedGoalId: relatedGoalId,
    );
  }

  Future<AppNotification?> _generate({
    required NotificationTrigger trigger,
    String? eventName,
    String? relatedGoalId,
    bool silent = false,
  }) async {
    if (_familyId == null || _goalProvider == null || _isGenerating) return null;

    if (trigger != NotificationTrigger.event &&
        _lastGeneratedAt != null &&
        DateTime.now().difference(_lastGeneratedAt!) < _generationCooldown) {
      _error = 'Please wait a moment before requesting another suggestion.';
      notifyListeners();
      return null;
    }

    final goals = _goalProvider!.goals;
    final today = _goalProvider!.today;
    final inflation = _goalProvider!.globalInflation;
    final globalReturn = _goalProvider!.globalReturn;

    _isGenerating = true;
    _error = null;
    notifyListeners();

    try {
      final recent = await _notificationService.getRecentNotifications(_familyId!, limit: 5);
      final result = await _aiService.generate(
        familyId: _familyId!,
        goals: goals,
        recentNotifications: recent,
        trigger: trigger,
        eventName: eventName,
        relatedGoalId: relatedGoalId,
        today: today,
        globalInflation: inflation,
        globalReturn: globalReturn,
      );

      if (!result.savedRemotely) {
        await _notificationService.saveNotification(_familyId!, result.notification);
      }

      _prependNotification(result.notification);
      _lastGeneratedAt = DateTime.now();

      if (!silent) {
        await _scheduler.showInstant(
          title: result.notification.title,
          body: result.notification.suggestedAction,
          payload: result.notification.id,
        );
      }

      return result.notification;
    } on FirebaseFunctionsException catch (e) {
      _error = e.message ?? 'AI service error (${e.code})';
      debugPrint('Notification generation failed: ${e.code} ${e.message}');
      return null;
    } catch (e) {
      _error = e.toString();
      debugPrint('Notification generation failed: $e');
      return null;
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String notificationId) async {
    if (_familyId == null) return;
    await _notificationService.markAsRead(_familyId!, notificationId);
  }

  Future<void> markAllAsRead() async {
    if (_familyId == null) return;
    await _notificationService.markAllAsRead(_familyId!);
  }

  Future<void> deleteNotification(String notificationId) async {
    if (_familyId == null) return;
    await _notificationService.deleteNotification(_familyId!, notificationId);
    _notifications = _notifications.where((n) => n.id != notificationId).toList();
    notifyListeners();
  }

  Future<void> clearAllNotifications() async {
    if (_familyId == null) return;
    await _notificationService.clearAllNotifications(_familyId!);
    _notifications = [];
    notifyListeners();
  }

  void _prependNotification(AppNotification notification) {
    _notifications = _sortedNewestFirst([
      notification,
      ..._notifications.where((n) => n.id != notification.id),
    ]);
    notifyListeners();
  }

  List<AppNotification> _sortedNewestFirst(List<AppNotification> list) {
    final sorted = [...list];
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
