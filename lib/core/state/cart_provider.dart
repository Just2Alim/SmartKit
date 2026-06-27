import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/analytics_service.dart';

class CartProvider extends ChangeNotifier {
  static final CartProvider instance = CartProvider._internal();
  CartProvider._internal() {
    _loadCart();
  }

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> get items => _items;

  Future<void> _loadCart() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('cart_items');
    if (data != null) {
      try {
        final List<dynamic> decoded = json.decode(data);
        _items =
            decoded
                .map((item) => _hydrateMap(Map<String, dynamic>.from(item)))
                .toList();
        notifyListeners();
      } catch (e) {
        debugPrint('Error loading cart: $e');
      }
    }
  }

  Map<String, dynamic> _hydrateMap(Map<String, dynamic> map) {
    final result = <String, dynamic>{};
    map.forEach((key, value) {
      if (value is Map<String, dynamic> && value.containsKey('_type')) {
        final type = value['_type'];
        if (type == 'Color') {
          result[key] = Color(value['value']);
        } else if (type == 'IconData') {
          result[key] = _iconFromCodePoint((value['codePoint'] as num).toInt());
        } else if (type == 'DateTime') {
          result[key] = DateTime.parse(value['value']);
        } else {
          result[key] = value;
        }
      } else if (value is Map<String, dynamic>) {
        result[key] = _hydrateMap(value);
      } else {
        result[key] = value;
      }
    });
    return result;
  }

  IconData _iconFromCodePoint(int codePoint) {
    const supportedIcons = <IconData>[
      Icons.bolt_rounded,
      Icons.sanitizer_rounded,
      Icons.air_rounded,
      Icons.spa_rounded,
      Icons.favorite_rounded,
      Icons.record_voice_over_rounded,
      Icons.medication_rounded,
      Icons.medical_services_rounded,
      Icons.local_pharmacy_rounded,
      Icons.healing_rounded,
    ];

    return supportedIcons.firstWhere(
      (icon) => icon.codePoint == codePoint,
      orElse: () => Icons.medication_rounded,
    );
  }

  Future<void> _saveCart() async {
    final prefs = await SharedPreferences.getInstance();

    // Deep copy and sanitize for JSON
    final serializable =
        _items.map((item) {
          final copy = _sanitizeMap(item);
          return copy;
        }).toList();

    await prefs.setString('cart_items', json.encode(serializable));
  }

  Map<String, dynamic> _sanitizeMap(Map<String, dynamic> map) {
    final result = <String, dynamic>{};
    map.forEach((key, value) {
      if (value is Color) {
        result[key] = {'_type': 'Color', 'value': value.toARGB32()};
      } else if (value is IconData) {
        result[key] = {'_type': 'IconData', 'codePoint': value.codePoint};
      } else if (value is DateTime) {
        result[key] = {'_type': 'DateTime', 'value': value.toIso8601String()};
      } else if (value is Map<String, dynamic>) {
        result[key] = _sanitizeMap(value);
      } else {
        result[key] = value;
      }
    });
    return result;
  }

  String _itemKey(Map<String, dynamic> item) {
    return (item['id'] ?? item['title'] ?? '').toString();
  }

  int _quantityOf(Map<String, dynamic> item) {
    return (item['quantity'] as num?)?.toInt() ?? 1;
  }

  void addItem(Map<String, dynamic> item, {int quantity = 1}) {
    final key = _itemKey(item);
    final existingIndex = _items.indexWhere(
      (cartItem) => _itemKey(cartItem) == key,
    );

    if (existingIndex >= 0) {
      final existing = _items[existingIndex];
      existing['quantity'] = _quantityOf(existing) + quantity;
    } else {
      _items.add({...item, 'quantity': quantity});
    }

    _saveCart();
    notifyListeners();
    AnalyticsService.instance.trackFeature(
      'cart',
      action: 'item_added',
      properties: {'quantity': quantity, 'item_count': itemCount},
    );
  }

  void addItems(Iterable<Map<String, dynamic>> items) {
    for (final item in items) {
      final quantity = _quantityOf(item);
      final key = _itemKey(item);
      final existingIndex = _items.indexWhere(
        (cartItem) => _itemKey(cartItem) == key,
      );

      if (existingIndex >= 0) {
        final existing = _items[existingIndex];
        existing['quantity'] = _quantityOf(existing) + quantity;
      } else {
        _items.add({...item, 'quantity': quantity});
      }
    }

    _saveCart();
    notifyListeners();
    AnalyticsService.instance.trackFeature(
      'cart',
      action: 'items_added',
      properties: {'item_count': itemCount},
    );
  }

  void incrementItem(int index) {
    if (index >= 0 && index < _items.length) {
      _items[index]['quantity'] = _quantityOf(_items[index]) + 1;
      _saveCart();
      notifyListeners();
      AnalyticsService.instance.trackFeature(
        'cart',
        action: 'quantity_increased',
        properties: {'item_count': itemCount},
      );
    }
  }

  void decrementItem(int index) {
    if (index >= 0 && index < _items.length) {
      final quantity = _quantityOf(_items[index]);
      if (quantity <= 1) {
        _items.removeAt(index);
      } else {
        _items[index]['quantity'] = quantity - 1;
      }
      _saveCart();
      notifyListeners();
      AnalyticsService.instance.trackFeature(
        'cart',
        action: 'quantity_decreased',
        properties: {'item_count': itemCount},
      );
    }
  }

  void removeItem(int index) {
    if (index >= 0 && index < _items.length) {
      _items.removeAt(index);
      _saveCart();
      notifyListeners();
      AnalyticsService.instance.trackFeature(
        'cart',
        action: 'item_removed',
        properties: {'item_count': itemCount},
      );
    }
  }

  void clearCart() {
    _items.clear();
    _saveCart();
    notifyListeners();
  }

  int get totalPrice {
    return _items.fold(0, (sum, item) {
      final priceStr = item['price'] as String;
      final onlyDigits = priceStr.replaceAll(RegExp(r'[^0-9]'), '');
      return sum + ((int.tryParse(onlyDigits) ?? 0) * _quantityOf(item));
    });
  }

  int get itemCount {
    return _items.fold(0, (sum, item) => sum + _quantityOf(item));
  }
}
