import 'package:flutter/material.dart';

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
  late int _currentIndex;

  final List<Widget> _screens = [
    DashboardScreen(),
    const SearchScreen(),
    FamilyScreen(),
    const ShopScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;
    setState(() {
      _currentIndex = index;
    });
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
