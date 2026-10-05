import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/drawing.dart';
import '../../providers/auth_providers.dart';
import '../../core/utils/result.dart';
import '../../providers/couple_providers.dart';
import '../../providers/drawing_providers.dart';
import '../../services/export/drawing_export_service.dart';
import '../../services/notifications/drawing_notifier.dart';
import '../../widgets/couple_header.dart';
import '../../widgets/polaroid.dart';
import '../../widgets/double_tap_react.dart';
import '../../widgets/empty_state.dart';

/// Détail d'un dessin : grand aperçu + rejouer stroke par stroke + répondre.
class DrawingDetailScreen extends ConsumerStatefulWidget {
  const DrawingDetailScreen({super.key, required this.drawingId});

  final String drawingId;

  @override
  ConsumerState<DrawingDetailScreen> createState() =>
      _DrawingDetailScreenState();
}

class _DrawingDetailScreenState extends ConsumerState<DrawingDetailScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _replay = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
    value: 1, // dessin complet par défaut
  );

  bool _viewedMarked = false;

  @override
  void initState() {
    super.initState();
    // Supprime les notifs premier plan tant que ce dessin est ouvert.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(isViewingReceivedProvider.notifier).state = true;
    });
  }

  @override
  void dispose() {
    _replay.dispose();
    // Le provider est autoDispose-safe : on remet à false si encore monté.
    Future.microtask(() {
      ref.read(isViewingReceivedProvider.notifier).state = false;
    });
    super.dispose();
  }

  void _maybeMarkViewed(Drawing drawing) {
    if (_viewedMarked) return;
    final uid = ref.read(currentUidProvider);
    if (drawing.receiverId == uid && !drawing.isViewed) {
      _viewedMarked = true;
      ref.read(drawingControllerProvider).markViewed(drawing);
      DrawingNotifier.cancelFor(drawing.id);
    }
  }

  Future<void> _saveToGallery(Drawing drawing) async {
    final isMine = drawing.senderId == ref.read(currentUidProvider);
    final partnerName =
        ref.read(partnerProvider).valueOrNull?.displayName ?? 'Ton amour';
    final author = isMine
        ? (ref.read(currentUserProvider).valueOrNull?.displayName ?? 'Moi')
        : partnerName;
    final date = drawing.createdAt;
    final result = await DrawingExportService.saveToGallery(
      drawing,
      subcaption: date == null
          ? author
          : '$author · ${DateFormat('d MMMM yyyy', 'fr').format(date)}',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isSuccess
              ? 'Enregistré dans ta galerie (album Duo) 📷'
              : (result as Failure).message,
        ),
      ),
    );
  }

  void _playReplay() {
    _replay
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(drawingByIdProvider(widget.drawingId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dessin'),
        actions: [
          IconButton(
            tooltip: 'Enregistrer dans la galerie',
            onPressed: async.valueOrNull == null
                ? null
                : () => _saveToGallery(async.valueOrNull!),
            icon: const Icon(Icons.download_rounded),
          ),
          IconButton(
            tooltip: 'Rejouer',
            onPressed: _playReplay,
            icon: const Icon(Icons.play_circle_outline_rounded),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const EmptyState(emoji: '😕', title: 'Dessin introuvable'),
        data: (drawing) {
          if (drawing == null) {
            return const EmptyState(emoji: '😕', title: 'Dessin introuvable');
          }
          _maybeMarkViewed(drawing);
          return _DetailBody(drawing: drawing, replay: _replay);
        },
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.drawing, required this.replay});

  final Drawing drawing;
  final Animation<double> replay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMine = drawing.senderId == ref.watch(currentUidProvider);
    final partner = ref.watch(partnerProvider).valueOrNull;
    final partnerName = partner?.displayName ?? 'Ton amour';
    final date = drawing.createdAt;
    final dateLabel =
        date != null ? DateFormat('d MMMM · HH:mm', 'fr').format(date) : '';
    // « Alex · 27 septembre · 10:57 » ou « Pour Alex 🌻 · … ».
    final author =
        isMine ? 'Pour ${displayNameWithEmojis(partner)}' : partnerName;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 20),
        child: Column(
          children: [
            Expanded(
              child: DoubleTapReact(
                enabled: !isMine,
                onReact: () => ref
                    .read(drawingControllerProvider)
                    .toggleReaction(drawing, '❤️'),
                child: Hero(
                  tag: 'drawing-${drawing.id}',
                  child: AnimatedBuilder(
                    animation: replay,
                    builder: (context, _) => Polaroid(
                      drawing: drawing,
                      caption: drawing.message,
                      subcaption: dateLabel.isEmpty
                          ? author
                          : '$author · $dateLabel',
                      progress: replay.value,
                      repaint: replay,
                      reaction: drawing.reaction,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Réagir à un dessin reçu (le même emoji une 2e fois le retire).
            if (!isMine) ...[
              _ReactionBar(
                selected: drawing.reaction,
                onSelected: (emoji) => ref
                    .read(drawingControllerProvider)
                    .toggleReaction(drawing, emoji),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Conversation visuelle : remonter au dessin d'origine.
                if (drawing.replyToDrawingId != null) ...[
                  TextButton.icon(
                    onPressed: () =>
                        context.push('/detail/${drawing.replyToDrawingId}'),
                    icon: const Icon(Icons.history_rounded, size: 18),
                    label: const Text("Dessin d'origine"),
                  ),
                  const SizedBox(width: 8),
                ],
                FilledButton.icon(
                  onPressed: () =>
                      context.push('/canvas?replyTo=${drawing.id}'),
                  icon: const Icon(Icons.reply_rounded, size: 18),
                  label: const Text('Répondre'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Petites réactions possibles à un dessin reçu.
class _ReactionBar extends StatelessWidget {
  const _ReactionBar({required this.selected, required this.onSelected});

  static const List<String> emojis = ['❤️', '🐞', '🥹', '😂', '🔥'];

  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final emoji in emojis)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => onSelected(emoji),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: emoji == selected
                      ? primary.withValues(alpha: 0.14)
                      : Colors.transparent,
                  border: Border.all(
                    color: emoji == selected ? primary : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
          ),
      ],
    );
  }
}
