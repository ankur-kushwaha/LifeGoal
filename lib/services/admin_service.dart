import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../firebase_options.dart';
import '../models/admin_config_model.dart';
import '../models/family_model.dart';
import '../models/goal_model.dart';
import '../models/profile_model.dart';
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
    String? pin,
  }) async {
    final Map<String, FamilyOverviewData> familiesMap = {};

    // 1. First attempt fetching via Cloud Function getAllFamiliesAdmin (fastest & superadmin bypass)
    if (DefaultFirebaseOptions.isConfigured) {
      try {
        final functions = FirebaseFunctions.instanceFor(
          app: Firebase.app(),
          region: 'asia-south1',
        );
        final callable = functions.httpsCallable(
          'getAllFamiliesAdmin',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
        );
        final res = await callable.call<Map<String, dynamic>>({
          'pin': ?pin,
        });
        final data = Map<String, dynamic>.from(res.data);
        final list = data['families'] as List?;
        if (list != null && list.isNotEmpty) {
          for (final item in list) {
            final fMap = Map<String, dynamic>.from(item as Map);
            final famInfoMap = Map<String, dynamic>.from(fMap['family'] as Map);
            final famId = famInfoMap['id'] as String;
            final famInfo = FamilyInfo.fromJson(famId, famInfoMap);

            final membersList = (fMap['members'] as List?)
                    ?.map((m) => FamilyMember.fromJson(
                        m['userId'] as String? ?? 'user',
                        Map<String, dynamic>.from(m as Map)))
                    .toList() ??
                [];

            final goalsList = (fMap['goals'] as List?)
                    ?.map((g) =>
                        GoalModel.fromJson(Map<String, dynamic>.from(g as Map)))
                    .toList() ??
                [];

            final inflation =
                (fMap['globalInflation'] as num?)?.toDouble() ?? 6.0;
            final returns = (fMap['globalReturn'] as num?)?.toDouble() ?? 14.0;
            DateTime refDate = DateTime(2026, 7, 1);
            if (fMap['today'] is String) {
              try {
                refDate = DateTime.parse(fMap['today'] as String);
              } catch (_) {}
            }

            familiesMap[famId] = FamilyOverviewData(
              family: famInfo,
              members: membersList,
              goals: goalsList,
              globalInflation: inflation,
              globalReturn: returns,
              referenceDate: refDate,
            );
          }
        }
      } catch (e) {
        debugPrint('Cloud Function getAllFamiliesAdmin exception: $e');
      }
    }

    // 2. Fallback to direct Firestore collection scan if Cloud Function was unavailable
    if (familiesMap.isEmpty && DefaultFirebaseOptions.isConfigured) {
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
        debugPrint('Direct Cloud families query exception: $e');
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

  /// Deletes a family and all its members and goals as Super Admin.
  Future<void> deleteFamily(String familyId, {String? pin}) async {
    bool deletedInCloud = false;

    // 1. Try recursive delete via Cloud Function
    if (DefaultFirebaseOptions.isConfigured) {
      try {
        final functions = FirebaseFunctions.instanceFor(
          app: Firebase.app(),
          region: 'asia-south1',
        );
        final callable = functions.httpsCallable(
          'deleteFamilyAdmin',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 25)),
        );
        final res = await callable.call<Map<String, dynamic>>({
          'familyId': familyId,
          'pin': ?pin,
        });
        final data = Map<String, dynamic>.from(res.data);
        if (data['success'] == true) {
          deletedInCloud = true;
        }
      } catch (e) {
        debugPrint('Cloud Function deleteFamilyAdmin exception: $e');
      }
    }

    // 2. Direct Firestore fallback if Cloud Function didn't execute
    if (!deletedInCloud && DefaultFirebaseOptions.isConfigured) {
      try {
        final firestore = FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseId: kFirestoreDatabaseId,
        );

        final famRef = firestore.collection('families').doc(familyId);

        // Delete members
        final membersSnap = await famRef.collection('members').get();
        for (final doc in membersSnap.docs) {
          await doc.reference.delete();
        }

        // Delete goals
        final goalsSnap = await famRef.collection('goals').get();
        for (final doc in goalsSnap.docs) {
          await doc.reference.delete();
        }

        // Delete invites
        final invitesSnap = await famRef.collection('invites').get();
        for (final doc in invitesSnap.docs) {
          await doc.reference.delete();
        }

        // Delete notifications
        final notifsSnap = await famRef.collection('notifications').get();
        for (final doc in notifsSnap.docs) {
          await doc.reference.delete();
        }

        await famRef.delete();
      } catch (e) {
        debugPrint('Direct Firestore family delete exception: $e');
      }
    }

    // 3. Clear local SharedPreferences entries for this family
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('family_$familyId');
      await prefs.remove('members_$familyId');
      await prefs.remove('goalsList_$familyId');
      await prefs.remove('family_profile_$familyId');
      await prefs.remove('settings_$familyId');
    } catch (e) {
      debugPrint('Local family cleanup exception: $e');
    }
  }

  /// Adds a member to a family as Super Admin
  Future<FamilyMember> addMemberToFamily(
    String familyId, {
    required String email,
    String? displayName,
    FamilyRole role = FamilyRole.member,
    MemberProfile memberProfile = const MemberProfile(),
    bool makePrimaryAdmin = false,
    String? pin,
  }) async {
    final normEmail = email.trim().toLowerCase();

    // 1. Try via Cloud Function manageFamilyMemberAdmin
    if (DefaultFirebaseOptions.isConfigured) {
      try {
        final functions = FirebaseFunctions.instanceFor(
          app: Firebase.app(),
          region: 'asia-south1',
        );
        final callable = functions.httpsCallable(
          'manageFamilyMemberAdmin',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
        );
        final res = await callable.call<Map<String, dynamic>>({
          'action': 'add',
          'familyId': familyId,
          'email': normEmail,
          'displayName': ?displayName,
          'role': role.name,
          'memberProfile': memberProfile.toJson(),
          'makePrimaryAdmin': makePrimaryAdmin,
          'pin': ?pin,
        });
        final data = Map<String, dynamic>.from(res.data);
        if (data['success'] == true && data['member'] != null) {
          final mData = Map<String, dynamic>.from(data['member'] as Map);
          return FamilyMember.fromJson(mData['userId'] as String? ?? 'user', mData);
        }
      } catch (e) {
        debugPrint('Cloud Function manageFamilyMemberAdmin (add) exception: $e');
      }
    }

    // 2. Direct Firestore fallback
    String userId = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now();
    if (DefaultFirebaseOptions.isConfigured) {
      try {
        final firestore = FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseId: kFirestoreDatabaseId,
        );
        final userDocRef = firestore.collection('users').doc();
        userId = userDocRef.id;

        final newMember = FamilyMember(
          userId: userId,
          email: normEmail,
          displayName: displayName,
          role: role,
          joinedAt: now,
          memberProfile: memberProfile,
        );

        final batch = firestore.batch();
        batch.set(
          firestore.collection('families').doc(familyId).collection('members').doc(userId),
          newMember.toJson(),
        );
        batch.set(userDocRef, {
          'familyId': familyId,
          'email': normEmail,
          'displayName': ?displayName,
        }, SetOptions(merge: true));

        if (makePrimaryAdmin) {
          batch.update(firestore.collection('families').doc(familyId), {'adminId': userId});
        }

        await batch.commit();
        return newMember;
      } catch (e) {
        debugPrint('Direct Firestore addMember exception: $e');
      }
    }

    // 3. Local SharedPreferences fallback
    final newMember = FamilyMember(
      userId: userId,
      email: normEmail,
      displayName: displayName,
      role: role,
      joinedAt: now,
      memberProfile: memberProfile,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'members_$familyId';
      final jsonStr = prefs.getString(key);
      List<dynamic> list = [];
      if (jsonStr != null) {
        list = json.decode(jsonStr) as List;
      }
      list.add({'userId': userId, ...newMember.toJson()});
      await prefs.setString(key, json.encode(list));
    } catch (_) {}

    return newMember;
  }

  /// Updates a family member as Super Admin
  Future<FamilyMember> updateFamilyMember(
    String familyId,
    String memberId, {
    String? displayName,
    FamilyRole? role,
    MemberProfile? memberProfile,
    bool makePrimaryAdmin = false,
    String? pin,
  }) async {
    // 1. Try Cloud Function
    if (DefaultFirebaseOptions.isConfigured) {
      try {
        final functions = FirebaseFunctions.instanceFor(
          app: Firebase.app(),
          region: 'asia-south1',
        );
        final callable = functions.httpsCallable(
          'manageFamilyMemberAdmin',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
        );
        final res = await callable.call<Map<String, dynamic>>({
          'action': 'update',
          'familyId': familyId,
          'memberId': memberId,
          'displayName': ?displayName,
          if (role != null) 'role': role.name,
          if (memberProfile != null) 'memberProfile': memberProfile.toJson(),
          'makePrimaryAdmin': makePrimaryAdmin,
          'pin': ?pin,
        });
        final data = Map<String, dynamic>.from(res.data);
        if (data['success'] == true && data['member'] != null) {
          final mData = Map<String, dynamic>.from(data['member'] as Map);
          return FamilyMember.fromJson(memberId, mData);
        }
      } catch (e) {
        debugPrint('Cloud Function manageFamilyMemberAdmin (update) exception: $e');
      }
    }

    // 2. Direct Firestore fallback
    if (DefaultFirebaseOptions.isConfigured) {
      try {
        final firestore = FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseId: kFirestoreDatabaseId,
        );
        final memberRef = firestore
            .collection('families')
            .doc(familyId)
            .collection('members')
            .doc(memberId);

        final updateData = <String, dynamic>{
          'displayName': ?displayName,
          if (role != null) 'role': role.name,
          if (memberProfile != null) 'memberProfile': memberProfile.toJson(),
        };

        final batch = firestore.batch();
        batch.set(memberRef, updateData, SetOptions(merge: true));
        if (makePrimaryAdmin) {
          batch.update(firestore.collection('families').doc(familyId), {'adminId': memberId});
        }
        await batch.commit();

        final snap = await memberRef.get();
        if (snap.exists) {
          return FamilyMember.fromJson(memberId, snap.data()!);
        }
      } catch (e) {
        debugPrint('Direct Firestore updateMember exception: $e');
      }
    }

    return FamilyMember(
      userId: memberId,
      email: '',
      displayName: displayName,
      role: role ?? FamilyRole.member,
      joinedAt: DateTime.now(),
      memberProfile: memberProfile ?? const MemberProfile(),
    );
  }

  /// Removes a member from a family as Super Admin
  Future<void> removeMemberFromFamily(
    String familyId,
    String memberId, {
    String? newAdminId,
    String? pin,
  }) async {
    // 1. Try Cloud Function
    if (DefaultFirebaseOptions.isConfigured) {
      try {
        final functions = FirebaseFunctions.instanceFor(
          app: Firebase.app(),
          region: 'asia-south1',
        );
        final callable = functions.httpsCallable(
          'manageFamilyMemberAdmin',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
        );
        final res = await callable.call<Map<String, dynamic>>({
          'action': 'remove',
          'familyId': familyId,
          'memberId': memberId,
          'newAdminId': ?newAdminId,
          'pin': ?pin,
        });
        final data = Map<String, dynamic>.from(res.data);
        if (data['success'] == true) {
          return;
        }
      } catch (e) {
        debugPrint('Cloud Function manageFamilyMemberAdmin (remove) exception: $e');
      }
    }

    // 2. Direct Firestore fallback
    if (DefaultFirebaseOptions.isConfigured) {
      try {
        final firestore = FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseId: kFirestoreDatabaseId,
        );
        final batch = firestore.batch();
        batch.delete(
          firestore.collection('families').doc(familyId).collection('members').doc(memberId),
        );
        batch.set(
          firestore.collection('users').doc(memberId),
          {'familyId': FieldValue.delete()},
          SetOptions(merge: true),
        );
        if (newAdminId != null) {
          batch.update(firestore.collection('families').doc(familyId), {'adminId': newAdminId});
        }
        await batch.commit();
      } catch (e) {
        debugPrint('Direct Firestore removeMember exception: $e');
      }
    }

    // 3. Local storage cleanup
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'members_$familyId';
      final jsonStr = prefs.getString(key);
      if (jsonStr != null) {
        final list = json.decode(jsonStr) as List;
        list.removeWhere((item) => (item as Map)['userId'] == memberId);
        await prefs.setString(key, json.encode(list));
      }
    } catch (_) {}
  }
}
