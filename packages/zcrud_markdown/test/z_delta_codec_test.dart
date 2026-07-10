// AC2 / AC5 / AC9 — `ZDeltaCodec` : round-trip IDENTITÉ (sans perte) sur corpus
// réel + décodage DÉFENSIF (AD-10) + traversée fidèle des ops embed opaques.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

import 'fixtures/rich_corpus.dart';

void main() {
  const codec = ZDeltaCodec();

  group('AC2 — round-trip IDENTITÉ sur corpus réel', () {
    for (final c in deltaIdentityCorpus) {
      test('identité: ${c.name}', () {
        final persisted = codec.encode(c.ops);
        final restored = codec.decode(persisted);
        // Round-trip bit-à-bit sémantique (jsonDecode(jsonEncode(x)) == x).
        expect(jsonEncode(restored), jsonEncode(c.ops),
            reason: 'perte sur le cas ${c.name} (ZDeltaCodec doit être lossless)');
        expect(restored, equals(c.ops));
      });
    }

    test('format persisté = String JSON canonique (contrat documenté)', () {
      final persisted = codec.encode(simpleOps);
      expect(persisted, isA<String>());
      expect(persisted, jsonEncode(simpleOps));
    });
  });

  group('AC9 — ops embed OPAQUES traversent à l\'identique', () {
    test('formule LaTeX (E6-3) préservée', () {
      expect(jsonEncode(codec.decode(codec.encode(latexEmbedOps))),
          jsonEncode(latexEmbedOps));
    });
    test('embed tableau opaque (E6-4) préservé', () {
      expect(jsonEncode(codec.decode(codec.encode(opaqueEmbedOps))),
          jsonEncode(opaqueEmbedOps));
    });
  });

  group('AC5 — décodage DÉFENSIF : jamais de throw, [] sur invalide', () {
    final defensiveInputs = <String, Object?>{
      'null': null,
      'chaîne vide': '',
      'espaces': '   ',
      'liste vide JSON': '[]',
      'liste vide native': <Object?>[],
      'JSON tronqué': '[{"insert":',
      'JSON non-liste': '{"insert":"x"}',
      'op sans insert': <Object?>[
        <String, dynamic>{'retain': 3},
      ],
      'op non-Map': <Object?>['pas une op'],
      'type inattendu (int)': 42,
      'chaîne non-JSON': 'juste du texte',
    };
    defensiveInputs.forEach((label, input) {
      test('decode($label) → [] sans throw', () {
        late List<Map<String, dynamic>> out;
        expect(() => out = codec.decode(input), returnsNormally);
        expect(out, isEmpty);
      });
    });

    test('encode(const []) → "[]" sans throw', () {
      expect(codec.encode(const <Map<String, dynamic>>[]), '[]');
    });
  });
}
