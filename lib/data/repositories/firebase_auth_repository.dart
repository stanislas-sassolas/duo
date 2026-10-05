import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/utils/resilient_stream.dart';
import '../../core/utils/result.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../models/app_user.dart';
import '../datasources/firestore_refs.dart';

/// Implémentation Firebase de [AuthRepository].
///
/// MVP : authentification anonyme. L'identité durable est portée par le profil
/// Firestore + le lien de couple, ce qui suffit à un usage à deux.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    required FirebaseAuth auth,
    required FirestoreRefs refs,
  })  : _auth = auth,
        _refs = refs;

  final FirebaseAuth _auth;
  final FirestoreRefs _refs;

  @override
  String? get currentUid => _auth.currentUser?.uid;

  @override
  Stream<String?> authStateChanges() =>
      _auth.authStateChanges().map((user) => user?.uid);

  @override
  Future<Result<String>> signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();
      final uid = credential.user?.uid;
      if (uid == null) {
        return const Failure('Connexion impossible.');
      }
      return Success(uid);
    } on FirebaseAuthException catch (e) {
      return Failure(e.message ?? 'Erreur d\'authentification.', cause: e);
    }
  }

  @override
  Future<Result<AppUser>> createProfile({
    required String uid,
    required String displayName,
  }) async {
    try {
      final user = AppUser(id: uid, displayName: displayName.trim());
      // merge:true → idempotent si le profil existe déjà.
      await _refs.user(uid).set(user.toCreateJson(), SetOptions(merge: true));
      final snapshot = await _refs.user(uid).get();
      return Success(AppUser.fromDoc(snapshot));
    } catch (e) {
      return Failure('Impossible de créer le profil.', cause: e);
    }
  }

  @override
  Stream<AppUser?> watchUser(String uid) {
    // Profil du partenaire : lisible seulement une fois le couple enregistré
    // côté serveur, d'où la réouverture en cas de refus passager.
    return resilientSnapshots(
      () => _refs.user(uid).snapshots().map(
            (doc) => doc.exists ? AppUser.fromDoc(doc) : null,
          ),
    );
  }

  @override
  Future<Result<void>> updateDisplayName(String uid, String displayName) async {
    try {
      await _refs.user(uid).update({'displayName': displayName.trim()});
      return const Success(null);
    } catch (e) {
      return Failure('Mise à jour impossible.', cause: e);
    }
  }

  @override
  Future<Result<void>> updatePhotoUrl(String uid, String? photoUrl) async {
    try {
      await _refs.user(uid).update({'photoUrl': photoUrl});
      return const Success(null);
    } catch (e) {
      return Failure('Mise à jour impossible.', cause: e);
    }
  }

  @override
  Future<Result<void>> updateSignature(String uid, String signature) async {
    try {
      await _refs.user(uid).update({'signature': signature.trim()});
      return const Success(null);
    } catch (e) {
      return Failure('Mise à jour impossible.', cause: e);
    }
  }

  @override
  Future<void> addFcmToken(String uid, String token) async {
    await _refs.user(uid).set(
      {
        'fcmTokens': FieldValue.arrayUnion([token]),
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> removeFcmToken(String uid, String token) async {
    await _refs.user(uid).update({
      'fcmTokens': FieldValue.arrayRemove([token]),
    });
  }

  @override
  String? get linkedGoogleEmail {
    final providers = _auth.currentUser?.providerData ?? const [];
    for (final info in providers) {
      if (info.providerId == GoogleAuthProvider.PROVIDER_ID) {
        return info.email ?? '';
      }
    }
    return null;
  }

  @override
  Future<Result<void>> linkWithGoogle(String idToken) async {
    final user = _auth.currentUser;
    if (user == null) return const Failure('Non connecté.');
    try {
      await user.linkWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
      await user.reload();
      return const Success(null);
    } on FirebaseAuthException catch (e) {
      return Failure(
        switch (e.code) {
          'credential-already-in-use' || 'email-already-in-use' =>
            'Ce compte Google est déjà utilisé par un autre compte Duo.',
          'provider-already-linked' => 'Ton compte est déjà lié à Google.',
          _ => e.message ?? 'Liaison impossible.',
        },
        cause: e,
      );
    }
  }

  @override
  Future<Result<String>> signInWithGoogle(String idToken) async {
    try {
      final result = await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
      final uid = result.user?.uid;
      return uid == null ? const Failure('Connexion impossible.') : Success(uid);
    } on FirebaseAuthException catch (e) {
      return Failure(e.message ?? 'Connexion impossible.', cause: e);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<Result<void>> deleteAccount(String uid) async {
    try {
      await _refs.privatePhrases(uid).delete();
      await _refs.user(uid).delete();
      await _auth.currentUser?.delete();
      return const Success(null);
    } on FirebaseAuthException catch (e) {
      // requires-recent-login : géré côté UI si nécessaire.
      return Failure(e.message ?? 'Suppression impossible.', cause: e);
    } catch (e) {
      return Failure('Suppression impossible.', cause: e);
    }
  }
}
