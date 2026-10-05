import 'dart:ui';

/// Un point élémentaire d'un tracé.
///
/// Les coordonnées sont **normalisées** entre 0.0 et 1.0 par rapport à la
/// taille du canvas au moment du dessin. Cela permet de rejouer un dessin
/// identiquement quelle que soit la taille d'écran du destinataire.
class DrawPoint {
  const DrawPoint({
    required this.dx,
    required this.dy,
    this.t = 0,
  });

  /// Coordonnée X normalisée (0.0 = bord gauche, 1.0 = bord droit).
  final double dx;

  /// Coordonnée Y normalisée (0.0 = haut, 1.0 = bas).
  final double dy;

  /// Décalage temporel en millisecondes depuis le début du stroke.
  /// Utile pour le futur mode "replay" et le mode live.
  final int t;

  /// Convertit en coordonnées écran réelles pour le rendu.
  Offset toOffset(Size size) => Offset(dx * size.width, dy * size.height);

  /// Crée un point normalisé à partir de coordonnées écran réelles.
  factory DrawPoint.fromOffset(Offset offset, Size size, {int t = 0}) {
    final safeWidth = size.width == 0 ? 1.0 : size.width;
    final safeHeight = size.height == 0 ? 1.0 : size.height;
    return DrawPoint(
      dx: (offset.dx / safeWidth).clamp(0.0, 1.0),
      dy: (offset.dy / safeHeight).clamp(0.0, 1.0),
      t: t,
    );
  }

  /// Représentation `{x, y, t}`.
  ///
  /// Volontairement un objet et non un tableau : Firestore **interdit les
  /// tableaux imbriqués** (un stroke contient déjà un tableau de points).
  Map<String, num> toJson() => {
        'x': double.parse(dx.toStringAsFixed(4)),
        'y': double.parse(dy.toStringAsFixed(4)),
        't': t,
      };

  factory DrawPoint.fromJson(Map<String, dynamic> json) {
    return DrawPoint(
      dx: (json['x'] as num).toDouble(),
      dy: (json['y'] as num).toDouble(),
      t: (json['t'] as num?)?.toInt() ?? 0,
    );
  }
}
