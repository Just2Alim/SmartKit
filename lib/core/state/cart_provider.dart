import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        _items = decoded.map((item) => _hydrateMap(Map<String, dynamic>.from(item))).toList();
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
          result[key] = IconData(value['codePoint'], fontFamily: 'MaterialIcons');
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


  Future<void> _saveCart() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Deep copy and sanitize for JSON
    final serializable = _items.map((item) {
      final copy = _sanitizeMap(item);
      return copy;
    }).toList();
    
    await prefs.setString('cart_items', json.encode(serializable));
  }

  Map<String, dynamic> _sanitizeMap(Map<String, dynamic> map) {
    final result = <String, dynamic>{};
    map.forEach((key, value) {
      if (value is Color) {
        result[key] = {'_type': 'Color', 'value': value.value};
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

  void addItem(Map<String, dynamic> item) {
    _items.add(item);
    _saveCart();
    notifyListeners();
  }


  void removeItem(int index) {
    if (index >= 0 && index < _items.length) {
      _items.removeAt(index);
      _saveCart();
      notifyListeners();
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
      return sum + (int.tryParse(onlyDigits) ?? 0);
    });
  }
}
