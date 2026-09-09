// Formulaire de carte du multi-éditeur : ce que le DÉFAUT sait éditer, le
// créneau de formulaire COMPLET (`cardFormBuilder`), la validation bloquante au
// commit, et les libellés de la garde de sortie.
//
// Quatre propriétés, indépendantes :
//
//  1. LE DÉFAUT ÉDITE LA CARTE ENTIÈRE — un QCM créé dans le multi-éditeur porte
//     ses choix et sa bonne réponse ; un vrai/faux porte sa valeur ; les balises
//     sont éditables. Avant ce lot, `choices`/`isTrue`/`tagIds` n'étaient jamais
//     écrits : une carte QCM sortait du multi-éditeur SANS choix, invalide pour
//     la révision.
//
//  2. LA CARTE INVALIDE BLOQUE LE COMMIT — l'espion de commit est prouvé captant
//     (écriture témoin) AVANT toute assertion « 0 écriture ».
//
//  3. `cardFormBuilder` EST UN CRÉNEAU — fourni, il est RENDU (le formulaire du
//     socle disparaît, aucun champ n'est rendu deux fois) et ses écritures
//     atteignent le brouillon PUIS le commit.
//
//  4. LES LIBELLÉS DE SORTIE SONT SURCHARGEABLES — posés, le dialogue les
//     affiche ; absents, le repli du socle (`ZDiscardChangesGuard`) s'applique
//     inchangé.
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart'
    show EditionFieldType, Unit, ZFieldSpec, ZResult;
import 'package:zcrud_core/zcrud_core.dart' show ZTagsFieldWidget;
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart' show ZDiscardChangesGuard;

class _CommitSpy {
  int writes = 0;
  final List<List<ZFlashcard>> payloads = <List<ZFlashcard>>[];
  Future<ZResult<Unit>> call(List<ZFlashcard> cards) async {
    writes++;
    payloads.add(List<ZFlashcard>.of(cards));
    return right(unit);
  }
}

ZMultiFlashcardEditorLabels _labels({
  String? discardTitle,
  String? discardMessage,
  String? discardConfirmLabel,
  String? discardCancelLabel,
}) =>
    ZMultiFlashcardEditorLabels(
      addCardLabel: 'Ajouter',
      deleteSelectedLabel: 'Supprimer',
      commitLabel: 'Enregistrer',
      applyCommonLabel: 'Appliquer',
      selectAllLabel: 'Tout sélectionner',
      emptyState: 'Aucune carte',
      detailPlaceholder: 'Sélectionner une carte',
      backToListLabel: 'Retour',
      questionLabel: 'Question',
      answerLabel: 'Réponse',
      explanationLabel: 'Explication',
      hintLabel: 'Indice',
      typeLabel: 'Type',
      commonFieldPickerLabel: 'Champ',
      commonValueLabel: 'Valeur',
      previewTitle: 'Aperçu',
      commitSucceeded: 'Enregistré',
      commitFailed: 'Échec',
      selectCardSemanticLabel: (i) => 'Sélectionner la carte $i',
      countLabelBuilder: (n) => '$n sélectionnée(s)',
      applyReportBuilder: (r) => 'Appliqué ${r.succeededCount}',
      discardTitle: discardTitle,
      discardMessage: discardMessage,
      discardConfirmLabel: discardConfirmLabel,
      discardCancelLabel: discardCancelLabel,
    );

Widget _harness(Widget child) => MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 1200, height: 2000, child: child),
      ),
    );

/// Surface d'affichage assez grande pour que TOUS les contrôles du formulaire
/// soient réellement à l'écran : un `tap` sur une cible hors viewport
/// n'atteindrait pas son gestionnaire et rendrait la garde trompeuse.
void _bigScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Ouvre le volet détail sur la carte dont le résumé porte [question].
Future<void> _focusCard(WidgetTester tester, String question) async {
  await tester.tap(find.text(question).first);
  await tester.pump();
}

Future<void> _commit(WidgetTester tester) async {
  await tester.tap(find.byKey(ZMultiFlashcardEditor.commitButtonKey));
  await tester.pumpAndSettle();
}

