import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/app_routes.dart';
import '../../medicine/data/medicine_repository.dart';
import '../../medicine/models/medicine_intake_log_model.dart';
import '../../medicine/models/medicine_model.dart';
import '../data/family_repository.dart';
import '../models/family_account_model.dart';
import '../models/family_member_model.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final FamilyRepository _repository = FamilyRepository();
  final MedicineRepository _medicineRepository = MedicineRepository();

  late Future<FamilyModel?> _familyFuture;

  @override
  void initState() {
    super.initState();
    _familyFuture = _repository.getCurrentFamily();
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'owner':
        return 'Владелец';
      case 'admin':
        return 'Администратор';
      default:
        return 'Участник';
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'invited':
        return 'Ожидает';
      case 'disabled':
        return 'Отключен';
      default:
        return 'Активен';
    }
  }

  String _buildInviteLink(String token) {
    final encoded = Uri.encodeComponent(token);
    final configured = AppConfig.familyInviteBaseUrl.trim();

    if (configured.isNotEmpty) {
      return '${configured.replaceFirst(RegExp(r'/$'), '')}/#${AppRoutes.familyInvite}?token=$encoded';
    }

    final base = Uri.base;
    if ((base.scheme == 'http' || base.scheme == 'https') &&
        base.host.isNotEmpty) {
      return '${base.origin}/#${AppRoutes.familyInvite}?token=$encoded';
    }

    return 'smartkit://family-invite?token=$encoded';
  }

  String _extractToken(String value) {
    final text = value.trim();
    final uri = Uri.tryParse(text);
    if (uri != null) {
      final queryToken = uri.queryParameters['token'];
      if (queryToken != null && queryToken.isNotEmpty) return queryToken;

      final fragmentUri = Uri.tryParse(uri.fragment);
      final fragmentToken = fragmentUri?.queryParameters['token'];
      if (fragmentToken != null && fragmentToken.isNotEmpty) {
        return fragmentToken;
      }
    }

    final marker = 'token=';
    final index = text.indexOf(marker);
    if (index >= 0) {
      return text.substring(index + marker.length).split('&').first;
    }
    return text;
  }

  Future<void> _showInviteSheet() async {
    final emailCtrl = TextEditingController();
    String role = 'member';
    bool isCreating = false;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> createInvite() async {
              setSheetState(() => isCreating = true);
              try {
                final invite = await _repository.createFamilyInvite(
                  email: emailCtrl.text,
                  role: role,
                );
                final link = _buildInviteLink(invite.token);
                await Clipboard.setData(ClipboardData(text: link));

                if (!mounted || !sheetContext.mounted) return;
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ссылка приглашения скопирована'),
                  ),
                );
                await showDialog<void>(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('Ссылка приглашения'),
                        content: SelectableText(link),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Готово'),
                          ),
                          FilledButton.icon(
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: link),
                              );
                              if (context.mounted) Navigator.pop(context);
                            },
                            icon: const Icon(Icons.copy_rounded),
                            label: const Text('Копировать'),
                          ),
                        ],
                      ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Не удалось создать ссылку: $e')),
                );
              } finally {
                if (mounted && sheetContext.mounted) {
                  setSheetState(() => isCreating = false);
                }
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  20 + MediaQuery.of(sheetContext).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Пригласить аккаунт',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'Можно оставить пустым',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      decoration: const InputDecoration(
                        labelText: 'Роль',
                        prefixIcon: Icon(Icons.admin_panel_settings_rounded),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'member',
                          child: Text('Участник'),
                        ),
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text('Администратор'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() => role = value);
                      },
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: isCreating ? null : createInvite,
                        icon:
                            isCreating
                                ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.link_rounded),
                        label: const Text('Создать ссылку'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    emailCtrl.dispose();
  }

  Future<void> _showAcceptLinkSheet() async {
    final linkCtrl = TextEditingController();
    final token = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (sheetContext) => SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                20 + MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Принять приглашение',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: linkCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Ссылка или токен',
                      prefixIcon: Icon(Icons.link_rounded),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed:
                          () => Navigator.pop(
                            sheetContext,
                            _extractToken(linkCtrl.text),
                          ),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Открыть приглашение'),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
    linkCtrl.dispose();

    if (token == null || token.trim().isEmpty || !mounted) return;
    Navigator.pushNamed(
      context,
      AppRoutes.familyInvite,
      arguments: {'token': token.trim()},
    );
  }

  Future<void> _removeAccount(FamilyAccountMemberModel member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Отключить доступ'),
            content: Text('Отключить ${member.displayName} от семьи?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Отключить'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    try {
      await _repository.removeFamilyAccountMember(member.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Доступ отключен')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Не удалось отключить: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Моя семья')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            () => Navigator.pushNamed(context, AppRoutes.addFamilyMember),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Профиль'),
      ),
      body: SafeArea(
        child:
            user == null
                ? const Center(child: Text('Пользователь не найден'))
                : FutureBuilder<FamilyModel?>(
                  future: _familyFuture,
                  builder: (context, familySnapshot) {
                    if (familySnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final family = familySnapshot.data;

                    return StreamBuilder<List<FamilyAccountMemberModel>>(
                      stream: _repository.getFamilyAccountMembers(),
                      builder: (context, accountSnapshot) {
                        final accounts = accountSnapshot.data ?? [];
                        FamilyAccountMemberModel? currentAccount;
                        for (final account in accounts) {
                          if (account.userId == user.id) {
                            currentAccount = account;
                            break;
                          }
                        }
                        final canManage = currentAccount?.canManage ?? false;

                        return StreamBuilder<List<FamilyMemberModel>>(
                          stream: _repository.getFamilyMembersByUser(user.id),
                          builder: (context, memberSnapshot) {
                            if (memberSnapshot.connectionState ==
                                    ConnectionState.waiting &&
                                !memberSnapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            if (memberSnapshot.hasError) {
                              return Center(
                                child: Text('Ошибка: ${memberSnapshot.error}'),
                              );
                            }

                            final members = memberSnapshot.data ?? [];

                            return ListView(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                12,
                                20,
                                96,
                              ),
                              children: [
                                _buildHeader(
                                  family: family,
                                  accountsCount: accounts.length,
                                  profilesCount: members.length,
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed:
                                            canManage ? _showInviteSheet : null,
                                        icon: const Icon(Icons.link_rounded),
                                        label: const Text('Пригласить'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _showAcceptLinkSheet,
                                        icon: const Icon(Icons.input_rounded),
                                        label: const Text('Принять'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                _sectionTitle('Аккаунты семьи'),
                                const SizedBox(height: 12),
                                _buildAccountsCard(
                                  accounts,
                                  canManage: canManage,
                                  currentUserId: user.id,
                                ),
                                const SizedBox(height: 24),
                                _sectionTitle('Журнал выдачи'),
                                const SizedBox(height: 12),
                                _buildRecentIntakeCard(),
                                const SizedBox(height: 24),
                                _sectionTitle('Профили и лекарства'),
                                const SizedBox(height: 12),
                                if (members.isEmpty)
                                  _emptyCard(
                                    'Пока нет профилей семьи',
                                    Icons.family_restroom_rounded,
                                  )
                                else
                                  ...members.map(
                                    (member) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: _buildMemberCard(member),
                                    ),
                                  ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                ),
      ),
    );
  }

  Widget _buildHeader({
    required FamilyModel? family,
    required int accountsCount,
    required int profilesCount,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF34D399), Color(0xFF059669)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 8),
            color: const Color(0xFF059669).withValues(alpha: 0.25),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.group_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  family?.name ?? 'Семейная аптечка',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$accountsCount аккаунт(ов) • $profilesCount профиль(ей)',
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _buildAccountsCard(
    List<FamilyAccountMemberModel> accounts, {
    required bool canManage,
    required String currentUserId,
  }) {
    if (accounts.isEmpty) {
      return _emptyCard('Аккаунты пока не загружены', Icons.people_outline);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          ...accounts.map((member) {
            final isCurrent = member.userId == currentUserId;
            final canRemove = canManage && member.role != 'owner' && !isCurrent;

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: CircleAvatar(
                backgroundColor:
                    member.status == 'active'
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFFF7ED),
                child: Icon(
                  member.status == 'active'
                      ? Icons.verified_user_rounded
                      : Icons.hourglass_top_rounded,
                  color:
                      member.status == 'active'
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFEA580C),
                ),
              ),
              title: Text(
                isCurrent ? '${member.displayName} • вы' : member.displayName,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                [
                  _roleLabel(member.role),
                  _statusLabel(member.status),
                  if ((member.email ?? '').isNotEmpty) member.email!,
                ].join(' • '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing:
                  canRemove
                      ? PopupMenuButton<String>(
                        onSelected: (_) => _removeAccount(member),
                        itemBuilder:
                            (context) => const [
                              PopupMenuItem(
                                value: 'remove',
                                child: Text('Отключить доступ'),
                              ),
                            ],
                      )
                      : null,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecentIntakeCard() {
    return StreamBuilder<List<MedicineIntakeLogModel>>(
      stream: _medicineRepository.getFamilyIntakeLogs(),
      builder: (context, snapshot) {
        final logs = snapshot.data ?? [];

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: LinearProgressIndicator());
        }

        if (logs.isEmpty) {
          return _emptyCard(
            'Выдачи лекарств пока не отмечались',
            Icons.history,
          );
        }

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            children: [
              ...logs
                  .take(5)
                  .map(
                    (log) => _IntakeActivityTile(
                      log: log,
                      familyRepository: _repository,
                      medicineRepository: _medicineRepository,
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMemberCard(FamilyMemberModel member) {
    final isLinked = (member.linkedUserId ?? '').isNotEmpty;
    final ageLabel = member.age > 0 ? '${member.age} лет' : 'Возраст не указан';

    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.familyMemberProfile,
          arguments: member.id,
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
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
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                isLinked ? Icons.account_circle_rounded : Icons.person_rounded,
                color: const Color(0xFF16A34A),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${member.relation} • $ageLabel',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (isLinked) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Аккаунт подключен',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ],
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
    );
  }

  Widget _emptyCard(String text, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntakeActivityTile extends StatefulWidget {
  final MedicineIntakeLogModel log;
  final FamilyRepository familyRepository;
  final MedicineRepository medicineRepository;

  const _IntakeActivityTile({
    required this.log,
    required this.familyRepository,
    required this.medicineRepository,
  });

  @override
  State<_IntakeActivityTile> createState() => _IntakeActivityTileState();
}

class _IntakeActivityTileState extends State<_IntakeActivityTile> {
  late Future<_IntakeEventData> _eventFuture;

  @override
  void initState() {
    super.initState();
    _eventFuture = _loadEvent();
  }

  @override
  void didUpdateWidget(covariant _IntakeActivityTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.log.id != widget.log.id) {
      _eventFuture = _loadEvent();
    }
  }

  Future<_IntakeEventData> _loadEvent() async {
    MedicineModel? medicine;
    FamilyMemberModel? recipient;

    try {
      medicine = await widget.medicineRepository.getMedicineById(
        widget.log.medicineId,
      );
    } catch (_) {}

    final recipientId = widget.log.familyMemberId;
    if (recipientId != null && recipientId.isNotEmpty) {
      try {
        recipient = await widget.familyRepository.getFamilyMemberById(
          recipientId,
        );
      } catch (_) {}
    }

    return _IntakeEventData(medicine: medicine, recipient: recipient);
  }

  String _formatDateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month.${date.year} $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_IntakeEventData>(
      future: _eventFuture,
      builder: (context, snapshot) {
        final event = snapshot.data;
        final medicine = event?.medicine;
        final recipient = event?.recipient;
        final actor =
            (widget.log.actorName ?? '').trim().isEmpty
                ? 'Кто-то из семьи'
                : widget.log.actorName!.trim();
        final unit =
            medicine == null || medicine.unitLabel.isEmpty
                ? 'шт'
                : medicine.unitLabel;
        final recipientLabel = recipient?.name ?? 'себя';
        final medicineId = medicine?.id;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFDBEAFE),
            child: Icon(Icons.medication_rounded, color: Color(0xFF2563EB)),
          ),
          title: Text(
            '$actor дал(а) ${medicine?.name ?? 'лекарство'}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            [
              'Для: $recipientLabel',
              '-${widget.log.amount} $unit',
              _formatDateTime(widget.log.takenAt),
            ].join(' • '),
          ),
          onTap:
              medicineId == null
                  ? null
                  : () => Navigator.pushNamed(
                    context,
                    AppRoutes.medicineDetail,
                    arguments: medicineId,
                  ),
        );
      },
    );
  }
}

class _IntakeEventData {
  final MedicineModel? medicine;
  final FamilyMemberModel? recipient;

  const _IntakeEventData({this.medicine, this.recipient});
}
