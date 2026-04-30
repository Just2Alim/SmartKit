import 'package:cloud_firestore/cloud_firestore.dart';

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
      'userId': userId,
      'medicineId': medicineId,
      'familyMemberId': familyMemberId,
      'title': title,
      'time': time,
      'isDaily': isDaily,
      'enabled': enabled,
      'weekDays': weekDays,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ReminderModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ReminderModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      medicineId: data['medicineId'] ?? '',
      familyMemberId: data['familyMemberId'],
      title: data['title'] ?? '',
      time: data['time'] ?? '',
      isDaily: data['isDaily'] ?? true,
      enabled: data['enabled'] ?? true,
      weekDays: List<int>.from(data['weekDays'] ?? []),
      createdAt:
          data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
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
