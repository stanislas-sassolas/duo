import 'package:cloud_firestore/cloud_firestore.dart';

/// Rouvre une écoute Firestore refusée pour « permission-denied ».
///
/// Pourquoi : juste après une écriture (création d'un espace, arrivée du
/// partenaire), le cache local annonce la nouveauté avant que le serveur l'ait
/// enregistrée. Une écoute ouverte pendant cette fenêtre est refusée par les
/// Security Rules et Firestore la ferme définitivement : l'écran restait alors
/// figé (« En attente de ton partenaire »). On réessaie quelques fois, avec un
/// délai croissant, avant d'abandonner (vrai refus : ex. couple supprimé).
Stream<T> resilientSnapshots<T>(
  Stream<T> Function() open, {
  int maxRetries = 4,
}) async* {
  var attempt = 0;
  while (true) {
    try {
      await for (final value in open()) {
        attempt = 0;
        yield value;
      }
      return;
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied' || attempt >= maxRetries) rethrow;
      attempt++;
      await Future<void>.delayed(Duration(milliseconds: 800 * attempt));
    }
  }
}
