import 'package:flutter/material.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/state/cart_provider.dart';
import '../../b2b/inventory/data/b2b_inventory_repository.dart';
import '../../b2b/inventory/models/b2b_inventory_model.dart';
import '../data/shop_repository.dart';
import '../models/shop_order_model.dart';
import '../utils/shop_product_mapper.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final B2BInventoryRepository _inventoryRepo = B2BInventoryRepository();
  final ShopRepository _shopRepository = ShopRepository();
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = 'Все';
  late Future<ShopPersonalizationSignals> _signalsFuture;

  @override
  void initState() {
    super.initState();
    _signalsFuture = _shopRepository.getPersonalizationSignals();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  void _clearFilters() {
    _searchController.clear();
    setState(() => _selectedCategory = 'Все');
  }

  Map<String, dynamic> _productMap(B2BInventoryModel product) {
    return ShopProductMapper.toProductMap(product);
  }

  List<B2BInventoryModel> _personalizedProducts(
    List<B2BInventoryModel> products,
    ShopPersonalizationSignals signals,
  ) {
    if (signals.categoryScores.isEmpty &&
        signals.purchasedInventoryIds.isEmpty) {
      return const [];
    }

    final scored = <({B2BInventoryModel product, int score})>[];
    for (final product in products) {
      if (product.stock <= 0) continue;
      final categoryScore = signals.categoryScores[product.category] ?? 0;
      final refillScore =
          signals.purchasedInventoryIds.contains(product.id) ? 8 : 0;
      final lowStockBoost = product.stock <= product.minStock ? -2 : 0;
      final score = categoryScore * 3 + refillScore + lowStockBoost;
      if (score > 0) scored.add((product: product, score: score));
    }

    scored.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      return a.product.name.compareTo(b.product.name);
    });

    return scored.map((item) => item.product).take(6).toList();
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
      SnackBar(
        content: Text('${product.name} добавлен в корзину'),
        action: SnackBarAction(
          label: 'Открыть',
          onPressed: () => Navigator.pushNamed(context, AppRoutes.cart),
        ),
      ),
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
            final availableProducts =
                products.where((item) => item.stock > 0).length;
            final categories = [
              'Все',
              ...products.map((item) => item.category).toSet().toList()..sort(),
            ];
            final visibleProducts = _filterProducts(products);
            final columns = MediaQuery.of(context).size.width > 640 ? 3 : 2;
            final ratio = MediaQuery.of(context).size.width < 380 ? 0.62 : 0.68;

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _buildHeader(
                    context,
                    products.length,
                    availableProducts,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _buildSearchAndFilters(
                    categories,
                    visibleProducts.length,
                    products.length,
                  ),
                ),
                FutureBuilder<ShopPersonalizationSignals>(
                  future: _signalsFuture,
                  builder: (context, signalsSnapshot) {
                    final recommendations = _personalizedProducts(
                      products,
                      signalsSnapshot.data ?? ShopPersonalizationSignals.empty,
                    );

                    if (recommendations.isEmpty) {
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    }

                    return SliverToBoxAdapter(
                      child: _buildPersonalRecommendations(recommendations),
                    );
                  },
                ),
                if (snapshot.hasError)
                  SliverFillRemaining(
                    child: _emptyState(
                      'Витрина временно недоступна. Проверьте доступ к товарам склада.',
                    ),
                  )
                else if (products.isEmpty)
                  SliverFillRemaining(child: _emptyState('Витрина пока пуста'))
                else if (visibleProducts.isEmpty)
                  SliverFillRemaining(
                    child: _emptyState(
                      'Ничего не найдено',
                      actionLabel: 'Сбросить фильтры',
                      onAction: _clearFilters,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 112),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            _productCard(context, visibleProducts[index]),
                        childCount: visibleProducts.length,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: ratio,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: _buildCartBar(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildHeader(
    BuildContext context,
    int productCount,
    int availableProducts,
  ) {
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
              color: const Color(0xFF047857).withValues(alpha: 0.18),
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
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.local_pharmacy_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Мои заказы',
                  onPressed:
                      () => Navigator.pushNamed(context, AppRoutes.shopOrders),
                  icon: const Icon(
                    Icons.receipt_long_outlined,
                    color: Colors.white,
                  ),
                ),
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
              '$productCount товаров в каталоге • $availableProducts доступно сейчас',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(
    List<String> categories,
    int visibleCount,
    int totalCount,
  ) {
    final hasFilters =
        _selectedCategory != 'Все' || _searchController.text.trim().isNotEmpty;

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
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  hasFilters
                      ? 'Показано $visibleCount из $totalCount'
                      : 'Быстрый подбор по категории',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (hasFilters)
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Сбросить'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalRecommendations(List<B2BInventoryModel> products) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 0, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Персонально для вас',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final product = products[index];
                final color = ShopProductMapper.categoryColor(product.category);
                return SizedBox(
                  width: 230,
                  child: Material(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
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
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    ShopProductMapper.categoryIcon(
                                      product.category,
                                    ),
                                    color: color,
                                    size: 20,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${product.stock} шт',
                                  style: TextStyle(
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              product.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    ShopProductMapper.formatPrice(
                                      product.price,
                                    ),
                                    style: const TextStyle(
                                      color: Color(0xFF10B981),
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                IconButton.filled(
                                  onPressed:
                                      product.stock <= 0
                                          ? null
                                          : () => _addToCart(context, product),
                                  icon: const Icon(
                                    Icons.add_shopping_cart_rounded,
                                    size: 18,
                                  ),
                                  style: IconButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
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
    final color = ShopProductMapper.categoryColor(product.category);
    final outOfStock = product.stock <= 0;
    final lowStock = !outOfStock && product.stock <= product.minStock;
    final stockLabel =
        outOfStock
            ? 'Нет'
            : lowStock
            ? 'Мало'
            : '${product.stock} шт';
    final stockBackground =
        outOfStock
            ? const Color(0xFFFEF2F2)
            : lowStock
            ? const Color(0xFFFFF7ED)
            : const Color(0xFFECFDF5);
    final stockColor =
        outOfStock
            ? const Color(0xFFDC2626)
            : lowStock
            ? const Color(0xFFEA580C)
            : const Color(0xFF047857);

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
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Icon(
                      ShopProductMapper.categoryIcon(product.category),
                      color: color,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: stockBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      stockLabel,
                      style: TextStyle(
                        color: stockColor,
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
                      ShopProductMapper.formatPrice(product.price),
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
                          outOfStock
                              ? null
                              : () => _addToCart(context, product),
                      padding: EdgeInsets.zero,
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                        disabledForegroundColor:
                            Theme.of(context).colorScheme.onSurfaceVariant,
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

  Widget _buildCartBar(BuildContext context) {
    return ListenableBuilder(
      listenable: CartProvider.instance,
      builder: (context, _) {
        final count = CartProvider.instance.itemCount;
        if (count == 0) return const SizedBox.shrink();

        return SizedBox(
          width: MediaQuery.of(context).size.width - 40,
          height: 58,
          child: Material(
            color: const Color(0xFF10B981),
            borderRadius: BorderRadius.circular(20),
            elevation: 0,
            shadowColor: const Color(0xFF047857).withValues(alpha: 0.24),
            child: InkWell(
              onTap: () => Navigator.pushNamed(context, AppRoutes.cart),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Badge.count(
                      count: count,
                      backgroundColor: const Color(0xFFF59E0B),
                      child: const Icon(
                        Icons.shopping_bag_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Перейти к корзине',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      ShopProductMapper.formatPrice(
                        CartProvider.instance.totalPrice,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _emptyState(
    String text, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
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
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ],
        ),
      ),
    );
  }
}
