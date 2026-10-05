import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/router/app_flow.dart';
import '../core/router/app_router.dart';
import '../models/drawing.dart';
import '../providers/auth_providers.dart';
import '../providers/couple_providers.dart';
import '../providers/drawing_providers.dart';
import '../providers/personal_providers.dart';
import '../providers/service_providers.dart';
import '../providers/settings_providers.dart';
import '../services/audio/sound_service.dart';
import '../services/background/drawing_check_task.dart';
import '../services/notifications/drawing_notifier.dart';
import '../services/update/app_update_service.dart';
import '../services/widget/drawing_widget_service.dart';

/// Effectue les initialisations dépendantes du contexte applicatif :
/// - démarrage de l'outbox (renvoi des dessins en attente) ;
/// - notifications : permission, jeton FCM, tâche d'arrière-plan ;
/// - réaction à l'arrivée d'un nouveau dessin (son ou notification) ;
/// - ouverture du dessin quand on touche une notification ;
/// - synchronisation des préférences (son, notifications) vers les services.
class AppStartup extends ConsumerStatefulWidget {
  const AppStartup({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends ConsumerState<AppStartup>
    with WidgetsBindingObserver {
  String? _registeredToken;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<String?>? _widgetClickSub;

  /// Dessin à ouvrir dès que l'utilisateur est sur l'application principale.
  String? _pendingOpenId;

  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  /// Réactions déjà connues sur mes dessins envoyés (id → emoji).
  Map<String, String?>? _knownReactions;

  /// Surnom et petits mots par défaut posés une seule fois par session.
  bool _personalDefaultsApplied = false;

  late final NotificationWatermark _watermark =
      NotificationWatermark(ref.read(sharedPreferencesProvider));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
  }

  Future<void> _init() async {
    // 1. Outbox : rejoue les dessins en attente et écoute le réseau.
    ref.read(outboxServiceProvider).start();
    // Les sons de l'app ne coupent jamais la musique du téléphone.
    await SoundService.configureAudioSession();

    // 2. Notifications locales + ouverture du dessin touché.
    await _watermark.ensureInitialized();
    try {
      await DrawingNotifier.initialize(onOpen: _openDrawing);
      final launchId = await DrawingNotifier.launchDrawingId();
      if (launchId != null) _openDrawing(launchId);
    } catch (e) {
      debugPrint('Notifications locales indisponibles : $e');
    }

    // 3. Widget d'écran d'accueil : toucher le widget ouvre le dessin.
    final widgetLaunchId = await DrawingWidgetService.launchDrawingId();
    if (widgetLaunchId != null) _openDrawing(widgetLaunchId);
    _widgetClickSub = DrawingWidgetService.clicks.listen((id) {
      if (id != null) _openDrawing(id);
    });

    // 4. Vérification périodique quand l'app est fermée (Android).
    try {
      await DrawingCheckTask.schedule();
    } catch (e) {
      debugPrint('Tâche d\'arrière-plan non planifiée : $e');
    }

    // 5. Permission de notifier + jeton FCM (non bloquant).
    final push = ref.read(pushNotificationServiceProvider);
    push.suppressForeground = () => ref.read(isViewingReceivedProvider);
    try {
      await push.init();
      _tokenRefreshSub = push.onTokenRefresh.listen(_registerToken);
      final token = await push.currentToken();
      if (token != null) await _registerToken(token);
    } catch (_) {
      // Sans Google Play Services / hors-ligne : non bloquant.
    }

    // 6. Mises à jour dans l'app.
    unawaited(_checkForUpdate());
  }

  /// Vérifie discrètement s'il y a une nouvelle version. Tant que le compte
  /// testeur n'est pas connecté, on ne le propose qu'une fois ; ensuite,
  /// c'est depuis les Paramètres.
  Future<void> _checkForUpdate() async {
    await Future<void>.delayed(const Duration(seconds: 3));
    final prefs = ref.read(sharedPreferencesProvider);
    final signedIn = await AppUpdateService.isSignedIn();
    if (!signedIn && (prefs.getBool(AppConstants.prefUpdateAsked) ?? false)) {
      return;
    }
    final status = await AppUpdateService.run(
      ref.read(routerProvider).routerDelegate.navigatorKey,
    );
    // En cas d'erreur (hors-ligne…), on le reproposera au prochain lancement.
    if (!signedIn && status != UpdateStatus.error) {
      await prefs.setBool(AppConstants.prefUpdateAsked, true);
    }
  }

  Future<void> _registerToken(String token) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null || token == _registeredToken) return;
    _registeredToken = token;
    await ref.read(authRepositoryProvider).addFcmToken(uid, token);
  }

  /// Ouvre un dessin (tap sur une notification). Si l'app n'est pas encore
  /// prête (chargement), on attend que le parcours arrive à l'accueil.
  void _openDrawing(String drawingId) {
    if (ref.read(appFlowProvider) == AppFlow.ready) {
      ref.read(routerProvider).push('/detail/$drawingId');
    } else {
      _pendingOpenId = drawingId;
    }
  }

