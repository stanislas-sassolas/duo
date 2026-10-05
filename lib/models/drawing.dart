import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import 'placed_sticker.dart';
import 'stroke.dart';

/// Un dessin envoyé d'un partenaire à l'autre.
///
/// Document Firestore : `couples/{coupleId}/drawings/{drawingId}`.
///
/// Les [strokes] sont stockés vectoriellement (voir [Stroke]) et non comme une
/// image. Une vignette PNG optionnelle ([thumbnailUrl]) peut être générée pour
/// l'aperçu et le widget d'écran d'accueil.
class Drawing {
  const Drawing({
    required this.id,
    required this.coupleId,
    required this.senderId,
    required this.receiverId,
    required this.strokes,
    this.stickers = const [],
    this.aspectRatio = AppConstants.canvasAspectRatio,
    this.message,
    this.replyToDrawingId,
    this.thumbnailUrl,
    this.createdAt,
    this.viewedAt,
    this.reaction,
  });

  final String id;
  final String coupleId;
  final String senderId;
  final String receiverId;
  final List<Stroke> strokes;

  /// Stickers posés sur le dessin (par-dessus les traits).
  final List<PlacedSticker> stickers;

  /// Ratio largeur / hauteur du canvas sur lequel le dessin a été fait. Les
  /// anciens dessins (sans ce champ) prennent le ratio par défaut.
  final double aspectRatio;

  /// Petit mot optionnel accompagnant le dessin.
  final String? message;

  /// Id du dessin auquel celui-ci répond (conversation visuelle).
  final String? replyToDrawingId;

  /// URL Storage d'une vignette PNG (aperçu léger / widget).
  final String? thumbnailUrl;

  final DateTime? createdAt;

  /// Renseigné quand le destinataire ouvre le dessin.
  final DateTime? viewedAt;

  /// Réaction du destinataire (ex. « ❤️ », « 🐞 »), ou `null`.
  final String? reaction;

  bool get isViewed => viewedAt != null;
  bool get isEmpty => strokes.isEmpty && stickers.isEmpty;

  Drawing copyWith({DateTime? viewedAt, String? thumbnailUrl}) {
    return Drawing(
      id: id,
      coupleId: coupleId,
      senderId: senderId,
      receiverId: receiverId,
      strokes: strokes,
      stickers: stickers,
      aspectRatio: aspectRatio,
      message: message,
      replyToDrawingId: replyToDrawingId,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      createdAt: createdAt,
      viewedAt: viewedAt ?? this.viewedAt,
      reaction: reaction,
    );
  }

  Map<String, dynamic> toCreateJson() => {
        'senderId': senderId,
        'receiverId': receiverId,
        'strokes': strokes.map((stroke) => stroke.toJson()).toList(),
        if (stickers.isNotEmpty)
          'stickers': stickers.map((sticker) => sticker.toJson()).toList(),
        'aspectRatio': aspectRatio,
        'message': message,
        'replyToDrawingId': replyToDrawingId,
        'thumbnailUrl': thumbnailUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'viewedAt': null,
      };

  factory Drawing.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String coupleId,
  }) {
    final data = doc.data() ?? const {};
    return Drawing(
      id: doc.id,
      coupleId: coupleId,
      senderId: (data['senderId'] as String?) ?? '',
      receiverId: (data['receiverId'] as String?) ?? '',
      strokes: (data['strokes'] as List<dynamic>?)
              ?.map((raw) => Stroke.fromJson(raw as Map<String, dynamic>))
              .toList() ??
          const [],
      stickers: (data['stickers'] as List<dynamic>?)
              ?.map((raw) =>
                  PlacedSticker.fromJson(raw as Map<String, dynamic>))
              .toList() ??
          const [],
      aspectRatio: (data['aspectRatio'] as num?)?.toDouble() ??
          AppConstants.canvasAspectRatio,
      message: data['message'] as String?,
      replyToDrawingId: data['replyToDrawingId'] as String?,
      thumbnailUrl: data['thumbnailUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      viewedAt: (data['viewedAt'] as Timestamp?)?.toDate(),
      reaction: data['reaction'] as String?,
    );
  }
}
