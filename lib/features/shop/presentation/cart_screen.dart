import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/state/cart_provider.dart';
import '../../b2b/inventory/data/b2b_inventory_repository.dart';
import '../data/shop_repository.dart';
import '../models/payment_method_model.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final ShopRepository _shopRepository = ShopRepository();
  final B2BInventoryRepository _inventoryRepository = B2BInventoryRepository();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  bool _isLoading = false;
  String? _selectedPaymentMethodId;

  @override
  void dispose() {
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
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

  int _quantityOf(Map<String, dynamic> item) {
    return (item['quantity'] as num?)?.toInt() ?? 1;
  }

  int _priceOf(Map<String, dynamic> item) {
    return int.tryParse(
          item['price'].toString().replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0;
  }

  Future<void> _showAddCardSheet() async {
    final numberCtrl = TextEditingController();
    final holderCtrl = TextEditingController();
    final monthCtrl = TextEditingController();
    final yearCtrl = TextEditingController();
    bool isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> saveCard() async {
              final number = numberCtrl.text.replaceAll(RegExp(r'\D'), '');
              final month = int.tryParse(monthCtrl.text.trim());
              final rawYear = int.tryParse(yearCtrl.text.trim());
              final year =
                  rawYear == null
                      ? null
                      : rawYear < 100
                      ? 2000 + rawYear
                      : rawYear;

              if (number.length < 12 || month == null || year == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Проверьте данные карты')),
                );
                return;
              }

              setSheetState(() => isSaving = true);
              try {
                final card = await _shopRepository.addFakeCard(
                  cardholderName: holderCtrl.text.trim(),
                  cardNumber: number,
                  expMonth: month,
                  expYear: year,
                );
                if (!mounted || !sheetContext.mounted) return;
                setState(() => _selectedPaymentMethodId = card.id);
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${card.brand} ${card.maskedNumber} добавлена',
                    ),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Ошибка карты: $e')));
              } finally {
                if (mounted && sheetContext.mounted) {
                  setSheetState(() => isSaving = false);
                }
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  20 + MediaQuery.of(sheetContext).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Добавить карту',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: numberCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Номер карты',
                        hintText: '4242 4242 4242 4242',
                        prefixIcon: Icon(Icons.credit_card_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: holderCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Имя на карте',
                        hintText: 'A AITBAEV',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: monthCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Месяц',
                              hintText: '12',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: yearCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Год',
                              hintText: '28',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: isSaving ? null : saveCard,
                        icon:
                            isSaving
                                ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.lock_rounded),
                        label: const Text('Сохранить fake-карту'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    numberCtrl.dispose();
    holderCtrl.dispose();
    monthCtrl.dispose();
    yearCtrl.dispose();
  }

  Future<void> _processCheckout(PaymentMethodModel? paymentMethod) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Войдите в аккаунт для оформления заказа'),
        ),
      );
      return;
    }

    if (paymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте или выберите карту')),
      );
      return;
    }

    if (_addressCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Укажите адрес и телефон')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final cartItems = CartProvider.instance.items;
      final itemsByOrganization = <String, List<Map<String, dynamic>>>{};

      for (final item in cartItems) {
        if (!item.containsKey('b2b_item')) {
          throw StateError('В корзине есть товар без складской карточки');
        }

        final itemId = item['id'] as String;
        final quantity = _quantityOf(item);
        final latest = await _inventoryRepository.getItemById(itemId);
        if (latest == null) {
          throw StateError('Товар "${item['title']}" больше недоступен');
        }
        if (latest.stock < quantity) {
          throw StateError(
            'Недостаточно товара "${latest.name}": доступно ${latest.stock} шт.',
          );
        }

        itemsByOrganization.putIfAbsent(latest.userId, () => []);
        itemsByOrganization[latest.userId]!.add({
          'inventory_id': latest.id,
          'quantity': quantity,
        });
      }

      for (final entry in itemsByOrganization.entries) {
        await _shopRepository.placeOrder(
          organizationId: entry.key,
          items: entry.value,
          paymentMethodId: paymentMethod.id,
          deliveryAddress: _addressCtrl.text.trim(),
          customerPhone: _phoneCtrl.text.trim(),
          customerNote:
              _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        );
      }

      CartProvider.instance.clearCart();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заказ оплачен и отправлен в аптеку')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка оформления: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _emptyCartState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 72,
            ),
            const SizedBox(height: 18),
            Text(
              'Корзина пока пуста',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.shop),
              icon: const Icon(Icons.storefront_rounded),
              label: const Text('Вернуться в магазин'),
            ),
          ],
        ),
      ),
    );
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
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHighest,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _checkoutDetails(List<PaymentMethodModel> methods) {
    if (_selectedPaymentMethodId == null && methods.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedPaymentMethodId == null) {
          setState(() => _selectedPaymentMethodId = methods.first.id);
        }
      });
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_rounded, color: Color(0xFF10B981)),
              const SizedBox(width: 8),
              Text(
                'Оплата и доставка',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _showAddCardSheet,
                icon: const Icon(Icons.add_card_rounded),
                label: const Text('Карта'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (methods.isEmpty)
            OutlinedButton.icon(
              onPressed: _showAddCardSheet,
              icon: const Icon(Icons.credit_card_rounded),
              label: const Text('Добавить fake-карту'),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _selectedPaymentMethodId ?? methods.first.id,
              decoration: const InputDecoration(
                labelText: 'Карта',
                prefixIcon: Icon(Icons.credit_card_rounded),
              ),
              items:
                  methods
                      .map(
                        (method) => DropdownMenuItem(
                          value: method.id,
                          child: Text(
                            '${method.brand} ${method.maskedNumber} • ${method.expiryLabel}',
                          ),
                        ),
                      )
                      .toList(),
              onChanged:
                  (value) => setState(() => _selectedPaymentMethodId = value),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressCtrl,
            decoration: const InputDecoration(
              labelText: 'Адрес доставки',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Телефон',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Комментарий',
              hintText: 'Например: позвонить за 10 минут',
            ),
          ),
        ],
      ),
    );
  }

  Widget _cartItemCard(Map<String, dynamic> item, int index) {
    final quantity = _quantityOf(item);
    final maxStock =
        item['b2b_item'] is Map<String, dynamic>
            ? ((item['b2b_item'] as Map<String, dynamic>)['stock'] as num?)
                ?.toInt()
            : null;
    final itemColor = item['color'] as Color;
    final iconColor = item['iconColor'] as Color;
    final icon = item['icon'] as IconData;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 4),
            color: Colors.black.withValues(alpha: 0.04),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: itemColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  _formatPrice(_priceOf(item) * quantity),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF10B981),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _quantityButton(
                      Icons.remove_rounded,
                      () => CartProvider.instance.decrementItem(index),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '$quantity',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    _quantityButton(Icons.add_rounded, () {
                      if (maxStock != null && quantity >= maxStock) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Больше нет на складе')),
                        );
                        return;
                      }
                      CartProvider.instance.incrementItem(index);
                    }),
                  ],
                ),
                if (maxStock != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Доступно: $maxStock шт',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Удалить',
            onPressed: () => CartProvider.instance.removeItem(index),
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFEF4444),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CartProvider.instance,
      builder: (context, _) {
        final cartItems = CartProvider.instance.items;
        final totalPrice = CartProvider.instance.totalPrice;

        return StreamBuilder<List<PaymentMethodModel>>(
          stream: _shopRepository.getPaymentMethods(),
          initialData: const [],
          builder: (context, paymentSnapshot) {
            final methods = paymentSnapshot.data ?? [];
            PaymentMethodModel? selectedPayment;
            for (final method in methods) {
              if (method.id == _selectedPaymentMethodId) {
                selectedPayment = method;
                break;
              }
            }
            selectedPayment ??= methods.isEmpty ? null : methods.first;

            return Scaffold(
              appBar: AppBar(title: const Text('Корзина')),
              body: SafeArea(
                child:
                    cartItems.isEmpty
                        ? _emptyCartState(context)
                        : Column(
                          children: [
                            Expanded(
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  12,
                                  20,
                                  12,
                                ),
                                itemCount: cartItems.length + 1,
                                separatorBuilder:
                                    (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  if (index == 0) {
                                    return _checkoutDetails(methods);
                                  }
                                  return _cartItemCard(
                                    cartItems[index - 1],
                                    index - 1,
                                  );
                                },
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                16,
                                20,
                                24,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                boxShadow: [
                                  BoxShadow(
                                    blurRadius: 12,
                                    offset: const Offset(0, -4),
                                    color: Colors.black.withValues(alpha: 0.04),
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
                                          '${CartProvider.instance.itemCount} товаров',
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
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 56,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF10B981,
                                          ),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          elevation: 0,
                                        ),
                                        onPressed:
                                            _isLoading
                                                ? null
                                                : () => _processCheckout(
                                                  selectedPayment,
                                                ),
                                        icon:
                                            _isLoading
                                                ? const SizedBox(
                                                  height: 20,
                                                  width: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white,
                                                      ),
                                                )
                                                : const Icon(
                                                  Icons.lock_rounded,
                                                ),
                                        label: Text(
                                          _isLoading
                                              ? 'Оплата...'
                                              : 'Оплатить и оформить',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
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
      },
    );
  }
}
