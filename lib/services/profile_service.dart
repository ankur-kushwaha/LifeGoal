import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../models/profile_model.dart';

abstract class BaseProfileService {
  Stream<FamilyProfile> streamFamilyProfile(String familyId);
  Future<void> saveFamilyProfile(String familyId, FamilyProfile profile);
  Future<void> saveMemberProfile(String familyId, String memberId, MemberProfile profile);
  Future<MemberProfile> getMemberProfile(String familyId, String memberId);
}

class FirestoreProfileService implements BaseProfileService {
  FirestoreProfileService()
      : _firestore = FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseId: kFirestoreDatabaseId,
        );

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _familyRef(String familyId) =>
      _firestore.collection('families').doc(familyId);

  @override
  Stream<FamilyProfile> streamFamilyProfile(String familyId) {
    return _familyRef(familyId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return const FamilyProfile();
      final data = doc.data()!;
      return FamilyProfile.fromJson(data['familyProfile'] as Map<String, dynamic>?);
    });
  }

  @override
  Future<void> saveFamilyProfile(String familyId, FamilyProfile profile) async {
    await _familyRef(familyId).set(
      {'familyProfile': profile.toJson()},
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> saveMemberProfile(
    String familyId,
    String memberId,
    MemberProfile profile,
  ) async {
    await _familyRef(familyId).collection('members').doc(memberId).set(
      {'memberProfile': profile.toJson()},
      SetOptions(merge: true),
    );
  }

  @override
  Future<MemberProfile> getMemberProfile(String familyId, String memberId) async {
    final doc = await _familyRef(familyId).collection('members').doc(memberId).get();
    if (!doc.exists || doc.data() == null) return const MemberProfile();
    return MemberProfile.fromJson(doc.data()!['memberProfile'] as Map<String, dynamic>?);
  }
}

class SharedPreferencesProfileService implements BaseProfileService {
  String _familyKey(String familyId) => 'familyProfile_$familyId';
  String _memberKey(String familyId, String memberId) =>
      'memberProfile_${familyId}_$memberId';

  final Map<String, StreamController<FamilyProfile>> _familyControllers = {};

  StreamController<FamilyProfile> _familyController(String familyId) {
    return _familyControllers.putIfAbsent(familyId, () {
      final controller = StreamController<FamilyProfile>.broadcast();
      _loadFamilyProfile(familyId).then(controller.add);
      return controller;
    });
  }

  Future<FamilyProfile> _loadFamilyProfile(String familyId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_familyKey(familyId));
    if (raw == null) return const FamilyProfile();
    try {
      return FamilyProfile.fromJson(json.decode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const FamilyProfile();
    }
  }

  Future<MemberProfile> _loadMemberProfile(String familyId, String memberId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_memberKey(familyId, memberId));
    if (raw == null) return const MemberProfile();
    try {
      return MemberProfile.fromJson(json.decode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const MemberProfile();
    }
  }

  @override
  Stream<FamilyProfile> streamFamilyProfile(String familyId) {
    return _familyController(familyId).stream;
  }

  @override
  Future<void> saveFamilyProfile(String familyId, FamilyProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_familyKey(familyId), json.encode(profile.toJson()));
    _familyController(familyId).add(profile);
  }

  @override
  Future<void> saveMemberProfile(
    String familyId,
    String memberId,
    MemberProfile profile,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _memberKey(familyId, memberId),
      json.encode(profile.toJson()),
    );
  }

  @override
  Future<MemberProfile> getMemberProfile(String familyId, String memberId) {
    return _loadMemberProfile(familyId, memberId);
  }
}

String buildFamilyProfileContextText({
  required FamilyProfile familyProfile,
  required List<({String name, MemberProfile profile})> members,
}) {
  final lines = <String>['=== Family financial profile ==='];

  if (familyProfile.monthlyHouseholdIncome != null) {
    lines.add('Household income: ₹${_formatInr(familyProfile.monthlyHouseholdIncome!)}');
  }
  if (familyProfile.monthlyHouseholdExpenses != null) {
    lines.add('Household expenses: ₹${_formatInr(familyProfile.monthlyHouseholdExpenses!)}');
  }
  if (familyProfile.totalMonthlyEmi > 0) {
    lines.add('Total loan EMI: ₹${_formatInr(familyProfile.totalMonthlyEmi)}');
  }
  final surplus = familyProfile.monthlySurplus;
  if (surplus != null) {
    lines.add('Estimated monthly surplus for goals: ₹${_formatInr(surplus)}');
  }
  final emergency = familyProfile.emergencyFundTarget;
  if (emergency != null) {
    lines.add(
      'Emergency fund target (${familyProfile.emergencyFundMonths} months): ₹${_formatInr(emergency)}',
    );
  }
  lines.add('Housing: ${familyProfile.housingStatus.label}');
  lines.add('Health insurance: ${familyProfile.hasHealthInsurance ? "yes" : "no"}');
  lines.add('Life insurance: ${familyProfile.hasLifeInsurance ? "yes" : "no"}');

  if (familyProfile.dependents.isNotEmpty) {
    lines.add('\nDependents:');
    for (final dep in familyProfile.dependents) {
      final age = dep.ageYears;
      lines.add(
        '- ${dep.name} (${dep.relationship.label}${age != null ? ", age $age" : ""})',
      );
    }
  }

  if (familyProfile.loans.isNotEmpty) {
    lines.add('\nLoans:');
    for (final loan in familyProfile.loans) {
      lines.add(
        '- ${loan.type.label}: EMI ₹${_formatInr(loan.emi)}, ${loan.remainingMonths} months left'
        '${loan.outstandingAmount != null ? ", outstanding ₹${_formatInr(loan.outstandingAmount!)}" : ""}',
      );
    }
  }

  if (members.isNotEmpty) {
    lines.add('\nMember profiles:');
    for (final member in members) {
      final p = member.profile;
      final parts = <String>[member.name];
      if (p.ageYears != null) parts.add('age ${p.ageYears}');
      if (p.monthlyIncome != null) parts.add('income ₹${_formatInr(p.monthlyIncome!)}');
      if (p.monthlyExpenses != null) parts.add('expenses ₹${_formatInr(p.monthlyExpenses!)}');
      parts.add(p.employmentType.label);
      parts.add('risk: ${p.riskAppetite.label}');
      parts.add('retire at ${p.retirementAge}');
      lines.add('- ${parts.join(", ")}');
    }
  }

  if (familyProfile.isEmpty && members.every((m) => m.profile.isEmpty)) {
    return 'Family profile not filled in yet.';
  }

  return lines.join('\n');
}

String _formatInr(double amount) {
  return amount.round().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{2})+(?!\d))'),
        (m) => '${m[1]},',
      );
}
