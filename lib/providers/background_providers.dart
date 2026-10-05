import 'dart:io';
import 'dart:math';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../core/constants/app_constants.dart';
import 'service_providers.dart';

/// Illustrations de Paris dessinées pour Duo (tools/generate_art.py).
class ParisBackgrounds {
  ParisBackgrounds._();

  static const List<String> everyday = [
    'assets/backgrounds/eiffel.png',
    'assets/backgrounds/boulangerie.png',
    'assets/backgrounds/toits_nuit.png',
    'assets/backgrounds/seine.png',
    'assets/backgrounds/louvre.png',
  ];

  static const List<String> christmas = [
    'assets/backgrounds/noel_eiffel.png',
    'assets/backgrounds/noel_boulangerie.png',
    'assets/backgrounds/noel_toits.png',
  ];

  /// Du 1er décembre au 6 janvier : Paris sous la neige.
  static bool isChristmasSeason(DateTime now) =>
      now.month == 12 || (now.month == 1 && now.day <= 6);
}

/// Mes propres images de fond (chemins de fichiers copiés dans l'app).
final customBackgroundsProvider =
    StateNotifierProvider<CustomBackgroundsNotifier, List<String>>((ref) {
  return CustomBackgroundsNotifier(ref);
});

class CustomBackgroundsNotifier extends StateNotifier<List<String>> {
  CustomBackgroundsNotifier(this._ref)
      : super(
          (_ref
                      .read(sharedPreferencesProvider)
                      .getStringList(AppConstants.prefCustomBackgrounds) ??
                  const [])
              .where((path) => File(path).existsSync())
              .toList(),
        );

  final Ref _ref;

  /// Choisit des images dans la galerie et les copie dans l'app (elles
  /// restent disponibles même si elles sont supprimées de la galerie).
  Future<int> addFromGallery() async {
    final picked = await ImagePicker().pickMultiImage(
      maxWidth: 1600,
      imageQuality: 88,
    );
    if (picked.isEmpty) return 0;
    final dir = Directory(
      '${(await getApplicationSupportDirectory()).path}/backgrounds',
    );
    await dir.create(recursive: true);
    final added = <String>[];
    for (final file in picked) {
      final ext = file.path.split('.').last.toLowerCase();
      final target =
          '${dir.path}/${DateTime.now().microsecondsSinceEpoch}.${ext.length <= 4 ? ext : 'jpg'}';
      await File(file.path).copy(target);
      added.add(target);
    }
    await _save([...state, ...added]);
    return added.length;
  }

  Future<void> remove(String path) async {
    try {
      await File(path).delete();
    } catch (_) {}
    await _save(state.where((p) => p != path).toList());
  }

  Future<void> _save(List<String> paths) async {
    state = paths;
    await _ref
        .read(sharedPreferencesProvider)
        .setStringList(AppConstants.prefCustomBackgrounds, paths);
  }
}

/// Le fond de l'accueil, tiré au sort **une fois par ouverture de l'app** :
/// illustrations de Paris (sous la neige à Noël) + mes propres images.
final homeBackgroundProvider = Provider<ImageProvider>((ref) {
  final custom = ref.read(customBackgroundsProvider);
  final now = DateTime.now();
  final paris = ParisBackgrounds.isChristmasSeason(now)
      ? ParisBackgrounds.christmas
      : [...ParisBackgrounds.everyday, ...ParisBackgrounds.christmas];
  final pool = <ImageProvider>[
    for (final asset in paris) AssetImage(asset),
    for (final path in custom) FileImage(File(path)),
  ];
  return pool[Random().nextInt(pool.length)];
});
