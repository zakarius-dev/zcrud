/// SU-7 / AC9 — **CONTRAT D'HÔTE du moteur d'examen** : `answers` est
/// POSITIONNEL-PAR-ARRIVÉE, et seul un scorer **COMMUTATIF** est admissible.
///
/// # 🔴 Pourquoi ce fichier existe
///
/// AC9 exige, mot pour mot : « l'apprenant répond **dans un ordre quelconque** (y
/// compris en sautant des questions, puis en revenant) ⇒ chaque qualité est
/// **enregistrée sur SA carte** — jamais décalée d'un cran. »
///
/// **Cette clause est SATISFAITE sur le canal que su-7 possède** — `onAnswered`
/// émet l'index de SA carte, et la `Map` de l'hôte range sous cette position ;
/// c'est gardé par `z_list_session_view_mapping_test.dart` (axe « la correction
/// de CHAQUE carte est peinte SUR SA carte »).
///
/// **Elle est FAUSSE sur le canal `hôte → moteur`**, et ce fichier le **FIGE**
/// plutôt que de le laisser « certifié absent » :
/// `ZWhiteExamSessionEngine.answer(int quality)` est **positionnel** — il
/// enregistre pour `queue[cursor]` et avance d'un cran. Il **n'a aucun moyen**
/// de représenter un saut ou une réponse hors-ordre, alors que `ZListSessionView`
/// rend les N cartes **toutes saisissables** (l'ordre libre est son mode
/// **nominal**, exigé par AC9/AC6).
///
/// # Ce qui est en jeu (pourquoi ce n'est pas cosmétique)
///
/// Le dégât est **contenu aujourd'hui** — `scoreWhiteExam` est un comptage
/// **commutatif**, et l'affichage passe par la `Map`, jamais par `answers`. Mais
/// [ZExamScoringPort] est un **seam PUBLIC** : un scorer positionnel légitime
/// (« la question 1 vaut double ») lirait `qualities[0]` en croyant tenir `Q1` et
/// **noterait la mauvaise question** ⇒ **note fausse pour l'apprenant, sans
/// aucune exception**. La commutativité qui sauve aujourd'hui est une propriété
/// du **défaut**, jamais du **contrat** — jusqu'à ces tests.
///
/// # Voie retenue (et pourquoi les deux autres ont été écartées)
///
/// - ❌ *Faire porter l'index au moteur* (`answer({index, quality})`) : c'est un
///   **changement de contrat du DOMAINE**, consommé par 20+ tests d'une story
///   antérieure (`z_white_exam_session_test.dart`), et **D10 met explicitement
///   le moteur hors périmètre de su-7**. À porter par une story dédiée.
/// - ❌ *Contraindre l'ordre dans la vue* (ne rendre saisissable que
///   `cards[engine.answered]`) : **contredit AC9 et AC6 tels qu'ÉCRITS** (« ordre
///   quelconque », « sauter une question »). Amender une AC est une **décision
///   owner**, pas un correctif de revue.
/// - ✅ *Documenter honnêtement + GARDER le seam public* : la prose cesse de
///   mentir, la limite devient **visible et figée**, et la seule précondition qui
///   rend le système correct (**commutativité**) est **testée** au lieu d'être
///   espérée. Aucune AC n'est contredite, aucun contrat de domaine n'est cassé.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

import 'z_exam_harness.dart';

