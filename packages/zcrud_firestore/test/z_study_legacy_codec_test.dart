@Tags(<String>['serialization-compat'])
library;

/// CORPUS de rétro-compatibilité de sérialisation IFFD legacy (ES-3.5, AD-10).
///
/// Exécuté par le slot de gate de merge `verify:serialization`
/// (`scripts/ci/verify_serialization.dart` → `flutter test --tags
/// serialization-compat`). ARME le gate à ENFORCED sous
/// `ZCRUD_REQUIRE_SERIALIZATION_COMPAT=1` — ce corpus PROUVE son pouvoir
/// discriminant (chaque garde naît avec sa fixture d'échec ; injections R3-x
/// documentées ★ en commentaire).
///
/// Fixtures = documents Firestore **HISTORIQUES RÉELS** de l'app IFFD
/// (`FolderDocument.toMap`, clés camelCase) : `test/fixtures/iffd_legacy/*.json`.
///
/// **Confinement** : `zcrud_firestore` n'a AUCUNE arête vers `zcrud_flashcard`
/// (AD-1). L'entité de décodage end-to-end est un double de test `_LegacyDoc`
/// (aucune arête neuve) ; les statuts sont assertés par **noms d'enum String**
/// (pas d'import `ZDocumentStatus`). AC5 (divergence `ZFlashcardSource`) est
/// épinglée par **réplication de contrat** (le lib flashcard, inchangé,
/// implémente exactement ce contrat) — cf. groupe AC5.
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';

// ───────────────────────── Chargement des fixtures ─────────────────────────

