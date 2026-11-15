import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

/// DriveMate visual system.
/// Deep navy is the brand color, electric blue is the action color,
/// and pages sit on white / light grey. Existing token names are kept
/// so screens, API flows, and navigation stay wired the same way.
class AppColors {
  /// Global dark mode indicator dynamically synchronized with provider state.
  static bool isDarkModeGlobal = false;

  static const Color navy = Color(0xFF0B1C38);
  static const Color electric = Color(0xFF2F6FED);
  static const Color lightPage = Color(0xFFF4F7FB);
  static const Color ink = Color(0xFF0B1C38);
  static const Color slate = Color(0xFF5C6B82);
  static const Color muted = Color(0xFF8A97AB);
  static const Color lightLine = Color(0xFFE4EBF3);

  // Dark Mode Tokens (Deep midnight navy + crisp contrast hierarchy)
  static const Color darkBg = Color(0xFF0A1220); // scaffold
  static const Color darkCardBg = Color(0xFF122238); // elevated cards
  static const Color darkCardElevated = Color(0xFF192C48); // inner cards / inputs
  static const Color darkBorder = Color(0xFF1E3A5F); // borders
  static const Color darkTextPrimary = Color(0xFFF8FAFC); // heading / primary
  static const Color darkTextSecondary = Color(0xFFCBD5E1); // body / secondary
  static const Color darkTextMuted = Color(0xFF94A3B8); // captions / placeholders

  static const Color page = lightPage;
  static const Color bgDark = lightPage;
  static const Color bgSecondary = Color(0xFFFFFFFF);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color cardElevated = Color(0xFFF8FAFC);

  static const Color primaryBlue = electric;
  static const Color accentCyan = Color(0xFF0EA5E9);
  static const Color successGreen = Color(0xFF16A34A);
  static const Color errorRed = Color(0xFFDC2626);
  static const Color warningAmber = Color(0xFFD97706);

  static const Color textPrimary = ink;
  static const Color textSecondary = slate;
  static const Color textMuted = muted;

  static const Color line = lightLine;
  static const Color borderSubtle = lightLine;
  static const Color borderFocus = electric;

  static const Color primaryDark = navy;
  static const Color primaryNavy = navy;
  static const Color primaryLight = Color(0xFF16325C);
  static const Color navy900 = navy;
  static const Color navy800 = Color(0xFF12243F);
  static const Color navy700 = Color(0xFF1A3358);
  static const Color navy600 = Color(0xFF23406B);

  static const Color electricBlue = electric;
  static const Color cyanAccent = accentCyan;
  static const Color cyanLight = Color(0xFFE7F0FF);

  static const Color accentGold = Color(0xFFD97706);

  static const Color surfaceLight = lightPage;
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceDark = darkBg;
  static const Color surfaceCardDark = darkCardBg;

  static const Color textPrimaryDark = ink;
  static const Color textSecondaryDark = slate;
  static const Color textPrimaryLight = ink;
  static const Color textSecondaryLight = Color(0xFFC5D0DE);

  static const Color onNavy = Color(0xFFFFFFFF);

  // Context-aware design token resolvers
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark || isDarkModeGlobal;

  static Color textPrimaryOf(BuildContext context) =>
      isDark(context) ? darkTextPrimary : textPrimary;

  static Color textSecondaryOf(BuildContext context) =>
      isDark(context) ? darkTextSecondary : textSecondary;

  static Color textMutedOf(BuildContext context) =>
      isDark(context) ? darkTextMuted : textMuted;

  static Color cardBgOf(BuildContext context) =>
      isDark(context) ? darkCardBg : cardBg;

  static Color cardElevatedOf(BuildContext context) =>
      isDark(context) ? darkCardElevated : cardElevated;

  static Color pageBgOf(BuildContext context) =>
      isDark(context) ? darkBg : page;

  static Color borderSubtleOf(BuildContext context) =>
      isDark(context) ? darkBorder : borderSubtle;

  static Color inputFillOf(BuildContext context) =>
      isDark(context) ? darkCardElevated : const Color(0xFFF8FAFC);

  static Color navy900Of(BuildContext context) =>
      isDark(context) ? const Color(0xFF93C5FD) : navy900;

