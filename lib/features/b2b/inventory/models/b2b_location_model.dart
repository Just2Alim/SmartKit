import 'package:cloud_firestore/cloud_firestore.dart';

class B2BLocationModel {
  final String id;
  final String userId;
  final String name;
  final String type; // 'Warehouse', 'Pharmacy', 'Storage'
  final String address;
  final int currentItems;
  final int capacity;
  final String status; // 'Active', 'Full', 'Maintenance'

  B2BLocationModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.address,
    required this.currentItems,
    required this.capacity,
    required this.status,
  });

  double get occupancyRate => capacity > 0 ? currentItems / capacity : 0;

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'type': type,
      'address': address,
      'currentItems': currentItems,
      'capacity': capacity,
      'status': status,
    };
  }

  factory B2BLocationModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return B2BLocationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      type: data['type'] ?? 'Storage',
      address: data['address'] ?? '',
      currentItems: data['currentItems'] ?? 0,
      capacity: data['capacity'] ?? 0,
      status: data['status'] ?? 'Active',
    );
  }
}
