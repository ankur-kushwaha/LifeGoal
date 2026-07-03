import 'profile_model.dart';

class FamilyMember {
  final String userId;
  final String email;
  final String? displayName;
  final FamilyRole role;
  final DateTime joinedAt;
  final MemberProfile memberProfile;

  const FamilyMember({
    required this.userId,
    required this.email,
    this.displayName,
    required this.role,
    required this.joinedAt,
    this.memberProfile = const MemberProfile(),
  });

  bool get isAdmin => role == FamilyRole.admin;

  String get label => displayName?.trim().isNotEmpty == true ? displayName!.trim() : _nameFromEmail(email);

  bool matchesAccount(String account) {
    final value = account.trim().toLowerCase();
    if (value.isEmpty) return false;
    if (label.toLowerCase() == value) return true;
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty && name.toLowerCase() == value) return true;
    final emailLocal = email.split('@').first.toLowerCase();
    if (emailLocal == value) return true;
    final firstName = label.split(RegExp(r'\s+')).first.toLowerCase();
    if (firstName == value) return true;
    return false;
  }

  factory FamilyMember.fromJson(String userId, Map<String, dynamic> json) {
    return FamilyMember(
      userId: userId,
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String?,
      role: FamilyRole.fromString(json['role'] as String? ?? 'member'),
      joinedAt: _parseDate(json['joinedAt']),
      memberProfile: MemberProfile.fromJson(
        json['memberProfile'] as Map<String, dynamic>?,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'email': email,
        if (displayName != null) 'displayName': displayName,
        'role': role.name,
        'joinedAt': joinedAt.toIso8601String(),
        if (!memberProfile.isEmpty) 'memberProfile': memberProfile.toJson(),
      };

  FamilyMember copyWith({MemberProfile? memberProfile}) {
    return FamilyMember(
      userId: userId,
      email: email,
      displayName: displayName,
      role: role,
      joinedAt: joinedAt,
      memberProfile: memberProfile ?? this.memberProfile,
    );
  }

  static String _nameFromEmail(String email) {
    final local = email.split('@').first;
    if (local.isEmpty) return email;
    return local[0].toUpperCase() + local.substring(1);
  }

  static DateTime _parseDate(dynamic value) {
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }
}

enum FamilyRole {
  admin,
  member;

  static FamilyRole fromString(String value) {
    return value == 'admin' ? FamilyRole.admin : FamilyRole.member;
  }
}

class FamilyInvite {
  final String id;
  final String email;
  final String familyId;
  final String invitedBy;
  final DateTime createdAt;
  final InviteStatus status;

  const FamilyInvite({
    required this.id,
    required this.email,
    required this.familyId,
    required this.invitedBy,
    required this.createdAt,
    required this.status,
  });

  factory FamilyInvite.fromJson(String id, Map<String, dynamic> json) {
    return FamilyInvite(
      id: id,
      email: json['email'] as String? ?? '',
      familyId: json['familyId'] as String? ?? '',
      invitedBy: json['invitedBy'] as String? ?? '',
      createdAt: FamilyMember._parseDate(json['createdAt']),
      status: InviteStatus.fromString(json['status'] as String? ?? 'pending'),
    );
  }

  Map<String, dynamic> toJson() => {
        'email': email,
        'familyId': familyId,
        'invitedBy': invitedBy,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
      };
}

enum InviteStatus {
  pending,
  accepted,
  declined;

  static InviteStatus fromString(String value) {
    switch (value) {
      case 'accepted':
        return InviteStatus.accepted;
      case 'declined':
        return InviteStatus.declined;
      default:
        return InviteStatus.pending;
    }
  }
}

class FamilyInfo {
  final String id;
  final String name;
  final String adminId;
  final DateTime createdAt;

  const FamilyInfo({
    required this.id,
    required this.name,
    required this.adminId,
    required this.createdAt,
  });

  factory FamilyInfo.fromJson(String id, Map<String, dynamic> json) {
    return FamilyInfo(
      id: id,
      name: json['name'] as String? ?? 'My Family',
      adminId: json['adminId'] as String? ?? '',
      createdAt: FamilyMember._parseDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'adminId': adminId,
        'createdAt': createdAt.toIso8601String(),
      };
}

String normalizeEmail(String email) => email.trim().toLowerCase();
