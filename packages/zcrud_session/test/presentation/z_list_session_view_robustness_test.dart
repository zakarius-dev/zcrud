/// SU-7 / AC6 — Robustesse **AD-10** : jamais de throw sur les chemins hostiles.
///
/// 🔴 **Le moteur LÈVE `StateError`** sur toute transition illégale (`answer`
/// hors `running`, **double `submit`**) — c'est **voulu** (« no-op muet
/// interdit ») et **hors périmètre** de su-7. L'UI ne les **rattrape pas** :
/// 🚫 **aucun `try-catch`**. Elle les rend **structurellement inatteignables** en
/// gatant toute affordance sur la **PHASE**. Un `catch` masquerait un bug de
/// gating au lieu de le révéler.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

import 'z_answer_input_harness.dart' show SpyEvaluationPort;
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
    bool correctly = true,
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

  testWidgets('AC6 — examen VIDE : état l10n, et soumission ABSENTE (jamais '
      'grisée)', (tester) async {
    await tester.pumpWidget(const ExamHost(cards: <ZFlashcard>[]));
    expect(find.byKey(ZListSessionView.emptyKey), findsOneWidget);
    // 🔒 `submit()` sur file vide serait LÉGAL côté moteur (`total: 0`) : on ne
    // le PROPOSE pas, plutôt que de le griser (patron AD-45).
    expect(find.byKey(ZListSessionView.submitKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AC6 — UNE seule question : aucun `RangeError`, soumission '
      'offerte dès la réponse', (tester) async {
    useLargeSurface(tester);
    await tester.pumpWidget(ExamHost(cards: <ZFlashcard>[examCard('Q1')]));
    await answerCard(tester, 'Q1');
    expect(find.byKey(ZListSessionView.submitKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AC6 — la file RÉTRÉCIT sous la vue : aucun `RangeError` (D8 — '
      '`key` dérivée de l\'identité de la file, patron su-4)', (tester) async {
    useLargeSurface(tester);
    final full = <ZFlashcard>[examCard('Q1'), examCard('Q2'), examCard('Q3')];
    await tester.pumpWidget(ExamHost(cards: full));
    await answerCard(tester, 'Q3');

    // La file rétrécit — le cas EXACT qui produisait un `RangeError` en su-4.
    await tester.pumpWidget(ExamHost(cards: <ZFlashcard>[examCard('Q1')]));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(ZFlashcardAnswerInput), findsOneWidget);

    // 🔴 **L'ABSENCE D'EXCEPTION NE PROUVE RIEN** — c'est le motif exact du HIGH
    // de su-4 : cette garde constatait qu'**UN** widget est là, jamais **CE
    // QU'IL DIT**. Elle est restée VERTE pendant que l'UI affichait
    // « **-2 questions sans réponse** ». Le compte est donc asséré, sur les
    // **DEUX canaux** (leçon su-6).
    expect(
      tester.widget<Text>(find.byKey(ZListSessionView.unansweredTextKey)).data,
      '1',
      reason: '🔴 la file rétrécie porte 1 carte VIERGE ⇒ 1 sans réponse. Un '
          'compte NÉGATIF (« -2 ») signifie que des clés PÉRIMÉES sont '
          'comptées (AD-10).',
    );
    expect(
      tester.getSemantics(find.byKey(ZListSessionView.unansweredKey)).value,
      '1',
      reason: '🔴 le lecteur d\'écran annonçait « -2 » — le canal sémantique '
          'doit dire la même VÉRITÉ que le canal visible.',
    );
  });

  testWidgets('🔴 AC6 — l\'HÔTE PURGE quand la file change : une carte NEUVE en '
      'position déjà répondue n\'HÉRITE PAS de la réponse de l\'ancienne',
      (tester) async {
    useLargeSurface(tester);
    // 🔴 **Le scénario où la défense de la VUE ne suffit PAS.** Si la clé
    // périmée est **HORS bornes**, la vue la filtre et le compte est juste sans
    // que l'hôte fasse quoi que ce soit. Mais ici la clé périmée `0` est **DANS
    // les bornes** : rien, côté vue, ne peut distinguer « position 0 répondue »
    // de « position 0 occupée par une carte NEUVE et VIERGE ». **Seul l'hôte
    // sait que la file a changé** — d'où `didUpdateWidget`.
    //
    // Sans la purge : Q9, jamais répondue, est réputée répondue ; le compte
    // sans réponse dit **0** au lieu de **1** ; et `_CorrectionReveal` peint sur
    // Q9 la **correction de l'ANCIENNE Q1**. C'est LITTÉRALEMENT « la
    // correction affichée pointe la mauvaise carte » — le risque n°1 de la
    // story, par la voie légitime, sans aucune exception.
    await tester.pumpWidget(
      ExamHost(cards: <ZFlashcard>[examCard('Q1'), examCard('Q2')]),
    );
    await answerCard(tester, 'Q1');

    final before = tester.state<ExamHostState>(find.byType(ExamHost));
    expect(
      before.submissions.containsKey(0),
      isTrue,
      reason: 'contre-preuve : la position 0 EST répondue avant le changement',
    );

    // La file change : une carte NEUVE et VIERGE occupe désormais la position 0.
    await tester.pumpWidget(
      ExamHost(cards: <ZFlashcard>[examCard('Q9'), examCard('Q8')]),
    );
    await tester.pumpAndSettle();

    final host = tester.state<ExamHostState>(find.byType(ExamHost));
    expect(
      host.submissions,
      isEmpty,
      reason: '🔴 les clés de [submissions] sont des POSITIONS : elles PÉRIMENT '
          'dès que `cards` change. Une position ne porte aucune identité ⇒ rien '
          'ne permet de savoir ce qu\'une clé périmée désignait. La purge doit '
          'être TOTALE — un remappage inventerait la correspondance.',
    );
    expect(
      host.engine.state.queue.map((i) => i.flashcardId),
      <String>['Q9', 'Q8'],
      reason: '🔴 `engine` était `late final` sans `didUpdateWidget` : sa file '
          'restait PÉRIMÉE (`[Q1,Q2]`) pendant que la vue rendait `[Q9,Q8]` — '
          'l\'hôte de RÉFÉRENCE incarnait la désynchronisation qu\'il prétend '
          'réfuter, dans le test censé prouver que le rétrécissement est géré.',
    );
    // Q9 est VIERGE : les 2 cartes sont sans réponse.
    expect(
      tester.widget<Text>(find.byKey(ZListSessionView.unansweredTextKey)).data,
      '2',
      reason: '🔴 Q9 hérite de la réponse de l\'ancienne Q1 : elle est comptée '
          'répondue alors que l\'apprenant ne l\'a JAMAIS vue.',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('🔴 AC6 — clés HORS BORNES sous la vue (hôte qui ne purge PAS) : '
      'le compte sans réponse reste dans `[0, cards.length]` — JAMAIS un '
      'NÉGATIF (AD-10)', (tester) async {
    useLargeSurface(tester);
    // 🔴 Ce test attaque **LA VUE**, pas l'`ExamHost` (qui purge désormais) :
    // la vue est **PUBLIQUE** (exportée au barrel), donc elle ne doit **pas
    // faire confiance** à un hôte tiers. Scénario MESURÉ : 3 clés {0,1,2}
    // survivent contre 1 seule carte ⇒ `1 - 3 = **-2**` s'affichait,
    // s'annonçait (`Semantics(value:'-2')`) et se **répétait dans le dialog de
    // confirmation** — au moment le plus irréversible du parcours, **sans
    // aucune exception**.
    //
    // ⚠️ **PORTÉE HONNÊTE de cette garde** — elle n'assère PAS « le compte est
    // la vérité ». La clé de [submissions] est une **POSITION**, pas une
    // identité : la vue **ne peut PAS savoir** que la clé `0` désignait une
    // carte **disparue** plutôt que la carte neuve occupant la position `0`.
    // Ce qu'elle garantit — et c'est **tout** ce qu'elle peut garantir — c'est
    // qu'aucune clé **hors `[0, cards.length)`** n'est comptée, donc **jamais
    // de compte négatif**. Que le compte soit **la VÉRITÉ** exige que l'hôte
    // **purge** : c'est un fait de l'hôte, gardé séparément par le test
    // « la file RÉTRÉCIT » ci-dessus (via le `didUpdateWidget` d'`ExamHost`).
    final stale = <int, ZFlashcardSubmission>{
      for (var i = 0; i < 3; i++)
        i: const ZFlashcardSubmission(
          quality: 5,
          timeTaken: Duration.zero,
          hintsUsed: 0,
        ),
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ZListSessionView(
            cards: <ZFlashcard>[examCard('Q9')],
            phase: ZExamViewPhase.running,
            submissions: stale,
            onAnswered: (_, __) {},
            onSubmit: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final shown =
        tester.widget<Text>(find.byKey(ZListSessionView.unansweredTextKey)).data;
    expect(
      int.parse(shown!),
      inInclusiveRange(0, 1),
      reason: '🔴 1 carte ⇒ le compte vit dans `[0, 1]`. « -2 » signifie que '
          'les clés PÉRIMÉES {1,2} — qui ne désignent AUCUNE carte — sont '
          'comptées (AD-10).',
    );
    expect(
      tester.getSemantics(find.byKey(ZListSessionView.unansweredKey)).value,
      shown,
      reason: '🔴 les DEUX canaux doivent dire le MÊME nombre (leçon su-6).',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('AC6 — réponses PARTIELLES : soumission possible ; les cartes '
      'non répondues ne sont PAS comptées fausses', (tester) async {
    useLargeSurface(tester);
    await tester.pumpWidget(
      ExamHost(
        cards: <ZFlashcard>[examCard('Q1'), examCard('Q2'), examCard('Q3')],
      ),
    );
    await answerCard(tester, 'Q2');

    await tester.tap(find.byKey(ZListSessionView.submitKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ZListSessionView.confirmKey));
    await tester.pumpAndSettle();

    final host = tester.state<ExamHostState>(find.byType(ExamHost));
    expect(
      host.engine.result!.total,
      1,
      reason: '🔴 `total` = les réponses RÉELLEMENT données (1), jamais 3 : une '
          'question sautée n\'est pas une faute, et l\'UI n\'invente aucune '
          'qualité pour elle.',
    );
    expect(host.engine.result!.correct, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AC6 — le nombre de questions SANS RÉPONSE est dit sur les DEUX '
      'canaux (visible ET sémantique)', (tester) async {
    useLargeSurface(tester);
    await tester.pumpWidget(
      ExamHost(
        cards: <ZFlashcard>[examCard('Q1'), examCard('Q2'), examCard('Q3')],
      ),
    );
    await answerCard(tester, 'Q1');

    // 🔴 Leçon su-6 : le streak n'existait QUE dans `Semantics(value:)` —
    // invisible à l'œil, test VERT. Ici les DEUX canaux sont assertés.
    expect(
      tester.widget<Text>(find.byKey(ZListSessionView.unansweredTextKey)).data,
      '2',
      reason: 'canal VISIBLE',
    );
    expect(
      tester.getSemantics(find.byKey(ZListSessionView.unansweredKey)).value,
      '2',
      reason: 'canal SÉMANTIQUE',
    );
  });

  testWidgets(
    '🔴 AC6 — DOUBLE SOUMISSION : l\'affordance DISPARAÎT en phase `submitted` '
    '⇒ le `StateError` du moteur est INATTEIGNABLE (aucun `try-catch`)',
    (tester) async {
      useLargeSurface(tester);
      await tester.pumpWidget(
        ExamHost(cards: <ZFlashcard>[examCard('Q1'), examCard('Q2')]),
      );
      await answerCard(tester, 'Q1');

      await tester.tap(find.byKey(ZListSessionView.submitKey));
      await tester.pumpAndSettle();
      // 🔴 On **TAPE RÉELLEMENT** le bouton de confirmation (présence ≠
      // association : su-4, le bouton « précédent » qui AVANÇAIT était vert
      // parce que jamais tapé).
      await tester.tap(find.byKey(ZListSessionView.confirmKey));
      await tester.pumpAndSettle();

      final host = tester.state<ExamHostState>(find.byType(ExamHost));
      expect(host.engine.isSubmitted, isTrue);

      // Le gate est la PHASE : l'affordance n'existe plus.
      expect(
        find.byKey(ZListSessionView.submitKey),
        findsNothing,
        reason: '🔴 la soumission reste offerte APRÈS soumission ⇒ un 2ᵉ tap '
            'appellerait `submit()` en phase `submitted` ⇒ `StateError`.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('🔴 AC6 — ANNULER le dialog ne soumet RIEN (le contrôle est '
      'ACTIONNÉ, pas seulement constaté)', (tester) async {
    useLargeSurface(tester);
    await tester.pumpWidget(
      ExamHost(cards: <ZFlashcard>[examCard('Q1'), examCard('Q2')]),
    );
    await answerCard(tester, 'Q1');

    await tester.tap(find.byKey(ZListSessionView.submitKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ZListSessionView.cancelKey));
    await tester.pumpAndSettle();

    final host = tester.state<ExamHostState>(find.byType(ExamHost));
    expect(host.engine.isSubmitted, isFalse,
        reason: '🔴 « Annuler » a soumis l\'examen — irréversiblement (D7).');
    expect(find.byKey(ZListSessionView.submitKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AC6 — après soumission, la saisie est INERTE ⇒ `answer()` hors '
      '`running` est inatteignable', (tester) async {
    useLargeSurface(tester);
    await tester.pumpWidget(
      ExamHost(cards: <ZFlashcard>[examCard('Q1'), examCard('Q2')]),
    );
    await answerCard(tester, 'Q1');
    await tester.tap(find.byKey(ZListSessionView.submitKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ZListSessionView.confirmKey));
    await tester.pumpAndSettle();

    final host = tester.state<ExamHostState>(find.byType(ExamHost));
    final before = List<int>.of(host.answeredIndexes);

    // 🔴 On TAPE la carte JAMAIS répondue, en phase `submitted`.
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('Q2'),
          matching: find.byType(ZFlashcardAnswerInput),
        ),
        matching: find.byKey(EK.answerTrue),
      ),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(host.answeredIndexes, before,
        reason: '🔴 une réponse est partie APRÈS soumission ⇒ `answer()` en '
            'phase `submitted` ⇒ `StateError`.');
    expect(tester.takeException(), isNull);
  });

  testWidgets('AC6 — `byQuality` CORROMPU (clé non-numérique, compte négatif) '
      ': aucun throw', (tester) async {
    useLargeSurface(tester);
    await tester.pumpWidget(
      ExamHost(
        cards: <ZFlashcard>[examCard('Q1')],
        scorer: (qualities, {required int passThreshold}) =>
            const ZStudySessionResult(
              mode: ZReviewMode.whiteExam,
              total: 1,
              correct: 1,
              // Clé illisible + compte négatif : la lecture IGNORE l'entrée.
              byQuality: <String, int>{'pas-un-nombre': 3, '5': -7},
            ),
      ),
    );
    await answerCard(tester, 'Q1');
    await tester.tap(find.byKey(ZListSessionView.submitKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ZListSessionView.confirmKey));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: '🔴 AD-10 : un agrégat corrompu a fait planter l\'écran de fin.');
    expect(find.byType(ZSessionSummaryView), findsOneWidget);
  });

  testWidgets('AC6 — qualité HORS ÉCHELLE : `config.clampQuality` est la voie '
      'UNIQUE (jamais un clamp réécrit, AD-46)', (tester) async {
    useLargeSurface(tester);
    // 🔴 **CE TEST ÉTAIT VACUE, ET SA PROSE MENTAIT** (défaut MESURÉ) : elle
    // annonçait « le port rend une qualité ABERRANTE (99) » alors qu'**AUCUN
    // port n'était branché** — `ExamHost` n'en acceptait même pas. La carte
    // testée était un **Vrai/Faux** ⇒ chemin LOCAL, qui rend `maxQuality` **par
    // construction**. Les deux assertions étaient donc vides de sens
    // (`clampQuality` est **idempotent** ⇒ `x == clamp(x)` est vrai pour tout
    // `x` déjà en échelle). **Preuve** : en supprimant entièrement le
    // `clampQuality` de la prod, le test **passait encore**.
    //
    // 🔴 **ET L'ABERRATION EST NÉGATIVE, PAS `99`** — c'est le cœur du
    // correctif. Un `99` **ne discrimine RIEN** : `zApplyHintCeiling` (appliqué
    // ensuite, AD-36) fait déjà `min(raw, maxQuality)` ⇒ il **plafonne à 5 tout
    // seul**, même si `clampQuality` disparaît. **Vérifié par mutation** : en
    // supprimant le `clampQuality` de la prod, un test à `99` reste **VERT**.
    //
    // La **borne BASSE**, elle, n'est portée que par `clampQuality` :
    //   · avec clamp    → `clampQuality(-7) = 0`, puis `min(0, 5) = **0**` ✅
    //   · sans clamp    → `min(-7, 5) = **-7**` ⇒ qualité HORS ÉCHELLE émise ❌
    // C'est donc `-7` qui rend cette garde **PORTEUSE**.
    await tester.pumpWidget(
      ExamHost(
        cards: <ZFlashcard>[examWrittenCard('Q1')],
        // 🔒 Le spy de **su-3** est RÉUTILISÉ — jamais une doublure réécrite.
        evaluationPort: SpyEvaluationPort(suggestedQuality: -7),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(EK.answerField), 'ma réponse');
    await tester.tap(find.byKey(EK.submitAnswer));
    await tester.pumpAndSettle();

    final host = tester.state<ExamHostState>(find.byType(ExamHost));
    final q = host.submissions[0]!.quality;

    // 🔒 Contre-preuve de NON-VACUITÉ : la valeur assérée n'est pas celle que le
    // port a rendue ⇒ une transformation a RÉELLEMENT eu lieu.
    expect(q, isNot(-7), reason: 'la qualité aberrante a traversé telle quelle');
    expect(
      q,
      inInclusiveRange(config.minQuality, config.maxQuality),
      reason: '🔴 AD-46 : la qualité ABERRANTE (-7) du port a atteint le '
          'moteur SANS passer par `config.clampQuality` — l\'échelle SRS est '
          'violée par une qualité NÉGATIVE.',
    );
    expect(
      q,
      config.clampQuality(-7),
      reason: '🔴 la voie UNIQUE est `config.clampQuality` — jamais un clamp '
          'réécrit par su-7 : le -7 doit ressortir EXACTEMENT comme la config '
          'le décide.',
    );
    expect(tester.takeException(), isNull);
  });
}
