/// Tests de garde du noyau (ES-1.1, AC1/AC6/AD-10) : `ZStudySessionConfig`
/// remontée + neutralisée (`types` en `List<String>`).
///
/// Prouve : round-trip **byte-identique** au wire E9 (noms d'enum camelCase) ;
/// `types` neutre conserve toute clé String ; désérialisation défensive ; slots
/// AD-4 (`extra`/`extension`) ; enregistrement `ZcrudRegistry`.
library;

import 'package:test/test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

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
  group('ZReviewMode (remonté)', () {
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

    test('valeur inconnue → spaced (défensif, sans throw)', () {
      final config = ZStudySessionConfig.fromMap(
        <String, dynamic>{'mode': 'totallyUnknownMode'},
      );
      expect(config.mode, ZReviewMode.spaced);
    });
  });

  group('ZStudySessionConfig — round-trip byte-identique au wire E9 (AC6)', () {
    test('wire exact (types = noms d\'enum camelCase, byte-identique E9)', () {
      const config = ZStudySessionConfig(
        mode: ZReviewMode.learn,
        folderId: 'f1',
        tagIds: <String>['t1', 't2'],
        types: <String>['multipleChoice', 'trueOrFalse'],
        count: 20,
      );
      final map = config.toMap();
      // Le corpus E9 sérialisait `types` en noms d'enum camelCase : la
      // neutralisation `List<String>` produit un wire IDENTIQUE.
      expect(map, <String, dynamic>{
        'mode': 'learn',
        'folder_id': 'f1',
        'tag_ids': <String>['t1', 't2'],
        'types': <String>['multipleChoice', 'trueOrFalse'],
        'count': 20,
      });
      expect(ZStudySessionConfig.fromMap(map), config);
    });

    test('fromMap(toMap()) == config (idempotence)', () {
      const config = ZStudySessionConfig(
        mode: ZReviewMode.whiteExam,
        types: <String>['exercise'],
      );
      expect(ZStudySessionConfig.fromMap(config.toMap()), config);
    });

    test('types neutre : toute clé String survit (round-trip zéro-perte AD-10)',
        () {
      final config = ZStudySessionConfig.fromMap(<String, dynamic>{
        'types': <dynamic>['multipleChoice', 'futureUnknownType', 'exercise'],
      });
      // Aucun drop côté noyau : les clés inconnues sont conservées (le drop
      // typé vit côté flashcard).
      expect(config.types, <String>[
        'multipleChoice',
        'futureUnknownType',
        'exercise',
      ]);
      expect(config.toMap()['types'], <String>[
        'multipleChoice',
        'futureUnknownType',
        'exercise',
      ]);
    });

    test('défauts : mode spaced, filtres null', () {
      const config = ZStudySessionConfig();
      expect(config.mode, ZReviewMode.spaced);
      expect(config.folderId, isNull);
      expect(config.tagIds, isNull);
      expect(config.types, isNull);
      expect(config.count, isNull);
    });
  });

  group('ZStudySessionConfig — désérialisation défensive (AD-10)', () {
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
        'mode': 123,
        'folder_id': <int>[1],
        'tag_ids': 'pas une liste',
        'types': 'pas une liste',
        'count': 'pas un int',
        'extension': <dynamic>[1, 2],
      });
      expect(config.mode, ZReviewMode.spaced);
      expect(config.folderId, isNull);
      expect(config.tagIds, isNull);
      expect(config.types, isNull);
      expect(config.count, isNull);
      expect(config.extension, isNull);
    });

    test('types : éléments non-String filtrés', () {
      final config = ZStudySessionConfig.fromMap(<String, dynamic>{
        'types': <dynamic>['multipleChoice', 42, null, 'exercise'],
      });
      expect(config.types, <String>['multipleChoice', 'exercise']);
    });
  });

  group('ZStudySessionConfig — slots AD-4', () {
    test('extra inconnu préservé au round-trip, non-modifiable', () {
      final config = ZStudySessionConfig.fromMap(<String, dynamic>{
        'mode': 'list',
        'session_note': 'libre',
      });
      expect(config.extra['session_note'], 'libre');
      expect(config.toMap()['session_note'], 'libre');
      expect(() => config.extra['x'] = 1, throwsUnsupportedError);
    });

    test('extension round-trip via parser injecté', () {
      final config = ZStudySessionConfig(extension: const _TestExt('e'));
      final back = ZStudySessionConfig.fromMap(
        config.toMap(),
        extensionParser: _TestExt.fromJsonSafe,
      );
      expect(back.extension, const _TestExt('e'));
    });

    test('copyWith à sentinelle préserve/reset', () {
      final config = ZStudySessionConfig(
        mode: ZReviewMode.test,
        folderId: 'f1',
        extension: const _TestExt('x'),
      );
      final kept = config.copyWith(count: 5);
      expect(kept.folderId, 'f1');
      expect(kept.extension, const _TestExt('x'));
      expect(kept.count, 5);
      final cleared = config.copyWith(folderId: null);
      expect(cleared.folderId, isNull);
    });
  });

  group('ZStudySessionConfig — enregistrement ZcrudRegistry', () {
    test('registerZStudySessionConfig câble le kind "study_session_config"', () {
      final registry = ZcrudRegistry();
      registerZStudySessionConfig(registry);
      expect(registry.isRegistered('study_session_config'), isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // AD-19 (ES-1.3, finding H1/H2 du code-review) — NON-RÉGRESSION.
  //
  // ⚠️ SI CE GROUPE TOMBE : `_reservedKeys` a perdu `...ZSyncMeta.reservedKeys`.
  // Les clés de sync (propriété du STORE) repollueraient `extra` (AD-4) et
  // seraient RÉÉMISES par `toMap()` (AD-16). `ZStudySessionConfig` est le patron
  // canonique du NOYAU : toute entité d'ES-2 le copiera.
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
      // Round-trip AD-4 des clés VRAIMENT inconnues : non régressé.
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
      expect(map.containsKey('isDeleted'), isFalse);
    });

    test('convergence : fromMap(toMap(c)) == c (l\'== n\'est plus cassée entre '
        'une config en mémoire et la même relue du store)', () {
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
