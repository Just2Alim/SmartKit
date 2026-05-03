import 'package:flutter/material.dart';

import '../../../../core/router/app_routes.dart';
import '../data/b2b_inventory_repository.dart';
import '../models/b2b_inventory_model.dart';

class B2BMedicineDetailScreen extends StatefulWidget {
  final String medicineId;

  const B2BMedicineDetailScreen({super.key, required this.medicineId});

  @override
  State<B2BMedicineDetailScreen> createState() =>
      _B2BMedicineDetailScreenState();
}

class _B2BMedicineDetailScreenState extends State<B2BMedicineDetailScreen> {
  final B2BInventoryRepository _repository = B2BInventoryRepository();
  bool isDeleting = false;

  Color _statusColor(B2BInventoryModel item) {
    if (item.stock <= item.minStock) return const Color(0xFFDC2626);
    if (item.stock <= item.minStock * 2) return const Color(0xFFEA580C);
    return const Color(0xFF10B981);
  }

  String _statusText(B2BInventoryModel item) {
    if (item.stock <= item.minStock) return 'Критический остаток';
    if (item.stock <= item.minStock * 2) return 'Низкий остаток';
    return 'Остаток в норме';
  }

  String _formatPrice(int price) {
    return '$price ₸';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String _formatOptionalDate(DateTime? date) {
    return date == null ? 'Не указан' : _formatDate(date);
  }

  Future<void> _deleteItem() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Удалить товар'),
          content: const Text('Вы уверены, что хотите удалить этот товар?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => isDeleting = true);

    try {
      await _repository.deleteItem(widget.medicineId);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Товар удалён')));

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка удаления: $e')));
    } finally {
      if (mounted) {
        setState(() => isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: FutureBuilder<B2BInventoryModel?>(
        future: _repository.getItemById(widget.medicineId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF10B981)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ошибка: ${snapshot.error}',
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                ],
              ),
            );
          }

          final item = snapshot.data;

          if (item == null) {
            return const Center(
              child: Text(
                'Товар не найден',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            );
          }

          final statusColor = _statusColor(item);

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                stretch: true,
                backgroundColor: statusColor,
                elevation: 0,
                leading: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    onPressed: () async {
                      final updated = await Navigator.pushNamed(
                        context,
                        AppRoutes.b2bAddMedicine,
                        arguments: item.id,
                      );
                      if (updated == true && mounted) {
                        setState(() {});
                      }
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.zoomBackground,
                    StretchMode.blurBackground,
                  ],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [statusColor.withOpacity(0.8), statusColor],
                          ),
                        ),
                      ),
                      Center(
                        child: Hero(
                          tag: 'medicine_${item.id}',
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: const Icon(
                              Icons.medication_rounded,
                              color: Colors.white,
                              size: 64,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item.category,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _statusTag(item),
                          ],
                        ),
                        const SizedBox(height: 32),

                        _sectionTitle('Информация о товаре'),
                        const SizedBox(height: 16),
                        _infoGrid(item),

                        const SizedBox(height: 32),
                        _sectionTitle('Управление запасами'),
                        const SizedBox(height: 16),
                        _stockControlCard(item),

                        const SizedBox(height: 40),
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFF1F2),
                              foregroundColor: const Color(0xFFE11D48),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: const BorderSide(
                                  color: Color(0xFFFECDD3),
                                ),
                              ),
                            ),
                            onPressed: isDeleting ? null : _deleteItem,
                            icon:
                                isDeleting
                                    ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFFE11D48),
                                      ),
                                    )
                                    : const Icon(Icons.delete_outline_rounded),
                            label: Text(
                              isDeleting ? 'Удаление...' : 'Удалить из базы',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: Theme.of(context).colorScheme.onSurface,
        letterSpacing: 0,
      ),
    );
  }

  Widget _infoGrid(B2BInventoryModel item) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        _gridItem('Цена', _formatPrice(item.price), Icons.payments_outlined),
        _gridItem(
          'Текущий остаток',
          '${item.stock} шт',
          Icons.inventory_2_outlined,
        ),
        _gridItem('Минимум', '${item.minStock} шт', Icons.low_priority_rounded),
        if ((item.dosage ?? '').isNotEmpty)
          _gridItem('Дозировка', item.dosage!, Icons.science_outlined),
        if ((item.packageSize ?? '').isNotEmpty)
          _gridItem('Упаковка', item.packageSize!, Icons.all_inbox_outlined),
        if ((item.manufacturer ?? '').isNotEmpty)
          _gridItem(
            'Производитель',
            item.manufacturer!,
            Icons.factory_outlined,
          ),
        if ((item.batchNumber ?? '').isNotEmpty)
          _gridItem('Серия', item.batchNumber!, Icons.qr_code_2_rounded),
        _gridItem(
          'Срок годности',
          _formatOptionalDate(item.expiryDate),
          Icons.event_available_outlined,
        ),
        _gridItem(
          'Создано',
          _formatDate(item.createdAt),
          Icons.calendar_today_outlined,
        ),
      ],
    );
  }

  Widget _gridItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stockControlCard(B2BInventoryModel item) {
    final color = _statusColor(item);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.analytics_outlined, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _statusText(item),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value:
                  item.stock /
                  (item.minStock * 4)
                      .clamp(item.stock, double.infinity)
                      .toDouble(),
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusTag(B2BInventoryModel item) {
    final color = _statusColor(item);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        item.stock > item.minStock ? 'В наличии' : 'Мало',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
