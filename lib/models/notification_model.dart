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
