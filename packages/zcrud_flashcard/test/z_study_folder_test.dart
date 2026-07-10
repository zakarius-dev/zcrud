/// Tests E9-3 : entité `ZStudyFolder` (AC2/AC3/AC4/AC5/AC6/AC10/AC11).
///
/// Couvre : round-trip zéro-perte (snake_case), `isArchived` + réversibilité du
/// soft-archive, absence de `is_deleted`, `updatedAt` DANS l'entité (LWW), bloc
/// partage V2c inerte, slots AD-4 (`extra` + `extension` défensifs),
/// `relatedTopics`/`countryCode` via `extra`, désérialisation défensive réelle
/// (maps corrompues), enregistrement `ZcrudRegistry`.
///
/// Exécuté via `flutter test` (le domaine réutilise
/// `package:zcrud_core/zcrud_core.dart`, qui tire le SDK Flutter).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

/// Extension de test concrète (AD-4) : `formatVersion` géré = 1 ; toute autre
/// version → `null` via `fromJsonSafe` (le parent survit).
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
  group('ZStudyFolder — round-trip codegen (AC2)', () {
    test('round-trip complet zéro-perte (snake_case)', () {
      final folder = ZStudyFolder(
        id: 'f1',
        title: 'Douane',
        colorKey: 'blue',
        parentId: 'root',
        ownerId: 'uid-42',
        archivedAt: DateTime.utc(2026, 3, 1, 10),
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 2, 2),
      );
      final map = folder.toMap();
      // Clés snake_case.
      expect(map['color_key'], 'blue');
      expect(map['parent_id'], 'root');
      expect(map['owner_id'], 'uid-42');
      expect(map['archived_at'], DateTime.utc(2026, 3, 1, 10).toIso8601String());
      expect(map['created_at'], DateTime.utc(2026, 1, 1).toIso8601String());
      expect(map['updated_at'], DateTime.utc(2026, 2, 2).toIso8601String());
      // Round-trip.
      expect(ZStudyFolder.fromMap(map), folder);
    });

    test('isEphemeral dérivé de ZEntity (id == null)', () {
      expect(const ZStudyFolder(title: 't').isEphemeral, isTrue);
      expect(const ZStudyFolder(id: 'x', title: 't').isEphemeral, isFalse);
    });

    test('title requis projeté dans le ZFieldSpec (validateur)', () {
      final titleSpec =
          $ZStudyFolderFieldSpecs.firstWhere((s) => s.name == 'title');
      expect(titleSpec.validators, isNotEmpty);
    });
  });

  group('ZStudyFolder — soft-archive réversible (AC5)', () {
    test('archivedAt fixée ⇒ isArchived == true + round-trip', () {
      final folder = ZStudyFolder(
        title: 't',
        archivedAt: DateTime.utc(2026, 5, 5),
      );
      expect(folder.isArchived, isTrue);
      final back = ZStudyFolder.fromMap(folder.toMap());
      expect(back.isArchived, isTrue);
      expect(back.archivedAt, DateTime.utc(2026, 5, 5));
    });

    test('archivedAt null ⇒ isArchived == false', () {
      expect(const ZStudyFolder(title: 't').isArchived, isFalse);
    });

    test('désarchivage réversible via copyWith(archivedAt: null) (sentinelle)',
        () {
      final archived =
          ZStudyFolder(title: 't', archivedAt: DateTime.utc(2026, 5, 5));
      final unarchived = archived.copyWith(archivedAt: null);
      expect(unarchived.isArchived, isFalse);
      expect(unarchived.archivedAt, isNull);
      // copyWith sans argument préserve archivedAt.
      final renamed = archived.copyWith(title: 'u');
      expect(renamed.isArchived, isTrue);
    });

    test('toMap ne produit AUCUNE clé is_deleted (soft-delete hors-entité)', () {
      final map = ZStudyFolder(
        title: 't',
        archivedAt: DateTime.utc(2026, 5, 5),
      ).toMap();
      expect(map.containsKey('is_deleted'), isFalse);
      expect(map.containsKey('isDeleted'), isFalse);
    });
  });

  group('ZStudyFolder — updatedAt DANS l\'entité (AC6, LWW)', () {
    test('updatedAt round-trip zéro-perte', () {
      final folder =
          ZStudyFolder(title: 't', updatedAt: DateTime.utc(2026, 9, 9, 8, 7));
      final back = ZStudyFolder.fromMap(folder.toMap());
      expect(back.updatedAt, DateTime.utc(2026, 9, 9, 8, 7));
    });
  });

  group('ZStudyFolder — bloc partage V2c inerte (AC4)', () {
    test('défauts sûrs', () {
      const folder = ZStudyFolder(title: 't');
      expect(folder.isPublic, isFalse);
      expect(folder.sharedWith, isEmpty);
      expect(folder.canBeJoinedWithLink, isFalse);
      expect(folder.coWorkersCanInviteOthers, isFalse);
      expect(folder.shareId, isNull);
    });

    test('round-trip du bloc V2c avec valeurs non-défaut (snake_case)', () {
      final folder = ZStudyFolder(
        title: 't',
        isPublic: true,
        sharedWith: const <String>['a', 'b'],
        canBeJoinedWithLink: true,
        coWorkersCanInviteOthers: true,
        shareId: 'share-9',
      );
      final map = folder.toMap();
      expect(map['is_public'], true);
      expect(map['shared_with'], <String>['a', 'b']);
      expect(map['can_be_joined_with_link'], true);
      expect(map['co_workers_can_invite_others'], true);
      expect(map['share_id'], 'share-9');
      expect(ZStudyFolder.fromMap(map), folder);
    });
  });

  group('ZStudyFolder — slots AD-4 extra/extension (AC3)', () {
    test('extra inconnu préservé au round-trip, non-modifiable', () {
      final folder = ZStudyFolder.fromMap(<String, dynamic>{
        'title': 't',
        'related_topics': <String>['tva', 'droits'],
        'folder_explanation': 'note libre',
        'country_code': 'NE',
      });
      expect(folder.extra['related_topics'], <String>['tva', 'droits']);
      expect(folder.extra['folder_explanation'], 'note libre');
      expect(folder.extra['country_code'], 'NE');
      // Round-trip : les clés inconnues ressortent.
      final map = folder.toMap();
      expect(map['country_code'], 'NE');
      expect(map['related_topics'], <String>['tva', 'droits']);
      // Non-modifiable.
      expect(() => folder.extra['x'] = 1, throwsUnsupportedError);
    });

    test('extension gérée round-trip via parser injecté', () {
      final folder = ZStudyFolder(title: 't', extension: const _TestExt('hi'));
      final map = folder.toMap();
      final back = ZStudyFolder.fromMap(
        map,
        extensionParser: _TestExt.fromJsonSafe,
      );
      expect(back.extension, const _TestExt('hi'));
    });

    test('extension de formatVersion non gérée → null, parent survit', () {
      final folder = ZStudyFolder.fromMap(
        <String, dynamic>{
          'title': 't',
          'extension': <String, dynamic>{'format_version': 99, 'note': 'x'},
        },
        extensionParser: _TestExt.fromJsonSafe,
      );
      expect(folder.extension, isNull);
      expect(folder.title, 't');
    });

    test('extra ne contient jamais les clés réservées (champs générés)', () {
      final folder = ZStudyFolder.fromMap(<String, dynamic>{
        'title': 't',
        'color_key': 'red',
        'unknown': 1,
      });
      expect(folder.extra.containsKey('title'), isFalse);
      expect(folder.extra.containsKey('color_key'), isFalse);
      expect(folder.extra['unknown'], 1);
    });
  });

  group('ZStudyFolder — désérialisation défensive (AC10, gate E2-10)', () {
    test('map vide {} → défauts sûrs, jamais de throw', () {
      final folder = ZStudyFolder.fromMap(const <String, dynamic>{});
      expect(folder.title, '');
      expect(folder.ownerId, '');
      expect(folder.colorKey, '');
      expect(folder.parentId, isNull);
      expect(folder.archivedAt, isNull);
      expect(folder.createdAt, isNull);
      expect(folder.updatedAt, isNull);
      expect(folder.isPublic, isFalse);
      expect(folder.sharedWith, isEmpty);
      expect(folder.canBeJoinedWithLink, isFalse);
      expect(folder.coWorkersCanInviteOthers, isFalse);
      expect(folder.shareId, isNull);
      expect(folder.extension, isNull);
      expect(folder.extra, isEmpty);
    });

    test('champs illisibles → défauts sûrs (jamais de throw)', () {
      final folder = ZStudyFolder.fromMap(<String, dynamic>{
        'title': 123, // non-String → ''
        'parent_id': <int>[1], // non-String → null
        'archived_at': 'pas une date', // illisible → null
        'created_at': 42, // illisible → null
        'shared_with': 'pas une liste', // non-liste → const []
        'is_public': 'oui', // non-bool → false
      });
      expect(folder.title, '');
      expect(folder.parentId, isNull);
      expect(folder.archivedAt, isNull);
      expect(folder.createdAt, isNull);
      expect(folder.sharedWith, isEmpty);
      expect(folder.isPublic, isFalse);
    });

    test('extension corrompue (non-map) → null, parent survit', () {
      final folder = ZStudyFolder.fromMap(
        <String, dynamic>{'title': 't', 'extension': 'corrompu'},
        extensionParser: _TestExt.fromJsonSafe,
      );
      expect(folder.extension, isNull);
      expect(folder.title, 't');
    });
  });

  group('ZStudyFolder — enregistrement ZcrudRegistry (AC2)', () {
    test('registerZStudyFolder câble le kind "study_folder"', () {
      final registry = ZcrudRegistry();
      registerZStudyFolder(registry);
      expect(registry.isRegistered('study_folder'), isTrue);
    });
  });
}
