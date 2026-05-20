class B2BTeamMemberModel {
  final String id;
  final String organizationId;
  final String? userId;
  final String email;
  final String? name;
  final String role;
  final String status;
  final DateTime createdAt;
  final bool isCurrentUser;

  const B2BTeamMemberModel({
    required this.id,
    required this.organizationId,
    required this.userId,
    required this.email,
    required this.name,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.isCurrentUser,
  });

  bool get isPending => status == 'invited';
  bool get isDisabled => status == 'disabled';
  bool get isOwner => role == 'owner';

  String get displayName {
    final trimmedName = name?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) return trimmedName;
    return email.split('@').first;
  }

  String get initials {
    final source = displayName.trim();
    if (source.isEmpty) return 'SK';
    final parts =
        source.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return source.runes.take(2).map(String.fromCharCode).join().toUpperCase();
  }

  String get roleLabel {
    switch (role) {
      case 'owner':
        return 'Владелец';
      case 'admin':
        return 'Администратор';
      case 'pharmacist':
        return 'Фармацевт';
      case 'analyst':
        return 'Аналитик';
      default:
        return role;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'active':
        return 'Активен';
      case 'invited':
        return 'Приглашён';
      case 'disabled':
        return 'Отключён';
      default:
        return status;
    }
  }

  factory B2BTeamMemberModel.fromRows({
    required Map<String, dynamic> membership,
    required Map<String, dynamic>? profile,
    required String currentUserId,
  }) {
    final profileEmail = profile?['email']?.toString();
    final invitedEmail = membership['invited_email']?.toString();
    final userId = membership['user_id']?.toString();

    return B2BTeamMemberModel(
      id: membership['id']?.toString() ?? '',
      organizationId: membership['organization_id']?.toString() ?? '',
      userId: userId,
      email:
          (profileEmail != null && profileEmail.isNotEmpty)
              ? profileEmail
              : invitedEmail ?? '',
      name: profile?['name']?.toString(),
      role: membership['role']?.toString() ?? 'pharmacist',
      status: membership['status']?.toString() ?? 'active',
      createdAt:
          DateTime.tryParse(membership['created_at']?.toString() ?? '') ??
          DateTime.now(),
      isCurrentUser: userId == currentUserId,
    );
  }
}
