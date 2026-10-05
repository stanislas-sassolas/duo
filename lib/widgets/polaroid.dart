import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/drawing.dart';
import 'drawing_canvas.dart';

/// Un dessin présenté comme une photo polaroïd : cadre blanc, légère ombre,
/// petit mot écrit à la main dans la marge du bas.
///
/// Utilisé sur l'accueil (grand, légèrement incliné), dans l'historique
/// (petit) et dans le détail.
class Polaroid extends StatelessWidget {
  const Polaroid({
    super.key,
    required this.drawing,
    this.caption,
    this.subcaption,
    this.tilt = 0,
    this.compact = false,
    this.progress = 1,
    this.repaint,
    this.trailing,
    this.reaction,
  });

  final Drawing drawing;

  /// Petit mot (écriture manuscrite).
  final String? caption;

  /// Ligne discrète sous le petit mot (« Alex · il y a 5 min »).
  final String? subcaption;

  /// Inclinaison en radians (ex. -0.02) pour un effet « posé sur la table ».
  final double tilt;

  /// Version miniature pour les grilles.
  final bool compact;

  /// Animation de rejeu (voir [DrawingPreview]).
  final double progress;
  final Listenable? repaint;

  /// Petit bouton optionnel à droite de la légende (ex. répondre).
  final Widget? trailing;

  /// Réaction du destinataire (« ❤️ »), en pastille sur le coin du cadre.
  final String? reaction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = compact ? 8.0 : 14.0;
        final bottomPad = compact ? 6.0 : 10.0;
        // Place réservée à la légende sous le dessin.
        final captionSpace = compact ? 40.0 : 76.0;
        final ratio = drawing.aspectRatio;

        // Le dessin est aussi grand que possible sans dépasser l'espace.
        var imageWidth = constraints.maxWidth - 2 * pad;
        if (constraints.hasBoundedHeight) {
          final maxImageHeight =
              constraints.maxHeight - pad - bottomPad - captionSpace;
          if (imageWidth / ratio > maxImageHeight) {
            imageWidth = maxImageHeight * ratio;
          }
        }
        if (imageWidth < 0) imageWidth = 0;

        var frame = _frame(context, pad, bottomPad, imageWidth);
        if (reaction != null && reaction!.isNotEmpty) {
          frame = Stack(
            clipBehavior: Clip.none,
            children: [
              frame,
              Positioned(
                top: compact ? -8 : -12,
                right: compact ? -8 : -12,
                child: _ReactionBadge(emoji: reaction!, small: compact),
              ),
            ],
          );
        }
        return Center(
          child: tilt == 0 ? frame : Transform.rotate(angle: tilt, child: frame),
        );
      },
    );
  }

  Widget _frame(
    BuildContext context,
    double pad,
    double bottomPad,
    double imageWidth,
  ) {
    final hasCaption = caption != null && caption!.trim().isNotEmpty;
    return Container(
      width: imageWidth + 2 * pad,
      padding: EdgeInsets.fromLTRB(pad, pad, pad, bottomPad),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F3A1F2A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
          BoxShadow(
            color: Color(0x0F3A1F2A),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: imageWidth,
            height: imageWidth / drawing.aspectRatio,
            child: DrawingPreview(
              strokes: drawing.strokes,
              stickers: drawing.stickers,
              aspectRatio: drawing.aspectRatio,
              progress: progress,
              repaint: repaint,
              bordered: false,
              // Papier légèrement crème : le cadre blanc ressort.
              background: const Color(0xFFFAF6F1),
            ),
          ),
          SizedBox(height: compact ? 4 : 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasCaption)
                      Text(
                        caption!.trim(),
                        maxLines: compact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.handStyle(
                          context,
                          size: compact ? 18 : 28,
                        ),
                      ),
                    if (subcaption != null)
                      Text(
                        subcaption!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 10.5 : 12.5,
                          color: const Color(0xFF8B8290),
                          letterSpacing: 0.2,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ],
      ),
    );
  }
}

class _ReactionBadge extends StatelessWidget {
  const _ReactionBadge({required this.emoji, required this.small});

  final String emoji;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final size = small ? 28.0 : 40.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x263A1F2A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Text(emoji, style: TextStyle(fontSize: small ? 15 : 21)),
    );
  }
}
