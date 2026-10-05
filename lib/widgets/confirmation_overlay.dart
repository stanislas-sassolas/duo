import 'dart:math';

import 'package:flutter/material.dart';

import '../core/constants/personal.dart';

/// Petite animation de confirmation « Envoyé à … ❤️ », affichée en surimpression
/// puis auto-dismissée.
class ConfirmationOverlay {
  ConfirmationOverlay._();

  static Future<void> show(BuildContext context, String message) async {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => _ConfirmationWidget(message: message),
    );
    overlay.insert(entry);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    entry.remove();
  }
}

class _ConfirmationWidget extends StatefulWidget {
  const _ConfirmationWidget({required this.message});
  final String message;

  @override
  State<_ConfirmationWidget> createState() => _ConfirmationWidgetState();
}

class _ConfirmationWidgetState extends State<_ConfirmationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  )..forward();

  /// ❤️, ☀️, ⭐ ou 🌻, au hasard.
  final String _emoji =
      Personal.sentEmojis[Random().nextInt(Personal.sentEmojis.length)];

  late final Animation<double> _scale = CurvedAnimation(
    parent: _controller,
    curve: Curves.elasticOut,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: ScaleTransition(
            scale: _scale,
            // Material : donne au texte le style du thème (sans lui, Flutter
            // affiche le texte souligné en jaune, en police de débogage).
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
