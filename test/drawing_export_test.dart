import 'package:duo_draw/models/draw_point.dart';
import 'package:duo_draw/models/drawing.dart';
import 'package:duo_draw/models/enums.dart';
import 'package:duo_draw/models/stroke.dart';
import 'package:duo_draw/services/export/drawing_export_service.dart';
import 'package:duo_draw/services/widget/drawing_widget_service.dart';
import 'package:flutter_test/flutter_test.dart';

Drawing _drawing({String? message}) => Drawing(
      id: 'd1',
      coupleId: 'c1',
      senderId: 'a',
      receiverId: 'b',
      message: message,
      strokes: const [
        Stroke(
          points: [DrawPoint(dx: 0.1, dy: 0.1), DrawPoint(dx: 0.9, dy: 0.9)],
          color: 0xFFD62828,
          width: 0.02,
          tool: BrushTool.pen,
          startedAt: 0,
        ),
      ],
    );

bool _isPng(List<int> bytes) =>
    bytes.length > 8 &&
    bytes[0] == 0x89 &&
    bytes[1] == 0x50 &&
    bytes[2] == 0x4E &&
    bytes[3] == 0x47;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('le polaroïd de la galerie est une vraie image PNG', () async {
    final png = await DrawingExportService.renderPolaroidPng(
      _drawing(message: '❤️ Bisous'),
      subcaption: 'Sam · 27 septembre 2026',
      width: 300,
    );
    expect(_isPng(png), isTrue);
  });

  test('les pinceaux surligneur et néon se dessinent', () async {
    final base = _drawing();
    for (final tool in [BrushTool.highlighter, BrushTool.neon]) {
      final drawing = Drawing(
        id: 'd2',
        coupleId: 'c1',
        senderId: 'a',
        receiverId: 'b',
        strokes: [
          Stroke(
            points: base.strokes.first.points,
            color: 0xFF1E88E5,
            width: 0.03,
            tool: tool,
            startedAt: 0,
          ),
        ],
      );
      final png = await DrawingWidgetService.renderPng(drawing, width: 100);
      expect(_isPng(png), isTrue);
    }
  });

  test('l\'image du widget est une vraie image PNG', () async {
    final png = await DrawingWidgetService.renderPng(_drawing(), width: 120);
    expect(_isPng(png), isTrue);
  });
}