  /// Un nouveau dessin reçu arrive par l'écoute temps réel de Firestore.
  void _onLatestReceived(Drawing? drawing) {
    if (drawing == null || drawing.isViewed) return;
    final createdAt = drawing.createdAt;
    if (createdAt == null || !_watermark.isNew(createdAt)) return;
    unawaited(_watermark.advanceTo(createdAt));

    if (_lifecycle == AppLifecycleState.resumed) {
      // App à l'écran : l'accueil affiche déjà le dessin, un petit son suffit.
      if (!ref.read(isViewingReceivedProvider)) {
        unawaited(ref.read(soundServiceProvider).playReceived());
      }
      return;
    }

    // App en arrière-plan (encore en mémoire) : notification immédiate.
    if (!ref.read(settingsProvider).notificationsEnabled) return;
    final partnerName =
        ref.read(partnerProvider).valueOrNull?.displayName ?? 'Ton amour';
    unawaited(
      DrawingNotifier.showNewDrawing(
        drawingId: drawing.id,
        senderName: partnerName,
        message: drawing.message,
        isReply: drawing.replyToDrawingId != null,
      ),
    );
  }

  /// Mon partenaire vient de réagir à l'un de mes dessins.
  void _onHistory(List<Drawing>? history) {
    if (history == null) return;
    final uid = ref.read(currentUidProvider);
    final current = {
      for (final d in history)
        if (d.senderId == uid) d.id: d.reaction,
    };
    final known = _knownReactions;
    _knownReactions = current;
    if (known == null) return; // premier chargement : rien de nouveau

    for (final entry in current.entries) {
      final reaction = entry.value;
      if (reaction == null || known[entry.key] == reaction) continue;
      if (!known.containsKey(entry.key)) continue; // nouveau dessin
      if (_lifecycle == AppLifecycleState.resumed) {
        unawaited(ref.read(soundServiceProvider).playReceived());
      } else if (ref.read(settingsProvider).notificationsEnabled) {
        final partnerName =
            ref.read(partnerProvider).valueOrNull?.displayName ?? 'Ton amour';
        unawaited(
          DrawingNotifier.showReaction(
            drawingId: entry.key,
            partnerName: partnerName,
            reaction: reaction,
          ),
        );
      }
    }
  }

  /// Le widget d'écran d'accueil montre toujours le dernier dessin reçu.
  void _refreshHomeWidget(AsyncValue<Drawing?> latest) {
    if (latest is! AsyncData<Drawing?>) return;
    final drawing = latest.value;
    if (drawing == null) {
      // Vide seulement après une vraie dissociation (profil chargé, sans
      // couple) : au démarrage, « pas de dessin » veut juste dire « pas
      // encore chargé ».
      final user = ref.read(currentUserProvider);
      if (user is AsyncData && user.value != null && !user.value!.hasCouple) {
        unawaited(DrawingWidgetService.clear());
      }
      return;
    }
    final partnerName =
        ref.read(partnerProvider).valueOrNull?.displayName ?? 'Ton amour';
    unawaited(DrawingWidgetService.showDrawing(drawing, partnerName));
  }

  @override
  Widget build(BuildContext context) {
    // Propage les préférences vers les services à chaque changement.
    ref.listen(settingsProvider, (_, settings) {
      ref.read(soundServiceProvider).enabled = settings.soundEnabled;
      ref.read(pushNotificationServiceProvider).soundEnabled =
          settings.soundEnabled && settings.notificationsEnabled;
    });

    // Premier profil chargé : surnom et petits mots par défaut (Sam, Alex).
    ref.listen(currentUserProvider, (_, next) {
      if (_personalDefaultsApplied || next.valueOrNull == null) return;
      _personalDefaultsApplied = true;
      unawaited(
        ref.read(personalControllerProvider).applyDefaultsIfNeeded(),
      );
    });

    ref.listen(latestReceivedProvider, (_, next) {
      _onLatestReceived(next.valueOrNull);
      _refreshHomeWidget(next);
    });
    ref.listen(historyProvider, (_, next) => _onHistory(next.valueOrNull));

    // Le prénom du partenaire peut arriver après le dessin.
    ref.listen(partnerProvider, (_, __) {
      _refreshHomeWidget(ref.read(latestReceivedProvider));
    });

    ref.listen(appFlowProvider, (_, flow) {
      final pending = _pendingOpenId;
      if (flow == AppFlow.ready && pending != null) {
        _pendingOpenId = null;
        // Laisse le router se poser sur l'accueil avant d'empiler le détail.
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => ref.read(routerProvider).push('/detail/$pending'),
        );
      }
    });

    return widget.child;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tokenRefreshSub?.cancel();
    _widgetClickSub?.cancel();
    super.dispose();
  }
}
