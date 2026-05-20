import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

import '../../family/data/family_repository.dart';
import '../../family/models/family_member_model.dart';
import '../data/medicine_repository.dart';

class EditMedicineScreen extends StatefulWidget {
  final String medicineId;

  const EditMedicineScreen({super.key, required this.medicineId});

  @override
  State<EditMedicineScreen> createState() => _EditMedicineScreenState();
}

class _EditMedicineScreenState extends State<EditMedicineScreen> {
  final MedicineRepository _repository = MedicineRepository();
  final FamilyRepository _familyRepository = FamilyRepository();

  final nameCtrl = TextEditingController();
  final dosageCtrl = TextEditingController();
  final quantityCtrl = TextEditingController();
  final notesCtrl = TextEditingController();

  String selectedCategory = 'Обезболивающее';
  DateTime? selectedDate;
  String selectedOwner = 'me';

  bool isLoading = true;
  bool isSaving = false;

  List<FamilyMemberModel> familyMembers = [];

  final categories = const [
    'Обезболивающее',
    'Жаропонижающее',
    'Антибиотик',
    'Витамины',
    'Противовоспалительное',
    'Антисептик',
    'От аллергии',
    'ЖКТ',
    'Сорбенты',
    'Противовирусное',
    'От простуды',
    'Другое',
  ];

  List<String> get _categoryOptions {
    final options = [...categories];
    if (!options.contains(selectedCategory)) {
      options.add(selectedCategory);
    }
    return options;
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    dosageCtrl.dispose();
    quantityCtrl.dispose();
    notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        familyMembers =
            await _familyRepository.getFamilyMembersByUser(user.id).first;
      }

      final medicine = await _repository.getMedicineById(widget.medicineId);

      if (medicine == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Лекарство не найдено')));
        Navigator.pop(context);
        return;
      }

      nameCtrl.text = medicine.name;
      dosageCtrl.text = medicine.dosage;
      quantityCtrl.text = medicine.quantity.toString();
      notesCtrl.text = medicine.notes ?? '';
      selectedCategory = medicine.category;
      selectedDate = medicine.expiryDate;
      selectedOwner = medicine.familyMemberId ?? 'me';
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка загрузки: $e')));
      Navigator.pop(context);
      return;
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> pickDate() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );

    if (result != null) {
      setState(() {
        selectedDate = result;
      });
    }
  }

  Future<void> saveChanges() async {
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

    setState(() => isSaving = true);

    try {
      await _repository.updateMedicine(
        medicineId: widget.medicineId,
        name: nameCtrl.text.trim(),
        dosage: dosageCtrl.text.trim(),
        quantity: quantity,
        category: selectedCategory,
        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
        familyMemberId: selectedOwner == 'me' ? null : selectedOwner,
        expiryDate: selectedDate,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Изменения сохранены')));

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e')));
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
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
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
      appBar: AppBar(title: const Text('Редактировать лекарство')),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
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
                decoration: const InputDecoration(
                  hintText: 'Например: Парацетамол',
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedCategory,
                    isExpanded: true,
                    items:
                        _categoryOptions
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
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
                                  ? const Color(0xFF9CA3AF)
                                  : const Color(0xFF111827),
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
                  onPressed: isSaving ? null : saveChanges,
                  child:
                      isSaving
                          ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Text(
                            'Сохранить изменения',
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
