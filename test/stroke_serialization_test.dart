import 'dart:ui';

import 'package:duo_draw/models/draw_point.dart';
import 'package:duo_draw/models/enums.dart';
import 'package:duo_draw/models/stroke.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Sérialisation vectorielle', () {
    test('DrawPoint : normalisation puis retour à l\'écran', () {
      const size = Size(200, 400);
      final point = DrawPoint.fromOffset(const Offset(100, 100), size);
      expect(point.dx, closeTo(0.5, 0.001));
      expect(point.dy, closeTo(0.25, 0.001));

      final back = point.toOffset(size);
      expect(back.dx, closeTo(100, 0.1));
      expect(back.dy, closeTo(100, 0.1));
    });

    test('DrawPoint : les coordonnées sont bornées à [0,1]', () {
      const size = Size(100, 100);
      final point = DrawPoint.fromOffset(const Offset(-50, 500), size);
      expect(point.dx, 0.0);
      expect(point.dy, 1.0);
    });

    test('Stroke : round-trip JSON préserve les données', () {
      final stroke = Stroke(
        points: const [
          DrawPoint(dx: 0.1, dy: 0.2, t: 0),
          DrawPoint(dx: 0.3, dy: 0.4, t: 16),
        ],
        color: 0xFFE53935,
        width: BrushSize.medium.relativeWidth,
        tool: BrushTool.pen,
        startedAt: 1700000000000,
      );

      final restored = Stroke.fromJson(stroke.toJson());

      expect(restored.points.length, 2);
      expect(restored.color, 0xFFE53935);
      expect(restored.width, closeTo(BrushSize.medium.relativeWidth, 1e-5));
      expect(restored.tool, BrushTool.pen);
      expect(restored.startedAt, 1700000000000);
      expect(restored.points[1].t, 16);
    });

    test('Stroke : épaisseur relative → pixels selon la taille du canvas', () {
      final stroke = Stroke(
        points: const [DrawPoint(dx: 0, dy: 0)],
        color: 0xFF000000,
        width: 0.02,
        tool: BrushTool.pen,
        startedAt: 0,
      );
      expect(stroke.widthFor(const Size(300, 400)), closeTo(6, 1e-9));
      expect(stroke.widthFor(const Size(600, 800)), closeTo(12, 1e-9));
    });

    test('Stroke : un ancien dessin (épaisseur en pixels "w") reste lisible',
        () {
      final restored = Stroke.fromJson({
        'p': [
          {'x': 0.1, 'y': 0.1, 't': 0},
        ],
        'c': 0xFF000000,
        'w': 18,
        't': 'pen',
        'ts': 0,
      });
      expect(restored.width, closeTo(18 / 360, 1e-9));
    });

    test('Enums : identifiants stables et robustesse au parsing', () {
      expect(BrushTool.fromId('eraser'), BrushTool.eraser);
      expect(BrushTool.fromId('inconnu'), BrushTool.pen);
      expect(BrushSize.fromId('thick'), BrushSize.thick);
      expect(BrushSize.fromId(null), BrushSize.medium);
    });
  });
}
