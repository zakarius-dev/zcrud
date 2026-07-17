import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_example/demos/study_session_demo_screen.dart';
import 'package:zcrud_example/support/rebuild_indicator.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart'
    show ZSessionCardSwiper, ZSummaryCelebration;

import 'support/pump_helpers.dart';

/// T6 (AC6/AC8, NFR-SU9) — SM-1 de bout en bout sur le PARCOURS RÉEL.
///
/// 🔴 On exerce le **chemin markdown RÉEL** (leçon su-2 : 9 taps verts sur une
/// fonctionnalité MORTE sous markdown) : la carte courante porte un contenu
/// markdown/formule rendu par `ZFlashcardMarkdownContent` (Quill), pas un contenu
/// par défaut.
void main() {
  // 2 cartes : la courante (index 0) est RÉDIGÉE + markdown (champ de saisie
  // présent) ; une 2ᵉ carte sert de contrôle POSITIF (une avance RÉELLE bouge la
  // pile — preuve que la sonde n'est pas morte).
  StudyAutoStart twoWrittenCards() => const StudyAutoStart(
        mode: ZReviewMode.learn,
        queue: <ZFlashcard>[
          ZFlashcard(
            id: 'md0',
            folderId: 'demoStudyFolder',
            type: ZFlashcardType.openQuestion,
            question: '**Valeur en douane** : donnez la formule '
                r'$V = P + F + A$.',
            answer: 'V = P + F + A',
          ),
          ZFlashcard(
            id: 'md1',
            folderId: 'demoStudyFolder',
            type: ZFlashcardType.openQuestion,
            question: 'Deuxième carte rédigée _markdown_.',
            answer: 'ok',
          ),
        ],
      );

  testWidgets(
      '🔴 taper 100 caractères ne reconstruit QUE le champ courant — pile / '
      'carte inchangées, focus conservé, aucun Form (chemin markdown réel)',
      (tester) async {
    useTallSurface(tester);
    final log = RebuildLog();
    await tester.pumpWidget(
      wrapForTest(
        StudySessionDemoScreen(
          autoStart: twoWrittenCards(),
          rebuildLog: log,
          celebration: ZSummaryCelebration.none,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Aucun `Form` global (AD-2 / objectif produit n°1).
    expect(find.byType(Form), findsNothing);

    // Le champ de saisie de la carte RÉDIGÉE courante (clé du paquet su-3).
    final field = find.descendant(
      of: find.byKey(const ValueKey<String>('zAnswerField')),
      matching: find.byType(EditableText),
    );
    expect(field, findsOneWidget,
        reason: 'la carte courante rédigée expose un champ de saisie');

    // 🔬 Sonde VIVANTE (contrôle avant assertion) : la pile et la carte ont bien
    // été construites au montage — un plancher > 0 prouve que la sonde capte.
    final baseSwiper = log.countOf('swiper');
    final baseCard0 = log.countOf('card_md0');
    expect(baseSwiper, greaterThan(0), reason: 'sonde pile morte ?');
    expect(baseCard0, greaterThan(0), reason: 'sonde carte morte ?');

    // Frappe de 100 caractères, un par un (100 événements de saisie réels).
    final buffer = StringBuffer();
    for (var i = 0; i < 100; i++) {
      buffer.write('a');
      await tester.enterText(field, buffer.toString());
      await tester.pump();
    }

    // (i) SM-1 : ni la pile, ni la carte d'affichage ne se reconstruisent sous
    // la frappe — SEUL le champ (interne à `EditableText`) réagit.
    expect(log.countOf('swiper'), baseSwiper,
        reason: 'la PILE s\'est reconstruite pendant la frappe → setState global '
            '(violation SM-1)');
    expect(log.countOf('card_md0'), baseCard0,
        reason: 'la CARTE d\'affichage s\'est reconstruite pendant la frappe '
            '(violation SM-1)');

    // (ii) Le champ courant a bien traité les 100 frappes, focus + curseur
    // conservés (aucune perte de focus, aucune ré-injection écrasante).
    final editable = tester.widget<EditableText>(field);
    expect(editable.focusNode.hasFocus, isTrue, reason: 'Focus perdu');
    expect(editable.controller.text, 'a' * 100);
    expect(editable.controller.selection.baseOffset, 100,
        reason: 'Curseur non conservé en fin de saisie');

    // (iii) CONTRÔLE POSITIF (R3) : une avance RÉELLE de la pile DOIT, elle,
    // reconstruire la pile — sinon la sonde « inchangée » ci-dessus serait
    // infalsifiable. On tape le bouton d'avance accessible du swiper.
    await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
    await tester.pumpAndSettle();
    expect(log.countOf('swiper'), greaterThan(baseSwiper),
        reason: '🔴 une avance réelle DOIT reconstruire la pile (sonde vivante) — '
            'sinon l\'assertion « inchangée » sous la frappe ne prouverait rien');
  });

  testWidgets(
      '🔬 DISCRIMINANT : 200 frappes ne coûtent pas plus de rebuilds de pile que '
      '100 (le coût de la frappe est INDÉPENDANT du nombre de frappes)',
      (tester) async {
    useTallSurface(tester);

    Future<int> pileRebuildsUnder(int chars) async {
      final log = RebuildLog();
      await tester.pumpWidget(
        wrapForTest(
          StudySessionDemoScreen(
            autoStart: twoWrittenCards(),
            rebuildLog: log,
            celebration: ZSummaryCelebration.none,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final field = find.descendant(
        of: find.byKey(const ValueKey<String>('zAnswerField')),
        matching: find.byType(EditableText),
      );
      final base = log.countOf('swiper');
      final buffer = StringBuffer();
      for (var i = 0; i < chars; i++) {
        buffer.write('a');
        await tester.enterText(field, buffer.toString());
        await tester.pump();
      }
      return log.countOf('swiper') - base;
    }

    final at100 = await pileRebuildsUnder(100);
    final at200 = await pileRebuildsUnder(200);
    expect(at100, 0);
    expect(at200, at100,
        reason: 'le nombre de reconstructions de pile doit être INDÉPENDANT du '
            'nombre de frappes (100 ⇒ $at100, 200 ⇒ $at200)');
  });
}