void main() {
  const config = ZSrsConfig();

  void useLargeSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> answerCard(
    WidgetTester tester,
    String q, {
    required bool correctly,
  }) async {
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text(q),
          matching: find.byType(ZFlashcardAnswerInput),
        ),
        matching: find.byKey(correctly ? EK.answerTrue : EK.answerFalse),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('🔴 AC9 — le contrat RÉEL de `engine.answers` (positionnel-par-arrivée)',
      () {
    testWidgets('sous saisie DÉSORDONNÉE, `answers` suit le rang d\'ARRIVÉE — '
        '`answers[i]` ne désigne PAS `queue[i]` (limite FIGÉE, pas un défaut '
        'silencieux)', (tester) async {
      useLargeSurface(tester);
      // Scénario EXACT de la sonde de revue : Q3 juste, Q1 faux, Q2 SAUTÉE.
      await tester.pumpWidget(
        ExamHost(
          cards: <ZFlashcard>[examCard('Q1'), examCard('Q2'), examCard('Q3')],
        ),
      );
      await answerCard(tester, 'Q3', correctly: true);
      await answerCard(tester, 'Q1', correctly: false);

      final host = tester.state<ExamHostState>(find.byType(ExamHost));
      final engine = host.engine;

      // 🔒 La VÉRITÉ de ce que l'apprenant a fait — lue dans la `Map` de la vue,
      // le SEUL canal fiable (indexé par position de carte).
      expect(host.submissions[2]!.quality, config.maxQuality, reason: 'Q3 juste');
      expect(host.submissions[0]!.quality, config.minQuality, reason: 'Q1 faux');
      expect(host.submissions.containsKey(1), isFalse, reason: 'Q2 sautée');

      // 🔴 Ce que le MOTEUR a enregistré : le rang d'ARRIVÉE. C'est la limite
      // documentée sur `ZWhiteExamSessionEngine.answer`. Elle est **assérée**
      // pour qu'une story qui la lèverait (`answer({index, quality})`) fasse
      // **rougir ce test** au lieu de partir en silence.
      expect(
        engine.state.answers,
        <int>[config.maxQuality, config.minQuality],
        reason: '🔴 `answers` = [note de Q3, note de Q1] — l\'ordre d\'ARRIVÉE. '
            'Lu POSITIONNELLEMENT contre `queue` = [Q1,Q2,Q3], cela dirait : '
            'Q1 vaut 5 (c\'est la note de Q3), Q2 vaut 0 (elle n\'a JAMAIS été '
            'répondue), Q3 nulle part. LES TROIS attributions seraient fausses. '
            'Si ce test rougit parce que le moteur porte désormais l\'index : '
            'BRAVO — supprimez la limite documentée avec lui.',
      );

      // 🔴 Corollaire : `current`/`cursor` sont eux aussi ININTERPRÉTABLES sous
      // cet hôte non-linéaire — `current` désigne Q3 (**déjà répondue**) pendant
      // que Q2, la vraie carte vierge, est réputée traitée.
      expect(
        engine.state.cursor,
        2,
        reason: '🔴 le curseur a avancé de 2 crans par ARRIVÉE, sans rapport '
            'avec les cartes réellement répondues (0 et 2).',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('l\'AGRÉGAT reste JUSTE malgré le désordre — c\'est ce qui rend '
        'la limite tenable (et c\'est TOUT ce sur quoi su-7 s\'appuie)',
        (tester) async {
      useLargeSurface(tester);
      await tester.pumpWidget(
        ExamHost(
          cards: <ZFlashcard>[examCard('Q1'), examCard('Q2'), examCard('Q3')],
        ),
      );
      await answerCard(tester, 'Q3', correctly: true);
      await answerCard(tester, 'Q1', correctly: false);

      await tester.tap(find.byKey(ZListSessionView.submitKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ZListSessionView.confirmKey));
      await tester.pumpAndSettle();

      final host = tester.state<ExamHostState>(find.byType(ExamHost));
      final result = host.engine.result!;
      // 🔒 L'agrégat est insensible à la permutation : 2 réponses, 1 réussie.
      // C'est **la seule** lecture de `answers` que su-7 s'autorise.
      expect(result.total, 2);
      expect(result.correct, 1);
      expect(tester.takeException(), isNull);
    });
  });

  group('🔴 AC9 — `ZExamScoringPort` : la COMMUTATIVITÉ est une PRÉCONDITION du '
      'seam public, pas un accident du défaut', () {
    test('`scoreWhiteExam` est COMMUTATIF — toute permutation rend le MÊME '
        'agrégat', () {
      const qualities = <int>[5, 0, 3, 1, 4];
      final reference = scoreWhiteExam(
        qualities,
        passThreshold: config.passThreshold,
      );

      // 🔒 Contre-preuve de NON-VACUITÉ : l'agrégat de référence n'est pas
      // dégénéré (sans quoi « toutes les permutations sont égales » serait vrai
      // pour de mauvaises raisons).
      expect(reference.total, 5);
      expect(reference.correct, greaterThan(0));
      expect(reference.correct, lessThan(reference.total));

      // 🔒 Le scan est **NON VIDE** et **EXERCE** le vrai scorer sur des
      // permutations réelles — jamais une ré-implémentation de la règle.
      final permutations = <List<int>>[
        <int>[0, 5, 3, 1, 4],
        <int>[4, 1, 3, 0, 5],
        <int>[5, 4, 3, 1, 0],
        <int>[1, 3, 4, 5, 0],
        qualities.reversed.toList(),
      ];
      expect(permutations, isNotEmpty);

      for (final permutation in permutations) {
        final scored = scoreWhiteExam(
          permutation,
          passThreshold: config.passThreshold,
        );
        expect(
          scored.total,
          reference.total,
          reason: '🔴 $permutation : `total` a changé sous permutation.',
        );
        expect(
          scored.correct,
          reference.correct,
          reason: '🔴 $permutation : `correct` a changé sous permutation ⇒ le '
              'scorer par défaut n\'est PLUS commutatif. Or `answers` est '
              'positionnel-par-arrivée : un scorer non-commutatif noterait la '
              'MAUVAISE question dès que l\'apprenant répond dans le désordre.',
        );
        expect(
          scored.byQuality,
          reference.byQuality,
          reason: '🔴 $permutation : `byQuality` a changé sous permutation.',
        );
      }
    });

    test('🔴 un scorer POSITIONNEL (« la question 1 vaut double ») produit une '
        'NOTE FAUSSE sous désordre — la démonstration de POURQUOI le contrat '
        'exige la commutativité', () {
      // Ce scorer est **légitime en apparence** et **compile** : c'est
      // exactement ce qu'une app branche sur le seam public.
      ZStudySessionResult positionalScorer(
        List<int> qualities, {
        required int passThreshold,
      }) {
        var correct = 0;
        for (var i = 0; i < qualities.length; i++) {
          final weight = i == 0 ? 2 : 1; // « la question 1 vaut double »
          if (qualities[i] >= passThreshold) correct += weight;
        }
        return ZStudySessionResult(
          mode: ZReviewMode.whiteExam,
          total: qualities.length,
          correct: correct,
          byQuality: const <String, int>{},
        );
      }

      // Même apprenant, même copie — seul l'ORDRE DE RÉPONSE diffère.
      // Il répond dans l'ordre : Q1 juste (5), Q2 faux (0).
      final inOrder = positionalScorer(<int>[5, 0], passThreshold: 3);
      // Il répond dans le désordre : Q2 d'abord (0), puis Q1 (5).
      final outOfOrder = positionalScorer(<int>[0, 5], passThreshold: 3);

      expect(
        inOrder.correct,
        isNot(outOfOrder.correct),
        reason: '🔴 Si ces deux valeurs devenaient égales, ce scorer serait '
            'commutatif et la démonstration serait vide.',
      );
      expect(inOrder.correct, 2, reason: 'Q1 juste comptée double');
      expect(
        outOfOrder.correct,
        1,
        reason: '🔴 LA MÊME COPIE vaut 1 au lieu de 2, pour la seule raison que '
            'l\'apprenant a répondu à Q2 en premier : le scorer a appliqué le '
            'coefficient de Q1 à Q2. C\'est la NOTE FAUSSE que le contrat de '
            '`ZExamScoringPort` interdit — d\'où « seul un scorer COMMUTATIF '
            'est admissible » tant que le moteur reste positionnel.',
      );
    });
  });
}
