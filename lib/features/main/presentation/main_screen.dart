import 'package:flutter/material.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/state/cart_provider.dart';
import '../../../core/widgets/bottom_nav_bar.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../family/presentation/family_screen.dart';
import '../../medicine/presentation/search_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../shop/presentation/shop_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const _tabNames = ['dashboard', 'search', 'family', 'shop', 'profile'];

  late int _currentIndex;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _screens = [
      DashboardScreen(onOpenFamilyTab: () => _onTabTapped(2)),
      const SearchScreen(),
      FamilyScreen(),
      const ShopScreen(),
      const ProfileScreen(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackTab(_currentIndex);
    });
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;
    setState(() {
      _currentIndex = index;
    });
    _trackTab(index);
  }

  void _trackTab(int index) {
    AnalyticsService.instance.trackTab(
      area: 'b2c',
      tab: _tabNames[index],
      index: index,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: ListenableBuilder(
        listenable: CartProvider.instance,
        builder: (context, _) {
          return AppBottomNavBar(
            currentIndex: _currentIndex,
            onTap: _onTabTapped,
            badgeCounts: {3: CartProvider.instance.itemCount},
          );
        },
      ),
    );
  }
}
