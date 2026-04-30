import 'package:flutter/material.dart';

import '../../../core/router/app_routes.dart';


class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final products = [
      {
        'id': '1',
        'title': 'Базовая аптечка',
        'subtitle': 'Для дома и повседневного использования',
        'price': '12 990 ₸',
        'icon': Icons.medical_services_rounded,
        'color': const Color(0xFFDBEAFE),
        'iconColor': const Color(0xFF2563EB),
      },
      {
        'id': '2',
        'title': 'Аптечка в поездку',
        'subtitle': 'Компактный набор для путешествий',
        'price': '9 490 ₸',
        'icon': Icons.luggage_rounded,
        'color': const Color(0xFFFFEDD5),
        'iconColor': const Color(0xFFEA580C),
      },
      {
        'id': '3',
        'title': 'Детский набор',
        'subtitle': 'Подборка для семьи с ребёнком',
        'price': '14 500 ₸',
        'icon': Icons.child_care_rounded,
        'color': const Color(0xFFDCFCE7),
        'iconColor': const Color(0xFF16A34A),
      },
      {
        'id': '4',
        'title': 'Антисептики и перевязка',
        'subtitle': 'Базовый комплект первой помощи',
        'price': '6 700 ₸',
        'icon': Icons.healing_rounded,
        'color': const Color(0xFFEDE9FE),
        'iconColor': const Color(0xFF7C3AED),
      },
    ];

    return Scaffold(

      appBar: AppBar(
        title: const Text('Магазин'),
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
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                      color: const Color(0xFF2563EB).withOpacity(0.25),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.shopping_bag_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SmartKit Shop',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Готовые наборы и полезные товары для аптечки',
                            style: TextStyle(fontSize: 13, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Популярные товары',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              ...products.map(
                (product) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.shopProduct,
                        arguments: product,
                      );
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
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
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? (product['color'] as Color).withOpacity(0.2)
                                  : (product['color'] as Color),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              product['icon'] as IconData,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? (product['iconColor'] as Color).withOpacity(0.9)
                                  : (product['iconColor'] as Color),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product['title'] as String,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  product['subtitle'] as String,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  product['price'] as String,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                           Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 18,
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                    ),
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
