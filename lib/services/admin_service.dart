import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../firebase_options.dart';
import '../models/admin_config_model.dart';
import '../models/family_model.dart';
import '../models/goal_model.dart';
import '../providers/goal_provider.dart';

class AdminService {
  static const String _storageKey = 'super_admin_config';
  static const String _firestoreCollection = 'system_config';
  static const String _firestoreDoc = 'global';

  static final AdminService _instance = AdminService._internal();
  factory AdminService() => _instance;
  AdminService._internal();

  AdminConfig? _cachedConfig;

  AdminConfig get currentConfig =>
      _cachedConfig ?? AdminConfig.defaultValues();

  Future<AdminConfig> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localJson = prefs.getString(_storageKey);
      if (localJson != null) {
        final decoded = json.decode(localJson) as Map<String, dynamic>;
        _cachedConfig = AdminConfig.fromJson(decoded);
        return _cachedConfig!;
      }
    } catch (e) {
      debugPrint('Error reading local admin config: $e');
    }

    // Attempt cloud config if available
    if (DefaultFirebaseOptions.isConfigured) {
      try {
        final firestore = FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseId: kFirestoreDatabaseId,
        );
        final doc = await firestore
            .collection(_firestoreCollection)
            .doc(_firestoreDoc)
            .get();
        if (doc.exists && doc.data() != null) {
          _cachedConfig = AdminConfig.fromJson(doc.data()!);
          return _cachedConfig!;
        }
      } catch (e) {
        debugPrint('Cloud admin config not accessible (using default): $e');
      }
    }

    _cachedConfig = AdminConfig.defaultValues();
    return _cachedConfig!;
  }

  Future<void> saveConfig(AdminConfig config) async {
    _cachedConfig = config.copyWith(lastUpdated: DateTime.now());

    // 1. Save to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = json.encode(_cachedConfig!.toJson());
      await prefs.setString(_storageKey, jsonStr);
    } catch (e) {
      debugPrint('Failed to save admin config to SharedPreferences: $e');
    }

    // 2. Best-effort sync to Firestore
    if (DefaultFirebaseOptions.isConfigured) {
      try {
        final firestore = FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseId: kFirestoreDatabaseId,
        );
        await firestore
            .collection(_firestoreCollection)
            .doc(_firestoreDoc)
            .set(_cachedConfig!.toJson(), SetOptions(merge: true));
      } catch (e) {
        debugPrint('Firestore admin config sync skipped/failed: $e');
      }
    }
  }

  Future<AdminConfig> resetDefaults() async {
    final fresh = AdminConfig.defaultValues().copyWith(lastUpdated: DateTime.now());
    await saveConfig(fresh);
    return fresh;
  }

  String exportConfigJson() {
    return currentConfig.toFormattedJson();
  }

  Future<AdminConfig> importConfigJson(String jsonString) async {
    final decoded = json.decode(jsonString) as Map<String, dynamic>;
    final config = AdminConfig.fromJson(decoded);
    await saveConfig(config);
    return config;
  }

  bool isAuthorizedSuperAdmin({String? email, String? enteredPin}) {
    final cfg = currentConfig;

    // PIN check
    if (enteredPin != null && enteredPin.trim() == cfg.adminPin.trim()) {
      return true;
    }

    // Email check
    if (email != null && email.trim().isNotEmpty) {
      final normalized = email.trim().toLowerCase();
      for (final adminEmail in cfg.superAdminEmails) {
        if (adminEmail.trim().toLowerCase() == normalized) {
          return true;
        }
      }
      // Convenience matching for common local/testing admin identities
      if (normalized.startsWith('admin@') || normalized.startsWith('ankur')) {
        return true;
      }
    }

    // If PIN protection is explicitly disabled
    if (!cfg.pinProtectionEnabled) {
      return true;
    }

    return false;
  }

  Future<void> clearLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _cachedConfig = null;
  }

  /// Fetches all families along with their members and goals for Super Admin overview.
  Future<List<FamilyOverviewData>> loadAllFamiliesWithDetails({
    GoalProvider? currentGoalProvider,
  }) async {
    final Map<String, FamilyOverviewData> familiesMap = {};

    // 1. If Firestore is configured, attempt fetching all families from cloud
    if (DefaultFirebaseOptions.isConfigured) {
      try {
        final firestore = FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseId: kFirestoreDatabaseId,
        );

        final familiesSnap = await firestore.collection('families').get();
        for (final doc in familiesSnap.docs) {
          final familyId = doc.id;
          final familyData = doc.data();
          final familyInfo = FamilyInfo.fromJson(familyId, familyData);

          final inflation =
              (familyData['globalInflation'] as num?)?.toDouble() ?? 6.0;
          final returns =
              (familyData['globalReturn'] as num?)?.toDouble() ?? 14.0;
          DateTime refDate = DateTime(2026, 7, 1);
          if (familyData['today'] is String) {
            try {
              refDate = DateTime.parse(familyData['today'] as String);
            } catch (_) {}
          }

          // Fetch members
          final membersSnap = await firestore
              .collection('families')
              .doc(familyId)
              .collection('members')
              .get();
          final members = membersSnap.docs
              .map((d) => FamilyMember.fromJson(d.id, d.data()))
              .toList()
            ..sort((a, b) => a.label.compareTo(b.label));

          // Fetch goals
          final goalsSnap = await firestore
              .collection('families')
              .doc(familyId)
              .collection('goals')
              .get();
          final goals = goalsSnap.docs.map((d) {
            final data = d.data();
            if (data['id'] == null) data['id'] = d.id;
            return GoalModel.fromJson(data);
          }).toList();

          familiesMap[familyId] = FamilyOverviewData(
            family: familyInfo,
            members: members,
            goals: goals,
            globalInflation: inflation,
            globalReturn: returns,
            referenceDate: refDate,
          );
        }
      } catch (e) {
        debugPrint('Cloud families query exception: $e');
      }
    }

    // 2. Also check SharedPreferences (local families)
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      // Find all family_* keys
      for (final key in keys) {
        if (key.startsWith('family_')) {
          final familyId = key.substring('family_'.length);
          if (familiesMap.containsKey(familyId)) continue;

          final jsonStr = prefs.getString(key);
          if (jsonStr != null) {
            try {
              final decoded = json.decode(jsonStr) as Map<String, dynamic>;
              final familyInfo = FamilyInfo.fromJson(familyId, decoded);

              // Load members
              final membersKey = 'members_$familyId';
              final membersJson = prefs.getString(membersKey);
              List<FamilyMember> members = [];
              if (membersJson != null) {
                final list = json.decode(membersJson) as List;
                members = list.map((item) {
                  final map = item as Map<String, dynamic>;
                  return FamilyMember.fromJson(map['userId'] ?? 'user', map);
                }).toList();
              }

              // Load goals
              final goalsKey = 'goalsList_$familyId';
              final goalsJson = prefs.getString(goalsKey);
              List<GoalModel> goals = [];
              if (goalsJson != null) {
                final list = json.decode(goalsJson) as List;
                goals = list.map((item) => GoalModel.fromJson(item)).toList();
              }

              familiesMap[familyId] = FamilyOverviewData(
                family: familyInfo,
                members: members,
                goals: goals,
                referenceDate: DateTime(2026, 7, 1),
              );
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('Local families scan exception: $e');
    }

    // 3. Always ensure currentGoalProvider's active family is included if present
    if (currentGoalProvider != null &&
        currentGoalProvider.currentFamilyId != null) {
      final curId = currentGoalProvider.currentFamilyId!;
      final curFamily = currentGoalProvider.family ??
          FamilyInfo(
            id: curId,
            name: 'Active Family',
            adminId: currentGoalProvider.currentUserId ?? 'admin',
            createdAt: DateTime.now(),
          );
      familiesMap[curId] = FamilyOverviewData(
        family: curFamily,
        members: currentGoalProvider.familyMembers,
        goals: currentGoalProvider.goals,
        globalInflation: currentGoalProvider.globalInflation,
        globalReturn: currentGoalProvider.globalReturn,
        referenceDate: currentGoalProvider.today,
      );
    }

    return familiesMap.values.toList();
  }
}
