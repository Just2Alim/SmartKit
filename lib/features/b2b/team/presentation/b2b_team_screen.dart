import 'package:flutter/material.dart';

class B2BTeamScreen extends StatelessWidget {
  const B2BTeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final team = [
      {
        'name': 'Менеджер склада',
        'role': 'Inventory Manager',
        'email': 'manager@smartkit.kz',
        'color': const Color(0xFFDBEAFE),
        'iconColor': const Color(0xFF2563EB),
      },
      {
        'name': 'Фармацевт',
        'role': 'Pharmacist',
        'email': 'pharma@smartkit.kz',
        'color': const Color(0xFFDCFCE7),
        'iconColor': const Color(0xFF16A34A),
      },
      {
        'name': 'Администратор',
        'role': 'Admin',
        'email': 'admin@smartkit.kz',
        'color': const Color(0xFFEDE9FE),
        'iconColor': const Color(0xFF7C3AED),
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('B2B команда'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF34D399), Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Row(
                children: [
                  Icon(Icons.group_rounded, color: Colors.white, size: 42),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Команда бизнеса\nроли и доступы сотрудников',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Сотрудники',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 12),
            ...team.map(
              (member) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: member['color'] as Color,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          Icons.person_rounded,
                          color: member['iconColor'] as Color,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member['name'] as String,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${member['role']} • ${member['email']}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}