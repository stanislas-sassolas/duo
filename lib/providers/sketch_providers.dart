import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/personal.dart';
import '../models/stroke.dart';
import 'auth_providers.dart';

/// Un dessin tout prêt (généré par tools/generate_sketches.py), posé sur la
/// feuille comme des traits ordinaires.
class SecretSketch {
  const SecretSketch({
    required this.id,
    required this.name,
    required this.emoji,
    required this.strokes,
  });

  final String id;
  final String name;
  final String emoji;
  final List<Stroke> strokes;

  factory SecretSketch.fromJson(Map<String, dynamic> json) => SecretSketch(
        id: json['id'] as String,
        name: json['name'] as String,
        emoji: json['emoji'] as String,
        strokes: [
          for (final raw in json['strokes'] as List<dynamic>)
            Stroke.fromJson(raw as Map<String, dynamic>),
        ],
      );
}

/// Les dessins tout prêts, seulement pour les prénoms de
/// [Personal.secretSketchesFor] (liste vide pour les autres).
final secretSketchesProvider = FutureProvider<List<SecretSketch>>((ref) async {
  final name = ref.watch(currentUserProvider).valueOrNull?.displayName;
  if (name == null || !Personal.seesSecretSketches(name)) return const [];
  final raw = await rootBundle.loadString('assets/sketches/sketches.json');
  return [
    for (final item in jsonDecode(raw) as List<dynamic>)
      SecretSketch.fromJson(item as Map<String, dynamic>),
  ];
});
