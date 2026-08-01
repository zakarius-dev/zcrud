// CHAT-0 — AC7/AC8. Gardes **G1** (round-trip par type) et **G9** (règles
// dérivées FAIL-SAFE : `ZChatResponseConfidence.level`,
// `ZChatSourceFreshness.isPotentiallyOutdated`).
import 'package:test/test.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

void main() {
  group('G1 — round-trip de chaque value object', () {
    test('ZChatThinkingStep', () {
      final ZChatThinkingStep step = ZChatThinkingStep(
        agent: 'planner',
        content: 'analyse',
        timestamp: DateTime.utc(2026, 7, 9, 12),
      );
      expect(ZChatThinkingStep.fromJson(step.toJson()), equals(step));
      // Sonde de mordant : chaque champ discrimine.
      expect(step, isNot(step.copyWith(agent: 'autre')));
    });

    test('ZChatAttachment', () {
      const ZChatAttachment a = ZChatAttachment(
        id: 'a1',
        url: 'https://exemple/x',
        mimeType: 'image/png',
        fileName: 'x.png',
      );
      expect(ZChatAttachment.fromJson(a.toJson()), equals(a));
      expect(a, isNot(a.copyWith(fileName: 'y.png')));
    });

    test('ZChatSuggestion + ZChatSuggestionAction (payload imbriqué)', () {
      const ZChatSuggestion s = ZChatSuggestion(
        id: 's1',
        type: 'followUp',
        content: 'et ensuite ?',
        actions: <ZChatSuggestionAction>[
          ZChatSuggestionAction(
            shortcut: 'k',
            title: 't',
            description: 'd',
            actionType: 'sendMessage',
            payload: <String, dynamic>{
              'a': 1,
              'l': <dynamic>[
                1,
                <String, dynamic>{'b': 2},
              ],
            },
          ),
        ],
      );
      final ZChatSuggestion? relu = ZChatSuggestion.fromJson(s.toJson());
      expect(relu, equals(s));
      expect(<Object>{relu!, s}, hasLength(1),
          reason: 'égalité PROFONDE du payload d\'action');
    });

    test('ZChatQuotaSnapshot', () {
      const ZChatQuotaSnapshot q = ZChatQuotaSnapshot(
        limit: 10,
        remaining: 3,
        resetEpoch: 1234,
        prepaidBalance: 5,
      );
      expect(ZChatQuotaSnapshot.fromJson(q.toJson()), equals(q));
      expect(q, isNot(q.copyWith(prepaidBalance: 6)));
    });

    test('ZChatSourceFreshness', () {
      final ZChatSourceFreshness f = ZChatSourceFreshness(
        datasetId: 'd1',
        domain: 'dom',
        title: 'T',
        version: '2014',
        lastIndexedAt: DateTime.utc(2026),
        checksum: 'abc',
        freshness: ZChatDatasetFreshness.stale,
        pendingUpdates: true,
      );
      expect(ZChatSourceFreshness.fromJson(f.toJson()), equals(f));
    });

    test('ZChatResponseConfidence + ZChatConfidenceFactor', () {
      const ZChatResponseConfidence c = ZChatResponseConfidence(
        faithfulnessScore: 0.9,
        completenessScore: 0.8,
        qualityGrade: 'pass',
        citationGuardStatus: 'ok',
        citationsVerified: 3,
        citationsRejected: 0,
        coverageStatus: 'available',
        verifiedSourceCount: 3,
        totalSourceCount: 3,
      );
      expect(ZChatResponseConfidence.fromJson(c.toJson()), equals(c));
      const ZChatConfidenceFactor f = ZChatConfidenceFactor(
        code: 'faithfulness',
        humanValue: '90 %',
        sense: ZChatConfidenceFactorSense.positive,
      );
      expect(ZChatConfidenceFactor.fromJson(f.toJson()), equals(f));
    });
  });

  group('AC7 — brut ET typé (supérieur à lex)', () {
    test('un `type` inconnu survit en brut, le getter typé rend null', () {
      const ZChatSuggestion s = ZChatSuggestion(type: 'variantMaison');
      expect(s.type, 'variantMaison');
      expect(s.typedType, isNull);
      expect(ZChatSuggestion.fromJson(s.toJson())!.type, 'variantMaison',
          reason: 'round-trip LOSSLESS d\'une valeur inconnue');
    });

    test('un `type` connu est exposé TYPÉ (alias lex compris)', () {
      expect(const ZChatSuggestion(type: 'followUp').typedType,
          ZChatSuggestionType.followUp);
      expect(const ZChatSuggestion(type: 'follow_up').typedType,
          ZChatSuggestionType.followUp);
      expect(
        const ZChatSuggestionAction(actionType: 'send_message')
            .typedActionType,
        ZChatSuggestionActionType.sendMessage,
      );
      expect(
        const ZChatSuggestionAction(actionType: 'zzz').typedActionType,
        isNull,
      );
    });
  });

  group('AC7/AC8 — lecture défensive (AD-10) : aucun throw', () {
    test('raw non-map ⇒ null pour chaque value object', () {
      for (final Object? raw in <Object?>[null, 42, 'x', <dynamic>[]]) {
        expect(ZChatThinkingStep.fromJson(raw), isNull);
        expect(ZChatAttachment.fromJson(raw), isNull);
        expect(ZChatSuggestion.fromJson(raw), isNull);
        expect(ZChatSuggestionAction.fromJson(raw), isNull);
        expect(ZChatQuotaSnapshot.fromJson(raw), isNull);
        expect(ZChatSourceFreshness.fromJson(raw), isNull);
        expect(ZChatResponseConfidence.fromJson(raw), isNull);
        expect(ZChatConfidenceFactor.fromJson(raw), isNull);
      }
    });

    test('`timestamp` corrompu ⇒ null, l\'étape SURVIT (AD-10)', () {
      for (final Object? v in <Object?>[null, 'pas-une-date', 42]) {
        final ZChatThinkingStep? s = ZChatThinkingStep.fromJson(
          <String, dynamic>{'agent': 'a', 'content': 'c', 'timestamp': v},
        );
        expect(s, isNotNull);
        expect(s!.timestamp, isNull);
        expect(s.toJson().containsKey('timestamp'), isFalse);
      }
    });

    test('une action illisible n\'annule pas la liste d\'actions (G10)', () {
      final ZChatSuggestion? s = ZChatSuggestion.fromJson(<String, dynamic>{
        'id': 's',
        'actions': <dynamic>[
          <String, dynamic>{'shortcut': 'a'},
          42,
          null,
          <String, dynamic>{'shortcut': 'b'},
        ],
      });
      expect(s!.actions, hasLength(2));
    });
  });

  group('G9 — `ZChatSourceFreshness.isPotentiallyOutdated` FAIL-SAFE', () {
    test('true UNIQUEMENT sur `stale` OU `pendingUpdates`', () {
      expect(
        const ZChatSourceFreshness(freshness: ZChatDatasetFreshness.stale)
            .isPotentiallyOutdated,
        isTrue,
      );
      expect(
        const ZChatSourceFreshness(pendingUpdates: true)
            .isPotentiallyOutdated,
        isTrue,
      );
    });

    test('`unknown` reste NEUTRE — jamais marqué périmé', () {
      expect(
        const ZChatSourceFreshness(freshness: ZChatDatasetFreshness.unknown)
            .isPotentiallyOutdated,
        isFalse,
        reason: 'un checksum non comparable n\'est pas une preuve de péremption',
      );
      expect(
        const ZChatSourceFreshness(freshness: ZChatDatasetFreshness.fresh)
            .isPotentiallyOutdated,
        isFalse,
      );
    });

    test('alias legacy `pending_amendments` (liste non vide) lu', () {
      final ZChatSourceFreshness f = ZChatSourceFreshness.fromJson(
        <String, dynamic>{
          'dataset_id': 'd',
          'pending_amendments': <dynamic>['x'],
        },
      )!;
      expect(f.pendingUpdates, isTrue);
      expect(f.toJson()['pending_updates'], isTrue);
      expect(f.toJson().containsKey('pending_amendments'), isFalse,
          reason: 'le nom juridique n\'est plus RÉÉMIS');
    });

    test('`pending_amendments` vide ⇒ false', () {
      final ZChatSourceFreshness f = ZChatSourceFreshness.fromJson(
        <String, dynamic>{'dataset_id': 'd', 'pending_amendments': <dynamic>[]},
      )!;
      expect(f.pendingUpdates, isFalse);
    });
  });

  group('G9/AC8 — `ZChatResponseConfidence.level` : JAMAIS `high` par défaut',
      () {
    test('aucun signal ⇒ toVerify', () {
      const ZChatResponseConfidence c = ZChatResponseConfidence();
      expect(c.hasNoSignal, isTrue);
      expect(c.level, ZChatConfidenceLevel.toVerify);
    });

    test('garde-citations dégradé ⇒ toVerify MÊME avec de bons scores', () {
      for (final String guard in <String>['degraded', 'all_rejected', 'error']) {
        final ZChatResponseConfidence c = ZChatResponseConfidence(
          faithfulnessScore: 1.0,
          completenessScore: 1.0,
          citationGuardStatus: guard,
          coverageStatus: 'available',
          verifiedSourceCount: 5,
          totalSourceCount: 5,
        );
        expect(c.level, ZChatConfidenceLevel.toVerify, reason: 'guard=$guard');
      }
    });

    test('couverture dégradée ⇒ toVerify MÊME avec de bons scores', () {
      for (final String cov in <String>['unavailable', 'partial', 'error']) {
        final ZChatResponseConfidence c = ZChatResponseConfidence(
          faithfulnessScore: 1.0,
          completenessScore: 1.0,
          citationGuardStatus: 'ok',
          coverageStatus: cov,
          verifiedSourceCount: 5,
          totalSourceCount: 5,
        );
        expect(c.level, ZChatConfidenceLevel.toVerify, reason: 'coverage=$cov');
      }
    });

    test('sources attendues mais AUCUNE vérifiée ⇒ toVerify', () {
      const ZChatResponseConfidence c = ZChatResponseConfidence(
        faithfulnessScore: 1.0,
        completenessScore: 1.0,
        citationGuardStatus: 'ok',
        verifiedSourceCount: 0,
        totalSourceCount: 4,
      );
      expect(c.level, ZChatConfidenceLevel.toVerify);
    });

    test('scores `null` sans source concordante ⇒ toVerify', () {
      const ZChatResponseConfidence c = ZChatResponseConfidence(
        citationGuardStatus: 'ok',
        verifiedSourceCount: 0,
      );
      expect(c.level, ZChatConfidenceLevel.toVerify);
    });

    test('`high` exige les QUATRE conditions simultanément', () {
      const ZChatResponseConfidence bon = ZChatResponseConfidence(
        faithfulnessScore: 0.85,
        completenessScore: 0.75,
        citationGuardStatus: 'ok',
        verifiedSourceCount: 2,
        totalSourceCount: 2,
      );
      expect(bon.level, ZChatConfidenceLevel.high);

      // Chaque condition retirée fait redescendre — la garde est DISCRIMINANTE.
      expect(
        const ZChatResponseConfidence(
          faithfulnessScore: 0.79,
          completenessScore: 0.75,
          citationGuardStatus: 'ok',
          verifiedSourceCount: 2,
          totalSourceCount: 2,
        ).level,
        ZChatConfidenceLevel.moderate,
      );
      expect(
        const ZChatResponseConfidence(
          faithfulnessScore: 0.85,
          completenessScore: 0.69,
          citationGuardStatus: 'ok',
          verifiedSourceCount: 2,
          totalSourceCount: 2,
        ).level,
        ZChatConfidenceLevel.moderate,
      );
      expect(
        const ZChatResponseConfidence(
          faithfulnessScore: 0.85,
          completenessScore: 0.75,
          citationGuardStatus: 'ok',
          verifiedSourceCount: 1,
          totalSourceCount: 2,
        ).level,
        ZChatConfidenceLevel.moderate,
      );
      expect(
        const ZChatResponseConfidence(
          faithfulnessScore: 0.85,
          completenessScore: 0.75,
          citationGuardStatus: 'no_citations',
          verifiedSourceCount: 2,
          totalSourceCount: 2,
        ).level,
        ZChatConfidenceLevel.moderate,
      );
    });

    test('les seuils sont des CONSTANTES NOMMÉES (aucun littéral épars)', () {
      expect(ZChatConfidenceThresholds.faithfulnessHigh, 0.8);
      expect(ZChatConfidenceThresholds.completenessOk, 0.7);
      expect(ZChatConfidenceThresholds.minVerifiedForHigh, 2);
    });

    test('`factors` explicable : codes stables, aucun libellé traduisible', () {
      const ZChatResponseConfidence c = ZChatResponseConfidence(
        faithfulnessScore: 0.9,
        completenessScore: 0.5,
        citationGuardStatus: 'ok',
        coverageStatus: 'available',
        verifiedSourceCount: 1,
        totalSourceCount: 3,
      );
      final List<String> codes =
          c.factors.map((ZChatConfidenceFactor f) => f.code).toList();
      expect(
        codes,
        <String>[
          'faithfulness',
          'completeness',
          'citationGuard',
          'verifiedSources',
          'coverage',
        ],
      );
      expect(c.factors.first.sense, ZChatConfidenceFactorSense.positive);
      expect(c.factors[1].sense, ZChatConfidenceFactorSense.negative);
      expect(c.hasUnverifiedSources, isTrue);
      expect(() => c.factors.add(c.factors.first), throwsUnsupportedError);
    });

    test('un score absent n\'est JAMAIS coercé en 0.0', () {
      final ZChatResponseConfidence c =
          ZChatResponseConfidence.fromJson(<String, dynamic>{})!;
      expect(c.faithfulnessScore, isNull);
      expect(c.completenessScore, isNull);
    });
  });
}
