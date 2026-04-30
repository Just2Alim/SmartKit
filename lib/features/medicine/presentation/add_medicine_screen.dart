import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../family/data/family_repository.dart';
import '../../family/models/family_member_model.dart';
import '../data/medicine_repository.dart';
import '../models/medicine_model.dart';
import '../../../core/router/app_routes.dart';


class AddMedicineScreen extends StatefulWidget {
  final String? preselectedMemberId;
  final String? initialName;
  final String? initialCategory;

  const AddMedicineScreen({
    super.key, 
    this.preselectedMemberId,
    this.initialName,
    this.initialCategory,
  });

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _repository = MedicineRepository();
  final _familyRepository = FamilyRepository();

  final nameCtrl = TextEditingController();
  final dosageCtrl = TextEditingController();
  final quantityCtrl = TextEditingController();
  final notesCtrl = TextEditingController();

  String selectedCategory = 'Обезболивающее';
  DateTime? selectedDate;
  bool isLoading = false;

  String selectedOwner = 'me';
  List<FamilyMemberModel> familyMembers = [];

  final categories = [
    'Обезболивающее',
    'Антибиотик',
    'Витамины',
    'Противовоспалительное',
    'Другое',
  ];

  @override
  void initState() {
    super.initState();
    _loadFamilyMembers();

    if (widget.preselectedMemberId != null) {
      selectedOwner = widget.preselectedMemberId!;
    }
    
    if (widget.initialName != null) {
      nameCtrl.text = widget.initialName!;
    }
    
    if (widget.initialCategory != null && categories.contains(widget.initialCategory)) {
      selectedCategory = widget.initialCategory!;
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    dosageCtrl.dispose();
    quantityCtrl.dispose();
    notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFamilyMembers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _familyRepository.getFamilyMembersByUser(user.uid).first.then((members) {
      if (!mounted) return;
      setState(() {
        familyMembers = members;
      });
    });
  }

  Future<void> pickDate() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 10),
    );

    if (result != null) {
      setState(() {
        selectedDate = result;
      });
    }
  }

  Future<void> saveMedicine() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Пользователь не найден')));
      return;
    }

    if (nameCtrl.text.trim().isEmpty ||
        dosageCtrl.text.trim().isEmpty ||
        quantityCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните обязательные поля')),
      );
      return;
    }

    final quantity = int.tryParse(quantityCtrl.text.trim());
    if (quantity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Количество должно быть числом')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final medicine = MedicineModel(
        id: '',
        userId: user.uid,
        familyMemberId: selectedOwner == 'me' ? null : selectedOwner,
        name: nameCtrl.text.trim(),
        dosage: dosageCtrl.text.trim(),
        quantity: quantity,
        category: selectedCategory,
        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
        expiryDate: selectedDate,
        createdAt: DateTime.now(),
      );

      await _repository.addMedicine(medicine);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Лекарство сохранено')));

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e')));
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
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ownerItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: 'me', child: Text('Для меня')),
      ...familyMembers.map(
        (member) => DropdownMenuItem(
          value: member.id,
          child: Text('${member.name} (${member.relation})'),
        ),
      ),
    ];

    return Scaffold(

      appBar: AppBar(title: const Text('Добавить лекарство')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Для кого'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedOwner,
                    isExpanded: true,
                    items: ownerItems,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        selectedOwner = value;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _label('Название'),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  hintText: 'Например: Парацетамол',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    onPressed: () async {
                      final result = await Navigator.pushNamed(context, AppRoutes.scanBarcode);
                      if (result != null && result is Map<String, dynamic> && result['manual'] != true) {
                        setState(() {
                          nameCtrl.text = result['name'] ?? nameCtrl.text;
                          if (result['category'] != null && categories.contains(result['category'])) {
                            selectedCategory = result['category'];
                          }
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _label('Дозировка'),
              TextField(
                controller: dosageCtrl,
                decoration: const InputDecoration(hintText: 'Например: 500 мг'),
              ),
              const SizedBox(height: 16),

              _label('Количество'),
              TextField(
                controller: quantityCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'Например: 20'),
              ),
              const SizedBox(height: 16),

              _label('Категория'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedCategory,
                    isExpanded: true,
                    items:
                        categories
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

              _label('Срок годности'),
              InkWell(
                onTap: pickDate,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 18,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        selectedDate == null
                            ? 'Выбрать дату'
                            : '${selectedDate!.day.toString().padLeft(2, '0')}.${selectedDate!.month.toString().padLeft(2, '0')}.${selectedDate!.year}',
                        style: TextStyle(
                          color:
                              selectedDate == null
                                  ? Theme.of(context).colorScheme.onSurfaceVariant
                                  : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _label('Заметки'),
              TextField(
                controller: notesCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Дополнительная информация...',
                ),
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: isLoading ? null : saveMedicine,
                  child:
                      isLoading
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
