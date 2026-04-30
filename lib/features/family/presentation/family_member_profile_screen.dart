import 'package:flutter/material.dart';
import '../../../core/router/app_routes.dart';
import '../data/family_repository.dart';
import '../models/family_member_model.dart';

class FamilyMemberProfileScreen extends StatefulWidget {
  final String memberId;

  const FamilyMemberProfileScreen({super.key, required this.memberId});

  @override
  State<FamilyMemberProfileScreen> createState() =>
      _FamilyMemberProfileScreenState();
}

class _FamilyMemberProfileScreenState extends State<FamilyMemberProfileScreen> {
  final FamilyRepository _repository = FamilyRepository();
  bool isDeleting = false;

  Future<void> _deleteMember() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Удалить профиль'),
          content: const Text(
            'Вы уверены, что хотите удалить этого члена семьи?',
          ),
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
      await _repository.deleteFamilyMember(widget.memberId);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Член семьи удалён')));

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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  IconData _getRelationIcon(String relation) {
    switch (relation.toLowerCase()) {
      case 'ребенок':
        return Icons.child_care_rounded;
      case 'мама':
      case 'папа':
      case 'бабушка':
      case 'дедушка':
      case 'брат':
      case 'сестра':
        return Icons.person_rounded;
      default:
        return Icons.family_restroom_rounded;
    }
  }

  Color _getRelationColor(String relation) {
    switch (relation.toLowerCase()) {
      case 'мама':
        return const Color(0xFFDB2777);
      case 'папа':
        return const Color(0xFF2563EB);
      case 'ребенок':
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFF7C3AED);
    }
  }

  Color _getRelationBg(String relation) {
    switch (relation.toLowerCase()) {
      case 'мама':
        return const Color(0xFFFCE7F3);
      case 'папа':
        return const Color(0xFFDBEAFE);
      case 'ребенок':
        return const Color(0xFFDCFCE7);
      default:
        return const Color(0xFFEDE9FE);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(title: const Text('Профиль члена семьи')),
      body: FutureBuilder<FamilyMemberModel?>(
        future: _repository.getFamilyMemberById(widget.memberId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }

          final member = snapshot.data;

          if (member == null) {
            return const Center(child: Text('Профиль не найден'));
          }

          final color = _getRelationColor(member.relation);
          final bg = _getRelationBg(member.relation);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.85), color],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                        color: color.withOpacity(0.25),
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
                        child: Icon(
                          _getRelationIcon(member.relation),
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        member.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${member.relation} • ${member.age} лет',
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
                  title: 'Основная информация',
                  children: [
                    _infoRow('Имя', member.name),
                    _infoRow('Кем приходится', member.relation),
                    _infoRow('Возраст', '${member.age} лет'),
                    _infoRow('Создано', _formatDate(member.createdAt)),
                  ],
                ),

                const SizedBox(height: 16),

                _infoCard(
                  title: 'Заметки',
                  children: [
                    Text(
                      member.notes == null || member.notes!.trim().isEmpty
                          ? 'Нет заметок'
                          : member.notes!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF111827),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                InkWell(
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.familyMemberMedicines,
                      arguments: member.id,
                    );
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
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
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.medication_rounded, color: color),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Лекарства',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Открыть лекарства этого члена семьи',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 18,
                          color: Color(0xFF9CA3AF),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.addMedicine,
                        arguments: widget.memberId,
                      );
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text(
                      'Добавить лекарство',
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
                    onPressed: () async {
                      final result = await Navigator.pushNamed(
                        context,
                        AppRoutes.editFamilyMember,
                        arguments: widget.memberId,
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
                    onPressed: isDeleting ? null : _deleteMember,
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
                      isDeleting ? 'Удаление...' : 'Удалить профиль',
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
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
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
}
