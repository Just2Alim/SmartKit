import 'package:flutter/material.dart';

import '../../../core/router/app_routes.dart';
import '../../b2b/inventory/data/b2b_inventory_repository.dart';
import '../../b2b/inventory/models/b2b_inventory_model.dart';
import '../../../core/utils/db_seeder.dart';
import 'package:firebase_auth/firebase_auth.dart';


class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final inventoryRepo = B2BInventoryRepository();
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'test_user';

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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await DbSeeder.seedB2BInventory(userId);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('База данных заполнена тестовыми товарами')),
            );
          }
        },
        label: const Text('Заполнить БД'),
        icon: const Icon(Icons.auto_awesome),
      ),
      body: SafeArea(
        child: StreamBuilder<List<B2BInventoryModel>>(
          stream: inventoryRepo.getAllItems(),
          builder: (context, snapshot) {
            final b2bProducts = snapshot.data ?? [];
            
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                          color: const Color(0xFF10B981).withOpacity(0.25),
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
                  
                  // Section: Popular items (B2B Inventory)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Доступно сейчас',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text('См. всё', style: TextStyle(color: Color(0xFF10B981))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
                  else if (b2bProducts.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5)),
                            const SizedBox(height: 16),
                            const Text('В магазине пока нет товаров'),
                            const SizedBox(height: 8),
                            const Text('Используйте кнопку "Заполнить БД"'),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: b2bProducts.length,
                      itemBuilder: (context, index) {
                        final product = b2bProducts[index];
                        final isLowStock = product.stock <= product.minStock;
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.shopProduct,
                                arguments: {
                                  'id': product.id,
                                  'title': product.name,
                                  'subtitle': product.category,
                                  'price': '${product.price} ₸',
                                  'icon': Icons.medication_rounded,
                                  'color': const Color(0xFFECFDF5),
                                  'iconColor': const Color(0xFF10B981),
                                  'b2b_item': product.toMap(),
                                },
                              );
                            },
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.grey.withOpacity(0.1)),
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
                                      color: const Color(0xFFECFDF5),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: const Icon(
                                      Icons.medication_rounded,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.name,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: Theme.of(context).colorScheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          product.category,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Text(
                                              '${product.price} ₸',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                color: const Color(0xFF10B981),
                                              ),
                                            ),
                                            const Spacer(),
                                            if (isLowStock)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Text(
                                                  'Мало',
                                                  style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                              )
                                            else
                                               Text(
                                                '${product.stock} шт.',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

