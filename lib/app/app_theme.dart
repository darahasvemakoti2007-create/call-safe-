import 'package:flutter/material.dart';

/// Central theme definition for GuardCall.
///
/// Designed with a calm deep navy / soft teal aesthetic tailored for
/// readability, accessibility, and high visual contrast.
class AppTheme {
  // Brand color palette
  static const Color navyBackground = Color(0xFF0B132B);
  static const Color navySurface = Color(0xFF14213D);
  static const Color navySurfaceLight = Color(0xFF1C2D50);
  static const Color navyBorder = Color(0xFF2A3D66);

  static const Color tealPrimary = Color(0xFF2DD4BF); // Teal 400
  static const Color tealDark = Color(0xFF0F766E); // Teal 700
  static const Color tealLight = Color(0xFF99F6E4); // Teal 200
  static const Color skyAccent = Color(0xFF38BDF8); // Sky 400

  // Risk colors (with high-contrast companion text colors)
  static const Color riskSafe = Color(0xFF10B981); // Emerald 500
  static const Color riskSuspicious = Color(0xFFF59E0B); // Amber 500
  static const Color riskHigh = Color(0xFFF97316); // Orange 500
  static const Color riskCritical = Color(0xFFEF4444); // Red 500

  // Neutral text colors
  static const Color textPrimary = Color(0xFFF8FAFC); // Slate 50
  static const Color textSecondary = Color(0xFF94A3B8); // Slate 400
  static const Color textMuted = Color(0xFF64748B); // Slate 500

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: navyBackground,
      colorScheme: const ColorScheme.dark(
        primary: tealPrimary,
        onPrimary: Color(0xFF022C22),
        secondary: skyAccent,
        onSecondary: navyBackground,
        surface: navySurface,
        onSurface: textPrimary,
        error: riskCritical,
        onError: Colors.white,
      ),
      fontFamily: null, // Uses default clean modern system font
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          letterSpacing: -0.5,
          height: 1.25,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.3,
          height: 1.3,
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.35,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.4,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          height: 1.4,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: textPrimary,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: textSecondary,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: textMuted,
          height: 1.4,
        ),
      ),
      cardTheme: CardThemeData(
        color: navySurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: navyBorder, width: 1),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navySurface,
        elevation: 8,
        indicatorColor: tealPrimary.withValues(alpha: 0.18),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: tealPrimary, size: 26);
          }
          return const IconThemeData(color: textSecondary, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: tealPrimary,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: textSecondary,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: navySurfaceLight,
        contentTextStyle: const TextStyle(color: textPrimary, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: navyBorder),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
