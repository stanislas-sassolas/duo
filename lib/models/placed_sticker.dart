import 'dart:math' as math;

/// Un sticker posé sur un dessin : soit un de nos stickers importés
/// ([stickerId], image partagée du couple), soit un tampon emoji ([emoji]).
///
/// Position et taille sont normalisées comme les traits : [x], [y] = centre
/// (0–1 sur la largeur / hauteur du canvas), [width] = fraction de la largeur
/// du canvas, [rotation] en radians.
class PlacedSticker {
  const PlacedSticker({
    this.stickerId,
    this.emoji,
    required this.x,
    required this.y,
    this.width = 0.3,
    this.rotation = 0,
  }) : assert(stickerId != null || emoji != null);

  final String? stickerId;
  final String? emoji;
  final double x;
  final double y;
  final double width;
  final double rotation;

  bool get isEmoji => emoji != null;

  PlacedSticker copyWith({
    double? x,
    double? y,
    double? width,
    double? rotation,
  }) {
    return PlacedSticker(
      stickerId: stickerId,
      emoji: emoji,
      x: (x ?? this.x).clamp(0.0, 1.0),
      y: (y ?? this.y).clamp(0.0, 1.0),
      width: (width ?? this.width).clamp(0.06, 1.2),
      rotation: (rotation ?? this.rotation) % (2 * math.pi),
    );
  }

  Map<String, dynamic> toJson() => {
        if (stickerId != null) 's': stickerId,
        if (emoji != null) 'e': emoji,
        'x': double.parse(x.toStringAsFixed(4)),
        'y': double.parse(y.toStringAsFixed(4)),
        'w': double.parse(width.toStringAsFixed(4)),
        'r': double.parse(rotation.toStringAsFixed(3)),
      };

  factory PlacedSticker.fromJson(Map<String, dynamic> json) {
    return PlacedSticker(
      stickerId: json['s'] as String?,
      emoji: json['e'] as String? ?? (json['s'] == null ? '❤️' : null),
      x: (json['x'] as num?)?.toDouble() ?? 0.5,
      y: (json['y'] as num?)?.toDouble() ?? 0.5,
      width: (json['w'] as num?)?.toDouble() ?? 0.3,
      rotation: (json['r'] as num?)?.toDouble() ?? 0,
    );
  }
}
