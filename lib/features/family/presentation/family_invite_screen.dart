import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/router/app_routes.dart';
import '../data/family_repository.dart';
import '../models/family_account_model.dart';

class FamilyInviteScreen extends StatefulWidget {
  final String? initialToken;

  const FamilyInviteScreen({super.key, this.initialToken});

  @override
  State<FamilyInviteScreen> createState() => _FamilyInviteScreenState();
}

class _FamilyInviteScreenState extends State<FamilyInviteScreen> {
  final FamilyRepository _repository = FamilyRepository();
  final tokenCtrl = TextEditingController();

  Future<FamilyInviteModel?>? _inviteFuture;
  bool isAccepting = false;

  @override
  void initState() {
    super.initState();
    final token = widget.initialToken?.trim();
    if (token != null && token.isNotEmpty) {
      tokenCtrl.text = token;
      _inviteFuture = _repository.getFamilyInviteDetails(token);
    }
  }

  @override
  void dispose() {
    tokenCtrl.dispose();
    super.dispose();
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

  void _loadInvite() {
    final token = _extractToken(tokenCtrl.text);
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Вставьте ссылку или токен приглашения')),
      );
      return;
    }

    setState(() {
      tokenCtrl.text = token;
      _inviteFuture = _repository.getFamilyInviteDetails(token);
    });
  }

  Future<void> _acceptInvite() async {
    final token = _extractToken(tokenCtrl.text);
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала войдите или зарегистрируйтесь')),
      );
      return;
    }

    setState(() => isAccepting = true);
    try {
      await _repository.acceptFamilyInvite(token);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Вы присоединились к семье')),
      );
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.main,
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка приглашения: $e')));
    } finally {
      if (mounted) setState(() => isAccepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Приглашение в семью')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF34D399), Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Row(
                children: [
                  Icon(Icons.group_add_rounded, color: Colors.white, size: 34),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Присоединиться к семейной аптечке',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: tokenCtrl,
              decoration: const InputDecoration(
                labelText: 'Ссылка или токен',
                prefixIcon: Icon(Icons.link_rounded),
              ),
              onSubmitted: (_) => _loadInvite(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _loadInvite,
                icon: const Icon(Icons.search_rounded),
                label: const Text('Проверить приглашение'),
              ),
            ),
            const SizedBox(height: 20),
            if (_inviteFuture != null)
              FutureBuilder<FamilyInviteModel?>(
                future: _inviteFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError || snapshot.data == null) {
                    return _MessageCard(
                      icon: Icons.error_outline_rounded,
                      title: 'Приглашение не найдено',
                      subtitle: 'Проверьте ссылку или попросите новую.',
                      color: colorScheme.error,
                    );
                  }

                  final invite = snapshot.data!;
                  final roleLabel =
                      invite.role == 'admin' ? 'Администратор' : 'Участник';

                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invite.familyName ?? 'Семья SmartKit',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          [
                            roleLabel,
                            if (invite.invitedByName != null)
                              'пригласил(а) ${invite.invitedByName}',
                          ].join(' • '),
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                        if (invite.email != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            invite.email!,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        if (user == null)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed:
                                      () => Navigator.pushNamed(
                                        context,
                                        AppRoutes.login,
                                        arguments: {
                                          'familyInviteToken': _extractToken(
                                            tokenCtrl.text,
                                          ),
                                        },
                                      ),
                                  child: const Text('Войти'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed:
                                      () => Navigator.pushNamed(
                                        context,
                                        AppRoutes.signup,
                                        arguments: {
                                          'role': 'b2c',
                                          'familyInviteToken': _extractToken(
                                            tokenCtrl.text,
                                          ),
                                        },
                                      ),
                                  child: const Text('Регистрация'),
                                ),
                              ),
                            ],
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: FilledButton.icon(
                              onPressed: isAccepting ? null : _acceptInvite,
                              icon:
                                  isAccepting
                                      ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Icon(Icons.check_rounded),
                              label: const Text('Присоединиться'),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _MessageCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
