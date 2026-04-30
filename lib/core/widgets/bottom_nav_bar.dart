import 'package:flutter/material.dart';

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    this.onTap,
  });

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return;

    if (onTap != null) {
      onTap!(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = <_NavItem>[
      const _NavItem(icon: Icons.home_rounded, label: 'Главная'),
      const _NavItem(icon: Icons.medication_rounded, label: 'Лекарства'),
      const _NavItem(icon: Icons.group_rounded, label: 'Семья'),
      const _NavItem(icon: Icons.shopping_bag_rounded, label: 'Магазин'),
      const _NavItem(icon: Icons.person_rounded, label: 'Профиль'),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, -4),
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (index) {
            final item = items[index];
            final isActive = currentIndex == index;

            return Expanded(
              child: InkWell(
                onTap: () => _onTap(context, index),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isActive ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        size: 22,
                        color:
                            isActive
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w500,
                          color:
                              isActive
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({required this.icon, required this.label});
}
