import 'package:flutter/material.dart';
import '../models/admin_config_model.dart';
import '../models/notification_model.dart';
import '../services/admin_service.dart';
import '../services/ai_notification_service.dart';
import '../services/local_ai_service.dart';
import 'goal_provider.dart';

class AdminProvider extends ChangeNotifier {
  final AdminService _service;
  AdminConfig _config = AdminConfig.defaultValues();
  bool _isLoading = true;
  bool _isSuperAdminVerified = false;
  String? _lastError;
  String? _lastSuccess;
  List<FamilyOverviewData> _allFamilies = [];
  bool _isLoadingFamilies = false;

  AdminProvider({AdminService? service})
      : _service = service ?? AdminService() {
    _initialize();
  }

  AdminConfig get config => _config;
  bool get isLoading => _isLoading;
  bool get isSuperAdminVerified => _isSuperAdminVerified;
  List<FamilyOverviewData> get allFamilies => _allFamilies;
  bool get isLoadingFamilies => _isLoadingFamilies;
  String? get lastError => _lastError;
  String? get lastSuccess => _lastSuccess;

  Future<void> _initialize() async {
    _isLoading = true;
    notifyListeners();
    try {
      _config = await _service.loadConfig();
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool checkSuperAdminAccess(String? email) {
    if (_isSuperAdminVerified) return true;
    if (email != null && _service.isAuthorizedSuperAdmin(email: email)) {
      _isSuperAdminVerified = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  bool verifyPin(String enteredPin) {
    if (enteredPin.trim() == _config.adminPin.trim()) {
      _isSuperAdminVerified = true;
      _lastError = null;
      notifyListeners();
      return true;
    }
    _lastError = 'Invalid Super Admin PIN.';
    notifyListeners();
    return false;
  }

  void grantAccessForTesting() {
    _isSuperAdminVerified = true;
    notifyListeners();
  }

  void lockSession() {
    _isSuperAdminVerified = false;
    notifyListeners();
  }

  void updateInMemory(AdminConfig updated) {
    _config = updated;
    notifyListeners();
  }

  Future<void> saveConfig([AdminConfig? updated]) async {
    if (updated != null) {
      _config = updated;
    }
    _isLoading = true;
    _lastError = null;
    _lastSuccess = null;
    notifyListeners();

    try {
      await _service.saveConfig(_config);
      _lastSuccess = 'Super Admin configuration saved successfully!';
    } catch (e) {
      _lastError = 'Failed to save configuration: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resetToDefaults() async {
    _isLoading = true;
    notifyListeners();
    try {
      _config = await _service.resetDefaults();
      _lastSuccess = 'Configuration reset to system defaults!';
    } catch (e) {
      _lastError = 'Reset failed: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> importFromJson(String jsonStr) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      _config = await _service.importConfigJson(jsonStr);
      _lastSuccess = 'Configuration imported successfully!';
      return true;
    } catch (e) {
      _lastError = 'Import error: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String exportToJson() {
    return _service.exportConfigJson();
  }

  /// Applies the admin default inflation and rate of return to the active family
  Future<void> applyDefaultsToFamily(GoalProvider goalProvider) async {
    await goalProvider.updateSettings(
      inflation: _config.defaultInflationRate,
      rateOfReturn: _config.defaultExpectedReturn,
      referenceToday: _config.defaultPlanningDate,
    );
    _lastSuccess =
        'Applied defaults (${_config.defaultInflationRate}% inf / ${_config.defaultExpectedReturn}% return) to current family!';
    notifyListeners();
  }

  /// Live test generation of AI notification using configured settings
  Future<AppNotification> testAiNotification(GoalProvider goalProvider) async {
    final goals = goalProvider.goals;
    final today = _config.defaultPlanningDate;

    if (_config.forceLocalAIFallback || _config.aiProvider == 'local') {
      final localAI = LocalAIService();
      return localAI.generate(
        goals: goals,
        recentNotifications: const [],
        trigger: NotificationTrigger.custom,
        eventName: 'admin_test_trigger',
        today: today,
        globalInflation: _config.defaultInflationRate,
        globalReturn: _config.defaultExpectedReturn,
      );
    }

    try {
      final aiService = AINotificationService();
      final result = await aiService.generate(
        familyId: goalProvider.currentFamilyId ?? 'admin-test-family',
        goals: goals,
        recentNotifications: const [],
        trigger: NotificationTrigger.custom,
        eventName: 'admin_test_trigger',
        today: today,
        globalInflation: _config.defaultInflationRate,
        globalReturn: _config.defaultExpectedReturn,
        useCloud: !_config.forceLocalAIFallback,
      );
      return result.notification;
    } catch (e) {
      // Fallback to local AI with debug notification
      final localAI = LocalAIService();
      final localNote = localAI.generate(
        goals: goals,
        recentNotifications: const [],
        trigger: NotificationTrigger.custom,
        eventName: 'admin_test_trigger',
        today: today,
        globalInflation: _config.defaultInflationRate,
        globalReturn: _config.defaultExpectedReturn,
      );
      return AppNotification(
        id: 'test-${DateTime.now().millisecondsSinceEpoch}',
        title: '${localNote.title} (Fallback AI)',
        body: '${localNote.body}\n[Cloud AI Note: $e]',
        suggestedAction: localNote.suggestedAction,
        trigger: NotificationTrigger.custom,
        createdAt: DateTime.now(),
        isRead: false,
        isAiGenerated: true,
      );
    }
  }

  Future<void> fetchAllFamilies(GoalProvider goalProvider) async {
    _isLoadingFamilies = true;
    _lastError = null;
    notifyListeners();
    try {
      _allFamilies = await _service.loadAllFamiliesWithDetails(
        currentGoalProvider: goalProvider,
        pin: _config.adminPin,
      );
    } catch (e) {
      _lastError = 'Error fetching all families: $e';
      debugPrint('Error fetching all families in AdminProvider: $e');
    } finally {
      _isLoadingFamilies = false;
      notifyListeners();
    }
  }

  void clearMessages() {
    _lastError = null;
    _lastSuccess = null;
    notifyListeners();
  }
}
