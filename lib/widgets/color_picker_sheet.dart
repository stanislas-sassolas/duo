import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';

/// Nuancier complet (fenêtre du bas) : une grille de teintes et de nuances,
/// plus les couleurs utilisées récemment. Renvoie la couleur choisie.
class ColorPickerSheet extends StatelessWidget {
  const ColorPickerSheet({super.key, required this.recent});

  final List<Color> recent;

  /// Teintes (0–360°) de chaque colonne, puis gris en dernière colonne.
  static const List<double> _hues = [0, 20, 40, 55, 90, 140, 175, 200, 225, 260, 290, 330];

  /// Nuances de chaque ligne : (saturation, luminosité).
  static const List<(double, double)> _shades = [
    (0.25, 0.97),
    (0.45, 0.92),
    (0.7, 0.88),
    (0.85, 0.78),
    (0.85, 0.6),
    (0.8, 0.42),
  ];

  static const List<Color> _greys = [
    Color(0xFFFFFFFF),
    Color(0xFFE6E1E4),
    Color(0xFFB9B1B6),
    Color(0xFF857C82),
    Color(0xFF4D4550),
    Color(0xFF1E1A1F),
  ];

  /// Ouvre le nuancier et mémorise la couleur choisie dans les récentes.
  static Future<Color?> show(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final recent = (prefs.getStringList(AppConstants.prefRecentColors) ?? [])
        .map((value) => Color(int.parse(value)))
        .toList();
    if (!context.mounted) return null;
    final color = await showModalBottomSheet<Color>(
      context: context,
      showDragHandle: true,
      builder: (_) => ColorPickerSheet(recent: recent),
    );
    if (color != null) {
      final updated = [
        color.toARGB32().toString(),
        ...recent
            .map((c) => c.toARGB32().toString())
            .where((v) => v != color.toARGB32().toString()),
      ].take(12).toList();
      await prefs.setStringList(AppConstants.prefRecentColors, updated);
    }
    return color;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (recent.isNotEmpty) ...[
              Text('Récentes', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final c in recent) _Dot(color: c, size: 32)],
              ),
              const SizedBox(height: 16),
            ],
            Text('Toutes les couleurs', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = _hues.length + 1;
                final size = (constraints.maxWidth / columns) - 4;
                return Column(
                  children: [
                    for (var row = 0; row < _shades.length; row++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (final hue in _hues)
                              _Dot(
                                color: HSVColor.fromAHSV(
                                  1,
                                  hue,
                                  _shades[row].$1,
                                  _shades[row].$2,
                                ).toColor(),
                                size: size,
                                square: true,
                              ),
                            _Dot(color: _greys[row], size: size, square: true),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.size, this.square = false});

  final Color color;
  final double size;
  final bool square;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(color),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: square ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: square ? BorderRadius.circular(6) : null,
          border: Border.all(color: Colors.black12),
        ),
      ),
    );
  }
}
