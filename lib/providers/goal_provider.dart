import 'dart:async';
import 'dart:convert';
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
        // No local user data exists, seed mock goals matching the spreadsheet
        debugPrint("Cloud storage is empty, seeding mock goals...");
        for (final goal in _getMockGoals()) {
          await _storageService.saveGoal(userId, goal);
        }
      } else {
        debugPrint("Migrating ${localGoals.length} local goals to Firebase Cloud...");
        for (final goal in localGoals) {
          await _storageService.saveGoal(userId, goal);
        }

        // Migrate local settings as well
        final localSettings = await localStore.streamSettings(userId).first.timeout(
          const Duration(milliseconds: 500),
          onTimeout: () => <String, dynamic>{},
        );
        if (localSettings.isNotEmpty) {
          await _storageService.saveSettings(userId, localSettings);
        }
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

  // Settings operations
  void updateSettings({double? inflation, double? rateOfReturn, DateTime? referenceToday}) {
    if (_currentUserId == null) return;
    
    if (inflation != null) _globalInflation = inflation;
    if (rateOfReturn != null) _globalReturn = rateOfReturn;
    if (referenceToday != null) _today = referenceToday;

    final settings = {
      'globalInflation': _globalInflation,
      'globalReturn': _globalReturn,
      'today': _today.toIso8601String(),
    };

    _storageService.saveSettings(_currentUserId!, settings);
    notifyListeners();
  }

  // CRUD Operations
  void addGoal(GoalModel goal) {
    if (_currentUserId == null) return;
    _storageService.saveGoal(_currentUserId!, goal);
  }

  void updateGoal(GoalModel updatedGoal) {
    if (_currentUserId == null) return;
    _storageService.saveGoal(_currentUserId!, updatedGoal);
  }

  void deleteGoal(String id) {
    if (_currentUserId == null) return;
    _storageService.deleteGoal(_currentUserId!, id);
  }

  // Import JSON string
  bool importData(String jsonString) {
    if (_currentUserId == null) return false;
    try {
      final decoded = json.decode(jsonString);
      if (decoded is Map<String, dynamic>) {
        final Map<String, dynamic> settings = {};
        if (decoded.containsKey('globalInflation')) {
          _globalInflation = (decoded['globalInflation'] as num).toDouble();
          settings['globalInflation'] = _globalInflation;
        }
        if (decoded.containsKey('globalReturn')) {
          _globalReturn = (decoded['globalReturn'] as num).toDouble();
          settings['globalReturn'] = _globalReturn;
        }
        if (decoded.containsKey('today')) {
          _today = DateTime.parse(decoded['today'] as String);
          settings['today'] = _today.toIso8601String();
        }
        
        if (settings.isNotEmpty) {
          _storageService.saveSettings(_currentUserId!, settings);
        }

        if (decoded.containsKey('goals')) {
          final list = decoded['goals'] as List;
          final newGoals = list.map((g) => GoalModel.fromJson(g as Map<String, dynamic>)).toList();
          for (final goal in newGoals) {
            _storageService.saveGoal(_currentUserId!, goal);
          }
        }
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint("Error importing data: $e");
    }
    return false;
  }

  // Export JSON string
  String exportData() {
    final data = {
      'globalInflation': _globalInflation,
      'globalReturn': _globalReturn,
      'today': _today.toIso8601String(),
      'goals': _goals.map((g) => g.toJson()).toList(),
    };
    return json.encode(data);
  }

  List<GoalModel> _getMockGoals() {
    return [
      GoalModel(
        id: '1',
        name: 'Home loan',
        account: 'Ankur',
        targetCost: 700000.0,
        startDate: DateTime(2023, 10, 4),
        targetDate: DateTime(2027, 3, 30),
        currentSavings: 780795.0,
      ),
      GoalModel(
        id: '2',
        name: 'Bali',
        account: 'Ankur',
        targetCost: 300000.0,
        startDate: DateTime(2024, 10, 4),
        targetDate: DateTime(2026, 12, 12),
        currentSavings: 108452.0,
      ),
      GoalModel(
        id: '3',
        name: 'Shree ki shadi',
        account: 'Ankur',
        targetCost: 2000000.0,
        startDate: DateTime(2024, 10, 4),
        targetDate: DateTime(2050, 6, 3),
        currentSavings: 418674.0,
      ),
      GoalModel(
        id: '4',
        name: 'Shree ki education',
        account: 'Ankur',
        targetCost: 2000000.0,
        startDate: DateTime(2024, 10, 4),
        targetDate: DateTime(2042, 6, 4),
        currentSavings: 343087.0,
      ),
      GoalModel(
        id: '5',
        name: 'DreamHome',
        account: 'Neha',
        targetCost: 3000000.0,
        startDate: DateTime(2024, 10, 4),
        targetDate: DateTime(2028, 8, 13),
        currentSavings: 1343000.0,
      ),
      GoalModel(
        id: '6',
        name: 'Miscellaneous',
        account: 'Neha',
        targetCost: 100000.0,
        startDate: DateTime(2024, 10, 4),
        targetDate: DateTime(2026, 12, 14),
        currentSavings: 29920.0,
      ),
      GoalModel(
        id: '7',
        name: 'Emergency',
        account: 'Neha',
        targetCost: 300000.0,
        startDate: DateTime(2024, 10, 4),
        targetDate: DateTime(2025, 12, 14),
        currentSavings: 367000.0,
      ),
    ];
  }
}
