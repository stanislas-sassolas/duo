import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:gal/gal.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/result.dart';
import '../../models/drawing.dart';
import '../stickers/sticker_loader.dart';
import '../../widgets/stroke_painter.dart';

/// Enregistre des dessins dans la galerie du téléphone, en photo polaroïd
/// (cadre blanc, papier crème, petit mot manuscrit), dans l'album « Duo ».
class DrawingExportService {
  DrawingExportService._();

  static const String album = 'Duo';

  /// Enregistre un dessin. [subcaption] : « Alex · 23 septembre ».
  static Future<Result<void>> saveToGallery(
    Drawing drawing, {
    String? subcaption,
  }) async {
    final access = await _ensureAccess();
    if (access != null) return access;
    try {
      final png = await renderPolaroidPng(
        drawing,
        subcaption: subcaption,
        stickerImages: await StickerLoader.forDrawing(drawing),
      );
      await Gal.putImageBytes(png, album: album, name: 'duo_${drawing.id}');
      return const Success(null);
    } catch (e) {
      return Failure('Enregistrement impossible.', cause: e);
    }
  }

  /// Enregistre plusieurs dessins. [onProgress] reçoit le nombre déjà faits.
  static Future<Result<int>> saveAllToGallery(
    List<Drawing> drawings, {
    String Function(Drawing)? subcaptionFor,
    void Function(int done)? onProgress,
  }) async {
    final access = await _ensureAccess();
    if (access != null) return Failure(access.message);
    var saved = 0;
    for (final drawing in drawings) {
      try {
        final png = await renderPolaroidPng(
          drawing,
          subcaption: subcaptionFor?.call(drawing),
          stickerImages: await StickerLoader.forDrawing(drawing),
        );
        await Gal.putImageBytes(png, album: album, name: 'duo_${drawing.id}');
        saved++;
        onProgress?.call(saved);
      } catch (_) {
        // On continue avec les suivants.
      }
    }
    return Success(saved);
  }

  static Future<Failure<void>?> _ensureAccess() async {
    try {
      if (await Gal.hasAccess(toAlbum: true)) return null;
      if (await Gal.requestAccess(toAlbum: true)) return null;
      return const Failure('Autorise Duo à enregistrer des photos.');
    } catch (e) {
      return Failure('Accès à la galerie impossible.', cause: e);
    }
  }

  /// Dessine le polaroïd complet en PNG (1080 px de large).
  static Future<Uint8List> renderPolaroidPng(
    Drawing drawing, {
    String? subcaption,
    double width = 1080,
    Map<String, ui.Image> stickerImages = const {},
  }) async {
    const pad = 60.0;
    final imageWidth = width - 2 * pad;
    final imageHeight = imageWidth / drawing.aspectRatio;
    final caption = drawing.message?.trim() ?? '';
    const captionHeight = 230.0;
    final height = pad + imageHeight + captionHeight;
    final size = Size(width, height);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFFFFFF));

    // Le dessin sur papier crème.
    canvas.save();
    canvas.translate(pad, pad);
    StrokePainter(
      strokes: drawing.strokes,
      background: const Color(0xFFFAF6F1),
      stickers: drawing.stickers,
      stickerImages: stickerImages,
    ).paint(canvas, Size(imageWidth, imageHeight));
    canvas.restore();

    // Le petit mot, écrit à la main, puis l'auteur et la date.
    var y = pad + imageHeight + 34;
    if (caption.isNotEmpty) {
      final text = TextPainter(
        text: TextSpan(
          text: caption,
          style: const TextStyle(
            fontFamily: AppTheme.handwriting,
            fontSize: 84,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2B2530),
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: imageWidth);
      text.paint(canvas, Offset(pad, y));
      y += text.height + 8;
    }
    if (subcaption != null && subcaption.isNotEmpty) {
      TextPainter(
        text: TextSpan(
          text: subcaption,
          style: const TextStyle(fontSize: 36, color: Color(0xFF8B8290)),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )
        ..layout(maxWidth: imageWidth)
        ..paint(canvas, Offset(pad, y));
    }

    final image = await recorder
        .endRecording()
        .toImage(width.round(), height.round());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bytes!.buffer.asUint8List();
  }
}
