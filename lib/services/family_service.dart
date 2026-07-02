import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../models/family_model.dart';

abstract class BaseFamilyService {
  Stream<FamilyInfo?> streamFamily(String familyId);
  Stream<List<FamilyMember>> streamMembers(String familyId);
  Stream<List<FamilyInvite>> streamPendingInvites(String familyId);
  Future<String?> getUserFamilyId(String userId);
  Future<void> ensureMembership({
    required String userId,
    required String email,
    String? displayName,
  });
  Future<void> inviteMember({
    required String familyId,
    required String invitedBy,
    required String email,
  });
  Future<void> removeMember({
    required String familyId,
    required String memberId,
    required String adminId,
  });
  Future<void> updateFamilyName({
    required String familyId,
    required String name,
    required String adminId,
  });
}

class FirestoreFamilyService implements BaseFamilyService {
  FirestoreFamilyService()
      : _firestore = FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseId: kFirestoreDatabaseId,
        );

  final FirebaseFirestore _firestore;

  @override
  Stream<FamilyInfo?> streamFamily(String familyId) {
    return _firestore.collection('families').doc(familyId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return FamilyInfo.fromJson(doc.id, doc.data()!);
    });
  }

  @override
  Stream<List<FamilyMember>> streamMembers(String familyId) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('members')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => FamilyMember.fromJson(doc.id, doc.data()))
          .toList()
        ..sort((a, b) => a.label.compareTo(b.label));
    });
  }

  @override
  Stream<List<FamilyInvite>> streamPendingInvites(String familyId) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('invites')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => FamilyInvite.fromJson(doc.id, doc.data()))
          .toList();
    });
  }

  @override
  Future<String?> getUserFamilyId(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return doc.data()?['familyId'] as String?;
  }

  @override
  Future<void> ensureMembership({
    required String userId,
    required String email,
    String? displayName,
  }) async {
    final normalizedEmail = normalizeEmail(email);
    final userRef = _firestore.collection('users').doc(userId);
    final userDoc = await userRef.get();

    if (userDoc.exists && userDoc.data()?['familyId'] != null) {
      await userRef.set({
        'email': normalizedEmail,
        if (displayName != null) 'displayName': displayName,
      }, SetOptions(merge: true));
      return;
    }

    final inviteRef = _firestore.collection('invites').doc(normalizedEmail);
    final inviteDoc = await inviteRef.get();

    if (inviteDoc.exists && inviteDoc.data()?['status'] == 'pending') {
      final familyId = inviteDoc.data()!['familyId'] as String;
      await _joinFamily(
        userId: userId,
        email: normalizedEmail,
        displayName: displayName,
        familyId: familyId,
        role: FamilyRole.member,
      );
      await inviteRef.set({'status': 'accepted'}, SetOptions(merge: true));
      await _migratePersonalGoalsToFamily(userId, familyId);
      return;
    }

    final familyId = _firestore.collection('families').doc().id;
    final batch = _firestore.batch();
    final now = DateTime.now().toIso8601String();

    batch.set(_firestore.collection('families').doc(familyId), {
      'name': '${_nameFromEmail(normalizedEmail)}\'s Family',
      'adminId': userId,
      'createdAt': now,
    });

    batch.set(
      _firestore.collection('families').doc(familyId).collection('members').doc(userId),
      FamilyMember(
        userId: userId,
        email: normalizedEmail,
        displayName: displayName,
        role: FamilyRole.admin,
        joinedAt: DateTime.parse(now),
      ).toJson(),
    );

    batch.set(userRef, {
      'familyId': familyId,
      'email': normalizedEmail,
      if (displayName != null) 'displayName': displayName,
    }, SetOptions(merge: true));

    await batch.commit();
    await _migratePersonalGoalsToFamily(userId, familyId);
  }

  @override
  Future<void> inviteMember({
    required String familyId,
    required String invitedBy,
    required String email,
  }) async {
    final normalizedEmail = normalizeEmail(email);
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      throw Exception('Please enter a valid email address.');
    }

    final members = await _firestore
        .collection('families')
        .doc(familyId)
        .collection('members')
        .get();

    final alreadyMember = members.docs.any(
      (doc) => normalizeEmail(doc.data()['email'] as String? ?? '') == normalizedEmail,
    );
    if (alreadyMember) {
      throw Exception('This person is already a family member.');
    }

    final now = DateTime.now().toIso8601String();
    final batch = _firestore.batch();

    batch.set(
      _firestore.collection('families').doc(familyId).collection('invites').doc(normalizedEmail),
      {
        'email': normalizedEmail,
        'familyId': familyId,
        'invitedBy': invitedBy,
        'createdAt': now,
        'status': 'pending',
      },
    );

    batch.set(
      _firestore.collection('invites').doc(normalizedEmail),
      {
        'email': normalizedEmail,
        'familyId': familyId,
        'invitedBy': invitedBy,
        'createdAt': now,
        'status': 'pending',
      },
    );

    await batch.commit();
  }

  @override
  Future<void> removeMember({
    required String familyId,
    required String memberId,
    required String adminId,
  }) async {
    final familyDoc = await _firestore.collection('families').doc(familyId).get();
    if (familyDoc.data()?['adminId'] != adminId) {
      throw Exception('Only the family admin can remove members.');
    }
    if (memberId == adminId) {
      throw Exception('The admin cannot be removed from the family.');
    }

    final batch = _firestore.batch();
    batch.delete(
      _firestore.collection('families').doc(familyId).collection('members').doc(memberId),
    );
    batch.set(
      _firestore.collection('users').doc(memberId),
      {'familyId': FieldValue.delete()},
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  @override
  Future<void> updateFamilyName({
    required String familyId,
    required String name,
    required String adminId,
  }) async {
    final familyDoc = await _firestore.collection('families').doc(familyId).get();
    if (familyDoc.data()?['adminId'] != adminId) {
      throw Exception('Only the family admin can rename the family.');
    }
    await _firestore.collection('families').doc(familyId).set(
      {'name': name.trim()},
      SetOptions(merge: true),
    );
  }

  Future<void> _joinFamily({
    required String userId,
    required String email,
    required String familyId,
    required FamilyRole role,
    String? displayName,
  }) async {
    final batch = _firestore.batch();
    batch.set(
      _firestore.collection('families').doc(familyId).collection('members').doc(userId),
      FamilyMember(
        userId: userId,
        email: email,
        displayName: displayName,
        role: role,
        joinedAt: DateTime.now(),
      ).toJson(),
    );
    batch.set(
      _firestore.collection('users').doc(userId),
      {
        'familyId': familyId,
        'email': email,
        if (displayName != null) 'displayName': displayName,
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> _migratePersonalGoalsToFamily(String userId, String familyId) async {
    final personalGoals = await _firestore
        .collection('users')
        .doc(userId)
        .collection('goals')
        .get();

    if (personalGoals.docs.isEmpty) return;

    final familyGoals = await _firestore
        .collection('families')
        .doc(familyId)
        .collection('goals')
        .get();

    if (familyGoals.docs.isNotEmpty) return;

    final batch = _firestore.batch();
    for (final doc in personalGoals.docs) {
      batch.set(
        _firestore.collection('families').doc(familyId).collection('goals').doc(doc.id),
        doc.data(),
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  String _nameFromEmail(String email) {
    final local = email.split('@').first;
    if (local.isEmpty) return 'Family';
    return local[0].toUpperCase() + local.substring(1);
  }
}

class LocalFamilyService implements BaseFamilyService {
  final Map<String, StreamController<FamilyInfo?>> _familyControllers = {};
  final Map<String, StreamController<List<FamilyMember>>> _memberControllers = {};
  final Map<String, StreamController<List<FamilyInvite>>> _inviteControllers = {};

  @override
  Stream<FamilyInfo?> streamFamily(String familyId) {
    final controller = _familyControllers.putIfAbsent(
      familyId,
      () => StreamController<FamilyInfo?>.broadcast(),
    );
    _loadFamilyJson(familyId).then((json) {
      if (json != null) {
        controller.add(FamilyInfo.fromJson(familyId, json));
      }
    });
    return controller.stream;
  }

  @override
  Stream<List<FamilyMember>> streamMembers(String familyId) {
    final controller = _memberControllers.putIfAbsent(
      familyId,
      () => StreamController<List<FamilyMember>>.broadcast(),
    );
    _loadMembers(familyId).then(controller.add);
    return controller.stream;
  }

  @override
  Stream<List<FamilyInvite>> streamPendingInvites(String familyId) {
    final controller = _inviteControllers.putIfAbsent(
      familyId,
      () => StreamController<List<FamilyInvite>>.broadcast(),
    );
    _loadInvites(familyId).then(controller.add);
    return controller.stream;
  }

  @override
  Future<String?> getUserFamilyId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('familyId_$userId');
  }

  @override
  Future<void> ensureMembership({
    required String userId,
    required String email,
    String? displayName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final existingFamilyId = prefs.getString('familyId_$userId');
    if (existingFamilyId != null) {
      await prefs.setString('userEmail_$userId', normalizeEmail(email));
      return;
    }

    final normalizedEmail = normalizeEmail(email);
    final inviteKey = 'invite_$normalizedEmail';
    final inviteJson = prefs.getString(inviteKey);

    String familyId;
    FamilyRole role;

    if (inviteJson != null) {
      final invite = json.decode(inviteJson) as Map<String, dynamic>;
      familyId = invite['familyId'] as String;
      role = FamilyRole.member;
      await prefs.remove(inviteKey);
    } else {
      familyId = 'local_family_$userId';
      role = FamilyRole.admin;
      final family = FamilyInfo(
        id: familyId,
        name: '${_nameFromEmail(normalizedEmail)}\'s Family',
        adminId: userId,
        createdAt: DateTime.now(),
      );
      await prefs.setString('family_$familyId', json.encode(family.toJson()));
      _familyControllers[familyId]?.add(family);
    }

    final member = FamilyMember(
      userId: userId,
      email: normalizedEmail,
      displayName: displayName,
      role: role,
      joinedAt: DateTime.now(),
    );

    final members = await _loadMembers(familyId);
    members.add(member);
    await _saveMembers(familyId, members);
    await prefs.setString('familyId_$userId', familyId);
    await prefs.setString('userEmail_$userId', normalizedEmail);
  }

  @override
  Future<void> inviteMember({
    required String familyId,
    required String invitedBy,
    required String email,
  }) async {
    final normalizedEmail = normalizeEmail(email);
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      throw Exception('Please enter a valid email address.');
    }

    final members = await _loadMembers(familyId);
    if (members.any((m) => normalizeEmail(m.email) == normalizedEmail)) {
      throw Exception('This person is already a family member.');
    }

    final invite = FamilyInvite(
      id: normalizedEmail,
      email: normalizedEmail,
      familyId: familyId,
      invitedBy: invitedBy,
      createdAt: DateTime.now(),
      status: InviteStatus.pending,
    );

    final invites = await _loadInvites(familyId);
    invites.removeWhere((i) => normalizeEmail(i.email) == normalizedEmail);
    invites.add(invite);
    await _saveInvites(familyId, invites);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('invite_$normalizedEmail', json.encode({
      'familyId': familyId,
      'invitedBy': invitedBy,
      'status': 'pending',
    }));
  }

  @override
  Future<void> removeMember({
    required String familyId,
    required String memberId,
    required String adminId,
  }) async {
    final familyJson = await _loadFamilyJson(familyId);
    if (familyJson == null || familyJson['adminId'] != adminId) {
      throw Exception('Only the family admin can remove members.');
    }
    if (memberId == adminId) {
      throw Exception('The admin cannot be removed from the family.');
    }

    final members = await _loadMembers(familyId);
    members.removeWhere((m) => m.userId == memberId);
    await _saveMembers(familyId, members);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('familyId_$memberId');
  }

  @override
  Future<void> updateFamilyName({
    required String familyId,
    required String name,
    required String adminId,
  }) async {
    final familyJson = await _loadFamilyJson(familyId);
    if (familyJson == null || familyJson['adminId'] != adminId) {
      throw Exception('Only the family admin can rename the family.');
    }
    familyJson['name'] = name.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('family_$familyId', json.encode(familyJson));
    _familyControllers[familyId]?.add(FamilyInfo.fromJson(familyId, familyJson));
  }

  Future<Map<String, dynamic>?> _loadFamilyJson(String familyId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('family_$familyId');
    if (jsonStr == null) return null;
    return json.decode(jsonStr) as Map<String, dynamic>;
  }

  Future<List<FamilyMember>> _loadMembers(String familyId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('familyMembers_$familyId');
    if (jsonStr == null) return [];
    final list = json.decode(jsonStr) as List;
    return list
        .map((item) => FamilyMember.fromJson(
              item['userId'] as String,
              item as Map<String, dynamic>,
            ))
        .toList();
  }

  Future<void> _saveMembers(String familyId, List<FamilyMember> members) async {
    final prefs = await SharedPreferences.getInstance();
    final data = members.map((m) => {...m.toJson(), 'userId': m.userId}).toList();
    await prefs.setString('familyMembers_$familyId', json.encode(data));
    _memberControllers[familyId]?.add(members);
  }

  Future<List<FamilyInvite>> _loadInvites(String familyId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('familyInvites_$familyId');
    if (jsonStr == null) return [];
    final list = json.decode(jsonStr) as List;
    return list
        .map((item) => FamilyInvite.fromJson(
              item['id'] as String,
              item as Map<String, dynamic>,
            ))
        .toList();
  }

  Future<void> _saveInvites(String familyId, List<FamilyInvite> invites) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = invites.where((i) => i.status == InviteStatus.pending).toList();
    final data = pending.map((i) => {...i.toJson(), 'id': i.id}).toList();
    await prefs.setString('familyInvites_$familyId', json.encode(data));
    _inviteControllers[familyId]?.add(pending);
  }

  String _nameFromEmail(String email) {
    final local = email.split('@').first;
    if (local.isEmpty) return 'Family';
    return local[0].toUpperCase() + local.substring(1);
  }
}
