import 'package:duo_draw/services/widget/drawing_widget_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('le lien du widget donne l\'id du dessin à ouvrir', () {
    expect(
      DrawingWidgetService.drawingIdFromUri(Uri.parse('duo://drawing/abc-123')),
      'abc-123',
    );
    expect(DrawingWidgetService.drawingIdFromUri(Uri.parse('duo://home')), isNull);
    expect(DrawingWidgetService.drawingIdFromUri(null), isNull);
  });
}
