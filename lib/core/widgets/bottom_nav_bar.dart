import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;
  final List<AppNavItem> items;
  final Map<int, int> badgeCounts;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    this.onTap,
    this.items = _defaultItems,
    this.badgeCounts = const {},
  });

  static const List<AppNavItem> _defaultItems = [
    AppNavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Главная',
    ),
    AppNavItem(
      icon: Icons.medication_outlined,
      activeIcon: Icons.medication_rounded,
      label: 'Лекарства',
    ),
    AppNavItem(
      icon: Icons.group_outlined,
      activeIcon: Icons.group_rounded,
      label: 'Семья',
    ),
    AppNavItem(
      icon: Icons.shopping_bag_outlined,
      activeIcon: Icons.shopping_bag_rounded,
      label: 'Магазин',
    ),
    AppNavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Профиль',
    ),
  ];

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return;

    if (onTap != null) {
      onTap!(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      decoration: BoxDecoration(color: AppColors.page(context)),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.border(context)),
            boxShadow: [
              BoxShadow(
                blurRadius: 22,
                offset: const Offset(0, 10),
                color: AppColors.shadow(context),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isActive = currentIndex == index;
              final badgeCount = badgeCounts[index] ?? 0;

              return Expanded(
                child: Semantics(
                  button: true,
                  selected: isActive,
                  label: item.label,
                  child: InkWell(
                    onTap: () => _onTap(context, index),
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      constraints: const BoxConstraints(minHeight: 58),
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isActive
                                ? scheme.primary.withValues(alpha: 0.14)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Badge.count(
                            count: badgeCount,
                            isLabelVisible: badgeCount > 0,
                            backgroundColor: AppColors.warning,
                            child: AnimatedScale(
                              scale: isActive ? 1.08 : 1,
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              child: Icon(
                                isActive ? item.activeIcon : item.icon,
                                size: 23,
                                color:
                                    isActive
                                        ? scheme.primary
                                        : scheme.onSurfaceVariant.withValues(
                                          alpha: 0.76,
                                        ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1,
                              fontWeight:
                                  isActive ? FontWeight.w800 : FontWeight.w600,
                              color:
                                  isActive
                                      ? scheme.primary
                                      : scheme.onSurfaceVariant.withValues(
                                        alpha: 0.78,
                                      ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class AppNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const AppNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
