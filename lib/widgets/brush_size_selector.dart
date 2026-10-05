import 'package:flutter/material.dart';

import '../models/enums.dart';

/// Sélecteur de taille de pinceau (très fin / fin / moyen / épais).
class BrushSizeSelector extends StatelessWidget {
  const BrushSizeSelector({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.color,
  });

  final BrushSize selected;
  final ValueChanged<BrushSize> onSelected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final size in BrushSize.values)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: _Dot(
              size: size,
              color: color,
              selected: size == selected,
              onTap: () => onSelected(size),
            ),
          ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.size,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final BrushSize size;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Container(
            width: size.strokeWidth + 6,
            height: size.strokeWidth + 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}
