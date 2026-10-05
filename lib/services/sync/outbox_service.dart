import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/utils/result.dart';
import '../../data/local/pending_drawings_store.dart';
import '../../domain/repositories/drawing_repository.dart';
import '../../models/drawing.dart';
import '../connectivity/connectivity_service.dart';

/// Issue de l'envoi d'un dessin.
enum SendOutcome {
  /// Parti tout de suite.
  sent,

  /// En file d'attente (hors-ligne / erreur passagère) : partira tout seul.
  queued,

  /// Refusé définitivement par le serveur : retiré de la file.
  rejected,
}

/// Orchestre l'envoi fiable des dessins, en ligne comme hors-ligne.
///
/// Stratégie :
/// 1. On empile toujours le dessin dans l'outbox local (aucune perte possible).
/// 2. On tente un flush immédiat.
/// 3. Le retour du réseau déclenche automatiquement un nouveau flush.
///
/// Les flush sont **sérialisés** (jamais deux en parallèle), et un dessin
/// refusé définitivement est retiré de la file pour ne pas bloquer les
/// suivants.
class OutboxService {
  OutboxService({
    required PendingDrawingsStore store,
    required DrawingRepository drawingRepository,
    required ConnectivityService connectivity,
  })  : _store = store,
        _drawings = drawingRepository,
        _connectivity = connectivity;

  final PendingDrawingsStore _store;
  final DrawingRepository _drawings;
  final ConnectivityService _connectivity;

  StreamSubscription<bool>? _connectivitySub;

  /// File d'exécution : chaque flush attend la fin du précédent.
  Future<void> _lock = Future.value();

  /// Ids des dessins refusés définitivement lors des flush récents.
  final Set<String> _rejected = {};

  /// À appeler au démarrage : rejoue les dessins en attente et écoute le réseau.
  void start() {
    _connectivitySub ??= _connectivity.onConnectedChanged.listen((connected) {
      if (connected) unawaited(flush());
    });
    unawaited(flush());
  }

  void dispose() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  /// Empile un dessin puis tente immédiatement de l'envoyer.
  Future<SendOutcome> enqueueAndSend(Drawing drawing) async {
    await _store.add(drawing);

    // Hors-ligne : on ne tente pas l'écriture (le Future Firestore ne se
    // résoudrait pas). Le dessin reste en file et partira au retour du réseau.
    if (!await _connectivity.isConnected) return SendOutcome.queued;

    await flush();

    if (_rejected.remove(drawing.id)) return SendOutcome.rejected;
    final stillPending = _store.load().any((d) => d.id == drawing.id);
    return stillPending ? SendOutcome.queued : SendOutcome.sent;
  }

  int get pendingCount => _store.load().length;

  /// Tente d'envoyer tous les dessins en attente. Sûr à appeler en boucle.
  Future<void> flush() {
    final run = _lock.then((_) => _flushOnce());
    _lock = run.catchError((Object _) {});
    return run;
  }

  Future<void> _flushOnce() async {
    if (!await _connectivity.isConnected) return;
    for (final drawing in _store.load()) {
      final result = await _drawings.sendDrawing(drawing);
      switch (result) {
        case Success():
          await _store.remove(drawing.id);
        case Failure(permanent: true, :final cause):
          // Réessayer ne servira à rien : on retire ce dessin pour ne pas
          // bloquer toute la file derrière lui.
          debugPrint('Outbox : dessin ${drawing.id} refusé ($cause)');
          _rejected.add(drawing.id);
          await _store.remove(drawing.id);
        case Failure():
          // Erreur passagère : on s'arrête pour préserver l'ordre d'envoi.
          return;
      }
    }
  }
}
