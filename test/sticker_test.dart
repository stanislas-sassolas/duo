import 'dart:ui';

import 'package:duo_draw/models/drawing.dart';
import 'package:duo_draw/models/placed_sticker.dart';
import 'package:duo_draw/presentation/canvas/drawing_controller.dart';
import 'package:duo_draw/services/widget/drawing_widget_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('un sticker posé survit à l\'aller-retour JSON', () {
    const sticker = PlacedSticker(emoji: '🐞', x: 0.2, y: 0.7, width: 0.25, rotation: 0.5);
    final back = PlacedSticker.fromJson(sticker.toJson());
    expect(back.emoji, '🐞');
    expect(back.x, closeTo(0.2, 1e-4));
    expect(back.width, closeTo(0.25, 1e-4));
    expect(back.rotation, closeTo(0.5, 1e-3));
  });

  test('poser, déplacer, annuler un sticker', () {
    final c = CanvasController()..canvasSize = const Size(300, 400);
    c.addSticker(emoji: '❤️');
    expect(c.stickers, hasLength(1));
    expect(c.selectedSticker, 0);
    expect(c.isEmpty, isFalse);
    c.moveSelected(const Offset(30, 40));
    expect(c.stickers.first.x, closeTo(0.6, 1e-9));
    expect(c.stickers.first.y, closeTo(0.6, 1e-9));
    c.undo();
    expect(c.stickers, isEmpty);
    c.redo();
    expect(c.stickers, hasLength(1));
    c.deselect();
    c.clear();
    expect(c.isEmpty, isTrue);
  });

  test('annuler respecte l\'ordre traits / stickers', () {
    final c = CanvasController()..canvasSize = const Size(300, 400);
    c
      ..startStroke(const Offset(10, 10))
      ..addPoint(const Offset(40, 40))
      ..endStroke();
    c.addSticker(emoji: '🌻');
    c.undo();
    expect(c.stickers, isEmpty);
    expect(c.strokes, hasLength(1));
  });

  test('un dessin avec un tampon emoji se rend en image', () async {
    const drawing = Drawing(
      id: 'd',
      coupleId: 'c',
      senderId: 'a',
      receiverId: 'b',
      strokes: [],
      stickers: [PlacedSticker(emoji: '🐞', x: 0.5, y: 0.5)],
    );
    final png = await DrawingWidgetService.renderPng(drawing, width: 120);
    expect(png.length, greaterThan(8));
  });
}