void main() {
  group('🔴 le DÉFAUT édite la carte ENTIÈRE (choix / vrai-faux / balises)', () {
    testWidgets(
      '🔴 QCM : deux choix saisis + une bonne réponse ⇒ le commit les porte',
      (tester) async {
      _bigScreen(tester);
        final spy = _CommitSpy();
        await tester.pumpWidget(_harness(ZMultiFlashcardEditor(
          initialCards: const <ZFlashcard>[
            ZFlashcard(
              id: 'a',
              question: 'Q0',
              type: ZFlashcardType.multipleChoice,
            ),
          ],
          onCommit: spy.call,
          labels: _labels(),
        )));
        await _focusCard(tester, 'Q0');

        // L'éditeur QCM du socle est MONTÉ (jamais un second éditeur écrit ici).
        expect(find.byType(ZChoicesFieldWidget), findsOneWidget,
            reason: '🔴 une carte QCM DOIT exposer son éditeur de choix');

        // Deux choix, le premier correct.
        await tester.tap(find.byKey(const Key('z-flashcard-choice-add')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('z-flashcard-choice-add')));
        await tester.pump();
        await tester.enterText(
            find.byKey(const ValueKey<String>('z-flashcard-choice-content-0')),
            'Paris');
        await tester.pump();
        await tester.enterText(
            find.byKey(const ValueKey<String>('z-flashcard-choice-content-1')),
            'Lyon');
        await tester.pump();
        await tester.tap(
            find.byKey(const ValueKey<String>('z-flashcard-choice-correct-0')));
        await tester.pump();

        await _commit(tester);

        final committed = spy.payloads.last.single;
        expect(committed.choices, isNotNull,
            reason: '🔴 un QCM créé dans le multi-éditeur DOIT porter ses choix');
        expect(committed.choices!.map((c) => c.content),
            equals(<String>['Paris', 'Lyon']));
        expect(committed.choices!.where((c) => c.isCorrect).map((c) => c.content),
            equals(<String>['Paris']),
            reason: '🔴 la bonne réponse DOIT atteindre le lot committé');
      },
    );

    testWidgets('🔴 vrai/faux : la valeur cochée atteint le commit',
        (tester) async {
      _bigScreen(tester);
      final spy = _CommitSpy();
      await tester.pumpWidget(_harness(ZMultiFlashcardEditor(
        initialCards: const <ZFlashcard>[
          ZFlashcard(
            id: 'a',
            question: 'Q0',
            type: ZFlashcardType.trueOrFalse,
          ),
        ],
        onCommit: spy.call,
        labels: _labels(),
      )));
      await _focusCard(tester, 'Q0');

      expect(find.byType(ZTrueFalseFieldWidget), findsOneWidget,
          reason: '🔴 une carte vrai/faux DOIT exposer son sélecteur');
      await tester.tap(find.byKey(const Key('z-flashcard-true')));
      await tester.pump();

      await _commit(tester);
      expect(spy.payloads.last.single.isTrue, isTrue,
          reason: '🔴 une carte vrai/faux sans valeur est invalide en révision');
    });

    testWidgets('🔴 balises : une étiquette ajoutée atteint `tagIds`',
        (tester) async {
      _bigScreen(tester);
      final spy = _CommitSpy();
      await tester.pumpWidget(_harness(ZMultiFlashcardEditor(
        initialCards: const <ZFlashcard>[ZFlashcard(id: 'a', question: 'Q0')],
        onCommit: spy.call,
        labels: _labels(),
      )));
      await _focusCard(tester, 'Q0');

      final tagsField = find.byType(ZTagsFieldWidget);
      expect(tagsField, findsOneWidget,
          reason: '🔴 les balises DOIVENT être éditables dans le multi-éditeur');
      await tester.enterText(
        find.descendant(of: tagsField, matching: find.byType(TextField)),
        'algebre',
      );
      await tester.pump();
      await tester.tap(
          find.descendant(of: tagsField, matching: find.byType(IconButton)));
      await tester.pump();

      await _commit(tester);
      expect(spy.payloads.last.single.tagIds, equals(<String>['algebre']));
    });

    testWidgets(
      'les champs conditionnels ne sont montés QUE pour leur type',
      (tester) async {
      _bigScreen(tester);
        final spy = _CommitSpy();
        await tester.pumpWidget(_harness(ZMultiFlashcardEditor(
          initialCards: const <ZFlashcard>[ZFlashcard(id: 'a', question: 'Q0')],
          onCommit: spy.call,
          labels: _labels(),
        )));
        await _focusCard(tester, 'Q0');
        expect(find.byType(ZChoicesFieldWidget), findsNothing,
            reason: 'une question ouverte n\'a pas de choix');
        expect(find.byType(ZTrueFalseFieldWidget), findsNothing);
        // Les balises, elles, ne dépendent pas du type.
        expect(find.byType(ZTagsFieldWidget), findsOneWidget);
      },
    );

    testWidgets(
      '🔴 une valeur posée HORS formulaire n\'est pas écrasée par la frappe '
      'suivante',
      (tester) async {
      _bigScreen(tester);
        final spy = _CommitSpy();
        await tester.pumpWidget(_harness(ZMultiFlashcardEditor(
          initialCards: const <ZFlashcard>[ZFlashcard(id: 'a', question: 'Q0')],
          onCommit: spy.call,
          labels: _labels(),
          commonFields: <ZMultiFlashcardCommonField>[
            ZMultiFlashcardCommonField(
              spec: const ZFieldSpec(
                name: 'tag_ids',
                type: EditionFieldType.text,
              ),
              label: 'Balises',
              apply: (card, value) => card.copyWith(
                tagIds: (value == null || value.isEmpty)
                    ? const <String>[]
                    : value.split(','),
              ),
            ),
          ],
        )));
        await tester.pump();

        // Le formulaire est monté D'ABORD : sa tranche de balises est donc
        // seedée VIDE. Sans cette séquence, la tranche serait seedée sur la
        // valeur déjà appliquée et la garde serait verte même sans protection.
        await _focusCard(tester, 'Q0');

        // PUIS on applique les balises à la sélection, HORS du formulaire.
        await tester.tap(find.byTooltip('Tout sélectionner'));
        await tester.pump();
        await tester.enterText(
            find.byKey(const ValueKey<String>('z-multi-editor-common-value')),
            'x,y');
        await tester.tap(
            find.byKey(const ValueKey<String>('z-multi-editor-apply-common')));
        await tester.pump();

        // ENFIN une frappe DANS le formulaire.
        await tester.enterText(
            find.byKey(const ValueKey<String>('z-card-question')), 'Q!');
        await tester.pump();

        await _commit(tester);
        expect(spy.payloads.last.single.tagIds, equals(<String>['x', 'y']),
            reason: '🔴 la tranche de balises seedée au montage ne DOIT pas '
                'reverter une valeur appliquée hors formulaire');
        expect(spy.payloads.last.single.question, 'Q!');
      },
    );
  });

  group('🔴 la carte INVALIDE bloque le commit', () {
    testWidgets(
      '🔴 QCM à un seul choix ⇒ AUCUNE salve, message affiché ; complété ⇒ salve',
      (tester) async {
      _bigScreen(tester);
        final spy = _CommitSpy();

        // ÉCRITURE TÉMOIN : l'espion capte réellement (sinon « 0 écriture » est
        // infalsifiable).
        await spy.call(const <ZFlashcard>[ZFlashcard(question: 'témoin')]);
        expect(spy.writes, 1);

        await tester.pumpWidget(_harness(ZMultiFlashcardEditor(
          initialCards: const <ZFlashcard>[
            ZFlashcard(
              id: 'a',
              question: 'Q0',
              type: ZFlashcardType.multipleChoice,
              choices: <ZChoice>[ZChoice(content: 'seul', isCorrect: true)],
            ),
          ],
          onCommit: spy.call,
          labels: _labels(),
        )));
        await tester.pump();

        await _commit(tester);
        expect(spy.writes, 1,
            reason: '🔴 un QCM à moins de 2 choix ne DOIT pas être committé');
        // Adressé par la CLÉ de la région d'état : un `find.text` nu pourrait
        // être satisfait par un autre widget portant le même texte.
        expect(
          tester
              .widget<Text>(find
                  .byKey(const ValueKey<String>('z-multi-editor-status')))
              .data,
          ZFlashcardEditionValidator.defaultMessages.qcmMinChoices,
          reason: '🔴 le refus DOIT être rapporté à l\'écran',
        );

        // Complète le QCM : la carte devient valide ⇒ le commit passe.
        await _focusCard(tester, 'Q0');
        await tester.tap(find.byKey(const Key('z-flashcard-choice-add')));
        await tester.pump();
        await tester.enterText(
            find.byKey(const ValueKey<String>('z-flashcard-choice-content-1')),
            'deuxième');
        await tester.pump();
        await _commit(tester);
        expect(spy.writes, 2,
            reason: '🔴 une fois valide, la carte DOIT être committée');
      },
    );

    testWidgets(
      '🔴 QCM sans bonne réponse ⇒ commit bloqué avec le message dédié',
      (tester) async {
      _bigScreen(tester);
        final spy = _CommitSpy();
        // ÉCRITURE TÉMOIN : l'espion capte réellement.
        await spy.call(const <ZFlashcard>[ZFlashcard(question: 'témoin')]);
        expect(spy.writes, 1);

        await tester.pumpWidget(_harness(ZMultiFlashcardEditor(
          initialCards: const <ZFlashcard>[
            ZFlashcard(
              id: 'a',
              question: 'Q0',
              type: ZFlashcardType.multipleChoice,
              choices: <ZChoice>[
                ZChoice(content: 'a'),
                ZChoice(content: 'b'),
              ],
            ),
          ],
          onCommit: spy.call,
          labels: _labels(),
        )));
        await tester.pump();
        await _commit(tester);
        expect(spy.writes, 1,
            reason: '🔴 un QCM sans bonne réponse ne DOIT pas être committé');
        expect(
          tester
              .widget<Text>(find
                  .byKey(const ValueKey<String>('z-multi-editor-status')))
              .data,
          ZFlashcardEditionValidator.defaultMessages.qcmNoCorrect,
        );
      },
    );

    testWidgets('un `cardValidator` injecté remplace la règle du socle',
        (tester) async {
      _bigScreen(tester);
      final spy = _CommitSpy();
      await tester.pumpWidget(_harness(ZMultiFlashcardEditor(
        initialCards: const <ZFlashcard>[
          ZFlashcard(
            id: 'a',
            question: 'Q0',
            type: ZFlashcardType.multipleChoice,
          ),
        ],
        onCommit: spy.call,
        labels: _labels(),
        // Échappatoire : l'hôte reprend la main sur la règle.
        cardValidator: (card) => null,
      )));
      await tester.pump();
      await _commit(tester);
      expect(spy.writes, 1,
          reason: 'la règle injectée l\'emporte sur celle du socle');
    });
  });

  group('🔴 `cardFormBuilder` — créneau de formulaire COMPLET', () {
    testWidgets(
      '🔴 fourni ⇒ RENDU, et le formulaire du socle disparaît (aucun doublon)',
      (tester) async {
      _bigScreen(tester);
        final spy = _CommitSpy();
        await tester.pumpWidget(_harness(ZMultiFlashcardEditor(
          initialCards: const <ZFlashcard>[ZFlashcard(id: 'a', question: 'Q0')],
          onCommit: spy.call,
          labels: _labels(),
          cardFormBuilder: (context, slot) =>
              const Text('FORMULAIRE COMPLET HÔTE'),
        )));
        await _focusCard(tester, 'Q0');

        expect(find.text('FORMULAIRE COMPLET HÔTE'), findsOneWidget,
            reason: '🔴 le créneau DOIT être rendu, pas seulement passé');
        for (final key in <String>[
          'z-card-question',
          'z-card-answer',
          'z-card-explanation',
          'z-card-hint',
          'z-card-type',
        ]) {
          expect(find.byKey(ValueKey<String>(key)), findsNothing,
              reason: '🔴 le socle ne rend JAMAIS deux fois un champ que '
                  'l\'hôte rend ($key)');
        }
        expect(find.byType(ZTagsFieldWidget), findsNothing);
      },
    );

    testWidgets(
      '🔴 les écritures du créneau atteignent le brouillon PUIS le commit',
      (tester) async {
      _bigScreen(tester);
        final spy = _CommitSpy();
        late ZFlashcardCardFormSlot captured;
        await tester.pumpWidget(_harness(ZMultiFlashcardEditor(
          initialCards: const <ZFlashcard>[ZFlashcard(id: 'a', question: 'Q0')],
          onCommit: spy.call,
          labels: _labels(),
          cardFormBuilder: (context, slot) {
            captured = slot;
            return const Text('HÔTE');
          },
        )));
        await _focusCard(tester, 'Q0');

        captured.onQuestionChanged('Capitale ?');
        captured.onAnswerChanged('Paris');
        captured.onExplanationChanged('Depuis 508.');
        captured.onHintChanged('Sur la Seine.');
        captured.onTypeChanged(ZFlashcardType.multipleChoice);
        captured.onChoicesChanged(const <ZChoice>[
          ZChoice(content: 'Paris', isCorrect: true),
          ZChoice(content: 'Lyon'),
        ]);
        captured.onTagIdsChanged(const <String>['geo']);
        await tester.pump();

        await _commit(tester);

        expect(spy.writes, 1,
            reason: '🔴 le commit reste UNIQUE (une salve par intention)');
        final card = spy.payloads.last.single;
        expect(card.question, 'Capitale ?');
        expect(card.answer, 'Paris');
        expect(card.explanation, 'Depuis 508.');
        expect(card.hint, 'Sur la Seine.');
        expect(card.type, ZFlashcardType.multipleChoice);
        expect(card.choices!.length, 2);
        expect(card.choices!.first.isCorrect, isTrue);
        expect(card.tagIds, equals(<String>['geo']));
        expect(card.id, 'a', reason: 'l\'identité persistée est préservée');
      },
    );

    testWidgets(
      '🔴 vrai/faux du créneau : `onIsTrueChanged` atteint le lot committé',
      (tester) async {
      _bigScreen(tester);
        final spy = _CommitSpy();
        late ZFlashcardCardFormSlot captured;
        await tester.pumpWidget(_harness(ZMultiFlashcardEditor(
          initialCards: const <ZFlashcard>[
            ZFlashcard(
                id: 'a', question: 'Q0', type: ZFlashcardType.trueOrFalse),
          ],
          onCommit: spy.call,
          labels: _labels(),
          cardFormBuilder: (context, slot) {
            captured = slot;
            return const Text('HÔTE');
          },
        )));
        await _focusCard(tester, 'Q0');
        captured.onIsTrueChanged(false);
        await tester.pump();
        await _commit(tester);
        expect(spy.payloads.last.single.isTrue, isFalse);
      },
    );

    testWidgets(
      '🔴 le controller remis est STABLE et sa saisie est PUBLIÉE',
      (tester) async {
      _bigScreen(tester);
        final spy = _CommitSpy();
        late ZFlashcardCardFormSlot captured;
        await tester.pumpWidget(_harness(ZMultiFlashcardEditor(
          initialCards: const <ZFlashcard>[ZFlashcard(id: 'a', question: 'Q0')],
          onCommit: spy.call,
          labels: _labels(),
          cardFormBuilder: (context, slot) {
            captured = slot;
            return TextField(
              key: const ValueKey<String>('hote-question'),
              controller: slot.controllerOf(ZFlashcardEditorField.question),
            );
          },
        )));
        await _focusCard(tester, 'Q0');

        final before = captured.controllerOf(ZFlashcardEditorField.question);
        expect(before.text, 'Q0',
            reason: 'le controller est seedé sur la carte du brouillon');

        await tester.enterText(
            find.byKey(const ValueKey<String>('hote-question')), 'Édité');
        await tester.pump();

        final after = captured.controllerOf(ZFlashcardEditorField.question);
        expect(identical(before, after), isTrue,
            reason: '🔴 AD-2 : controller STABLE entre deux reconstructions');

        await _commit(tester);
        expect(spy.payloads.last.single.question, 'Édité',
            reason: '🔴 la saisie de l\'hôte DOIT atteindre le lot committé');
      },
    );

    testWidgets('🔴 `slot.validate()` rend la règle du socle', (tester) async {
      _bigScreen(tester);
      final spy = _CommitSpy();
      late ZFlashcardCardFormSlot captured;
      await tester.pumpWidget(_harness(ZMultiFlashcardEditor(
        initialCards: const <ZFlashcard>[
          ZFlashcard(
              id: 'a', question: 'Q0', type: ZFlashcardType.multipleChoice),
        ],
        onCommit: spy.call,
        labels: _labels(),
        cardFormBuilder: (context, slot) {
          captured = slot;
          return const Text('HÔTE');
        },
      )));
      await _focusCard(tester, 'Q0');

      expect(captured.validate(),
          ZFlashcardEditionValidator.defaultMessages.qcmMinChoices);

      captured.onChoicesChanged(const <ZChoice>[
        ZChoice(content: 'a', isCorrect: true),
        ZChoice(content: 'b'),
      ]);
      await tester.pump();
      expect(captured.validate(), isNull,
          reason: 'la carte complétée est valide');
    });

    testWidgets('la carte remise au créneau est celle du BROUILLON',
        (tester) async {
      _bigScreen(tester);
      final spy = _CommitSpy();
      final seen = <String>[];
      await tester.pumpWidget(_harness(ZMultiFlashcardEditor(
        initialCards: const <ZFlashcard>[ZFlashcard(id: 'a', question: 'Q0')],
        onCommit: spy.call,
        labels: _labels(),
        cardFormBuilder: (context, slot) {
          seen.add(slot.card.question);
          return Text(slot.card.question);
        },
      )));
      await _focusCard(tester, 'Q0');
      expect(seen, isNotEmpty);
      expect(seen.last, 'Q0');
    });
  });

  group('🔴 libellés de la garde de sortie', () {
    Future<void> pumpAndLeave(
      WidgetTester tester,
      ZMultiFlashcardEditorLabels labels,
    ) async {
      final spy = _CommitSpy();
      await tester.pumpWidget(_harness(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppBar(),
                  body: ZMultiFlashcardEditor(
                    onCommit: spy.call,
                    labels: labels,
                  ),
                ),
              ),
            ),
            child: const Text('PUSH'),
          ),
        ),
      ));
      await tester.tap(find.text('PUSH'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ZMultiFlashcardEditor.addButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
    }

    testWidgets('🔴 posés ⇒ le dialogue les AFFICHE', (tester) async {
      _bigScreen(tester);
      await pumpAndLeave(
        tester,
        _labels(
          discardTitle: 'Abandonner les cartes ?',
          discardMessage: 'Les cartes saisies seront perdues.',
          discardConfirmLabel: 'Abandonner',
          discardCancelLabel: 'Continuer la saisie',
        ),
      );
      // Sujet monté PROUVÉ : le dialogue est bien à l'écran.
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Abandonner les cartes ?'), findsOneWidget);
      expect(find.text('Les cartes saisies seront perdues.'), findsOneWidget);
      expect(find.text('Abandonner'), findsOneWidget);
      expect(find.text('Continuer la saisie'), findsOneWidget);
      // Contre-preuve : le repli du socle n'est PAS affiché.
      expect(find.text(ZDiscardChangesGuard.defaultTitle), findsNothing);
    });

    testWidgets('non posés ⇒ le repli du socle, inchangé', (tester) async {
      _bigScreen(tester);
      await pumpAndLeave(tester, _labels());
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text(ZDiscardChangesGuard.defaultTitle), findsOneWidget);
      expect(find.text(ZDiscardChangesGuard.defaultMessage), findsOneWidget);
    });
  });
}
