import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../../models/drawing.dart';
import '../stickers/sticker_loader.dart';
import '../../widgets/stroke_painter.dart';

/// Met à jour le widget d'écran d'accueil Android (voir DuoWidgetProvider.kt)
/// avec le dernier dessin reçu : image PNG, petit mot, « Alex · 10:57 ».
///
/// Utilisable depuis l'app et depuis la tâche d'arrière-plan.
class DrawingWidgetService {
  DrawingWidgetService._();

  static const String _provider = 'com.duo.duo_draw.DuoWidgetProvider';

  static const String keyImage = 'duo_latest';
  static const String keyCaption = 'duo_caption';
  static const String keySub = 'duo_sub';
  static const String keyDrawingId = 'duo_drawing_id';

  /// Papier crème, comme les polaroïds de l'app.
  static const Color paper = Color(0xFFFAF6F1);

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  /// Affiche [drawing] (reçu de [senderName]) sur le widget. L'image n'est
  /// redessinée que si le dessin a changé.
  static Future<void> showDrawing(Drawing drawing, String senderName) async {
    if (!_supported) return;
    try {
      final time = drawing.createdAt == null
          ? ''
          : ' · ${DateFormat.Hm('fr').format(drawing.createdAt!)}';
      final sub = '$senderName$time';
      final currentId = await HomeWidget.getWidgetData<String>(keyDrawingId);
      final currentSub = await HomeWidget.getWidgetData<String>(keySub);
      if (currentId == drawing.id && currentSub == sub) return;

      if (currentId != drawing.id) {
        final png = await renderPng(
          drawing,
          stickerImages: await StickerLoader.forDrawing(drawing),
        );
        await HomeWidget.saveFile(keyImage, png, extension: 'png');
      }
      await HomeWidget.saveWidgetData<String>(keyCaption, drawing.message ?? '');
      await HomeWidget.saveWidgetData<String>(keySub, sub);
      await HomeWidget.saveWidgetData<String>(keyDrawingId, drawing.id);
      await HomeWidget.updateWidget(qualifiedAndroidName: _provider);
    } catch (e) {
      debugPrint('Widget non mis à jour : $e');
    }
  }

  /// Remet le widget à vide (ex. après une dissociation).
  static Future<void> clear() async {
    if (!_supported) return;
    try {
      if (await HomeWidget.getWidgetData<String>(keyDrawingId) == null) return;
      await HomeWidget.saveWidgetData<String>(keyImage, null);
      await HomeWidget.saveWidgetData<String>(keyCaption, null);
      await HomeWidget.saveWidgetData<String>(keySub, null);
      await HomeWidget.saveWidgetData<String>(keyDrawingId, null);
      await HomeWidget.updateWidget(qualifiedAndroidName: _provider);
    } catch (e) {
      debugPrint('Widget non vidé : $e');
    }
  }

  /// Dessine [drawing] dans une image PNG (largeur [width] px).
  static Future<Uint8List> renderPng(
    Drawing drawing, {
    int width = 600,
    Map<String, ui.Image> stickerImages = const {},
  }) async {
    final height = (width / drawing.aspectRatio).round();
    final size = Size(width.toDouble(), height.toDouble());
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & size);
    StrokePainter(
      strokes: drawing.strokes,
      background: paper,
      stickers: drawing.stickers,
      stickerImages: stickerImages,
    )
        .paint(canvas, size);
    final image = await recorder.endRecording().toImage(width, height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bytes!.buffer.asUint8List();
  }

  /// Id du dessin à ouvrir si l'app a été lancée par un toucher sur le widget.
  static Future<String?> launchDrawingId() async {
    if (!_supported) return null;
    try {
      return drawingIdFromUri(await HomeWidget.initiallyLaunchedFromHomeWidget());
    } catch (_) {
      return null;
    }
  }

  /// Touchers sur le widget pendant que l'app tourne.
  static Stream<String?> get clicks => _supported
      ? HomeWidget.widgetClicked.map(drawingIdFromUri)
      : const Stream.empty();

  /// `duo://drawing/<id>` → `<id>`.
  static String? drawingIdFromUri(Uri? uri) {
    if (uri == null || uri.host != 'drawing') return null;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    return segments.isEmpty ? null : segments.first;
  }
}
