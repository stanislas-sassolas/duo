import 'dart:convert';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/utils/sticker_codec.dart';
import '../../models/drawing.dart';

/// Charge les images des stickers utilisés par un dessin, directement depuis
/// Firestore (utilisable hors de l'interface : widget, galerie, tâche de
/// fond). Garde un petit cache en mémoire.
class StickerLoader {
  StickerLoader._();

  static final Map<String, ui.Image> _cache = {};

  static Future<Map<String, ui.Image>> forDrawing(Drawing drawing) async {
    final ids = {
      for (final sticker in drawing.stickers)
        if (sticker.stickerId != null) sticker.stickerId!,
    };
    final result = <String, ui.Image>{};
    for (final id in ids) {
      final cached = _cache[id];
      if (cached != null) {
        result[id] = cached;
        continue;
      }
      try {
        final doc = await FirebaseFirestore.instance
            .doc('couples/${drawing.coupleId}/stickers/$id')
            .get();
        final data = doc.data()?['data'];
        if (data is! String) continue;
        final image = await StickerCodec.decode(base64Decode(data));
        _cache[id] = image;
        result[id] = image;
      } catch (e) {
        debugPrint('Sticker $id non chargé : $e');
      }
    }
    return result;
  }
}
