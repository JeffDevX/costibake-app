import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  /// 🍨 Modo Vainilla: Pastelería suave, crema cálida y caramelo miel (Stitch Light).
  static ThemeData get vainillaTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryCaramel,
        onPrimary: Colors.white,
        secondary: AppColors.honeyAccent,
        onSecondary: Colors.white,
        surface: AppColors.surfaceWarm,
        onSurface: AppColors.textEspresso,
        error: AppColors.costRed,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.surfaceWarm,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.butterCream,
        foregroundColor: AppColors.textEspresso,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textEspresso,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceCard,
        elevation: 1,
        shadowColor: AppColors.textEspresso.withAlpha(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderWarm, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryCaramel,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 48), // Kitchen touch standard >= 48px
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryCaramel,
          minimumSize: const Size(64, 48),
          side: const BorderSide(color: AppColors.primaryCaramel, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderWarm),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderWarm),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryCaramel, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.costRed),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primaryCaramel,
        unselectedItemColor: AppColors.textMuted,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      extensions: const [
        BakeryColorsExtension.vainilla,
      ],
    );
  }

  /// 🍫 Modo Cacao: Chocolate trufa, cacao profundo y ámbar dorado (Stitch Dark).
  static ThemeData get cacaoTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.cacaoPrimaryCaramel,
        onPrimary: Color(0xFF1A1614),
        secondary: AppColors.cacaoHoneyAccent,
        onSecondary: Color(0xFF1A1614),
        surface: AppColors.cacaoSurfaceWarm,
        onSurface: AppColors.cacaoTextEspresso,
        error: AppColors.cacaoCostRed,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.cacaoSurfaceWarm,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.cacaoButterCream,
        foregroundColor: AppColors.cacaoTextEspresso,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.cacaoTextEspresso,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cacaoSurfaceCard,
        elevation: 2,
        shadowColor: Colors.black.withAlpha(120),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cacaoBorderWarm, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.cacaoPrimaryCaramel,
          foregroundColor: const Color(0xFF1A1614),
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.cacaoPrimaryCaramel,
          minimumSize: const Size(64, 48),
          side: const BorderSide(color: AppColors.cacaoPrimaryCaramel, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF141110),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cacaoBorderWarm),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cacaoBorderWarm),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cacaoPrimaryCaramel, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cacaoCostRed),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.cacaoSurfaceCard,
        selectedItemColor: AppColors.cacaoPrimaryCaramel,
        unselectedItemColor: AppColors.cacaoTextMuted,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      extensions: const [
        BakeryColorsExtension.cacao,
      ],
    );
  }

  // Backwards compatibility aliases
  static ThemeData get lightTheme => vainillaTheme;
  static ThemeData get darkTheme => cacaoTheme;
}
