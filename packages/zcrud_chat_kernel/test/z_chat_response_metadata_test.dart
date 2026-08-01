// CHAT-7 — carte OUVERTE de fin de réponse (`ZChatResponseMetadata`).
//
// 🔴 Ce que ces tests protègent, et qui n'est PAS une préférence de style :
//  • le socle **transporte des verdicts**, il n'en calcule aucun ;
//  • une carte vide ne fabrique **ni exception ni valeur trompeuse** (leçon de
//    l'instantané de quota à zéro, qui se lit « épuisé » et bloque
//    l'utilisateur d'un déploiement où le quota est désactivé) ;
//  • un champ au mauvais type ne fait **pas échouer le parent** (AD-10) ;
//  • une note inconnue est **préservée**, pas jetée (carte OUVERTE, AD-4).
//
// Aucun `dart:io` ici : ce fichier doit tourner tel quel sous `dart test -p
// node` (gate `web-determinism`). Les gardes qui LISENT les sources vivent dans
// `z_chat_response_metadata_guard_test.dart`, annoté `@TestOn('vm')`.

import 'package:test/test.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

/// Carte de fin de réponse **réelle** de lex, recopiée depuis la composition
/// serveur : `backend/app/api/v1/chat/routes.py:1292-1315` (base
/// `duration_ms`/`agents_called`/`cost_total_usd`/`tokens_total`, fusion de
/// `_build_confidence_metadata` `routes.py:85-97`, puis `source_freshness`
/// composé par `app/services/agents/source_inspector.py:371-397`).
Map<String, dynamic> lexDoneMetadata() => <String, dynamic>{
  'duration_ms': 4210,
  'agents_called': <String>['retriever', 'writer'],
  'cost_total_usd': 0.0142,
  'tokens_total': 5312,
  'faithfulness_score': 0.91,
  'completeness_score': 0.84,
  'quality_grade': 'pass',
  'citation_guard_status': 'ok',
  'citations_verified': 3,
  'citations_rejected': 0,
  'coverage_status': 'available',
  'source_freshness': <Map<String, dynamic>>[
    <String, dynamic>{
      'dataset_id': 'cd-2021',
      'domain': 'code',
      'generated_at': '2026-05-04T10:00:00.000Z',
      'checksum': 'abc123',
      'freshness': 'fresh',
      'pending_amendments': <Object?>[],
      'is_potentially_outdated': false,
      'version': '3',
      'title': 'Code des douanes',
    },
  ],
};

