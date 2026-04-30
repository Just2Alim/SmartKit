import 'package:flutter/material.dart';
import '../../../core/state/cart_provider.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

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
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = cartItems[index];
                              
                              // Handle Color and IconData from persistence (they might be stored as ints)
                              final Color itemColor = item['color'] is int 
                                  ? Color(item['color']) 
                                  : (item['color'] as Color);
                              final Color iconColor = item['iconColor'] is int 
                                  ? Color(item['iconColor']) 
                                  : (item['iconColor'] as Color);
                              final IconData icon = item['icon'] is int 
                                  ? IconData(item['icon'], fontFamily: 'MaterialIcons') 
                                  : (item['icon'] as IconData);

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
                                        color: itemColor,
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: Icon(
                                        icon,
                                        color: iconColor,
                                      ),
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
                                              color: Theme.of(context).colorScheme.onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            item['price'] as String,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
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
                                        color: Color(0xFFDC2626),
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
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      _formatPrice(totalPrice),
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed: cartItems.isEmpty ? null : () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Оформление заказа позже'),
                                        ),
                                      );
                                    },
                                    child: const Text(
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
