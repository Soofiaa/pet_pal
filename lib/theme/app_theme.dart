import 'package:flutter/material.dart';

import 'package:pet_pal/theme/category_colors.dart';

/// Paleta de PetPal. Los pares texto/fondo cumplen 4.5:1 (WCAG AA); ver
/// test/theme/app_theme_test.dart.
class AppPalette {
  const AppPalette._();

  static const Color seed = Color(0xFF0F766E);

  static const Color lightSurface = Color(0xFFF7FAF9);
  static const Color lightOnSurface = Color(0xFF1B2422);
  static const Color lightOnSurfaceVariant = Color(0xFF5F6B69);
  static const Color lightPrimary = Color(0xFF0F766E);
  static const Color lightError = Color(0xFFB93815);

  static const Color darkSurface = Color(0xFF101514);
  static const Color darkOnSurface = Color(0xFFE3EAE8);
  static const Color darkOnSurfaceVariant = Color(0xFFA9B5B2);
  static const Color darkPrimary = Color(0xFF5EEAD4);
  static const Color darkOnPrimary = Color(0xFF00201C);
  static const Color darkAppBar = Color(0xFF16302D);
  static const Color darkError = Color(0xFFFFB4A2);

  /// Acento de acciones destacadas (botón flotante). El ícono es gráfico, por
  /// eso basta 3:1 contra el blanco.
  static const Color accent = CategoryColors.agenda;
}

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  final scheme = ColorScheme.fromSeed(
    seedColor: AppPalette.seed,
    brightness: brightness,
  ).copyWith(
    primary: isDark ? AppPalette.darkPrimary : AppPalette.lightPrimary,
    onPrimary: isDark ? AppPalette.darkOnPrimary : Colors.white,
    secondary: AppPalette.accent,
    onSecondary: Colors.white,
    error: isDark ? AppPalette.darkError : AppPalette.lightError,
    onError: isDark ? AppPalette.darkSurface : Colors.white,
    surface: isDark ? AppPalette.darkSurface : AppPalette.lightSurface,
    onSurface: isDark ? AppPalette.darkOnSurface : AppPalette.lightOnSurface,
    onSurfaceVariant:
        isDark ? AppPalette.darkOnSurfaceVariant : AppPalette.lightOnSurfaceVariant,
  );

  final appBarBackground = isDark ? AppPalette.darkAppBar : scheme.primary;
  final appBarForeground = isDark ? AppPalette.darkOnSurface : Colors.white;

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    appBarTheme: AppBarTheme(
      backgroundColor: appBarBackground,
      foregroundColor: appBarForeground,
      centerTitle: true,
      elevation: 4,
      titleTextStyle: TextStyle(
        color: appBarForeground,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.secondary,
      foregroundColor: scheme.onSecondary,
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: const TextStyle(fontSize: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      floatingLabelStyle: TextStyle(color: scheme.primary),
    ),
  );
}
