/// Tests de [ZNoteAudio] — **le PREMIER `ZExtension` concret du repo** (AC5,
/// AC11, D6).
///
/// AD-4 pt.1 (« slot type additif **versionné**, parsé **défensivement**,
/// **jamais** de throw ») n'avait, avant cette story, **jamais été exercé
/// concrètement** : `grep -r "implements ZExtension" packages/*/lib` rendait
/// **zéro**. C'était un filet **qu'on n'avait jamais vu mordre** (rétro ES-1 §7).
/// Ces tests le font **mordre**.
library;

import 'package:test/test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_note/zcrud_note.dart';

void main() {
  group('AC5 — ZNoteAudio : contrat ZExtension (AD-4 pt.1)', () {
    test('EST une `ZExtension` et porte un `formatVersion` propre', () {
      const audio = ZNoteAudio(url: 'https://x/a.mp3');
      expect(audio, isA<ZExtension>());
      expect(audio.formatVersion, 1);
      expect(kZNoteAudioFormatVersion, 1);
    });

    test('round-trip `toJson` → `fromJsonSafe` (identité)', () {
      const audio = ZNoteAudio(
        url: 'https://x/a.mp3',
        path: '/local/a.mp3',
        textHash: 'abc',
      );
      final json = audio.toJson();
      expect(json['format_version'], 1);
      expect(json['url'], 'https://x/a.mp3');
      expect(json['path'], '/local/a.mp3');
      expect(json['text_hash'], 'abc');

      final relu = ZNoteAudio.fromJsonSafe(json);
      expect(relu, audio);
      expect(relu.hashCode, audio.hashCode);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // AC11 / AD-10 — CHAQUE invariant naît avec sa GARDE **ET** son cas CORROMPU.
  // « Jamais de throw » : le parent doit TOUJOURS survivre.
  // ═══════════════════════════════════════════════════════════════════════════
  group('AC11 — fromJsonSafe : défensif, JAMAIS de throw', () {
    test('GARDE : `format_version: 1` est géré', () {
      final a = ZNoteAudio.fromJsonSafe(<String, dynamic>{
        'format_version': 1,
        'url': 'u',
      });
      expect(a, isNotNull);
      expect(a!.url, 'u');
    });

    test('CORROMPU : `format_version: 99` (version NON GÉRÉE) ⇒ null', () {
      expect(
        ZNoteAudio.fromJsonSafe(<String, dynamic>{
          'format_version': 99,
          'url': 'u',
        }),
        isNull,
        reason: 'AD-10 : une version future/inconnue ne fait JAMAIS échouer le '
            'parent — le slot est simplement ignoré (évolution additive).',
      );
    });

    test('CORROMPU : `format_version` ABSENTE ⇒ null', () {
      expect(ZNoteAudio.fromJsonSafe(<String, dynamic>{'url': 'u'}), isNull);
    });

    test('CORROMPU : `format_version` non numérique ⇒ null', () {
      expect(
        ZNoteAudio.fromJsonSafe(<String, dynamic>{'format_version': 'x'}),
        isNull,
      );
    });

    test('CORROMPU : `null` / non-map (int, String, List) ⇒ null', () {
      expect(ZNoteAudio.fromJsonSafe(null), isNull);
      expect(ZNoteAudio.fromJsonSafe(42), isNull);
      expect(ZNoteAudio.fromJsonSafe('texte'), isNull);
      expect(ZNoteAudio.fromJsonSafe(<Object?>[1, 2]), isNull);
    });

    test('CORROMPU : champs individuels illisibles ⇒ champ `null`, PAS de throw',
        () {
      final a = ZNoteAudio.fromJsonSafe(<String, dynamic>{
        'format_version': 1,
        'url': 42, // non-String
        'path': <Object?>[], // non-String
        'text_hash': <String, dynamic>{'x': 1}, // ni String ni num
      });
      expect(a, isNotNull);
      expect(a!.url, isNull);
      expect(a.path, isNull);
      expect(a.textHash, isNull);
    });

    test('map à clés non-`String` (Hive) ⇒ coercée, pas de throw', () {
      final a = ZNoteAudio.fromJsonSafe(<Object?, Object?>{
        'format_version': 1,
        'url': 'u',
      });
      expect(a?.url, 'u');
    });

    test('AUCUNE entrée de la table ne throw', () {
      final entrees = <Object?>[
        null,
        42,
        'x',
        true,
        <Object?>[],
        <String, dynamic>{},
        <String, dynamic>{'format_version': 1},
        <String, dynamic>{'format_version': 0},
        <String, dynamic>{'format_version': -1},
        <String, dynamic>{'format_version': 99, 'url': 'u'},
        <String, dynamic>{'format_version': 1, 'text_hash': <Object?>[]},
        <Object?, Object?>{1: 2},
      ];
      for (final e in entrees) {
        expect(() => ZNoteAudio.fromJsonSafe(e), returnsNormally,
            reason: 'entrée: $e');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // AC5 / AC11 — 🔴 DIVERGENCE RÉELLE lex ↔ IFFD sur `audioTextHash`.
  //   lex : `String?` (smart_note.dart l. 36)
  //   IFFD : `int?`   (smart_note_model.dart l. 11 — `int.tryParse(…toString())`)
  // ═══════════════════════════════════════════════════════════════════════════
  group('AC5 — textHash : coercition `String` (lex) | `num` (IFFD)', () {
    String? hash(Object? raw) => ZNoteAudio.fromJsonSafe(<String, dynamic>{
          'format_version': 1,
          'text_hash': raw,
        })?.textHash;

    test('GARDE lex : `\'abc\'` (String) ⇒ `\'abc\'`', () {
      expect(hash('abc'), 'abc');
    });

    test('🔴 IFFD : `12345` (int) ⇒ `\'12345\'` (String) — divergence absorbée',
        () {
      expect(hash(12345), '12345');
    });

    test('IFFD : `double` ⇒ String', () {
      expect(hash(1.5), '1.5');
    });

    test('CORROMPU : `[]` / `{}` / `true` ⇒ null (jamais de throw)', () {
      expect(hash(<Object?>[]), isNull);
      expect(hash(<String, dynamic>{}), isNull);
      expect(hash(true), isNull);
      expect(hash(null), isNull);
    });
  });
}
