import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/services/b2b_ai_service.dart';
import '../data/b2b_inventory_repository.dart';
import '../data/b2b_sales_repository.dart';
import '../data/b2b_locations_repository.dart';
import '../models/b2b_inventory_model.dart';
import '../models/b2b_location_model.dart';
import '../models/b2b_sale_model.dart';

class B2BNotificationsScreen extends StatefulWidget {
  const B2BNotificationsScreen({super.key});

  @override
  State<B2BNotificationsScreen> createState() => _B2BNotificationsScreenState();
}

class _B2BNotificationsScreenState extends State<B2BNotificationsScreen> {
  final B2BInventoryRepository _repository = B2BInventoryRepository();
  final B2BSalesRepository _salesRepository = B2BSalesRepository();
  final B2BLocationsRepository _locationRepository = B2BLocationsRepository();

  String? _aiAlert;
  bool _isLoadingAi = false;

  Future<void> _fetchAiInsights(
    List<B2BInventoryModel> inventory,
    List<B2BSaleModel> sales,
    List<B2BLocationModel> locations,
  ) async {
    if (_aiAlert != null || _isLoadingAi) return;

    setState(() {
      _isLoadingAi = true;
    });

    try {
      B2BAiService.instance.init(inventory, sales, locations);
      final result = await B2BAiService.instance.sendMessage(
        'Проанализируй эти данные и дай ОДНО самое важное предупреждение или совет для бизнеса на сегодня. Будь максимально краток (1-2 предложения).',
      );
      if (!mounted) return;
      setState(() {
        _aiAlert = result;
      });
    } catch (e) {
      // Игнорируем ошибки ИИ в уведомлениях, чтобы не мешать основному флоу
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAi = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Уведомления',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      body:
          user == null
              ? const Center(child: Text('Пользователь не найден'))
              : StreamBuilder<List<B2BInventoryModel>>(
                stream: _repository.getItemsByUser(user.uid),
                builder: (context, inventorySnapshot) {
                  return StreamBuilder<List<B2BSaleModel>>(
                    stream: _salesRepository.getSalesByUser(user.uid),
                    builder: (context, salesSnapshot) {
                      return StreamBuilder<List<B2BLocationModel>>(
                        stream: _locationRepository.getLocationsByUser(
                          user.uid,
                        ),
                        builder: (context, locationsSnapshot) {
                          if (inventorySnapshot.connectionState ==
                                  ConnectionState.waiting ||
                              salesSnapshot.connectionState ==
                                  ConnectionState.waiting ||
                              locationsSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF10B981),
                              ),
                            );
                          }

                          final items = inventorySnapshot.data ?? [];
                          final sales = salesSnapshot.data ?? [];
                          final locations = locationsSnapshot.data ?? [];

                          // Запускаем ИИ анализ если есть данные
                          if (items.isNotEmpty &&
                              _aiAlert == null &&
                              !_isLoadingAi) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _fetchAiInsights(items, sales, locations);
                            });
                          }

                          final critical =
                              items
                                  .where((item) => item.stock <= item.minStock)
                                  .toList();

                          final low =
                              items
                                  .where(
                                    (item) =>
                                        item.stock > item.minStock &&
                                        item.stock <= item.minStock * 2,
                                  )
                                  .toList();

                          if (critical.isEmpty &&
                              low.isEmpty &&
                              _aiAlert == null) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.notifications_off_outlined,
                                    size: 64,
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Нет важных уведомлений',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                            physics: const BouncingScrollPhysics(),
                            children: [
                              // AI Insight Section
                              if (_aiAlert != null || _isLoadingAi) ...[
                                _aiInsightCard(),
                                const SizedBox(height: 24),
                              ],

                              if (critical.isNotEmpty) ...[
                                _sectionHeader(
                                  'Критический остаток',
                                  const Color(0xFFEF4444),
                                ),
                                const SizedBox(height: 12),
                                ...critical.map(
                                  (item) => _card(
                                    context,
                                    item,
                                    color: const Color(0xFFDC2626),
                                    title: 'Срочно пополнить',
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                              if (low.isNotEmpty) ...[
                                _sectionHeader(
                                  'Низкий остаток',
                                  const Color(0xFFF59E0B),
                                ),
                                const SizedBox(height: 12),
                                ...low.map(
                                  (item) => _card(
                                    context,
                                    item,
                                    color: const Color(0xFFEA580C),
                                    title: 'Скоро закончится',
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Theme.of(context).colorScheme.onSurface,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }

  Widget _aiInsightCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFF10B981),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'AI АНАЛИТИК',
                style: TextStyle(
                  color: const Color(0xFF10B981).withOpacity(0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              if (_isLoadingAi)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF10B981),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingAi)
            Text(
              'Анализирую склад и продажи...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Text(
              _aiAlert ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
        ],
      ),
    );
  }

  Widget _card(
    BuildContext context,
    B2BInventoryModel item, {
    required Color color,
    required String title,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            AppRoutes.b2bMedicineDetail,
            arguments: item.id,
          );
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$title • Остаток ${item.stock} шт, минимум ${item.minStock} шт',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
