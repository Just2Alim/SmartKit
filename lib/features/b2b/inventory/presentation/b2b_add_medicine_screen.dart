import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/b2b_inventory_repository.dart';
import '../models/b2b_inventory_model.dart';

class B2BAddMedicineScreen extends StatefulWidget {
  const B2BAddMedicineScreen({super.key});

  @override
  State<B2BAddMedicineScreen> createState() => _B2BAddMedicineScreenState();
}

class _B2BAddMedicineScreenState extends State<B2BAddMedicineScreen> {
  final _repository = B2BInventoryRepository();

  final nameCtrl = TextEditingController();
  final stockCtrl = TextEditingController();
  final minStockCtrl = TextEditingController();
  final priceCtrl = TextEditingController();

  String selectedCategory = 'Обезболивающее';
  bool isLoading = false;

  final categories = const [
    'Обезболивающее',
    'Антибиотик',
    'Витамины',
    'Противовоспалительное',
    'Антисептик',
    'Другое',
  ];

  @override
  void dispose() {
    nameCtrl.dispose();
    stockCtrl.dispose();
    minStockCtrl.dispose();
    priceCtrl.dispose();
    super.dispose();
  }

  Future<void> saveItem() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пользователь не найден')),
      );
      return;
    }

    if (nameCtrl.text.trim().isEmpty ||
        stockCtrl.text.trim().isEmpty ||
        minStockCtrl.text.trim().isEmpty ||
        priceCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля')),
      );
      return;
    }

    final stock = int.tryParse(stockCtrl.text.trim());
    final minStock = int.tryParse(minStockCtrl.text.trim());
    final price = int.tryParse(priceCtrl.text.trim());

    if (stock == null || minStock == null || price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Количество, минимум и цена должны быть числами')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final item = B2BInventoryModel(
        id: '',
        userId: user.uid,
        name: nameCtrl.text.trim(),
        category: selectedCategory,
        stock: stock,
        minStock: minStock,
        price: price,
        createdAt: DateTime.now(),
      );

      await _repository.addItem(item);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Товар добавлен')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сохранения: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF111827),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Добавить товар'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Название'),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  hintText: 'Например: Парацетамол',
                ),
              ),
              const SizedBox(height: 16),

              _label('Категория'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedCategory,
                    isExpanded: true,
                    items: categories
                        .map(
                          (category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        selectedCategory = value;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _label('Остаток на складе'),
              TextField(
                controller: stockCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Например: 100',
                ),
              ),
              const SizedBox(height: 16),

              _label('Минимальный остаток'),
              TextField(
                controller: minStockCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Например: 10',
                ),
              ),
              const SizedBox(height: 16),

              _label('Цена, ₸'),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Например: 2500',
                ),
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: isLoading ? null : saveItem,
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Сохранить',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}