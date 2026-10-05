import 'dart:math';

import 'package:flutter/material.dart';

import '../core/constants/personal.dart';
import '../core/theme/app_theme.dart';
import '../models/app_user.dart';

/// En-tête de l'accueil : « Sam ❤️ Alex 🌻 ».
///
/// Les deux prénoms s'affichent toujours dans le même ordre sur les deux
/// téléphones ([first] = créateur de l'espace). Un surnom fait d'emojis se
/// colle au prénom ; un surnom en toutes lettres n'est pas affiché ici.
///
/// Easter egg : un appui long sur le ❤️ fait s'envoler un petit souvenir.
class CoupleHeader extends StatefulWidget {
  const CoupleHeader({super.key, required this.first, required this.second});

  final AppUser? first;
  final AppUser? second;

  @override
  State<CoupleHeader> createState() => _CoupleHeaderState();
}

class _CoupleHeaderState extends State<CoupleHeader>
    with SingleTickerProviderStateMixin {
  final _random = Random();
  late final AnimationController _egg = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  String _eggEmoji = Personal.easterEggs.first;

  @override
  void dispose() {
    _egg.dispose();
    super.dispose();
  }

  void _releaseEgg() {
    setState(() {
      _eggEmoji =
          Personal.easterEggs[_random.nextInt(Personal.easterEggs.length)];
    });
    _egg.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final nameStyle = AppTheme.serifStyle(context, size: 26);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_nameLine(widget.first), maxLines: 1, style: nameStyle),
              GestureDetector(
                onLongPress: _releaseEgg,
                child: SizedBox(
                  width: 44,
                  height: 32,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      const Text('❤️', style: TextStyle(fontSize: 18)),
                      AnimatedBuilder(
                        animation: _egg,
                        builder: (context, _) {
                          if (!_egg.isAnimating) {
                            return const SizedBox.shrink();
                          }
                          final t = Curves.easeOut.transform(_egg.value);
                          return Positioned(
                            top: -48 * t,
                            child: Opacity(
                              opacity: (1 - _egg.value).clamp(0.0, 1.0),
                              child: Text(
                                _eggEmoji,
                                style: TextStyle(fontSize: 18 + 10 * t),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Text(_nameLine(widget.second), maxLines: 1, style: nameStyle),
            ],
          ),
        ),
      ],
    );
  }

  /// « Alex 🌻 » (surnom emoji collé), « Sam » sinon.
  String _nameLine(AppUser? user) =>
      user == null ? '…' : displayNameWithEmojis(user);
}

/// Nom affichable d'un utilisateur avec son surnom emoji éventuel
/// (« Alex 🌻 », « Sam »). Utilisé pour « Envoyer à … ».
String displayNameWithEmojis(AppUser? user, {String fallback = 'ton amour'}) {
  if (user == null) return fallback;
  final signature = user.signatureText;
  return Personal.isEmojiOnly(signature)
      ? '${user.displayName} $signature'
      : user.displayName;
}
