import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/personal.dart';
import '../core/utils/result.dart';
import '../data/repositories/firestore_phrases_repository.dart';
import '../domain/repositories/phrases_repository.dart';
import 'auth_providers.dart';
import 'service_providers.dart';

final phrasesRepositoryProvider = Provider<PhrasesRepository>(
  (ref) => FirestorePhrasesRepository(ref.watch(firestoreRefsProvider)),
);

/// Mes petits mots (temps réel). Liste vide tant qu'ils ne sont pas chargés
/// ou si je n'en ai aucun.
final myPhrasesProvider = StreamProvider<List<String>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref
      .watch(phrasesRepositoryProvider)
      .watchPhrases(uid)
      .map((phrases) => phrases ?? const []);
});

final personalControllerProvider =
    Provider<PersonalController>((ref) => PersonalController(ref));

class PersonalController {
  PersonalController(this._ref);
  final Ref _ref;

  /// Au premier lancement de la version personnalisée : pose le surnom et
  /// les petits mots par défaut selon le prénom (voir [Personal]). Ne touche
  /// jamais à ce que l'utilisateur a déjà défini.
  Future<void> applyDefaultsIfNeeded() async {
    final user = _ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    if (user.signature == null) {
      await _ref.read(authRepositoryProvider).updateSignature(
            user.id,
            Personal.defaultSignatureFor(user.displayName),
          );
    }

    final repo = _ref.read(phrasesRepositoryProvider);
    final existing = await repo.watchPhrases(user.id).first;
    if (existing == null) {
      await repo.savePhrases(
        user.id,
        Personal.defaultPhrasesFor(user.displayName),
      );
    }
  }

  Future<Result<void>> updateSignature(String signature) async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return const Failure('Non connecté.');
    return _ref.read(authRepositoryProvider).updateSignature(uid, signature);
  }

  Future<Result<void>> savePhrases(List<String> phrases) async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return const Failure('Non connecté.');
    final limited = [
      for (final phrase in phrases)
        if (phrase.trim().isNotEmpty)
          phrase.trim().length > AppConstants.maxMessageLength
              ? phrase.trim().substring(0, AppConstants.maxMessageLength)
              : phrase.trim(),
    ];
    return _ref.read(phrasesRepositoryProvider).savePhrases(uid, limited);
  }
}
