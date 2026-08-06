/// **Lot 1 « étude »** — SM-1 (objectif produit n°1, AD-2/AD-15) sur l'écran
/// de session assemblé.
///
/// ## Ce que ce fichier mesure — et pourquoi de cette façon
///
/// L'assemblage de référence pilote tout par `setState` d'écran. Le socle n'en
/// a **aucun** : chaque tranche est un `ValueNotifier`, et la vue n'écoute que
/// la tranche dont elle dépend. Les assertions ci-dessous mesurent la
/// **conséquence observable** de cette discipline :
///
/// 1. taper 100 caractères ne reconstruit **aucune** des trois tranches ;
/// 2. l'`Element` de la pile est **le même objet** avant et après la frappe
///    (aucune remontée d'`Element` : la classe de `RangeError` de su-4 D1 est
///    hors de portée d'une frappe) ;
/// 3. le focus et le curseur survivent aux 100 frappes.
///
/// ## 🔴 Contre-preuve de NON-VACUITÉ — sans elle, rien n'est prouvé
///
/// Une assertion « le compteur n'a pas bougé » est **verte sur une sonde
/// morte** : un probe jamais construit rend `0`, et `0 == 0`. Chaque assertion
/// de stabilité est donc encadrée par :
///
/// * un **plancher** (`> 0` au montage : la sonde capte réellement) ;
/// * un **contrôle positif** (un vrai tour de session DOIT faire monter les
///   mêmes compteurs — sinon la stabilité mesurée ne distinguerait pas
///   « granulaire » de « débranché »).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZFlashcard;
import 'package:zcrud_session/zcrud_session.dart'
    show ZFlashcardAnswerInput, ZSessionCardSwiper;
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZReviewMode;

import '../support/z_study_session_harness.dart';

