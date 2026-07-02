import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../models/goal_model.dart';

abstract class BaseStorageService {
  Stream<List<GoalModel>> streamGoals(String familyId);
  Stream<Map<String, dynamic>> streamSettings(String familyId);
  Future<void> saveGoal(String familyId, GoalModel goal);
  Future<void> deleteGoal(String familyId, String goalId);
  Future<void> saveSettings(String familyId, Map<String, dynamic> settings);
  Future<List<GoalModel>> getGoalsOnce(String familyId);
}

class FirestoreStorageService implements BaseStorageService {
  FirestoreStorageService()
      : _firestore = FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseId: kFirestoreDatabaseId,
        ) {
    _firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _goalsRef(String familyId) =>
      _firestore.collection('families').doc(familyId).collection('goals');

  DocumentReference<Map<String, dynamic>> _settingsRef(String familyId) =>
      _firestore.collection('families').doc(familyId);

  @override
  Stream<List<GoalModel>> streamGoals(String familyId) {
    return _goalsRef(familyId).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        if (data['id'] == null) {
          data['id'] = doc.id;
        }
        return GoalModel.fromJson(data);
      }).toList();
    });
  }

  @override
  Stream<Map<String, dynamic>> streamSettings(String familyId) {
    return _settingsRef(familyId).snapshots().map((docSnapshot) {
      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        return {
          if (data.containsKey('globalInflation')) 'globalInflation': data['globalInflation'],
          if (data.containsKey('globalReturn')) 'globalReturn': data['globalReturn'],
          if (data.containsKey('today')) 'today': data['today'],
        };
      }
      return <String, dynamic>{};
    });
  }

  @override
  Future<void> saveGoal(String familyId, GoalModel goal) async {
    await _goalsRef(familyId).doc(goal.id).set(goal.toJson(), SetOptions(merge: true));
  }

  @override
  Future<void> deleteGoal(String familyId, String goalId) async {
    await _goalsRef(familyId).doc(goalId).delete();
  }

  @override
  Future<void> saveSettings(String familyId, Map<String, dynamic> settings) async {
    await _settingsRef(familyId).set(settings, SetOptions(merge: true));
  }

  @override
  Future<List<GoalModel>> getGoalsOnce(String familyId) async {
    final snapshot = await _goalsRef(familyId).get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      if (data['id'] == null) {
        data['id'] = doc.id;
      }
      return GoalModel.fromJson(data);
    }).toList();
  }
}

class SharedPreferencesStorageService implements BaseStorageService {
  final Map<String, StreamController<List<GoalModel>>> _goalsControllers = {};
  final Map<String, StreamController<Map<String, dynamic>>> _settingsControllers = {};

  StreamController<List<GoalModel>> _getGoalsController(String familyId) {
    return _goalsControllers.putIfAbsent(familyId, () {
      final controller = StreamController<List<GoalModel>>.broadcast();
      _loadLocalGoals(familyId).then((goals) => controller.add(goals));
      return controller;
    });
  }

  StreamController<Map<String, dynamic>> _getSettingsController(String familyId) {
    return _settingsControllers.putIfAbsent(familyId, () {
      final controller = StreamController<Map<String, dynamic>>.broadcast();
      _loadLocalSettings(familyId).then((settings) => controller.add(settings));
      return controller;
    });
  }

  Future<List<GoalModel>> _loadLocalGoals(String familyId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'goalsList_$familyId';
      final goalsJson = prefs.getString(key);
      if (goalsJson != null) {
        final decoded = json.decode(goalsJson) as List;
        return decoded.map((item) => GoalModel.fromJson(item)).toList();
      }

      final legacyGoalsJson = prefs.getString('goalsList');
      if (legacyGoalsJson != null) {
        final decoded = json.decode(legacyGoalsJson) as List;
        final list = decoded.map((item) => GoalModel.fromJson(item)).toList();
        await prefs.setString(key, legacyGoalsJson);
        return list;
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>> _loadLocalSettings(String familyId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'settings_$familyId';
    final settingsJson = prefs.getString(key);
    if (settingsJson != null) {
      try {
        return json.decode(settingsJson) as Map<String, dynamic>;
      } catch (_) {}
    }

    return {
      'globalInflation': prefs.getDouble('globalInflation') ?? 6.0,
      'globalReturn': prefs.getDouble('globalReturn') ?? 14.0,
      'today': prefs.getString('today') ?? DateTime(2026, 7, 1).toIso8601String(),
    };
  }

  @override
  Stream<List<GoalModel>> streamGoals(String familyId) {
    return _getGoalsController(familyId).stream;
  }

  @override
  Stream<Map<String, dynamic>> streamSettings(String familyId) {
    return _getSettingsController(familyId).stream;
  }

  @override
  Future<void> saveGoal(String familyId, GoalModel goal) async {
    final prefs = await SharedPreferences.getInstance();
    final goals = await _loadLocalGoals(familyId);

    final index = goals.indexWhere((g) => g.id == goal.id);
    if (index != -1) {
      goals[index] = goal;
    } else {
      goals.add(goal);
    }

    final key = 'goalsList_$familyId';
    await prefs.setString(key, json.encode(goals.map((g) => g.toJson()).toList()));
    _getGoalsController(familyId).add(goals);
  }

  @override
  Future<void> deleteGoal(String familyId, String goalId) async {
    final prefs = await SharedPreferences.getInstance();
    final goals = await _loadLocalGoals(familyId);
    goals.removeWhere((g) => g.id == goalId);

    final key = 'goalsList_$familyId';
    await prefs.setString(key, json.encode(goals.map((g) => g.toJson()).toList()));
    _getGoalsController(familyId).add(goals);
  }

  @override
  Future<void> saveSettings(String familyId, Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'settings_$familyId';
    await prefs.setString(key, json.encode(settings));
    _getSettingsController(familyId).add(settings);
  }

  @override
  Future<List<GoalModel>> getGoalsOnce(String familyId) async {
    return _loadLocalGoals(familyId);
  }
}
