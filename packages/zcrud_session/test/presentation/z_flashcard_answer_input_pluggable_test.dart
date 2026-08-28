/// Gardes du mode contrôlé et des slots de `ZFlashcardAnswerInput`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';

import 'z_answer_input_harness.dart';

const _qcmTypeTree = <String>[
  'ZFlashcardAnswerInput',
  'Column',
  'IgnorePointer',
  'ZFlashcardDefaultContent',
  'Text',
  'RichText',
  'SizedBox',
  '_ChoicesInput',
  'ValueListenableBuilder<_Correction?>',
  'ValueListenableBuilder<Set<int>>',
  'Column',
  '_ChoiceRow',
  'MergeSemantics',
  'Semantics',
  'ConstrainedBox',
  'InkWell',
  '_InkResponseStateWidget',
  '_ParentInkResponseProvider',
  'Actions',
  '_ActionsScope',
  'Focus',
  '_FocusInheritedScope',
  'Semantics',
  'MouseRegion',
  'Builder',
  'DefaultSelectionStyle',
  'Semantics',
  'GestureDetector',
  'RawGestureDetector',
  'Listener',
  'Padding',
  'Row',
  'Icon',
  'Semantics',
  'ExcludeSemantics',
  'SizedBox',
  'Center',
  'RichText',
  'SizedBox',
  'Expanded',
  'Text',
  'RichText',
  '_ChoiceRow',
  'MergeSemantics',
  'Semantics',
  'ConstrainedBox',
  'InkWell',
  '_InkResponseStateWidget',
  '_ParentInkResponseProvider',
  'Actions',
  '_ActionsScope',
  'Focus',
  '_FocusInheritedScope',
  'Semantics',
  'MouseRegion',
  'Builder',
  'DefaultSelectionStyle',
  'Semantics',
  'GestureDetector',
  'RawGestureDetector',
  'Listener',
  'Padding',
  'Row',
  'Icon',
  'Semantics',
  'ExcludeSemantics',
  'SizedBox',
  'Center',
  'RichText',
  'SizedBox',
  'Expanded',
  'Text',
  'RichText',
  '_ChoiceRow',
  'MergeSemantics',
  'Semantics',
  'ConstrainedBox',
  'InkWell',
  '_InkResponseStateWidget',
  '_ParentInkResponseProvider',
  'Actions',
  '_ActionsScope',
  'Focus',
  '_FocusInheritedScope',
  'Semantics',
  'MouseRegion',
  'Builder',
  'DefaultSelectionStyle',
  'Semantics',
  'GestureDetector',
  'RawGestureDetector',
  'Listener',
  'Padding',
  'Row',
  'Icon',
  'Semantics',
  'ExcludeSemantics',
  'SizedBox',
  'Center',
  'RichText',
  'SizedBox',
  'Expanded',
  'Text',
  'RichText',
  'SizedBox',
  '_SubmitButton',
  '_ControlButton',
  'Semantics',
  'ConstrainedBox',
  'Material',
  '_MaterialInterior',
  'PhysicalShape',
  '_ShapeBorderPaint',
  'CustomPaint',
  'NotificationListener<LayoutChangedNotification>',
  '_InkFeatures',
  'AnimatedDefaultTextStyle',
  'DefaultTextStyle',
  'InkWell',
  '_InkResponseStateWidget',
  '_ParentInkResponseProvider',
  'Actions',
  '_ActionsScope',
  'Focus',
  '_FocusInheritedScope',
  'Semantics',
  'MouseRegion',
  'Builder',
  'DefaultSelectionStyle',
  'Semantics',
  'GestureDetector',
  'RawGestureDetector',
  'Listener',
  'Padding',
  'Row',
  'Flexible',
  'Text',
  'RichText',
  'SizedBox',
  '_HintSection',
  'Column',
  'ValueListenableBuilder<List<String>>',
  'Column',
  'ValueListenableBuilder<_Correction?>',
  'SizedBox',
  'ValueListenableBuilder<String?>',
  'SizedBox',
  'SizedBox',
  '_DontKnowButton',
  'ValueListenableBuilder<_Correction?>',
  '_ControlButton',
  'Semantics',
  'ConstrainedBox',
  'Material',
  '_MaterialInterior',
  'PhysicalShape',
  '_ShapeBorderPaint',
  'CustomPaint',
  'NotificationListener<LayoutChangedNotification>',
  '_InkFeatures',
  'AnimatedDefaultTextStyle',
  'DefaultTextStyle',
  'InkWell',
  '_InkResponseStateWidget',
  '_ParentInkResponseProvider',
  'Actions',
  '_ActionsScope',
  'Focus',
  '_FocusInheritedScope',
  'Semantics',
  'MouseRegion',
  'Builder',
  'DefaultSelectionStyle',
  'Semantics',
  'GestureDetector',
  'RawGestureDetector',
  'Listener',
  'Padding',
  'Row',
  'Flexible',
  'Text',
  'RichText',
  'SizedBox',
  '_CorrectionSection',
  'ValueListenableBuilder<_Correction?>',
  'SizedBox',
];

