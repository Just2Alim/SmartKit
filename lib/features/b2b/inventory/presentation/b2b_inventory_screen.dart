import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/router/app_routes.dart';
import '../data/b2b_inventory_repository.dart';
import '../models/b2b_inventory_model.dart';

class B2BInventoryScreen extends StatelessWidget {
  B2BInventoryScreen({super.key});

  final B2BInventoryRepository _repository = B2BInventoryRepository();

  Color _statusColor(B2BInventoryModel item) {
    if (item.stock <= item.minStock) {
      return const Color(0xFFDC2626); // Critical red
    }
    if (item.stock <= item.minStock * 2) {
      return const Color(0xFFF59E0B); // Warning amber
    }
    return const Color(0xFF10B981); // Emerald success
  }

  String _statusText(B2BInventoryModel item) {
    if (item.stock <= item.minStock) {
      return 'Критично';
    }
    if (item.stock <= item.minStock * 2) {
      return 'Низкий';
    }
    return 'В норме';
  }

  String _formatPrice(int price) {
    return '$price ₸';
  }

  Future<void> _deleteItem(
    BuildContext context,
    B2BInventoryModel item,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: const Text('Удалить товар', style: TextStyle(fontWeight: FontWeight.w900)),
          content: Text('Удалить "${item.name}" из инвентаря склада?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _repository.deleteItem(item.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: user == null
          ? const Center(child: Text('Пользователь не найден'))
          : StreamBuilder<List<B2BInventoryModel>>(
              stream: _repository.getItemsByUser(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
                }

                final items = snapshot.data ?? [];

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _buildAppBar(context),
                    if (items.isEmpty)
                      _buildEmptyState()
                    else
                      SliverPadding(
                        padding: const EdgeInsets.all(20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _inventoryItemCard(context, items[index]),
                            childCount: items.length,
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.b2bAddMedicine),
        backgroundColor: const Color(0xFF10B981),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Добавить товар', style: TextStyle(fontWeight: FontWeight.w800)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF10B981),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: const Text(
          'Инвентарь склада',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -20,
                child: Icon(Icons.inventory_2_rounded, size: 140, color: Colors.white.withOpacity(0.1)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20),
                ],
              ),
              child: Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[300]),
            ),
            const SizedBox(height: 24),
            const Text(
              'Склад пока пуст',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Начните добавлять товары в ваш инвентарь',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inventoryItemCard(BuildContext context, B2BInventoryModel item) {
    final statusColor = _statusColor(item);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.b2bMedicineDetail,
                  arguments: item.id,
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(Icons.medication_rounded, color: statusColor, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1E293B),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.category} • ${_formatPrice(item.price)}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _infoChip('В наличии: ${item.stock}', statusColor),
                              const SizedBox(width: 8),
                              _infoChip('Мин: ${item.minStock}', const Color(0xFF94A3B8)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _statusTag(item),
                        const SizedBox(height: 8),
                        IconButton(
                          onPressed: () => _deleteItem(context, item),
                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF94A3B8), size: 22),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _statusTag(B2BInventoryModel item) {
    final color = _statusColor(item);
    final text = _statusText(item);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}