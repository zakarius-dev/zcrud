// MIN-1 — Souligné (`underline`) préservé au round-trip Markdown via `<u>…</u>`
// (parité DODLP). Prouve : encode émet `<u>…</u>`, decode ré-absorbe l'attribut,
// round-trip complet, préservation des autres attributs, défensif (texte sans
// souligné inchangé), et NON-régression de ZDeltaCodec (déjà sans perte).
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

bool _hasUnderlineText(List<Map<String, dynamic>> ops, String text) {
  return ops.any((op) {
    if (op['insert'] != text) return false;
    final attrs = op['attributes'];
    return attrs is Map && attrs['underline'] == true;
  });
}

void main() {
  const codec = ZMarkdownCodec();

  test('encode : souligné → marqueur <u>…</u> dans le Markdown', () {
    final ops = <Map<String, dynamic>>[
      <String, dynamic>{'insert': 'Hello '},
      <String, dynamic>{
        'insert': 'world',
        'attributes': <String, dynamic>{'underline': true},
      },
      <String, dynamic>{'insert': ' end\n'},
    ];
    final md = codec.encode(ops) as String;
    expect(md, contains('<u>world</u>'));
  });

  test('round-trip : decode(encode(ops)) préserve le souligné', () {
    final ops = <Map<String, dynamic>>[
      <String, dynamic>{'insert': 'Hello '},
      <String, dynamic>{
        'insert': 'world',
        'attributes': <String, dynamic>{'underline': true},
      },
      <String, dynamic>{'insert': ' end\n'},
    ];
    final back = codec.decode(codec.encode(ops));
    expect(_hasUnderlineText(back, 'world'), isTrue,
        reason: 'souligné perdu au round-trip Markdown (MIN-1 régressé)');
    // Le texte non souligné ne porte PAS l'attribut.
    expect(
      back.any((op) =>
          op['insert'] == 'Hello ' &&
          (op['attributes'] == null ||
              (op['attributes'] as Map)['underline'] != true)),
      isTrue,
    );
  });

  test('decode d\'un Markdown avec <u> littéral → attribut underline', () {
    final back = codec.decode('avant <u>souligné</u> après');
    expect(_hasUnderlineText(back, 'souligné'), isTrue);
  });

  test('souligné + gras combinés : les deux attributs préservés', () {
    final ops = <Map<String, dynamic>>[
      <String, dynamic>{
        'insert': 'both',
        'attributes': <String, dynamic>{'underline': true, 'bold': true},
      },
      <String, dynamic>{'insert': '\n'},
    ];
    final back = codec.decode(codec.encode(ops));
    final op = back.firstWhere((op) => op['insert'] == 'both',
        orElse: () => <String, dynamic>{});
    expect(op['attributes'], isNotNull);
    final attrs = op['attributes'] as Map;
    expect(attrs['underline'], true);
    expect(attrs['bold'], true);
  });

  test('texte SANS souligné : aucun marqueur, aucun attribut ajouté', () {
    final ops = <Map<String, dynamic>>[
      <String, dynamic>{'insert': 'plain text\n'},
    ];
    final md = codec.encode(ops) as String;
    expect(md, isNot(contains('<u>')));
    final back = codec.decode(md);
    expect(
      back.every((op) =>
          op['attributes'] == null ||
          (op['attributes'] as Map)['underline'] != true),
      isTrue,
    );
  });

  test('ZDeltaCodec reste sans perte (souligné conservé nativement)', () {
    const delta = ZDeltaCodec();
    final ops = <Map<String, dynamic>>[
      <String, dynamic>{
        'insert': 'u',
        'attributes': <String, dynamic>{'underline': true},
      },
      <String, dynamic>{'insert': '\n'},
    ];
    final back = delta.decode(delta.encode(ops));
    expect(_hasUnderlineText(back, 'u'), isTrue);
  });
}