const _trueFalseTypeTree = <String>[
  'ZFlashcardAnswerInput',
  'Column',
  'IgnorePointer',
  'ZFlashcardDefaultContent',
  'Text',
  'RichText',
  'SizedBox',
  '_TrueFalseInput',
  'ValueListenableBuilder<_Correction?>',
  'Row',
  '_ControlButton',
  'Semantics',
  'ConstrainedBox',
  'Material',
  '_MaterialInterior',
  'PhysicalShape',
  '_ShapeBorderPaint',
  'CustomPaint',
  'NotificationListener<LayoutChangedNotification>',
  '_InkFeatures',
  'AnimatedDefaultTextStyle',
  'DefaultTextStyle',
  'InkWell',
  '_InkResponseStateWidget',
  '_ParentInkResponseProvider',
  'Actions',
  '_ActionsScope',
  'Focus',
  '_FocusInheritedScope',
  'Semantics',
  'MouseRegion',
  'Builder',
  'DefaultSelectionStyle',
  'Semantics',
  'GestureDetector',
  'RawGestureDetector',
  'Listener',
  'Padding',
  'Row',
  'Flexible',
  'Text',
  'RichText',
  'SizedBox',
  '_ControlButton',
  'Semantics',
  'ConstrainedBox',
  'Material',
  '_MaterialInterior',
  'PhysicalShape',
  '_ShapeBorderPaint',
  'CustomPaint',
  'NotificationListener<LayoutChangedNotification>',
  '_InkFeatures',
  'AnimatedDefaultTextStyle',
  'DefaultTextStyle',
  'InkWell',
  '_InkResponseStateWidget',
  '_ParentInkResponseProvider',
  'Actions',
  '_ActionsScope',
  'Focus',
  '_FocusInheritedScope',
  'Semantics',
  'MouseRegion',
  'Builder',
  'DefaultSelectionStyle',
  'Semantics',
  'GestureDetector',
  'RawGestureDetector',
  'Listener',
  'Padding',
  'Row',
  'Flexible',
  'Text',
  'RichText',
  'SizedBox',
  '_HintSection',
  'Column',
  'ValueListenableBuilder<List<String>>',
  'Column',
  'ValueListenableBuilder<_Correction?>',
  'SizedBox',
  'ValueListenableBuilder<String?>',
  'SizedBox',
  'SizedBox',
  '_DontKnowButton',
  'ValueListenableBuilder<_Correction?>',
  '_ControlButton',
  'Semantics',
  'ConstrainedBox',
  'Material',
  '_MaterialInterior',
  'PhysicalShape',
  '_ShapeBorderPaint',
  'CustomPaint',
  'NotificationListener<LayoutChangedNotification>',
  '_InkFeatures',
  'AnimatedDefaultTextStyle',
  'DefaultTextStyle',
  'InkWell',
  '_InkResponseStateWidget',
  '_ParentInkResponseProvider',
  'Actions',
  '_ActionsScope',
  'Focus',
  '_FocusInheritedScope',
  'Semantics',
  'MouseRegion',
  'Builder',
  'DefaultSelectionStyle',
  'Semantics',
  'GestureDetector',
  'RawGestureDetector',
  'Listener',
  'Padding',
  'Row',
  'Flexible',
  'Text',
  'RichText',
  'SizedBox',
  '_CorrectionSection',
  'ValueListenableBuilder<_Correction?>',
  'SizedBox',
];

