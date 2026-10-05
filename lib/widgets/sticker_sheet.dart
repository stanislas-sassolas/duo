import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sketch_providers.dart';
import '../providers/sticker_providers.dart';
import 'stroke_painter.dart';

/// Ce qui a été choisi dans la feuille : un seul champ est renseigné.
class StickerChoice {
  const StickerChoice({this.stickerId, this.emoji, this.sketch});

  final String? stickerId;
  final String? emoji;
  final SecretSketch? sketch;
}

/// Choix d'un sticker à poser : tampons emoji, puis nos stickers importés
/// (et, pour Sam seulement, ses dessins tout prêts).
class StickerSheet extends ConsumerStatefulWidget {
  const StickerSheet({super.key});

  static Future<StickerChoice?> show(BuildContext context) {
    return showModalBottomSheet<StickerChoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.72,
        child: StickerSheet(),
      ),
    );
  }

  @override
  ConsumerState<StickerSheet> createState() => _StickerSheetState();
}

class _StickerSheetState extends ConsumerState<StickerSheet> {
  bool _importing = false;

  Future<void> _import() async {
    setState(() => _importing = true);
    try {
      final added =
          await ref.read(stickerControllerProvider).importFromFiles();
      if (!mounted) return;
      if (added > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$added sticker${added > 1 ? 's' : ''} ajouté${added > 1 ? 's' : ''} 🐞',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Import impossible.')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _confirmHide(String stickerId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer ce sticker ?'),
        content: const Text(
          'Il ne sera plus proposé, mais reste sur vos anciens dessins.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (ok ?? false) await ref.read(stickerControllerProvider).hide(stickerId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stickers = (ref.watch(coupleStickersProvider).valueOrNull ?? const [])
        .where((s) => !s.hidden)
        .toList();
    final sketches = ref.watch(secretSketchesProvider).valueOrNull ?? const [];

    return CustomScrollView(
      slivers: [
        if (sketches.isNotEmpty) ..._sketchSlivers(context, sketches),
        _title(context, 'Tampons'),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid.count(
            crossAxisCount: 8,
            children: [
              for (final emoji in emojiStamps)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () =>
                      Navigator.pop(context, StickerChoice(emoji: emoji)),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 28)),
                  ),
                ),
            ],
          ),
        ),
        _title(context, 'Nos stickers'),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Pour vos stickers WhatsApp : « Importer », puis ouvre le '
              'dossier Android › media › com.whatsapp › WhatsApp › Media › '
              'WhatsApp Stickers. Pour en prendre plusieurs : appui long sur '
              'le premier, puis touche les autres (ou ⋮ › Tout sélectionner). '
              'Appui long ici sur un sticker pour le retirer.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          sliver: SliverGrid.count(
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _importing ? null : _import,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Center(
                    child: _importing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(height: 4),
                              Text('Importer', style: theme.textTheme.labelSmall),
                            ],
                          ),
                  ),
                ),
              ),
              for (final sticker in stickers)
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.pop(
                    context,
                    StickerChoice(stickerId: sticker.id),
                  ),
                  onLongPress: () => _confirmHide(sticker.id),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Image.memory(sticker.png, fit: BoxFit.contain),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Les dessins tout prêts (visibles seulement chez Sam).
  List<Widget> _sketchSlivers(
    BuildContext context,
    List<SecretSketch> sketches,
  ) {
    final theme = Theme.of(context);
    return [
      _title(context, 'Mes dessins 🤫'),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        sliver: SliverToBoxAdapter(
          child: Text(
            'Visibles seulement chez toi. Le dessin se pose sur la feuille, '
            'tu peux ensuite le compléter, le colorier ou ajouter un mot.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        sliver: SliverGrid.count(
          crossAxisCount: 4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 3 / 4,
          children: [
            for (final sketch in sketches)
              Tooltip(
                message: sketch.name,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () =>
                      Navigator.pop(context, StickerChoice(sketch: sketch)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CustomPaint(
                      painter: StrokePainter(
                        strokes: sketch.strokes,
                        background: const Color(0xFFFAF6F1),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ];
  }

  Widget _title(BuildContext context, String text) => SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        sliver: SliverToBoxAdapter(
          child: Text(text, style: Theme.of(context).textTheme.titleMedium),
        ),
      );
}
