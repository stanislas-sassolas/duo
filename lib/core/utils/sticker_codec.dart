import 'dart:typed_data';
import 'dart:ui' as ui;

/// Prépare une image pour en faire un sticker : réduite (côté max [maxSide]
/// px), transparence conservée, encodée en PNG. Accepte PNG, JPEG, WebP
/// (y compris les stickers WhatsApp ; pour un sticker animé, la première
/// image seulement).
class StickerCodec {
  StickerCodec._();

  /// Poids maximal visé (octets) pour tenir confortablement dans Firestore.
  static const int maxBytes = 180 * 1024;

  static Future<Uint8List> prepare(Uint8List source, {int maxSide = 320}) async {
    var side = maxSide;
    while (true) {
      final png = await _resize(source, side);
      if (png.length <= maxBytes || side <= 128) return png;
      side = (side * 0.75).round();
    }
  }

  static Future<Uint8List> _resize(Uint8List source, int maxSide) async {
    final codec = await ui.instantiateImageCodec(source);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final scale = maxSide / (image.width > image.height ? image.width : image.height);
    final factor = scale < 1 ? scale : 1.0;
    final w = (image.width * factor).round().clamp(1, maxSide);
    final h = (image.height * factor).round().clamp(1, maxSide);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
    final resized = await recorder.endRecording().toImage(w, h);
    final bytes = await resized.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    resized.dispose();
    codec.dispose();
    return bytes!.buffer.asUint8List();
  }

  static Future<ui.Image> decode(Uint8List png) async {
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}
