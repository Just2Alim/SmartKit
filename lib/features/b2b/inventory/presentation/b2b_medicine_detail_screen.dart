import 'package:flutter/material.dart';

import '../data/b2b_inventory_repository.dart';
import '../models/b2b_inventory_model.dart';

class B2BMedicineDetailScreen extends StatefulWidget {
  final String medicineId;

  const B2BMedicineDetailScreen({
    super.key,
    required this.medicineId,
  });

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
    return const Color(0xFF16A34A);
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Товар удалён')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка удаления: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Детали товара'),
      ),
      body: FutureBuilder<B2BInventoryModel?>(
        future: _repository.getItemById(widget.medicineId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Ошибка: ${snapshot.error}'),
            );
          }

          final item = snapshot.data;

          if (item == null) {
            return const Center(
              child: Text('Товар не найден'),
            );
          }

          final statusColor = _statusColor(item);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        statusColor.withOpacity(0.85),
                        statusColor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                        color: statusColor.withOpacity(0.25),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(
                          Icons.inventory_2_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        item.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _statusText(item),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.92),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                _infoCard(
                  title: 'Информация о товаре',
                  children: [
                    _infoRow('Категория', item.category),
                    _infoRow('Цена', _formatPrice(item.price)),
                    _infoRow('Остаток', '${item.stock} шт'),
                    _infoRow('Минимальный остаток', '${item.minStock} шт'),
                    _infoRow('Дата добавления', _formatDate(item.createdAt)),
                  ],
                ),

                const SizedBox(height: 16),

                _infoCard(
                  title: 'Статус склада',
                  children: [
                    _statusBox(item),
                  ],
                ),

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                    ),
                    onPressed: isDeleting ? null : _deleteItem,
                    icon: isDeleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.delete_outline_rounded),
                    label: Text(
                      isDeleting ? 'Удаление...' : 'Удалить товар',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 4),
            color: Colors.black.withOpacity(0.04),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBox(B2BInventoryModel item) {
    final color = _statusColor(item);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _statusText(item),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}