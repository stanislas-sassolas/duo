import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../models/drawing.dart';
import '../../models/placed_sticker.dart';
import '../../models/stroke.dart';

/// File d'attente locale et persistée des dessins créés hors-ligne.
///
/// Chaque dessin porte un id client (uuid) → l'envoi est idempotent : si la
/// connexion revient et qu'un renvoi partiel a eu lieu, on n'écrit jamais deux
/// fois le même document.
class PendingDrawingsStore {
  PendingDrawingsStore(this._prefs);

  final SharedPreferences _prefs;

  List<Drawing> load() {
    final raw = _prefs.getString(AppConstants.prefOutbox);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => _drawingFromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Données corrompues → on repart propre plutôt que de crasher.
      return [];
    }
  }

  Future<void> add(Drawing drawing) async {
    final current = load()..add(drawing);
    await _save(current);
  }

  Future<void> remove(String drawingId) async {
    final current = load()..removeWhere((d) => d.id == drawingId);
    await _save(current);
  }

  Future<void> clear() => _prefs.remove(AppConstants.prefOutbox);

  Future<void> _save(List<Drawing> drawings) async {
    final encoded =
        jsonEncode(drawings.map(_drawingToJson).toList());
    await _prefs.setString(AppConstants.prefOutbox, encoded);
  }

  // --- Sérialisation locale (inclut les ids, contrairement au toCreateJson) ---

  Map<String, dynamic> _drawingToJson(Drawing d) => {
        'id': d.id,
        'coupleId': d.coupleId,
        'senderId': d.senderId,
        'receiverId': d.receiverId,
        'strokes': d.strokes.map((s) => s.toJson()).toList(),
        'stickers': d.stickers.map((s) => s.toJson()).toList(),
        'aspectRatio': d.aspectRatio,
        'message': d.message,
        'replyToDrawingId': d.replyToDrawingId,
      };

  Drawing _drawingFromJson(Map<String, dynamic> json) => Drawing(
        id: json['id'] as String,
        coupleId: json['coupleId'] as String,
        senderId: json['senderId'] as String,
        receiverId: json['receiverId'] as String,
        strokes: (json['strokes'] as List<dynamic>)
            .map((raw) => Stroke.fromJson(raw as Map<String, dynamic>))
            .toList(),
        stickers: (json['stickers'] as List<dynamic>? ?? const [])
            .map((raw) => PlacedSticker.fromJson(raw as Map<String, dynamic>))
            .toList(),
        aspectRatio: (json['aspectRatio'] as num?)?.toDouble() ??
            AppConstants.canvasAspectRatio,
        message: json['message'] as String?,
        replyToDrawingId: json['replyToDrawingId'] as String?,
      );
}
