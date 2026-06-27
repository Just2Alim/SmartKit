import 'package:flutter/material.dart';
import '../data/medicine_repository.dart';
import '../models/medicine_model.dart';
import '../../../core/router/app_routes.dart';
import '../../family/data/family_repository.dart';

class MedicineDetailScreen extends StatefulWidget {
  final String medicineId;

  const MedicineDetailScreen({super.key, required this.medicineId});

  @override
  State<MedicineDetailScreen> createState() => _MedicineDetailScreenState();
}

class _MedicineDetailScreenState extends State<MedicineDetailScreen> {
  final MedicineRepository _repository = MedicineRepository();
  final FamilyRepository _familyRepository = FamilyRepository();
  bool isDeleting = false;
  bool isRecordingIntake = false;

  Future<String> _getOwnerLabel(MedicineModel medicine) async {
    if (medicine.familyMemberId == null) {
      return 'Для меня';
    }

    final member = await _familyRepository.getFamilyMemberById(
      medicine.familyMemberId!,
    );

    if (member == null) {
      return 'Член семьи';
    }

    return '${member.name} (${member.relation})';
  }

  Future<void> _deleteMedicine() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Удалить лекарство'),
          content: const Text('Вы уверены, что хотите удалить это лекарство?'),
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
      await _repository.deleteMedicine(widget.medicineId);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Лекарство удалено')));

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

  String _formatDate(DateTime? date) {
    if (date == null) return 'Не указано';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String _formatDateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month.${date.year} $hour:$minute';
  }

  Future<void> _recordIntake(MedicineModel medicine) async {
    if (medicine.quantity <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Остаток уже нулевой')));
      return;
    }

    setState(() => isRecordingIntake = true);
    try {
      final result = await _repository.recordIntake(medicineId: medicine.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Отмечено для семьи. Осталось ${result.quantityAfter}'),
        ),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка приема: $e')));
    } finally {
      if (mounted) setState(() => isRecordingIntake = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Детали лекарства')),
      body: FutureBuilder<MedicineModel?>(
        future: _repository.getMedicineById(widget.medicineId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }

          final medicine = snapshot.data;

          if (medicine == null) {
            return const Center(child: Text('Лекарство не найдено'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Icon(
                          Icons.medication_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        medicine.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        medicine.dosage.trim().isEmpty
                            ? medicine.category
                            : medicine.dosage,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed:
                        medicine.quantity <= 0 || isRecordingIntake
                            ? null
                            : () => _recordIntake(medicine),
                    icon:
                        isRecordingIntake
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.check_circle_rounded),
                    label: Text(
                      medicine.quantity <= 0
                          ? 'Нет остатка'
                          : 'Принял (-1 ${medicine.unitLabel})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                FutureBuilder<String>(
                  future: _getOwnerLabel(medicine),
                  builder: (context, ownerSnapshot) {
                    final ownerLabel = ownerSnapshot.data ?? 'Загрузка...';

                    return _infoCard(
                      title: 'Основная информация',
                      children: [
                        _infoRow('Владелец', ownerLabel),
                        _infoRow('Категория', medicine.category),
                        if ((medicine.form ?? '').isNotEmpty)
                          _infoRow('Форма', medicine.form!),
                        _infoRow(
                          'Количество',
                          '${medicine.quantity} ${medicine.unitLabel}',
                        ),
                        _infoRow(
                          'Мин. остаток',
                          '${medicine.lowStockThreshold} ${medicine.unitLabel}',
                        ),
                        _infoRow(
                          'Срок годности',
                          _formatDate(medicine.expiryDate),
                        ),
                        if ((medicine.storagePlace ?? '').isNotEmpty)
                          _infoRow('Место хранения', medicine.storagePlace!),
                        if (medicine.openedAt != null)
                          _infoRow('Вскрыто', _formatDate(medicine.openedAt)),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 16),

                _infoCard(
                  title: 'Дополнительно',
                  children: [
                    if ((medicine.barcode ?? '').isNotEmpty)
                      _infoRow('Штрих-код', medicine.barcode!),
                    if ((medicine.manufacturer ?? '').isNotEmpty)
                      _infoRow('Производитель', medicine.manufacturer!),
                    if ((medicine.packageSize ?? '').isNotEmpty)
                      _infoRow('Упаковка', medicine.packageSize!),
                    if ((medicine.batchNumber ?? '').isNotEmpty)
                      _infoRow('Серия/партия', medicine.batchNumber!),
                    if ((medicine.scanSource ?? '').isNotEmpty)
                      _infoRow('Источник', medicine.scanSource!),
                    _infoRow(
                      'Заметки',
                      medicine.notes == null || medicine.notes!.isEmpty
                          ? 'Нет заметок'
                          : medicine.notes!,
                    ),
                    _infoRow('Создано', _formatDate(medicine.createdAt)),
                  ],
                ),

                const SizedBox(height: 16),

                _intakeHistoryCard(medicine),

                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.pushNamed(
                        context,
                        AppRoutes.editMedicine,
                        arguments: widget.medicineId,
                      );

                      if (result == true && mounted) {
                        setState(() {});
                      }
                    },
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text(
                      'Редактировать',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                    ),
                    onPressed: isDeleting ? null : _deleteMedicine,
                    icon:
                        isDeleting
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
                      isDeleting ? 'Удаление...' : 'Удалить лекарство',
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

  Widget _infoCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 4),
            color: Colors.black.withValues(alpha: 0.04),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _intakeHistoryCard(MedicineModel medicine) {
    return StreamBuilder(
      stream: _repository.getIntakeLogsByMedicine(medicine.id),
      builder: (context, snapshot) {
        final logs = snapshot.data ?? [];

        return _infoCard(
          title: 'История приема',
          children: [
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(),
              )
            else if (logs.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Приемы пока не отмечались',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ...logs.take(5).map((log) {
                final actor =
                    (log.actorName ?? '').trim().isEmpty
                        ? 'Кто-то из семьи'
                        : log.actorName!.trim();
                return _infoRow(
                  _formatDateTime(log.takenAt),
                  '-${log.amount} ${medicine.unitLabel} • $actor',
                );
              }),
          ],
        );
      },
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
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
