import 'dart:io';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../core/constants/app_constants.dart';
import '../../firebase_options.dart';
import '../../models/drawing.dart';
import '../notifications/drawing_notifier.dart';
import '../widget/drawing_widget_service.dart';

/// Vérification périodique des nouveaux dessins quand l'app est fermée.
///
/// Sans Cloud Functions (forfait gratuit), aucun serveur ne peut envoyer de
/// push. Android exécute donc cette tâche environ toutes les 15 minutes (le
/// minimum autorisé par le système) : elle interroge Firestore et affiche une
/// notification locale pour chaque nouveau dessin reçu.
class DrawingCheckTask {
  DrawingCheckTask._();

  static const String uniqueName = 'duo-check-new-drawings';
  static const String taskName = 'duo.checkNewDrawings';

  /// À appeler au démarrage de l'app (Android uniquement).
  static Future<void> schedule() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await Workmanager().initialize(drawingCheckDispatcher);
    await Workmanager().registerPeriodicTask(
      uniqueName,
      taskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  /// Le travail lui-même. Retourne toujours `true` : en cas d'échec, on
  /// réessaiera simplement au prochain passage.
  static Future<bool> run() async {
    try {
      DartPluginRegistrant.ensureInitialized();
      // Isolate séparé : les formats de date français ne sont pas chargés.
      await initializeDateFormatting('fr');
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // valeurs écrites par l'app (autre isolate)

      final user = await FirebaseAuth.instance.authStateChanges().first;
      if (user == null) return true;

      final db = FirebaseFirestore.instance;
      const server = GetOptions(source: Source.server);
      final me = await db.doc('users/${user.uid}').get(server);
      final coupleId = me.data()?['coupleId'] as String?;
      if (coupleId == null || coupleId.isEmpty) return true;

      final watermark = NotificationWatermark(prefs);
      await watermark.ensureInitialized();

      final snap = await db
          .collection('couples/$coupleId/drawings')
          .where('receiverId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get(server);

      // Widget d'écran d'accueil : toujours le dernier dessin reçu.
      final names = <String, String>{};
      if (snap.docs.isNotEmpty) {
        final latest = Drawing.fromDoc(snap.docs.first, coupleId: coupleId);
        names[latest.senderId] = await _displayName(db, latest.senderId);
        await DrawingWidgetService.showDrawing(
          latest,
          names[latest.senderId]!,
        );
      }

      if (!(prefs.getBool(AppConstants.prefNotificationsEnabled) ?? true)) {
        return true;
      }

      // Du plus ancien au plus récent, seulement les nouveaux non vus.
      final fresh = snap.docs.reversed.where((doc) {
        final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();
        return createdAt != null &&
            doc.data()['viewedAt'] == null &&
            watermark.isNew(createdAt);
      }).toList();
      if (fresh.isEmpty) return true;

      await DrawingNotifier.initialize();
      for (final doc in fresh) {
        final data = doc.data();
        final senderId = data['senderId'] as String? ?? '';
        names[senderId] ??= await _displayName(db, senderId);
        await DrawingNotifier.showNewDrawing(
          drawingId: doc.id,
          senderName: names[senderId]!,
          message: data['message'] as String?,
          isReply: data['replyToDrawingId'] != null,
        );
        await watermark.advanceTo((data['createdAt'] as Timestamp).toDate());
      }
    } catch (e) {
      debugPrint('DrawingCheckTask : $e');
    }
    return true;
  }

  static Future<String> _displayName(FirebaseFirestore db, String uid) async {
    try {
      final doc = await db.doc('users/$uid').get();
      final name = doc.data()?['displayName'] as String?;
      if (name != null && name.trim().isNotEmpty) return name;
    } catch (_) {}
    return 'Ton amour';
  }
}

/// Point d'entrée de la tâche d'arrière-plan. DOIT être une fonction
/// top-level annotée (exécutée dans un isolate séparé).
@pragma('vm:entry-point')
void drawingCheckDispatcher() {
  Workmanager().executeTask((task, inputData) => DrawingCheckTask.run());
}
