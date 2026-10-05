import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Résultat d'une recherche de mise à jour.
enum UpdateStatus { upToDate, started, canceled, error }

/// Mises à jour directement dans l'app, via Firebase App Distribution.
///
/// La première fois, le testeur se connecte avec le compte Google qui a reçu
/// l'invitation. Ensuite : « Nouvelle version » → autorisation d'installer
/// (une seule fois) → téléchargement → installeur Android.
class AppUpdateService {
  AppUpdateService._();

  static const MethodChannel _channel = MethodChannel('duo/update');

  /// Déjà connecté à App Distribution (les vérifications sont silencieuses).
  static Future<bool> isSignedIn() async {
    try {
      return await _channel.invokeMethod<bool>('isSignedIn') ?? false;
    } catch (e) {
      debugPrint('Mises à jour indisponibles : $e');
      return false;
    }
  }

  /// Numéro de version installé, ex. « 1.3.0 ».
  static Future<String?> version() async {
    try {
      return await _channel.invokeMethod<String>('version');
    } catch (_) {
      return null;
    }
  }

  /// Parcours complet. Les fenêtres s'ouvrent sur [navigator].
  static Future<UpdateStatus> run(GlobalKey<NavigatorState> navigator) async {
    try {
      if (!await isSignedIn()) {
        final signIn = await _channel.invokeMethod<String>('signIn');
        if (signIn != 'ok') return _fromNative(signIn);
      }

      final release = await _channel.invokeMethod<Object?>('check');
      if (release == null) return UpdateStatus.upToDate;
      if (release is! Map) return _fromNative(release as String?);
      final version = release['version'] as String? ?? '';
      final notes = release['notes'] as String? ?? '';

      if (!await _confirm(
        navigator,
        title: 'Nouvelle version ✨',
        message: 'Duo $version est prête.${notes.isEmpty ? '' : '\n\n$notes'}',
        ok: 'Mettre à jour',
        cancel: 'Plus tard',
      )) {
        return UpdateStatus.canceled;
      }

      // Android doit autoriser Duo à installer une app (une seule fois).
      if (!await _canInstall()) {
        if (!await _confirm(
          navigator,
          title: 'Une petite autorisation',
          message: 'Pour installer la mise à jour, Android doit autoriser '
              'Duo. Active « Autoriser depuis cette source », puis reviens '
              'dans Duo.',
          ok: 'Ouvrir les réglages',
          cancel: 'Annuler',
        )) {
          return UpdateStatus.canceled;
        }
        final back = _nextResume();
        await _channel.invokeMethod<void>('openInstallSettings');
        await back;
        if (!await _canInstall()) return UpdateStatus.canceled;
      }

      final context = navigator.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Téléchargement de la mise à jour… 🐞'),
          ),
        );
      }
      return _fromNative(
        await _channel.invokeMethod<String>('install'),
        ok: UpdateStatus.started,
      );
    } catch (e) {
      debugPrint('Mise à jour impossible : $e');
      return UpdateStatus.error;
    }
  }

  static UpdateStatus _fromNative(
    String? status, {
    UpdateStatus ok = UpdateStatus.upToDate,
  }) {
    if (status == 'ok') return ok;
    if (status == 'canceled') return UpdateStatus.canceled;
    debugPrint('Mise à jour : $status');
    return UpdateStatus.error;
  }

  static Future<bool> _canInstall() async =>
      await _channel.invokeMethod<bool>('canInstall') ?? false;

  /// Se termine quand on revient dans l'app (après les réglages Android).
  static Future<void> _nextResume() {
    final done = Completer<void>();
    late final AppLifecycleListener listener;
    listener = AppLifecycleListener(
      onResume: () {
        listener.dispose();
        if (!done.isCompleted) done.complete();
      },
    );
    return done.future;
  }

  static Future<bool> _confirm(
    GlobalKey<NavigatorState> navigator, {
    required String title,
    required String message,
    required String ok,
    required String cancel,
  }) async {
    final context = navigator.currentContext;
    if (context == null || !context.mounted) return false;
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(ok),
          ),
        ],
      ),
    );
    return answer ?? false;
  }
}
