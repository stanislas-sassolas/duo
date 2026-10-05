import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/invite_code.dart';
import '../../core/utils/resilient_stream.dart';
import '../../core/utils/result.dart';
import '../../domain/repositories/couple_repository.dart';
import '../../models/couple.dart';
import '../datasources/firestore_refs.dart';

/// Implémentation Firestore de [CoupleRepository].
///
/// - `couples/{coupleId}` : document du couple (source de vérité).
/// - `invites/{CODE}` : annuaire code → coupleId, pour rejoindre sans lire les
///   autres couples.
/// - `users/{uid}.coupleId` : dénormalisé pour un accès rapide.
class FirestoreCoupleRepository implements CoupleRepository {
  FirestoreCoupleRepository(this._refs);

  final FirestoreRefs _refs;

  @override
  Future<Result<Couple>> createCouple(String uid) async {
    try {
      // Génère un code unique (retries en cas de collision improbable).
      final code = await _generateUniqueCode();

      final coupleRef = _refs.couples.doc();
      final couple = Couple(
        id: coupleRef.id,
        userA: uid,
        userB: null,
        inviteCode: code,
        members: [uid],
      );

      final batch = FirebaseFirestore.instance.batch();
      batch.set(coupleRef, couple.toCreateJson());
      batch.set(_refs.invite(code), {
        'coupleId': coupleRef.id,
        'createdBy': uid,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(AppConstants.inviteValidity),
        ),
      });
      batch.set(
        _refs.user(uid),
        {'coupleId': coupleRef.id},
        SetOptions(merge: true),
      );
      await batch.commit();

      return Success(couple);
    } catch (e) {
      return Failure('Impossible de créer votre espace.', cause: e);
    }
  }

  @override
  Future<Result<Couple>> joinCouple({
    required String uid,
    required String inviteCode,
  }) async {
    final code = InviteCode.normalize(inviteCode);
    if (!InviteCode.isValid(code)) {
      return const Failure('Ce code n\'est pas valide.');
    }

    try {
      final inviteSnap = await _refs.invite(code).get();
      if (!inviteSnap.exists) {
        return const Failure('Aucun espace ne correspond à ce code.');
      }
      final invite = inviteSnap.data()!;
      if (invite['active'] != true) {
        return const Failure('Ce code a déjà été utilisé.');
      }
      final expiresAt = (invite['expiresAt'] as Timestamp?)?.toDate();
      if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
        return const Failure(
          "Ce code a expiré. Demande à ton partenaire d'en créer un nouveau.",
        );
      }
      final coupleId = invite['coupleId'] as String;
      final coupleRef = _refs.couple(coupleId);

      // Transaction : on lie userB de façon atomique et sûre.
      final couple = await _refs.runTransaction<Couple>((tx) async {
        final snap = await tx.get(coupleRef);
        if (!snap.exists) {
          throw _JoinException('Cet espace n\'existe plus.');
        }
        final current = Couple.fromDoc(snap);
        if (current.userA == uid) {
          throw _JoinException('Vous ne pouvez pas rejoindre votre propre code.');
        }
        if (current.isComplete) {
          throw _JoinException('Cet espace est déjà complet.');
        }

        tx.update(coupleRef, {
          'userB': uid,
          'members': [current.userA, uid],
        });
        tx.set(
          _refs.user(uid),
          {'coupleId': coupleId},
          SetOptions(merge: true),
        );
        tx.update(_refs.invite(code), {'active': false});

        return Couple(
          id: current.id,
          userA: current.userA,
          userB: uid,
          inviteCode: current.inviteCode,
          members: [current.userA, uid],
          createdAt: current.createdAt,
        );
      });

      return Success(couple);
    } on _JoinException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Impossible de rejoindre cet espace.', cause: e);
    }
  }

  @override
  Stream<Couple?> watchCouple(String coupleId) {
    return resilientSnapshots(
      () => _refs.couple(coupleId).snapshots().map(
            (doc) => doc.exists ? Couple.fromDoc(doc) : null,
          ),
    );
  }

  @override
  Future<Result<void>> unlink({
    required String coupleId,
    required String uid,
  }) async {
    try {
      final snap = await _refs.couple(coupleId).get();
      if (!snap.exists) {
        // Couple déjà supprimé (ex : l'autre a dissocié) : on nettoie son profil.
        await _refs.user(uid).set({'coupleId': null}, SetOptions(merge: true));
        return const Success(null);
      }
      final couple = Couple.fromDoc(snap);

      // 1. Efface l'historique commun (confidentialité) : les dessins doivent
      //    partir AVANT le couple, sinon plus personne n'a le droit de les lire
      //    ni de les supprimer.
      await _deleteAllDrawings(coupleId);
      await _deleteAll(_refs.stickers(coupleId));

      // 2. Supprime le couple et son invitation, et libère son propre profil.
      //    Les Security Rules n'autorisent qu'à modifier son propre profil : le
      //    partenaire détecte la suppression du couple (son `coupleProvider`
      //    passe à null) et repasse en écran de connexion.
      final batch = FirebaseFirestore.instance.batch();
      batch.set(_refs.user(uid), {'coupleId': null}, SetOptions(merge: true));
      if (couple.inviteCode.isNotEmpty) {
        final invite = await _refs.invite(couple.inviteCode).get();
        if (invite.exists) batch.delete(invite.reference);
      }
      batch.delete(_refs.couple(coupleId));
      await batch.commit();
      return const Success(null);
    } catch (e) {
      return Failure('Impossible de dissocier.', cause: e);
    }
  }

  /// Supprime tous les documents d'une collection, par lots.
  Future<void> _deleteAll(CollectionReference<Map<String, dynamic>> col) async {
    while (true) {
      final page = await col.limit(100).get();
      if (page.docs.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in page.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  /// Supprime tous les dessins d'un couple, par lots (limite de 500
  /// opérations par batch Firestore).
  Future<void> _deleteAllDrawings(String coupleId) async {
    while (true) {
      final page = await _refs.drawings(coupleId).limit(300).get();
      if (page.docs.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in page.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Future<String> _generateUniqueCode() async {
    for (var attempt = 0; attempt < 6; attempt++) {
      final code = InviteCode.generate();
      final exists = (await _refs.invite(code).get()).exists;
      if (!exists) return code;
    }
    // Extrêmement improbable ; on renvoie tout de même un code.
    return InviteCode.generate();
  }
}

class _JoinException implements Exception {
  _JoinException(this.message);
  final String message;
}
