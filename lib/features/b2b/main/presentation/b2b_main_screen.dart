import 'package:flutter/material.dart';
import '../../inventory/presentation/b2b_dashboard_screen.dart';
import '../../inventory/presentation/b2b_inventory_screen.dart';
import '../../inventory/presentation/b2b_sales_history_screen.dart';
import '../../reports/presentation/b2b_reports_screen.dart';
import '../../settings/presentation/b2b_settings_screen.dart';

class B2BMainScreen extends StatefulWidget {
  const B2BMainScreen({super.key});

  @override
  State<B2BMainScreen> createState() => _B2BMainScreenState();
}

class _B2BMainScreenState extends State<B2BMainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    B2BDashboardScreen(),
    B2BInventoryScreen(),
    const B2BSalesHistoryScreen(),
    B2BReportsScreen(),
    const B2BSettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.28 : 0.06,
              ),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: _onItemTapped,
                type: BottomNavigationBarType.fixed,
                backgroundColor: theme.cardColor,
                selectedItemColor: scheme.primary,
                unselectedItemColor: scheme.onSurfaceVariant,
                showSelectedLabels: true,
                showUnselectedLabels: true,
                selectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                  letterSpacing: 0,
                ),
                elevation: 0,
                items: [
                  _navItem(Icons.home_rounded, Icons.home_filled, 'Главная', 0),
                  _navItem(
                    Icons.inventory_2_outlined,
                    Icons.inventory_2_rounded,
                    'Склад',
                    1,
                  ),
                  _navItem(
                    Icons.history_outlined,
                    Icons.history_rounded,
                    'Продажи',
                    2,
                  ),
                  _navItem(
                    Icons.analytics_outlined,
                    Icons.analytics_rounded,
                    'Отчёты',
                    3,
                  ),
                  _navItem(
                    Icons.settings_outlined,
                    Icons.settings_rounded,
                    'Настройки',
                    4,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _navItem(
    IconData icon,
    IconData activeIcon,
    String label,
    int index,
  ) {
    final isSelected = _selectedIndex == index;
    return BottomNavigationBarItem(
      icon: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Icon(isSelected ? activeIcon : icon, size: 26),
      ),
      label: label,
    );
  }
}
