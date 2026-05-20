import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import '../data/b2b_locations_repository.dart';
import '../data/b2b_inventory_repository.dart';
import '../models/b2b_location_model.dart';
import '../models/b2b_inventory_model.dart';
import 'b2b_location_inventory_screen.dart';
import '../../../../core/utils/db_seeder.dart';

class B2BLocationsScreen extends StatelessWidget {
  const B2BLocationsScreen({super.key});

  void _showLocationDialog(BuildContext context, {B2BLocationModel? location}) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final nameController = TextEditingController(text: location?.name);
    final addressController = TextEditingController(text: location?.address);
    final capacityController = TextEditingController(
      text: location?.capacity.toString() ?? '1000',
    );
    String selectedType = location?.type ?? 'Warehouse';
    String selectedStatus = location?.status ?? 'Active';

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  title: Text(
                    location == null ? 'Новая точка' : 'Редактировать',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: 'Название',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: addressController,
                          decoration: InputDecoration(
                            labelText: 'Адрес',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: capacityController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Вместимость (ед.)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedType,
                          decoration: InputDecoration(
                            labelText: 'Тип объекта',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Warehouse',
                              child: Text('Склад'),
                            ),
                            DropdownMenuItem(
                              value: 'Pharmacy',
                              child: Text('Аптека'),
                            ),
                            DropdownMenuItem(
                              value: 'Storage',
                              child: Text('Хранилище'),
                            ),
                          ],
                          onChanged:
                              (val) => setState(() => selectedType = val!),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedStatus,
                          decoration: InputDecoration(
                            labelText: 'Статус',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Active',
                              child: Text('Активен'),
                            ),
                            DropdownMenuItem(
                              value: 'Full',
                              child: Text('Заполнен'),
                            ),
                            DropdownMenuItem(
                              value: 'Maintenance',
                              child: Text('Тех. работы'),
                            ),
                          ],
                          onChanged:
                              (val) => setState(() => selectedStatus = val!),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Отмена',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final newLocation = B2BLocationModel(
                          id: location?.id ?? '',
                          userId: user.id,
                          name: nameController.text,
                          type: selectedType,
                          address: addressController.text,
                          currentItems: location?.currentItems ?? 0,
                          capacity:
                              int.tryParse(capacityController.text) ?? 1000,
                          status: selectedStatus,
                        );

                        final repo = B2BLocationsRepository();
                        if (location == null) {
                          await repo.addLocation(newLocation);
                        } else {
                          await repo.updateLocation(newLocation);
                        }
                        if (context.mounted) Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        location == null ? 'Создать' : 'Сохранить',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final locationsRepository = B2BLocationsRepository();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body:
          user == null
              ? const Center(child: Text('Пользователь не найден'))
              : StreamBuilder<List<B2BLocationModel>>(
                stream: locationsRepository.getLocationsByUser(user.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF10B981),
                      ),
                    );
                  }

                  final locations = snapshot.data ?? [];

                  if (locations.isEmpty) {
                    DbSeeder.seedB2BLocations(user.id);
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF10B981),
                      ),
                    );
                  }

                  return CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      _buildAppBar(context),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _LocationCard(
                              location: locations[index],
                              onEdit:
                                  () => _showLocationDialog(
                                    context,
                                    location: locations[index],
                                  ),
                            ),
                            childCount: locations.length,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLocationDialog(context),
        backgroundColor: const Color(0xFF1E293B),
        icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
        label: const Text(
          'Добавить точку',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF10B981),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: const Text(
          'Локации и склады',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: 0,
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
                top: 40,
                child: Icon(
                  Icons.business_rounded,
                  size: 150,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final B2BLocationModel location;
  final VoidCallback onEdit;

  const _LocationCard({required this.location, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final inventoryRepo = B2BInventoryRepository();

    return StreamBuilder<List<B2BInventoryModel>>(
      stream: inventoryRepo.getItemsByLocation(location.id),
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        final itemCount = items.length;
        final totalStock = items.fold<int>(0, (sum, item) => sum + item.stock);
        final occupancy =
            location.capacity > 0
                ? (totalStock / location.capacity).clamp(0.0, 1.0)
                : 0.0;
        final statusColor =
            occupancy >= 1.0
                ? const Color(0xFFEF4444)
                : (location.status == 'Active'
                    ? const Color(0xFF10B981)
                    : const Color(0xFFF59E0B));
        final statusText =
            occupancy >= 1.0
                ? 'Переполнен'
                : (location.status == 'Active' ? 'Активен' : 'Заполнен');

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha:
                      Theme.of(context).brightness == Brightness.dark
                          ? 0.22
                          : 0.05,
                ),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF064E3B)
                              : const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      location.type == 'Warehouse'
                          ? Icons.warehouse_rounded
                          : Icons.local_pharmacy_rounded,
                      color: const Color(0xFF10B981),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).colorScheme.onSurface,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          location.address,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Загрузка хранилища',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${(occupancy * 100).toInt()}%',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: occupancy,
                  minHeight: 8,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _infoTile(
                    context,
                    Icons.inventory_2_outlined,
                    '$itemCount',
                    'Позиций',
                  ),
                  const SizedBox(width: 32),
                  _infoTile(
                    context,
                    Icons.shopping_basket_outlined,
                    '$totalStock',
                    'Всего ед.',
                  ),
                  const SizedBox(width: 32),
                  _infoTile(
                    context,
                    Icons.storage_rounded,
                    '${location.capacity}',
                    'Емкость',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onEdit,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Изменить',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => B2BLocationInventoryScreen(
                                  location: location,
                                ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Инвентарь',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoTile(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
