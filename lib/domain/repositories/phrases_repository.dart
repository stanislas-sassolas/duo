import '../../core/utils/result.dart';

/// Petits mots personnels proposés à l'envoi d'un dessin.
///
/// Chaque utilisateur a sa propre liste, privée : l'autre ne la voit jamais
/// (il ne voit que la phrase choisie, jointe au dessin).
abstract interface class PhrasesRepository {
  /// Liste temps réel des petits mots de [uid]. `null` si elle n'a encore
  /// jamais été créée (premier lancement).
  Stream<List<String>?> watchPhrases(String uid);

  /// Remplace la liste complète des petits mots de [uid].
  Future<Result<void>> savePhrases(String uid, List<String> phrases);
}
