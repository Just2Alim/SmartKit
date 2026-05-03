import 'package:flutter/material.dart';
import '../data/b2b_inventory_repository.dart';
import '../models/b2b_inventory_model.dart';
import '../models/b2b_location_model.dart';

class B2BLocationInventoryScreen extends StatelessWidget {
  final B2BLocationModel location;

  const B2BLocationInventoryScreen({super.key, required this.location});

  @override
  Widget build(BuildContext context) {
    final inventoryRepo = B2BInventoryRepository();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              location.name,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            Text(
              'Инвентарь локации',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<List<B2BInventoryModel>>(
        stream: inventoryRepo.getItemsByLocation(location.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
          }

          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'В этой локации пока нет товаров',
                    style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.medication_rounded, color: Color(0xFF10B981)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                          ),
                          Text(
                            item.category,
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${item.stock} ед.',
                          style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                        ),
                        if (item.stock <= item.minStock)
                          const Text(
                            'Мало!',
                            style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.w800),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
