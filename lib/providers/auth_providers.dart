import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/result.dart';
import '../models/app_user.dart';
import '../services/auth/google_auth_service.dart';
import 'service_providers.dart';

/// Flux de l'uid connecté (ou null).
final authStateProvider = StreamProvider<String?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// uid courant (synchrone, peut être null au tout premier lancement).
final currentUidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).valueOrNull,
);

/// Profil temps réel de l'utilisateur courant.
final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(authRepositoryProvider).watchUser(uid);
});

/// Adresse Google liée au compte (ou `null`). Rafraîchi après une liaison.
final googleLinkProvider = Provider<String?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(authRepositoryProvider).linkedGoogleEmail;
});

/// Contrôleur des actions d'authentification.
final authControllerProvider =
    Provider<AuthController>((ref) => AuthController(ref));

class AuthController {
  AuthController(this._ref);
  final Ref _ref;

  /// Connexion + création du profil en une étape (onboarding).
  Future<Result<AppUser>> signInAndCreateProfile(String displayName) async {
    final auth = _ref.read(authRepositoryProvider);
    // Déjà connecté (ex. compte Google choisi sans profil Duo) : on garde ce
    // compte au lieu d'en créer un anonyme.
    final existing = auth.currentUid;
    if (existing != null) {
      return auth.createProfile(uid: existing, displayName: displayName);
    }
    final signIn = await auth.signInAnonymously();
    return switch (signIn) {
      Failure(:final message) => Failure(message),
      Success(:final value) =>
        await auth.createProfile(uid: value, displayName: displayName),
    };
  }

  Future<Result<void>> updateDisplayName(String name) async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return const Failure('Non connecté.');
    return _ref.read(authRepositoryProvider).updateDisplayName(uid, name);
  }

  Future<void> signOut() async {
    await GoogleAuthService.signOut();
    await _ref.read(authRepositoryProvider).signOut();
  }

  /// Adresse Google liée, ou `null` (compte seulement anonyme).
  String? get linkedGoogleEmail =>
      _ref.read(authRepositoryProvider).linkedGoogleEmail;

  /// Sécurise le compte actuel avec Google. `Success(false)` si annulé.
  Future<Result<bool>> linkWithGoogle() async {
    try {
      final idToken = await GoogleAuthService.pickAccountIdToken();
      if (idToken == null) return const Success(false);
      final result =
          await _ref.read(authRepositoryProvider).linkWithGoogle(idToken);
      _ref.invalidate(googleLinkProvider);
      return switch (result) {
        Success() => const Success(true),
        Failure(:final message) => Failure(message),
      };
    } catch (e) {
      return Failure('Connexion Google impossible.', cause: e);
    }
  }

  /// Retrouve un compte existant sur un nouveau téléphone. `Success(false)`
  /// si annulé.
  Future<Result<bool>> signInWithGoogle() async {
    try {
      final idToken = await GoogleAuthService.pickAccountIdToken();
      if (idToken == null) return const Success(false);
      final result =
          await _ref.read(authRepositoryProvider).signInWithGoogle(idToken);
      _ref.invalidate(googleLinkProvider);
      return switch (result) {
        Success() => const Success(true),
        Failure(:final message) => Failure(message),
      };
    } catch (e) {
      return Failure('Connexion Google impossible.', cause: e);
    }
  }

  /// Supprime le compte et TOUTES ses données : le couple et l'historique
  /// commun sont effacés d'abord (dissociation), puis le profil et le compte.
  Future<Result<void>> deleteAccount() async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return const Failure('Non connecté.');

    final coupleId = _ref.read(currentUserProvider).valueOrNull?.coupleId;
    if (coupleId != null && coupleId.isNotEmpty) {
      final unlinked = await _ref
          .read(coupleRepositoryProvider)
          .unlink(coupleId: coupleId, uid: uid);
      if (unlinked case Failure(:final message)) return Failure(message);
    }
    await _ref.read(pendingDrawingsStoreProvider).clear();
    return _ref.read(authRepositoryProvider).deleteAccount(uid);
  }
}