void main() {
  group('CHAT-7 — décodage de la carte RÉELLE de lex', () {
    test('les verdicts du serveur traversent intégralement', () {
      final ZChatResponseMetadata meta = ZChatResponseMetadata.fromJson(
        lexDoneMetadata(),
        verifiedSourceCount: 3,
        totalSourceCount: 3,
      );

      expect(meta.durationMs, 4210);
      expect(meta.agentsCalled, <String>['retriever', 'writer']);
      expect(meta.costTotalUsd, closeTo(0.0142, 1e-9));
      expect(meta.tokensTotal, 5312);

      final ZChatResponseConfidence? c = meta.confidence;
      expect(c, isNotNull, reason: 'sept signaux présents : verdict attendu');
      expect(c!.faithfulnessScore, closeTo(0.91, 1e-9));
      expect(c.completenessScore, closeTo(0.84, 1e-9));
      expect(c.qualityGrade, 'pass');
      expect(c.citationGuardStatus, 'ok');
      expect(c.citationsVerified, 3);
      expect(c.citationsRejected, 0);
      expect(c.coverageStatus, 'available');
      expect(c.verifiedSourceCount, 3);
      expect(c.totalSourceCount, 3);
      // Le palier est DÉRIVÉ par la règle CHAT-0, pas recalculé ici.
      expect(c.level, ZChatConfidenceLevel.high);

      expect(meta.sourceFreshness, hasLength(1));
      final ZChatSourceFreshness f = meta.sourceFreshness.single;
      expect(f.datasetId, 'cd-2021');
      expect(f.freshness, ZChatDatasetFreshness.fresh);
      expect(f.version, '3');
      expect(f.title, 'Code des douanes');
      expect(f.lastIndexedAt, isNotNull, reason: 'alias `generated_at`');
      expect(f.pendingUpdates, isFalse);
      expect(f.isPotentiallyOutdated, isFalse);

      // Le drapeau DÉRIVÉ `is_potentially_outdated` du serveur n'est pas un
      // champ typé : il n'est pas rejoué, mais il n'est pas non plus jeté.
      expect(meta.extra.containsKey('is_potentially_outdated'), isFalse,
          reason: 'il appartient à la FICHE, pas à la carte de premier niveau');
      expect(meta.extra, isEmpty,
          reason: 'la carte réelle de lex est intégralement typée');
      expect(meta.isEmpty, isFalse);
    });

    test('le garde-citations dégradé fait redescendre le palier (verdict '
        'SERVEUR, jamais recalculé par le socle)', () {
      final Map<String, dynamic> raw = lexDoneMetadata()
        ..['citation_guard_status'] = 'all_rejected';
      final ZChatResponseMetadata meta = ZChatResponseMetadata.fromJson(
        raw,
        verifiedSourceCount: 3,
        totalSourceCount: 3,
      );
      expect(meta.confidence!.level, ZChatConfidenceLevel.toVerify);
    });
  });

  group('CHAT-7 — une carte vide ne fabrique NI exception NI valeur '
      'trompeuse', () {
    test('carte vide ⇒ `empty`, aucun champ inventé', () {
      final ZChatResponseMetadata meta = ZChatResponseMetadata.fromJson(
        <String, dynamic>{},
      );
      expect(meta, ZChatResponseMetadata.empty);
      expect(meta.isEmpty, isTrue);
      expect(meta.durationMs, isNull, reason: '`0 ms` se lirait « instantané »');
      expect(meta.tokensTotal, isNull);
      expect(meta.costTotalUsd, isNull, reason: '`0.0` se lirait « gratuit »');
      expect(meta.agentsCalled, isEmpty);
      expect(meta.sourceFreshness, isEmpty);
      expect(meta.extra, isEmpty);
      expect(meta.toJson(), isEmpty);
    });

    test('🔴 carte vide ⇒ AUCUN agrégat de confiance — un « à vérifier » est '
        'un VERDICT, pas un défaut', () {
      expect(
        ZChatResponseMetadata.fromJson(<String, dynamic>{}).confidence,
        isNull,
        reason: 'un backend muet (IFFD, ou lex avec ses nœuds désactivés) '
            'afficherait sinon un verdict de défiance que PERSONNE n\'a émis',
      );
    });

    test('un signal présent mais NON ÉVALUÉ (`null`, sémantique FR20 du '
        'serveur) reste indiscernable d\'une clé absente', () {
      // `_build_confidence_metadata` (routes.py:88-90) émet la clé TELLE QUELLE
      // quand elle vaut `None` dans le state : « présent mais non noté ».
      final ZChatResponseMetadata meta = ZChatResponseMetadata.fromJson(
        <String, dynamic>{
          'faithfulness_score': null,
          'completeness_score': null,
          'quality_grade': null,
        },
      );
      expect(meta.confidence, isNull);
    });

    test('un backend SANS contrat (carte absente / non-Map) ⇒ `empty`, jamais '
        'une exception', () {
      for (final Object? raw in <Object?>[
        null,
        'done',
        42,
        <Object?>['duration_ms'],
        true,
      ]) {
        expect(ZChatResponseMetadata.fromJson(raw), ZChatResponseMetadata.empty,
            reason: 'entrée $raw');
      }
    });

    test('un score RÉELLEMENT nul se distingue d\'un score absent', () {
      final ZChatResponseMetadata zero = ZChatResponseMetadata.fromJson(
        <String, dynamic>{'faithfulness_score': 0.0, 'cost_total_usd': 0.0},
      );
      expect(zero.confidence, isNotNull);
      expect(zero.confidence!.faithfulnessScore, 0.0);
      expect(zero.costTotalUsd, 0.0);

      final ZChatResponseMetadata absent = ZChatResponseMetadata.fromJson(
        <String, dynamic>{},
      );
      expect(absent.confidence, isNull);
      expect(absent.costTotalUsd, isNull);
    });
  });

  group('CHAT-7 — un champ au mauvais type ne fait PAS échouer le parent', () {
    test('chaque champ typé corrompu est traité comme absent, les autres '
        'survivent', () {
      final ZChatResponseMetadata meta = ZChatResponseMetadata.fromJson(
        <String, dynamic>{
          'duration_ms': 'beaucoup',
          'agents_called': 42,
          'cost_total_usd': <String, dynamic>{'usd': 1},
          'tokens_total': <Object?>[],
          'source_freshness': <String, dynamic>{'dataset_id': 'x'},
          'quality_grade': 'pass',
        },
      );
      expect(meta.durationMs, isNull);
      expect(meta.agentsCalled, isEmpty);
      expect(meta.costTotalUsd, isNull);
      expect(meta.tokensTotal, isNull);
      expect(meta.sourceFreshness, isEmpty);
      // Le parent SURVIT : le seul champ lisible est bien lu.
      expect(meta.confidence, isNotNull);
      expect(meta.confidence!.qualityGrade, 'pass');
    });

    test('une fiche de fraîcheur illisible n\'emporte pas les autres', () {
      final ZChatResponseMetadata meta = ZChatResponseMetadata.fromJson(
        <String, dynamic>{
          'source_freshness': <Object?>[
            'pas une fiche',
            <String, dynamic>{'dataset_id': 'tec-2022', 'freshness': 'stale'},
            null,
          ],
        },
      );
      expect(meta.sourceFreshness, hasLength(1));
      expect(meta.sourceFreshness.single.datasetId, 'tec-2022');
      expect(meta.sourceFreshness.single.isPotentiallyOutdated, isTrue);
    });

    test('un élément non-String de `agents_called` est ignoré, la liste '
        'survit', () {
      final ZChatResponseMetadata meta = ZChatResponseMetadata.fromJson(
        <String, dynamic>{
          'agents_called': <Object?>['retriever', 7, null, 'writer'],
        },
      );
      expect(meta.agentsCalled, <String>['retriever', 'writer']);
    });
  });

  group('CHAT-7 — une note inconnue est PRÉSERVÉE, pas jetée (carte '
      'OUVERTE)', () {
    test('les clés non typées traversent verbatim et ressortent au toJson', () {
      final Map<String, dynamic> raw = lexDoneMetadata()
        ..['coverage_disclaimer'] = 'Couverture partielle du corpus.'
        ..['une_cle_future_du_serveur'] = <String, dynamic>{'n': 1}
        ..['cache_hit'] = true;

      final ZChatResponseMetadata meta = ZChatResponseMetadata.fromJson(raw);
      expect(meta.extra.keys, containsAll(<String>[
        'coverage_disclaimer',
        'une_cle_future_du_serveur',
        'cache_hit',
      ]));
      expect(meta.extra['coverage_disclaimer'],
          'Couverture partielle du corpus.');
      expect(meta.extra['une_cle_future_du_serveur'],
          <String, dynamic>{'n': 1});

      final Map<String, dynamic> back = meta.toJson();
      expect(back['coverage_disclaimer'], 'Couverture partielle du corpus.');
      expect(back['cache_hit'], isTrue);
      expect(back['une_cle_future_du_serveur'], <String, dynamic>{'n': 1});
    });

    test('aller-retour SANS PERTE sur la carte réelle enrichie d\'inconnues',
        () {
      final Map<String, dynamic> raw = lexDoneMetadata()
        ..['note_inconnue'] = 'ø';
      final ZChatResponseMetadata first = ZChatResponseMetadata.fromJson(
        raw,
        verifiedSourceCount: 3,
        totalSourceCount: 3,
      );
      final ZChatResponseMetadata second = ZChatResponseMetadata.fromJson(
        first.toJson(),
      );
      expect(second, first,
          reason: 'les comptes de sources doivent survivre au round-trip via '
              'les clés persistées, sans être re-fournis par l\'appelant');
      expect(second.extra['note_inconnue'], 'ø');
    });
  });

  group('CHAT-7 — câblage sur l\'événement TERMINAL du flux', () {
    test('`ZChatDoneEvent.responseMetadata()` lit la carte du fil', () {
      final ZChatStreamEvent? event = ZChatStreamEvent.fromJson(
        <String, dynamic>{
          'type': 'done',
          'message_id': 'm1',
          'conversation_id': 'c1',
          'metadata': lexDoneMetadata(),
        },
      );
      expect(event, isA<ZChatDoneEvent>());
      final ZChatDoneEvent done = event! as ZChatDoneEvent;

      final ZChatResponseMetadata meta = done.responseMetadata(
        verifiedSourceCount: 2,
        totalSourceCount: 2,
      );
      expect(meta.durationMs, 4210);
      expect(meta.confidence!.verifiedSourceCount, 2,
          reason: 'les comptes viennent de l\'APPELANT : le serveur ne les '
              'émet pas dans `done.metadata`');
      // La carte BRUTE reste intacte : la lecture typée est DÉRIVÉE.
      expect(done.metadata, lexDoneMetadata());
    });

    test('un `done` sans métadonnées rend une carte VIDE, pas un verdict', () {
      const ZChatDoneEvent done = ZChatDoneEvent(
        messageId: 'm1',
        conversationId: 'c1',
      );
      final ZChatResponseMetadata meta = done.responseMetadata();
      expect(meta.isEmpty, isTrue);
      expect(meta.confidence, isNull,
          reason: 'IFFD n\'a AUCUN contrat de fin de réponse : son hôte ne doit '
              'pas hériter d\'un « à vérifier » fabriqué par le socle');
    });

    test('un `done` dont les métadonnées sont corrompues ne casse pas le '
        'décodage de l\'événement', () {
      final ZChatStreamEvent? event = ZChatStreamEvent.fromJson(
        <String, dynamic>{
          'type': 'done',
          'message_id': 'm1',
          'conversation_id': 'c1',
          'metadata': 'corrompu',
        },
      );
      expect(event, isA<ZChatDoneEvent>());
      expect((event! as ZChatDoneEvent).responseMetadata().isEmpty, isTrue);
    });
  });

  group('CHAT-7 — égalité de VALEUR', () {
    test('deux cartes identiques (extra et listes compris) sont égales', () {
      final ZChatResponseMetadata a = ZChatResponseMetadata.fromJson(
        lexDoneMetadata()..['x'] = <Object?>[1, 2],
      );
      final ZChatResponseMetadata b = ZChatResponseMetadata.fromJson(
        lexDoneMetadata()..['x'] = <Object?>[1, 2],
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('une note inconnue différente rend les cartes différentes', () {
      final ZChatResponseMetadata a = ZChatResponseMetadata.fromJson(
        <String, dynamic>{'note': 'a'},
      );
      final ZChatResponseMetadata b = ZChatResponseMetadata.fromJson(
        <String, dynamic>{'note': 'b'},
      );
      expect(a, isNot(b));
    });
  });
}
