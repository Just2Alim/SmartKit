import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF10B981);
  static const Color primaryDark = Color(0xFF047857);
  static const Color primarySoft = Color(0xFFD1FAE5);
  static const Color secondary = Color(0xFF0EA5E9);

  static const Color background = Color(0xFFF9FAFB);
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color darkSurface = Color(0xFF111827);
  static const Color darkSurfaceHigh = Color(0xFF1F2937);

  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);

  static const Color accentGreen = Color(0xFFDCFCE7);
  static const Color accentBlue = Color(0xFFDBEAFE);
  static const Color accentPurple = Color(0xFFF3E8FF);

  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static Color card(BuildContext context) {
    return Theme.of(context).cardColor;
  }

  static Color page(BuildContext context) {
    return Theme.of(context).scaffoldBackgroundColor;
  }

  static Color text(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  static Color mutedText(BuildContext context) {
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  static Color border(BuildContext context) {
    return Theme.of(context).colorScheme.outlineVariant;
  }

  static Color softFill(BuildContext context) {
    return Theme.of(context).colorScheme.surfaceContainerHighest;
  }

  static Color softTint(BuildContext context, Color color) {
    return color.withValues(alpha: isDark(context) ? 0.18 : 0.1);
  }

  static Color shadow(BuildContext context) {
    return Colors.black.withValues(alpha: isDark(context) ? 0.28 : 0.06);
  }

  static List<Color> brandGradient(BuildContext context) {
    return isDark(context)
        ? const [Color(0xFF065F46), Color(0xFF0F172A)]
        : const [primary, primaryDark];
  }
}
