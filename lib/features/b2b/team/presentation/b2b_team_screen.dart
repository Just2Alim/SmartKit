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
        'initials': 'МС',
      },
      {
        'name': 'Фармацевт',
        'role': 'Pharmacist',
        'email': 'pharma@smartkit.kz',
        'initials': 'ФМ',
      },
      {
        'name': 'Администратор',
        'role': 'Admin',
        'email': 'admin@smartkit.kz',
        'initials': 'АД',
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final member = team[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _TeamMemberCard(member: member),
                  );
                },
                childCount: team.length,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                onPressed: () {},
                icon: const Icon(Icons.add_rounded, color: Color(0xFF10B981)),
                label: const Text(
                  'Добавить сотрудника',
                  style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF10B981),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: const Text(
          'Наша Команда',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamMemberCard extends StatelessWidget {
  final Map<String, String> member;

  const _TeamMemberCard({required this.member});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                member['initials']!,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member['name']!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  member['role']!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF10B981),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  member['email']!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}