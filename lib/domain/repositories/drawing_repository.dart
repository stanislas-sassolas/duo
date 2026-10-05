import '../../models/drawing.dart';
import '../../core/utils/result.dart';

/// Contrat d'envoi, réception et historique des dessins.
abstract interface class DrawingRepository {
  /// Envoie un dessin. Retourne le dessin persisté (avec id/serveur).
  Future<Result<Drawing>> sendDrawing(Drawing drawing);

  /// Flux du dernier dessin reçu par [uid] dans [coupleId].
  Stream<Drawing?> watchLatestReceived({
    required String coupleId,
    required String uid,
  });

  /// Historique complet du couple (tri anti-chronologique).
  Stream<List<Drawing>> watchHistory(String coupleId);

  /// Marque un dessin comme vu (renseigne `viewedAt`).
  Future<void> markViewed({
    required String coupleId,
    required String drawingId,
  });

  /// Réagit à un dessin reçu ([reaction] `null` pour retirer).
  Future<Result<void>> react({
    required String coupleId,
    required String drawingId,
    required String? reaction,
  });

  /// Charge un dessin unique (pour le détail / replay).
  Future<Result<Drawing>> getDrawing({
    required String coupleId,
    required String drawingId,
  });
}
