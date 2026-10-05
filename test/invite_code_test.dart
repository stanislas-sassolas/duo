import 'package:duo_draw/core/utils/invite_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InviteCode', () {
    test('génère un code au format LOVE-XXXXXX', () {
      for (var i = 0; i < 200; i++) {
        final code = InviteCode.generate();
        expect(InviteCode.isValid(code), isTrue, reason: code);
        expect(code.startsWith('LOVE-'), isTrue);
        expect(code.length, 11);
      }
    });

    test('n\'utilise pas de caractères ambigus (0/O/1/I)', () {
      for (var i = 0; i < 200; i++) {
        final body = InviteCode.generate().substring(5);
        expect(body.contains('0'), isFalse);
        expect(body.contains('O'), isFalse);
        expect(body.contains('1'), isFalse);
        expect(body.contains('I'), isFalse);
      }
    });

    test('normalise diverses saisies utilisateur', () {
      expect(InviteCode.normalize('love7k42'), 'LOVE-7K42');
      expect(InviteCode.normalize('  LOVE 7K42 '), 'LOVE-7K42');
      expect(InviteCode.normalize('love-7k42'), 'LOVE-7K42');
      expect(InviteCode.normalize('7K42'), 'LOVE-7K42');
    });

    test('valide et rejette correctement', () {
      expect(InviteCode.isValid('LOVE-7K42'), isTrue);
      expect(InviteCode.isValid('LOVE-701I'), isFalse); // 0 et I interdits
      expect(InviteCode.isValid('HATE-7K42'), isFalse);
      expect(InviteCode.isValid('LOVE-7K4'), isFalse);
      expect(InviteCode.isValid('LOVE-7K42QX'), isTrue);
      expect(InviteCode.isValid('LOVE-7K42Q'), isFalse);
    });
  });
}
