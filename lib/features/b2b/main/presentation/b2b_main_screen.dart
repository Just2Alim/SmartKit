import 'package:flutter/material.dart';
import '../../../../core/widgets/bottom_nav_bar.dart';
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
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          AppNavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: 'Главная',
          ),
          AppNavItem(
            icon: Icons.inventory_2_outlined,
            activeIcon: Icons.inventory_2_rounded,
            label: 'Склад',
          ),
          AppNavItem(
            icon: Icons.receipt_long_outlined,
            activeIcon: Icons.receipt_long_rounded,
            label: 'Продажи',
          ),
          AppNavItem(
            icon: Icons.analytics_outlined,
            activeIcon: Icons.analytics_rounded,
            label: 'Отчёты',
          ),
          AppNavItem(
            icon: Icons.widgets_outlined,
            activeIcon: Icons.widgets_rounded,
            label: 'Ещё',
          ),
        ],
      ),
    );
  }
}
