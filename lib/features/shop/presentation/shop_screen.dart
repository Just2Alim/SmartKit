import 'package:flutter/material.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/state/cart_provider.dart';
import '../../b2b/inventory/data/b2b_inventory_repository.dart';
import '../../b2b/inventory/models/b2b_inventory_model.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final B2BInventoryRepository _inventoryRepo = B2BInventoryRepository();
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = 'Все';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  Color _categoryColor(String category) {
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
    return const Color(0xFF10B981);
  }

  IconData _categoryIcon(String category) {
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
    return Icons.medication_rounded;
  }

  List<B2BInventoryModel> _filterProducts(List<B2BInventoryModel> products) {
    final query = _searchController.text.trim().toLowerCase();
    return products.where((product) {
      final matchesCategory =
          _selectedCategory == 'Все' || product.category == _selectedCategory;
      final searchable =
          [
            product.name,
            product.category,
            product.manufacturer ?? '',
            product.dosage ?? '',
          ].join(' ').toLowerCase();
      final matchesSearch = query.isEmpty || searchable.contains(query);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  Map<String, dynamic> _productMap(B2BInventoryModel product) {
    final color = _categoryColor(product.category);
    final subtitle = [
      product.category,
      if ((product.dosage ?? '').isNotEmpty) product.dosage!,
      if ((product.packageSize ?? '').isNotEmpty) product.packageSize!,
    ].join(' • ');

    return {
      'id': product.id,
      'title': product.name,
      'subtitle': subtitle,
      'price': _formatPrice(product.price),
      'icon': _categoryIcon(product.category),
      'color': color.withOpacity(0.12),
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

  void _addToCart(BuildContext context, B2BInventoryModel product) {
    final alreadyInCart = CartProvider.instance.items
        .where((item) => item['id'] == product.id)
        .fold<int>(
          0,
          (sum, item) => sum + ((item['quantity'] as num?)?.toInt() ?? 1),
        );

    if (alreadyInCart >= product.stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('В корзине уже выбран весь остаток')),
      );
      return;
    }

    CartProvider.instance.addItem(_productMap(product));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${product.name} добавлен в корзину')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: StreamBuilder<List<B2BInventoryModel>>(
          stream: _inventoryRepo.getPublicCatalogItems(),
          initialData: const [],
          builder: (context, snapshot) {
            final products = snapshot.data ?? [];
            final categories = [
              'Все',
              ...products.map((item) => item.category).toSet().toList()..sort(),
            ];
            final visibleProducts = _filterProducts(products);

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _buildHeader(context, products.length),
                ),
                SliverToBoxAdapter(child: _buildSearchAndFilters(categories)),
                if (snapshot.hasError)
                  SliverFillRemaining(
                    child: _emptyState(
                      'Витрина временно недоступна. Проверьте доступ к товарам склада.',
                    ),
                  )
                else if (products.isEmpty)
                  SliverFillRemaining(child: _emptyState('Витрина пока пуста'))
                else if (visibleProducts.isEmpty)
                  SliverFillRemaining(child: _emptyState('Ничего не найдено'))
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            _productCard(context, visibleProducts[index]),
                        childCount: visibleProducts.length,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:
                            MediaQuery.of(context).size.width > 640 ? 3 : 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.68,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int productCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF047857)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              blurRadius: 22,
              offset: const Offset(0, 12),
              color: const Color(0xFF047857).withOpacity(0.18),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.local_pharmacy_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const Spacer(),
                ListenableBuilder(
                  listenable: CartProvider.instance,
                  builder: (context, _) {
                    final count = CartProvider.instance.itemCount;
                    return IconButton(
                      onPressed:
                          () => Navigator.pushNamed(context, AppRoutes.cart),
                      icon: Badge.count(
                        count: count,
                        isLabelVisible: count > 0,
                        backgroundColor: const Color(0xFFF59E0B),
                        child: const Icon(
                          Icons.shopping_bag_outlined,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Text(
              'SmartKit Аптека',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$productCount товаров в наличии • проверенные складские остатки',
              style: TextStyle(
                color: Colors.white.withOpacity(0.78),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(List<String> categories) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Поиск лекарства, категории или бренда',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon:
                  _searchController.text.isEmpty
                      ? null
                      : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = categories[index];
                final selected = category == _selectedCategory;
                return ChoiceChip(
                  selected: selected,
                  label: Text(category),
                  onSelected:
                      (_) => setState(() => _selectedCategory = category),
                  selectedColor: const Color(0xFF10B981),
                  labelStyle: TextStyle(
                    color:
                        selected
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                  backgroundColor: Theme.of(context).cardColor,
                  side: BorderSide(
                    color:
                        selected
                            ? const Color(0xFF10B981)
                            : Theme.of(context).colorScheme.outlineVariant,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _productCard(BuildContext context, B2BInventoryModel product) {
    final color = _categoryColor(product.category);
    final lowStock = product.stock <= product.minStock;

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.pushNamed(
            context,
            AppRoutes.shopProduct,
            arguments: _productMap(product),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 16,
                offset: const Offset(0, 8),
                color: Colors.black.withValues(
                  alpha:
                      Theme.of(context).brightness == Brightness.dark
                          ? 0.22
                          : 0.04,
                ),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Icon(_categoryIcon(product.category), color: color),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color:
                          lowStock
                              ? const Color(0xFFFFF7ED)
                              : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      lowStock ? 'Мало' : '${product.stock} шт',
                      style: TextStyle(
                        color:
                            lowStock
                                ? const Color(0xFFEA580C)
                                : const Color(0xFF047857),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                [
                  product.category,
                  if ((product.dosage ?? '').isNotEmpty) product.dosage!,
                ].join(' • '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if ((product.manufacturer ?? '').isNotEmpty)
                Text(
                  product.manufacturer!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      _formatPrice(product.price),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton(
                      onPressed:
                          product.stock <= 0
                              ? null
                              : () => _addToCart(context, product),
                      padding: EdgeInsets.zero,
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(
                        Icons.add_shopping_cart_rounded,
                        size: 19,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.storefront_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 46,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
