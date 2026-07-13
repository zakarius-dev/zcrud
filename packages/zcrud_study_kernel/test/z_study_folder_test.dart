/// Tests de garde du noyau (ES-1.1, AC1) : `ZStudyFolder` remonté verbatim.
///
/// Prouve le portage : round-trip zéro-perte, défauts défensifs, slots AD-4,
/// soft-archive, enregistrement `ZcrudRegistry`.
library;

import 'package:test/test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

void main() {
  group('ZStudyFolder — round-trip (AC1)', () {
    test('round-trip complet zéro-perte (snake_case)', () {
      final folder = ZStudyFolder(
        id: 'id1',
        title: 'Dossier',
        colorKey: 'blue',
        parentId: 'p1',
        ownerId: 'u1',
        createdAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
        // Miroir de compat (AD-19) : exercé VOLONTAIREMENT (lecture legacy).
        // ignore: deprecated_member_use
        updatedAt: DateTime.utc(2026, 6, 7, 8, 9, 10),
      );
      final map = folder.toMap();
      expect(map['title'], 'Dossier');
      expect(map['color_key'], 'blue');
      expect(map['parent_id'], 'p1');
      expect(map['owner_id'], 'u1');
      // Aucune clé de soft-delete (AD-16 : is_deleted hors-entité).
      expect(map.containsKey('is_deleted'), isFalse);
      expect(ZStudyFolder.fromMap(map), folder);
    });

    test('défauts sûrs sur map minimale (défensif AD-10)', () {
      final folder = ZStudyFolder.fromMap(const <String, dynamic>{});
      expect(folder.title, '');
      expect(folder.ownerId, '');
      expect(folder.colorKey, '');
      expect(folder.isPublic, isFalse);
      expect(folder.sharedWith, isEmpty);
      expect(folder.parentId, isNull);
    });

    test('soft-archive réversible (isArchived)', () {
      const active = ZStudyFolder(title: 't');
      expect(active.isArchived, isFalse);
      final archived = active.copyWith(archivedAt: DateTime.utc(2026));
      expect(archived.isArchived, isTrue);
      final restored = archived.copyWith(archivedAt: null);
      expect(restored.isArchived, isFalse);
    });

    test('extra inconnu préservé au round-trip (AD-4)', () {
      final folder = ZStudyFolder.fromMap(<String, dynamic>{
        'title': 't',
        'related_topics': <String>['x'],
      });
      expect(folder.extra['related_topics'], <String>['x']);
      expect(folder.toMap()['related_topics'], <String>['x']);
    });

    test('registerZStudyFolder câble le kind "study_folder"', () {
      final registry = ZcrudRegistry();
      registerZStudyFolder(registry);
      expect(registry.isRegistered('study_folder'), isTrue);
    });
  });

  // ES-1.3 (AC4/AC5) — les clés de sync appartiennent au STORE, pas au domaine.
  // Les stores écrivent `updated_at`/`is_deleted` DANS le corps du document
  // (cf. `hive_z_local_store.dart` `_encode`) puis passent la map COMPLÈTE à
  // `fromMap`. L'entité ne doit ni les capturer dans `extra`, ni les réémettre.
  group('ZStudyFolder — AD-19 : clés de sync hors-entité (ES-1.3)', () {
    test('fromMap d\'une map de STORE : ni is_deleted ni updated_at dans extra',
        () {
      final folder = ZStudyFolder.fromMap(<String, dynamic>{
        'id': 'f1',
        'title': 't',
        'updated_at': DateTime.utc(2026, 5, 5).toIso8601String(),
        'is_deleted': true,
        'related_topics': <String>['tva'],
      });

      expect(folder.extra.containsKey('is_deleted'), isFalse);
      expect(folder.extra.containsKey('updated_at'), isFalse);
      // Le round-trip AD-4 des clés VRAIMENT inconnues n'est pas régressé.
      expect(folder.extra['related_topics'], <String>['tva']);
      // Le miroir de compat reste peuplé (lecture legacy, AD-10).
      // ignore: deprecated_member_use
      expect(folder.updatedAt, DateTime.utc(2026, 5, 5));
    });

    test('toMap() n\'émet JAMAIS is_deleted, même relu depuis une map de store',
        () {
      final folder = ZStudyFolder.fromMap(<String, dynamic>{
        'title': 't',
        'is_deleted': true,
      });
      final map = folder.toMap();
      expect(map.containsKey('is_deleted'), isFalse);
      expect(map.containsKey('isDeleted'), isFalse);
    });

    test('convergence : fromMap(toMap(f)).extra == f.extra (et == de l\'entité)',
        () {
      final fromStore = ZStudyFolder.fromMap(<String, dynamic>{
        'id': 'f1',
        'title': 't',
        'updated_at': DateTime.utc(2026, 5, 5).toIso8601String(),
        'is_deleted': false,
        'country_code': 'NE',
      });
      final reread = ZStudyFolder.fromMap(fromStore.toMap());
      expect(reread.extra, equals(fromStore.extra));
      expect(reread, equals(fromStore));
    });

    test('round-trip LEGACY : map d\'avant AD-19 (updated_at, PAS de is_deleted)'
        ' reste entièrement lisible', () {
      final legacy = <String, dynamic>{
        'id': 'legacy-1',
        'title': 'Dossier legacy',
        'color_key': 'blue',
        'created_at': DateTime.utc(2024).toIso8601String(),
        'updated_at': DateTime.utc(2025, 3, 3).toIso8601String(),
        'folder_explanation': 'note libre',
        'un_champ_futur_inconnu': 42,
      };
      final folder = ZStudyFolder.fromMap(legacy);

      expect(folder.id, 'legacy-1');
      expect(folder.title, 'Dossier legacy');
      expect(folder.colorKey, 'blue');
      // Miroir de compat peuplé — aucune donnée existante ne devient illisible.
      // ignore: deprecated_member_use
      expect(folder.updatedAt, DateTime.utc(2025, 3, 3));
      // Clés inconnues préservées (AD-4/AD-10, évolution additive seulement).
      expect(folder.extra['folder_explanation'], 'note libre');
      expect(folder.extra['un_champ_futur_inconnu'], 42);
      expect(folder.toMap()['un_champ_futur_inconnu'], 42);
    });

    test('map de sync CORROMPUE (is_deleted: "oui", updated_at: 42) ⇒ aucun '
        'throw, aucune pollution (AD-10)', () {
      final folder = ZStudyFolder.fromMap(<String, dynamic>{
        'title': 't',
        'updated_at': 42,
        'is_deleted': 'oui',
      });
      expect(folder.title, 't');
      // ignore: deprecated_member_use
      expect(folder.updatedAt, isNull);
      expect(folder.extra, isEmpty);
    });

    test('AC5-bis : le miroir n\'a AUCUN pouvoir d\'écriture — l\'estampille du '
        'store l\'ÉCRASE', () {
      // Le miroir MENT : 2030.
      final folder = ZStudyFolder(
        id: 'f1',
        title: 't',
        // ignore: deprecated_member_use
        updatedAt: DateTime.utc(2030),
      );
      final storeStamp = DateTime.utc(2026, 1, 1).toIso8601String();

      // Simulation du contrat d'encodage du store (l'entité ne peut pas dépendre
      // de `zcrud_firestore` — AD-1). Ordre REPRODUIT de
      // `packages/zcrud_firestore/lib/src/data/hive_z_local_store.dart` `_encode`
      // (`map = Map.of(_toMap(value))` PUIS `map[_kUpdatedAt] = ...`) : la méta
      // est écrite APRÈS le corps, donc elle écrase systématiquement le miroir.
      final encoded = <String, dynamic>{
        ...folder.toMap(),
        ZSyncMeta.kUpdatedAt: storeStamp,
        ZSyncMeta.kIsDeleted: false,
      };

      expect(encoded[ZSyncMeta.kUpdatedAt], storeStamp);
      expect(encoded[ZSyncMeta.kUpdatedAt],
          isNot(DateTime.utc(2030).toIso8601String()));
      // L'autorité de merge lit la méta, qui ignore le miroir.
      expect(ZSyncMeta.fromJson(encoded).updatedAt, DateTime.utc(2026, 1, 1));
      // Et la relecture ne pollue toujours pas `extra`.
      expect(ZStudyFolder.fromMap(encoded).extra, isEmpty);
    });
  });
}
