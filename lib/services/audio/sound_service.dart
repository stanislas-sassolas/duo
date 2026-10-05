import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Sons très légers des moments clés, créés pour l'app (clin d'œil à
/// Miraculous, sans reprendre la musique de la série) :
/// - envoi : un petit « fwip » de yoyo ;
/// - réception : un tintement magique.
///
/// Les fichiers sont générés par `tools/generate_sounds.py`. Ils se mêlent à
/// la musique du téléphone sans l'interrompre.
class SoundService {
  SoundService() {
    for (final player in [_sent, _received]) {
      player.setReleaseMode(ReleaseMode.stop);
      player.setVolume(_volume);
    }
  }

  static const double _volume = 0.45;

  final AudioPlayer _sent = AudioPlayer(playerId: 'duo-sent');
  final AudioPlayer _received = AudioPlayer(playerId: 'duo-received');

  bool enabled = true;

  /// À appeler une fois au démarrage : ne coupe jamais la musique du
  /// téléphone (Spotify, etc.).
  static Future<void> configureAudioSession() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
            .build(),
      );
    } catch (e) {
      debugPrint('Contexte audio non configuré : $e');
    }
  }

  Future<void> playSent() async {
    if (!enabled) return;
    await HapticFeedback.lightImpact();
    await _play(_sent, 'sounds/send_yoyo.wav');
  }

  Future<void> playReceived() async {
    if (!enabled) return;
    await HapticFeedback.selectionClick();
    await _play(_received, 'sounds/receive_sparkle.wav');
  }

  Future<void> _play(AudioPlayer player, String asset) async {
    try {
      await player.stop();
      await player.play(AssetSource(asset), volume: _volume);
    } catch (e) {
      debugPrint('Son non joué : $e');
    }
  }
}
