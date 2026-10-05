import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time_labels.dart';
import '../../models/drawing.dart';
import '../../providers/auth_providers.dart';
import '../../providers/couple_providers.dart';
import '../../providers/drawing_providers.dart';
import '../../widgets/couple_header.dart';
import '../../widgets/double_tap_react.dart';
import '../../widgets/paris_backdrop.dart';
import '../../widgets/polaroid.dart';

/// Accueil épuré : « Sam ❤️ Alex 🌻 » en haut, le dernier dessin reçu en
/// grand polaroïd, et une barre du bas (historique · dessiner · réglages).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partner = ref.watch(partnerProvider).valueOrNull;
    final latest = ref.watch(latestReceivedProvider).valueOrNull;
    final me = ref.watch(currentUserProvider).valueOrNull;
    final couple = ref.watch(coupleProvider).valueOrNull;
    final partnerName = partner?.displayName ?? 'ton amour';

    // Même ordre sur les deux téléphones : le créateur de l'espace d'abord.
    final meFirst = couple == null || couple.userA == me?.id;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: ParisBackdrop()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: CoupleHeader(
                    first: meFirst ? me : partner,
                    second: meFirst ? partner : me,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(48, 28, 48, 20),
                    child: latest == null
                        ? _EmptyPolaroid(partnerName: partnerName)
                        : _LatestPolaroid(
                            drawing: latest,
                            partnerName: partnerName,
                          ),
                  ),
                ),
                const _BottomBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LatestPolaroid extends ConsumerWidget {
  const _LatestPolaroid({required this.drawing, required this.partnerName});

  final Drawing drawing;
  final String partnerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Toucher : ouvrir. Double-tap : ❤️ (encore une fois pour retirer).
    return DoubleTapReact(
      onTap: () => context.push('/detail/${drawing.id}'),
      onReact: () =>
          ref.read(drawingControllerProvider).toggleReaction(drawing, '❤️'),
      child: Hero(
        tag: 'drawing-${drawing.id}',
        child: Polaroid(
          drawing: drawing,
          tilt: -0.025,
          reaction: drawing.reaction,
          caption: drawing.message,
          subcaption:
              '$partnerName · ${TimeLabels.relative(drawing.createdAt)}',
          trailing: IconButton(
            tooltip: 'Répondre',
            visualDensity: VisualDensity.compact,
            color: AppColors.primary,
            onPressed: () => context.push('/canvas?replyTo=${drawing.id}'),
            icon: const Icon(Icons.reply_rounded),
          ),
        ),
      ),
    );
  }
}

/// Polaroïd vide, en attendant le premier dessin reçu.
class _EmptyPolaroid extends StatelessWidget {
  const _EmptyPolaroid({required this.partnerName});

  final String partnerName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.rotate(
        angle: -0.025,
        child: AspectRatio(
          aspectRatio: 0.78,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F3A1F2A),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    color: const Color(0xFFFBF6F2),
                    alignment: Alignment.center,
                    child: const Text('🌻', style: TextStyle(fontSize: 56)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Envoie le premier dessin à $partnerName',
                  textAlign: TextAlign.center,
                  style: AppTheme.handStyle(context, size: 24),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Barre du bas : historique · grand bouton dessiner · réglages.
class _BottomBar extends StatelessWidget {
  const _BottomBar();

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface
        .withValues(alpha: 0.55);
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 4, 40, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: 'Nos dessins',
            iconSize: 28,
            color: muted,
            onPressed: () => context.push('/history'),
            icon: const Icon(Icons.photo_library_outlined),
          ),
          _DrawButton(onPressed: () => context.push('/canvas')),
          IconButton(
            tooltip: 'Réglages',
            iconSize: 28,
            color: muted,
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
    );
  }
}

class _DrawButton extends StatelessWidget {
  const _DrawButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Dessiner',
      child: Material(
        color: AppColors.primary,
        shape: const CircleBorder(),
        elevation: 6,
        shadowColor: AppColors.primary.withValues(alpha: 0.5),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: const SizedBox(
            width: 72,
            height: 72,
            child: Icon(Icons.brush_rounded, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }
}
