import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../notifications/drawing_notifier.dart';

/// Handler de messages reçus quand l'app est en arrière-plan / tuée.
///
/// DOIT être une fonction top-level (contrainte FCM). Enregistré dans `main`.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Le système affiche déjà la notification "notification" en arrière-plan.
  // Rien à faire ici ; point d'extension si un jour des push serveur sont
  // envoyés (nécessite le forfait Blaze pour la Cloud Function).
}

/// Gère FCM : permission de notifier, jeton de l'appareil, et affichage des
/// éventuels push reçus au premier plan.
///
/// Sur le forfait gratuit, aucun push serveur n'est envoyé : les
/// notifications viennent de l'écoute Firestore (app ouverte ou en
/// arrière-plan) et de [DrawingCheckTask] (app fermée).
class PushNotificationService {
  PushNotificationService({FirebaseMessaging? messaging})
      : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  /// Si non-null, les notifications au premier plan sont supprimées (ex :
  /// l'utilisateur regarde déjà le dessin reçu).
  bool Function()? suppressForeground;

  bool _soundEnabled = true;
  set soundEnabled(bool value) => _soundEnabled = value;
  bool get soundEnabled => _soundEnabled;

  StreamSubscription<RemoteMessage>? _foregroundSub;

  /// Demande la permission de notifier (Android 13+) et écoute les push.
  Future<void> init() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    _foregroundSub =
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  }

  /// Jeton FCM de l'appareil (à persister sur le profil pour les envois).
  Future<String?> currentToken() => _messaging.getToken();

  /// Flux des rafraîchissements de jeton.
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  void _handleForegroundMessage(RemoteMessage message) {
    if (suppressForeground?.call() ?? false) return;
    final drawingId = message.data['drawingId'] as String?;
    if (drawingId == null) return;
    DrawingNotifier.showNewDrawing(
      drawingId: drawingId,
      senderName: 'Ton amour',
    );
  }

  void dispose() {
    unawaited(_foregroundSub?.cancel());
  }
}
