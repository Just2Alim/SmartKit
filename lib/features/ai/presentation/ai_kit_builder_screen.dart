import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/state/cart_provider.dart';
import '../../b2b/inventory/data/b2b_inventory_repository.dart';
import '../../b2b/inventory/models/b2b_inventory_model.dart';
import '../../medicine/data/medicine_repository.dart';
import '../../medicine/models/medicine_model.dart';
import '../../shop/utils/shop_product_mapper.dart';
import '../domain/ai_kit_planner.dart';

class AiKitBuilderScreen extends StatefulWidget {
  const AiKitBuilderScreen({super.key});

  @override
  State<AiKitBuilderScreen> createState() => _AiKitBuilderScreenState();
}

class _AiKitBuilderScreenState extends State<AiKitBuilderScreen> {
  final B2BInventoryRepository _inventoryRepository = B2BInventoryRepository();
  final MedicineRepository _medicineRepository = MedicineRepository();

  String _scenario = 'Домашняя аптечка';
  bool _forChild = false;
  bool _forTravel = false;
  bool _includeAllergy = true;
  bool _includeDigestive = true;
  bool _includeColdCare = true;
  bool _includeWoundCare = true;
  bool _hasChronicConditions = false;
  bool _pregnantOrBreastfeeding = false;

  static const List<String> _scenarios = [
    'Домашняя аптечка',
    'Аптечка в поездку',
    'Для ребенка',
    'Минимальный базовый набор',
  ];

  AiKitPreferences get _preferences {
    return AiKitPreferences(
      scenario: _scenario,
      forChild: _forChild,
      forTravel: _forTravel,
      includeAllergy: _includeAllergy,
      includeDigestive: _includeDigestive,
      includeColdCare: _includeColdCare,
      includeWoundCare: _includeWoundCare,
      hasChronicConditions: _hasChronicConditions,
      pregnantOrBreastfeeding: _pregnantOrBreastfeeding,
    );
  }

  void _applyScenario(String scenario) {
    setState(() {
      _scenario = scenario;
      _forChild = scenario == 'Для ребенка';
      _forTravel = scenario == 'Аптечка в поездку';
      _includeAllergy = scenario != 'Минимальный базовый набор';
      _includeDigestive =
          scenario == 'Аптечка в поездку' || scenario == 'Домашняя аптечка';
      _includeColdCare = scenario != 'Минимальный базовый набор';
      _includeWoundCare = true;
    });
  }

  int _quantityInCart(String productId) {
    return CartProvider.instance.items
        .where((item) => item['id'] == productId)
        .fold<int>(
          0,
          (sum, item) => sum + ((item['quantity'] as num?)?.toInt() ?? 1),
        );
  }

