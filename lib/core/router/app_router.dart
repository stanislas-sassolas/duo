import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/personal.dart';

import '../../presentation/canvas/canvas_screen.dart';
import '../../presentation/history/drawing_detail_screen.dart';
import '../../presentation/history/history_screen.dart';
import '../../presentation/home/home_screen.dart';
import '../../presentation/onboarding/connect_partner_screen.dart';
import '../../presentation/onboarding/name_screen.dart';
import '../../presentation/onboarding/waiting_partner_screen.dart';
import '../../presentation/onboarding/welcome_screen.dart';
import '../../presentation/settings/backgrounds_screen.dart';
import '../../presentation/settings/phrases_screen.dart';
import '../../presentation/settings/settings_screen.dart';
import 'app_flow.dart';

/// Fournit le [GoRouter] de l'app avec redirection réactive à l'état du flow.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _FlowRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      // Lien du widget (duo://drawing/…) : l'ouverture du dessin est gérée
      // par AppStartup ; le routeur se contente de revenir à l'accueil.
      if (state.uri.scheme == 'duo') return '/';

      final flow = ref.read(appFlowProvider);
      final loc = state.matchedLocation;

      const onboardingRoutes = {'/welcome', '/name'};

      switch (flow) {
        case AppFlow.loading:
          return loc == '/splash' ? null : '/splash';
        case AppFlow.onboarding:
          return onboardingRoutes.contains(loc) ? null : '/welcome';
        case AppFlow.needsCouple:
          return loc == '/connect' ? null : '/connect';
        case AppFlow.waiting:
          return loc == '/waiting' ? null : '/waiting';
        case AppFlow.ready:
          const gated = {
            '/splash',
            '/welcome',
            '/name',
            '/connect',
            '/waiting',
          };
          return gated.contains(loc) ? '/' : null;
      }
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const _SplashScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (_, __) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/name',
        builder: (_, __) => const NameScreen(),
      ),
      GoRoute(
        path: '/connect',
        builder: (_, __) => const ConnectPartnerScreen(),
      ),
      GoRoute(
        path: '/waiting',
        builder: (_, __) => const WaitingPartnerScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: '/canvas',
        builder: (_, state) => CanvasScreen(
          replyToDrawingId: state.uri.queryParameters['replyTo'],
        ),
      ),
      GoRoute(
        path: '/history',
        builder: (_, state) => HistoryScreen(
          filter: HistoryScreen.filterFromQuery(
            state.uri.queryParameters['filter'],
          ),
        ),
      ),
      GoRoute(
        path: '/detail/:id',
        builder: (_, state) =>
            DrawingDetailScreen(drawingId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/phrases',
        builder: (_, __) => const PhrasesScreen(),
      ),
      GoRoute(
        path: '/backgrounds',
        builder: (_, __) => const BackgroundsScreen(),
      ),
    ],
  );
});

/// Rafraîchit le router quand l'étape du flow change.
class _FlowRefresh extends ChangeNotifier {
  _FlowRefresh(Ref ref) {
    _sub = ref.listen<AppFlow>(
      appFlowProvider,
      (_, __) => notifyListeners(),
      fireImmediately: false,
    );
  }

  late final ProviderSubscription<AppFlow> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('❤️', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              Personal.littlePrinceQuote,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).hintColor,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
