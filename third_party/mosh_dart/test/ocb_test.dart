import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:mosh_dart/ocb.dart';

Uint8List _hex(String s) {
  final bytes = <int>[];
  for (var i = 0; i < s.length; i += 2) {
    bytes.add(int.parse(s.substring(i, i + 2), radix: 16));
  }
  return Uint8List.fromList(bytes);
}

String _toHex(Uint8List bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

void main() {
  group('AesOcb', () {
    late AesOcb ocb;
    late Uint8List key;

    setUp(() {
      // 16-byte test key.
      key = Uint8List.fromList(
          List.generate(16, (i) => i));
      ocb = AesOcb(key);
    });

    test('encrypt then decrypt returns original plaintext', () {
      final nonce = Uint8List.fromList(List.generate(12, (i) => i + 1));
      final plaintext = Uint8List.fromList('Hello, mosh!'.codeUnits);

      final encrypted = ocb.encrypt(nonce, plaintext);
      // encrypted = [tag:16][ciphertext]
      expect(encrypted.length, equals(16 + plaintext.length));

      final decrypted = ocb.decrypt(nonce, encrypted);
      expect(decrypted, isNotNull);
      expect(decrypted, equals(plaintext));
    });

    test('decrypt with wrong nonce fails', () {
      final nonce1 = Uint8List.fromList(List.generate(12, (i) => i + 1));
      final nonce2 = Uint8List.fromList(List.generate(12, (i) => i + 2));
      final plaintext = Uint8List.fromList('test data'.codeUnits);

      final encrypted = ocb.encrypt(nonce1, plaintext);
      final decrypted = ocb.decrypt(nonce2, encrypted);
      expect(decrypted, isNull);
    });

    test('decrypt with tampered ciphertext fails', () {
      final nonce = Uint8List.fromList(List.generate(12, (i) => i));
      final plaintext = Uint8List.fromList('sensitive'.codeUnits);

      final encrypted = ocb.encrypt(nonce, plaintext);
      // Flip a bit in the ciphertext.
      encrypted[20] ^= 0x01;
      final decrypted = ocb.decrypt(nonce, encrypted);
      expect(decrypted, isNull);
    });

    test('decrypt with tampered tag fails', () {
      final nonce = Uint8List.fromList(List.generate(12, (i) => i));
      final plaintext = Uint8List.fromList('auth check'.codeUnits);

      final encrypted = ocb.encrypt(nonce, plaintext);
      // Flip a bit in the tag.
      encrypted[0] ^= 0x01;
      final decrypted = ocb.decrypt(nonce, encrypted);
      expect(decrypted, isNull);
    });

    test('decrypt with wrong key fails', () {
      final nonce = Uint8List.fromList(List.generate(12, (i) => i));
      final plaintext = Uint8List.fromList('wrong key'.codeUnits);

      final encrypted = ocb.encrypt(nonce, plaintext);

      final wrongKey = Uint8List.fromList(List.generate(16, (i) => i + 100));
      final otherOcb = AesOcb(wrongKey);
      final decrypted = otherOcb.decrypt(nonce, encrypted);
      expect(decrypted, isNull);
    });

    test('empty plaintext encrypts and decrypts', () {
      final nonce = Uint8List.fromList(List.generate(12, (i) => i));
      final plaintext = Uint8List(0);

      final encrypted = ocb.encrypt(nonce, plaintext);
      expect(encrypted.length, equals(16)); // tag only

      final decrypted = ocb.decrypt(nonce, encrypted);
      expect(decrypted, isNotNull);
      expect(decrypted!.length, equals(0));
    });

    test('block-aligned plaintext encrypts and decrypts', () {
      final nonce = Uint8List.fromList(List.generate(12, (i) => i));
      // Exactly 32 bytes = 2 full blocks.
      final plaintext = Uint8List.fromList(List.generate(32, (i) => i));

      final encrypted = ocb.encrypt(nonce, plaintext);
      expect(encrypted.length, equals(16 + 32));

      final decrypted = ocb.decrypt(nonce, encrypted);
      expect(decrypted, equals(plaintext));
    });

    test('large plaintext encrypts and decrypts', () {
      final nonce = Uint8List.fromList(List.generate(12, (i) => i));
      final plaintext = Uint8List.fromList(List.generate(1000, (i) => i & 0xff));

      final encrypted = ocb.encrypt(nonce, plaintext);
      final decrypted = ocb.decrypt(nonce, encrypted);
      expect(decrypted, equals(plaintext));
    });

    // RFC 7253 test vectors (A="" only — no AAD support in mosh OCB).
    // These are the exact expected outputs from RFC 7253 Appendix A,
    // cross-validated against the Go mosh-go OCB implementation.
    // Key = 000102030405060708090A0B0C0D0E0F for all vectors.
    group('RFC 7253 test vectors (cross-validated with Go)', () {
      final vectors = [
        // Vector 1: empty plaintext, empty AAD
        {
          'nonce': 'BBAA99887766554433221100',
          'plain': '',
          'ct': '785407bfffc8ad9edcc5520ac9111ee6',
        },
        // Vector 3: 8-byte plaintext, empty AAD
        {
          'nonce': 'BBAA99887766554433221102',
          'plain': '0001020304050607',
          'ct': '6dd42c17cbf9c7835dfd6e630e8f98eb3d2a49b0dc0f314e',
        },
        // Vector 5: 16-byte plaintext (one full block), empty AAD
        {
          'nonce': 'BBAA99887766554433221104',
          'plain': '000102030405060708090A0B0C0D0E0F',
          'ct': '571d535b60b277188be5147170a9a22c5e77b6af964090c0f8f567b7b2763e1c',
        },
        // Vector 7: 24-byte plaintext (1.5 blocks), empty AAD
        {
          'nonce': 'BBAA99887766554433221106',
          'plain': '000102030405060708090A0B0C0D0E0F1011121314151617',
          'ct': '5ce88ec2e0692706a915c00aeb8b23968467b2cfbb580496a361f6b4f1c479b222d7011eaa7b3144',
        },
        // Vector 9: 32-byte plaintext (two full blocks), empty AAD
        {
          'nonce': 'BBAA99887766554433221108',
          'plain': '000102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F',
          'ct': 'fed5b2062e331bd1d243dce4030bf42b1f0391097939c462293dac9fabc97010cfd6ef3e7ff48413e807ce43f63e7977',
        },
      ];

      for (final v in vectors) {
        test('N=${v['nonce']!.substring(v['nonce']!.length - 2)} P=${v['plain']!.length ~/ 2}B', () {
          final nonce = _hex(v['nonce']!);
          final plain = v['plain']!.isEmpty ? Uint8List(0) : _hex(v['plain']!);
          final expectedCt = _hex(v['ct']!);

          // Encrypt and verify output matches expected.
          final encrypted = ocb.encrypt(nonce, plain);
          expect(_toHex(encrypted), equals(v['ct']),
              reason: 'encrypt output mismatch');

          // Decrypt and verify round-trip.
          final decrypted = ocb.decrypt(nonce, expectedCt);
          expect(decrypted, isNotNull, reason: 'decrypt returned null');
          expect(decrypted, equals(plain), reason: 'decrypt plaintext mismatch');
        });
      }
    });

    // Verify Dart and Go OCB are interoperable: Go-encrypted data
    // can be decrypted by Dart and vice versa.
    test('Go-encrypted data decrypts correctly in Dart', () {
      // This ciphertext was produced by the Go mosh-go OCB with:
      // key=000102...0F, nonce=BBAA99887766554433221102, P=0001020304050607
      final goEncrypted = _hex('6dd42c17cbf9c7835dfd6e630e8f98eb3d2a49b0dc0f314e');
      final nonce = _hex('BBAA99887766554433221102');
      final expectedPlain = _hex('0001020304050607');

      final decrypted = ocb.decrypt(nonce, goEncrypted);
      expect(decrypted, isNotNull);
      expect(decrypted, equals(expectedPlain));
    });

    test('different nonces produce different ciphertexts', () {
      final nonce1 = Uint8List.fromList(List.generate(12, (i) => 0));
      final nonce2 = Uint8List.fromList(List.generate(12, (i) => 1));
      final plaintext = Uint8List.fromList('same data'.codeUnits);

      final enc1 = ocb.encrypt(nonce1, plaintext);
      final enc2 = ocb.encrypt(nonce2, plaintext);

      // Ciphertexts (after tag) should differ.
      var same = true;
      for (var i = 16; i < enc1.length; i++) {
        if (enc1[i] != enc2[i]) {
          same = false;
          break;
        }
      }
      expect(same, isFalse);
    });
  });
}
