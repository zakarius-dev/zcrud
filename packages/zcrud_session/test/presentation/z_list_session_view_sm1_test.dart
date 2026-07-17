/// SU-7 / AC8 — SM-1 : taper dans UNE question ne reconstruit **que** cette
/// question (**objectif produit n°1** — le bug historique que zcrud existe pour
/// corriger).
///
/// Patron **emprunté** à `z_flashcard_answer_input_sm1_test.dart` (su-3) : la
/// sonde est **DANS le sous-arbre visé** (le `contentBuilder` de chaque carte).
/// ⚠️ **Leçon D5 de su-2** : une sonde placée sur un *sibling* est
/// **structurellement aveugle** — elle ne bougerait pas même si tout le sous-arbre
/// se reconstruisait 100 fois.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';

import 'z_exam_harness.dart';

/// Sonde de comptage, par carte.
class _CountingContent extends StatelessWidget {
  const _CountingContent({required this.content, required this.onBuild});

  final String content;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild();
    return Text(content);
  }
}

/// Carte à réponse **RÉDIGÉE** — le seul type qui porte un `TextField` (donc le
/// seul où « taper » a un sens).
ZFlashcard writtenExamCard(String tag) => ZFlashcard(
  id: tag,
  folderId: 'f',
  question: tag,
  type: ZFlashcardType.openQuestion,
  answer: 'attendu',
);

void main() {
  const fieldKey = ValueKey<String>('zAnswerField');

  testWidgets(
    '🔴 AC8/SM-1 — 100 caractères dans la carte 1 : les builds des cartes '
    '2..N restent INCHANGÉS, et le focus n\'est jamais perdu',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final builds = <String, int>{'Q1': 0, 'Q2': 0, 'Q3': 0};
      await tester.pumpWidget(
        ExamHost(
          cards: <ZFlashcard>[
            writtenExamCard('Q1'),
            writtenExamCard('Q2'),
            writtenExamCard('Q3'),
          ],
          contentBuilder: (context, content) => _CountingContent(
            content: content,
            onBuild: () => builds[content] = (builds[content] ?? 0) + 1,
          ),
        ),
      );

      // Contre-preuve : les 3 cartes ont RÉELLEMENT été construites — sans quoi
      // « leurs builds n'augmentent pas » serait vrai par vacuité.
      expect(builds.values.every((v) => v > 0), isTrue,
          reason: 'les 3 cartes doivent être montées');

      final field = find.descendant(
        of: find.ancestor(
          of: find.text('Q1'),
          matching: find.byType(ZFlashcardAnswerInput),
        ),
        matching: find.byKey(fieldKey),
      );
      await tester.tap(field);
      await tester.pump();

      final others = <String, int>{'Q2': builds['Q2']!, 'Q3': builds['Q3']!};
      final controller = tester.widget<TextFormField>(field).controller;

      // Frappe caractère par caractère : le chemin RÉEL d'un utilisateur (un
      // seul `enterText` de 100 chars ne prouverait rien — c'est UNE mutation).
      final buffer = StringBuffer();
      for (var i = 0; i < 100; i++) {
        buffer.write('a');
        await tester.enterText(field, buffer.toString());
        await tester.pump();
      }

      expect(
        builds['Q2'],
        others['Q2'],
        reason: '🔴 SM-1 : taper dans la carte 1 a reconstruit la carte 2. '
            'L\'état de saisie a dû remonter dans un `setState` de l\'hôte ou '
            'de `ZListSessionView` — c\'est EXACTEMENT le bug historique '
            '(jank, perte de focus) que zcrud existe pour corriger.',
      );
      expect(builds['Q3'], others['Q3']);

      // 🔒 Le focus SURVIT (le symptôme visible du bug historique). On lit le
      // `FocusNode` sur l'`EditableText` réellement monté — `TextFormField`
      // n'expose pas le sien.
      final editable = tester.widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      );
      expect(editable.focusNode.hasFocus, isTrue,
          reason: '🔴 SM-1 : la frappe a fait perdre le focus.');

      // 🔒 Le `TextEditingController` n'est JAMAIS recréé (identité stable).
      expect(
        identical(tester.widget<TextFormField>(field).controller, controller),
        isTrue,
        reason: '🔴 SM-1 : le `TextEditingController` a été recréé pendant la '
            'frappe ⇒ curseur/sélection écrasés à chaque caractère.',
      );
      expect(controller!.text.length, 100, reason: 'la frappe a bien eu lieu');

      // 🔬 **CONTRE-PREUVE R12 — la sonde SAIT bouger.**
      //
      // Les `expect` ci-dessus sont des assertions d'**IMMOBILITÉ** : un
      // compteur **mort** (jamais incrémenté, ou branché sur un sous-arbre qui
      // ne se reconstruit jamais) les passerait TOUS au vert, sur du code
      // arbitrairement mauvais. C'est l'exacte parenté de « l'espion jamais
      // branché » de su-4.
      //
      // On provoque donc un rebuild RÉEL de la liste (soumettre une réponse
      // fait notifier le moteur ⇒ l'hôte reconstruit) et on exige que le
      // compteur de Q2 **bouge**. S'il ne bouge pas ici, aucune des assertions
      // d'immobilité ci-dessus ne prouve quoi que ce soit.
      await tester.tap(
        find.descendant(
          of: find.ancestor(
            of: find.text('Q2'),
            matching: find.byType(ZFlashcardAnswerInput),
          ),
          matching: find.byKey(const ValueKey<String>('zSubmit')),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        builds['Q2']!,
        greaterThan(others['Q2']!),
        reason: '🔬 la sonde de comptage est MORTE : elle ne bouge même pas '
            'quand la liste se reconstruit réellement ⇒ les assertions '
            'd\'immobilité ci-dessus étaient vertes pour de mauvaises raisons.',
      );
    },
  );
}