const _writtenTypeTree = <String>[
  'ZFlashcardAnswerInput',
  'Column',
  'IgnorePointer',
  'ZFlashcardDefaultContent',
  'Text',
  'RichText',
  'SizedBox',
  '_WrittenInput',
  'Column',
  'Semantics',
  'ValueListenableBuilder<_Correction?>',
  'TextFormField',
  'Semantics',
  'UnmanagedRestorationScope',
  'TextField',
  'MouseRegion',
  'TextFieldTapRegion',
  'IgnorePointer',
  'AnimatedBuilder',
  'Semantics',
  'TextSelectionGestureDetector',
  'RawGestureDetector',
  'Listener',
  'AnimatedBuilder',
  'InputDecorator',
  'Semantics',
  '_Decorator',
  'RepaintBoundary',
  'UnmanagedRestorationScope',
  'EditableText',
  '_CompositionCallback',
  'Actions',
  '_ActionsScope',
  'Builder',
  'TextFieldTapRegion',
  'MouseRegion',
  'UndoHistory<TextEditingValue>',
  'Actions',
  '_ActionsScope',
  'Focus',
  '_FocusInheritedScope',
  'NotificationListener<ScrollNotification>',
  'Scrollable',
  '_ScrollableScope',
  'Listener',
  'RawGestureDetector',
  'Listener',
  'Semantics',
  'IgnorePointer',
  'CompositedTransformTarget',
  'Semantics',
  '_ScribbleFocusable',
  'SizeChangedLayoutNotifier',
  '_Editable',
  '_HelperError',
  'SizedBox',
  '_BorderContainer',
  'CustomPaint',
  'SizedBox',
  'ValueListenableBuilder<_Correction?>',
  'Row',
  '_SubmitButton',
  '_ControlButton',
  'Semantics',
  'ConstrainedBox',
  'Material',
  '_MaterialInterior',
  'PhysicalShape',
  '_ShapeBorderPaint',
  'CustomPaint',
  'NotificationListener<LayoutChangedNotification>',
  '_InkFeatures',
  'AnimatedDefaultTextStyle',
  'DefaultTextStyle',
  'InkWell',
  '_InkResponseStateWidget',
  '_ParentInkResponseProvider',
  'Actions',
  '_ActionsScope',
  'Focus',
  '_FocusInheritedScope',
  'Semantics',
  'MouseRegion',
  'Builder',
  'DefaultSelectionStyle',
  'Semantics',
  'GestureDetector',
  'RawGestureDetector',
  'Listener',
  'Padding',
  'Row',
  'Flexible',
  'Text',
  'RichText',
  'SizedBox',
  '_HintSection',
  'Column',
  'ValueListenableBuilder<List<String>>',
  'Column',
  'ValueListenableBuilder<_Correction?>',
  'SizedBox',
  'ValueListenableBuilder<String?>',
  'SizedBox',
  'SizedBox',
  '_DontKnowButton',
  'ValueListenableBuilder<_Correction?>',
  '_ControlButton',
  'Semantics',
  'ConstrainedBox',
  'Material',
  '_MaterialInterior',
  'PhysicalShape',
  '_ShapeBorderPaint',
  'CustomPaint',
  'NotificationListener<LayoutChangedNotification>',
  '_InkFeatures',
  'AnimatedDefaultTextStyle',
  'DefaultTextStyle',
  'InkWell',
  '_InkResponseStateWidget',
  '_ParentInkResponseProvider',
  'Actions',
  '_ActionsScope',
  'Focus',
  '_FocusInheritedScope',
  'Semantics',
  'MouseRegion',
  'Builder',
  'DefaultSelectionStyle',
  'Semantics',
  'GestureDetector',
  'RawGestureDetector',
  'Listener',
  'Padding',
  'Row',
  'Flexible',
  'Text',
  'RichText',
  'SizedBox',
  '_CorrectionSection',
  'ValueListenableBuilder<_Correction?>',
  'SizedBox',
];

