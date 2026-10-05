import 'package:flutter/material.dart';

/// Palette de l'application : douce, romantique, jamais criarde.
class AppColors {
  AppColors._();

  // Marque
  static const Color primary = Color(0xFFE8687F); // rose corail tendre
  static const Color primaryDark = Color(0xFFD14E67);
  static const Color accent = Color(0xFFF4A7B6);

  // Surfaces claires
  static const Color lightBackground = Color(0xFFFDF8F7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFF0E6E4);
  static const Color lightText = Color(0xFF2B2530);
  static const Color lightSubtext = Color(0xFF8B8290);

  // Surfaces sombres
  static const Color darkBackground = Color(0xFF17141A);
  static const Color darkSurface = Color(0xFF211D26);
  static const Color darkBorder = Color(0xFF322C38);
  static const Color darkText = Color(0xFFF3EEF2);
  static const Color darkSubtext = Color(0xFF9A909E);

  /// Palette proposée sur le canvas, aux couleurs de nos petits emojis.
  static const List<Color> palette = [
    Color(0xFF2B2530), // noir doux
    Color(0xFFFFFFFF), // blanc
    Color(0xFFD62828), // rouge ají 🌶️
    Color(0xFFEC6EA0), // rose
    Color(0xFFF6B91A), // jaune tournesol 🌻
    Color(0xFF6A8D2F), // vert avocat 🥑
    Color(0xFF6B3E26), // brun chocolat 🍫
    Color(0xFF1E88E5), // bleu ciel de ski ⛷️
    Color(0xFF8E24AA), // violet
  ];
}
