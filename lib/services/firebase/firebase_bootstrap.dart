import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../messaging/push_notification_service.dart';
// Généré par `flutterfire configure`. Voir README si le fichier manque.
import '../../firebase_options.dart';

/// Point d'entrée d'initialisation de Firebase, appelé une seule fois au boot.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static Future<void> init() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Cache offline persistant : le dernier dessin reste visible sans réseau.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );
  }
}
