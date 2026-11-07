import 'package:flutter/material.dart';
import '../models/admin_config_model.dart';
import '../models/family_model.dart';
import '../models/notification_model.dart';
import '../models/profile_model.dart';
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

  /// Live test generation of financial notification using mathematical computation engine
  Future<AppNotification> testNotification(GoalProvider goalProvider) async {
    final goals = goalProvider.goals;
    final familyProfile = goalProvider.familyProfile;
    final today = _config.defaultPlanningDate;

    final generatorService = NotificationGeneratorService();
    final result = await generatorService.generate(
      familyId: goalProvider.currentFamilyId ?? 'admin-test-family',
      goals: goals,
      familyProfile: familyProfile,
      recentNotifications: const [],
      trigger: NotificationTrigger.custom,
      eventName: 'admin_test_trigger',
      today: today,
      globalInflation: _config.defaultInflationRate,
      globalReturn: _config.defaultExpectedReturn,
      useCloud: true,
    );
    return result.notification;
  }

  // Backward-compatible alias
  Future<AppNotification> testAiNotification(GoalProvider goalProvider) =>
      testNotification(goalProvider);

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

  Future<bool> deleteFamily(String familyId, [GoalProvider? goalProvider]) async {
    _isLoadingFamilies = true;
    _lastError = null;
    notifyListeners();
    try {
      await _service.deleteFamily(familyId, pin: _config.adminPin);
      _allFamilies.removeWhere((f) => f.family.id == familyId);
      _lastSuccess = 'Family deleted successfully!';
      return true;
    } catch (e) {
      _lastError = 'Failed to delete family: $e';
      return false;
    } finally {
      _isLoadingFamilies = false;
      notifyListeners();
    }
  }

  Future<bool> addMemberToFamily(
    String familyId, {
    required String email,
    String? displayName,
    FamilyRole role = FamilyRole.member,
    MemberProfile memberProfile = const MemberProfile(),
    bool makePrimaryAdmin = false,
  }) async {
    _isLoadingFamilies = true;
    _lastError = null;
    notifyListeners();
    try {
      final newMember = await _service.addMemberToFamily(
        familyId,
        email: email,
        displayName: displayName,
        role: role,
        memberProfile: memberProfile,
        makePrimaryAdmin: makePrimaryAdmin,
        pin: _config.adminPin,
      );

      final index = _allFamilies.indexWhere((f) => f.family.id == familyId);
      if (index != -1) {
        final fam = _allFamilies[index];
        final updatedMembers = [...fam.members, newMember]
          ..sort((a, b) => a.label.compareTo(b.label));
        final updatedFamily = makePrimaryAdmin
            ? FamilyInfo(
                id: fam.family.id,
                name: fam.family.name,
                adminId: newMember.userId,
                createdAt: fam.family.createdAt,
              )
            : fam.family;

        _allFamilies[index] = FamilyOverviewData(
          family: updatedFamily,
          members: updatedMembers,
          goals: fam.goals,
          globalInflation: fam.globalInflation,
          globalReturn: fam.globalReturn,
          referenceDate: fam.referenceDate,
        );
      }
      _lastSuccess = 'Added member "${newMember.label}" successfully!';
      return true;
    } catch (e) {
      _lastError = 'Failed to add member: $e';
      return false;
    } finally {
      _isLoadingFamilies = false;
      notifyListeners();
    }
  }

  Future<bool> updateFamilyMember(
    String familyId,
    String memberId, {
    String? displayName,
    FamilyRole? role,
    MemberProfile? memberProfile,
    bool makePrimaryAdmin = false,
  }) async {
    _isLoadingFamilies = true;
    _lastError = null;
    notifyListeners();
    try {
      final updatedMember = await _service.updateFamilyMember(
        familyId,
        memberId,
        displayName: displayName,
        role: role,
        memberProfile: memberProfile,
        makePrimaryAdmin: makePrimaryAdmin,
        pin: _config.adminPin,
      );

      final index = _allFamilies.indexWhere((f) => f.family.id == familyId);
      if (index != -1) {
        final fam = _allFamilies[index];
        final updatedMembers = fam.members.map((m) {
          if (m.userId == memberId) {
            return updatedMember;
          }
          return m;
        }).toList();

        final updatedFamily = makePrimaryAdmin
            ? FamilyInfo(
                id: fam.family.id,
                name: fam.family.name,
                adminId: memberId,
                createdAt: fam.family.createdAt,
              )
            : fam.family;

        _allFamilies[index] = FamilyOverviewData(
          family: updatedFamily,
          members: updatedMembers,
          goals: fam.goals,
          globalInflation: fam.globalInflation,
          globalReturn: fam.globalReturn,
          referenceDate: fam.referenceDate,
        );
      }
      _lastSuccess = 'Updated member "${updatedMember.label}" successfully!';
      return true;
    } catch (e) {
      _lastError = 'Failed to update member: $e';
      return false;
    } finally {
      _isLoadingFamilies = false;
      notifyListeners();
    }
  }

  Future<bool> removeMemberFromFamily(
    String familyId,
    String memberId, {
    String? newAdminId,
  }) async {
    _isLoadingFamilies = true;
    _lastError = null;
    notifyListeners();
    try {
      await _service.removeMemberFromFamily(
        familyId,
        memberId,
        newAdminId: newAdminId,
        pin: _config.adminPin,
      );

      final index = _allFamilies.indexWhere((f) => f.family.id == familyId);
      if (index != -1) {
        final fam = _allFamilies[index];
        final updatedMembers = fam.members.where((m) => m.userId != memberId).toList();
        final currentAdminId = fam.family.adminId;
        final updatedAdminId = currentAdminId == memberId
            ? (newAdminId ?? (updatedMembers.isNotEmpty ? updatedMembers.first.userId : ''))
            : currentAdminId;

        _allFamilies[index] = FamilyOverviewData(
          family: FamilyInfo(
            id: fam.family.id,
            name: fam.family.name,
            adminId: updatedAdminId,
            createdAt: fam.family.createdAt,
          ),
          members: updatedMembers,
          goals: fam.goals,
          globalInflation: fam.globalInflation,
          globalReturn: fam.globalReturn,
          referenceDate: fam.referenceDate,
        );
      }
      _lastSuccess = 'Removed member from family successfully!';
      return true;
    } catch (e) {
      _lastError = 'Failed to remove member: $e';
      return false;
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
