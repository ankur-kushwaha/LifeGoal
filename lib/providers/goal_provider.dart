import 'dart:async';
import 'package:flutter/material.dart';
import '../models/goal_model.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../firebase_options.dart';

class GoalProvider extends ChangeNotifier {
  List<GoalModel> _goals = [];
  double _globalInflation = 6.0;
  double _globalReturn = 14.0;
  DateTime _today = DateTime(2026, 7, 1);
  bool _isLoading = true;

  // Database mode and Service instances
  bool _isFirebaseMode = false;
  late BaseAuthService _authService;
  late BaseStorageService _storageService;
  String? _currentUserId;

  // Stream Subscriptions
  StreamSubscription<String?>? _authSubscription;
  StreamSubscription<List<GoalModel>>? _goalsSubscription;
  StreamSubscription<Map<String, dynamic>>? _settingsSubscription;

  // Getters
  List<GoalModel> get goals => _goals;
  double get globalInflation => _globalInflation;
  double get globalReturn => _globalReturn;
  DateTime get today => _today;
  bool get isLoading => _isLoading;
  bool get isFirebaseMode => _isFirebaseMode;
  String? get currentUserId => _currentUserId;
  bool get isAuthenticated => _currentUserId != null;

  BaseAuthService get authService => _authService;
  BaseStorageService get storageService => _storageService;

  List<String> get accounts {
    final list = _goals.map((g) => g.account.trim()).where((a) => a.isNotEmpty).toSet().toList();
    list.sort();
    return list;
  }

  // Financial Calculations
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
  }

  // Determine active database mode and initialize corresponding services
  Future<void> _initializeServices() async {
    _isLoading = true;
    notifyListeners();

    _cancelAllSubscriptions();

    final isConfigured = DefaultFirebaseOptions.isConfigured;
    _isFirebaseMode = isConfigured;

    if (_isFirebaseMode) {
      _authService = FirebaseAuthService();
      _storageService = FirestoreStorageService();
    } else {
      _authService = LocalMockAuthService();
      _storageService = SharedPreferencesStorageService();
    }

    // Listen to Auth State Changes
    _authSubscription = _authService.onAuthStateChanged.listen((userId) {
      _handleAuthStateChange(userId);
    });
  }

  Future<void> _handleAuthStateChange(String? userId) async {
    _goalsSubscription?.cancel();
    _settingsSubscription?.cancel();

    if (userId != null) {
      _currentUserId = userId;
      
      // Auto-migrate data if first-time user
      await _migrateLocalDataToCloud(userId);

      // Listen to goals and settings
      _goalsSubscription = _storageService.streamGoals(userId).listen((goalsList) {
        _goals = goalsList;
        _isLoading = false;
        notifyListeners();
      }, onError: (e) {
        debugPrint("Error listening to goals: $e");
        _isLoading = false;
        notifyListeners();
      });

      _settingsSubscription = _storageService.streamSettings(userId).listen((settingsMap) {
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
        debugPrint("Error listening to settings: $e");
      });
    } else {
      _currentUserId = null;
      _goals = [];
      _isLoading = false;
      notifyListeners();
    }
  }

  // Automatic Cloud Migration
  Future<void> _migrateLocalDataToCloud(String userId) async {
    try {
      // Fetch goals already present in the current active storage
      final cloudGoals = await _storageService.getGoalsOnce(userId);
      if (cloudGoals.isNotEmpty) {
        return; // Cloud already populated, skip migration
      }

      // Fetch goals from local SharedPreferencesStorageService
      final localStore = SharedPreferencesStorageService();
      final localGoals = await localStore.getGoalsOnce(userId);

      if (localGoals.isEmpty) {
        return;
      }

      debugPrint('Migrating ${localGoals.length} local goals to cloud...');
      for (final goal in localGoals) {
        await _storageService.saveGoal(userId, goal);
      }

      final localSettings = await localStore.streamSettings(userId).first.timeout(
        const Duration(milliseconds: 500),
        onTimeout: () => <String, dynamic>{},
      );
      if (localSettings.isNotEmpty) {
        await _storageService.saveSettings(userId, localSettings);
      }
    } catch (e) {
      debugPrint("Migration failed: $e");
    }
  }

  // Auth Operations
  Future<void> signUp(String email, String password) async {
    await _authService.signUp(email, password);
  }

  Future<void> signIn(String email, String password) async {
    await _authService.signIn(email, password);
  }

  Future<void> signInWithGoogle() async {
    await _authService.signInWithGoogle();
  }

  Future<void> sendPhoneVerificationCode(
    String phoneNumber, {
    required void Function(String verificationId) onCodeSent,
    required void Function(String message) onError,
    int? forceResendingToken,
  }) async {
    await _authService.sendPhoneVerificationCode(
      phoneNumber,
      onCodeSent: onCodeSent,
      onError: onError,
      forceResendingToken: forceResendingToken,
    );
  }

  Future<void> signInWithPhoneCode(String verificationId, String smsCode) async {
    await _authService.signInWithPhoneCode(verificationId, smsCode);
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  // Settings operations — writes sync to cloud immediately.
  Future<void> updateSettings({double? inflation, double? rateOfReturn, DateTime? referenceToday}) async {
    if (_currentUserId == null) return;

    if (inflation != null) _globalInflation = inflation;
    if (rateOfReturn != null) _globalReturn = rateOfReturn;
    if (referenceToday != null) _today = referenceToday;

    final settings = {
      'globalInflation': _globalInflation,
      'globalReturn': _globalReturn,
      'today': _today.toIso8601String(),
    };

    await _storageService.saveSettings(_currentUserId!, settings);
    notifyListeners();
  }

  // CRUD — each change is saved to Firestore and reflected via live streams.
  Future<void> addGoal(GoalModel goal) async {
    if (_currentUserId == null) return;
    await _storageService.saveGoal(_currentUserId!, goal);
  }

  Future<void> updateGoal(GoalModel updatedGoal) async {
    if (_currentUserId == null) return;
    await _storageService.saveGoal(_currentUserId!, updatedGoal);
  }

  Future<void> deleteGoal(String id) async {
    if (_currentUserId == null) return;
    await _storageService.deleteGoal(_currentUserId!, id);
  }

  Future<void> refreshFromCloud() async {
    if (_currentUserId == null) return;
    final goals = await _storageService.getGoalsOnce(_currentUserId!);
    _goals = goals;
    notifyListeners();
  }
}
