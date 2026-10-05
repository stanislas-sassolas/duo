import 'dart:ui';

import '../core/constants/app_constants.dart';
import 'draw_point.dart';
import 'enums.dart';

/// Un tracé continu : suite de points partageant la même couleur, largeur et
/// outil. Un dessin est une liste ordonnée de [Stroke].
///
/// Représentation vectorielle (et non une image aplatie) : cela permet le
/// replay stroke par stroke et le futur mode live.
class Stroke {
  const Stroke({
    required this.points,
    required this.color,
    required this.width,
    required this.tool,
    required this.startedAt,
  });

  final List<DrawPoint> points;

  /// Couleur ARGB. Ignorée visuellement quand [tool] == eraser.
  final int color;

  /// Largeur en **fraction de la largeur du canvas** (voir
  /// [BrushSize.relativeWidth]) : le trait garde les mêmes proportions sur un
  /// petit téléphone, une tablette ou une vignette.
  final double width;

  final BrushTool tool;

  /// Instant de début du tracé (epoch ms), pour l'ordonnancement et le replay.
  final int startedAt;

  bool get isEraser => tool == BrushTool.eraser;

  Color get uiColor => Color(color);

  /// Épaisseur réelle en pixels pour un canvas de taille [size].
  double widthFor(Size size) => width * size.width;

  Stroke copyWith({List<DrawPoint>? points}) {
    return Stroke(
      points: points ?? this.points,
      color: color,
      width: width,
      tool: tool,
      startedAt: startedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'p': points.map((point) => point.toJson()).toList(),
        'c': color,
        'wr': double.parse(width.toStringAsFixed(5)),
        't': tool.id,
        'ts': startedAt,
      };

  factory Stroke.fromJson(Map<String, dynamic> json) {
    return Stroke(
      points: (json['p'] as List<dynamic>)
          .map((raw) => DrawPoint.fromJson(raw as Map<String, dynamic>))
          .toList(),
      color: (json['c'] as num).toInt(),
      width: _widthFromJson(json),
      tool: BrushTool.fromId(json['t'] as String?),
      startedAt: (json['ts'] as num?)?.toInt() ?? 0,
    );
  }

  /// `wr` = largeur relative (format actuel). Les anciens dessins n'ont que
  /// `w`, en pixels absolus : on les ramène au canvas de référence.
  static double _widthFromJson(Map<String, dynamic> json) {
    final relative = json['wr'] as num?;
    if (relative != null) return relative.toDouble();
    final legacyPixels = (json['w'] as num?)?.toDouble() ?? 9;
    return legacyPixels / AppConstants.referenceCanvasWidth;
  }
}
