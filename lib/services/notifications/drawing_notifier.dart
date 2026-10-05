import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';

/// Affiche les notifications « nouveau dessin » et gère leur ouverture.
///
/// Utilisable depuis l'app **et** depuis la tâche d'arrière-plan (aucune
/// dépendance à Riverpod) : c'est ce qui permet de notifier sans serveur
/// (pas de Cloud Functions sur le forfait gratuit Spark).
class DrawingNotifier {
  DrawingNotifier._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Canal avec le petit tintement de Duo (res/raw/receive_sparkle.wav).
  /// Le son d'un canal Android ne peut plus changer après sa création : d'où
  /// un nouvel identifiant (l'ancien canal « drawings » est supprimé).
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'drawings_sparkle',
    'Dessins',
    description: 'Notifications de nouveaux dessins',
    importance: Importance.high,
    sound: RawResourceAndroidNotificationSound('receive_sparkle'),
  );

  /// Initialise le plugin. [onOpen] reçoit l'id du dessin quand l'utilisateur
  /// touche une notification pendant que l'app tourne.
  static Future<void> initialize(
      {void Function(String drawingId)? onOpen}) async {
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_duo'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        final id = response.payload;
        if (id != null && id.isNotEmpty) onOpen?.call(id);
      },
    );
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.deleteNotificationChannel('drawings');
    await android?.createNotificationChannel(_channel);
  }

  /// Id du dessin dont la notification a lancé l'app (démarrage à froid).
  static Future<String?> launchDrawingId() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    final id = details.notificationResponse?.payload;
    return (id == null || id.isEmpty) ? null : id;
  }

  static Future<void> showNewDrawing({
    required String drawingId,
    required String senderName,
    String? message,
    bool isReply = false,
  }) {
    // Avec un petit mot : « ❤️ Bisous » / « Sam t'a envoyé un dessin ».
    final phrase = message?.trim() ?? '';
    return _plugin.show(
      drawingId.hashCode & 0x7fffffff,
      phrase.isNotEmpty ? phrase : '$senderName t\'a envoyé un dessin ❤️',
      phrase.isNotEmpty
          ? '$senderName t\'a envoyé un dessin'
          : (isReply ? 'Une réponse pour toi' : 'Ouvre pour le découvrir'),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_stat_duo',
          sound: const RawResourceAndroidNotificationSound('receive_sparkle'),
          color: const Color(0xFFE8687F),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: drawingId,
    );
  }

  /// « Alex a réagi à ton dessin ❤️ ».
  static Future<void> showReaction({
    required String drawingId,
    required String partnerName,
    required String reaction,
  }) {
    return _plugin.show(
      ('r$drawingId').hashCode & 0x7fffffff,
      '$partnerName a réagi à ton dessin $reaction',
      null,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_stat_duo',
          color: const Color(0xFFE8687F),
          sound: const RawResourceAndroidNotificationSound('receive_sparkle'),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: drawingId,
    );
  }

  /// Retire la notification d'un dessin (ex : ouvert depuis l'app).
  static Future<void> cancelFor(String drawingId) =>
      _plugin.cancel(drawingId.hashCode & 0x7fffffff);
}

/// Mémorise jusqu'où les dessins reçus ont déjà été notifiés, pour ne jamais
/// notifier deux fois le même dessin (app et tâche d'arrière-plan partagent
/// cette valeur via SharedPreferences).
class NotificationWatermark {
  NotificationWatermark(this._prefs);

  final SharedPreferences _prefs;

  static const _key = AppConstants.prefLastNotifiedDrawingAt;

  /// Au tout premier lancement, on part de « maintenant » : pas de
  /// notification pour d'anciens dessins.
  Future<void> ensureInitialized() async {
    if (_prefs.getInt(_key) == null) {
      await _prefs.setInt(_key, DateTime.now().millisecondsSinceEpoch);
    }
  }

  bool isNew(DateTime createdAt) =>
      createdAt.millisecondsSinceEpoch > (_prefs.getInt(_key) ?? 0);

  Future<void> advanceTo(DateTime createdAt) async {
    final ms = createdAt.millisecondsSinceEpoch;
    if (ms > (_prefs.getInt(_key) ?? 0)) await _prefs.setInt(_key, ms);
  }
}
