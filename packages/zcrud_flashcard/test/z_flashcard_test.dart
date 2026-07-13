/// Tests E9-1 : `ZFlashcard` + `ZChoice` + `ZFlashcardType` + `ZFlashcardSource`.
///
/// Couvre les 10 ACs : round-trip zéro-perte, désérialisation défensive réelle
/// (maps corrompues), SRS hors carte, éphémère, provenance ouverte par registre,
/// slots AD-4 (`extra` + `extension`).
///
/// Exécuté via `flutter test` : le domaine flashcard réutilise
/// `package:zcrud_core/zcrud_core.dart` (qui tire le SDK Flutter), même
/// convention que `zcrud_mindmap`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

/// Extension de test concrète (AD-4) : `formatVersion` géré = 1 ; toute autre
/// version → `null` via `fromJsonSafe` (parent survit).
class _TestExt extends ZExtension {
  const _TestExt(this.note);

  final String note;

  @override
  int get formatVersion => 1;

  @override
  Map<String, dynamic> toJson() =>
      <String, dynamic>{'format_version': formatVersion, 'note': note};

  /// Parse défensif : version non gérée → `null`.
  static ZExtension? fromJsonSafe(Map<String, dynamic> json) {
    if (json['format_version'] != 1) return null;
    return ZExtension.guard<ZExtension?>(
      () => _TestExt(json['note'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _TestExt && note == other.note && formatVersion == 1;

  @override
  int get hashCode => Object.hash(note, formatVersion);
}

void main() {
  group('ZFlashcardType (AC1)', () {
    test('chaque valeur round-trip en camelCase (= name)', () {
      for (final value in ZFlashcardType.values) {
        final card = ZFlashcard(question: 'q', type: value);
        final map = card.toMap();
        expect(map['type'], value.name);
        expect(ZFlashcard.fromMap(map).type, value);
      }
    });

    test('valeur inconnue → openQuestion (défensif, sans throw)', () {
      final card = ZFlashcard.fromMap(
        <String, dynamic>{'question': 'q', 'type': 'totallyUnknownType'},
      );
      expect(card.type, ZFlashcardType.openQuestion);
    });

    test('clé absente → openQuestion', () {
      final card = ZFlashcard.fromMap(<String, dynamic>{'question': 'q'});
      expect(card.type, ZFlashcardType.openQuestion);
    });
  });

  group('ZChoice (AC2)', () {
    test('round-trip + clé persistée is_correct (snake_case)', () {
      const choice = ZChoice(content: 'Réponse A', isCorrect: true);
      final map = choice.toMap();
      expect(map['is_correct'], true);
      expect(map.containsKey('isCorrect'), isFalse);
      expect(ZChoice.fromMap(map), choice);
    });

    test('content absent → "" ; isCorrect absent → false (défauts)', () {
      final choice = ZChoice.fromMap(<String, dynamic>{});
      expect(choice.content, '');
      expect(choice.isCorrect, false);
    });

    test('types corrompus → défauts sûrs (jamais de throw)', () {
      final choice = ZChoice.fromMap(
        <String, dynamic>{'content': 42, 'is_correct': 'yes'},
      );
      expect(choice.content, '');
      expect(choice.isCorrect, false);
    });
  });

  group('ZFlashcard round-trip zéro-perte (AC3)', () {
    test('entité complète round-trip (snake_case + specials)', () {
      final card = ZFlashcard(
        id: 'card-1',
        folderId: 'f1',
        subFolderId: 'sf1',
        type: ZFlashcardType.multipleChoice,
        question: 'Quelle est la capitale ?',
        answer: 'Paris',
        isTrue: true,
        choices: const <ZChoice>[
          ZChoice(content: 'Paris', isCorrect: true),
          ZChoice(content: 'Lyon'),
        ],
        explanation: 'Explication',
        hint: 'Indice',
        tagIds: const <String>['geo', 'fr'],
        isReadOnly: true,
        createdAt: DateTime.utc(2026, 7, 10, 12),
        updatedAt: DateTime.utc(2026, 7, 10, 13),
        source: const ZNoteSource(noteId: 'n1'),
        extension: const _TestExt('meta'),
        extra: const <String, dynamic>{'app_key': 'app_value'},
      );

      final map = card.toMap();
      // Clés snake_case attendues.
      expect(map['sub_folder_id'], 'sf1');
      expect(map['is_read_only'], true);
      expect(map['tag_ids'], <String>['geo', 'fr']);
      expect(map['created_at'], '2026-07-10T12:00:00.000Z');

      final back = ZFlashcard.fromMap(
        map,
        extensionParser: _TestExt.fromJsonSafe,
      );
      expect(back, card);
    });
  });

  group('État SRS HORS carte (AC4)', () {
    test('aucune clé SRS dans la map persistée', () {
      final card = ZFlashcard(
        question: 'q',
        createdAt: DateTime.utc(2026),
      );
      final map = card.toMap();
      const srsKeys = <String>[
        'interval',
        'repetitions',
        'ease_factor',
        'easeFactor',
        'next_review_date',
        'nextReviewDate',
        'learned_at',
        'last_quality',
        'repetition_info',
      ];
      for (final key in srsKeys) {
        expect(map.containsKey(key), isFalse, reason: 'clé SRS interdite: $key');
      }
    });
  });

  group('Éphémère dérivé (AC5)', () {
    test('id == null → éphémère ; id fourni → matérialisée', () {
      expect(const ZFlashcard(question: 'q').isEphemeral, isTrue);
      expect(const ZFlashcard(id: 'x', question: 'q').isEphemeral, isFalse);
    });
  });

  group('Provenance ouverte par registre (AC6)', () {
    test('note round-trip (générique)', () {
      const src = ZNoteSource(noteId: 'n1');
      final decoded = ZFlashcardSource.fromJson(src.toJson());
      expect(decoded, src);
    });

    test('document round-trip (avec et sans page)', () {
      const withPage = ZDocumentSource(documentId: 'd1', page: 7);
      expect(ZFlashcardSource.fromJson(withPage.toJson()), withPage);
      const noPage = ZDocumentSource(documentId: 'd2');
      final map = noPage.toJson();
      expect(map.containsKey('page'), isFalse);
      expect(ZFlashcardSource.fromJson(map), noPage);
    });

    test('conversation round-trip', () {
      const src = ZConversationSource(conversationId: 'c1', messageId: 'm1');
      expect(ZFlashcardSource.fromJson(src.toJson()), src);
    });

    test('kind "article" enregistré → codec du registre consulté', () {
      final registry = ZSourceRegistry()
        ..register(
          'article',
          fromJson: (json) => <String, dynamic>{
            'article_id': json['article_id'],
            'decoded_by_registry': true,
          },
          toJson: (payload) {
            final p = payload as Map<String, dynamic>;
            return <String, dynamic>{'article_id': p['article_id']};
          },
        );

      final src = ZCustomSource('article', <String, dynamic>{'article_id': 'A1'});
      final wire = src.toJson(registry: registry);
      expect(wire['kind'], 'article');
      expect(wire['article_id'], 'A1');

      final decoded = ZFlashcardSource.fromJson(wire, registry: registry);
      expect(decoded, isA<ZCustomSource>());
      final custom = decoded! as ZCustomSource;
      expect(custom.kind, 'article');
      expect(custom.payload['article_id'], 'A1');
      // PREUVE de consultation : la clé n'est présente que via le codec.
      expect(custom.payload['decoded_by_registry'], true);

      // Sans registre : repli custom conservant le payload, PAS de marqueur.
      final noReg = ZFlashcardSource.fromJson(wire);
      expect(noReg, isA<ZCustomSource>());
      expect((noReg! as ZCustomSource).payload.containsKey('decoded_by_registry'),
          isFalse);
    });

    test('kind inconnu et non enregistré → custom conservant le payload', () {
      final decoded = ZFlashcardSource.fromJson(
        <String, dynamic>{'kind': 'mystery', 'foo': 'bar', 'n': 1},
      );
      expect(decoded, isA<ZCustomSource>());
      final custom = decoded! as ZCustomSource;
      expect(custom.kind, 'mystery');
      expect(custom.payload, <String, dynamic>{'foo': 'bar', 'n': 1});
    });

    test('"article" n\'est jamais un variant codé en dur', () {
      // Sans enregistrement, "article" reste un ZCustomSource générique.
      final decoded = ZFlashcardSource.fromJson(
        <String, dynamic>{'kind': 'article', 'article_id': 'A1'},
      );
      expect(decoded, isA<ZCustomSource>());
    });
  });

  group('Slots d\'extension AD-4 (AC7)', () {
    test('extension concrète round-trip', () {
      final card = ZFlashcard(
        question: 'q',
        extension: const _TestExt('hello'),
      );
      final back = ZFlashcard.fromMap(
        card.toMap(),
        extensionParser: _TestExt.fromJsonSafe,
      );
      expect(back.extension, const _TestExt('hello'));
    });

    test('extension de formatVersion non gérée → null (parent survit)', () {
      final map = <String, dynamic>{
        'question': 'q',
        'extension': <String, dynamic>{'format_version': 2, 'note': 'x'},
      };
      final card = ZFlashcard.fromMap(map, extensionParser: _TestExt.fromJsonSafe);
      expect(card.extension, isNull);
      expect(card.question, 'q');
    });

    test('clés extra inconnues préservées au round-trip', () {
      final card = ZFlashcard.fromMap(<String, dynamic>{
        'question': 'q',
        'unknown_a': 'keep',
        'unknown_b': 42,
      });
      expect(card.extra, <String, dynamic>{'unknown_a': 'keep', 'unknown_b': 42});
      final map = card.toMap();
      expect(map['unknown_a'], 'keep');
      expect(map['unknown_b'], 42);
      // extra ne capture jamais les clés réservées.
      expect(card.extra.containsKey('question'), isFalse);
    });

    test('extra par défaut = {} jamais null', () {
      expect(const ZFlashcard(question: 'q').extra, <String, dynamic>{});
    });
  });

  group('Désérialisation défensive de bout en bout (AC8)', () {
    test('map vide {} → défauts sûrs, aucun throw', () {
      final card = ZFlashcard.fromMap(<String, dynamic>{});
      expect(card.question, '');
      expect(card.type, ZFlashcardType.openQuestion);
      expect(card.tagIds, <String>[]);
      expect(card.choices, isNull);
      expect(card.source, isNull);
      expect(card.extension, isNull);
      expect(card.extra, <String, dynamic>{});
      expect(card.isEphemeral, isTrue);
    });

    test('choices malformés → décodage défensif par élément', () {
      final card = ZFlashcard.fromMap(<String, dynamic>{
        'question': 'q',
        'choices': <dynamic>[
          <String, dynamic>{'content': 'ok', 'is_correct': true},
          'not-a-map',
          42,
          <String, dynamic>{'is_correct': 'x'}, // content absent → ''
        ],
      });
      // Éléments non-map ignorés ; maps décodées défensivement.
      expect(card.choices, <ZChoice>[
        const ZChoice(content: 'ok', isCorrect: true),
        const ZChoice(content: '', isCorrect: false),
      ]);
    });

    test('source de kind inconnu/non-map → custom ou null', () {
      final unknown = ZFlashcard.fromMap(<String, dynamic>{
        'question': 'q',
        'source': <String, dynamic>{'kind': 'weird', 'x': 1},
      });
      expect(unknown.source, isA<ZCustomSource>());

      final notMap = ZFlashcard.fromMap(<String, dynamic>{
        'question': 'q',
        'source': 'nope',
      });
      expect(notMap.source, isNull);

      final noKind = ZFlashcard.fromMap(<String, dynamic>{
        'question': 'q',
        'source': <String, dynamic>{'x': 1},
      });
      expect(noKind.source, isNull);
    });

    test('extension corrompue → null (parent survit)', () {
      final card = ZFlashcard.fromMap(
        <String, dynamic>{'question': 'q', 'extension': 'not-a-map'},
        extensionParser: _TestExt.fromJsonSafe,
      );
      expect(card.extension, isNull);
      expect(card.question, 'q');
    });

    test('tag_ids absent → const []', () {
      final card = ZFlashcard.fromMap(<String, dynamic>{'question': 'q'});
      expect(card.tagIds, isEmpty);
    });
  });

  group('copyWith préserve les canaux hors-codegen', () {
    test('copyWith(question:) ne perd ni source ni extension ni extra', () {
      final card = ZFlashcard(
        question: 'q1',
        source: const ZNoteSource(noteId: 'n1'),
        extension: const _TestExt('x'),
        extra: const <String, dynamic>{'k': 'v'},
      );
      final updated = card.copyWith(question: 'q2');
      expect(updated.question, 'q2');
      expect(updated.source, const ZNoteSource(noteId: 'n1'));
      expect(updated.extension, const _TestExt('x'));
      expect(updated.extra, <String, dynamic>{'k': 'v'});
    });

    test('copyWith(answer: null) remet explicitement à null (sentinelle)', () {
      const card = ZFlashcard(question: 'q', answer: 'a');
      expect(card.copyWith(answer: null).answer, isNull);
      expect(card.copyWith().answer, 'a');
    });
  });

  group('Enregistrement ZcrudRegistry (AC9)', () {
    test('registerZFlashcard câble le kind "flashcard"', () {
      final registry = ZcrudRegistry();
      registerZFlashcard(registry);
      registerZChoice(registry);
      expect(registry.isRegistered('flashcard'), isTrue);
      expect(registry.isRegistered('flashcard_choice'), isTrue);
    });
  });

  // ES-1.3 (AC4) — MÊME défaut que `ZStudyFolder` : les stores écrivent
  // `updated_at`/`is_deleted` DANS le corps puis passent la map COMPLÈTE à
  // `fromMap`. `is_deleted` (non déclaré) atterrissait dans `extra` et était
  // réémis par `toMap` — fuite d'une préoccupation de store dans le domaine.
  group('ZFlashcard — AD-19 : clés de sync hors-entité (ES-1.3)', () {
    test('fromMap d\'une map de STORE : ni is_deleted ni updated_at dans extra',
        () {
      final card = ZFlashcard.fromMap(<String, dynamic>{
        'id': 'c1',
        'question': 'q',
        'updated_at': DateTime.utc(2026, 5, 5).toIso8601String(),
        'is_deleted': true,
        'un_champ_inconnu': 'gardé',
      });
      expect(card.extra.containsKey('is_deleted'), isFalse);
      expect(card.extra.containsKey('updated_at'), isFalse);
      // Round-trip AD-4 des clés VRAIMENT inconnues : non régressé.
      expect(card.extra['un_champ_inconnu'], 'gardé');
      // Miroir de compat peuplé (lecture legacy, AD-10).
      expect(card.updatedAt, DateTime.utc(2026, 5, 5));
    });

    test('toMap() n\'émet JAMAIS is_deleted (AD-16, soft-delete hors-entité)',
        () {
      final card = ZFlashcard.fromMap(<String, dynamic>{
        'question': 'q',
        'is_deleted': true,
      });
      final map = card.toMap();
      expect(map.containsKey('is_deleted'), isFalse);
      expect(map.containsKey('isDeleted'), isFalse);
    });

    test('convergence : fromMap(toMap(c)) == c (l\'== n\'est plus cassée entre '
        'une carte en mémoire et la même relue du store)', () {
      final fromStore = ZFlashcard.fromMap(<String, dynamic>{
        'id': 'c1',
        'question': 'q',
        'updated_at': DateTime.utc(2026, 5, 5).toIso8601String(),
        'is_deleted': false,
      });
      final reread = ZFlashcard.fromMap(fromStore.toMap());
      expect(reread.extra, equals(fromStore.extra));
      expect(reread, equals(fromStore));
    });

    test('map de sync corrompue (is_deleted: "oui", updated_at: 42) ⇒ aucun '
        'throw, aucune pollution (AD-10)', () {
      final card = ZFlashcard.fromMap(<String, dynamic>{
        'question': 'q',
        'updated_at': 42,
        'is_deleted': 'oui',
      });
      expect(card.question, 'q');
      expect(card.updatedAt, isNull);
      expect(card.extra, isEmpty);
    });
  });
}
