import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/b2b_activity_repository.dart';
import '../models/b2b_activity_model.dart';

class B2BActivityHistoryScreen extends StatefulWidget {
  const B2BActivityHistoryScreen({super.key});

  @override
  State<B2BActivityHistoryScreen> createState() =>
      _B2BActivityHistoryScreenState();
}

class _B2BActivityHistoryScreenState extends State<B2BActivityHistoryScreen> {
  final B2BActivityRepository _repository = B2BActivityRepository();
  B2BActivityType? _selectedType;

  List<B2BActivityModel> _filterActivities(List<B2BActivityModel> activities) {
    final selectedType = _selectedType;
    if (selectedType == null) return activities;
    return activities
        .where((activity) => activity.type == selectedType)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildFilters(context)),
          StreamBuilder<List<B2BActivityModel>>(
            stream: _repository.watchCurrentOrganizationActivities(limit: 300),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              if (snapshot.hasError) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _StateCard(
                      icon: Icons.error_outline_rounded,
                      title: 'История недоступна',
                      subtitle: snapshot.error.toString(),
                    ),
                  ),
                );
              }

              final activities = _filterActivities(snapshot.data ?? const []);
              if (activities.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: _StateCard(
                      icon: Icons.history_toggle_off_rounded,
                      title: 'Активности пока нет',
                      subtitle:
                          'Когда команда будет добавлять товары, менять остатки или проводить продажи, события появятся здесь.',
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                sliver: SliverList.separated(
                  itemCount: activities.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder:
                      (context, index) =>
                          _ActivityCard(activity: activities[index]),
                ),
              );
            },
          ),
        ],
      ),
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
          'История активности',
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
                'Полный журнал продаж, склада и локаций',
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

  Widget _buildFilters(BuildContext context) {
    final filters = <B2BActivityType?>[
      null,
      B2BActivityType.sale,
      B2BActivityType.stockReceipt,
      B2BActivityType.stockUpdate,
      B2BActivityType.itemAdded,
      B2BActivityType.itemUpdated,
      B2BActivityType.locationCreated,
      B2BActivityType.locationUpdated,
    ];

    return SizedBox(
      height: 58,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final type = filters[index];
          final selected = type == _selectedType;
          return ChoiceChip(
            selected: selected,
            onSelected: (_) => setState(() => _selectedType = type),
            selectedColor: const Color(0xFF10B981),
            label: Text(type == null ? 'Все' : _typeLabel(type)),
            labelStyle: TextStyle(
              color:
                  selected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w900,
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: filters.length,
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity});

  final B2BActivityModel activity;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(activity.type);
    final dateFormat = DateFormat('dd.MM, HH:mm');
    final amount = activity.metadata?['amount'];

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: style.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(style.icon, color: style.color, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        activity.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (amount != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '+$amount ₸',
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  activity.description,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _Pill(label: _typeLabel(activity.type), color: style.color),
                    _Pill(label: dateFormat.format(activity.timestamp)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityStyle {
  const _ActivityStyle({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

_ActivityStyle _styleFor(B2BActivityType type) {
  switch (type) {
    case B2BActivityType.sale:
      return const _ActivityStyle(
        icon: Icons.shopping_bag_outlined,
        color: Color(0xFF10B981),
      );
    case B2BActivityType.stockUpdate:
      return const _ActivityStyle(
        icon: Icons.inventory_2_outlined,
        color: Color(0xFFF59E0B),
      );
    case B2BActivityType.stockReceipt:
      return const _ActivityStyle(
        icon: Icons.playlist_add_check_rounded,
        color: Color(0xFF0EA5E9),
      );
    case B2BActivityType.itemAdded:
      return const _ActivityStyle(
        icon: Icons.add_circle_outline_rounded,
        color: Color(0xFF10B981),
      );
    case B2BActivityType.itemUpdated:
      return const _ActivityStyle(
        icon: Icons.edit_note_rounded,
        color: Color(0xFF6366F1),
      );
    case B2BActivityType.locationCreated:
    case B2BActivityType.locationUpdated:
      return const _ActivityStyle(
        icon: Icons.location_on_outlined,
        color: Color(0xFF8B5CF6),
      );
  }
}

String _typeLabel(B2BActivityType type) {
  switch (type) {
    case B2BActivityType.sale:
      return 'Продажи';
    case B2BActivityType.stockUpdate:
      return 'Остатки';
    case B2BActivityType.stockReceipt:
      return 'Приход';
    case B2BActivityType.itemAdded:
      return 'Новый товар';
    case B2BActivityType.itemUpdated:
      return 'Изменение товара';
    case B2BActivityType.locationCreated:
      return 'Новая локация';
    case B2BActivityType.locationUpdated:
      return 'Изменение локации';
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
