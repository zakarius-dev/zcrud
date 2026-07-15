// DW-ES24-1 (ES-3.0, Phase B) — immuabilité PROFONDE INCONDITIONNELLE du canal
// `ZSmartNote.content` (canal #3, `List<Map<String,dynamic>>` — 2 niveaux).
library;

import 'package:test/test.dart';
import 'package:zcrud_note/zcrud_note.dart';

void main() {
  group('DW-ES24-1 #3 — ZSmartNote.content (profond)', () {
    test('ctor NOMINAL non-const + mutation LISTE via accesseur ⇒ Unsupported',
        () {
      final ops = <Map<String, dynamic>>[
        <String, dynamic>{'insert': 'hi\n'},
      ];
      final note = ZSmartNote(content: ops); // ctor const, invoqué non-const
      expect(() => note.content.add(<String, dynamic>{'insert': 'x'}),
          throwsUnsupportedError);
      expect(() => note.content.clear(), throwsUnsupportedError);
    });

    test('mutation de l\'op INTERNE (2ᵉ niveau) via accesseur ⇒ Unsupported', () {
      final ops = <Map<String, dynamic>>[
        <String, dynamic>{'insert': 'hi\n'},
      ];
      final note = ZSmartNote(content: ops);
      expect(() => note.content[0]['insert'] = 'muté', throwsUnsupportedError);
      expect(() => note.content[0].remove('insert'), throwsUnsupportedError);
    });

    test('AC13 — `const` PRÉSERVÉ + fromMap toujours profondément immuable', () {
      const note = ZSmartNote(); // ctor const préservé
      expect(note.content, isEmpty);
      final relu = ZSmartNote.fromMap(const <String, dynamic>{
        'content': <Map<String, dynamic>>[
          <String, dynamic>{'insert': 'hi\n'},
        ],
      });
      expect(() => relu.content[0]['insert'] = 'x', throwsUnsupportedError);
    });

    test('AC14 — zéro-copie sur le chemin chaud (accesseur idempotent)', () {
      final relu = ZSmartNote.fromMap(const <String, dynamic>{
        'content': <Map<String, dynamic>>[
          <String, dynamic>{'insert': 'hi\n'},
        ],
      });
      expect(identical(relu.content, relu.content), isTrue);
    });
  });
}
