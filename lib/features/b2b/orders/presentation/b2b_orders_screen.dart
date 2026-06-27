import 'package:flutter/material.dart';

import '../../../shop/data/shop_repository.dart';
import '../../../shop/models/shop_order_model.dart';
import '../../../shop/utils/shop_product_mapper.dart';

class B2BOrdersScreen extends StatefulWidget {
  const B2BOrdersScreen({super.key});

  @override
  State<B2BOrdersScreen> createState() => _B2BOrdersScreenState();
}

class _B2BOrdersScreenState extends State<B2BOrdersScreen> {
  final ShopRepository _repository = ShopRepository();
  String _filter = 'active';
  bool _isUpdating = false;

  final _filters = const [
    ('active', 'Активные'),
    ('paid', 'Оплачены'),
    ('assembling', 'Сборка'),
    ('ready', 'Готовы'),
    ('final', 'Завершены'),
  ];

  List<ShopOrderModel> _filterOrders(List<ShopOrderModel> orders) {
    switch (_filter) {
      case 'paid':
        return orders.where((order) => order.status == 'paid').toList();
      case 'assembling':
        return orders
            .where(
              (order) =>
                  order.status == 'confirmed' || order.status == 'assembling',
            )
            .toList();
      case 'ready':
        return orders.where((order) => order.status == 'ready').toList();
      case 'final':
        return orders.where((order) => order.isFinal).toList();
      default:
        return orders.where((order) => !order.isFinal).toList();
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'Оплачен';
      case 'confirmed':
        return 'Подтвержден';
      case 'assembling':
        return 'Собирается';
      case 'ready':
        return 'Готов';
      case 'delivered':
        return 'Выдан';
      case 'cancelled':
        return 'Отменен';
      default:
        return 'Новый';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'cancelled':
        return const Color(0xFFDC2626);
      case 'delivered':
        return const Color(0xFF047857);
      case 'ready':
        return const Color(0xFF2563EB);
      case 'assembling':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF10B981);
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month.${date.year} $hour:$minute';
  }

  String _shortId(String id) => id.length <= 8 ? id : id.substring(0, 8);

  List<({String status, String label, IconData icon})> _actionsFor(
    ShopOrderModel order,
  ) {
    switch (order.status) {
      case 'paid':
        return const [
          (
            status: 'confirmed',
            label: 'Подтвердить',
            icon: Icons.check_circle_rounded,
          ),
          (status: 'cancelled', label: 'Отменить', icon: Icons.cancel_rounded),
        ];
      case 'confirmed':
        return const [
          (
            status: 'assembling',
            label: 'В сборку',
            icon: Icons.inventory_rounded,
          ),
          (status: 'cancelled', label: 'Отменить', icon: Icons.cancel_rounded),
        ];
      case 'assembling':
        return const [
          (status: 'ready', label: 'Готов', icon: Icons.task_alt_rounded),
        ];
      case 'ready':
        return const [
          (
            status: 'delivered',
            label: 'Выдан',
            icon: Icons.local_shipping_rounded,
          ),
        ];
      default:
        return const [];
    }
  }

  Future<void> _updateStatus(ShopOrderModel order, String status) async {
    String? reason;
    if (status == 'cancelled') {
      reason = await showDialog<String>(
        context: context,
        builder: (context) {
          final ctrl = TextEditingController();
          return AlertDialog(
            title: const Text('Отменить заказ'),
            content: TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Причина',
                hintText: 'Например: нет товара',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Назад'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, ctrl.text.trim()),
                child: const Text('Отменить заказ'),
              ),
            ],
          );
        },
      );
      if (reason == null) return;
    }

    setState(() => _isUpdating = true);
    try {
      await _repository.updateOrderStatus(
        orderId: order.id,
        status: status,
        cancellationReason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Статус: ${_statusLabel(status)}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Не удалось обновить: $e')));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: StreamBuilder<List<ShopOrderModel>>(
          stream: _repository.getOrdersForCurrentOrganization(),
          initialData: const [],
          builder: (context, snapshot) {
            final allOrders = snapshot.data ?? [];
            final orders = _filterOrders(allOrders);
            final activeCount =
                allOrders.where((order) => !order.isFinal).length;

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _header(activeCount)),
                SliverToBoxAdapter(child: _filterChips()),
                if (snapshot.hasError)
                  SliverFillRemaining(
                    child: Center(child: Text('Ошибка: ${snapshot.error}')),
                  )
                else if (orders.isEmpty)
                  const SliverFillRemaining(
                    child: Center(child: Text('Заказов в этом статусе нет')),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
                    sliver: SliverList.separated(
                      itemCount: orders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder:
                          (context, index) => _orderCard(orders[index]),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(int activeCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF064E3B), Color(0xFF10B981)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.fact_check_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Онлайн-заказы',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$activeCount активных заказов в работе',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChips() {
    return SizedBox(
      height: 50,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = _filters[index];
          final selected = item.$1 == _filter;
          return ChoiceChip(
            selected: selected,
            label: Text(item.$2),
            onSelected: (_) => setState(() => _filter = item.$1),
            selectedColor: const Color(0xFF10B981),
            labelStyle: TextStyle(
              color:
                  selected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
            backgroundColor: Theme.of(context).cardColor,
          );
        },
      ),
    );
  }

  Widget _orderCard(ShopOrderModel order) {
    final color = _statusColor(order.status);
    final actions = _actionsFor(order);
    final card = order.paymentSnapshot;
    final paymentLabel =
        '${card['brand'] ?? 'Card'} •••• ${card['last4'] ?? '0000'}';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Заказ #${_shortId(order.id)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(order.status),
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatDate(order.createdAt)} • $paymentLabel',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...order.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.name} × ${item.quantity}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    ShopProductMapper.formatPrice(item.lineTotal),
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  [
                    if ((order.customerPhone ?? '').isNotEmpty)
                      order.customerPhone!,
                    if ((order.deliveryAddress ?? '').isNotEmpty)
                      order.deliveryAddress!,
                  ].join(' • '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                ShopProductMapper.formatPrice(order.totalAmount),
                style: const TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  actions
                      .map(
                        (action) => FilledButton.icon(
                          onPressed:
                              _isUpdating
                                  ? null
                                  : () => _updateStatus(order, action.status),
                          icon: Icon(action.icon, size: 18),
                          label: Text(action.label),
                        ),
                      )
                      .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
