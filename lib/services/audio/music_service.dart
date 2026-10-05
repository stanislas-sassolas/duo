import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Petite boîte à musique en boucle pendant qu'on dessine (valse originale,
/// voir `tools/generate_sounds.py`). Coupée par défaut, volume doux.
class MusicService {
  MusicService() {
    _player.setReleaseMode(ReleaseMode.loop);
  }

  static const double _volume = 0.3;

  final AudioPlayer _player = AudioPlayer(playerId: 'duo-music');
  bool _playing = false;

  Future<void> start() async {
    if (_playing) return;
    _playing = true;
    try {
      await _player.play(AssetSource('sounds/music_box.wav'), volume: _volume);
    } catch (e) {
      _playing = false;
      debugPrint('Musique non jouée : $e');
    }
  }

  Future<void> pause() async {
    if (!_playing) return;
    await _player.pause();
  }

  Future<void> resume() async {
    if (!_playing) return;
    await _player.resume();
  }

  Future<void> stop() async {
    _playing = false;
    await _player.stop();
  }
}
