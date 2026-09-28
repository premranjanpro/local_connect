import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  ShopConnector App Theme — Dark & Light
// ══════════════════════════════════════════════════════════════════════════════

class AppTheme {
  // ── Brand colours ──────────────────────────────────────────────────────────
  static const Color primaryBlue   = Color(0xFF1D4ED8);
  static const Color primaryGreen  = Color(0xFF059669);
  static const Color primaryAmber  = Color(0xFFF59E0B);
  static const Color accentPurple  = Color(0xFF8B5CF6);
  static const Color accentIndigo  = Color(0xFF6366F1);
  static const Color successGreen  = Color(0xFF10B981);
  static const Color dangerRed     = Color(0xFFEF4444);

  // ── Dark palette (default) ─────────────────────────────────────────────────
  static const Color darkBg        = Color(0xFF060B18);
  static const Color darkSurface   = Color(0xFF0F172A);
  static const Color darkCard      = Color(0xFF1E293B);
  static const Color darkCard2     = Color(0xFF334155);
  static const Color darkBorder    = Color(0xFF1E293B);
  static const Color darkText      = Color(0xFFE2E8F0);
  static const Color darkSubText   = Color(0xFF94A3B8);
  static const Color darkHint      = Color(0xFF64748B);

  // ── Light palette ──────────────────────────────────────────────────────────
  static const Color lightBg       = Color(0xFFF1F5F9);
  static const Color lightSurface  = Color(0xFFFFFFFF);
  static const Color lightCard     = Color(0xFFFFFFFF);
  static const Color lightCard2    = Color(0xFFF8FAFC);
  static const Color lightBorder   = Color(0xFFE2E8F0);
  static const Color lightText     = Color(0xFF0F172A);
  static const Color lightSubText  = Color(0xFF475569);
  static const Color lightHint     = Color(0xFF94A3B8);

  // ══════════════════════════════════════════════════════════════════════════
  //  DARK THEME
  // ══════════════════════════════════════════════════════════════════════════
  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      colorScheme: ColorScheme.dark(
        primary: primaryBlue,
        secondary: primaryGreen,
        tertiary: accentPurple,
        surface: darkSurface,
        error: dangerRed,
      ),
      cardColor: darkCard,
      dividerColor: Colors.white10,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkText,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: darkText),
        titleTextStyle: TextStyle(
          color: darkText,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: primaryBlue,
        unselectedLabelColor: darkSubText,
        indicatorColor: primaryBlue,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
        ),
        labelStyle: const TextStyle(color: darkSubText),
        hintStyle: const TextStyle(color: darkHint),
        prefixIconColor: darkSubText,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          side: const BorderSide(color: primaryBlue),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkCard2,
        labelStyle: const TextStyle(color: darkText, fontSize: 11),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: darkText, fontWeight: FontWeight.bold, fontSize: 26),
        headlineMedium: TextStyle(color: darkText, fontWeight: FontWeight.bold, fontSize: 22),
        titleLarge: TextStyle(color: darkText, fontWeight: FontWeight.bold, fontSize: 18),
        titleMedium: TextStyle(color: darkText, fontWeight: FontWeight.w600, fontSize: 15),
        bodyLarge: TextStyle(color: darkText, fontSize: 14),
        bodyMedium: TextStyle(color: darkSubText, fontSize: 13),
        bodySmall: TextStyle(color: darkHint, fontSize: 11),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 8,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primaryGreen : darkCard2,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? primaryGreen.withValues(alpha: 0.4)
              : darkCard2,
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: primaryBlue,
        thumbColor: primaryBlue,
        inactiveTrackColor: darkCard2,
      ),
      iconTheme: const IconThemeData(color: darkSubText),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  LIGHT THEME
  // ══════════════════════════════════════════════════════════════════════════
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      colorScheme: ColorScheme.light(
        primary: primaryBlue,
        secondary: primaryGreen,
        tertiary: accentPurple,
        surface: lightSurface,
        error: dangerRed,
      ),
      cardColor: lightCard,
      dividerColor: lightBorder,
      appBarTheme: const AppBarTheme(
        backgroundColor: lightSurface,
        foregroundColor: lightText,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: lightText),
        titleTextStyle: TextStyle(
          color: lightText,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: primaryBlue,
        unselectedLabelColor: lightSubText,
        indicatorColor: primaryBlue,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
        ),
        labelStyle: const TextStyle(color: lightSubText),
        hintStyle: const TextStyle(color: lightHint),
        prefixIconColor: lightSubText,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          side: const BorderSide(color: primaryBlue),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lightCard2,
        labelStyle: const TextStyle(color: lightText, fontSize: 11),
        side: const BorderSide(color: lightBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: lightText, fontWeight: FontWeight.bold, fontSize: 26),
        headlineMedium: TextStyle(color: lightText, fontWeight: FontWeight.bold, fontSize: 22),
        titleLarge: TextStyle(color: lightText, fontWeight: FontWeight.bold, fontSize: 18),
        titleMedium: TextStyle(color: lightText, fontWeight: FontWeight.w600, fontSize: 15),
        bodyLarge: TextStyle(color: lightText, fontSize: 14),
        bodyMedium: TextStyle(color: lightSubText, fontSize: 13),
        bodySmall: TextStyle(color: lightHint, fontSize: 11),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: lightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 8,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primaryGreen : lightHint,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? primaryGreen.withValues(alpha: 0.4)
              : lightBorder,
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: primaryBlue,
        thumbColor: primaryBlue,
        inactiveTrackColor: lightBorder,
      ),
      iconTheme: const IconThemeData(color: lightSubText),
    );
  }
}
