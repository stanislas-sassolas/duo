import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/resilient_stream.dart';
import '../../core/utils/result.dart';
import '../../domain/repositories/drawing_repository.dart';
import '../../models/drawing.dart';
import '../datasources/firestore_refs.dart';

/// Implémentation Firestore de [DrawingRepository].
class FirestoreDrawingRepository implements DrawingRepository {
  FirestoreDrawingRepository(this._refs);

  final FirestoreRefs _refs;

  @override
  Future<Result<Drawing>> sendDrawing(Drawing drawing) async {
    try {
      // Id fourni par le modèle (permet l'idempotence depuis l'outbox offline).
      final ref = drawing.id.isEmpty
          ? _refs.drawings(drawing.coupleId).doc()
          : _refs.drawing(drawing.coupleId, drawing.id);

      // Idempotence : si un envoi précédent a abouti côté serveur sans que
      // l'app ait reçu la confirmation, le document existe déjà. Le réécrire
      // serait une *mise à jour*, refusée par les règles : on considère donc
      // l'envoi comme réussi.
      if (drawing.id.isNotEmpty) {
        final existing = await ref.get(const GetOptions(source: Source.server));
        if (existing.exists) return Success(drawing);
      }

      final batch = FirebaseFirestore.instance.batch();
      batch.set(ref, drawing.toCreateJson());
      // Met à jour l'horodatage du dernier dessin du couple (aperçu/tri).
      batch.set(
        _refs.couple(drawing.coupleId),
        {'lastDrawingAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      await batch.commit();

      return Success(drawing);
    } on FirebaseException catch (e) {
      return Failure(
        'Envoi impossible.',
        cause: e,
        permanent: _permanentCodes.contains(e.code),
      );
    } catch (e) {
      return Failure('Envoi impossible.', cause: e);
    }
  }

  /// Erreurs pour lesquelles réessayer ne changera rien.
  static const _permanentCodes = {
    'permission-denied',
    'invalid-argument',
    'not-found',
    'failed-precondition',
    'out-of-range',
  };

  @override
  Stream<Drawing?> watchLatestReceived({
    required String coupleId,
    required String uid,
  }) {
    return resilientSnapshots(
      () => _refs
          .drawings(coupleId)
          .where('receiverId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots()
          .map((snap) {
        if (snap.docs.isEmpty) return null;
        return Drawing.fromDoc(snap.docs.first, coupleId: coupleId);
      }),
    );
  }

  @override
  Stream<List<Drawing>> watchHistory(String coupleId) {
    return resilientSnapshots(
      () => _refs
          .drawings(coupleId)
          .orderBy('createdAt', descending: true)
          .limit(200)
          .snapshots()
          .map((snap) => snap.docs
              .map((doc) => Drawing.fromDoc(doc, coupleId: coupleId))
              .toList()),
    );
  }

  @override
  Future<void> markViewed({
    required String coupleId,
    required String drawingId,
  }) async {
    await _refs.drawing(coupleId, drawingId).set(
      {'viewedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  @override
  Future<Result<void>> react({
    required String coupleId,
    required String drawingId,
    required String? reaction,
  }) async {
    try {
      await _refs.drawing(coupleId, drawingId).set(
        {'reaction': reaction},
        SetOptions(merge: true),
      );
      return const Success(null);
    } catch (e) {
      return Failure('Réaction impossible.', cause: e);
    }
  }

  @override
  Future<Result<Drawing>> getDrawing({
    required String coupleId,
    required String drawingId,
  }) async {
    try {
      final doc = await _refs.drawing(coupleId, drawingId).get();
      if (!doc.exists) return const Failure('Dessin introuvable.');
      return Success(Drawing.fromDoc(doc, coupleId: coupleId));
    } catch (e) {
      return Failure('Chargement impossible.', cause: e);
    }
  }
}
