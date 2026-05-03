import 'package:flutter/material.dart';
import '../../../core/state/cart_provider.dart';
import '../../b2b/inventory/data/b2b_inventory_repository.dart';
import '../../b2b/inventory/data/b2b_sales_repository.dart';
import '../../b2b/inventory/models/b2b_sale_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isLoading = false;

  String _formatPrice(int value) {
    final text = value.toString();
    final buffer = StringBuffer();
    int counter = 0;

    for (int i = text.length - 1; i >= 0; i--) {
      buffer.write(text[i]);
      counter++;
      if (counter % 3 == 0 && i != 0) {
        buffer.write(' ');
      }
    }

    return '${buffer.toString().split('').reversed.join()} ₸';
  }

  int _quantityOf(Map<String, dynamic> item) {
    return (item['quantity'] as num?)?.toInt() ?? 1;
  }

  int _priceOf(Map<String, dynamic> item) {
    return int.tryParse(
          item['price'].toString().replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0;
  }

  Widget _quantityButton(IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFFF1F5F9),
          foregroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Future<void> _processCheckout(BuildContext context) async {
    setState(() => _isLoading = true);

    try {
      final cartItems = CartProvider.instance.items;
      final inventoryRepo = B2BInventoryRepository();
      final salesRepo = B2BSalesRepository();
      final customerId = FirebaseAuth.instance.currentUser?.uid ?? 'guest_user';
      final salesByOwner = <String, List<Map<String, dynamic>>>{};
      final totalsByOwner = <String, int>{};

      for (final item in cartItems) {
        if (!item.containsKey('b2b_item')) continue;

        final quantity = _quantityOf(item);
        final itemId = item['id'] as String;
        final latest = await inventoryRepo.getItemById(itemId);
        if (latest == null) {
          throw StateError('Товар "${item['title']}" больше недоступен');
        }
        if (latest.stock < quantity) {
          throw StateError(
            'Недостаточно товара "${latest.name}": доступно ${latest.stock} шт.',
          );
        }
      }

      for (var item in cartItems) {
        final quantity = _quantityOf(item);
        if (item.containsKey('b2b_item')) {
          final itemId = item['id'] as String;
          final soldItem = await inventoryRepo.decreaseStockForSale(
            itemId,
            quantity,
          );

          salesByOwner.putIfAbsent(soldItem.userId, () => []);
          salesByOwner[soldItem.userId]!.add({
            'id': itemId,
            'name': soldItem.name,
            'price': soldItem.price,
            'quantity': quantity,
          });
          totalsByOwner[soldItem.userId] =
              (totalsByOwner[soldItem.userId] ?? 0) + soldItem.price * quantity;
        } else if (item['id'] != null) {
          final fallbackOwner = customerId;
          salesByOwner.putIfAbsent(fallbackOwner, () => []);
          salesByOwner[fallbackOwner]!.add({
            'id': item['id'],
            'name': item['title'],
            'price': _priceOf(item),
            'quantity': quantity,
          });
          totalsByOwner[fallbackOwner] =
              (totalsByOwner[fallbackOwner] ?? 0) + _priceOf(item) * quantity;
        }
      }

      for (final entry in salesByOwner.entries) {
        final sale = B2BSaleModel(
          id: '',
          userId: entry.key,
          items: entry.value,
          totalAmount: totalsByOwner[entry.key] ?? 0,
          saleDate: DateTime.now(),
          customerId: customerId,
          staffName: 'Онлайн-магазин',
        );
        await salesRepo.recordSale(sale);
      }

      CartProvider.instance.clearCart();

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Заказ успешно оформлен!')));
      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка при оформлении: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CartProvider.instance,
      builder: (context, _) {
        final cartItems = CartProvider.instance.items;
        final totalPrice = CartProvider.instance.totalPrice;

        return Scaffold(
          appBar: AppBar(title: const Text('Корзина')),
          body: SafeArea(
            child:
                cartItems.isEmpty
                    ? Center(
                      child: Text(
                        'Корзина пока пуста',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                    : Column(
                      children: [
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                            itemCount: cartItems.length,
                            separatorBuilder:
                                (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = cartItems[index];
                              final quantity = _quantityOf(item);
                              final maxStock =
                                  item['b2b_item'] is Map<String, dynamic>
                                      ? ((item['b2b_item']
                                                  as Map<
                                                    String,
                                                    dynamic
                                                  >)['stock']
                                              as num?)
                                          ?.toInt()
                                      : null;

                              final Color itemColor = item['color'] as Color;
                              final Color iconColor =
                                  item['iconColor'] as Color;
                              final IconData icon = item['icon'] as IconData;

                              return Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                      color: Colors.black.withOpacity(0.04),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 58,
                                      height: 58,
                                      decoration: BoxDecoration(
                                        color: itemColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: Icon(icon, color: iconColor),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['title'] as String,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _formatPrice(
                                              _priceOf(item) * quantity,
                                            ),
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF10B981),
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              _quantityButton(
                                                Icons.remove_rounded,
                                                () {
                                                  CartProvider.instance
                                                      .decrementItem(index);
                                                },
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                    ),
                                                child: Text(
                                                  '$quantity',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 15,
                                                    color:
                                                        Theme.of(
                                                          context,
                                                        ).colorScheme.onSurface,
                                                  ),
                                                ),
                                              ),
                                              _quantityButton(
                                                Icons.add_rounded,
                                                () {
                                                  if (maxStock != null &&
                                                      quantity >= maxStock) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Больше нет на складе',
                                                        ),
                                                      ),
                                                    );
                                                    return;
                                                  }
                                                  CartProvider.instance
                                                      .incrementItem(index);
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        CartProvider.instance.removeItem(index);
                                      },
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Color(0xFFEF4444),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 12,
                                offset: const Offset(0, -4),
                                color: Colors.black.withOpacity(0.04),
                              ),
                            ],
                          ),
                          child: SafeArea(
                            top: false,
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Итого',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      _formatPrice(totalPrice),
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF10B981),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 0,
                                    ),
                                    onPressed:
                                        (cartItems.isEmpty || _isLoading)
                                            ? null
                                            : () => _processCheckout(context),
                                    child:
                                        _isLoading
                                            ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                            : const Text(
                                              'Оформить заказ',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
          ),
        );
      },
    );
  }
}
