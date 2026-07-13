/// Tests E9-3 : `ZReviewMode` + `ZStudySessionConfig` (AC1/AC3/AC7/AC10).
///
/// Couvre : les 6 modes round-trip camelCase + repli défensif `spaced` ;
/// round-trip zéro-perte de la config ; `types` (liste d'enum) défensif ; slots
/// AD-4 (`extra`/`extension`) ; désérialisation défensive réelle ;
/// enregistrement `ZcrudRegistry`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

class _TestExt extends ZExtension {
  const _TestExt(this.note);

  final String note;

  @override
  int get formatVersion => 1;

  @override
  Map<String, dynamic> toJson() =>
      <String, dynamic>{'format_version': formatVersion, 'note': note};

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
  group('ZReviewMode (AC1)', () {
    test('6 modes exacts', () {
      expect(ZReviewMode.values, <ZReviewMode>[
        ZReviewMode.spaced,
        ZReviewMode.learn,
        ZReviewMode.list,
        ZReviewMode.test,
        ZReviewMode.whiteExam,
        ZReviewMode.cramming,
      ]);
    });

    test('chaque valeur round-trip en camelCase (= name)', () {
      for (final mode in ZReviewMode.values) {
        final config = ZStudySessionConfig(mode: mode);
        final map = config.toMap();
        expect(map['mode'], mode.name);
        expect(ZStudySessionConfig.fromMap(map).mode, mode);
      }
    });

    test('whiteExam persisté "whiteExam"', () {
      expect(ZReviewMode.whiteExam.name, 'whiteExam');
    });

    test('valeur inconnue → spaced (défensif, sans throw)', () {
      final config = ZStudySessionConfig.fromMap(
        <String, dynamic>{'mode': 'totallyUnknownMode'},
      );
      expect(config.mode, ZReviewMode.spaced);
    });

    test('clé mode absente → spaced', () {
      expect(
        ZStudySessionConfig.fromMap(const <String, dynamic>{}).mode,
        ZReviewMode.spaced,
      );
    });
  });

  group('ZStudySessionConfig — round-trip codegen (AC7)', () {
    test('round-trip complet zéro-perte (snake_case), types via ergonomie typée',
        () {
      // ES-1.1 : `types` est neutralisé en `List<String>` dans le noyau ;
      // l'ergonomie typée `ZFlashcardType` passe par `withFlashcardTypes`
      // (extension flashcard). Le wire reste byte-identique à E9.
      final config = const ZStudySessionConfig(
        mode: ZReviewMode.learn,
        folderId: 'f1',
        tagIds: <String>['t1', 't2'],
        count: 20,
      ).withFlashcardTypes(const <ZFlashcardType>[
        ZFlashcardType.multipleChoice,
        ZFlashcardType.trueOrFalse,
      ]);
      final map = config.toMap();
      expect(map['mode'], 'learn');
      expect(map['folder_id'], 'f1');
      expect(map['tag_ids'], <String>['t1', 't2']);
      // Wire byte-identique à E9 : noms d'enum camelCase.
      expect(map['types'], <String>['multipleChoice', 'trueOrFalse']);
      expect(map['count'], 20);
      // Round-trip : la config neutre porte des clés String.
      expect(config.types, <String>['multipleChoice', 'trueOrFalse']);
      expect(ZStudySessionConfig.fromMap(map), config);
      // Ergonomie typée restituée.
      expect(config.flashcardTypes, <ZFlashcardType>[
        ZFlashcardType.multipleChoice,
        ZFlashcardType.trueOrFalse,
      ]);
    });

    test('défauts : mode spaced, filtres null (= pas de filtre)', () {
      const config = ZStudySessionConfig();
      expect(config.mode, ZReviewMode.spaced);
      expect(config.folderId, isNull);
      expect(config.tagIds, isNull);
      expect(config.types, isNull);
      expect(config.count, isNull);
    });

    test('types : clés neutres conservées ; flashcardTypes drop défensif (AD-10)',
        () {
      final config = ZStudySessionConfig.fromMap(<String, dynamic>{
        'types': <dynamic>['multipleChoice', 'totallyUnknownType', 'exercise'],
      });
      // Noyau neutre : toutes les clés String survivent (round-trip zéro-perte).
      expect(config.types, <String>[
        'multipleChoice',
        'totallyUnknownType',
        'exercise',
      ]);
      // Ergonomie typée (flashcard) : les clés inconnues sont ignorées.
      expect(config.flashcardTypes, <ZFlashcardType>[
        ZFlashcardType.multipleChoice,
        ZFlashcardType.exercise,
      ]);
    });

    test('copyWith à sentinelle préserve/reset les canaux', () {
      final config = ZStudySessionConfig(
        mode: ZReviewMode.test,
        folderId: 'f1',
        extension: const _TestExt('x'),
      );
      // Omis → préservé.
      final renamed = config.copyWith(count: 5);
      expect(renamed.folderId, 'f1');
      expect(renamed.extension, const _TestExt('x'));
      expect(renamed.count, 5);
      // null explicite → reset.
      final cleared = config.copyWith(folderId: null);
      expect(cleared.folderId, isNull);
    });
  });

