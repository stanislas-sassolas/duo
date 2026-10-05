import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/background_providers.dart';

/// Fond de Paris (ou une de mes images), tiré au sort à chaque ouverture de
/// l'app. Utilisé sur l'accueil et sur les écrans du début.
///
/// [readable] ajoute un voile plus marqué pour les écrans avec du texte au
/// centre (bienvenue, prénom, code…) ; sinon, voiles doux seulement en haut
/// et en bas.
class ParisBackdrop extends ConsumerWidget {
  const ParisBackdrop({super.key, this.readable = false});

  final bool readable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(homeBackgroundProvider);
    final veil = Theme.of(context).scaffoldBackgroundColor;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: veil),
        Image(
          image: image,
          fit: BoxFit.cover,
          frameBuilder: (context, child, frame, wasSync) => AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 600),
            child: child,
          ),
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0, 0.22, 0.72, 1],
              colors: readable
                  ? [
                      veil.withValues(alpha: 0.92),
                      veil.withValues(alpha: 0.72),
                      veil.withValues(alpha: 0.72),
                      veil.withValues(alpha: 0.92),
                    ]
                  : [
                      veil.withValues(alpha: 0.92),
                      veil.withValues(alpha: 0.05),
                      veil.withValues(alpha: 0.05),
                      veil.withValues(alpha: 0.92),
                    ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Écran posé sur le fond de Paris (Scaffold transparent par-dessus).
class ParisScaffold extends StatelessWidget {
  const ParisScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.readable = true,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final bool readable;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: ParisBackdrop(readable: readable)),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: appBar,
          body: body,
        ),
      ],
    );
  }
}
