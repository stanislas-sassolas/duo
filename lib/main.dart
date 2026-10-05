import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'providers/service_providers.dart';
import 'services/firebase/firebase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Toujours en portrait (le dessin est au format 3:4), téléphone comme
  // tablette.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Firebase (Auth, Firestore, Storage, Messaging).
  await FirebaseBootstrap.init();

  // Formats de date localisés (historique).
  await initializeDateFormatting('fr');

  // Préférences locales — chargées avant de construire l'arbre pour être
  // disponibles de façon synchrone via [sharedPreferencesProvider].
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const DuoApp(),
    ),
  );
}