  static Color navy700Of(BuildContext context) =>
      isDark(context) ? darkTextPrimary : navy700;

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF0B1C38), Color(0xFF1D4ED8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient buttonGradient = LinearGradient(
    colors: [Color(0xFF2F6FED), Color(0xFF1D4ED8)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient driverGreenGradient = LinearGradient(
    colors: [Color(0xFF22C55E), Color(0xFF15803D)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient cardDarkGradient = LinearGradient(
    colors: [Color(0xFF12243F), Color(0xFF0B1C38)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static List<BoxShadow> get softShadow => [
        const BoxShadow(
          color: Color(0x120B1C38),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get blueGlowShadow => [
        BoxShadow(
          color: electric.withOpacity(0.22),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get greenGlowShadow => [
        BoxShadow(
          color: successGreen.withOpacity(0.18),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];
}

class AppTheme {
  static ThemeData get lightTheme {
    const scheme = ColorScheme.light(
      primary: AppColors.electric,
      onPrimary: Colors.white,
      secondary: AppColors.accentCyan,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: AppColors.ink,
      error: AppColors.errorRed,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.page,
      primaryColor: AppColors.electric,
      canvasColor: AppColors.page,
      colorScheme: scheme,
      dividerColor: AppColors.line,
      splashColor: AppColors.electric.withOpacity(0.08),
      highlightColor: AppColors.electric.withOpacity(0.05),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.lightLine),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.electric,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy,
          side: const BorderSide(color: AppColors.lightLine),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.electric,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.slate, fontWeight: FontWeight.w600),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.lightLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.lightLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.electric, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.errorRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.errorRed, width: 1.6),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.electric),
      dividerTheme: const DividerThemeData(color: AppColors.lightLine, thickness: 1),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// Dark Mode Theme configured with complete design tokens for high-contrast accessibility.
  static ThemeData get darkTheme {
    const darkSurface = AppColors.darkCardBg;
    const darkBg = AppColors.darkBg;
    const darkBorder = AppColors.darkBorder;
    const textBright = AppColors.darkTextPrimary;
    const textSubtle = AppColors.darkTextSecondary;
    const textDim = AppColors.darkTextMuted;

    const scheme = ColorScheme.dark(
      primary: AppColors.electric,
      onPrimary: Colors.white,
      secondary: AppColors.accentCyan,
      onSecondary: Colors.white,
      surface: darkSurface,
      onSurface: textBright,
      error: AppColors.errorRed,
      onError: Colors.white,
      outline: darkBorder,
      outlineVariant: Color(0xFF23406B),
      surfaceContainerHighest: AppColors.darkCardElevated,
      onSurfaceVariant: textSubtle,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      primaryColor: AppColors.electric,
      canvasColor: darkBg,
      colorScheme: scheme,
      dividerColor: darkBorder,
      splashColor: AppColors.electric.withOpacity(0.12),
      highlightColor: AppColors.electric.withOpacity(0.08),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        foregroundColor: textBright,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          color: textBright,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: textBright, fontWeight: FontWeight.w800),
        headlineMedium: TextStyle(color: textBright, fontWeight: FontWeight.w700),
        headlineSmall: TextStyle(color: textBright, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(color: textBright, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: textBright, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: textSubtle, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: textBright, fontSize: 15),
        bodyMedium: TextStyle(color: textSubtle, fontSize: 13.5),
        bodySmall: TextStyle(color: textDim, fontSize: 12),
        labelLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        labelMedium: TextStyle(color: textSubtle, fontWeight: FontWeight.w600),
        labelSmall: TextStyle(color: textDim, fontSize: 11),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.electric,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.electric,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textBright,
          side: const BorderSide(color: darkBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentCyan,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkCardElevated,
        hintStyle: const TextStyle(color: textDim, fontSize: 14),
        labelStyle: const TextStyle(color: textSubtle, fontWeight: FontWeight.w600),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: AppColors.electric, width: 1.6),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: AppColors.errorRed),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: AppColors.errorRed, width: 1.6),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: darkSurface,
        contentTextStyle: const TextStyle(color: textBright, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: const TextStyle(color: textBright, fontSize: 18, fontWeight: FontWeight.w800),
        contentTextStyle: const TextStyle(color: textSubtle, fontSize: 14),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: darkSurface,
        headerBackgroundColor: AppColors.navy,
        headerForegroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          if (states.contains(WidgetState.disabled)) return textDim.withOpacity(0.5);
          return textBright;
        }),
        yearForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return textBright;
        }),
      ),
      timePickerTheme: const TimePickerThemeData(
        backgroundColor: darkSurface,
        hourMinuteTextColor: textBright,
        dialTextColor: textBright,
        dialHandColor: AppColors.electric,
        entryModeIconColor: textBright,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.electric),
      dividerTheme: const DividerThemeData(color: darkBorder, thickness: 1),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
