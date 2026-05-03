import 'package:flutter/material.dart';

import '../../b2b/inventory/models/b2b_inventory_model.dart';

class ShopProductMapper {
  static String formatPrice(int value) {
    final text = value.toString();
    final buffer = StringBuffer();
    var counter = 0;

    for (var i = text.length - 1; i >= 0; i--) {
      buffer.write(text[i]);
      counter++;
      if (counter % 3 == 0 && i != 0) {
        buffer.write(' ');
      }
    }

    return '${buffer.toString().split('').reversed.join()} ₸';
  }

  static Color categoryColor(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('витамин')) {
      return const Color(0xFFF59E0B);
    }
    if (lower.contains('антибиот')) {
      return const Color(0xFFEF4444);
    }
    if (lower.contains('жкт') || lower.contains('сорб')) {
      return const Color(0xFF3B82F6);
    }
    if (lower.contains('аллер')) {
      return const Color(0xFF8B5CF6);
    }
    if (lower.contains('антисеп')) {
      return const Color(0xFF06B6D4);
    }
    if (lower.contains('серд')) {
      return const Color(0xFFEF4444);
    }
    if (lower.contains('насморк') || lower.contains('дых')) {
      return const Color(0xFF0EA5E9);
    }
    if (lower.contains('дермат')) {
      return const Color(0xFF14B8A6);
    }
    return const Color(0xFF10B981);
  }

  static IconData categoryIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('витамин')) {
      return Icons.bolt_rounded;
    }
    if (lower.contains('антисеп')) {
      return Icons.sanitizer_rounded;
    }
    if (lower.contains('аллер')) {
      return Icons.air_rounded;
    }
    if (lower.contains('жкт') || lower.contains('сорб')) {
      return Icons.spa_rounded;
    }
    if (lower.contains('серд')) {
      return Icons.favorite_rounded;
    }
    if (lower.contains('каш') || lower.contains('горло')) {
      return Icons.record_voice_over_rounded;
    }
    if (lower.contains('насморк') || lower.contains('дых')) {
      return Icons.air_rounded;
    }
    return Icons.medication_rounded;
  }

  static Map<String, dynamic> toProductMap(B2BInventoryModel product) {
    final color = categoryColor(product.category);
    final subtitle = [
      product.category,
      if ((product.dosage ?? '').trim().isNotEmpty) product.dosage!,
      if ((product.packageSize ?? '').trim().isNotEmpty) product.packageSize!,
    ].join(' • ');

    return {
      'id': product.id,
      'title': product.name,
      'subtitle': subtitle,
      'price': formatPrice(product.price),
      'icon': categoryIcon(product.category),
      'color': color.withValues(alpha: 0.12),
      'iconColor': color,
      'description': product.description,
      'manufacturer': product.manufacturer,
      'dosage': product.dosage,
      'packageSize': product.packageSize,
      'stock': product.stock,
      'maxStock': product.stock,
      'expiryDate': product.expiryDate?.toIso8601String(),
      'b2b_item': {
        'id': product.id,
        'userId': product.userId,
        'name': product.name,
        'category': product.category,
        'description': product.description,
        'manufacturer': product.manufacturer,
        'barcode': product.barcode,
        'batchNumber': product.batchNumber,
        'dosage': product.dosage,
        'packageSize': product.packageSize,
        'stock': product.stock,
        'minStock': product.minStock,
        'price': product.price,
        'locationId': product.locationId,
        'expiryDate': product.expiryDate?.toIso8601String(),
        'createdAt': product.createdAt.toIso8601String(),
        'updatedAt': product.updatedAt?.toIso8601String(),
      },
    };
  }
}
