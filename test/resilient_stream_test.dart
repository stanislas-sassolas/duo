import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:duo_draw/core/utils/resilient_stream.dart';
import 'package:flutter_test/flutter_test.dart';

FirebaseException _denied() =>
    FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');

void main() {
  test('une écoute refusée au départ est rouverte puis fonctionne', () async {
    var opens = 0;
    Stream<int> open() {
      opens++;
      if (opens == 1) return Stream.error(_denied());
      return Stream.fromIterable([1, 2]);
    }

    final values = await resilientSnapshots(open).toList();
    expect(values, [1, 2]);
    expect(opens, 2);
  });

  test('un refus persistant finit par remonter l\'erreur', () async {
    final stream = resilientSnapshots<int>(
      () => Stream.error(_denied()),
      maxRetries: 1,
    );
    await expectLater(stream, emitsError(isA<FirebaseException>()));
  });

  test('les autres erreurs ne sont pas réessayées', () async {
    var opens = 0;
    final stream = resilientSnapshots<int>(() {
      opens++;
      return Stream.error(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );
    });
    await expectLater(stream, emitsError(isA<FirebaseException>()));
    expect(opens, 1);
  });
}
