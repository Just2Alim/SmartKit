import '../../features/b2b/inventory/data/b2b_inventory_repository.dart';
import '../../features/b2b/inventory/data/b2b_locations_repository.dart';
import '../../features/b2b/inventory/data/b2b_sales_repository.dart';
import '../../features/b2b/inventory/models/b2b_inventory_model.dart';
import '../../features/b2b/inventory/models/b2b_sale_model.dart';
import '../../features/b2b/inventory/models/b2b_location_model.dart';

class DbSeeder {
  static Future<void> seedB2BInventory(String userId) async {
    final repository = B2BInventoryRepository();

    final sampleItems = [
      B2BInventoryModel(
        id: 'nu_001',
        name: 'Нурофен Экспресс',
        category: 'Обезболивающее',
        stock: 150,
        minStock: 20,
        price: 1250,
        userId: userId,
        expiryDate: DateTime.now().add(const Duration(days: 365)),
        createdAt: DateTime.now(),
      ),
      B2BInventoryModel(
        id: 'pa_002',
        name: 'Парацетамол',
        category: 'Жаропонижающее',
        stock: 300,
        minStock: 50,
        price: 450,
        userId: userId,
        expiryDate: DateTime.now().add(const Duration(days: 500)),
        createdAt: DateTime.now(),
      ),
      B2BInventoryModel(
        id: 'sm_003',
        name: 'Смекта',
        category: 'ЖКТ',
        stock: 80,
        minStock: 15,
        price: 850,
        userId: userId,
        expiryDate: DateTime.now().add(const Duration(days: 200)),
        createdAt: DateTime.now(),
      ),
      B2BInventoryModel(
        id: 'li_004',
        name: 'Линекс Форте',
        category: 'ЖКТ',
        stock: 45,
        minStock: 10,
        price: 2100,
        userId: userId,
        expiryDate: DateTime.now().add(const Duration(days: 400)),
        createdAt: DateTime.now(),
      ),
      B2BInventoryModel(
        id: 'su_005',
        name: 'Супрастин',
        category: 'Аллергия',
        stock: 120,
        minStock: 20,
        price: 980,
        userId: userId,
        expiryDate: DateTime.now().add(
          const Duration(days: 10),
        ), // Скоро истекает
        createdAt: DateTime.now(),
      ),
      B2BInventoryModel(
        id: 'vi_006',
        name: 'Витамин C (1000мг)',
        category: 'Витамины',
        stock: 500,
        minStock: 100,
        price: 1500,
        userId: userId,
        expiryDate: DateTime.now().add(const Duration(days: 730)),
        createdAt: DateTime.now(),
      ),
      B2BInventoryModel(
        id: 'as_007',
        name: 'Аспирин Кардио',
        category: 'Сердце',
        stock: 200,
        minStock: 30,
        price: 1800,
        userId: userId,
        expiryDate: DateTime.now().add(const Duration(days: 450)),
        createdAt: DateTime.now(),
      ),
      B2BInventoryModel(
        id: 'en_008',
        name: 'Энтеросгель',
        category: 'Сорбенты',
        stock: 60,
        minStock: 5,
        price: 3200,
        userId: userId,
        expiryDate: DateTime.now().add(const Duration(days: 300)),
        createdAt: DateTime.now(),
      ),
      B2BInventoryModel(
        id: 'mi_009',
        name: 'Мирамистин 150мл',
        category: 'Антисептики',
        stock: 85,
        minStock: 15,
        price: 2400,
        userId: userId,
        expiryDate: DateTime.now().add(const Duration(days: 600)),
        createdAt: DateTime.now(),
      ),
      B2BInventoryModel(
        id: 'ka_010',
        name: 'Канефрон Н',
        category: 'Почки',
        stock: 40,
        minStock: 8,
        price: 4500,
        userId: userId,
        expiryDate: DateTime.now().add(const Duration(days: 250)),
        createdAt: DateTime.now(),
      ),
    ];

    for (var item in sampleItems) {
      await repository.addItem(item);
    }
  }

  static Future<void> seedB2BSales(String userId) async {
    final repository = B2BSalesRepository();

    final now = DateTime.now();
    final sampleSales = [
      B2BSaleModel(
        id: 's_001',
        items: [
          {'name': 'Нурофен Экспресс', 'quantity': 2, 'price': 1250},
          {'name': 'Парацетамол', 'quantity': 5, 'price': 450},
        ],
        totalAmount: 4750,
        saleDate: now.subtract(const Duration(hours: 2)),
        userId: userId,
      ),
      B2BSaleModel(
        id: 's_002',
        items: [
          {'name': 'Смекта', 'quantity': 10, 'price': 850},
        ],
        totalAmount: 8500,
        saleDate: now.subtract(const Duration(days: 1)),
        userId: userId,
      ),
      B2BSaleModel(
        id: 's_003',
        items: [
          {'name': 'Линекс Форте', 'quantity': 1, 'price': 2100},
          {'name': 'Супрастин', 'quantity': 3, 'price': 980},
        ],
        totalAmount: 5040,
        saleDate: now.subtract(const Duration(days: 2)),
        userId: userId,
      ),
      B2BSaleModel(
        id: 's_004',
        items: [
          {'name': 'Аспирин Кардио', 'quantity': 4, 'price': 1800},
        ],
        totalAmount: 7200,
        saleDate: now.subtract(const Duration(days: 3)),
        userId: userId,
      ),
      B2BSaleModel(
        id: 's_005',
        items: [
          {'name': 'Витамин C (1000мг)', 'quantity': 20, 'price': 1500},
        ],
        totalAmount: 30000,
        saleDate: now.subtract(const Duration(days: 5)),
        userId: userId,
      ),
    ];

    for (var sale in sampleSales) {
      await repository.recordSale(sale);
    }
  }

  static Future<void> seedB2BLocations(String userId) async {
    final repository = B2BLocationsRepository();

    final sampleLocations = [
      B2BLocationModel(
        id: 'loc_001',
        userId: userId,
        name: 'Центральный склад',
        type: 'Warehouse',
        address: 'ул. Достык, 12, Алматы',
        currentItems: 4500,
        capacity: 10000,
        status: 'Active',
      ),
      B2BLocationModel(
        id: 'loc_002',
        userId: userId,
        name: 'Филиал на Абая',
        type: 'Pharmacy',
        address: 'пр. Абая, 44, Алматы',
        currentItems: 1200,
        capacity: 1500,
        status: 'Full',
      ),
      B2BLocationModel(
        id: 'loc_003',
        userId: userId,
        name: 'Резервное хранилище',
        type: 'Warehouse',
        address: 'мкр. Аксай-2, 18, Алматы',
        currentItems: 800,
        capacity: 5000,
        status: 'Active',
      ),
    ];

    for (var loc in sampleLocations) {
      await repository.addLocation(loc);
    }
  }
}
