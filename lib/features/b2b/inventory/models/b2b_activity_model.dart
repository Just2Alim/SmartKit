enum B2BActivityType {
  sale,
  stockUpdate,
  stockReceipt,
  itemAdded,
  itemUpdated,
  locationCreated,
  locationUpdated,
}

class B2BActivityModel {
  final String id;
  final String userId;
  final B2BActivityType type;
  final String title;
  final String description;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  B2BActivityModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.description,
    required this.timestamp,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'organization_id': userId,
      'type': type.name,
      'title': title,
      'description': description,
      'created_at': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory B2BActivityModel.fromMap(Map<String, dynamic> data) {
    return B2BActivityModel(
      id: data['id'] ?? '',
      userId: data['organization_id'] ?? data['userId'] ?? '',
      type: B2BActivityType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => B2BActivityType.sale,
      ),
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      timestamp:
          data['created_at'] != null
              ? DateTime.parse(data['created_at'])
              : data['timestamp'] != null
              ? DateTime.parse(data['timestamp'])
              : DateTime.now(),
      metadata:
          data['metadata'] == null
              ? null
              : Map<String, dynamic>.from(data['metadata']),
    );
  }
}
