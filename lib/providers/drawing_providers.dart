import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/utils/result.dart';
import '../core/utils/stroke_simplifier.dart';
import '../models/drawing.dart';
import '../models/placed_sticker.dart';
import '../models/stroke.dart';
import 'auth_providers.dart';
import 'couple_providers.dart';
import '../services/sync/outbox_service.dart';
import 'service_providers.dart';

const _uuid = Uuid();

/// `true` quand l'utilisateur regarde actuellement un dessin reçu.
///
/// Lu par le service de notifications pour **ne pas** afficher de notif au
/// premier plan pendant que le dessin est déjà à l'écran.
final isViewingReceivedProvider = StateProvider<bool>((ref) => false);

/// Récupère un dessin par id (depuis l'historique en cache, sinon Firestore).
final drawingByIdProvider =
    FutureProvider.family<Drawing?, String>((ref, drawingId) async {
  final cached = ref
      .watch(historyProvider)
      .valueOrNull
      ?.where((d) => d.id == drawingId)
      .firstOrNull;
  if (cached != null) return cached;

  final couple = ref.watch(coupleProvider).valueOrNull;
  if (couple == null) return null;
  final result = await ref.read(drawingRepositoryProvider).getDrawing(
        coupleId: couple.id,
        drawingId: drawingId,
      );
  return result.valueOrNull;
});

/// Dernier dessin reçu par l'utilisateur courant (temps réel).
final latestReceivedProvider = StreamProvider<Drawing?>((ref) {
  final uid = ref.watch(currentUidProvider);
  final couple = ref.watch(coupleProvider).valueOrNull;
  if (uid == null || couple == null) return Stream.value(null);
  return ref.watch(drawingRepositoryProvider).watchLatestReceived(
        coupleId: couple.id,
        uid: uid,
      );
});

/// Historique complet du couple (temps réel).
final historyProvider = StreamProvider<List<Drawing>>((ref) {
  final couple = ref.watch(coupleProvider).valueOrNull;
  if (couple == null) return Stream.value(const []);
  return ref.watch(drawingRepositoryProvider).watchHistory(couple.id);
});

final drawingControllerProvider =
    Provider<DrawingController>((ref) => DrawingController(ref));

class DrawingController {
  DrawingController(this._ref);
  final Ref _ref;

  /// Construit et envoie un dessin.
  ///
  /// Passe systématiquement par l'outbox → aucune perte même hors-ligne.
  /// Retourne `true` si envoyé immédiatement, `false` si mis en file d'attente.
  /// Le dessin est allégé (points redondants retirés) avant l'envoi.
  Future<Result<bool>> send({
    required List<Stroke> strokes,
    List<PlacedSticker> stickers = const [],
    String? message,
    String? replyToDrawingId,
  }) async {
    if (strokes.isEmpty && stickers.isEmpty) {
      return const Failure('Le dessin est vide.');
    }

    final uid = _ref.read(currentUidProvider);
    final couple = _ref.read(coupleProvider).valueOrNull;
    if (uid == null || couple == null) {
      return const Failure('Aucun partenaire lié.');
    }
    final receiverId = couple.partnerOf(uid);
    if (receiverId == null) {
      return const Failure('En attente de votre partenaire.');
    }

    final compressed = StrokeSimplifier.compressForUpload(strokes);
    if (compressed == null) {
      return const Failure(
        'Ce dessin est trop détaillé pour être envoyé. '
        'Efface quelques traits et réessaie.',
      );
    }

    final drawing = Drawing(
      id: _uuid.v4(), // id client → envoi idempotent depuis l'outbox
      coupleId: couple.id,
      senderId: uid,
      receiverId: receiverId,
      strokes: compressed,
      stickers: stickers,
      message: (message != null && message.trim().isNotEmpty)
          ? message.trim()
          : null,
      replyToDrawingId: replyToDrawingId,
    );

    try {
      final outcome =
          await _ref.read(outboxServiceProvider).enqueueAndSend(drawing);
      return switch (outcome) {
        SendOutcome.sent => const Success(true),
        SendOutcome.queued => const Success(false),
        SendOutcome.rejected => const Failure(
            'Le dessin a été refusé. Vérifie que ton partenaire est '
            'toujours lié.',
          ),
      };
    } catch (e) {
      return Failure('Envoi impossible.', cause: e);
    }
  }

  /// Réagit à un dessin reçu. Le même emoji une deuxième fois le retire.
  Future<void> toggleReaction(Drawing drawing, String emoji) async {
    final uid = _ref.read(currentUidProvider);
    if (drawing.receiverId != uid) return;
    await _ref.read(drawingRepositoryProvider).react(
          coupleId: drawing.coupleId,
          drawingId: drawing.id,
          reaction: drawing.reaction == emoji ? null : emoji,
        );
  }

  /// Marque un dessin reçu comme vu.
  Future<void> markViewed(Drawing drawing) {
    return _ref.read(drawingRepositoryProvider).markViewed(
          coupleId: drawing.coupleId,
          drawingId: drawing.id,
        );
  }
}
