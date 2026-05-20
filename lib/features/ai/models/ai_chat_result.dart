import '../../shop/utils/shop_product_mapper.dart';

class AiSourceReference {
  final String name;
  final String url;
  final String type;
  final String? summary;

  const AiSourceReference({
    required this.name,
    required this.url,
    required this.type,
    this.summary,
  });

  factory AiSourceReference.fromMap(Map<String, dynamic> data) {
    return AiSourceReference(
      name: data['name']?.toString() ?? 'Источник',
      url: data['url']?.toString() ?? '',
      type: data['type']?.toString() ?? 'reference',
      summary: data['summary']?.toString(),
    );
  }
}

class AiProductSuggestion {
  final String id;
  final String organizationId;
  final String title;
  final String subtitle;
  final String category;
  final String? description;
  final String? manufacturer;
  final String? dosage;
  final String? packageSize;
  final int stock;
  final int maxStock;
  final int priceValue;
  final String price;
  final String? expiryDate;
  final Map<String, dynamic> b2bItem;

  const AiProductSuggestion({
    required this.id,
    required this.organizationId,
    required this.title,
    required this.subtitle,
    required this.category,
    this.description,
    this.manufacturer,
    this.dosage,
    this.packageSize,
    required this.stock,
    required this.maxStock,
    required this.priceValue,
    required this.price,
    this.expiryDate,
    required this.b2bItem,
  });

  factory AiProductSuggestion.fromMap(Map<String, dynamic> data) {
    final b2bItem = Map<String, dynamic>.from(
      (data['b2b_item'] as Map?) ?? const <String, dynamic>{},
    );
    final category =
        data['category']?.toString() ?? b2bItem['category']?.toString() ?? '';
    final priceValue =
        (data['priceValue'] as num?)?.toInt() ??
        (b2bItem['price'] as num?)?.toInt() ??
        0;

    return AiProductSuggestion(
      id: data['id']?.toString() ?? b2bItem['id']?.toString() ?? '',
      organizationId:
          data['organizationId']?.toString() ??
          b2bItem['userId']?.toString() ??
          b2bItem['organization_id']?.toString() ??
          '',
      title: data['title']?.toString() ?? b2bItem['name']?.toString() ?? '',
      subtitle:
          data['subtitle']?.toString() ??
          [
            category,
            if ((data['dosage'] ?? b2bItem['dosage']) != null)
              (data['dosage'] ?? b2bItem['dosage']).toString(),
            if ((data['packageSize'] ?? b2bItem['packageSize']) != null)
              (data['packageSize'] ?? b2bItem['packageSize']).toString(),
          ].where((part) => part.trim().isNotEmpty).join(' • '),
      category: category,
      description:
          data['description']?.toString() ?? b2bItem['description']?.toString(),
      manufacturer:
          data['manufacturer']?.toString() ??
          b2bItem['manufacturer']?.toString(),
      dosage: data['dosage']?.toString() ?? b2bItem['dosage']?.toString(),
      packageSize:
          data['packageSize']?.toString() ?? b2bItem['packageSize']?.toString(),
      stock:
          (data['stock'] as num?)?.toInt() ??
          (b2bItem['stock'] as num?)?.toInt() ??
          0,
      maxStock:
          (data['maxStock'] as num?)?.toInt() ??
          (data['stock'] as num?)?.toInt() ??
          (b2bItem['stock'] as num?)?.toInt() ??
          0,
      priceValue: priceValue,
      price:
          data['price']?.toString() ??
          ShopProductMapper.formatPrice(priceValue),
      expiryDate:
          data['expiryDate']?.toString() ?? b2bItem['expiryDate']?.toString(),
      b2bItem: b2bItem,
    );
  }

  Map<String, dynamic> toCartProduct() {
    final color = ShopProductMapper.categoryColor(category);
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'price': price,
      'icon': ShopProductMapper.categoryIcon(category),
      'color': color.withValues(alpha: 0.12),
      'iconColor': color,
      'description': description,
      'manufacturer': manufacturer,
      'dosage': dosage,
      'packageSize': packageSize,
      'stock': stock,
      'maxStock': maxStock,
      'expiryDate': expiryDate,
      'b2b_item': {
        ...b2bItem,
        'id': id,
        'userId': organizationId,
        'name': title,
        'category': category,
        'description': description,
        'manufacturer': manufacturer,
        'dosage': dosage,
        'packageSize': packageSize,
        'stock': stock,
        'price': priceValue,
        'expiryDate': expiryDate,
      },
    };
  }
}

class AiChatResult {
  final String message;
  final String? threadId;
  final List<AiProductSuggestion> productSuggestions;
  final List<AiSourceReference> sources;

  const AiChatResult({
    required this.message,
    this.threadId,
    this.productSuggestions = const [],
    this.sources = const [],
  });

  factory AiChatResult.fromMap(Map<String, dynamic> data) {
    List<T> parseList<T>(
      Object? value,
      T Function(Map<String, dynamic>) parser,
    ) {
      if (value is! List) return const [];
      return value
          .whereType<Map>()
          .map((item) => parser(Map<String, dynamic>.from(item)))
          .toList();
    }

    return AiChatResult(
      message: data['message']?.toString() ?? '',
      threadId: data['threadId']?.toString(),
      productSuggestions: parseList(
        data['productSuggestions'],
        AiProductSuggestion.fromMap,
      ),
      sources: parseList(data['sources'], AiSourceReference.fromMap),
    );
  }

  AiChatResult copyWith({
    String? message,
    String? threadId,
    List<AiProductSuggestion>? productSuggestions,
    List<AiSourceReference>? sources,
  }) {
    return AiChatResult(
      message: message ?? this.message,
      threadId: threadId ?? this.threadId,
      productSuggestions: productSuggestions ?? this.productSuggestions,
      sources: sources ?? this.sources,
    );
  }
}
