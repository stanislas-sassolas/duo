import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/datasources/firestore_refs.dart';
import '../data/local/pending_drawings_store.dart';
import '../data/repositories/firebase_auth_repository.dart';
import '../data/repositories/firestore_couple_repository.dart';
import '../data/repositories/firestore_drawing_repository.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/couple_repository.dart';
import '../domain/repositories/drawing_repository.dart';
import '../services/audio/music_service.dart';
import '../services/audio/sound_service.dart';
import '../services/connectivity/connectivity_service.dart';
import '../services/messaging/push_notification_service.dart';
import '../services/sync/outbox_service.dart';

/// Surchargé dans `main()` une fois SharedPreferences chargé.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider non initialisé'),
);

final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final firestoreRefsProvider =
    Provider<FirestoreRefs>((ref) => FirestoreRefs(FirebaseFirestore.instance));

// --- Repositories ---

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(
    auth: ref.watch(firebaseAuthProvider),
    refs: ref.watch(firestoreRefsProvider),
  ),
);

final coupleRepositoryProvider = Provider<CoupleRepository>(
  (ref) => FirestoreCoupleRepository(ref.watch(firestoreRefsProvider)),
);

final drawingRepositoryProvider = Provider<DrawingRepository>(
  (ref) => FirestoreDrawingRepository(ref.watch(firestoreRefsProvider)),
);

// --- Services ---

final connectivityServiceProvider =
    Provider<ConnectivityService>((ref) => ConnectivityService());

final soundServiceProvider = Provider<SoundService>((ref) => SoundService());

final musicServiceProvider = Provider<MusicService>((ref) {
  final music = MusicService();
  ref.onDispose(music.stop);
  return music;
});

final pushNotificationServiceProvider =
    Provider<PushNotificationService>((ref) => PushNotificationService());

final pendingDrawingsStoreProvider = Provider<PendingDrawingsStore>(
  (ref) => PendingDrawingsStore(ref.watch(sharedPreferencesProvider)),
);

final outboxServiceProvider = Provider<OutboxService>((ref) {
  final service = OutboxService(
    store: ref.watch(pendingDrawingsStoreProvider),
    drawingRepository: ref.watch(drawingRepositoryProvider),
    connectivity: ref.watch(connectivityServiceProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});
