import 'dart:math';

/// Génère et valide les codes d'invitation type `LOVE-7K42QX`.
///
/// 6 caractères = ~1 milliard de combinaisons : impossible à deviner par
/// essais successifs. Les anciens codes à 4 caractères restent acceptés.
///
/// Alphabet sans caractères ambigus (pas de 0/O, 1/I) pour faciliter la saisie
/// et la lecture à voix haute par le couple.
class InviteCode {
  InviteCode._();

  static const String _prefix = 'LOVE';
  static const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const int _bodyLength = 6;
  static const int _legacyBodyLength = 4;

  static final RegExp _pattern = RegExp(
    '^$_prefix-([$_alphabet]{$_bodyLength}|[$_alphabet]{$_legacyBodyLength})\$',
  );

  /// Génère un nouveau code aléatoire, ex. `LOVE-7K42QX`.
  static String generate([Random? random]) {
    final rng = random ?? Random.secure();
    final body = List.generate(
      _bodyLength,
      (_) => _alphabet[rng.nextInt(_alphabet.length)],
    ).join();
    return '$_prefix-$body';
  }

  /// Normalise une saisie utilisateur : trim, majuscules, ajout du tiret.
  ///
  /// Accepte `love7k42`, `LOVE 7K42`, `love-7k42` → `LOVE-7K42`.
  static String normalize(String raw) {
    var value = raw.trim().toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    if (value.startsWith(_prefix)) {
      value = value.substring(_prefix.length);
    }
    return '$_prefix-$value';
  }

  static bool isValid(String code) => _pattern.hasMatch(code);
}
