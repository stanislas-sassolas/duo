import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';

/// Références Firestore centralisées et typées.
///
/// Un seul endroit connaît les chemins → refactoring et Security Rules
/// restent cohérents.
class FirestoreRefs {
  FirestoreRefs(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get users =>
      _db.collection(AppConstants.usersCollection);

  DocumentReference<Map<String, dynamic>> user(String uid) => users.doc(uid);

  /// Petits mots personnels de [uid] : lisibles et modifiables par lui seul
  /// (sous-collection `private`, voir les Security Rules).
  DocumentReference<Map<String, dynamic>> privatePhrases(String uid) =>
      user(uid).collection('private').doc('phrases');

  CollectionReference<Map<String, dynamic>> get couples =>
      _db.collection(AppConstants.couplesCollection);

  DocumentReference<Map<String, dynamic>> couple(String coupleId) =>
      couples.doc(coupleId);

  /// Annuaire code → coupleId. Lisible par tout utilisateur authentifié pour
  /// permettre de rejoindre, sans exposer le contenu des couples.
  CollectionReference<Map<String, dynamic>> get invites =>
      _db.collection(AppConstants.invitesCollection);

  /// Le document invite a pour id le code lui-même (`LOVE-7K42QX`).
  DocumentReference<Map<String, dynamic>> invite(String code) =>
      invites.doc(code);

  /// Stickers importés, partagés par les deux membres du couple.
  CollectionReference<Map<String, dynamic>> stickers(String coupleId) =>
      couple(coupleId).collection('stickers');

  CollectionReference<Map<String, dynamic>> drawings(String coupleId) =>
      couple(coupleId).collection(AppConstants.drawingsSubcollection);

  DocumentReference<Map<String, dynamic>> drawing(
    String coupleId,
    String drawingId,
  ) =>
      drawings(coupleId).doc(drawingId);

  /// Transaction utilitaire.
  Future<T> runTransaction<T>(
    Future<T> Function(Transaction) handler,
  ) =>
      _db.runTransaction(handler);
}
