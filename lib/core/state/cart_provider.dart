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
        _items = decoded.map((item) => Map<String, dynamic>.from(item)).toList();
        notifyListeners();
      } catch (e) {
        debugPrint('Error loading cart: $e');
      }
    }
  }

  Future<void> _saveCart() async {
    final prefs = await SharedPreferences.getInstance();
    // We need to handle IconData and Color specially if we were storing them as raw objects,
    // but in a real app we'd store IDs or strings. 
    // For now, let's just store serializable data.
    final serializable = _items.map((item) {
      final copy = Map<String, dynamic>.from(item);
      // Remove or convert non-serializable fields if they exist
      if (copy['iconColor'] is Color) copy['iconColor'] = (copy['iconColor'] as Color).value;
      if (copy['color'] is Color) copy['color'] = (copy['color'] as Color).value;
      if (copy['icon'] is IconData) copy['icon'] = (copy['icon'] as IconData).codePoint;
      return copy;
    }).toList();
    
    await prefs.setString('cart_items', json.encode(serializable));
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
