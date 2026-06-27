class FamilyModel {
  final String id;
  final String ownerId;
  final String name;
  final DateTime createdAt;

  const FamilyModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.createdAt,
  });

  factory FamilyModel.fromMap(Map<String, dynamic> data) {
    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value;
      return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
    }

    return FamilyModel(
      id: data['id']?.toString() ?? '',
      ownerId:
          data['owner_id']?.toString() ?? data['ownerId']?.toString() ?? '',
      name: data['name']?.toString() ?? 'Моя семья',
      createdAt: parseDate(data['created_at'] ?? data['createdAt']),
    );
  }
}

class FamilyAccountMemberModel {
  final String id;
  final String familyId;
  final String userId;
  final String role;
  final String status;
  final String? invitedEmail;
  final String? email;
  final String displayName;
  final String? relation;
  final bool isDefault;
  final DateTime createdAt;

  const FamilyAccountMemberModel({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.role,
    required this.status,
    this.invitedEmail,
    this.email,
    required this.displayName,
    this.relation,
    required this.isDefault,
    required this.createdAt,
  });

  bool get isActive => status == 'active';
  bool get canManage => role == 'owner' || role == 'admin';

  factory FamilyAccountMemberModel.fromMap(Map<String, dynamic> data) {
    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value;
      return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
    }

    final email = data['email']?.toString();
    return FamilyAccountMemberModel(
      id: data['id']?.toString() ?? '',
      familyId:
          data['family_id']?.toString() ?? data['familyId']?.toString() ?? '',
      userId: data['user_id']?.toString() ?? data['userId']?.toString() ?? '',
      role: data['role']?.toString() ?? 'member',
      status: data['status']?.toString() ?? 'active',
      invitedEmail:
          data['invited_email']?.toString() ?? data['invitedEmail']?.toString(),
      email: email,
      displayName:
          (data['display_name']?.toString() ??
                  data['displayName']?.toString() ??
                  email ??
                  'Участник')
              .trim(),
      relation: data['relation']?.toString(),
      isDefault: data['is_default'] == true || data['isDefault'] == true,
      createdAt: parseDate(data['created_at'] ?? data['createdAt']),
    );
  }
}

class FamilyInviteModel {
  final String id;
  final String familyId;
  final String? familyName;
  final String token;
  final String? email;
  final String role;
  final String status;
  final String? invitedByName;
  final DateTime? expiresAt;

  const FamilyInviteModel({
    required this.id,
    required this.familyId,
    this.familyName,
    required this.token,
    this.email,
    required this.role,
    required this.status,
    this.invitedByName,
    this.expiresAt,
  });

  factory FamilyInviteModel.fromMap(Map<String, dynamic> data) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString());
    }

    return FamilyInviteModel(
      id: data['id']?.toString() ?? '',
      familyId:
          data['familyId']?.toString() ?? data['family_id']?.toString() ?? '',
      familyName:
          data['familyName']?.toString() ?? data['family_name']?.toString(),
      token: data['token']?.toString() ?? '',
      email: data['email']?.toString(),
      role: data['role']?.toString() ?? 'member',
      status: data['status']?.toString() ?? 'active',
      invitedByName:
          data['invitedByName']?.toString() ??
          data['invited_by_name']?.toString(),
      expiresAt: parseDate(data['expiresAt'] ?? data['expires_at']),
    );
  }
}
