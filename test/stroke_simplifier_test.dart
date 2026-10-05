import 'package:duo_draw/core/utils/stroke_simplifier.dart';
import 'package:duo_draw/models/draw_point.dart';
import 'package:duo_draw/models/enums.dart';
import 'package:duo_draw/models/stroke.dart';
import 'package:flutter_test/flutter_test.dart';

Stroke _stroke(List<DrawPoint> points) => Stroke(
      points: points,
      color: 0xFF000000,
      width: 0.02,
      tool: BrushTool.pen,
      startedAt: 0,
    );

void main() {
  group('StrokeSimplifier', () {
    test('une ligne droite très échantillonnée garde ses deux extrémités', () {
      final points = [
        for (var i = 0; i <= 1000; i++) DrawPoint(dx: i / 1000, dy: 0.5),
      ];
      final simplified = StrokeSimplifier.simplifyStroke(_stroke(points));
      expect(simplified.points, hasLength(2));
      expect(simplified.points.first.dx, 0);
      expect(simplified.points.last.dx, 1);
    });

    test('les angles marqués sont conservés', () {
      final points = [
        for (var i = 0; i <= 100; i++) DrawPoint(dx: i / 200, dy: 0.1),
        for (var i = 1; i <= 100; i++) DrawPoint(dx: 0.5, dy: 0.1 + i / 200),
      ];
      final simplified = StrokeSimplifier.simplifyStroke(_stroke(points));
      expect(simplified.points, hasLength(3));
      expect(simplified.points[1].dx, closeTo(0.5, 1e-9));
      expect(simplified.points[1].dy, closeTo(0.1, 1e-9));
    });

    test('un dessin énorme est ramené sous le plafond ou refusé', () {
      // Zigzag dense : difficile à simplifier.
      final points = [
        for (var i = 0; i < 20000; i++)
          DrawPoint(dx: (i % 200) / 200, dy: (i ~/ 200) / 100 + (i.isEven ? 0 : 0.004)),
      ];
      final result = StrokeSimplifier.compressForUpload(
        [_stroke(points)],
        maxPoints: 12000,
      );
      if (result != null) {
        expect(StrokeSimplifier.countPoints(result), lessThanOrEqualTo(12000));
      }
    });

    test('un petit dessin passe sans perte de traits', () {
      final strokes = [
        _stroke(const [DrawPoint(dx: 0.1, dy: 0.1)]),
        _stroke(const [DrawPoint(dx: 0.2, dy: 0.2), DrawPoint(dx: 0.3, dy: 0.3)]),
      ];
      final result = StrokeSimplifier.compressForUpload(strokes)!;
      expect(result, hasLength(2));
      expect(StrokeSimplifier.countPoints(result), 3);
    });
  });
}
