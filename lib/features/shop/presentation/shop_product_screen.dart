import 'package:flutter/material.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/state/cart_provider.dart';

class ShopProductScreen extends StatelessWidget {
  final Map<String, dynamic> product;

  const ShopProductScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final items = [
      'Продуманная подборка',
      'Подходит для базовых сценариев',
      'Можно использовать как основу аптечки',
      'Удобно для дома или поездок',
    ];

    return Scaffold(

      appBar: AppBar(
        title: const Text('Товар'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.cart);
            },
            icon: const Icon(Icons.shopping_cart_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? (product['color'] as Color).withOpacity(0.2)
                      : (product['color'] as Color),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(
                  product['icon'] as IconData,
                  size: 72,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? (product['iconColor'] as Color).withOpacity(0.9)
                      : (product['iconColor'] as Color),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                product['title'] as String,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                product['subtitle'] as String,
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                product['price'] as String,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Что входит',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
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
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF1E3A8A).withOpacity(0.3)
                                : const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () {
                    CartProvider.instance.addItem(product);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Товар добавлен в корзину')),
                    );
                  },
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  label: const Text(
                    'Добавить в корзину',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
