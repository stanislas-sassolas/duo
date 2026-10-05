import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/background_providers.dart';

/// « Fonds d'écran » : les illustrations de Paris (toujours incluses) et mes
/// propres images, tirées au sort à chaque ouverture de l'app.
class BackgroundsScreen extends ConsumerStatefulWidget {
  const BackgroundsScreen({super.key});

  @override
  ConsumerState<BackgroundsScreen> createState() => _BackgroundsScreenState();
}

class _BackgroundsScreenState extends ConsumerState<BackgroundsScreen> {
  bool _adding = false;

  Future<void> _add() async {
    setState(() => _adding = true);
    try {
      final count =
          await ref.read(customBackgroundsProvider.notifier).addFromGallery();
      if (!mounted || count == 0) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$count image${count > 1 ? 's' : ''} ajoutée${count > 1 ? 's' : ''} 🖼️',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir la galerie.')),
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final custom = ref.watch(customBackgroundsProvider);
    final theme = Theme.of(context);
    final paris = [
      ...ParisBackgrounds.everyday,
      ...ParisBackgrounds.christmas,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Fonds d\'écran')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _adding ? null : _add,
        icon: _adding
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Ajouter mes images'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Un fond est tiré au sort à chaque ouverture de l\'app. '
                'Paris sous la neige s\'invite surtout en décembre ❄️',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.hintColor),
              ),
            ),
          ),
          if (custom.isNotEmpty) ...[
            _title(context, 'Mes images'),
            _grid([
              for (final path in custom)
                _Thumb(
                  image: FileImage(File(path)),
                  onRemove: () => ref
                      .read(customBackgroundsProvider.notifier)
                      .remove(path),
                ),
            ]),
          ],
          _title(context, 'Paris'),
          _grid([
            for (final asset in paris) _Thumb(image: AssetImage(asset)),
          ]),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }

  Widget _title(BuildContext context, String text) => SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        sliver: SliverToBoxAdapter(
          child: Text(text, style: Theme.of(context).textTheme.titleMedium),
        ),
      );

  Widget _grid(List<Widget> children) => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverGrid.count(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 9 / 16,
          children: children,
        ),
      );
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.image, this.onRemove});

  final ImageProvider image;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image(
            image: ResizeImage(image, width: 240),
            fit: BoxFit.cover,
          ),
        ),
        if (onRemove != null)
          Positioned(
            top: 4,
            right: 4,
            child: IconButton.filledTonal(
              visualDensity: VisualDensity.compact,
              tooltip: 'Retirer',
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ),
      ],
    );
  }
}
