class ReminderModel {
  final String id;
  final String userId;
  final String medicineId;
  final String? familyMemberId;
  final String title;
  final String time; // HH:mm
  final bool isDaily;
  final bool enabled;
  final List<int> weekDays; // 1-7 если потом захочешь по дням
  final DateTime createdAt;

  ReminderModel({
    required this.id,
    required this.userId,
    required this.medicineId,
    this.familyMemberId,
    required this.title,
    required this.time,
    required this.isDaily,
    required this.enabled,
    required this.weekDays,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'medicine_id': medicineId,
      'family_member_id': familyMemberId,
      'title': title,
      'time': time,
      'is_daily': isDaily,
      'enabled': enabled,
      'week_days': weekDays,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ReminderModel.fromMap(Map<String, dynamic> data) {
    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value;
      return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
    }

    return ReminderModel(
      id: data['id'] ?? '',
      userId: data['user_id'] ?? data['userId'] ?? '',
      medicineId: data['medicine_id'] ?? data['medicineId'] ?? '',
      familyMemberId: data['family_member_id'] ?? data['familyMemberId'],
      title: data['title'] ?? '',
      time: data['time'] ?? '',
      isDaily: data['is_daily'] ?? data['isDaily'] ?? true,
      enabled: data['enabled'] ?? true,
      weekDays: List<int>.from(data['week_days'] ?? data['weekDays'] ?? []),
      createdAt: parseDate(data['created_at'] ?? data['createdAt']),
    );
  }

  ReminderModel copyWith({
    String? id,
    String? userId,
    String? medicineId,
    String? familyMemberId,
    String? title,
    String? time,
    bool? isDaily,
    bool? enabled,
    List<int>? weekDays,
    DateTime? createdAt,
  }) {
    return ReminderModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      medicineId: medicineId ?? this.medicineId,
      familyMemberId: familyMemberId ?? this.familyMemberId,
      title: title ?? this.title,
      time: time ?? this.time,
      isDaily: isDaily ?? this.isDaily,
      enabled: enabled ?? this.enabled,
      weekDays: weekDays ?? this.weekDays,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
