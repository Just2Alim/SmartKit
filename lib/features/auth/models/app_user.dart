class AppUser {
  final String id;
  final String email;
  final String role;
  final String? name;
  final String? companyName;
  final String? bin;
  final DateTime createdAt;
  final bool isDarkTheme;

  AppUser({
    required this.id,
    required this.email,
    required this.role,
    this.name,
    this.companyName,
    this.bin,
    required this.createdAt,
    this.isDarkTheme = false,
  });

  AppUser copyWith({
    String? id,
    String? email,
    String? role,
    String? name,
    String? companyName,
    String? bin,
    DateTime? createdAt,
    bool? isDarkTheme,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      role: role ?? this.role,
      name: name ?? this.name,
      companyName: companyName ?? this.companyName,
      bin: bin ?? this.bin,
      createdAt: createdAt ?? this.createdAt,
      isDarkTheme: isDarkTheme ?? this.isDarkTheme,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'legacy_uid': id,
      'email': email,
      'role': role,
      'name': name,
      'company_name': companyName,
      'companyName': companyName,
      'bin': bin,
      'created_at': createdAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'is_dark_theme': isDarkTheme,
      'isDarkTheme': isDarkTheme,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] ?? map['legacy_uid'] ?? map['uid'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'b2c',
      name: map['name'],
      companyName: map['company_name'] ?? map['companyName'],
      bin: map['bin'],
      createdAt:
          DateTime.tryParse(
            (map['created_at'] ?? map['createdAt'] ?? '').toString(),
          ) ??
          DateTime.now(),
      isDarkTheme: map['is_dark_theme'] ?? map['isDarkTheme'] ?? false,
    );
  }
}
