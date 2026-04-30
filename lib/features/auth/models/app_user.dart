class AppUser {
  final String uid;
  final String email;
  final String role;
  final String? name;
  final String? companyName;
  final String? bin;
  final DateTime createdAt;
  final bool isDarkTheme;

  AppUser({
    required this.uid,
    required this.email,
    required this.role,
    this.name,
    this.companyName,
    this.bin,
    required this.createdAt,
    this.isDarkTheme = false,
  });

  AppUser copyWith({
    String? uid,
    String? email,
    String? role,
    String? name,
    String? companyName,
    String? bin,
    DateTime? createdAt,
    bool? isDarkTheme,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
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
      'uid': uid,
      'email': email,
      'role': role,
      'name': name,
      'companyName': companyName,
      'bin': bin,
      'createdAt': createdAt.toIso8601String(),
      'isDarkTheme': isDarkTheme,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'b2c',
      name: map['name'],
      companyName: map['companyName'],
      bin: map['bin'],
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      isDarkTheme: map['isDarkTheme'] ?? false,
    );
  }
}
