import 'package:flutter/material.dart';

import '../data/b2b_team_member_model.dart';
import '../data/b2b_team_repository.dart';

class B2BTeamScreen extends StatefulWidget {
  const B2BTeamScreen({super.key});

  @override
  State<B2BTeamScreen> createState() => _B2BTeamScreenState();
}

class _B2BTeamScreenState extends State<B2BTeamScreen> {
  final B2BTeamRepository _repository = B2BTeamRepository();
  late final Future<B2BTeamMemberModel?> _currentMemberFuture;

  @override
  void initState() {
    super.initState();
    _currentMemberFuture = _repository.currentMember();
  }

  bool _canManage(B2BTeamMemberModel? member) {
    return member?.role == 'owner' || member?.role == 'admin';
  }

  Future<void> _showInviteDialog() async {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController();
    var selectedRole = 'pharmacist';
    var isSubmitting = false;

    final invited = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  title: const Text(
                    'Добавить сотрудника',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  content: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.mail_outline_rounded),
                          ),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (!email.contains('@') || !email.contains('.')) {
                              return 'Введите корректный email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: selectedRole,
                          decoration: const InputDecoration(
                            labelText: 'Роль',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'pharmacist',
                              child: Text('Фармацевт'),
                            ),
                            DropdownMenuItem(
                              value: 'admin',
                              child: Text('Администратор'),
                            ),
                            DropdownMenuItem(
                              value: 'analyst',
                              child: Text('Аналитик'),
                            ),
                          ],
                          onChanged:
                              (value) => setDialogState(
                                () => selectedRole = value ?? selectedRole,
                              ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          isSubmitting
                              ? null
                              : () => Navigator.pop(dialogContext, false),
                      child: const Text('Отмена'),
                    ),
                    ElevatedButton.icon(
                      onPressed:
                          isSubmitting
                              ? null
                              : () async {
                                if (!formKey.currentState!.validate()) return;
                                setDialogState(() => isSubmitting = true);
                                try {
                                  await _repository.inviteMember(
                                    email: emailController.text,
                                    role: selectedRole,
                                  );
                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext, true);
                                  }
                                } catch (error) {
                                  setDialogState(() => isSubmitting = false);
                                  if (dialogContext.mounted) {
                                    ScaffoldMessenger.of(
                                      dialogContext,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Не удалось добавить: $error',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                      icon:
                          isSubmitting
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Добавить'),
                    ),
                  ],
                ),
          ),
    );

    emailController.dispose();

    if (!mounted || invited != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Сотрудник добавлен или приглашён')),
    );
  }

  Future<void> _confirmRemove(B2BTeamMemberModel member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text(
              'Удалить доступ?',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            content: Text(
              '${member.displayName} больше не сможет работать с этой организацией.',
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
          ),
    );

    if (confirmed != true) return;
    try {
      await _repository.removeMember(member.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось удалить доступ: $error')),
      );
    }
  }

  Future<void> _updateRole(B2BTeamMemberModel member, String role) async {
    try {
      await _repository.updateRole(memberId: member.id, role: role);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось изменить роль: $error')),
      );
    }
  }

  Future<void> _toggleStatus(B2BTeamMemberModel member) async {
    final nextStatus = member.isDisabled ? 'active' : 'disabled';
    try {
      await _repository.updateStatus(memberId: member.id, status: nextStatus);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось изменить статус: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<B2BTeamMemberModel?>(
      future: _currentMemberFuture,
      builder: (context, currentSnapshot) {
        final currentMember = currentSnapshot.data;
        final canManage = _canManage(currentMember);

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          floatingActionButton:
              canManage
                  ? FloatingActionButton.extended(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    onPressed: _showInviteDialog,
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text(
                      'Добавить',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  )
                  : null,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(),
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: StreamBuilder<List<B2BTeamMemberModel>>(
                  stream: _repository.watchMembers(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return SliverToBoxAdapter(
                        child: _StateCard(
                          icon: Icons.error_outline_rounded,
                          title: 'Команда недоступна',
                          subtitle: snapshot.error.toString(),
                        ),
                      );
                    }

                    final members = snapshot.data ?? const [];
                    if (members.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: _StateCard(
                          icon: Icons.group_off_rounded,
                          title: 'Команда пока пустая',
                          subtitle:
                              'Добавьте сотрудников, чтобы они могли работать со складом и отчётами.',
                        ),
                      );
                    }

                    return SliverList.separated(
                      itemCount: members.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder:
                          (context, index) => _TeamMemberCard(
                            member: members[index],
                            canManage:
                                canManage &&
                                !members[index].isCurrentUser &&
                                !members[index].isOwner,
                            onRoleChanged:
                                (role) => _updateRole(members[index], role),
                            onToggleStatus: () => _toggleStatus(members[index]),
                            onRemove: () => _confirmRemove(members[index]),
                          ),
                    );
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 132,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF10B981),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: const Text(
          'Команда',
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
            ),
          ),
          child: const Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 54),
              child: Text(
                'Доступ сотрудников к складу, продажам и аналитике',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamMemberCard extends StatelessWidget {
  const _TeamMemberCard({
    required this.member,
    required this.canManage,
    required this.onRoleChanged,
    required this.onToggleStatus,
    required this.onRemove,
  });

  final B2BTeamMemberModel member;
  final bool canManage;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onToggleStatus;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final statusColor =
        member.isDisabled
            ? const Color(0xFFEF4444)
            : member.isPending
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha:
                  Theme.of(context).brightness == Brightness.dark ? 0.22 : 0.04,
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                member.initials,
                style: const TextStyle(
                  color: Color(0xFF059669),
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  member.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _Pill(label: member.roleLabel),
                    _Pill(label: member.statusLabel, color: statusColor),
                    if (member.isCurrentUser) const _Pill(label: 'Вы'),
                  ],
                ),
              ],
            ),
          ),
          if (canManage)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (value) {
                switch (value) {
                  case 'admin':
                  case 'pharmacist':
                  case 'analyst':
                    onRoleChanged(value);
                    break;
                  case 'status':
                    onToggleStatus();
                    break;
                  case 'remove':
                    onRemove();
                    break;
                }
              },
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(
                      value: 'admin',
                      child: Text('Сделать администратором'),
                    ),
                    const PopupMenuItem(
                      value: 'pharmacist',
                      child: Text('Сделать фармацевтом'),
                    ),
                    const PopupMenuItem(
                      value: 'analyst',
                      child: Text('Сделать аналитиком'),
                    ),
                    PopupMenuItem(
                      value: 'status',
                      child: Text(
                        member.isDisabled ? 'Включить доступ' : 'Отключить',
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'remove',
                      child: Text('Удалить доступ'),
                    ),
                  ],
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.color = const Color(0xFF64748B)});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF10B981), size: 36),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
