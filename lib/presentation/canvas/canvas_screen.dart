import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../models/enums.dart';
import '../../providers/couple_providers.dart';
import '../../providers/drawing_providers.dart';
import '../../providers/personal_providers.dart';
import '../../providers/service_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/sticker_providers.dart';
import '../../widgets/brush_size_selector.dart';
import '../../widgets/color_palette.dart';
import '../../widgets/color_picker_sheet.dart';
import '../../widgets/sticker_sheet.dart';
import '../../widgets/confirmation_overlay.dart';
import '../../widgets/couple_header.dart';
import '../../widgets/drawing_canvas.dart';
import '../../widgets/phrase_picker.dart';
import '../../widgets/primary_button.dart';
import 'drawing_controller.dart';

/// Écran de création : canvas + outils + envoi.
class CanvasScreen extends ConsumerStatefulWidget {
  const CanvasScreen({super.key, this.replyToDrawingId});

  /// Si fourni, le dessin envoyé sera une réponse au dessin ciblé.
  final String? replyToDrawingId;

  @override
  ConsumerState<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends ConsumerState<CanvasScreen>
    with WidgetsBindingObserver {
  final CanvasController _canvas = CanvasController();
  bool _sending = false;

  /// Petit mot choisi (optionnel), envoyé avec le dessin.
  String? _phrase;

  late final _music = ref.read(musicServiceProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Boîte à musique : seulement pendant qu'on dessine, si elle est activée.
    if (ref.read(settingsProvider).musicEnabled) _music.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _music.resume();
    } else if (state == AppLifecycleState.paused) {
      _music.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _music.stop();
    _canvas.dispose();
    super.dispose();
  }

  Future<void> _toggleMusic() async {
    final enabled = !ref.read(settingsProvider).musicEnabled;
    await ref.read(settingsProvider.notifier).setMusicEnabled(enabled);
    enabled ? await _music.start() : await _music.stop();
  }

  Future<void> _send() async {
    if (_canvas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dessine quelque chose d\'abord ✏️')),
      );
      return;
    }
    setState(() => _sending = true);

    final partnerName =
        ref.read(partnerProvider).valueOrNull?.displayName ?? 'ton amour';
    final result = await ref.read(drawingControllerProvider).send(
          strokes: _canvas.strokes,
          stickers: _canvas.stickers,
          message: _phrase,
          replyToDrawingId: widget.replyToDrawingId,
        );

    if (!mounted) return;
    setState(() => _sending = false);

    await result.when(
      success: (sentNow) async {
        await ref.read(soundServiceProvider).playSent();
        if (!mounted) return;
        final message = sentNow
            ? 'Envoyé à $partnerName'
            : 'En attente de réseau, il partira tout seul';
        await ConfirmationOverlay.show(context, message);
        if (mounted) context.pop();
      },
      failure: (message) async {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final partnerFull =
        displayNameWithEmojis(ref.watch(partnerProvider).valueOrNull);
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        title: Text(
          widget.replyToDrawingId != null ? 'Répondre' : 'Pour $partnerFull',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Stickers',
            onPressed: () async {
              final choice = await StickerSheet.show(context);
              if (choice == null) return;
              final sketch = choice.sketch;
              if (sketch != null) {
                _canvas.addStrokes(sketch.strokes);
              } else {
                _canvas.addSticker(
                  stickerId: choice.stickerId,
                  emoji: choice.emoji,
                );
              }
            },
            icon: const Icon(Icons.emoji_emotions_outlined),
          ),
          IconButton(
            tooltip: 'Musique',
            onPressed: _toggleMusic,
            icon: Icon(
              ref.watch(settingsProvider).musicEnabled
                  ? Icons.music_note_rounded
                  : Icons.music_off_outlined,
            ),
          ),
          AnimatedBuilder(
            animation: _canvas,
            builder: (context, _) => Row(
              children: [
                IconButton(
                  tooltip: 'Annuler',
                  onPressed: _canvas.canUndo ? _canvas.undo : null,
                  icon: const Icon(Icons.undo_rounded),
                ),
                IconButton(
                  tooltip: 'Rétablir',
                  onPressed: _canvas.canRedo ? _canvas.redo : null,
                  icon: const Icon(Icons.redo_rounded),
                ),
                IconButton(
                  tooltip: 'Tout effacer',
                  onPressed: _canvas.isEmpty ? null : _confirmClear,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            children: [
              Expanded(
                child: DrawingCanvas(
                  controller: _canvas,
                  elevated: true,
                  stickerImages:
                      ref.watch(stickerImagesProvider).valueOrNull ?? const {},
                ),
              ),
              const SizedBox(height: 16),
              _Tools(canvas: _canvas),
              const SizedBox(height: 14),
              PhrasePicker(
                phrases: ref.watch(myPhrasesProvider).valueOrNull ?? const [],
                selected: _phrase,
                onChanged: (phrase) => setState(() => _phrase = phrase),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Envoyer à $partnerFull',
                icon: Icons.send_rounded,
                loading: _sending,
                onPressed: _send,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tout effacer ?'),
        content: const Text('Le dessin en cours sera perdu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
    if (ok ?? false) _canvas.clear();
  }
}

class _Tools extends StatelessWidget {
  const _Tools({required this.canvas});
  final CanvasController canvas;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: canvas,
      builder: (context, _) {
        final isEraser = canvas.tool.name == 'eraser';
        // Tous les outils regroupés dans une seule carte discrète.
        return Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x123A1F2A),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              ColorPalette(
                colors: AppColors.palette,
                selected: canvas.color,
                onSelected: canvas.selectPen,
                onMore: () async {
                  final color = await ColorPickerSheet.show(context);
                  if (color != null) canvas.selectPen(color);
                },
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Rétrécit un peu sur les petits écrans plutôt que déborder.
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: BrushSizeSelector(
                        selected: canvas.size,
                        color: isEraser ? Colors.grey : canvas.color,
                        onSelected: canvas.selectSize,
                      ),
                    ),
                  ),
                  // Pinceaux (feutre, surligneur, néon) et gomme.
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final (tool, icon, label) in const [
                        (BrushTool.pen, Icons.brush_rounded, 'Feutre'),
                        (
                          BrushTool.highlighter,
                          Icons.border_color_rounded,
                          'Surligneur',
                        ),
                        (BrushTool.neon, Icons.auto_awesome_rounded, 'Néon'),
                        (
                          BrushTool.eraser,
                          Icons.auto_fix_normal_rounded,
                          'Gomme',
                        ),
                      ])
                        _ToolButton(
                          icon: icon,
                          tooltip: label,
                          selected: canvas.tool == tool,
                          onTap: () => tool == BrushTool.eraser
                              ? canvas.selectEraser()
                              : canvas.selectBrush(tool),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 40,
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: selected
                ? primary.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 21,
            color: selected ? primary : Theme.of(context).hintColor,
          ),
        ),
      ),
    );
  }
}
