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
    test('round-trip complet zéro-perte (snake_case)', () {
      final config = ZStudySessionConfig(
        mode: ZReviewMode.learn,
        folderId: 'f1',
        tagIds: const <String>['t1', 't2'],
        types: const <ZFlashcardType>[
          ZFlashcardType.multipleChoice,
          ZFlashcardType.trueOrFalse,
        ],
        count: 20,
      );
      final map = config.toMap();
      expect(map['mode'], 'learn');
      expect(map['folder_id'], 'f1');
      expect(map['tag_ids'], <String>['t1', 't2']);
      expect(map['types'], <String>['multipleChoice', 'trueOrFalse']);
      expect(map['count'], 20);
      expect(ZStudySessionConfig.fromMap(map), config);
    });

    test('défauts : mode spaced, filtres null (= pas de filtre)', () {
      const config = ZStudySessionConfig();
      expect(config.mode, ZReviewMode.spaced);
      expect(config.folderId, isNull);
      expect(config.tagIds, isNull);
      expect(config.types, isNull);
      expect(config.count, isNull);
    });

    test('types avec élément inconnu → décodé défensivement (ignoré)', () {
      final config = ZStudySessionConfig.fromMap(<String, dynamic>{
        'types': <dynamic>['multipleChoice', 'totallyUnknownType', 'exercise'],
      });
      expect(config.types, <ZFlashcardType>[
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
}
