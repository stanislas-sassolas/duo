import '../../models/app_user.dart';
import '../../core/utils/result.dart';

/// Contrat d'authentification. Implémenté par la couche data (Firebase).
abstract interface class AuthRepository {
  /// Utilisateur Firebase actuellement connecté (uid) ou `null`.
  String? get currentUid;

  /// Flux de l'état de connexion : émet l'uid ou `null` à la déconnexion.
  Stream<String?> authStateChanges();

  /// Connexion anonyme (MVP : pas de mot de passe, l'identité est le couple).
  Future<Result<String>> signInAnonymously();

  /// Crée le document profil `users/{uid}` après la première connexion.
  Future<Result<AppUser>> createProfile({
    required String uid,
    required String displayName,
  });

  /// Flux temps réel du profil utilisateur.
  Stream<AppUser?> watchUser(String uid);

  Future<Result<void>> updateDisplayName(String uid, String displayName);

  Future<Result<void>> updatePhotoUrl(String uid, String? photoUrl);

  /// Met à jour le petit surnom / les emojis affichés à côté du prénom.
  Future<Result<void>> updateSignature(String uid, String signature);

  /// Enregistre/retire un jeton FCM sur le profil.
  Future<void> addFcmToken(String uid, String token);
  Future<void> removeFcmToken(String uid, String token);

  /// Adresse Google liée au compte, ou `null` si le compte est seulement
  /// anonyme (donc perdu si le téléphone l'est).
  String? get linkedGoogleEmail;

  /// Lie le compte actuel (anonyme) à un compte Google : même uid, mêmes
  /// données, mais récupérable sur un autre téléphone.
  Future<Result<void>> linkWithGoogle(String idToken);

  /// Se connecte avec un compte Google déjà lié (nouveau téléphone).
  Future<Result<String>> signInWithGoogle(String idToken);

  Future<void> signOut();

  /// Supprime le compte et le profil.
  Future<Result<void>> deleteAccount(String uid);
}
