import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/resilient_stream.dart';
import '../core/utils/sticker_codec.dart';
import 'auth_providers.dart';
import 'couple_providers.dart';
import 'service_providers.dart';

/// Tampons emoji toujours disponibles (aucun import nécessaire).
const List<String> emojiStamps = [
  '🐞', '❤️', '🌻', '⭐', '🗼', '☀️', '🌙', '🥐',
  '🍫', '🥑', '🐹', '🌶️', '💋', '🌸', '✨', '🎄',
];

/// Un sticker importé, partagé par le couple.
///
/// Document : `couples/{coupleId}/stickers/{id}` → `{ data: <PNG base64>,
/// createdBy, createdAt, hidden }`. Un sticker « retiré » est seulement
/// masqué : les anciens dessins qui l'utilisent l'affichent toujours.
class CoupleSticker {
  const CoupleSticker({
    required this.id,
    required this.png,
    required this.hidden,
  });

  final String id;
  final Uint8List png;
  final bool hidden;
}

/// Tous les stickers du couple (y compris masqués), en temps réel.
final coupleStickersProvider = StreamProvider<List<CoupleSticker>>((ref) {
  final couple = ref.watch(coupleProvider).valueOrNull;
  if (couple == null) return Stream.value(const []);
  final refs = ref.watch(firestoreRefsProvider);
  return resilientSnapshots(
    () => refs
        .stickers(couple.id)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => [
            for (final doc in snap.docs)
              if (doc.data()['data'] is String)
                CoupleSticker(
                  id: doc.id,
                  png: base64Decode(doc.data()['data'] as String),
                  hidden: doc.data()['hidden'] == true,
                ),
          ],
        ),
  );
});

/// Images décodées des stickers (id → image), pour les dessiner.
final stickerImagesProvider = FutureProvider<Map<String, ui.Image>>((ref) async {
  final stickers = ref.watch(coupleStickersProvider).valueOrNull ?? const [];
  final images = <String, ui.Image>{};
  for (final sticker in stickers) {
    try {
      images[sticker.id] = await StickerCodec.decode(sticker.png);
    } catch (_) {}
  }
  return images;
});

final stickerControllerProvider =
    Provider<StickerController>((ref) => StickerController(ref));

class StickerController {
  StickerController(this._ref);
  final Ref _ref;

  /// Ouvre l'explorateur de fichiers (ex. le dossier des stickers WhatsApp)
  /// et ajoute les images choisies à nos stickers. Renvoie le nombre ajouté.
  Future<int> importFromFiles() async {
    final couple = _ref.read(coupleProvider).valueOrNull;
    final uid = _ref.read(currentUidProvider);
    if (couple == null || uid == null) return 0;

    // Explorateur de fichiers (et non la galerie) : le dossier des stickers
    // WhatsApp est masqué de la galerie, mais visible ici.
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['webp', 'png', 'jpg', 'jpeg', 'gif'],
    );
    var added = 0;
    for (final file in files) {
      try {
        final png = await StickerCodec.prepare(await file.xFile.readAsBytes());
        await _ref.read(firestoreRefsProvider).stickers(couple.id).add({
          'data': base64Encode(png),
          'createdBy': uid,
          'createdAt': FieldValue.serverTimestamp(),
          'hidden': false,
        });
        added++;
      } catch (_) {
        // Image illisible : on passe à la suivante.
      }
    }
    return added;
  }

  /// Retire un sticker de la liste (il reste visible sur les anciens dessins).
  Future<void> hide(String stickerId) async {
    final couple = _ref.read(coupleProvider).valueOrNull;
    if (couple == null) return;
    await _ref
        .read(firestoreRefsProvider)
        .stickers(couple.id)
        .doc(stickerId)
        .update({'hidden': true});
  }
}
