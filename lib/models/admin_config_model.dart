import 'dart:convert';
import 'family_model.dart';
import 'goal_model.dart';

/// Configuration settings manageable by the Super Admin.
class AdminConfig {
  // Financial Engine Defaults
  final double defaultInflationRate;
  final double defaultExpectedReturn;
  final DateTime defaultPlanningDate;
  final String currencySymbol;
  final int emergencyFundMonthsDefault;
  final double safeWithdrawalRate;

  // AI & Notification Engine
  final String aiProvider; // 'openrouter', 'local', 'gemini'
  final String aiModel;
  final int scheduledNotificationHour;
  final int scheduledNotificationMinute;
  final String aiAdvisorTone; // 'balanced', 'conservative', 'growth'
  final bool autoNotificationsEnabled;
  final bool forceLocalAIFallback;
  final String customOpenRouterApiKey;

  // Feature Flags & Platform Controls
  final bool maintenanceMode;
  final String maintenanceMessage;
  final bool allowNewRegistrations;
  final bool pwaPromptEnabled;
  final bool scenarioSimulatorEnabled;
  final bool strictAdminOnlyGoalDelete;
  final bool analyticsTrackingEnabled;

  // Super Admin Security & Access
  final List<String> superAdminEmails;
  final String adminPin;
  final bool pinProtectionEnabled;
  final DateTime lastUpdated;
  final String updatedBy;

  const AdminConfig({
    this.defaultInflationRate = 6.0,
    this.defaultExpectedReturn = 14.0,
    required this.defaultPlanningDate,
    this.currencySymbol = '₹',
    this.emergencyFundMonthsDefault = 6,
    this.safeWithdrawalRate = 4.0,
    this.aiProvider = 'openrouter',
    this.aiModel = 'google/gemini-2.5-flash',
    this.scheduledNotificationHour = 10,
    this.scheduledNotificationMinute = 0,
    this.aiAdvisorTone = 'balanced',
    this.autoNotificationsEnabled = true,
    this.forceLocalAIFallback = false,
    this.customOpenRouterApiKey = '',
    this.maintenanceMode = false,
    this.maintenanceMessage =
        'System is currently undergoing routine maintenance. Please check back shortly.',
    this.allowNewRegistrations = true,
    this.pwaPromptEnabled = true,
    this.scenarioSimulatorEnabled = false,
    this.strictAdminOnlyGoalDelete = false,
    this.analyticsTrackingEnabled = true,
    this.superAdminEmails = const ['ankur@lifegoal.ai', 'admin@lifegoal.ai'],
    this.adminPin = '7788',
    this.pinProtectionEnabled = true,
    required this.lastUpdated,
    this.updatedBy = 'Super Admin',
  });

  static AdminConfig defaultValues() {
    return AdminConfig(
      defaultPlanningDate: DateTime(2026, 7, 1),
      lastUpdated: DateTime(2026, 7, 1),
    );
  }

