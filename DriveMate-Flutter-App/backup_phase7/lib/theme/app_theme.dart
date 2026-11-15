import 'package:flutter/material.dart';

class AppColors {
  // DriveMate Primary Brand Colors (Deep Navy & Vibrant Cyan/Teal)
  static const Color navy900 = Color(0xFF0A192F);
  static const Color navy800 = Color(0xFF0F264A);
  static const Color navy700 = Color(0xFF1E3A66);
  static const Color navy600 = Color(0xFF2C5282);

  static const Color electricBlue = Color(0xFF0284C7);
  static const Color cyanAccent = Color(0xFF00B4D8);
  static const Color cyanLight = Color(0xFFE0F2FE);

  static const Color accentGold = Color(0xFFF59E0B);
  static const Color successGreen = Color(0xFF10B981);
  static const Color errorRed = Color(0xFFEF4444);

  // Neutral Surfaces
  static const Color surfaceLight = Color(0xFFF8FAFC);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF0A192F);
  static const Color surfaceCardDark = Color(0xFF132238);

  static const Color textPrimaryDark = Color(0xFF0F172A);
  static const Color textSecondaryDark = Color(0xFF64748B);
  static const Color textPrimaryLight = Color(0xFFF8FAFC);
  static const Color textSecondaryLight = Color(0xFF94A3B8);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.electricBlue,
      scaffoldBackgroundColor: AppColors.surfaceLight,
      colorScheme: const ColorScheme.light(
        primary: AppColors.electricBlue,
        secondary: AppColors.cyanAccent,
        surface: AppColors.surfaceCard,
        error: AppColors.errorRed,
        onPrimary: Colors.white,
        onSecondary: AppColors.navy900,
        onSurface: AppColors.textPrimaryDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.navy900,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: AppColors.surfaceCard,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      fontFamily: 'Roboto',
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.cyanAccent,
      scaffoldBackgroundColor: AppColors.navy900,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.cyanAccent,
        secondary: AppColors.electricBlue,
        surface: AppColors.surfaceCardDark,
        error: AppColors.errorRed,
        onPrimary: AppColors.navy900,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimaryLight,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.navy900,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: AppColors.surfaceCardDark,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
