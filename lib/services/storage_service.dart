import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../models/goal_model.dart';

abstract class BaseStorageService {
  Stream<List<GoalModel>> streamGoals(String userId);
  Stream<Map<String, dynamic>> streamSettings(String userId);
  Future<void> saveGoal(String userId, GoalModel goal);
  Future<void> deleteGoal(String userId, String goalId);
  Future<void> saveSettings(String userId, Map<String, dynamic> settings);
  Future<List<GoalModel>> getGoalsOnce(String userId);
}

class FirestoreStorageService implements BaseStorageService {
  FirestoreStorageService()
      : _firestore = FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseId: kFirestoreDatabaseId,
        );

  final FirebaseFirestore _firestore;

  @override
  Stream<List<GoalModel>> streamGoals(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('goals')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        // Ensure ID from Firestore is set in model if missing
        if (data['id'] == null) {
          data['id'] = doc.id;
        }
        return GoalModel.fromJson(data);
      }).toList();
    });
  }

  @override
  Stream<Map<String, dynamic>> streamSettings(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((docSnapshot) {
      if (docSnapshot.exists && docSnapshot.data() != null) {
        return docSnapshot.data()!;
      }
      return <String, dynamic>{};
    });
  }

  @override
  Future<void> saveGoal(String userId, GoalModel goal) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('goals')
        .doc(goal.id)
        .set(goal.toJson(), SetOptions(merge: true));
  }

  @override
  Future<void> deleteGoal(String userId, String goalId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('goals')
        .doc(goalId)
        .delete();
  }

  @override
  Future<void> saveSettings(String userId, Map<String, dynamic> settings) async {
    await _firestore.collection('users').doc(userId).set(settings, SetOptions(merge: true));
  }

  @override
  Future<List<GoalModel>> getGoalsOnce(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('goals')
        .get();
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
  // We use streams for SharedPreferences to match Firestore's interface.
  // When files change, we push data to the streams.
  final Map<String, StreamController<List<GoalModel>>> _goalsControllers = {};
  final Map<String, StreamController<Map<String, dynamic>>> _settingsControllers = {};

  StreamController<List<GoalModel>> _getGoalsController(String userId) {
    return _goalsControllers.putIfAbsent(userId, () {
      final controller = StreamController<List<GoalModel>>.broadcast();
      // Load initial data asynchronously and add to stream
      _loadLocalGoals(userId).then((goals) => controller.add(goals));
      return controller;
    });
  }

  StreamController<Map<String, dynamic>> _getSettingsController(String userId) {
    return _settingsControllers.putIfAbsent(userId, () {
      final controller = StreamController<Map<String, dynamic>>.broadcast();
      _loadLocalSettings(userId).then((settings) => controller.add(settings));
      return controller;
    });
  }

  Future<List<GoalModel>> _loadLocalGoals(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'goalsList_$userId';
      final goalsJson = prefs.getString(key);
      if (goalsJson != null) {
        final decoded = json.decode(goalsJson) as List;
        return decoded.map((item) => GoalModel.fromJson(item)).toList();
      }
      
      // Fallback: Check if there's legacy unpartitioned data in SharedPreferences
      final legacyGoalsJson = prefs.getString('goalsList');
      if (legacyGoalsJson != null) {
        final decoded = json.decode(legacyGoalsJson) as List;
        final list = decoded.map((item) => GoalModel.fromJson(item)).toList();
        // Save to this user's collection
        await prefs.setString(key, legacyGoalsJson);
        return list;
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>> _loadLocalSettings(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'settings_$userId';
    final settingsJson = prefs.getString(key);
    if (settingsJson != null) {
      try {
        return json.decode(settingsJson) as Map<String, dynamic>;
      } catch (_) {}
    }

    // Fallback: load legacy global settings
    final inflation = prefs.getDouble('globalInflation') ?? 6.0;
    final returns = prefs.getDouble('globalReturn') ?? 14.0;
    final todayStr = prefs.getString('today') ?? DateTime(2026, 7, 1).toIso8601String();

    final legacy = {
      'globalInflation': inflation,
      'globalReturn': returns,
      'today': todayStr,
    };
    return legacy;
  }

  @override
  Stream<List<GoalModel>> streamGoals(String userId) {
    return _getGoalsController(userId).stream;
  }

  @override
  Stream<Map<String, dynamic>> streamSettings(String userId) {
    return _getSettingsController(userId).stream;
  }

  @override
  Future<void> saveGoal(String userId, GoalModel goal) async {
    final prefs = await SharedPreferences.getInstance();
    final goals = await _loadLocalGoals(userId);
    
    final index = goals.indexWhere((g) => g.id == goal.id);
    if (index != -1) {
      goals[index] = goal;
    } else {
      goals.add(goal);
    }

    final key = 'goalsList_$userId';
    await prefs.setString(key, json.encode(goals.map((g) => g.toJson()).toList()));
    
    // Notify streams
    _getGoalsController(userId).add(goals);
  }

  @override
  Future<void> deleteGoal(String userId, String goalId) async {
    final prefs = await SharedPreferences.getInstance();
    final goals = await _loadLocalGoals(userId);
    goals.removeWhere((g) => g.id == goalId);

    final key = 'goalsList_$userId';
    await prefs.setString(key, json.encode(goals.map((g) => g.toJson()).toList()));

    // Notify streams
    _getGoalsController(userId).add(goals);
  }

  @override
  Future<void> saveSettings(String userId, Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'settings_$userId';
    await prefs.setString(key, json.encode(settings));

    // Notify streams
    _getSettingsController(userId).add(settings);
  }

  @override
  Future<List<GoalModel>> getGoalsOnce(String userId) async {
    return _loadLocalGoals(userId);
  }
}
