import 'dart:math' as math;

import '../../models/draw_point.dart';
import '../../models/stroke.dart';
import '../constants/app_constants.dart';

/// Allège un dessin avant l'envoi, sans changement visible.
///
/// Un écran à 120 Hz produit ~120 points par seconde de tracé, dont beaucoup
/// sont presque alignés. L'algorithme de Ramer-Douglas-Peucker supprime les
/// points qui s'écartent de moins de [tolerance] de la ligne formée par leurs
/// voisins. Résultat typique : 60 à 80 % de points en moins.
///
/// Indispensable car un document Firestore est limité à 1 Mio.
class StrokeSimplifier {
  StrokeSimplifier._();

  /// Tolérance par défaut, en fraction de la largeur du canvas
  /// (≈ 0,2 px sur un canvas de 360 px : invisible, même pour les détails
  /// fins dessinés en zoomant). Augmentée seulement si le dessin est lourd.
  static const double defaultTolerance = 0.0006;

  /// Nombre total de points d'une liste de traits.
  static int countPoints(List<Stroke> strokes) =>
      strokes.fold(0, (sum, stroke) => sum + stroke.points.length);

  /// Simplifie [strokes] jusqu'à passer sous
  /// [AppConstants.maxPointsPerDrawing], en augmentant la tolérance si
  /// nécessaire. Retourne `null` si le dessin reste trop lourd.
  static List<Stroke>? compressForUpload(
    List<Stroke> strokes, {
    double aspectRatio = AppConstants.canvasAspectRatio,
    int maxPoints = AppConstants.maxPointsPerDrawing,
  }) {
    var tolerance = defaultTolerance;
    for (var attempt = 0; attempt < 6; attempt++) {
      final simplified = [
        for (final stroke in strokes)
          simplifyStroke(stroke, tolerance: tolerance, aspectRatio: aspectRatio),
      ];
      if (countPoints(simplified) <= maxPoints) return simplified;
      tolerance *= 2;
    }
    return null;
  }

  static Stroke simplifyStroke(
    Stroke stroke, {
    double tolerance = defaultTolerance,
    double aspectRatio = AppConstants.canvasAspectRatio,
  }) {
    if (stroke.points.length <= 2) return stroke;
    return stroke.copyWith(
      points: simplifyPoints(
        stroke.points,
        tolerance: tolerance,
        aspectRatio: aspectRatio,
      ),
    );
  }

  /// RDP itératif (pas de récursion : pas de dépassement de pile sur un très
  /// long tracé).
  static List<DrawPoint> simplifyPoints(
    List<DrawPoint> points, {
    required double tolerance,
    required double aspectRatio,
  }) {
    if (points.length <= 2) return List.of(points);

    // Coordonnées normalisées séparément en x et y : on remet y à l'échelle
    // de x pour mesurer de vraies distances (canvas non carré).
    final yScale = 1 / aspectRatio;
    final keep = List<bool>.filled(points.length, false);
    keep[0] = true;
    keep[points.length - 1] = true;

    final stack = <(int, int)>[(0, points.length - 1)];
    while (stack.isNotEmpty) {
      final (start, end) = stack.removeLast();
      var maxDistance = 0.0;
      var index = -1;
      for (var i = start + 1; i < end; i++) {
        final d = _distanceToSegment(
          points[i],
          points[start],
          points[end],
          yScale,
        );
        if (d > maxDistance) {
          maxDistance = d;
          index = i;
        }
      }
      if (index != -1 && maxDistance > tolerance) {
        keep[index] = true;
        stack
          ..add((start, index))
          ..add((index, end));
      }
    }

    return [
      for (var i = 0; i < points.length; i++)
        if (keep[i]) points[i],
    ];
  }

  static double _distanceToSegment(
    DrawPoint p,
    DrawPoint a,
    DrawPoint b,
    double yScale,
  ) {
    final px = p.dx, py = p.dy * yScale;
    final ax = a.dx, ay = a.dy * yScale;
    final bx = b.dx, by = b.dy * yScale;
    final dx = bx - ax, dy = by - ay;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) {
      return math.sqrt((px - ax) * (px - ax) + (py - ay) * (py - ay));
    }
    final t = (((px - ax) * dx + (py - ay) * dy) / lengthSquared).clamp(0.0, 1.0);
    final cx = ax + t * dx, cy = ay + t * dy;
    return math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
  }
}
