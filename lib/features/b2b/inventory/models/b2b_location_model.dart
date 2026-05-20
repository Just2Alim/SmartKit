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
      'organization_id': userId,
      'name': name,
      'type': type,
      'address': address,
      'current_items': currentItems,
      'capacity': capacity,
      'status': status,
    };
  }

  factory B2BLocationModel.fromMap(Map<String, dynamic> data) {
    return B2BLocationModel(
      id: data['id'] ?? '',
      userId: data['organization_id'] ?? data['userId'] ?? '',
      name: data['name'] ?? '',
      type: data['type'] ?? 'Storage',
      address: data['address'] ?? '',
      currentItems:
          (data['current_items'] as num?)?.toInt() ??
          (data['currentItems'] as num?)?.toInt() ??
          0,
      capacity: (data['capacity'] as num?)?.toInt() ?? 0,
      status: data['status'] ?? 'Active',
    );
  }
}
