/// Tests de `ZStudyPodcast` (`ZExtensible`, patron ES-2.2b) — ES-2.8, FR-S11,
/// AC1..AC8/AC13.
///
/// ⚠️ **Aucun `dart:io`** (AC15) : le kernel est pur-Dart, ses tests tournent
/// sous `dart test` **ET** `dart test -p node`. Tout `DateTime` est construit en
/// `DateTime.utc(...)` explicite (JS-safe) — jamais `DateTime.now()`.
///
/// 🔴 Le cœur de FR-S11 est l'invalidation *content-addressed* PURE : `isStale`
/// et `podcastFreshness` sont prouvés **BIDIRECTIONNELLEMENT** (varier les DEUX
/// empreintes — leçon ES-2.3 : un golden figé serait POWERLESS).
library;

import 'package:test/test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

/// Extension type de test (AD-4 pt.1) — round-trip d'un slot `extension` typé.
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
    return ZExtension.guard<ZExtension?>(() => _TestExt(json['note'] as String));
  }

  @override
  bool operator ==(Object other) =>
      other is _TestExt && note == other.note && formatVersion == 1;

  @override
  int get hashCode => Object.hash(note, formatVersion);
}

void main() {
  group('ZStudyPodcast — modèle & défauts (AC1)', () {
    test('valeurs par défaut : id null, enums 1ʳᵉ constante, chaînes vides', () {
      const p = ZStudyPodcast();
      expect(p.id, isNull);
      expect(p.sourceKind, ZPodcastSourceKind.note);
      expect(p.sourceId, '');
      expect(p.folderId, '');
      expect(p.mode, ZPodcastMode.simple);
      expect(p.sourceHash, '');
      expect(p.resultRef, '');
      expect(p.status, ZPodcastStatus.ready);
      expect(p.createdAt, isNull);
      expect(p.extension, isNull);
      expect(p.extra, isEmpty);
      expect(p.isEphemeral, isTrue); // id == null (ZEntity, AD-14)
    });
  });

  group('ZStudyPodcast — round-trip défensif (AC2/AC3/AC14)', () {
    test('round-trip PLEIN idempotent : fromMap(toMap(x)) == x', () {
      final p = ZStudyPodcast(
        id: 'p1',
        sourceKind: ZPodcastSourceKind.document,
        sourceId: 's1',
        folderId: 'f1',
        mode: ZPodcastMode.dialogue,
        sourceHash: 'h-A',
        resultRef: 'gs://blob',
        status: ZPodcastStatus.failed,
        createdAt: DateTime.utc(2026, 7, 20),
      );
      final rt = ZStudyPodcast.fromMap(p.toMap());
      expect(rt, equals(p));
      expect(rt.hashCode, equals(p.hashCode));
    });

    test('anti-golden FORTUIT : varier sourceHash rend les instances INÉGALES',
        () {
      final a = ZStudyPodcast(
        sourceKind: ZPodcastSourceKind.document,
        mode: ZPodcastMode.dialogue,
        sourceHash: 'h-A',
        status: ZPodcastStatus.failed,
        createdAt: DateTime.utc(2026, 7, 20),
      );
      final b = a.copyWith(sourceHash: 'h-B');
      // Prouve que `==` DÉPEND RÉELLEMENT de sourceHash (pas un `true` fortuit).
      expect(a, isNot(equals(b)));
      // …et que le round-trip transporte bien l'empreinte (perte ⇒ ROUGE).
      expect(ZStudyPodcast.fromMap(b.toMap()).sourceHash, 'h-B');
    });

    test('clés persistées snake_case + enums camelCase `name`', () {
      final p = ZStudyPodcast(
        id: 'p',
        sourceKind: ZPodcastSourceKind.folder,
        sourceId: 's',
        folderId: 'f',
        mode: ZPodcastMode.dialogue,
        sourceHash: 'h',
        resultRef: 'r',
        status: ZPodcastStatus.stale,
        createdAt: DateTime.utc(2026, 7, 20),
      );
      final map = p.toMap();
      expect(map['id'], 'p');
      expect(map['source_kind'], 'folder');
      expect(map['source_id'], 's');
      expect(map['folder_id'], 'f');
      expect(map['mode'], 'dialogue');
      expect(map['source_hash'], 'h');
      expect(map['result_ref'], 'r');
      expect(map['status'], 'stale');
      expect(map['created_at'], '2026-07-20T00:00:00.000Z');
    });

    test('fromMap(const {}) ne throw pas et rend les défauts', () {
      expect(() => ZStudyPodcast.fromMap(const <String, dynamic>{}),
          returnsNormally);
      final p = ZStudyPodcast.fromMap(const <String, dynamic>{});
      expect(p.id, isNull);
      expect(p.sourceKind, ZPodcastSourceKind.note);
      expect(p.mode, ZPodcastMode.simple);
      expect(p.status, ZPodcastStatus.ready);
      expect(p.sourceId, '');
      expect(p.folderId, '');
      expect(p.sourceHash, '');
      expect(p.resultRef, '');
      expect(p.createdAt, isNull);
    });

    test('fixture d\'échec ISOLÉE (R2) : valeurs corrompues ⇒ défauts, no throw',
        () {
      final p = ZStudyPodcast.fromMap(<String, dynamic>{
        'source_kind': 'zzz',
        'mode': 'zzz',
        'status': 'zzz',
        'created_at': 'pas-une-date',
      });
      expect(p.sourceKind, ZPodcastSourceKind.note);
      expect(p.mode, ZPodcastMode.simple);
      expect(p.status, ZPodcastStatus.ready);
      expect(p.createdAt, isNull);
    });

    test('chaînes non-String ⇒ défaut vide (défensif)', () {
      final p = ZStudyPodcast.fromMap(<String, dynamic>{
        'source_id': 42,
        'folder_id': <String>['x'],
        'source_hash': <String, dynamic>{'k': 1},
        'result_ref': true,
      });
      expect(p.sourceId, '');
      expect(p.folderId, '');
      expect(p.sourceHash, '');
      expect(p.resultRef, '');
    });

    test('slot extension typé round-trippé ; corrompu ⇒ null (parent survit)',
        () {
      const p = ZStudyPodcast(sourceId: 's', extension: _TestExt('hello'));
      final map = p.toMap();
      expect((map['extension'] as Map)['note'], 'hello');
      final rt = ZStudyPodcast.fromMap(map, extensionParser: _TestExt.fromJsonSafe);
      expect(rt.extension, const _TestExt('hello'));

      final bad = ZStudyPodcast.fromMap(
        <String, dynamic>{'source_id': 's', 'extension': 'pas-une-map'},
        extensionParser: _TestExt.fromJsonSafe,
      );
      expect(bad.extension, isNull);
      expect(bad.sourceId, 's');
    });
  });

  group('ZStudyPodcast — copyWith à sentinelle (AC4)', () {
    test('argument omis préserve ; null explicite remet à null', () {
      final p = ZStudyPodcast(
        id: 'p',
        sourceId: 's',
        mode: ZPodcastMode.dialogue,
        sourceHash: 'h-A',
        createdAt: DateTime.utc(2026, 7, 20),
        extra: const <String, dynamic>{'k': 1},
      );
      final c = p.copyWith(sourceHash: 'h-B');
      expect(c.sourceHash, 'h-B');
      expect(c.id, 'p'); // préservé
      expect(c.mode, ZPodcastMode.dialogue); // préservé
      expect(c.extra, <String, dynamic>{'k': 1}); // préservé
      // null explicite sur un nullable.
      expect(p.copyWith(createdAt: null).createdAt, isNull);
      expect(p.copyWith(id: null).id, isNull);
    });

    test('injection R3 (garde partagée H2) : copyWith(extra:) NE ROUVRE PAS le '
        'filtre des clés réservées', () {
      const p = ZStudyPodcast(sourceId: 's');
      final c = p.copyWith(
        extra: <String, dynamic>{'is_deleted': true, 'updated_at': 'X', 'k': 'v'},
      );
      expect(c.extra.containsKey('is_deleted'), isFalse);
      expect(c.extra.containsKey('updated_at'), isFalse);
      expect(c.extra['k'], 'v');
      expect(c.toMap().containsKey('is_deleted'), isFalse);
    });
  });

  group('ZStudyPodcast — gardes extra ES-2.2b MESURÉES (AC5)', () {
    test('pollution ctor `const` NEUTRALISÉE par l\'accesseur normalisant', () {
      const p = ZStudyPodcast(
        sourceId: 's',
        extra: <String, dynamic>{'updated_at': 'X', 'k': 1},
      );
      expect(p.extra, <String, dynamic>{'k': 1});
      // Convergence : entité polluée en mémoire == la même relue du store.
      expect(ZStudyPodcast.fromMap(p.toMap()), equals(p));
    });

    test('sonde de STORE : is_deleted/updated_at hors extra + non réémis', () {
      final p = ZStudyPodcast.fromMap(<String, dynamic>{
        'id': 'p',
        'source_id': 's',
        'source_hash': 'h',
        'updated_at': '2026-01-01T00:00:00.000Z',
        'is_deleted': true,
        'zz_cle_inconnue': 'gardee',
      });
      expect(
        p.extra.keys.toSet().intersection(ZSyncMeta.reservedKeys),
        isEmpty,
      );
      expect(p.extra['zz_cle_inconnue'], 'gardee'); // anti-vacuité
      final map = p.toMap();
      expect(map.containsKey('updated_at'), isFalse);
      expect(map.containsKey('is_deleted'), isFalse);
      expect(map['zz_cle_inconnue'], 'gardee');
    });

    test('égalité PROFONDE sur extra imbriqué (DW-ES22-4)', () {
      const a = ZStudyPodcast(
        sourceId: 's',
        extra: <String, dynamic>{
          'a': <String, dynamic>{'b': 1},
        },
      );
      const b = ZStudyPodcast(
        sourceId: 's',
        extra: <String, dynamic>{
          'a': <String, dynamic>{'b': 1},
        },
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('ZStudyPodcast — buildId content-addressed PUR (AC6)', () {
    test('pouvoir discriminant OBSERVÉ (R2) : (sourceId, mode) distincts ⇒ ids '
        'distincts', () {
      expect(ZStudyPodcast.buildId('s1', ZPodcastMode.simple), 's1_simple');
      expect(ZStudyPodcast.buildId('s1', ZPodcastMode.dialogue), 's1_dialogue');
      expect(ZStudyPodcast.buildId('s2', ZPodcastMode.simple), 's2_simple');
      // Trois ids DISTINCTS (un littéral constant les ferait collisionner — R3).
      final ids = <String>{
        ZStudyPodcast.buildId('s1', ZPodcastMode.simple),
        ZStudyPodcast.buildId('s1', ZPodcastMode.dialogue),
        ZStudyPodcast.buildId('s2', ZPodcastMode.simple),
      };
      expect(ids.length, 3);
    });

    test('l\'entité n\'assigne JAMAIS id (AD-14) — buildId est le seul chemin', () {
      const p = ZStudyPodcast(sourceId: 's1', mode: ZPodcastMode.dialogue);
      expect(p.id, isNull);
      // Le repo matérialiserait : buildId(p.sourceId, p.mode).
      expect(ZStudyPodcast.buildId(p.sourceId, p.mode), 's1_dialogue');
    });
  });

  group('ZStudyPodcast — isStale : COMPARAISON PURE bidirectionnelle (AC7)', () {
    test('source A : isStale(B) == true, isStale(A) == false', () {
      const p = ZStudyPodcast(sourceId: 's', sourceHash: 'h-A');
      expect(p.isStale('h-B'), isTrue); // source changée
      expect(p.isStale('h-A'), isFalse); // source inchangée
    });

    test('VARIER l\'empreinte stockée (symétrie) : source B ⇒ isStale(A) == true',
        () {
      const p = ZStudyPodcast(sourceId: 's', sourceHash: 'h-B');
      expect(p.isStale('h-A'), isTrue);
      expect(p.isStale('h-B'), isFalse);
      // Prouve que la sortie dépend AUSSI de sourceHash (pas d'un B figé).
    });

    test('R3 — un retour constant (false OU true) ROUGIRAIT dans un sens', () {
      // Documente l'injection : `=> false` casse le cas true ; `=> true` casse
      // le cas false. Les DEUX assertions ci-dessous mordent (pouvoir bi-dir).
      const p = ZStudyPodcast(sourceHash: 'h-A');
      expect(p.isStale('h-B'), isTrue); // `=> false` échouerait ici
      expect(p.isStale('h-A'), isFalse); // `=> true` échouerait ici
    });
  });

  group('ZStudyPodcast — podcastFreshness PURE, 5 bords (AC8)', () {
    test('parité lex : absent / fresh / stale', () {
      expect(
        podcastFreshness(storedHash: null, currentSourceHash: 'h'),
        ZPodcastFreshness.absent,
      );
      expect(
        podcastFreshness(storedHash: '', currentSourceHash: ''),
        ZPodcastFreshness.absent,
      );
      expect(
        podcastFreshness(storedHash: 'h', currentSourceHash: 'h'),
        ZPodcastFreshness.fresh,
      );
      expect(
        podcastFreshness(storedHash: 'h-A', currentSourceHash: 'h-B'),
        ZPodcastFreshness.stale,
      );
      expect(
        podcastFreshness(storedHash: 'h', currentSourceHash: null),
        ZPodcastFreshness.stale,
      );
    });

    test('bidirectionnel (anti-golden ES-2.3) : la sortie dépend des DEUX hash',
        () {
      // Même storedHash, currentSourceHash qui varie ⇒ fresh puis stale.
      expect(
        podcastFreshness(storedHash: 'x', currentSourceHash: 'x'),
        ZPodcastFreshness.fresh,
      );
      expect(
        podcastFreshness(storedHash: 'x', currentSourceHash: 'y'),
        ZPodcastFreshness.stale,
      );
      // Même currentSourceHash, storedHash qui varie ⇒ stale puis fresh.
      expect(
        podcastFreshness(storedHash: 'a', currentSourceHash: 'z'),
        ZPodcastFreshness.stale,
      );
      expect(
        podcastFreshness(storedHash: 'z', currentSourceHash: 'z'),
        ZPodcastFreshness.fresh,
      );
    });

    test('R3 — retirer la garde `storedHash vide/null → absent` ROUGIRAIT', () {
      // Sans la garde, (null, 'h') retournerait `stale` : on épingle `absent`.
      expect(
        podcastFreshness(storedHash: null, currentSourceHash: 'h'),
        ZPodcastFreshness.absent,
      );
      expect(
        podcastFreshness(storedHash: '', currentSourceHash: 'h'),
        ZPodcastFreshness.absent,
      );
    });

    test('TOTALE : aucun couple ne throw', () {
      for (final s in <String?>[null, '', 'h']) {
        for (final c in <String?>[null, '', 'h', 'other']) {
          expect(
            () => podcastFreshness(storedHash: s, currentSourceHash: c),
            returnsNormally,
          );
        }
      }
    });
  });

  group('ZStudyPodcast — AD-19 : \$FieldSpecs ∩ ZSyncMeta.reservedKeys == {} '
      '(AC13)', () {
    test('aucun champ de schéma ne collisionne avec une clé de sync', () {
      final specNames = $ZStudyPodcastFieldSpecs.map((s) => s.name).toSet();
      expect(specNames.intersection(ZSyncMeta.reservedKeys), isEmpty);
    });

    test('aucun champ nommé updated_at / is_deleted (extraits hors-entité)', () {
      final specNames = $ZStudyPodcastFieldSpecs.map((s) => s.name).toSet();
      expect(specNames, isNot(contains('updated_at')));
      expect(specNames, isNot(contains('is_deleted')));
    });

    test('aucun champ timestamp réservé (AD-19.1.b)', () {
      expect(
        $ZStudyPodcastTimestampFields.intersection(ZSyncMeta.reservedKeys),
        isEmpty,
      );
    });
  });
}
