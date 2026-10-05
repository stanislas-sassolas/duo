import '../../models/couple.dart';
import '../../core/utils/result.dart';

/// Contrat de gestion du couple (création, jonction, dissociation).
abstract interface class CoupleRepository {
  /// Crée un couple pour [uid] et renvoie le couple (avec son code).
  Future<Result<Couple>> createCouple(String uid);

  /// Rejoint un couple existant via son [inviteCode].
  ///
  /// Échoue si le code est invalide, déjà complet, ou si l'utilisateur tente
  /// de rejoindre son propre couple.
  Future<Result<Couple>> joinCouple({
    required String uid,
    required String inviteCode,
  });

  /// Flux temps réel du couple.
  Stream<Couple?> watchCouple(String coupleId);

  /// Dissocie les deux partenaires et supprime le couple.
  Future<Result<void>> unlink({
    required String coupleId,
    required String uid,
  });
}
