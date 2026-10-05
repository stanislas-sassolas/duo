import '../../core/utils/result.dart';
import '../../domain/repositories/phrases_repository.dart';
import '../datasources/firestore_refs.dart';

/// Implémentation Firestore de [PhrasesRepository].
///
/// Document : `users/{uid}/private/phrases` → `{ items: [..] }`.
class FirestorePhrasesRepository implements PhrasesRepository {
  FirestorePhrasesRepository(this._refs);

  final FirestoreRefs _refs;

  @override
  Stream<List<String>?> watchPhrases(String uid) {
    return _refs.privatePhrases(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return (doc.data()?['items'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList();
    });
  }

  @override
  Future<Result<void>> savePhrases(String uid, List<String> phrases) async {
    try {
      final cleaned = [
        for (final phrase in phrases)
          if (phrase.trim().isNotEmpty) phrase.trim(),
      ];
      await _refs.privatePhrases(uid).set({'items': cleaned});
      return const Success(null);
    } catch (e) {
      return Failure('Enregistrement impossible.', cause: e);
    }
  }
}
