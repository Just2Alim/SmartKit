import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../medicine/data/medicine_repository.dart';
import '../../medicine/models/medicine_model.dart';
import '../data/reminder_repository.dart';
import '../models/reminder_model.dart';
import '../../../core/services/notification_service.dart';

class AddReminderScreen extends StatefulWidget {
  const AddReminderScreen({super.key});

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final ReminderRepository _reminderRepository = ReminderRepository();
  final MedicineRepository _medicineRepository = MedicineRepository();

  List<MedicineModel> medicines = [];
  String? selectedMedicineId;
  String selectedTitle = '';
  TimeOfDay? selectedTime;
  bool isDaily = true;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMedicines();
  }

  Future<void> _loadMedicines() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final data = await _medicineRepository.getMedicinesByUser(user.uid).first;

    if (!mounted) return;

    setState(() {
      medicines = data;
      if (medicines.isNotEmpty) {
        selectedMedicineId = medicines.first.id;
        selectedTitle = medicines.first.name;
      }
    });
  }

  Future<void> _pickTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.now(),
    );

    if (result != null) {
      setState(() {
        selectedTime = result;
      });
    }
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return 'Выбрать время';
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _saveReminder() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    if (selectedMedicineId == null || selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите лекарство и время')),
      );
      return;
    }

    final medicine = medicines.firstWhere((m) => m.id == selectedMedicineId);

    setState(() => isLoading = true);

    try {
      final reminder = ReminderModel(
        id: '',
        userId: user.uid,
        medicineId: medicine.id,
        familyMemberId: medicine.familyMemberId,
        title: medicine.name,
        time: _formatTime(selectedTime),
        isDaily: isDaily,
        enabled: true,
        weekDays: isDaily ? [1, 2, 3, 4, 5, 6, 7] : [],
        createdAt: DateTime.now(),
      );

      await _reminderRepository.addReminder(reminder);
      // await NotificationService.instance.showInstantNotification(
      //   id: 999,
      //   title: 'ТЕСТ',
      //   body: 'Работает',
      // );
      final notificationId = NotificationService.instance.reminderIdFromString(
        '${reminder.medicineId}_${reminder.time}_${reminder.title}',
      );

      final parts = reminder.time.split(':');
      final reminderTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );

      await NotificationService.instance.scheduleDailyReminder(
        id: notificationId,
        title: 'Время принять лекарство',
        body: reminder.title,
        time: reminderTime,
      );
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Напоминание добавлено')));

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
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
    final medicineItems =
        medicines
            .map(
              (medicine) => DropdownMenuItem<String>(
                value: medicine.id,
                child: Text(medicine.name),
              ),
            )
            .toList();

    return Scaffold(

      appBar: AppBar(title: const Text('Добавить напоминание')),
      body: SafeArea(
        child:
            medicines.isEmpty
                ? const Center(child: Text('Сначала добавьте лекарства'))
                : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Лекарство'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedMedicineId,
                            isExpanded: true,
                            items: medicineItems,
                            onChanged: (value) {
                              if (value == null) return;
                              final medicine = medicines.firstWhere(
                                (m) => m.id == value,
                              );
                              setState(() {
                                selectedMedicineId = value;
                                selectedTitle = medicine.name;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      _label('Время'),
                      InkWell(
                        onTap: _pickTime,
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
                                Icons.access_time_rounded,
                                size: 18,
                                color: Color(0xFF6B7280),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _formatTime(selectedTime),
                                style: TextStyle(
                                  color:
                                      selectedTime == null
                                          ? Theme.of(context).colorScheme.onSurfaceVariant
                                          : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      SwitchListTile(
                        value: isDaily,
                        onChanged: (value) {
                          setState(() {
                            isDaily = value;
                          });
                        },
                        title: const Text('Каждый день'),
                        contentPadding: EdgeInsets.zero,
                      ),

                      const SizedBox(height: 28),

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _saveReminder,
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
