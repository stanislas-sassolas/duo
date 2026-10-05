import 'dart:math';

import 'package:flutter/material.dart';

/// Quelques étoiles très pâles, affichées seulement en thème sombre
/// (clin d'œil au Petit Prince). Purement décoratif, ne capte aucun toucher.
class StarryBackground extends StatelessWidget {
  const StarryBackground({super.key});

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).brightness != Brightness.dark) {
      return const SizedBox.shrink();
    }
    return const IgnorePointer(
      child: CustomPaint(painter: _StarsPainter(), size: Size.infinite),
    );
  }
}

class _StarsPainter extends CustomPainter {
  const _StarsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Graine fixe : les étoiles restent à la même place à chaque affichage.
    final random = Random(1943);
    final paint = Paint()..color = const Color(0x22FFFFFF);
    for (var i = 0; i < 28; i++) {
      final center = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      canvas.drawCircle(center, 0.6 + random.nextDouble() * 1.2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarsPainter oldDelegate) => false;
}