List<String> _widgetTypeTree(WidgetTester tester) {
  final root = tester.element(find.byType(ZFlashcardAnswerInput));
  final types = <String>[];

  void visit(Element element) {
    types.add(element.widget.runtimeType.toString());
    element.visitChildren(visit);
  }

  visit(root);
  return types;
}

class _ChoiceContentProbe extends StatelessWidget {
  const _ChoiceContentProbe({required this.choice});

  final ZChoice choice;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: ValueKey<String>('customChoice_${choice.content}'),
    width: 24,
    height: 24,
  );
}

void main() {
  group('inertie absolue sans les nouveaux paramètres', () {
    testWidgets('QCM — arbre historique strict', (tester) async {
      await tester.pumpWidget(
        host(ZFlashcardAnswerInput(card: qcmSingle(), mode: ZReviewMode.learn)),
      );

      expect(_widgetTypeTree(tester), _qcmTypeTree);
    });

    testWidgets('Vrai/Faux — arbre historique strict', (tester) async {
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(card: trueFalseCard(), mode: ZReviewMode.learn),
        ),
      );

      expect(_widgetTypeTree(tester), _trueFalseTypeTree);
    });

    testWidgets('réponse ouverte — arbre historique strict', (tester) async {
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(card: writtenCard(), mode: ZReviewMode.learn),
        ),
      );

      expect(_widgetTypeTree(tester), _writtenTypeTree);
    });
  });

  testWidgets('choiceContentBuilder remplace exactement le Text historique', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        ZFlashcardAnswerInput(
          card: qcmSingle(),
          mode: ZReviewMode.learn,
          choiceContentBuilder: (context, choice) =>
              _ChoiceContentProbe(choice: choice),
        ),
      ),
    );

    final firstRow = find.byKey(K.choice(0));
    final expanded = tester.widget<Expanded>(
      find.descendant(of: firstRow, matching: find.byType(Expanded)),
    );

    expect(expanded.child, isA<_ChoiceContentProbe>());
    expect(
      find.byKey(const ValueKey<String>('customChoice_Accra')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: firstRow, matching: find.text('Accra')),
      findsNothing,
      reason: 'le Text(choice.content) historique ne doit pas survivre',
    );
  });

  group('onAnswerChanged', () {
    testWidgets('émet la frappe SANS reconstruire les frères (SM-1)', (
      tester,
    ) async {
      // Le slot de contenu est un FRÈRE de la saisie, construit par le
      // `build()` de la surface : le compteur mesure donc les rebuilds de la
      // surface elle-même, pas ceux de l'`EditableText` (plancher du SDK).
      var contentBuilds = 0;
      final drafts = <ZFlashcardAnswerDraft>[];

      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: writtenCard(),
            mode: ZReviewMode.learn,
            contentBuilder: (context, question) {
              contentBuilds++;
              return Text(question, textAlign: TextAlign.start);
            },
            onAnswerChanged: drafts.add,
          ),
        ),
      );

      final buildsAtRest = contentBuilds;
      await tester.enterText(find.byKey(K.answerField), 'transit douanier');
      await tester.pump();

      expect(
        drafts.map((d) => d.text).toList(),
        <String>['transit douanier'],
        reason: 'une frappe, une notification, la valeur courante',
      );
      expect(
        contentBuilds,
        buildsAtRest,
        reason: 'observer la réponse ne doit reconstruire aucun frère',
      );
    });

    testWidgets('émet les positions cochées d\'un QCM', (tester) async {
      final drafts = <ZFlashcardAnswerDraft>[];

      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: qcmSingle(),
            mode: ZReviewMode.learn,
            onAnswerChanged: drafts.add,
          ),
        ),
      );

      await tester.tap(find.byKey(K.choice(2)));
      await tester.pump();
      await tester.tap(find.byKey(K.choice(0)));
      await tester.pump();

      expect(drafts, <ZFlashcardAnswerDraft>[
        const ZFlashcardAnswerDraft(selectedChoiceIndexes: <int>{2}),
        const ZFlashcardAnswerDraft(selectedChoiceIndexes: <int>{0}),
      ]);
    });

    testWidgets('émet la réponse V/F AVANT la soumission qu\'elle déclenche', (
      tester,
    ) async {
      final journal = <String>[];

      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: trueFalseCard(),
            mode: ZReviewMode.learn,
            onAnswerChanged: (draft) =>
                journal.add('draft:${draft.answeredTrue}'),
            onSubmitted: (_) => journal.add('submitted'),
          ),
        ),
      );

      await tester.tap(find.byKey(K.answerFalse));
      await tester.pump();

      expect(journal, <String>['draft:false', 'submitted']);
    });

    testWidgets('reste MUET au montage et au changement de carte', (
      tester,
    ) async {
      final drafts = <ZFlashcardAnswerDraft>[];

      Widget surface(ZFlashcard card) => host(
        ZFlashcardAnswerInput(
          card: card,
          mode: ZReviewMode.learn,
          initialAnswer: 'brouillon',
          onAnswerChanged: drafts.add,
        ),
      );

      await tester.pumpWidget(surface(writtenCard()));
      expect(drafts, isEmpty, reason: 'la valeur initiale n\'est pas une saisie');

      await tester.pumpWidget(surface(writtenCard(hint: 'autre carte')));
      await tester.pump();

      expect(
        drafts,
        isEmpty,
        reason: 'la remise à zéro d\'une nouvelle carte n\'est pas une saisie',
      );
    });
  });

  testWidgets('initialAnswer préremplit au montage et n\'est JAMAIS réinjecté', (
    tester,
  ) async {
    Widget surface(String? initial) => host(
      ZFlashcardAnswerInput(
        card: writtenCard(),
        mode: ZReviewMode.learn,
        initialAnswer: initial,
      ),
    );

    await tester.pumpWidget(surface('brouillon'));
    expect(find.text('brouillon'), findsOneWidget);

    // L'utilisateur reprend la main, puis l'hôte se reconstruit avec une AUTRE
    // valeur initiale : la réinjecter écraserait la saisie en cours.
    await tester.enterText(find.byKey(K.answerField), 'ma réponse');
    await tester.pumpWidget(surface('valeur repoussée'));
    await tester.pump();

    expect(find.text('ma réponse'), findsOneWidget);
    expect(find.text('valeur repoussée'), findsNothing);
  });

  group('isSubmitted imposé', () {
    testWidgets('true ⇒ QCM inerte (aucune coche, aucun bouton)', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: qcmSingle(),
            mode: ZReviewMode.learn,
            isSubmitted: true,
          ),
        ),
      );

      await tester.tap(find.byKey(K.choice(1)), warnIfMissed: false);
      await tester.pump();

      expect(
        tester.widget<Semantics>(
          find
              .descendant(
                of: find.byKey(K.choice(1)),
                matching: find.byType(Semantics),
              )
              .first,
        ).properties.checked,
        isFalse,
        reason: 'un tap sur une saisie imposée close ne coche rien',
      );
      expect(find.byKey(K.submit), findsNothing);
      expect(find.byKey(K.dontKnow), findsNothing);
    });

    testWidgets('true ⇒ Vrai/Faux inerte, sans correction peinte', (
      tester,
    ) async {
      final submissions = <ZFlashcardSubmission>[];

      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: trueFalseCard(),
            mode: ZReviewMode.learn,
            isSubmitted: true,
            onSubmitted: submissions.add,
          ),
        ),
      );

      await tester.tap(find.byKey(K.answerTrue), warnIfMissed: false);
      await tester.pump();

      expect(submissions, isEmpty);
      expect(
        find.byKey(K.feedback),
        findsNothing,
        reason: 'imposer la clôture ne fabrique aucune correction',
      );
    });

    testWidgets('true ⇒ champ rédigé en lecture seule, contrôles retirés', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: writtenCard(hint: 'un indice'),
            mode: ZReviewMode.learn,
            isSubmitted: true,
          ),
        ),
      );

      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(K.answerField),
                matching: find.byType(TextField),
              ),
            )
            .readOnly,
        isTrue,
      );
      expect(find.byKey(K.submit), findsNothing);
      expect(find.byKey(K.dontKnow), findsNothing);
      expect(find.byKey(K.hintButton), findsNothing);
    });

    testWidgets('false ne rouvre PAS une soumission déjà consommée', (
      tester,
    ) async {
      final submissions = <ZFlashcardSubmission>[];

      Widget surface({bool? submitted}) => host(
        ZFlashcardAnswerInput(
          card: trueFalseCard(),
          mode: ZReviewMode.learn,
          isSubmitted: submitted,
          onSubmitted: submissions.add,
        ),
      );

      await tester.pumpWidget(surface());
      await tester.tap(find.byKey(K.answerTrue));
      await tester.pump();
      expect(submissions, hasLength(1));

      // L'hôte rouvre les affordances : le verrou one-shot reste seul maître
      // de ce qui part au barème.
      await tester.pumpWidget(surface(submitted: false));
      await tester.pump();
      await tester.tap(find.byKey(K.answerFalse), warnIfMissed: false);
      await tester.pump();

      expect(
        submissions,
        hasLength(1),
        reason: 'une carte, au plus une soumission',
      );
    });
  });

  testWidgets(
    'writtenAnswerFieldBuilder remplace le champ et reçoit le controller de '
    'la surface',
    (tester) async {
      const customKey = ValueKey<String>('customWrittenField');
      final port = SpyEvaluationPort();
      var receivedSubmitted = true;

      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: writtenCard(),
            mode: ZReviewMode.learn,
            evaluationPort: port,
            writtenAnswerFieldBuilder:
                (
                  context, {
                  required controller,
                  required focusNode,
                  required validator,
                  required isSubmitted,
                }) {
                  receivedSubmitted = isSubmitted;
                  return TextField(
                    key: customKey,
                    controller: controller,
                    focusNode: focusNode,
                    readOnly: isSubmitted,
                  );
                },
          ),
        ),
      );

      expect(
        find.byKey(K.answerField),
        findsNothing,
        reason: 'le TextFormField historique ne doit pas survivre',
      );
      expect(find.byKey(customKey), findsOneWidget);
      expect(receivedSubmitted, isFalse);

      // Le controller reçu doit être CELUI que lit la soumission : sinon le
      // texte saisi dans le champ injecté ne partirait jamais au barème.
      await tester.enterText(find.byKey(customKey), 'le transit suspend les droits');
      await tester.tap(find.byKey(K.submit));
      await tester.pumpAndSettle();

      expect(port.callCount, 1);
      expect(port.request!.userAnswer, 'le transit suspend les droits');
    },
  );
}
