import 'package:flutter/material.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/state/cart_provider.dart';

class ShopProductScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const ShopProductScreen({super.key, required this.product});

  @override
  State<ShopProductScreen> createState() => _ShopProductScreenState();
}

class _ShopProductScreenState extends State<ShopProductScreen> {
  int _quantity = 1;

  int get _stock => (widget.product['stock'] as num?)?.toInt() ?? 0;

  int get _price {
    return int.tryParse(
          widget.product['price'].toString().replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0;
  }

  String _formatPrice(int value) {
    final text = value.toString();
    final buffer = StringBuffer();
    int counter = 0;

    for (int i = text.length - 1; i >= 0; i--) {
      buffer.write(text[i]);
      counter++;
      if (counter % 3 == 0 && i != 0) buffer.write(' ');
    }

    return '${buffer.toString().split('').reversed.join()} ₸';
  }

  String _stringValue(String key) {
    return widget.product[key]?.toString().trim() ?? '';
  }

  List<Map<String, dynamic>> _details() {
    return [
      if (_stringValue('manufacturer').isNotEmpty)
        {
          'label': 'Производитель',
          'value': _stringValue('manufacturer'),
          'icon': Icons.factory_outlined,
        },
      if (_stringValue('dosage').isNotEmpty)
        {
          'label': 'Дозировка',
          'value': _stringValue('dosage'),
          'icon': Icons.science_outlined,
        },
      if (_stringValue('packageSize').isNotEmpty)
        {
          'label': 'Упаковка',
          'value': _stringValue('packageSize'),
          'icon': Icons.inventory_2_outlined,
        },
      {
        'label': 'Остаток',
        'value': '$_stock шт',
        'icon': Icons.warehouse_outlined,
      },
      {
        'label': 'Контроль качества',
        'value': 'Складской товар SmartKit',
        'icon': Icons.verified_outlined,
      },
    ];
  }

  void _changeQuantity(int delta) {
    if (_stock <= 0) return;
    final next = (_quantity + delta).clamp(1, _stock);
    setState(() => _quantity = next);
  }

  int _quantityInCart() {
    return CartProvider.instance.items
        .where((item) => item['id'] == widget.product['id'])
        .fold<int>(
          0,
          (sum, item) => sum + ((item['quantity'] as num?)?.toInt() ?? 1),
        );
  }

  @override
  Widget build(BuildContext context) {
    final Color itemColor = widget.product['color'] as Color;
    final Color iconColor = widget.product['iconColor'] as Color;
    final IconData icon = widget.product['icon'] as IconData;
    final description = _stringValue('description');
    final canBuy = _stock > 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Товар'),
        actions: [
          ListenableBuilder(
            listenable: CartProvider.instance,
            builder: (context, _) {
              final count = CartProvider.instance.itemCount;
              return IconButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.cart),
                icon: Badge.count(
                  count: count,
                  isLabelVisible: count > 0,
                  child: const Icon(Icons.shopping_bag_outlined),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [itemColor, Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: iconColor.withOpacity(0.12)),
              ),
              child: Center(
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: iconColor.withOpacity(0.16),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 54, color: iconColor),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.product['title'] as String,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.product['subtitle'] as String,
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatPrice(_price),
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
                _stockBadge(canBuy),
              ],
            ),
            const SizedBox(height: 24),
            _quantityControl(),
            const SizedBox(height: 24),
            ..._details().map(_detailTile),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed:
                    canBuy
                        ? () {
                          if (_quantityInCart() + _quantity > _stock) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'В корзине уже выбран весь остаток',
                                ),
                              ),
                            );
                            return;
                          }
                          CartProvider.instance.addItem(
                            widget.product,
                            quantity: _quantity,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Товар добавлен в корзину'),
                            ),
                          );
                        }
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: Text(
                  canBuy
                      ? 'Добавить $_quantity шт. • ${_formatPrice(_price * _quantity)}'
                      : 'Нет в наличии',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stockBadge(bool canBuy) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: canBuy ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        canBuy ? 'В наличии' : 'Нет в наличии',
        style: TextStyle(
          color: canBuy ? const Color(0xFF047857) : const Color(0xFFDC2626),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _quantityControl() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Количество',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          _quantityButton(Icons.remove_rounded, () => _changeQuantity(-1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '$_quantity',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          _quantityButton(Icons.add_rounded, () => _changeQuantity(1)),
        ],
      ),
    );
  }

  Widget _quantityButton(IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: 38,
      height: 38,
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 20),
        style: IconButton.styleFrom(
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHighest,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _detailTile(Map<String, dynamic> detail) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(detail['icon'] as IconData, color: const Color(0xFF10B981)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail['label'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  detail['value'] as String,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
