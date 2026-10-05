import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Thèmes clair et sombre, minimalistes et cohérents.
///
/// Typographie : police système pour l'interface, **Fraunces** (serif douce)
/// pour les prénoms et titres, **Caveat** (manuscrite) pour les petits mots
/// écrits sur les polaroïds.
class AppTheme {
  AppTheme._();

  static const double radius = 20;

  static const String serif = 'Fraunces';
  static const String handwriting = 'Caveat';

  /// Style des prénoms et titres.
  static TextStyle serifStyle(BuildContext context, {double size = 24}) =>
      TextStyle(
        fontFamily: serif,
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
        height: 1.15,
      );

  /// Style « écrit à la main » des petits mots.
  static TextStyle handStyle(BuildContext context, {double size = 26}) =>
      TextStyle(
        fontFamily: handwriting,
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: AppColors.lightText,
        height: 1.1,
      );

  static ThemeData get light => _base(
        brightness: Brightness.light,
        background: AppColors.lightBackground,
        surface: AppColors.lightSurface,
        border: AppColors.lightBorder,
        text: AppColors.lightText,
        subtext: AppColors.lightSubtext,
      );

  static ThemeData get dark => _base(
        brightness: Brightness.dark,
        background: AppColors.darkBackground,
        surface: AppColors.darkSurface,
        border: AppColors.darkBorder,
        text: AppColors.darkText,
        subtext: AppColors.darkSubtext,
      );

  static ThemeData _base({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color border,
    required Color text,
    required Color subtext,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    ).copyWith(
      primary: AppColors.primary,
      surface: surface,
    );

    final textTheme = Typography.material2021(platform: TargetPlatform.iOS)
        .black
        .apply(
          bodyColor: text,
          displayColor: text,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: brightness == Brightness.dark
          ? textTheme.apply(bodyColor: text, displayColor: text)
          : textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: text,
        titleTextStyle: TextStyle(
          fontFamily: serif,
          color: text,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        hintStyle: TextStyle(color: subtext),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
    );
  }
}
