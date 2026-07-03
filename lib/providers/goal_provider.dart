import 'dart:async';
import 'package:flutter/material.dart';
import '../models/family_model.dart';
import '../models/goal_model.dart';
import '../models/profile_model.dart';
import '../services/auth_service.dart';
import '../services/family_service.dart';
import '../services/profile_service.dart';
import '../services/storage_service.dart';
import '../firebase_options.dart';
import '../data/spreadsheet_goals.dart';

class GoalProvider extends ChangeNotifier {
  List<GoalModel> _goals = [];
  double _globalInflation = 6.0;
  double _globalReturn = 14.0;
  DateTime _today = DateTime(2026, 7, 1);
  bool _isLoading = true;

  bool _isFirebaseMode = false;
  late BaseAuthService _authService;
  late BaseStorageService _storageService;
  late BaseFamilyService _familyService;
  late BaseProfileService _profileService;
  String? _currentUserId;
  String? _currentFamilyId;
  FamilyInfo? _family;
  FamilyProfile _familyProfile = const FamilyProfile();
  List<FamilyMember> _familyMembers = [];
  List<FamilyInvite> _pendingInvites = [];

  StreamSubscription<String?>? _authSubscription;
  StreamSubscription<List<GoalModel>>? _goalsSubscription;
  StreamSubscription<Map<String, dynamic>>? _settingsSubscription;
  StreamSubscription<FamilyInfo?>? _familySubscription;
  StreamSubscription<List<FamilyMember>>? _membersSubscription;
  StreamSubscription<List<FamilyInvite>>? _invitesSubscription;
  StreamSubscription<FamilyProfile>? _familyProfileSubscription;

  List<GoalModel> get goals => _goals;
  double get globalInflation => _globalInflation;
  double get globalReturn => _globalReturn;
  DateTime get today => _today;
  bool get isLoading => _isLoading;
  bool get isFirebaseMode => _isFirebaseMode;
  String? get currentUserId => _currentUserId;
  String? get currentFamilyId => _currentFamilyId;
  bool get isAuthenticated => _currentUserId != null;
  FamilyInfo? get family => _family;
  FamilyProfile get familyProfile => _familyProfile;
  List<FamilyMember> get familyMembers => _familyMembers;
  List<FamilyInvite> get pendingInvites => _pendingInvites;

  BaseAuthService get authService => _authService;
  BaseStorageService get storageService => _storageService;

  FamilyMember? get currentMember {
    if (_currentUserId == null) return null;
    for (final member in _familyMembers) {
      if (member.userId == _currentUserId) return member;
    }
    return null;
  }

  bool get isFamilyAdmin => currentMember?.isAdmin ?? false;

  List<GoalModel> goalsForMember(String memberLabel) {
    if (memberLabel == 'All') return _goals;

    FamilyMember? member;
    for (final m in _familyMembers) {
      if (m.label.toLowerCase() == memberLabel.toLowerCase()) {
        member = m;
        break;
      }
    }

    if (member != null) {
      return _goals.where((g) => member!.matchesAccount(g.account)).toList();
    }

    return _goals
        .where((g) => g.account.trim().toLowerCase() == memberLabel.toLowerCase())
        .toList();
  }

  List<String> get familyMemberLabels {
    final list = _familyMembers.map((m) => m.label).toList()..sort();
    return list;
  }

  List<String> get accounts => familyMemberLabels;

  String resolveMemberLabel(String account) {
    for (final member in _familyMembers) {
      if (member.matchesAccount(account)) return member.label;
    }
    return account;
  }

  double get totalWealthInvested {
    return _goals.fold(0.0, (sum, g) => sum + g.currentSavings);
  }

  double get totalRequiredSIP {
    return _goals.fold(0.0, (sum, g) => sum + g.getRequiredSIP(_today, _globalInflation, _globalReturn));
  }

  double get totalRemainingInvestment {
    return _goals.fold(0.0, (sum, g) => sum + g.getRemainingAmountNeeded(_today, _globalInflation, _globalReturn));
  }

  double get overallProgressPercentage {
    double totalTarget = _goals.fold(0.0, (sum, g) => sum + g.getInflationAdjustedTarget(_globalInflation));
    if (totalTarget == 0) return 0.0;

    double totalProjected = _goals.fold(0.0, (sum, g) => sum + g.getProjectedSavings(_today, _globalReturn));
    double pct = (totalProjected / totalTarget) * 100;
    return pct > 100 ? 100 : pct;
  }

  GoalProvider() {
    _initializeServices();
  }

  @override
  void dispose() {
    _cancelAllSubscriptions();
    super.dispose();
  }

  void _cancelAllSubscriptions() {
    _authSubscription?.cancel();
    _goalsSubscription?.cancel();
    _settingsSubscription?.cancel();
    _familySubscription?.cancel();
    _membersSubscription?.cancel();
    _invitesSubscription?.cancel();
    _familyProfileSubscription?.cancel();
  }