void main() {
  /// Monte une session SRS instrumentée par [log] sur trois sondes
  /// granulaires : `card_<id>`, `counter`, `grading_<id>`.
  Widget probedHost(
    List<ZFlashcard> cards,
    FakeSessionReviewer reviewer,
    RebuildLog log,
  ) {
    final Map<String, ZFlashcard> byId = <String, ZFlashcard>{
      for (final ZFlashcard c in cards) c.id!: c,
    };
    return wrapForTest(
      ZStudySessionHost(
        mode: ZReviewMode.learn,
        queue: cards,
        reviewer: reviewer.call,
        cardBuilder: (BuildContext context, ZFlashcard card) => RebuildProbe(
          name: 'card_${card.id}',
          log: log,
          child: Text('carte ${card.id}'),
        ),
        counterBuilder: (BuildContext context, ZStudySessionProgress p) =>
            RebuildProbe(
          name: 'counter',
          log: log,
          child: Text('${p.reviewed}/${p.total}'),
        ),
        // 🔴 Le slot reçoit `submit` : c'est la voie qui le relie au runtime.
        // Sans elle, cette session instrumentée noterait dans le VIDE — et le
        // premier jet de ce test l'a démasqué (compteur d'écritures SRS à 0).
        gradingBuilder: (BuildContext context, item, submit) => RebuildProbe(
          name: 'grading_${item.flashcardId}',
          log: log,
          child: ZFlashcardAnswerInput(
            key: ValueKey<String>('probeAnswer_${item.flashcardId}'),
            card: byId[item.flashcardId]!,
            mode: ZReviewMode.learn,
            onSubmitted: submit,
          ),
        ),
      ),
    );
  }

  Finder answerField() => find.descendant(
        of: find.byKey(const ValueKey<String>('zAnswerField')),
        matching: find.byType(EditableText),
      );

  testWidgets(
      '🔴 SM-1 — taper 100 caractères ne reconstruit AUCUNE tranche '
      '(carte, compteurs, saisie), focus et curseur conservés', (tester) async {
    useTallSurface(tester);
    final log = RebuildLog();
    final reviewer = FakeSessionReviewer();
    await tester.pumpWidget(probedHost(writtenCards(2), reviewer, log));
    await tester.pumpAndSettle();

    // Aucun `Form` à l'échelle de l'écran (AD-2 / objectif produit n°1).
    expect(find.byType(Form), findsNothing);

    // 🔬 SONDES VIVANTES — plancher > 0 : chaque sonde a réellement été
    // construite. Sans ce contrôle, « inchangé » serait vert sur une sonde
    // morte (0 == 0).
    final int baseCard = log.countOf('card_c0');
    final int baseCounter = log.countOf('counter');
    final int baseGrading = log.countOf('grading_c0');
    expect(baseCard, greaterThan(0), reason: 'sonde carte morte ?');
    expect(baseCounter, greaterThan(0), reason: 'sonde compteurs morte ?');
    expect(baseGrading, greaterThan(0), reason: 'sonde saisie morte ?');

    // L'`Element` de la pile AVANT la frappe.
    final Element stackBefore = tester.element(find.byType(ZSessionCardSwiper));

    final Finder field = answerField();
    expect(field, findsOneWidget);

    // 100 événements de saisie RÉELS, un caractère à la fois.
    final StringBuffer buffer = StringBuffer();
    for (var i = 0; i < 100; i++) {
      buffer.write('a');
      await tester.enterText(field, buffer.toString());
      await tester.pump();
    }

    // (i) Aucune tranche n'a bougé sous la frappe.
    expect(log.countOf('card_c0'), baseCard,
        reason: '🔴 la CARTE s\'est reconstruite pendant la frappe ⇒ rebuild '
            'non granulaire (violation SM-1)');
    expect(log.countOf('counter'), baseCounter,
        reason: '🔴 les COMPTEURS se sont reconstruits pendant la frappe');
    expect(log.countOf('grading_c0'), baseGrading,
        reason: '🔴 la tranche de SAISIE s\'est reconstruite pendant la frappe '
            '— la saisie vit dans le `State` de `ZFlashcardAnswerInput`, elle '
            'ne doit traverser aucune tranche de l\'écran');

    // (ii) L'`Element` de la pile est LE MÊME OBJET : aucune remontée
    // d'`Element` sous la frappe ⇒ la classe de RangeError de su-4 D1 est hors
    // de portée d'une saisie.
    expect(
      identical(tester.element(find.byType(ZSessionCardSwiper)), stackBefore),
      isTrue,
      reason: '🔴 l\'`Element` de la pile a été RECRÉÉ pendant la frappe',
    );

    // (iii) Focus et curseur conservés.
    final EditableText editable = tester.widget<EditableText>(field);
    expect(editable.focusNode.hasFocus, isTrue, reason: 'focus perdu');
    expect(editable.controller.text, 'a' * 100);
    expect(editable.controller.selection.baseOffset, 100,
        reason: 'curseur non conservé en fin de saisie');
  });

  testWidgets(
      '🔬 CONTRE-PREUVE de NON-VACUITÉ — un vrai tour de session reconstruit '
      'bien les mêmes tranches (les sondes ne sont pas mortes)', (tester) async {
    useTallSurface(tester);
    final log = RebuildLog();
    final reviewer = FakeSessionReviewer();
    await tester.pumpWidget(probedHost(writtenCards(2), reviewer, log));
    await tester.pumpAndSettle();

    final int baseCounter = log.countOf('counter');
    final Element stackBefore = tester.element(find.byType(ZSessionCardSwiper));

    // Un tour RÉEL : « Je ne sais pas » ⇒ lapse ⇒ file du moteur permutée.
    await tester.tap(find.byKey(const ValueKey<String>('zDontKnow')));
    await tester.pumpAndSettle();

    expect(reviewer.writes, 1, reason: 'le tour a bien atteint le seam SRS');
    expect(log.countOf('counter'), greaterThan(baseCounter),
        reason: '🔴 un vrai tour DOIT reconstruire les compteurs — sinon '
            'l\'assertion « inchangés sous la frappe » ne prouverait RIEN');
    // La tranche de saisie de la NOUVELLE carte de devant a été construite.
    expect(log.countOf('grading_c1'), greaterThan(0),
        reason: '🔴 la saisie de la nouvelle carte de devant DOIT être '
            'construite — sinon la sonde de saisie est morte');
    // Et l'`Element` de la pile a, LUI, été remonté (identité de file changée).
    expect(
      identical(tester.element(find.byType(ZSessionCardSwiper)), stackBefore),
      isFalse,
      reason: '🔴 une file réellement changée DOIT remonter l\'`Element` — '
          'sinon l\'assertion « même `Element` sous la frappe » serait vraie '
          'pour de mauvaises raisons (un `Element` qui ne bouge JAMAIS)',
    );
  });


  testWidgets(
      '🔴 ZÉRO `setState` — MESURÉ : le `build()` du host ne se rejoue JAMAIS, '
      'même après plusieurs tours (l\'instance de `ZStudySessionView` est '
      'la MÊME)', (tester) async {
    // 🔬 Pourquoi CETTE mesure et pas « les compteurs ne bougent pas sous la
    // frappe » : la frappe vit dans le `State` de `ZFlashcardAnswerInput` — un
    // hôte à `setState` la traverserait sans rebuild lui non plus. La frappe ne
    // DISCRIMINE donc pas les deux architectures.
    //
    // Ce qui les discrimine, c'est la NOTATION : un hôte à `setState` rejoue
    // son `build()` à chaque tour (la démo le fait 5 fois — `:196`, `:270`,
    // `:333`, `:355`, `:386`). Ici, `build()` monte l'arbre UNE fois et ne le
    // rejoue jamais : chaque tranche se met à jour depuis son propre
    // `ValueListenableBuilder`. L'identité de l'instance de vue le prouve.
    useTallSurface(tester);
    final log = RebuildLog();
    final reviewer = FakeSessionReviewer();
    await tester.pumpWidget(probedHost(writtenCards(3), reviewer, log));
    await tester.pumpAndSettle();

    final ZStudySessionView viewAtMount =
        tester.widget<ZStudySessionView>(find.byType(ZStudySessionView));

    for (var turn = 0; turn < 3; turn++) {
      await tester.tap(find.byKey(const ValueKey<String>('zDontKnow')));
      await tester.pumpAndSettle();
    }
    expect(reviewer.writes, 3, reason: 'les 3 tours ont bien eu lieu');

    expect(
      identical(
        tester.widget<ZStudySessionView>(find.byType(ZStudySessionView)),
        viewAtMount,
      ),
      isTrue,
      reason: '🔴 le `build()` du host a été REJOUÉ : une nouvelle instance de '
          '`ZStudySessionView` a été construite. C\'est la signature d\'un '
          '`setState` d\'écran — et donc du rebuild global qui recrée '
          'l\'`Element` du swiper (chemin du RangeError su-4 D1).',
    );
  });

  testWidgets(
      '🔬 DISCRIMINANT — 200 frappes ne coûtent pas plus de reconstructions '
      'que 100 (le coût de la frappe est INDÉPENDANT du nombre de frappes)',
      (tester) async {
    useTallSurface(tester);

    Future<int> cardRebuildsUnder(int chars) async {
      final log = RebuildLog();
      await tester.pumpWidget(
        probedHost(writtenCards(2), FakeSessionReviewer(), log),
      );
      await tester.pumpAndSettle();
      final int base = log.countOf('card_c0');
      final Finder field = answerField();
      final StringBuffer buffer = StringBuffer();
      for (var i = 0; i < chars; i++) {
        buffer.write('a');
        await tester.enterText(field, buffer.toString());
        await tester.pump();
      }
      return log.countOf('card_c0') - base;
    }

    final int at100 = await cardRebuildsUnder(100);
    final int at200 = await cardRebuildsUnder(200);
    expect(at100, 0);
    expect(at200, at100,
        reason: 'le nombre de reconstructions doit être INDÉPENDANT du nombre '
            'de frappes (100 ⇒ $at100, 200 ⇒ $at200)');
  });
}