  AdminConfig copyWith({
    double? defaultInflationRate,
    double? defaultExpectedReturn,
    DateTime? defaultPlanningDate,
    String? currencySymbol,
    int? emergencyFundMonthsDefault,
    double? safeWithdrawalRate,
    String? aiProvider,
    String? aiModel,
    int? scheduledNotificationHour,
    int? scheduledNotificationMinute,
    String? aiAdvisorTone,
    bool? autoNotificationsEnabled,
    bool? forceLocalAIFallback,
    String? customOpenRouterApiKey,
    bool? maintenanceMode,
    String? maintenanceMessage,
    bool? allowNewRegistrations,
    bool? pwaPromptEnabled,
    bool? scenarioSimulatorEnabled,
    bool? strictAdminOnlyGoalDelete,
    bool? analyticsTrackingEnabled,
    List<String>? superAdminEmails,
    String? adminPin,
    bool? pinProtectionEnabled,
    DateTime? lastUpdated,
    String? updatedBy,
  }) {
    return AdminConfig(
      defaultInflationRate: defaultInflationRate ?? this.defaultInflationRate,
      defaultExpectedReturn: defaultExpectedReturn ?? this.defaultExpectedReturn,
      defaultPlanningDate: defaultPlanningDate ?? this.defaultPlanningDate,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      emergencyFundMonthsDefault:
          emergencyFundMonthsDefault ?? this.emergencyFundMonthsDefault,
      safeWithdrawalRate: safeWithdrawalRate ?? this.safeWithdrawalRate,
      aiProvider: aiProvider ?? this.aiProvider,
      aiModel: aiModel ?? this.aiModel,
      scheduledNotificationHour:
          scheduledNotificationHour ?? this.scheduledNotificationHour,
      scheduledNotificationMinute:
          scheduledNotificationMinute ?? this.scheduledNotificationMinute,
      aiAdvisorTone: aiAdvisorTone ?? this.aiAdvisorTone,
      autoNotificationsEnabled:
          autoNotificationsEnabled ?? this.autoNotificationsEnabled,
      forceLocalAIFallback: forceLocalAIFallback ?? this.forceLocalAIFallback,
      customOpenRouterApiKey:
          customOpenRouterApiKey ?? this.customOpenRouterApiKey,
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
      maintenanceMessage: maintenanceMessage ?? this.maintenanceMessage,
      allowNewRegistrations:
          allowNewRegistrations ?? this.allowNewRegistrations,
      pwaPromptEnabled: pwaPromptEnabled ?? this.pwaPromptEnabled,
      scenarioSimulatorEnabled:
          scenarioSimulatorEnabled ?? this.scenarioSimulatorEnabled,
      strictAdminOnlyGoalDelete:
          strictAdminOnlyGoalDelete ?? this.strictAdminOnlyGoalDelete,
      analyticsTrackingEnabled:
          analyticsTrackingEnabled ?? this.analyticsTrackingEnabled,
      superAdminEmails: superAdminEmails ?? this.superAdminEmails,
      adminPin: adminPin ?? this.adminPin,
      pinProtectionEnabled: pinProtectionEnabled ?? this.pinProtectionEnabled,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  Map<String, dynamic> toJson() => {
        'defaultInflationRate': defaultInflationRate,
        'defaultExpectedReturn': defaultExpectedReturn,
        'defaultPlanningDate': defaultPlanningDate.toIso8601String(),
        'currencySymbol': currencySymbol,
        'emergencyFundMonthsDefault': emergencyFundMonthsDefault,
        'safeWithdrawalRate': safeWithdrawalRate,
        'aiProvider': aiProvider,
        'aiModel': aiModel,
        'scheduledNotificationHour': scheduledNotificationHour,
        'scheduledNotificationMinute': scheduledNotificationMinute,
        'aiAdvisorTone': aiAdvisorTone,
        'autoNotificationsEnabled': autoNotificationsEnabled,
        'forceLocalAIFallback': forceLocalAIFallback,
        'customOpenRouterApiKey': customOpenRouterApiKey,
        'maintenanceMode': maintenanceMode,
        'maintenanceMessage': maintenanceMessage,
        'allowNewRegistrations': allowNewRegistrations,
        'pwaPromptEnabled': pwaPromptEnabled,
        'scenarioSimulatorEnabled': scenarioSimulatorEnabled,
        'strictAdminOnlyGoalDelete': strictAdminOnlyGoalDelete,
        'analyticsTrackingEnabled': analyticsTrackingEnabled,
        'superAdminEmails': superAdminEmails,
        'adminPin': adminPin,
        'pinProtectionEnabled': pinProtectionEnabled,
        'lastUpdated': lastUpdated.toIso8601String(),
        'updatedBy': updatedBy,
      };

  factory AdminConfig.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value, DateTime fallback) {
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (_) {}
      }
      return fallback;
    }

    final rawEmails = json['superAdminEmails'];
    List<String> emails;
    if (rawEmails is List) {
      emails = rawEmails.map((e) => e.toString().trim().toLowerCase()).toList();
    } else {
      emails = const ['ankur@lifegoal.ai', 'admin@lifegoal.ai'];
    }