  Future<void> _initializeServices() async {
    _isLoading = true;
    notifyListeners();

    _cancelAllSubscriptions();

    final isConfigured = DefaultFirebaseOptions.isConfigured;
    _isFirebaseMode = isConfigured;

    if (_isFirebaseMode) {
      _authService = FirebaseAuthService();
      _storageService = FirestoreStorageService();
      _familyService = FirestoreFamilyService();
      _profileService = FirestoreProfileService();
    } else {
      _authService = LocalMockAuthService();
      _storageService = SharedPreferencesStorageService();
      _familyService = LocalFamilyService();
      _profileService = SharedPreferencesProfileService();
    }

    _authSubscription = _authService.onAuthStateChanged.listen((userId) {
      _handleAuthStateChange(userId);
    });
  }

  Future<void> _handleAuthStateChange(String? userId) async {
    _goalsSubscription?.cancel();
    _settingsSubscription?.cancel();
    _familySubscription?.cancel();
    _membersSubscription?.cancel();
    _invitesSubscription?.cancel();
    _familyProfileSubscription?.cancel();

    if (userId != null) {
      _currentUserId = userId;
      _isLoading = true;
      notifyListeners();

      final email = _authService.currentUserEmail ?? '';
      try {
        await _familyService.ensureMembership(
          userId: userId,
          email: email,
          displayName: _authService.currentUserDisplayName,
        );
      } catch (e) {
        debugPrint('Family setup failed: $e');
        _isLoading = false;
        notifyListeners();
        return;
      }

      _currentFamilyId = await _familyService.getUserFamilyId(userId);
      if (_currentFamilyId == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      await _migrateLocalDataToCloud(_currentFamilyId!);

      _familySubscription = _familyService.streamFamily(_currentFamilyId!).listen((family) {
        _family = family;
        notifyListeners();
      });

      _membersSubscription = _familyService.streamMembers(_currentFamilyId!).listen((members) {
        _familyMembers = members;
        _pendingInvites = _pendingInvitesForMembers(_pendingInvites, members);
        notifyListeners();
      });

      _invitesSubscription = _familyService.streamPendingInvites(_currentFamilyId!).listen((invites) {
        _pendingInvites = _pendingInvitesForMembers(invites, _familyMembers);
        notifyListeners();
      });

      _familyProfileSubscription =
          _profileService.streamFamilyProfile(_currentFamilyId!).listen((profile) {
        _familyProfile = profile;
        notifyListeners();
      });

      _goalsSubscription = _storageService.streamGoals(_currentFamilyId!).listen((goalsList) {
        _goals = goalsList;
        _isLoading = false;
        notifyListeners();
      }, onError: (e) {
        debugPrint('Error listening to goals: $e');
        _isLoading = false;
        notifyListeners();
      });

      _settingsSubscription = _storageService.streamSettings(_currentFamilyId!).listen((settingsMap) {
        if (settingsMap.containsKey('globalInflation')) {
          _globalInflation = (settingsMap['globalInflation'] as num).toDouble();
        }
        if (settingsMap.containsKey('globalReturn')) {
          _globalReturn = (settingsMap['globalReturn'] as num).toDouble();
        }
        if (settingsMap.containsKey('today')) {
          _today = DateTime.parse(settingsMap['today'] as String);
        }
        notifyListeners();
      }, onError: (e) {
        debugPrint('Error listening to settings: $e');
      });
    } else {
      _currentUserId = null;
      _currentFamilyId = null;
      _family = null;
      _familyProfile = const FamilyProfile();
      _familyMembers = [];
      _pendingInvites = [];
      _goals = [];
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _migrateLocalDataToCloud(String familyId) async {
    try {
      final cloudGoals = await _storageService.getGoalsOnce(familyId);
      if (cloudGoals.isNotEmpty) return;

      final localStore = SharedPreferencesStorageService();
      final localGoals = await localStore.getGoalsOnce(familyId);
      if (localGoals.isEmpty && _currentUserId != null) {
        final legacyGoals = await localStore.getGoalsOnce(_currentUserId!);
        if (legacyGoals.isNotEmpty) {
          for (final goal in legacyGoals) {
            await _storageService.saveGoal(familyId, goal);
          }
        }
      } else if (localGoals.isNotEmpty) {
        for (final goal in localGoals) {
          await _storageService.saveGoal(familyId, goal);
        }
      }

      final localSettings = await localStore.streamSettings(familyId).first.timeout(
        const Duration(milliseconds: 500),
        onTimeout: () => <String, dynamic>{},
      );
      if (localSettings.isNotEmpty) {
        await _storageService.saveSettings(familyId, localSettings);
      }
    } catch (e) {
      debugPrint('Migration failed: $e');
    }
  }

  Future<void> signUp(String email, String password) async {
    await _authService.signUp(email, password);
  }

  Future<void> signIn(String email, String password) async {
    await _authService.signIn(email, password);
  }

  Future<void> signInWithGoogle() async {
    await _authService.signInWithGoogle();
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  Future<void> inviteFamilyMember(String email) async {
    if (_currentFamilyId == null || _currentUserId == null) {
      throw Exception('You must be signed in to invite members.');
    }
    if (!isFamilyAdmin) {
      throw Exception('Only the family admin can invite members.');
    }
    await _familyService.inviteMember(
      familyId: _currentFamilyId!,
      invitedBy: _currentUserId!,
      email: email,
    );
  }

  Future<void> removeFamilyMember(String memberId) async {
    if (_currentFamilyId == null || _currentUserId == null) {
      throw Exception('You must be signed in to remove members.');
    }
    await _familyService.removeMember(
      familyId: _currentFamilyId!,
      memberId: memberId,
      adminId: _currentUserId!,
    );
  }

  Future<void> updateFamilyName(String name) async {
    if (_currentFamilyId == null || _currentUserId == null) {
      throw Exception('You must be signed in to update the family.');
    }
    await _familyService.updateFamilyName(
      familyId: _currentFamilyId!,
      name: name,
      adminId: _currentUserId!,
    );
  }

  Future<void> saveFamilyProfile(FamilyProfile profile) async {
    if (_currentFamilyId == null) {
      throw Exception('Family not ready yet.');
    }
    await _profileService.saveFamilyProfile(_currentFamilyId!, profile);
    _familyProfile = profile;
    notifyListeners();
  }

  Future<void> saveMemberProfile(String memberId, MemberProfile profile) async {
    if (_currentFamilyId == null) {
      throw Exception('Family not ready yet.');
    }
    await _profileService.saveMemberProfile(_currentFamilyId!, memberId, profile);
    _familyMembers = _familyMembers
        .map((m) => m.userId == memberId ? m.copyWith(memberProfile: profile) : m)
        .toList();
    notifyListeners();
  }

  Future<MemberProfile> loadMemberProfile(String memberId) async {
    if (_currentFamilyId == null) return const MemberProfile();
    return _profileService.getMemberProfile(_currentFamilyId!, memberId);
  }

  String get familyProfileContextText {
    return buildFamilyProfileContextText(
      familyProfile: _familyProfile,
      members: _familyMembers
          .map((m) => (name: m.label, profile: m.memberProfile))
          .toList(),
    );
  }

  Future<void> updateSettings({double? inflation, double? rateOfReturn, DateTime? referenceToday}) async {
    if (_currentFamilyId == null) return;

    if (inflation != null) _globalInflation = inflation;
    if (rateOfReturn != null) _globalReturn = rateOfReturn;
    if (referenceToday != null) _today = referenceToday;

    final settings = {
      'globalInflation': _globalInflation,
      'globalReturn': _globalReturn,
      'today': _today.toIso8601String(),
    };

    await _storageService.saveSettings(_currentFamilyId!, settings);
    notifyListeners();
  }

  Future<void> addGoal(GoalModel goal) async {
    if (_currentFamilyId == null) {
      throw Exception('Family not ready yet. Please wait a moment and try again.');
    }
    _goals = [..._goals, goal];
    notifyListeners();
    try {
      await _storageService.saveGoal(_currentFamilyId!, goal);
    } catch (e) {
      _goals = _goals.where((g) => g.id != goal.id).toList();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateGoal(GoalModel updatedGoal) async {
    if (_currentFamilyId == null) {
      throw Exception('Family not ready yet. Please wait a moment and try again.');
    }
    final previous = _goals;
    _goals = _goals.map((g) => g.id == updatedGoal.id ? updatedGoal : g).toList();
    notifyListeners();
    try {
      await _storageService.saveGoal(_currentFamilyId!, updatedGoal);
    } catch (e) {
      _goals = previous;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteGoal(String id) async {
    if (_currentFamilyId == null) return;
    await _storageService.deleteGoal(_currentFamilyId!, id);
  }

  Future<void> refreshFromCloud() async {
    if (_currentFamilyId == null) return;
    final goals = await _storageService.getGoalsOnce(_currentFamilyId!);
    _goals = goals;
    notifyListeners();
  }

  /// Import or refresh the 7 goals from the planning spreadsheet.
  Future<int> importSpreadsheetGoals() async {
    if (_currentFamilyId == null) {
      throw Exception('Family not ready yet. Please wait a moment and try again.');
    }

    var imported = 0;
    for (final goal in SpreadsheetGoals.all) {
      final exists = _goals.any((g) => g.id == goal.id);
      if (exists) {
        await updateGoal(goal);
      } else {
        await addGoal(goal);
      }
      imported++;
    }
    return imported;
  }

  List<FamilyInvite> _pendingInvitesForMembers(
    List<FamilyInvite> invites,
    List<FamilyMember> members,
  ) {
    final memberEmails = members.map((m) => normalizeEmail(m.email)).toSet();
    return invites
        .where((invite) => !memberEmails.contains(normalizeEmail(invite.email)))
        .toList();
  }
}
