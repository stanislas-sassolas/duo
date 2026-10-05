import 'package:flutter/material.dart';

/// Rangée de pastilles de couleur sélectionnables.
class ColorPalette extends StatelessWidget {
  const ColorPalette({
    super.key,
    required this.colors,
    required this.selected,
    required this.onSelected,
    this.onMore,
  });

  final List<Color> colors;
  final Color selected;
  final ValueChanged<Color> onSelected;

  /// Ouvre le nuancier complet (dernière pastille, arc-en-ciel).
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    // Toutes les couleurs visibles d'un coup, réparties sur la largeur
    // (une palette qui défile cachait la dernière couleur).
    return SizedBox(
      height: 44,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = colors.length + (onMore != null ? 1 : 0);
          final slot = constraints.maxWidth / count;
          final base = (slot - 6).clamp(20.0, 34.0);
          final isCustom =
              !colors.any((c) => c.toARGB32() == selected.toARGB32());
          return Row(
            children: [
              for (final color in colors)
                Expanded(
                  child: Center(
                    child: _Swatch(
                      color: color,
                      size: base,
                      selected: color.toARGB32() == selected.toARGB32(),
                      onTap: () => onSelected(color),
                    ),
                  ),
                ),
              if (onMore != null)
                Expanded(
                  child: Center(
                    child: _MoreSwatch(
                      size: base,
                      // Une couleur du nuancier est choisie : on l'affiche ici.
                      custom: isCustom ? selected : null,
                      onTap: onMore!,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final double size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: selected ? size + 6 : size,
        height: selected ? size + 6 : size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.black12,
            width: selected ? 3 : 1,
          ),
        ),
      ),
    );
  }
}

/// Pastille arc-en-ciel « + » : plus de couleurs.
class _MoreSwatch extends StatelessWidget {
  const _MoreSwatch({
    required this.size,
    required this.custom,
    required this.onTap,
  });

  final double size;
  final Color? custom;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = custom != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: selected ? size + 6 : size,
        height: selected ? size + 6 : size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: custom,
          gradient: custom == null
              ? const SweepGradient(
                  colors: [
                    Color(0xFFE53935),
                    Color(0xFFFDD835),
                    Color(0xFF43A047),
                    Color(0xFF1E88E5),
                    Color(0xFF8E24AA),
                    Color(0xFFE53935),
                  ],
                )
              : null,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.black12,
            width: selected ? 3 : 1,
          ),
        ),
        child: custom == null
            ? const Icon(Icons.add_rounded, size: 18, color: Colors.white)
            : null,
      ),
    );
  }
}
