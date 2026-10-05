import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/placed_sticker.dart';
import '../models/stroke.dart';

/// Peint une liste de [Stroke] vectoriels sur un canvas.
///
/// Réutilisé partout : édition en direct, aperçu, détail, replay. La gomme est
/// rendue via [BlendMode.clear] sur une couche isolée (fond transparent) ou en
/// peignant la couleur de fond quand [background] est fourni.
class StrokePainter extends CustomPainter {
  StrokePainter({
    required this.strokes,
    this.background,
    super.repaint,
    this.progress = 1.0,
    this.stickers = const [],
    this.stickerImages = const {},
    this.selectedSticker,
  });

  final List<Stroke> strokes;

  /// Stickers posés par-dessus les traits.
  final List<PlacedSticker> stickers;

  /// Images décodées des stickers importés (id → image).
  final Map<String, ui.Image> stickerImages;

  /// Index du sticker en cours d'édition (entouré d'un pointillé).
  final int? selectedSticker;

  /// Couleur de fond opaque. Si non-null, la gomme peint cette couleur.
  final Color? background;

  /// Fraction [0..1] des points à dessiner, pour l'animation de replay.
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (background != null) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = background!,
      );
    }

    final useLayer = background == null;
    if (useLayer) {
      // Couche isolée pour permettre BlendMode.clear (gomme transparente).
      canvas.saveLayer(Offset.zero & size, Paint());
    }

    final totalPoints = strokes.fold<int>(0, (sum, s) => sum + s.points.length);
    final maxPoints = (totalPoints * progress).ceil();
    var drawn = 0;

    for (final stroke in strokes) {
      if (drawn >= maxPoints) break;
      _paintStroke(canvas, size, stroke, maxPoints - drawn);
      drawn += stroke.points.length;
    }

    if (useLayer) canvas.restore();

    // Les stickers apparaissent une fois le rejeu terminé.
    if (progress >= 1) _paintStickers(canvas, size);
  }

  void _paintStroke(Canvas canvas, Size size, Stroke stroke, int limit) {
    if (stroke.points.isEmpty || limit <= 0) return;

    final width = stroke.widthFor(size);
    final count = limit >= stroke.points.length ? stroke.points.length : limit;

    // Forme du trait : un point isolé devient un petit disque.
    final Path path;
    if (count == 1) {
      final p = stroke.points.first.toOffset(size);
      path = Path()..addOval(Rect.fromCircle(center: p, radius: width / 2));
    } else {
      path = Path()
        ..moveTo(
          stroke.points.first.toOffset(size).dx,
          stroke.points.first.toOffset(size).dy,
        );
      for (var i = 1; i < count; i++) {
        final current = stroke.points[i].toOffset(size);
        final previous = stroke.points[i - 1].toOffset(size);
        // Lissage : segment quadratique via le point milieu.
        final mid = Offset(
          (previous.dx + current.dx) / 2,
          (previous.dy + current.dy) / 2,
        );
        path.quadraticBezierTo(previous.dx, previous.dy, mid.dx, mid.dy);
      }
    }
    final isDot = count == 1;

    Paint base(Color color, double w) => Paint()
      ..color = color
      ..style = isDot ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = w
      ..isAntiAlias = true;

    switch (stroke.tool) {
      case BrushTool.eraser:
        final paint = base(background ?? const Color(0xFFFFFFFF), width);
        if (background == null) paint.blendMode = BlendMode.clear;
        canvas.drawPath(path, paint);
      case BrushTool.highlighter:
        // Large et transparent, comme un surligneur.
        canvas.drawPath(
          path,
          base(stroke.uiColor.withValues(alpha: 0.38), width * 1.8),
        );
      case BrushTool.neon:
        // Halo coloré flou + cœur clair : un trait qui brille.
        canvas.drawPath(
          path,
          base(stroke.uiColor.withValues(alpha: 0.85), width * 1.3)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.6),
        );
        canvas.drawPath(
          path,
          base(Color.lerp(stroke.uiColor, Colors.white, 0.7)!, width * 0.45),
        );
      case BrushTool.pen:
        canvas.drawPath(path, base(stroke.uiColor, width));
    }
  }

  @override
  bool shouldRepaint(covariant StrokePainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.progress != progress ||
        oldDelegate.background != background ||
        oldDelegate.stickers != stickers ||
        oldDelegate.stickerImages != stickerImages ||
        oldDelegate.selectedSticker != selectedSticker;
  }

  /// Dessine les stickers (les tampons emoji en texte, les autres en image).
  void _paintStickers(Canvas canvas, Size size) {
    for (var i = 0; i < stickers.length; i++) {
      final sticker = stickers[i];
      final width = sticker.width * size.width;
      canvas.save();
      canvas.translate(sticker.x * size.width, sticker.y * size.height);
      canvas.rotate(sticker.rotation);
      var height = width;
      if (sticker.isEmoji) {
        final text = TextPainter(
          text: TextSpan(
            text: sticker.emoji,
            style: TextStyle(fontSize: width * 0.82, height: 1),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        height = text.height;
        text.paint(canvas, Offset(-text.width / 2, -text.height / 2));
      } else {
        final image = stickerImages[sticker.stickerId];
        if (image != null) {
          height = width * image.height / image.width;
          canvas.drawImageRect(
            image,
            Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
            Rect.fromCenter(center: Offset.zero, width: width, height: height),
            Paint()..filterQuality = FilterQuality.medium,
          );
        }
      }
      if (i == selectedSticker) {
        final rect = Rect.fromCenter(
          center: Offset.zero,
          width: width + 16,
          height: height + 16,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(10)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xFFE8687F),
        );
      }
      canvas.restore();
    }
  }
}
