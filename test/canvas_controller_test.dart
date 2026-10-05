import 'package:duo_draw/models/enums.dart';
import 'dart:ui';

import 'package:duo_draw/presentation/canvas/drawing_controller.dart';
import 'package:duo_draw/widgets/stroke_painter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CanvasController', () {
    CanvasController drawOneStroke() {
      final controller = CanvasController()..canvasSize = const Size(300, 400);
      controller
        ..startStroke(const Offset(10, 10))
        ..addPoint(const Offset(50, 60))
        ..endStroke();
      return controller;
    }

    test('annuler / rétablir / effacer déclenchent un redessin', () {
      final controller = drawOneStroke();

      var before = StrokePainter(strokes: controller.renderStrokes);
      controller.undo();
      var after = StrokePainter(strokes: controller.renderStrokes);
      expect(after.shouldRepaint(before), isTrue);
      expect(controller.renderStrokes, isEmpty);

      before = after;
      controller.redo();
      after = StrokePainter(strokes: controller.renderStrokes);
      expect(after.shouldRepaint(before), isTrue);
      expect(controller.renderStrokes, hasLength(1));

      before = after;
      controller.clear();
      after = StrokePainter(strokes: controller.renderStrokes);
      expect(after.shouldRepaint(before), isTrue);
    });

    test('les traits sont stockés avec une épaisseur relative', () {
      final controller = drawOneStroke();
      final width = controller.strokes.single.width;
      expect(width, greaterThan(0));
      expect(width, lessThan(1));
    });
  });

  group('Zoom et pinceaux', () {
    test('en zoom, les points tracés restent au bon endroit du dessin', () {
      final controller = CanvasController()..canvasSize = const Size(300, 400);
      controller.setView(2, const Offset(-150, -200)); // zoom x2 au centre
      // Le centre de l'écran correspond au centre du dessin.
      final p = controller.toCanvas(const Offset(150, 200));
      expect(p.dx, closeTo(150, 1e-9));
      expect(p.dy, closeTo(200, 1e-9));
      controller.resetView();
      expect(controller.isZoomed, isFalse);
    });

    test('le zoom ne laisse jamais de vide autour de la feuille', () {
      final controller = CanvasController()..canvasSize = const Size(300, 400);
      controller.setView(2, const Offset(50, 50));
      expect(controller.pan, Offset.zero);
      controller.setView(10, Offset.zero);
      expect(controller.zoom, 5);
    });

    test('choisir une couleur garde le pinceau choisi (pas la gomme)', () {
      final controller = CanvasController();
      controller.selectBrush(BrushTool.neon);
      controller.selectEraser();
      controller.selectPen(const Color(0xFFD62828));
      expect(controller.tool, BrushTool.neon);
    });
  });
}