/// Charge une fixture JSON legacy (clés camelCase) depuis le disque.
Map<String, dynamic> _fixture(String name) {
  final file = File('test/fixtures/iffd_legacy/$name.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

// ───────────────────────── Entité de décodage (double de test) ─────────────

/// Entité de test minimale décodant la forme **canonique** (snake_case) produite
/// par [ZStudyLegacyCodec.toCanonical]. `fromMap` **défensif** (AD-10) : jamais
/// de throw, champs illisibles → `null`. Vit ENTIÈREMENT dans le test (aucune
/// arête runtime neuve, D8).
class _LegacyDoc extends ZEntity {
  const _LegacyDoc({
    this.id,
    this.subjectId,
    this.folderId,
    this.subFolderId,
    this.creatorId,
    this.createdAtIso,
    this.name,
    this.contentLength,
    this.pageCount,
    this.status,
    this.legacyStatus,
    this.cloudPath,
    this.assistantFileId,
  });

  @override
  final String? id;
  final String? subjectId;
  final String? folderId;
  final String? subFolderId;
  final String? creatorId;
  final String? createdAtIso;
  final String? name;
  final int? contentLength;
  final int? pageCount;

  /// Nom d'enum canonique `ZDocumentStatus` (String) — jamais l'enum réel (D8).
  final String? status;

  /// Granularité legacy exacte préservée dans `extra` (AD-4).
  final String? legacyStatus;
  final String? cloudPath;
  final String? assistantFileId;

  static _LegacyDoc fromMap(Map<String, dynamic> map) {
    String? asString(Object? v) => v is String ? v : null;
    int? asInt(Object? v) => v is int ? v : null;
    return _LegacyDoc(
      id: asString(map['id']),
      subjectId: asString(map['subject_id']),
      folderId: asString(map['folder_id']),
      subFolderId: asString(map['sub_folder_id']),
      creatorId: asString(map['creator_id']),
      createdAtIso: asString(map['created_at']),
      name: asString(map['name']),
      contentLength: asInt(map['content_length']),
      pageCount: asInt(map['page_count']),
      status: asString(map['status']),
      legacyStatus: asString(map['${ZStudyLegacyCodec.kLegacyPrefix}status']),
      cloudPath: asString(map['cloud_path']),
      assistantFileId: asString(map['assistant_file_id']),
    );
  }
}

// ───────────────────────── Le codec sous test ─────────────────────────────

const ZStudyLegacyCodec _codec = ZStudyLegacyCodec(
  valueMappers: <String, ZLegacyValueMapper>{
    'status': ZStudyLegacyCodec.mapDocumentStatus,
  },
  preserveLegacyUnder: <String>{'status'},
);

void main() {
  // ══════════════════════════════════════════════════════════════════════
  // AC1 — camelCase legacy → snake_case canonique, SANS PERTE (bidirectionnel)
  // ══════════════════════════════════════════════════════════════════════
  group('AC1 — mapping de casse camelCase → snake_case (sans perte)', () {
    test('chaque clé camelCase mesurée est renommée en snake_case + VALEUR '
        'réelle préservée (★ R3-1 : camelToSnake=identité ⇒ ces valeurs '
        'reviennent null ⇒ ROUGE)', () {
      final canonical = _codec.toCanonical(_fixture('document_embedded'));

      // Valeurs réelles des champs renommés (pas null/défaut).
      expect(canonical['subject_id'], 'subj_math_101');
      expect(canonical['folder_id'], 'folder_algebra');
      expect(canonical['sub_folder_id'], 'subfolder_polynomials');
      expect(canonical['creator_id'], 'user_amadou');
      expect(canonical['content_length'], 48213);
      expect(canonical['page_count'], 12);
      expect(canonical['cloud_path'],
          'subjects/subj_math_101/documents/doc_iffd_001.pdf');
      expect(canonical['assistant_file_id'], 'file-abc123xyz');

      // Les clés camelCase d'origine ont DISPARU (renommées, pas dupliquées).
      expect(canonical.containsKey('subjectId'), isFalse);
      expect(canonical.containsKey('contentLength'), isFalse);
    });

    test('mot simple / clé inchangée : id, name, type, content, status(clé) '
        'restent tels quels', () {
      final canonical = _codec.toCanonical(_fixture('document_embedded'));
      expect(canonical['id'], 'doc_iffd_001');
      expect(canonical['name'], 'chapitre_1_polynomes.pdf');
      expect(canonical['type'], 'pdf');
      expect(canonical.containsKey('status'), isTrue);
    });

    test('clé inconnue : transformée + conservée (jamais perdue)', () {
      final canonical =
          _codec.toCanonical(<String, dynamic>{'someFutureField': 'v'});
      expect(canonical['some_future_field'], 'v');
    });

    test('round-trip toLegacy∘toCanonical restitue la forme camelCase '
        '(modulo ZSyncMeta additif ; valeurs non-lossy préservées)', () {
      final legacy = _fixture('document_embedded');
      final roundTrip = _codec.toLegacy(_codec.toCanonical(legacy));

      // Clés camelCase restituées.
      for (final key in <String>[
        'subjectId',
        'folderId',
        'subFolderId',
        'creatorId',
        'contentLength',
        'pageCount',
        'cloudPath',
        'assistantFileId',
      ]) {
        expect(roundTrip.containsKey(key), isTrue, reason: 'clé $key restituée');
      }
      // Valeurs non-lossy (ni date, ni statut) préservées à l'identique.
      expect(roundTrip['subjectId'], 'subj_math_101');
      expect(roundTrip['name'], 'chapitre_1_polynomes.pdf');
      expect(roundTrip['contentLength'], 48213);
    });

    test('camelToSnake / snakeToCamel — cas unitaires + idempotence', () {
      expect(ZStudyLegacyCodec.camelToSnake('subjectId'), 'subject_id');
      expect(ZStudyLegacyCodec.camelToSnake('assistantFileId'),
          'assistant_file_id');
      expect(ZStudyLegacyCodec.camelToSnake('createdAt'), 'created_at');
      expect(ZStudyLegacyCodec.camelToSnake('id'), 'id');
      expect(ZStudyLegacyCodec.camelToSnake('status'), 'status');
      expect(ZStudyLegacyCodec.camelToSnake('is_deleted'), 'is_deleted');
      expect(ZStudyLegacyCodec.snakeToCamel('subject_id'), 'subjectId');
      expect(ZStudyLegacyCodec.snakeToCamel('assistant_file_id'),
          'assistantFileId');
      expect(ZStudyLegacyCodec.snakeToCamel('id'), 'id');
    });

    test('décodage end-to-end : un doc legacy restitue les VRAIES valeurs '
        '(pas null/défaut)', () {
      final doc = _LegacyDoc.fromMap(
          _codec.toCanonical(_fixture('document_embedded')));
      expect(doc.id, 'doc_iffd_001');
      expect(doc.subjectId, 'subj_math_101');
      expect(doc.folderId, 'folder_algebra');
      expect(doc.subFolderId, 'subfolder_polynomials');
      expect(doc.contentLength, 48213);
      expect(doc.assistantFileId, 'file-abc123xyz');
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // AC2 — mapping legacy IFFD 6 statuts → 4 canoniques (DW-ES21-1 soldée)
  // ══════════════════════════════════════════════════════════════════════
  group('AC2 — mapDocumentStatus 6→4 déterministe & exhaustif', () {
    // ★ R3-2 : casser une ligne (ex. converted→uploading) ⇒ ce cas ROUGE ;
    //   inverser le défaut (inconnu→ready) ⇒ le cas inconnu ROUGE.
    test('les 6 statuts legacy → sortie canonique attendue (assertions '
        'individuelles)', () {
      expect(ZStudyLegacyCodec.mapDocumentStatus('uploading'), 'uploading');
      expect(ZStudyLegacyCodec.mapDocumentStatus('converting'), 'validating');
      expect(ZStudyLegacyCodec.mapDocumentStatus('embedding'), 'validating');
      expect(ZStudyLegacyCodec.mapDocumentStatus('uploaded'), 'ready');
      expect(ZStudyLegacyCodec.mapDocumentStatus('converted'), 'ready');
      expect(ZStudyLegacyCodec.mapDocumentStatus('embedded'), 'ready');
    });

    test('absent / null / inconnu / non-String → uploading (défaut sûr = 1ʳᵉ '
        'constante)', () {
      expect(ZStudyLegacyCodec.mapDocumentStatus(null), 'uploading');
      expect(ZStudyLegacyCodec.mapDocumentStatus('quantum_indexing'),
          'uploading');
      expect(ZStudyLegacyCodec.mapDocumentStatus(42), 'uploading');
      expect(ZStudyLegacyCodec.mapDocumentStatus(<String>['x']), 'uploading');
    });

    test('les 4 sorties possibles seulement — jamais rejected', () {
      const legacyValues = <Object?>[
        'uploading',
        'converting',
        'embedding',
        'uploaded',
        'converted',
        'embedded',
        'inconnu',
        null,
      ];
      final outputs = legacyValues
          .map(ZStudyLegacyCodec.mapDocumentStatus)
          .toSet();
      expect(outputs, <String>{'uploading', 'validating', 'ready'});
      expect(outputs.contains('rejected'), isFalse);
    });

    test('granularité legacy exacte PRÉSERVÉE dans extra (_legacy_status), '
        'zéro perte (AD-4)', () {
      final canonical = _codec.toCanonical(_fixture('document_embedded'));
      expect(canonical['status'], 'ready'); // remap 6→4
      expect(canonical['${ZStudyLegacyCodec.kLegacyPrefix}status'],
          'embedded'); // survie de la granularité
    });

    test('décodage end-to-end : status canonique + legacyStatus préservé', () {
      final doc = _LegacyDoc.fromMap(
          _codec.toCanonical(_fixture('document_converting')));
      expect(doc.status, 'validating');
      expect(doc.legacyStatus, 'converting');
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // AC3 — décodage DÉFENSIF : un doc corrompu DÉGRADE, ne throw JAMAIS (AD-10)
  // ══════════════════════════════════════════════════════════════════════
  group('AC3 — défensif : corrompu → dégrade, jamais throw', () {
    // ★ R3-3 : introduire un `throw` sur valeur inattendue dans toCanonical
    //   ⇒ ce groupe ROUGE (attend returnsNormally).
    test('toCanonical(doc corrompu) ne throw jamais', () {
      expect(() => _codec.toCanonical(_fixture('document_corrupt')),
          returnsNormally);
    });

    test('toLegacy(doc corrompu) ne throw jamais', () {
      final canonical = _codec.toCanonical(_fixture('document_corrupt'));
      expect(() => _codec.toLegacy(canonical), returnsNormally);
    });

    test('décodage end-to-end d\'un doc corrompu survit (parent non null, '
        'champs repliés)', () {
      late _LegacyDoc doc;
      expect(
        () => doc = _LegacyDoc.fromMap(
            _codec.toCanonical(_fixture('document_corrupt'))),
        returnsNormally,
      );
      expect(doc.id, 'doc_iffd_005'); // champ sain conservé
      expect(doc.name, isNull); // name:null → null
      expect(doc.contentLength, isNull); // "beaucoup" → null (pas de throw)
      // status:42 (non-String) → défaut 'uploading' via le valueMapper.
      expect(doc.status, 'uploading');
    });

    test('valeurs extrêmes/vides → jamais throw', () {
      expect(() => _codec.toCanonical(<String, dynamic>{}), returnsNormally);
      expect(
        () => _codec.toCanonical(<String, dynamic>{
          'a': null,
          'nestedMap': <String, dynamic>{'x': 1},
          'listVal': <int>[1, 2, 3],
        }),
        returnsNormally,
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // AC4 — ajout ZSyncMeta ADDITIF rétro-compatible → doc legacy VISIBLE
  // ══════════════════════════════════════════════════════════════════════
  group('AC4 — ZSyncMeta additif (is_deleted:false) ⇒ visible', () {
    // ★ R3-4 : retirer l'ajout is_deleted:false ⇒ ces assertions + le
    //   end-to-end getAll deviennent ROUGES (doc non visible).
    test('doc legacy SANS sync-meta : is_deleted=false ajouté, updated_at '
        'laissé absent', () {
      final canonical = _codec.toCanonical(_fixture('document_embedded'));
      // Exactement la condition de _isVisible (data[is_deleted] == false).
      expect(canonical[ZSyncMeta.kIsDeleted], false);
      expect(canonical.containsKey(ZSyncMeta.kUpdatedAt), isFalse);

      final meta = ZSyncMeta.fromJson(canonical);
      expect(meta.isDeleted, isFalse);
      expect(meta.updatedAt, isNull); // LWW « jamais synchronisé »
    });

    test('doc portant DÉJÀ is_deleted/updated_at : NON écrasé (additif)', () {
      final canonical = _codec.toCanonical(_fixture('document_with_sync_meta'));
      expect(canonical[ZSyncMeta.kIsDeleted], true); // préservé, pas écrasé
      expect(canonical[ZSyncMeta.kUpdatedAt], '2024-04-01T08:00:00.000Z');
    });

    test('end-to-end : un doc legacy normalisé (codec) est VISIBLE via getAll '
        '(★ R3-4 : sans is_deleted ⇒ getAll vide ⇒ ROUGE)', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = FirebaseZRepositoryImpl<_LegacyDoc>(
        firestore: firestore,
        collectionPath: 'docs',
        kind: 'study_document',
        fromMap: _LegacyDoc.fromMap,
        toMap: (v) => <String, dynamic>{'id': v.id},
      );
      addTearDown(repo.dispose);

      // Migration-shaped : on STOCKE la sortie canonique du codec (avec
      // is_deleted:false ajouté), puis on relit via le repo (filtre serveur
      // is_deleted==false + _isVisible).
      final canonical = _codec.toCanonical(_fixture('document_embedded'));
      await firestore.collection('docs').doc('doc_iffd_001').set(canonical);

      final result = await repo.getAll();
      final docs = result.getOrElse(() => <_LegacyDoc>[]);
      expect(docs, hasLength(1));
      expect(docs.single.subjectId, 'subj_math_101');
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // AC5 — FlashcardSource inconnu → variant custom, JAMAIS FormatException
  // ══════════════════════════════════════════════════════════════════════
  //
  // `zcrud_firestore` n'a AUCUNE arête vers `zcrud_flashcard` (AD-1). Le lib
  // `ZFlashcardSource.fromJson` (INCHANGÉ) implémente exactement le contrat
  // ci-dessous : `kind` inconnu → variant « custom » conservant le payload,
  // `kind` absent → null, JAMAIS de throw — même si le codec d'app throw
  // (absorbé par un guard). On épingle ce CONTRAT par réplication (double de
  // test), avec l'injection R3-5 qui prouve le pouvoir discriminant.
  group('AC5 — divergence FlashcardSource (contrat répliqué, épinglé)', () {
    // ★ R3-5 : retirer le guard autour du codec d'app (useGuard:false) ⇒ le
    //   cas « codec d'app qui throw » ROUGE (attend returnsNormally).
    test('kind inconnu → custom (payload préservé), jamais throw', () {
      final source = _decodeSourceLikeFlashcard(
        <String, dynamic>{'kind': 'article', 'hs_code': '8471.30'},
      );
      expect(source, isNotNull);
      expect(source!['kind'], 'article');
      expect(source['payload'], <String, dynamic>{'hs_code': '8471.30'});
    });

    test('kind absent → null (jamais throw)', () {
      expect(_decodeSourceLikeFlashcard(<String, dynamic>{'x': 1}), isNull);
      expect(_decodeSourceLikeFlashcard(null), isNull);
      expect(_decodeSourceLikeFlashcard('not-a-map'), isNull);
    });

    test('codec d\'app qui THROW sur kind inconnu → absorbé par le guard '
        '(returnsNormally, payload conservé)', () {
      expect(
        () => _decodeSourceLikeFlashcard(
          <String, dynamic>{'kind': 'article', 'v': 1},
          throwingAppCodec: true,
        ),
        returnsNormally,
      );
      final source = _decodeSourceLikeFlashcard(
        <String, dynamic>{'kind': 'article', 'v': 1},
        throwingAppCodec: true,
      );
      expect(source, isNotNull);
      expect(source!['kind'], 'article');
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // AC6 — interop dates bi-format IFFD (Timestamp natif ET int millis) → ISO
  // ══════════════════════════════════════════════════════════════════════
  group('AC6 — dates bi-format → même ISO-8601 (DW-ES32-1 partielle)', () {
    const int millis = 1710498600000; // 2024-03-15T10:30:00.000Z

    // ★ R3-6 : neutraliser la branche int millis du codec ⇒ created_at reste
    //   un int (pas une String ISO) ⇒ ces assertions ROUGES.
    test('createdAt en int millis → String ISO-8601 (codec comble le cas int)',
        () {
      final canonical =
          _codec.toCanonical(<String, dynamic>{'createdAt': millis});
      expect(canonical['created_at'], isA<String>());
      expect(DateTime.parse(canonical['created_at'] as String).toUtc(),
          DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true));
    });

    test('createdAt déjà String ISO → traversée inchangée', () {
      final canonical = _codec.toCanonical(_fixture('document_created_at_iso'));
      expect(canonical['created_at'], '2024-03-15T10:30:00.000Z');
    });

    test('int hors bornes plausibles / non-date → laissé intact (défensif)',
        () {
      // content_length int NON traité (clé ne finit pas par _at).
      final c1 = _codec.toCanonical(<String, dynamic>{'contentLength': 48213});
      expect(c1['content_length'], 48213);
      // *_at avec int hors bornes (année > 9999) → laissé intact.
      final c2 = _codec
          .toCanonical(<String, dynamic>{'weirdAt': 999999999999999999});
      expect(c2['weird_at'], 999999999999999999);
    });

    test('end-to-end : Timestamp natif ET int millis décodent au même instant '
        '(Timestamp via l\'adaptateur, int via le codec)', () async {
      final firestore = FakeFirebaseFirestore();
      // timestampFields hinte la clé LEGACY `createdAt` : _inject normalise le
      // Timestamp natif → ISO AVANT le codec ; le codec comble le cas int.
      final repo = FirebaseZRepositoryImpl<_LegacyDoc>(
        firestore: firestore,
        collectionPath: 'docs',
        kind: 'study_document',
        fromMap: (raw) => _LegacyDoc.fromMap(_codec.toCanonical(raw)),
        toMap: (v) => <String, dynamic>{'id': v.id},
        timestampFields: const <String>{'createdAt'},
      );
      addTearDown(repo.dispose);

      await firestore.collection('docs').doc('ts').set(<String, dynamic>{
        'createdAt': Timestamp.fromMillisecondsSinceEpoch(millis),
        ZSyncMeta.kIsDeleted: false,
      });
      await firestore.collection('docs').doc('int').set(<String, dynamic>{
        'createdAt': millis,
        ZSyncMeta.kIsDeleted: false,
      });

      final docs = (await repo.getAll()).getOrElse(() => <_LegacyDoc>[]);
      final byId = <String, _LegacyDoc>{for (final d in docs) d.id!: d};
      expect(byId['ts']!.createdAtIso, isNotNull);
      expect(byId['int']!.createdAtIso, isNotNull);
      expect(
        DateTime.parse(byId['ts']!.createdAtIso!).toUtc(),
        DateTime.parse(byId['int']!.createdAtIso!).toUtc(),
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // Invariant universel AD-10 : chaque fixture historique décode sans throw
  // ══════════════════════════════════════════════════════════════════════
  group('Invariant AD-10 — toute fixture historique survit', () {
    for (final name in const <String>[
      'document_embedded',
      'document_converting',
      'document_created_at_iso',
      'document_unknown_status',
      'document_corrupt',
      'document_with_sync_meta',
    ]) {
      test('[$name] toCanonical → décodage ne throw jamais', () {
        expect(
          () => _LegacyDoc.fromMap(_codec.toCanonical(_fixture(name))),
          returnsNormally,
        );
      });
    }
  });
}

// ───────────────────────── AC5 : contrat FlashcardSource répliqué ──────────

/// Réplique DÉFENSIVE du contrat `ZFlashcardSource.fromJson` (lib
/// `zcrud_flashcard`, INCHANGÉ ; non importable ici — AD-1) : `kind` absent →
/// `null` ; `kind` inconnu → variant « custom » conservant le payload ; JAMAIS
/// de throw — même si le codec d'app throw ([throwingAppCodec], absorbé par le
/// guard quand [useGuard]).
Map<String, dynamic>? _decodeSourceLikeFlashcard(
  Object? raw, {
  bool throwingAppCodec = false,
  bool useGuard = true,
}) {
  if (raw is! Map) return null;
  final map = <String, dynamic>{
    for (final e in raw.entries) '${e.key}': e.value,
  };
  final kind = map['kind'];
  if (kind is! String || kind.isEmpty) return null;

  final body = <String, dynamic>{
    for (final e in map.entries)
      if (e.key != 'kind') e.key: e.value,
  };

  Map<String, dynamic> runAppCodec() {
    if (throwingAppCodec) throw const FormatException('app codec boom');
    return body;
  }

  Map<String, dynamic> payload;
  if (useGuard) {
    try {
      payload = runAppCodec();
    } on Object {
      payload = body; // absorbé (AD-10) → jamais de throw
    }
  } else {
    payload = runAppCodec(); // ★ R3-5 : sans guard, un codec throwant remonte
  }

  return <String, dynamic>{'kind': kind, 'payload': payload};
}
