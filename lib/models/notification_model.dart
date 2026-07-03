import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationTrigger {
  scheduled,
  custom,
  event;

  static NotificationTrigger fromString(String value) {
    switch (value) {
      case 'scheduled':
      case 'daily': // legacy
        return NotificationTrigger.scheduled;
      case 'event':
        return NotificationTrigger.event;
      default:
        return NotificationTrigger.custom;
    }
  }

  String toJson() => name;
}

enum SuggestionType {
  actionOnGoal,
  addNewGoal,
  portfolioReview;

  static SuggestionType fromString(String? value) {
    switch (value) {
      case 'add_new_goal':
        return SuggestionType.addNewGoal;
      case 'portfolio_review':
        return SuggestionType.portfolioReview;
      default:
        return SuggestionType.actionOnGoal;
    }
  }

  String toJson() {
    switch (this) {
      case SuggestionType.addNewGoal:
        return 'add_new_goal';
      case SuggestionType.portfolioReview:
        return 'portfolio_review';
      case SuggestionType.actionOnGoal:
        return 'action_on_goal';
    }
  }
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String suggestedAction;
  final NotificationTrigger trigger;
  final String? eventName;
  final String? relatedGoalId;
  final DateTime createdAt;
  final bool isRead;
  final bool isAiGenerated;
  final SuggestionType suggestionType;
  final String? suggestedNewGoalName;
  final double? suggestedNewGoalTargetCost;
  final int? suggestedNewGoalMonths;
  final String? suggestedNewGoalAccount;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.suggestedAction,
    required this.trigger,
    this.eventName,
    this.relatedGoalId,
    required this.createdAt,
    this.isRead = false,
    this.isAiGenerated = false,
    this.suggestionType = SuggestionType.actionOnGoal,
    this.suggestedNewGoalName,
    this.suggestedNewGoalTargetCost,
    this.suggestedNewGoalMonths,
    this.suggestedNewGoalAccount,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'suggestedAction': suggestedAction,
      'trigger': trigger.toJson(),
      if (eventName != null) 'eventName': eventName,
      if (relatedGoalId != null) 'relatedGoalId': relatedGoalId,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'isAiGenerated': isAiGenerated,
      'suggestionType': suggestionType.toJson(),
      if (suggestedNewGoalName != null) 'suggestedNewGoalName': suggestedNewGoalName,
      if (suggestedNewGoalTargetCost != null) 'suggestedNewGoalTargetCost': suggestedNewGoalTargetCost,
      if (suggestedNewGoalMonths != null) 'suggestedNewGoalMonths': suggestedNewGoalMonths,
      if (suggestedNewGoalAccount != null) 'suggestedNewGoalAccount': suggestedNewGoalAccount,
    };
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      suggestedAction: json['suggestedAction'] as String? ?? '',
      trigger: NotificationTrigger.fromString(json['trigger'] as String? ?? 'custom'),
      eventName: json['eventName'] as String?,
      relatedGoalId: json['relatedGoalId'] as String?,
      createdAt: parseNotificationDate(json['createdAt']),
      isRead: json['isRead'] as bool? ?? false,
      isAiGenerated: json['isAiGenerated'] as bool? ?? false,
      suggestionType: SuggestionType.fromString(json['suggestionType'] as String?),
      suggestedNewGoalName: json['suggestedNewGoalName'] as String?,
      suggestedNewGoalTargetCost: (json['suggestedNewGoalTargetCost'] as num?)?.toDouble(),
      suggestedNewGoalMonths: json['suggestedNewGoalMonths'] as int?,
      suggestedNewGoalAccount: json['suggestedNewGoalAccount'] as String?,
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      suggestedAction: suggestedAction,
      trigger: trigger,
      eventName: eventName,
      relatedGoalId: relatedGoalId,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      isAiGenerated: isAiGenerated,
    );
  }
}

DateTime parseNotificationDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.parse(value);
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return DateTime.now();
}