  Future<void> _confirmCreateCart(AiKitPlan plan) async {
    final purchasable = plan.purchasableItems;
    if (purchasable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нет доступных товаров для автоматической корзины'),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Создать корзину?'),
            content: Text(
              'Добавить ${purchasable.length} позиций на сумму '
              '${ShopProductMapper.formatPrice(plan.estimatedTotal)}. '
              'Перед применением лекарств проверьте инструкцию и противопоказания.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Добавить'),
              ),
            ],
          ),
    );

    if (confirm != true || !mounted) return;

    final cartItems = <Map<String, dynamic>>[];
    final skipped = <String>[];

    for (final item in purchasable) {
      final product = item.product!;
      final inCart = _quantityInCart(product.id);
      if (inCart + item.quantity > product.stock) {
        skipped.add(product.name);
        continue;
      }

      final map = ShopProductMapper.toProductMap(product);
      map['quantity'] = item.quantity;
      map['source'] = 'ai_kit_builder';
      cartItems.add(map);
    }

    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Все выбранные товары уже в корзине')),
      );
      return;
    }

    CartProvider.instance.addItems(cartItems);

    if (!mounted) return;
    final message =
        skipped.isEmpty
            ? 'Корзина собрана'
            : 'Корзина собрана, часть товаров уже выбрана по максимуму';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    Navigator.pushNamed(context, AppRoutes.cart);
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('AI сбор аптечки')),
      body:
          user == null
              ? const Center(child: Text('Пользователь не найден'))
              : SafeArea(
                child: StreamBuilder<List<B2BInventoryModel>>(
                  stream: _inventoryRepository.getPublicCatalogItems(),
                  initialData: const [],
                  builder: (context, catalogSnapshot) {
                    return StreamBuilder<List<MedicineModel>>(
                      stream: _medicineRepository.getMedicinesByUser(user.id),
                      initialData: const [],
                      builder: (context, medicineSnapshot) {
                        final catalog = catalogSnapshot.data ?? [];
                        final medicines = medicineSnapshot.data ?? [];
                        final isLoading =
                            catalogSnapshot.connectionState ==
                                ConnectionState.waiting ||
                            medicineSnapshot.connectionState ==
                                ConnectionState.waiting;
                        final plan = AiKitPlanner.buildPlan(
                          preferences: _preferences,
                          catalog: catalog,
                          homeMedicines: medicines,
                        );

                        if (isLoading && catalog.isEmpty) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        return ListView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                          children: [
                            _hero(context, plan),
                            const SizedBox(height: 18),
                            _scenarioSelector(context),
                            const SizedBox(height: 18),
                            _preferencesPanel(context),
                            const SizedBox(height: 22),
                            _planHeader(context, plan),
                            const SizedBox(height: 12),
                            ...plan.items.map(
                              (item) => _planTile(context, item),
                            ),
                            const SizedBox(height: 18),
                            _safetyPanel(context, plan),
                            const SizedBox(height: 18),
                            SizedBox(
                              height: 56,
                              child: FilledButton.icon(
                                onPressed:
                                    plan.purchasableItems.isEmpty
                                        ? null
                                        : () => _confirmCreateCart(plan),
                                icon: const Icon(
                                  Icons.add_shopping_cart_rounded,
                                ),
                                label: Text(
                                  plan.purchasableItems.isEmpty
                                      ? 'Нет доступных товаров'
                                      : 'Подтвердить корзину • ${ShopProductMapper.formatPrice(plan.estimatedTotal)}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
    );
  }

  Widget _hero(BuildContext context, AiKitPlan plan) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 8),
            color: const Color(0xFF2563EB).withValues(alpha: 0.22),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.medical_services_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  plan.summary,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scenarioSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, 'Сценарий'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _scenario,
              isExpanded: true,
              items:
                  _scenarios
                      .map(
                        (scenario) => DropdownMenuItem(
                          value: scenario,
                          child: Text(scenario),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                if (value != null) _applyScenario(value);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _preferencesPanel(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          _switchTile(
            context,
            'Для ребенка',
            _forChild,
            (value) => setState(() => _forChild = value),
          ),
          _switchTile(
            context,
            'Поездка',
            _forTravel,
            (value) => setState(() => _forTravel = value),
          ),
          _switchTile(
            context,
            'Аллергия',
            _includeAllergy,
            (value) => setState(() => _includeAllergy = value),
          ),
          _switchTile(
            context,
            'ЖКТ',
            _includeDigestive,
            (value) => setState(() => _includeDigestive = value),
          ),
          _switchTile(
            context,
            'Простуда',
            _includeColdCare,
            (value) => setState(() => _includeColdCare = value),
          ),
          _switchTile(
            context,
            'Раны и ожоги',
            _includeWoundCare,
            (value) => setState(() => _includeWoundCare = value),
          ),
          _switchTile(
            context,
            'Хронические состояния',
            _hasChronicConditions,
            (value) => setState(() => _hasChronicConditions = value),
          ),
          _switchTile(
            context,
            'Беременность/ГВ',
            _pregnantOrBreastfeeding,
            (value) => setState(() => _pregnantOrBreastfeeding = value),
          ),
        ],
      ),
    );
  }

  Widget _switchTile(
    BuildContext context,
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      dense: true,
      title: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
      ),
      activeThumbColor: const Color(0xFF10B981),
    );
  }

  Widget _planHeader(BuildContext context, AiKitPlan plan) {
    return Row(
      children: [
        Expanded(child: _sectionTitle(context, 'План аптечки')),
        Text(
          '${plan.purchasableItems.length} в корзину',
          style: const TextStyle(
            color: Color(0xFF10B981),
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _planTile(BuildContext context, AiKitPlanItem item) {
    final color =
        item.alreadyCovered
            ? const Color(0xFF2563EB)
            : item.canPurchase
            ? const Color(0xFF10B981)
            : const Color(0xFFF59E0B);
    final status =
        item.alreadyCovered
            ? 'Уже есть'
            : item.canPurchase
            ? 'В корзину'
            : 'Уточнить';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              item.canPurchase
                  ? Icons.add_shopping_cart_rounded
                  : item.alreadyCovered
                  ? Icons.check_rounded
                  : Icons.info_outline_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.displayName,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      status,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  item.purpose,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.safetyNote.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.safetyNote,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _safetyPanel(BuildContext context, AiKitPlan plan) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined, color: Color(0xFFD97706), size: 20),
              SizedBox(width: 8),
              Text(
                'Безопасность',
                style: TextStyle(
                  color: Color(0xFF92400E),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...plan.safetyNotes
              .take(4)
              .map(
                (note) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '• $note',
                    style: const TextStyle(
                      color: Color(0xFF92400E),
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}
