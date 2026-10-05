import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Double-tap pour réagir : un grand ❤️ éclot au centre puis s'efface.
///
/// Un simple toucher reste disponible ([onTap], ex. ouvrir le dessin).
class DoubleTapReact extends StatefulWidget {
  const DoubleTapReact({
    super.key,
    required this.child,
    required this.onReact,
    this.onTap,
    this.enabled = true,
    this.emoji = '❤️',
  });

  final Widget child;
  final VoidCallback onReact;
  final VoidCallback? onTap;

  /// Faux pour ses propres dessins (on ne réagit qu'aux dessins reçus).
  final bool enabled;
  final String emoji;

  @override
  State<DoubleTapReact> createState() => _DoubleTapReactState();
}

class _DoubleTapReactState extends State<DoubleTapReact>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  void _react() {
    HapticFeedback.lightImpact();
    _burst.forward(from: 0);
    widget.onReact();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTap: widget.enabled ? _react : null,
      child: Stack(
        alignment: Alignment.center,
        children: [
          widget.child,
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _burst,
              builder: (context, _) {
                if (!_burst.isAnimating) return const SizedBox.shrink();
                final t = _burst.value;
                final scale = Curves.elasticOut.transform((t * 1.6).clamp(0, 1));
                final opacity = t < 0.6 ? 1.0 : (1 - (t - 0.6) / 0.4);
                return Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.4 + scale * 0.8,
                    child: Text(
                      widget.emoji,
                      style: const TextStyle(fontSize: 96),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
