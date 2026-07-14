/// AC7 — **AD-26 prouvé PAR MACHINE** (état personnel / contenu partageable) et
/// AC8 — conformité au **patron ES-2.0**, **OBSERVÉE** sur la voie registre.
library;

import 'package:test/test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_document/zcrud_document.dart';

/// Registre peuplé par les **3** registrars générés du package — c'est
/// EXACTEMENT la voie qu'un store (`FirebaseZRepositoryImpl.fromRegistry`)
/// emprunte.
ZcrudRegistry buildRegistry() {
  final r = ZcrudRegistry();
  // ⚠️ Chaque `registerZ…` d'une classe `ZExtensible` exécute le GARDE RUNTIME
  // `_$zRequireExtraPreserved` (émis dans le `.g.dart`, PAS sous `assert`) : si
  // `fromMap` ne peuplait pas `extra`, ou si `toMap()` ne le réémettait pas, CES
  // TROIS LIGNES LÈVERAIENT. Leur simple succès est déjà une observation.
  registerZStudyDocument(r);
  registerZDocumentReadingState(r);
  registerZDocumentViewerPrefs(r);
  return r;
}

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // AC7 — AD-26 : l'état PERSONNEL n'est JAMAIS colocalisé dans le sous-arbre
  // PARTAGEABLE. Prouvé PAR CONSTRUCTION sur les schémas générés — pas en prose.
  // ═══════════════════════════════════════════════════════════════════════════
  group('AC7 — AD-26 : non-colocation état personnel / contenu partageable', () {
    /// Clés qui appartiennent EXCLUSIVEMENT à l'état de lecture PERSONNEL.
    const clesDeLecturePersonnelle = <String>{
      'current_page',
      'prefs',
      'learning',
      'quality_by_page',
      'zoom_level',
      'scroll_direction',
      'page_layout',
    };

    test('`\$ZStudyDocumentFieldSpecs` ne contient AUCUNE clé d\'état de lecture',
        () {
      final docKeys = $ZStudyDocumentFieldSpecs.map((s) => s.name).toSet();
      expect(
        docKeys.intersection(clesDeLecturePersonnelle),
        isEmpty,
        reason: 'AD-26 : partager/dupliquer un document n\'emporte JAMAIS la '
            'progression de lecture d\'autrui — l\'état personnel ne peut donc '
            'pas vivre dans le sous-arbre partageable.',
      );
    });

    test('`ZStudyDocument` n\'IMBRIQUE ni l\'état de lecture ni le learning', () {
      // Aucun champ de type `subItems` (sous-modèle) : le document ne peut pas
      // porter `ZDocumentReadingState` ni `ZDocumentLearningInfo` en sous-objet.
      expect(
        $ZStudyDocumentFieldSpecs
            .where((s) => s.type == EditionFieldType.subItems)
            .toList(),
        isEmpty,
        reason: 'aucun sous-modèle imbriqué dans le contenu partageable',
      );
      // Et la map réellement persistée le confirme, sur une instance PLEINE.
      final m = ZStudyDocument(
        id: 'd',
        folderId: 'f',
        fileName: 'x.pdf',
        status: ZDocumentStatus.ready,
        storagePath: 'gs://x',
        pageCount: 3,
        sizeBytes: 9,
        createdAt: DateTime.utc(2026),
      ).toMap();
      for (final cle in clesDeLecturePersonnelle) {
        expect(m.containsKey(cle), isFalse, reason: 'clé personnelle `$cle`');
      }
    });

    test('les DEUX entités sont des `kind` DISTINCTS (documents séparés)', () {
      final r = buildRegistry();
      expect(r.isRegistered('study_document'), isTrue);
      expect(r.isRegistered('document_reading_state'), isTrue);
      // Le « où » (résolution de collection) reste du ressort de
      // `ZFirestorePathResolver` — ES-3.2, HORS PÉRIMÈTRE. Ce qui est prouvé ici,
      // c'est que la SÉPARATION est structurelle, pas conventionnelle.
      expect(
        $ZDocumentReadingStateFieldSpecs.map((s) => s.name).toSet(),
        isNot(contains('storage_path')),
        reason: 'symétrie : le contenu partageable ne fuit pas non plus dans '
            'l\'état personnel',
      );
    });

    test('l\'état de lecture référence le document par `doc_id` (jointure 1↔1)',
        () {
      expect(
        $ZDocumentReadingStateFieldSpecs.map((s) => s.name),
        contains('doc_id'),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // AC8 — PATRON ES-2.0, OBSERVÉ (pas seulement déclaré).
  //
  // Le build a déjà refusé (1) l'absence de décodeur de domaine et (2) la
  // délégation nue d'une `ZExtensible`. Le GARDE RUNTIME, lui, observe le POUVOIR
  // à l'enregistrement. Restent à observer ICI : le round-trip `extra` complet par
  // la VOIE REGISTRE (decode → encode), et — anti-H2 — celui du canal HORS-CODEGEN
  // `learning`, qu'AUCUNE assertion du gate n'observe.
  // ═══════════════════════════════════════════════════════════════════════════
  group('AC8 — voie REGISTRE : round-trip `extra` (DW-ES14-1)', () {
    test('les 3 registrars s\'enregistrent (⇒ le GARDE RUNTIME est PASSÉ)', () {
      final r = buildRegistry();
      expect(r.kinds.toSet(), <String>{
        'study_document',
        'document_reading_state',
        'document_viewer_prefs',
      });
    });

    for (final kind in <String>['study_document', 'document_reading_state']) {
      test('$kind : une clé hors-schéma survit à decode ET à encode', () {
        final r = buildRegistry();
        final probe = <String, dynamic>{
          if (kind == 'study_document') 'id': 'p',
          if (kind == 'document_reading_state') 'doc_id': 'p',
          'zz_cle_inconnue': 'gardee',
          ZSyncMeta.kUpdatedAt: '2026-01-01T00:00:00.000Z',
          ZSyncMeta.kIsDeleted: true,
        };
        final entity = r.decode(kind, probe) as ZExtensible;
        final encoded = r.encode(kind, entity);

        // (b) la clé inconnue survit au DÉCODAGE...
        expect(entity.extra['zz_cle_inconnue'], 'gardee');
        // (a) ...sans capturer les clés du store...
        expect(entity.extra.keys.toSet().intersection(ZSyncMeta.reservedKeys),
            isEmpty);
        // (e) ...et survit au ROUND-TRIP COMPLET (le cœur de DW-ES14-1).
        expect(encoded['zz_cle_inconnue'], 'gardee');
        // (c)/(d) l'encodage ne réémet AUCUNE clé de sync.
        expect(encoded.containsKey(ZSyncMeta.kUpdatedAt), isFalse);
        expect(encoded.containsKey(ZSyncMeta.kIsDeleted), isFalse);
      });
    }

    test('AD-10 : `registry.decode(kind, {})` ne lève pour AUCUN des 3 kinds', () {
      final r = buildRegistry();
      for (final kind in r.kinds) {
        expect(() => r.decode(kind, <String, dynamic>{}), returnsNormally,
            reason: 'kind = $kind');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 🟠 ANTI-H2 — LE CANAL HORS-CODEGEN EST OBSERVÉ, PAS AFFIRMÉ.
  //
  // ⚠️ RE-STATUÉ (H1, code-review ES-2.1). La justification d'origine de ce
  // groupe — « parce qu'AUCUNE des assertions (a)…(e) du gate ne regarde
  // `learning` » — était EXACTE, et c'était précisément le problème : ce groupe
  // était un filet ARTISANAL, ÉCRIT À LA MAIN, PAR CANAL, dans un package. Rien
  // n'aurait obligé le PROCHAIN canal hors-codegen (ES-2.2 `ZSmartNote.content`,
  // ES-2.5…) à naître avec le sien — R1 violé. Le gate, lui, restait VERT quand
  // on retirait `kLearningKey` de `_reservedKeys` (mesuré).
  //
  // Le filet GÉNÉRIQUE existe désormais, et il MORD (injections rejouées) :
  //   - **(f)** volet (A) du harnais : `extra ∩ corps-de-sonde == ∅` — couvre
  //     `source`, `learning` et TOUT canal futur, SANS une ligne par entité ;
  //   - **(g1)/(g2)** volet AST du gate : un canal hors-codegen (champ ni
  //     `@ZcrudField` ni `extra`/`extension` d'une entité `ZExtensible`) DOIT
  //     être RÉSERVÉ **et** PORTÉ PAR LA SONDE.
  //
  // ## Pourquoi ce groupe est CONSERVÉ malgré tout (décision explicite)
  //
  // Il n'est PAS redondant — il observe **strictement plus** que (f), qui ne
  // regarde que l'intersection avec `extra` :
  //   1. la RECONSTRUCTION TYPÉE du canal (`qualityByPage` en `Map<int,int>`,
  //      `masteredCount`) — (f) ne dit rien du décodage métier ;
  //   2. la RÉÉMISSION À L'IDENTIQUE du payload (`encoded['learning'] == payload`) ;
  //   3. le chemin CORROMPU (`learning: 'pas une map'` ⇒ `empty`, jamais de throw).
  //
  // Et il tourne là où le gate ne tourne PAS : le harnais est dans `melos.ignore`
  // ⇒ **`melos run test` ne l'exécute pas** (seul `melos run verify` le fait). Ce
  // groupe est donc le signal de la suite de tests ; (f)/(g) sont celui du gate.
  // **Défense en profondeur, assumée — plus le SEUL filet.**
  // ═══════════════════════════════════════════════════════════════════════════
  group('anti-H2 — canal `learning` : round-trip REGISTRE OBSERVÉ', () {
    test('`learning` survit à `registry.decode` → `registry.encode`', () {
      final r = buildRegistry();
      const payload = <String, dynamic>{
        'quality_by_page': <String, dynamic>{'1': 2, '3': 0},
      };
      final entity = r.decode('document_reading_state', <String, dynamic>{
        'doc_id': 'd1',
        'current_page': 3,
        'learning': payload,
      }) as ZDocumentReadingState;

      // Décodage : le canal est bien reconstruit en objet typé.
      expect(entity.learning.qualityByPage, equals(<int, int>{1: 2, 3: 0}));
      expect(entity.learning.masteredCount, 1);

      // Ré-encodage : le canal est bien RÉÉMIS, à l'identique.
      final encoded = r.encode('document_reading_state', entity);
      expect(
        encoded['learning'],
        equals(payload),
        reason: 'H2 : un canal hors-codegen ne doit JAMAIS être déclaré '
            '« préservé » sans qu\'une machine l\'observe. Si ce test rougit, le '
            'câblage manuel de `learning` (fromMap/toMap/_reservedKeys) a été '
            'cassé — la perte serait SILENCIEUSE.',
      );

      // Et il n'est PAS dupliqué dans `extra` (clé réservée).
      expect(entity.extra.containsKey('learning'), isFalse);
    });

    test('`learning` corrompu sur la voie registre ⇒ `empty`, jamais de throw', () {
      final r = buildRegistry();
      final entity = r.decode('document_reading_state', <String, dynamic>{
        'doc_id': 'd1',
        'learning': 'pas une map',
      }) as ZDocumentReadingState;
      expect(entity.learning, ZDocumentLearningInfo.empty);
      // Réémis vide — jamais absent (round-trip idempotent).
      expect(r.encode('document_reading_state', entity)['learning'],
          equals(<String, dynamic>{'quality_by_page': <String, dynamic>{}}));
    });
  });
}
