import 'package:flutter/material.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/choose_role_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/settings_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/medicine/presentation/search_screen.dart';
import '../../features/family/presentation/family_screen.dart';
import '../../features/medicine/presentation/add_medicine_screen.dart';
import '../../features/medicine/presentation/medicine_detail_screen.dart';
import '../../features/medicine/presentation/edit_medicine_screen.dart';
import '../../features/medicine/presentation/barcode_scanner_screen.dart';
import '../../features/family/presentation/family_member_medicines_screen.dart';
import '../../features/family/presentation/family_member_profile_screen.dart';
import '../../features/family/presentation/add_family_member_screen.dart';
import '../../features/medicine/presentation/notifications_screen.dart';
import '../../features/family/presentation/edit_family_member_screen.dart';
import '../../features/analytics/presentation/analytics_screen.dart';
import '../../features/reminders/presentation/reminders_screen.dart';
import '../../features/reminders/presentation/add_reminder_screen.dart';
import '../services/auth_gate.dart';
import '../../features/ai/presentation/ai_features_screen.dart';
import '../../features/ai/presentation/ai_chat_screen.dart';
import '../../features/ai/presentation/ai_recommendations_screen.dart';
import '../../features/ai/presentation/ai_kit_builder_screen.dart';
import '../../features/shop/presentation/shop_screen.dart';
import '../../features/shop/presentation/shop_product_screen.dart';
import '../../features/shop/presentation/cart_screen.dart';
import '../../features/main/presentation/main_screen.dart';
import '../../features/b2b/auth/presentation/b2b_login_screen.dart';
import '../../features/b2b/auth/presentation/b2b_onboarding_screen.dart';
import '../../features/b2b/auth/presentation/b2b_signup_screen.dart';
import '../../features/b2b/inventory/presentation/b2b_add_medicine_screen.dart';
import '../../features/b2b/inventory/presentation/b2b_dashboard_screen.dart';
import '../../features/b2b/inventory/presentation/b2b_inventory_screen.dart';
import '../../features/b2b/inventory/presentation/b2b_medicine_detail_screen.dart';
import '../../features/b2b/inventory/presentation/b2b_notifications_screen.dart';
import '../../features/b2b/inventory/presentation/b2b_sales_history_screen.dart';
import '../../features/b2b/inventory/presentation/b2b_locations_screen.dart';
import '../../features/b2b/main/presentation/b2b_main_screen.dart';
import '../../features/b2b/reports/presentation/b2b_reports_screen.dart';
import '../../features/b2b/settings/presentation/b2b_settings_screen.dart';
import '../../features/b2b/team/presentation/b2b_team_screen.dart';
import 'app_routes.dart';

class AppRouter {
  static const initialRoute = AppRoutes.splash;

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return _page(const AuthGate());

      case AppRoutes.onboarding:
        return _page(const OnboardingScreen());

      case AppRoutes.login:
        return _page(const LoginScreen());

      case AppRoutes.signup:
        return _page(const SignupScreen());

      case AppRoutes.chooseRole:
        return _page(const ChooseRoleScreen());

      case AppRoutes.reminders:
        return _page(RemindersScreen());

      case AppRoutes.addReminder:
        return _page(const AddReminderScreen());

      case AppRoutes.main:
        return _page(const MainScreen());

      case AppRoutes.dashboard:
        return _page(DashboardScreen());

      case AppRoutes.addMedicine:
        final args = settings.arguments;
        if (args is Map<String, dynamic>) {
          return _page(AddMedicineScreen(
            preselectedMemberId: args['memberId'] as String?,
            initialName: args['name'] as String?,
            initialCategory: args['category'] as String?,
          ));
        }
        return _page(AddMedicineScreen(preselectedMemberId: args as String?));

      case AppRoutes.scanBarcode:
        return _page(const BarcodeScannerScreen());

      case AppRoutes.medicineDetail:
        final medicineId = settings.arguments as String;
        return _page(MedicineDetailScreen(medicineId: medicineId));

      case AppRoutes.editMedicine:
        final medicineId = settings.arguments as String;
        return _page(EditMedicineScreen(medicineId: medicineId));

      case AppRoutes.notifications:
        return _page(NotificationsScreen());

      case AppRoutes.search:
        return _page(const SearchScreen());

      case AppRoutes.family:
        return _page(FamilyScreen());

      case AppRoutes.addFamilyMember:
        return _page(const AddFamilyMemberScreen());

      case AppRoutes.familyMemberProfile:
        final memberId = settings.arguments as String;
        return _page(FamilyMemberProfileScreen(memberId: memberId));

      case AppRoutes.familyMemberMedicines:
        final memberId = settings.arguments as String;
        return _page(FamilyMemberMedicinesScreen(memberId: memberId));

      case AppRoutes.editFamilyMember:
        final memberId = settings.arguments as String;
        return _page(EditFamilyMemberScreen(memberId: memberId));

      case AppRoutes.profile:
        return _page(const ProfileScreen());

      case AppRoutes.editProfile:
        return _page(const EditProfileScreen());

      case AppRoutes.settings:
        return _page(const SettingsScreen());

      case AppRoutes.analytics:
        return _page(AnalyticsScreen());

      case AppRoutes.aiFeatures:
        return _page(const AiFeaturesScreen());

      case AppRoutes.aiChat:
        final mode = settings.arguments as String?;
        return _page(AiChatScreen(mode: mode));

      case AppRoutes.aiRecommendations:
        return _page(AiRecommendationsScreen());

      case AppRoutes.aiKitBuilder:
        return _page(const AiKitBuilderScreen());

      case AppRoutes.shop:
        return _page(const ShopScreen());

      case AppRoutes.shopProduct:
        final product = settings.arguments as Map<String, dynamic>;
        return _page(ShopProductScreen(product: product));

      case AppRoutes.cart:
        return _page(const CartScreen());

      case AppRoutes.b2bOnboarding:
        return _page(const B2BOnboardingScreen());

      case AppRoutes.b2bLogin:
        return _page(const B2BLoginScreen());

      case AppRoutes.b2bSignup:
        return _page(const B2BSignupScreen());

      case AppRoutes.b2bMain:
      case AppRoutes.b2bDashboard:
        return _page(const B2BMainScreen());

      case AppRoutes.b2bInventory:
        return _page(B2BInventoryScreen());

      case AppRoutes.b2bAddMedicine:
        return _page(const B2BAddMedicineScreen());

      case AppRoutes.b2bMedicineDetail:
        final medicineId = settings.arguments as String;
        return _page(B2BMedicineDetailScreen(medicineId: medicineId));

      case AppRoutes.b2bNotifications:
        return _page(B2BNotificationsScreen());

      case AppRoutes.b2bReports:
        return _page(B2BReportsScreen());

      case AppRoutes.b2bSettings:
        return _page(const B2BSettingsScreen());

      case AppRoutes.b2bTeam:
        return _page(const B2BTeamScreen());

      case AppRoutes.b2bSalesHistory:
        return _page(const B2BSalesHistoryScreen());

      case AppRoutes.b2bLocations:
        return _page(const B2BLocationsScreen());

      default:
        return _page(
          Scaffold(
            body: Center(child: Text('Маршрут не найден: ${settings.name}')),
          ),
        );
    }
  }

  static MaterialPageRoute _page(Widget child) {
    return MaterialPageRoute(builder: (_) => child);
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final String title;

  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
