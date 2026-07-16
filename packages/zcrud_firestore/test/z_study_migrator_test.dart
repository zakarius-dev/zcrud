@Tags(<String>['serialization-compat'])
library;

/// Migrateur de CORPUS legacy IFFD flat→canonique (ES-11.2, AD-27/AD-19/AD-10).
///
/// Exécuté par le slot de gate de merge `verify:serialization`
/// (`flutter test --tags serialization-compat`) : ce corpus PROUVE sans perte la
/// migration d'un corpus RÉ-ENTRANT (chaque garde naît avec sa fixture d'échec ;
/// injections R3-I1..I6 documentées ★ en commentaire).
///
/// **Fixtures = SYNTHÉTIQUES** (`test/fixtures/iffd_legacy/*.json`) — AUCUNE
/// donnée IFFD réelle. **Confinement** : `zcrud_firestore` n'a AUCUNE arête vers
/// un package d'entité (AD-1) ; l'entité de décodage end-to-end est un double de
/// test `_StudyDouble` (aucune arête neuve) ; les statuts sont assertés par
/// **noms d'enum String** (pas d'import `ZDocumentStatus`).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';

// ───────────────────────── Chargement des fixtures ─────────────────────────

Map<String, dynamic> _fixture(String name) {
  final file = File('test/fixtures/iffd_legacy/$name.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

// ───────────────── Entité de décodage défensive (double de test) ───────────

/// Entité minimale décodant la forme canonique (snake_case) produite par le
/// migrateur. `fromMap` **DÉFENSIF** (AD-10). Les clés de sync réservées
/// ([ZSyncMeta.reservedKeys]) sont **retirées** du corps AVANT capture d'`extra`
/// (contrat AD-19 : `updated_at`/`is_deleted` sont hors-entité, jamais dans
/// `extra`) ; `toMap` ne les réémet donc jamais. Vit ENTIÈREMENT dans le test.
class _StudyDouble extends ZEntity {
  const _StudyDouble({this.id, this.status, required this.extra});

  @override
  final String? id;

  /// Nom d'enum canonique (String), jamais l'enum réel (aucune arête neuve).
  final String? status;

  /// Échappatoire des clés inconnues — DOIT exclure les clés de sync (AD-19).
  final Map<String, dynamic> extra;

  static const Set<String> _known = <String>{'id', 'status'};

  static _StudyDouble fromMap(Map<String, dynamic> map) {
    // AD-19 : le corps métier n'inclut JAMAIS les clés de sync réservées.
    final body = ZSyncMeta.stripReserved(map);
    return _StudyDouble(
      id: body['id'] is String ? body['id'] as String : null,
      status: body['status'] is String ? body['status'] as String : null,
      extra: <String, dynamic>{
        for (final e in body.entries)
          if (!_known.contains(e.key)) e.key: e.value,
      },
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        if (id != null) 'id': id,
        if (status != null) 'status': status,
        ...extra,
      };
}

// ───────────────────────── Le migrateur sous test ─────────────────────────

const ZLegacyStudyMigrator _migrator = ZLegacyStudyMigrator();

void main() {
  // ══════════════════════════════════════════════════════════════════════
  // AC1 — migrateur pur/défensif, confiné à l'adapter, signature Map (AD-5)
  // ══════════════════════════════════════════════════════════════════════
  group('AC1 — migrateur pur, défensif, Map in/out', () {
    test('migrateDocument compose le codec : camelCase → snake_case + status '
        '6→4 (valeurs réelles préservées)', () {
      final o = _migrator.migrateDocument(_fixture('document_flat_full'));
      expect(o.canonical['subject_id'], 'subj_lit_310');
      expect(o.canonical['assistant_file_id'], 'file-lit310xyz');
      expect(o.canonical['content_length'], 73210);
      expect(o.canonical['status'], 'ready'); // embedded → ready (6→4)
      expect(o.alreadyCanonical, isFalse);
    });

    test('migrateDocument / migrateCorpus ne throw JAMAIS, quel que soit '
        "l'input (AD-10)", () {
      expect(() => _migrator.migrateDocument(<String, dynamic>{}),
          returnsNormally);
      expect(() => _migrator.migrateDocument(_fixture('document_corrupt')),
          returnsNormally);
      expect(
        () => _migrator.migrateCorpus(<Map<String, dynamic>>[
          <String, dynamic>{},
          _fixture('document_corrupt'),
          _fixture('document_flat_full'),
        ]),
        returnsNormally,
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // AC2 — R26 : PRÉSERVATION EXACTE du contenu métier (census, pas existence)
  // ══════════════════════════════════════════════════════════════════════
  group('AC2 — R26 census : aucune clé métier perdue', () {
    // ★ R3-I1 : dans migrateDocument, dropper une clé métier (ex. filtrer
    //   `assistantFileId` avant le codec, ou fusionner deux clés) ⇒ le census de
    //   couverture chute ⇒ ces assertions ROUGES.
    test('CHAQUE clé métier legacy nommée est retrouvable dans le canonique '
        '(snake ou _legacy_)', () {
      final o = _migrator.migrateDocument(_fixture('document_flat_full'));
      final c = o.canonical;
      // Renommées snake_case (valeur exacte, pas seulement présence).
      expect(c['id'], 'doc_iffd_101');
      expect(c['subject_id'], 'subj_lit_310');
      expect(c['folder_id'], 'folder_poetry');
      expect(c['sub_folder_id'], 'subfolder_sonnets');
      expect(c['creator_id'], 'user_akosua');
      expect(c['name'], 'recueil_sonnets.pdf');
      expect(c['content_length'], 73210);
      expect(c['page_count'], 27);
      expect(c['cloud_path'],
          'subjects/subj_lit_310/documents/doc_iffd_101.pdf');
      expect(c['cloud_url'], 'https://storage.example/doc_iffd_101.pdf');
      expect(c['assistant_file_id'], 'file-lit310xyz');
      expect(c['type'], 'pdf');
      // `status` remappé + granularité legacy exacte préservée (_legacy_status).
      expect(c['status'], 'ready');
      expect(c['${ZStudyLegacyCodec.kLegacyPrefix}status'], 'embedded');
    });

    test('census : couverture TOTALE (businessKeysIn.length == covered), '
        'lostBusinessKeys vide', () {
      final o = _migrator.migrateDocument(_fixture('document_flat_full'));
      expect(o.isPreservationComplete, isTrue);
      expect(o.lostBusinessKeys, isEmpty);
      expect(o.coveredBusinessKeys.length, o.businessKeysIn.length);
      // Chaque clé métier d'entrée est nommément couverte.
      for (final key in <String>[
        'id',
        'subjectId',
        'folderId',
        'subFolderId',
        'creatorId',
        'createdAt',
        'name',
        'type',
        'content',
        'contentLength',
        'pageCount',
        'status',
        'cloudPath',
        'cloudUrl',
        'assistantFileId',
      ]) {
        expect(o.coveredBusinessKeys, contains(key), reason: 'clé $key couverte');
      }
    });

    test('les clés de sync (is_deleted/updated_at) sont EXCLUES du census '
        '(hors-corps)', () {
      final o = _migrator.migrateDocument(_fixture('document_soft_deleted'));
      expect(o.businessKeysIn, isNot(contains(ZSyncMeta.kIsDeleted)));
      expect(o.businessKeysIn, isNot(contains(ZSyncMeta.kUpdatedAt)));
      expect(o.isPreservationComplete, isTrue);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // AC3 — IDEMPOTENCE : migrate ∘ migrate = migrate (franchit le TRAP status)
  // ══════════════════════════════════════════════════════════════════════
  group('AC3 — idempotence (point fixe, status NON rétrogradé)', () {
    // ★ R3-I2 : retirer la garde « déjà canonique » (_isAlreadyCanonical) ⇒
    //   le 2e passage ré-applique le codec ⇒ mapDocumentStatus('ready') tombe au
    //   défaut 'uploading' ⇒ status RÉTROGRADE ⇒ c2 != c ⇒ ROUGE.
    for (final name in const <String>[
      'document_flat_full', // embedded → ready
      'document_created_at_iso', // uploaded → ready
      'document_dw_es22_2', // converted → ready
    ]) {
      test('[$name] migrateDocument(c).canonical == c (point fixe profond)', () {
        final c = _migrator.migrateDocument(_fixture(name)).canonical;
        final o2 = _migrator.migrateDocument(c);
        expect(o2.alreadyCanonical, isTrue,
            reason: 'la re-migration détecte « déjà canonique »');
        expect(_deepEquals(o2.canonical, c), isTrue,
            reason: 'point fixe : re-migration NO-OP');
        // Le TRAP explicite : status déjà canonique NON rétrogradé.
        expect(o2.canonical['status'], c['status']);
        expect(c['status'], 'ready');
      });
    }

    test('is_deleted / _legacy_status NON ré-écrasés au 2e passage', () {
      final c = _migrator.migrateDocument(_fixture('document_flat_full')).canonical;
      final c2 = _migrator.migrateDocument(c).canonical;
      expect(c2[ZSyncMeta.kIsDeleted], c[ZSyncMeta.kIsDeleted]);
      expect(c2['${ZStudyLegacyCodec.kLegacyPrefix}status'],
          c['${ZStudyLegacyCodec.kLegacyPrefix}status']); // reste 'embedded'
      expect(c2['${ZStudyLegacyCodec.kLegacyPrefix}status'], 'embedded');
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // AC4 — ZSyncMeta HORS-CORPS : additif, jamais dans extra/le corps (AD-19)
  // ══════════════════════════════════════════════════════════════════════
  group('AC4 — ZSyncMeta hors-corps (additif, jamais dans extra)', () {
    // ★ R3-I3 : forcer is_deleted:false dans migrateDocument (écrasement) ⇒ le
    //   cas soft-deleted « préserve true » ROUGE. Variante : injecter updated_at
    //   dans le corps ⇒ le test « updated_at absent » ROUGE.
    test('doc SANS sync-meta : is_deleted:false additif, updated_at ABSENT', () {
      final o = _migrator.migrateDocument(_fixture('document_flat_full'));
      expect(o.canonical[ZSyncMeta.kIsDeleted], false);
      expect(o.canonical.containsKey(ZSyncMeta.kUpdatedAt), isFalse);
      final meta = ZSyncMeta.fromJson(o.canonical);
      expect(meta.isDeleted, isFalse);
      expect(meta.updatedAt, isNull); // LWW « jamais synchronisé »
    });

    test('doc soft-deleted legacy : is_deleted:true PRÉSERVÉ (jamais → false)',
        () {
      final o = _migrator.migrateDocument(_fixture('document_soft_deleted'));
      expect(o.canonical[ZSyncMeta.kIsDeleted], true);
      // Migré malgré is_deleted (clés camelCase ⇒ pas « déjà canonique »).
      expect(o.alreadyCanonical, isFalse);
      expect(o.canonical['subject_id'], 'subj_econ_205');
    });

    test('après décodage entité : ni updated_at ni is_deleted dans extra ni '
        'réémis par toMap (round-trip fromMap∘toMap)', () {
      final o = _migrator.migrateDocument(_fixture('document_soft_deleted'));
      final entity = _StudyDouble.fromMap(o.canonical);
      expect(entity.extra.containsKey(ZSyncMeta.kIsDeleted), isFalse);
      expect(entity.extra.containsKey(ZSyncMeta.kUpdatedAt), isFalse);
      final reemitted = _StudyDouble.fromMap(entity.toMap()).toMap();
      expect(reemitted.containsKey(ZSyncMeta.kIsDeleted), isFalse);
      expect(reemitted.containsKey(ZSyncMeta.kUpdatedAt), isFalse);
      // La granularité métier survit dans extra (ex. _legacy_status).
      expect(entity.extra['${ZStudyLegacyCodec.kLegacyPrefix}status'],
          'uploaded');
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // AC5 — DÉFENSIF : corrompu/absent/mal typé → défaut sûr, JAMAIS de throw
  // ══════════════════════════════════════════════════════════════════════
  group('AC5 — défensif : défaut sûr compté, jamais throw (AD-10)', () {
    // ★ R3-I4 : remplacer un défaut sûr par un throw/cast dur (`value as int`,
    //   `DateTime.parse` non gardé) dans migrateDocument ⇒ la fixture corrompue
    //   casse returnsNormally ⇒ ROUGE (le migrateur est défensif PAR
    //   CONSTRUCTION, sans blanket catch qui masquerait l'injection).
    test('corpus dégénéré → returnsNormally + défauts COMPTÉS (jamais avalés)',
        () {
      final corpus = <Map<String, dynamic>>[
        _fixture('document_corrupt'), // status:42, createdAt:"pas-une-date"
        _fixture('document_unknown_status'), // status inconnu
        <String, dynamic>{}, // vide
        <String, dynamic>{'a': null, 'weirdAt': 999999999999999999}, // int hors bornes
      ];
      late ZLegacyMigrationReport report;
      expect(() => report = _migrator.migrateCorpus(corpus), returnsNormally);
      expect(report.defaultsApplied, greaterThan(0));
    });

    test('status illisible → uploading (1ʳᵉ constante) + tracé dans '
        'defaultsApplied', () {
      final o = _migrator.migrateDocument(_fixture('document_corrupt'));
      expect(o.canonical['status'], 'uploading'); // status:42 → défaut
      expect(o.defaultsApplied, contains('status'));
    });

    test('createdAt implausible/non-date → laissé INTACT (jamais une date '
        'fabriquée) + tracé', () {
      final o = _migrator.migrateDocument(_fixture('document_corrupt'));
      expect(o.canonical['created_at'], 'pas-une-date-du-tout'); // intact
      expect(o.defaultsApplied, contains('created_at'));
    });

    test('document VIDE → canonique {is_deleted:false} sans crash', () {
      final o = _migrator.migrateDocument(<String, dynamic>{});
      expect(o.canonical[ZSyncMeta.kIsDeleted], false);
      expect(o.defaultsApplied, isEmpty);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // AC6 — RAPPORT auditable + DRY-RUN (write-back DÉFÉRÉ DW-ES112-1)
  // ══════════════════════════════════════════════════════════════════════
  group('AC6 — rapport auditable + DRY-RUN', () {
    // ★ R3-I5 : muter le Map d'entrée dans migrateCorpus (au lieu d'une copie)
    //   ⇒ « input inchangé » ROUGE ; fausser un compteur ⇒ l'invariant
    //   migrated+alreadyCanonical==total ROUGE.
    test('compteurs nommés cohérents (corpus mixte legacy + déjà-canonique)',
        () {
      final legacy = _fixture('document_flat_full');
      final canonical = _migrator.migrateDocument(legacy).canonical;
      final report = _migrator.migrateCorpus(<Map<String, dynamic>>[
        legacy, // migré
        _fixture('document_dw_es22_2'), // migré
        canonical, // déjà canonique
      ]);
      expect(report.total, 3);
      expect(report.migrated, 2);
      expect(report.alreadyCanonical, 1);
      expect(report.isConsistent, isTrue); // migrated+already==total
      expect(report.canonicalDocuments, hasLength(3));
      expect(report.preservedAllBusinessKeys, isTrue);
      expect(report.lostBusinessKeys, isEmpty);
    });

    test('DRY-RUN : migrateCorpus ne MUTE PAS les Map d\'entrée', () {
      final input = _fixture('document_flat_full');
      final before = _deepCopy(input);
      _migrator.migrateCorpus(<Map<String, dynamic>>[input]);
      expect(_deepEquals(input, before), isTrue,
          reason: 'entrée inchangée (DRY-RUN, aucune mutation)');
      // La forme canonique n'a pas contaminé l'entrée (toujours camelCase).
      expect(input.containsKey('subjectId'), isTrue);
      expect(input.containsKey('subject_id'), isFalse);
    });

    test('corpus vide → rapport nul cohérent', () {
      final report = _migrator.migrateCorpus(const <Map<String, dynamic>>[]);
      expect(report.total, 0);
      expect(report.isConsistent, isTrue);
      expect(report.canonicalDocuments, isEmpty);
      expect(report.preservedAllBusinessKeys, isTrue);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // AC7 — DW-ES22-2 : champs legacy IFFD spécifiques préservés sans perte
  // ══════════════════════════════════════════════════════════════════════
  group('AC7 — DW-ES22-2 (audioText / audioTextHash:int / subFolderId)', () {
    // ★ R3-I6 : coercer audioTextHash (int) en date parce qu'int, ou dropper
    //   audioText ⇒ le test de valeur exacte ROUGE.
    test('audioText → audio_text (String intacte) ; subFolderId → sub_folder_id',
        () {
      final o = _migrator.migrateDocument(_fixture('document_dw_es22_2'));
      final c = o.canonical;
      expect(c['audio_text'],
          "Transcription de la leçon d'audio pour l'indexation IA.");
      expect(c['sub_folder_id'], 'subfolder_rythme');
      expect(c['subject_id'], 'subj_music_400');
      expect(c['creator_id'], 'user_kwame');
    });

    test('audioTextHash:int → audio_text_hash conserve son int INTACT (PAS une '
        'date — la clé ne finit pas par _at)', () {
      final o = _migrator.migrateDocument(_fixture('document_dw_es22_2'));
      expect(o.canonical['audio_text_hash'], 8419203715);
      expect(o.canonical['audio_text_hash'], isA<int>());
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // Invariant AD-10 — chaque fixture historique migre sans throw
  // ══════════════════════════════════════════════════════════════════════
  group('Invariant AD-10 — toute fixture survit à la migration', () {
    for (final name in const <String>[
      'document_embedded',
      'document_converting',
      'document_created_at_iso',
      'document_unknown_status',
      'document_corrupt',
      'document_with_sync_meta',
      'document_flat_full',
      'document_dw_es22_2',
      'document_soft_deleted',
    ]) {
      test('[$name] migrateDocument → décodage entité ne throw jamais', () {
        expect(() {
          final o = _migrator.migrateDocument(_fixture(name));
          _StudyDouble.fromMap(o.canonical).toMap();
        }, returnsNormally);
      });
    }
  });
}

// ───────────────────────── Utilitaires de test ────────────────────────────

/// Égalité profonde de deux `Map` (records imbriqués compris) — sans dépendance.
bool _deepEquals(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

/// Copie profonde d'une `Map` (pour attester la non-mutation de l'entrée).
Map<String, dynamic> _deepCopy(Map<String, dynamic> src) => <String, dynamic>{
      for (final e in src.entries)
        e.key: e.value is Map<String, dynamic>
            ? _deepCopy(e.value as Map<String, dynamic>)
            : e.value is List
                ? List<dynamic>.of(e.value as List)
                : e.value,
    };
