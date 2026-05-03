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
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
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
                backgroundColor: Colors.white,
                selectedItemColor: const Color(0xFF10B981),
                unselectedItemColor: const Color(0xFF94A3B8),
                showSelectedLabels: true,
                showUnselectedLabels: true,
                selectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: -0.2,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                  letterSpacing: -0.2,
                ),
                elevation: 0,
                items: [
                  _navItem(Icons.home_rounded, Icons.home_filled, 'Главная', 0),
                  _navItem(Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'Склад', 1),
                  _navItem(Icons.history_outlined, Icons.history_rounded, 'Продажи', 2),
                  _navItem(Icons.analytics_outlined, Icons.analytics_rounded, 'Отчёты', 3),
                  _navItem(Icons.settings_outlined, Icons.settings_rounded, 'Настройки', 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _navItem(IconData icon, IconData activeIcon, String label, int index) {
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