  group('ZStudySessionConfig — slots AD-4 (AC3)', () {
    test('extra inconnu préservé au round-trip, non-modifiable', () {
      final config = ZStudySessionConfig.fromMap(<String, dynamic>{
        'mode': 'list',
        'session_note': 'libre',
      });
      expect(config.extra['session_note'], 'libre');
      expect(config.toMap()['session_note'], 'libre');
      expect(() => config.extra['x'] = 1, throwsUnsupportedError);
    });

    test('extension gérée round-trip via parser injecté', () {
      final config = ZStudySessionConfig(extension: const _TestExt('e'));
      final back = ZStudySessionConfig.fromMap(
        config.toMap(),
        extensionParser: _TestExt.fromJsonSafe,
      );
      expect(back.extension, const _TestExt('e'));
    });

    test('extension de formatVersion non gérée → null, parent survit', () {
      final config = ZStudySessionConfig.fromMap(
        <String, dynamic>{
          'mode': 'cramming',
          'extension': <String, dynamic>{'format_version': 42},
        },
        extensionParser: _TestExt.fromJsonSafe,
      );
      expect(config.extension, isNull);
      expect(config.mode, ZReviewMode.cramming);
    });
  });

  group('ZStudySessionConfig — désérialisation défensive (AC10)', () {
    test('map vide {} → défauts sûrs', () {
      final config = ZStudySessionConfig.fromMap(const <String, dynamic>{});
      expect(config.mode, ZReviewMode.spaced);
      expect(config.folderId, isNull);
      expect(config.tagIds, isNull);
      expect(config.types, isNull);
      expect(config.count, isNull);
      expect(config.extra, isEmpty);
    });

    test('valeurs corrompues → défauts sûrs (jamais de throw)', () {
      final config = ZStudySessionConfig.fromMap(<String, dynamic>{
        'mode': 123, // non-String → spaced
        'folder_id': <int>[1], // non-String → null
        'tag_ids': 'pas une liste', // non-liste → null
        'types': 'pas une liste', // non-liste → null
        'count': 'pas un int', // non-int → null
        'extension': <dynamic>[1, 2], // non-map → null
      });
      expect(config.mode, ZReviewMode.spaced);
      expect(config.folderId, isNull);
      expect(config.tagIds, isNull);
      expect(config.types, isNull);
      expect(config.count, isNull);
      expect(config.extension, isNull);
    });
  });

  group('ZStudySessionConfig — enregistrement ZcrudRegistry (AC7)', () {
    test('registerZStudySessionConfig câble le kind "study_session_config"', () {
      final registry = ZcrudRegistry();
      registerZStudySessionConfig(registry);
      expect(registry.isRegistered('study_session_config'), isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // AD-19 (ES-1.3, finding H2 du code-review) — MIROIR du groupe kernel.
  // Les deux copies de ce test évoluent ENSEMBLE (héritage ES-1.1).
  // ─────────────────────────────────────────────────────────────────────────
  group('ZStudySessionConfig — AD-19 : clés de sync hors-entité (ES-1.3)', () {
    test('fromMap d\'une map de STORE : ni is_deleted ni updated_at dans extra',
        () {
      final config = ZStudySessionConfig.fromMap(<String, dynamic>{
        'mode': 'spaced',
        'count': 20,
        'updated_at': DateTime.utc(2026, 5, 5).toIso8601String(),
        'is_deleted': false,
        'un_champ_inconnu': 'gardé',
      });

      expect(config.extra.containsKey('is_deleted'), isFalse);
      expect(config.extra.containsKey('updated_at'), isFalse);
      expect(config.extra['un_champ_inconnu'], 'gardé');
      expect(config.count, 20);
    });

    test('toMap() ne RÉÉMET aucune clé de sync (AD-16, soft-delete hors-entité)',
        () {
      final config = ZStudySessionConfig.fromMap(<String, dynamic>{
        'mode': 'spaced',
        'updated_at': DateTime.utc(2026, 5, 5).toIso8601String(),
        'is_deleted': true,
      });

      final map = config.toMap();
      expect(map.containsKey('is_deleted'), isFalse);
      expect(map.containsKey('updated_at'), isFalse);
    });

    test('convergence : fromMap(toMap(c)) == c', () {
      final fromStore = ZStudySessionConfig.fromMap(<String, dynamic>{
        'mode': 'spaced',
        'folder_id': 'f1',
        'updated_at': DateTime.utc(2026, 5, 5).toIso8601String(),
        'is_deleted': false,
      });
      final reread = ZStudySessionConfig.fromMap(fromStore.toMap());

      expect(reread.extra, equals(fromStore.extra));
      expect(reread, equals(fromStore));
      expect(fromStore.extra, isEmpty);
    });

    test('map de sync corrompue (is_deleted: "oui", updated_at: 42) ⇒ aucun '
        'throw, aucune pollution (AD-10)', () {
      final config = ZStudySessionConfig.fromMap(<String, dynamic>{
        'mode': 'spaced',
        'updated_at': 42,
        'is_deleted': 'oui',
      });

      expect(config.mode, ZReviewMode.spaced);
      expect(config.extra, isEmpty);
      expect(config.toMap().containsKey('is_deleted'), isFalse);
    });
  });
}
