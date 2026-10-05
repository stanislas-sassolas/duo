import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/time_labels.dart';
import '../../models/drawing.dart';
import '../../providers/auth_providers.dart';
import '../../providers/couple_providers.dart';
import '../../providers/drawing_providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/polaroid.dart';

enum HistoryFilter { all, sent, received }

/// « Nos dessins » : un mur de polaroïds classés par jour.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key, this.filter = HistoryFilter.all});

  final HistoryFilter filter;

  static HistoryFilter filterFromQuery(String? value) {
    return switch (value) {
      'sent' => HistoryFilter.sent,
      'received' => HistoryFilter.received,
      _ => HistoryFilter.all,
    };
  }

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late HistoryFilter _filter = widget.filter;

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider);
    final partnerName =
        ref.watch(partnerProvider).valueOrNull?.displayName ?? 'Ton amour';
    final history = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nos dessins')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
            child: SegmentedButton<HistoryFilter>(
              showSelectedIcon: false,
              segments: [
                const ButtonSegment(
                  value: HistoryFilter.all,
                  label: Text('Tous'),
                ),
                ButtonSegment(
                  value: HistoryFilter.received,
                  label: Text('De $partnerName'),
                ),
                const ButtonSegment(
                  value: HistoryFilter.sent,
                  label: Text('De moi'),
                ),
              ],
              selected: {_filter},
              onSelectionChanged: (value) =>
                  setState(() => _filter = value.first),
            ),
          ),
          Expanded(
            child: history.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const EmptyState(
                emoji: '😕',
                title: 'Impossible de charger',
              ),
              data: (all) {
                final drawings = all.where((d) {
                  return switch (_filter) {
                    HistoryFilter.sent => d.senderId == uid,
                    HistoryFilter.received => d.receiverId == uid,
                    HistoryFilter.all => true,
                  };
                }).toList();

                if (drawings.isEmpty) {
                  return const EmptyState(
                    emoji: '🐹',
                    title: 'Pithed attend ton premier dessin',
                  );
                }
                return _PolaroidWall(
                  drawings: drawings,
                  myUid: uid,
                  partnerName: partnerName,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PolaroidWall extends StatelessWidget {
  const _PolaroidWall({
    required this.drawings,
    required this.myUid,
    required this.partnerName,
  });

  final List<Drawing> drawings;
  final String? myUid;
  final String partnerName;

  @override
  Widget build(BuildContext context) {
    // Regroupe par jour (les dessins arrivent du plus récent au plus ancien).
    final groups = <String, List<Drawing>>{};
    for (final drawing in drawings) {
      final date = drawing.createdAt ?? DateTime.now();
      groups.putIfAbsent(TimeLabels.day(date), () => []).add(drawing);
    }

    return CustomScrollView(
      slivers: [
        for (final entry in groups.entries) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                entry.key,
                style: AppTheme.serifStyle(context, size: 18),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid.builder(
              // 2 colonnes sur téléphone, davantage sur tablette.
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 240,
                mainAxisSpacing: 18,
                crossAxisSpacing: 16,
                childAspectRatio: 0.66,
              ),
              itemCount: entry.value.length,
              itemBuilder: (context, index) {
                final drawing = entry.value[index];
                final author = drawing.senderId == myUid ? 'Moi' : partnerName;
                final time = drawing.createdAt == null
                    ? ''
                    : ' · ${DateFormat.Hm('fr').format(drawing.createdAt!)}';
                return GestureDetector(
                  onTap: () => context.push('/detail/${drawing.id}'),
                  child: Hero(
                    tag: 'drawing-${drawing.id}',
                    child: Polaroid(
                      drawing: drawing,
                      compact: true,
                      // Légère inclinaison alternée, comme posés sur un mur.
                      tilt: index.isEven ? -0.018 : 0.014,
                      caption: drawing.message,
                      subcaption: '$author$time',
                      reaction: drawing.reaction,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}
