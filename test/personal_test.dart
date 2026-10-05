import 'package:duo_draw/core/constants/personal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Personal', () {
    test('surnoms par défaut selon le prénom', () {
      expect(Personal.defaultSignatureFor('Alex'), '🌻');
      expect(Personal.defaultSignatureFor(' alex '), '🌻');
      expect(Personal.defaultSignatureFor('Quelqu\'un'), '');
    });

    test('les petits mots de Sam ne sont pas ceux d\'Alex', () {
      expect(Personal.defaultPhrasesFor('Sam'), contains('❤️ Bisous'));
      expect(Personal.defaultPhrasesFor('Sam'), hasLength(3));
      expect(Personal.defaultPhrasesFor('Alex'), isEmpty);
    });

    test('un surnom en emojis se colle au prénom, un surnom en lettres non', () {
      expect(Personal.isEmojiOnly('🌻'), isTrue);
      expect(Personal.isEmojiOnly('Mon cœur'), isFalse);
      expect(Personal.isEmojiOnly(''), isFalse);
    });
  });
}