    return AdminConfig(
      defaultInflationRate:
          (json['defaultInflationRate'] as num?)?.toDouble() ?? 6.0,
      defaultExpectedReturn:
          (json['defaultExpectedReturn'] as num?)?.toDouble() ?? 14.0,
      defaultPlanningDate: parseDate(
          json['defaultPlanningDate'], DateTime(2026, 7, 1)),
      currencySymbol: json['currencySymbol'] as String? ?? '₹',
      emergencyFundMonthsDefault:
          json['emergencyFundMonthsDefault'] as int? ?? 6,
      safeWithdrawalRate:
          (json['safeWithdrawalRate'] as num?)?.toDouble() ?? 4.0,
      aiProvider: json['aiProvider'] as String? ?? 'openrouter',
      aiModel: json['aiModel'] as String? ?? 'google/gemini-2.5-flash',
      scheduledNotificationHour:
          json['scheduledNotificationHour'] as int? ?? 10,
      scheduledNotificationMinute:
          json['scheduledNotificationMinute'] as int? ?? 0,
      aiAdvisorTone: json['aiAdvisorTone'] as String? ?? 'balanced',
      autoNotificationsEnabled:
          json['autoNotificationsEnabled'] as bool? ?? true,
      forceLocalAIFallback: json['forceLocalAIFallback'] as bool? ?? false,
      customOpenRouterApiKey:
          json['customOpenRouterApiKey'] as String? ?? '',
      maintenanceMode: json['maintenanceMode'] as bool? ?? false,
      maintenanceMessage: json['maintenanceMessage'] as String? ??
          'System is currently undergoing routine maintenance. Please check back shortly.',
      allowNewRegistrations: json['allowNewRegistrations'] as bool? ?? true,
      pwaPromptEnabled: json['pwaPromptEnabled'] as bool? ?? true,
      scenarioSimulatorEnabled:
          json['scenarioSimulatorEnabled'] as bool? ?? false,
      strictAdminOnlyGoalDelete:
          json['strictAdminOnlyGoalDelete'] as bool? ?? false,
      analyticsTrackingEnabled:
          json['analyticsTrackingEnabled'] as bool? ?? true,
      superAdminEmails: emails,
      adminPin: json['adminPin'] as String? ?? '7788',
      pinProtectionEnabled: json['pinProtectionEnabled'] as bool? ?? true,
      lastUpdated: parseDate(json['lastUpdated'], DateTime.now()),
      updatedBy: json['updatedBy'] as String? ?? 'Super Admin',
    );
  }

  String toFormattedJson() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toJson());
  }
}

/// Comprehensive snapshot of a Family, its members, and all associated goals for Super Admin inspection.
class FamilyOverviewData {
  final FamilyInfo family;
  final List<FamilyMember> members;
  final List<GoalModel> goals;
  final double globalInflation;
  final double globalReturn;
  final DateTime referenceDate;

  const FamilyOverviewData({
    required this.family,
    required this.members,
    required this.goals,
    this.globalInflation = 6.0,
    this.globalReturn = 14.0,
    required this.referenceDate,
  });

  double get totalCurrentSavings =>
      goals.fold(0.0, (sum, g) => sum + g.currentSavings);

  double get totalTargetCost =>
      goals.fold(0.0, (sum, g) => sum + g.getInflationAdjustedTarget(globalInflation));

  double get totalRequiredSip =>
      goals.fold(0.0, (sum, g) => sum + g.getRequiredSIP(referenceDate, globalInflation, globalReturn));

  double get overallProgressPercentage {
    final target = totalTargetCost;
    if (target <= 0) return 0.0;
    final projected =
        goals.fold(0.0, (sum, g) => sum + g.getProjectedSavings(referenceDate, globalReturn));
    final pct = (projected / target) * 100;
    return pct > 100 ? 100 : pct;
  }
}

