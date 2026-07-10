// AC1/AC2/AC3/AC4/AC6 — widgets d'édition flashcard ADDITIFS servis via
// `ZWidgetRegistry` : montage dans `DynamicEdition` sans repli, validation QCM
// révélée (canal `reveal`, sans `Form` global), SM-1 (rebuild ciblé + focus +
// contrôleur stable), a11y opérable ≥48dp + RTL, intégration dépôt (SRS piloté
// par l'app, aucune avancée SRS hors reviewCard).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

import 'support/a11y_asserts.dart';
import 'support/fakes.dart';

ZWidgetRegistry _registry() {
  final r = ZWidgetRegistry();
  registerZFlashcardEditors(r);
  return r;
}

ZFormController _controller(Map<String, Object?> values) => ZFormController(
      initialValues: values,
      visibleFields: values.keys.toList(),
    );

Widget _app(
  ZFormController controller,
  List<ZFieldSpec> fields, {
  ZWidgetRegistry? registry,
  TextDirection dir = TextDirection.ltr,
}) =>
    MaterialApp(
      home: Directionality(
        textDirection: dir,
        child: ZcrudScope(
          widgetRegistry: registry,
          child: ZFlashcardEditingScope(
            controller: controller,
            child: Scaffold(
              body: DynamicEdition(controller: controller, fields: fields),
            ),
          ),
        ),
      ),
    );

void main() {
  group('AC1 — widgets additifs servis via le registre (sans repli)', () {
    testWidgets('type/choices/trueFalse montés dans DynamicEdition', (t) async {
      final cases = <ZFieldSpec, Type>{
        ZFlashcardEditionFields.type(name: 'type'): ZFlashcardTypeFieldWidget,
        ZFlashcardEditionFields.choices(name: 'choices'): ZChoicesFieldWidget,
        ZFlashcardEditionFields.trueFalse(name: 'is_true'):
            ZTrueFalseFieldWidget,
      };
      for (final entry in cases.entries) {
        final c = _controller(<String, Object?>{entry.key.name: null});
        await t.pumpWidget(_app(c, <ZFieldSpec>[entry.key], registry: _registry()));
        expect(find.byType(entry.value), findsOneWidget);
        expect(find.byType(ZUnsupportedFieldWidget), findsNothing);
      }
    });

    testWidgets('registre absent (null) → repli ZUnsupportedFieldWidget',
        (t) async {
      final c = _controller(<String, Object?>{'choices': null});
      await t.pumpWidget(
          _app(c, <ZFieldSpec>[ZFlashcardEditionFields.choices(name: 'choices')]));
      expect(find.byType(ZChoicesFieldWidget), findsNothing);
      expect(find.byType(ZUnsupportedFieldWidget), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('type défensif : valeur illisible → openQuestion sélectionné',
        (t) async {
      final c = _controller(<String, Object?>{'type': 'garbage'});
      await t.pumpWidget(
          _app(c, <ZFieldSpec>[ZFlashcardEditionFields.type(name: 'type')],
              registry: _registry()));
      final node = t.getSemantics(
          find.byKey(const ValueKey<String>('z-flashcard-type-openQuestion')));
      expect(node, isSemantics(isSelected: true),
          reason: 'repli défensif AD-10 → openQuestion');
    });
  });

  group('AC3 — édition : la tranche reçoit la valeur typée', () {
    testWidgets('sélection de type → tranche = ZFlashcardType', (t) async {
      final c = _controller(<String, Object?>{'type': null});
      await t.pumpWidget(
          _app(c, <ZFieldSpec>[ZFlashcardEditionFields.type(name: 'type')],
              registry: _registry()));
      await t.tap(
          find.byKey(const ValueKey<String>('z-flashcard-type-multipleChoice')));
      await t.pump();
      expect(c.valueOf('type'), ZFlashcardType.multipleChoice);
    });

    testWidgets('vrai/faux → tranche = bool', (t) async {
      final c = _controller(<String, Object?>{'is_true': null});
      await t.pumpWidget(
          _app(c, <ZFieldSpec>[ZFlashcardEditionFields.trueFalse(name: 'is_true')],
              registry: _registry()));
      await t.tap(find.byKey(const Key('z-flashcard-false')));
      await t.pump();
      expect(c.valueOf('is_true'), false);
      await t.tap(find.byKey(const Key('z-flashcard-true')));
      await t.pump();
      expect(c.valueOf('is_true'), true);
    });

    testWidgets('QCM : add/edit/toggle-correct/reorder/remove → tranche liste',
        (t) async {
      final c = _controller(<String, Object?>{'choices': <ZChoice>[]});
      await t.pumpWidget(
          _app(c, <ZFieldSpec>[ZFlashcardEditionFields.choices(name: 'choices')],
              registry: _registry()));
      // Ajoute deux choix.
      await t.tap(find.byKey(const Key('z-flashcard-choice-add')));
      await t.pump();
      await t.tap(find.byKey(const Key('z-flashcard-choice-add')));
      await t.pump();
      await t.enterText(
          find.byKey(const ValueKey<String>('z-flashcard-choice-content-0')), 'A');
      await t.pump();
      await t.enterText(
          find.byKey(const ValueKey<String>('z-flashcard-choice-content-1')), 'B');
      await t.pump();
      // Marque le 1er correct.
      await t.tap(
          find.byKey(const ValueKey<String>('z-flashcard-choice-correct-0')));
      await t.pump();
      var choices = (c.valueOf('choices')! as List).cast<ZChoice>();
      expect(choices.map((e) => e.content).toList(), <String>['A', 'B']);
      expect(choices[0].isCorrect, isTrue);
      expect(choices[1].isCorrect, isFalse);
      // Réordonne : descend le 1er.
      await t.tap(find.byKey(const ValueKey<String>('z-flashcard-choice-down-0')));
      await t.pump();
      choices = (c.valueOf('choices')! as List).cast<ZChoice>();
      expect(choices.map((e) => e.content).toList(), <String>['B', 'A']);
      expect(choices[1].isCorrect, isTrue, reason: 'le "correct" suit le choix');
      // Supprime le 1er restant.
      await t.tap(find.byKey(const ValueKey<String>('z-flashcard-choice-remove-0')));
      await t.pump();
      choices = (c.valueOf('choices')! as List).cast<ZChoice>();
      expect(choices.map((e) => e.content).toList(), <String>['A']);
    });
  });

  group('AC2 — validation éditeur QCM révélée (canal reveal, sans Form global)',
      () {
    testWidgets('QCM invalide → message révélé + soumission bloquée ; corrigé → passe',
        (t) async {
      final c = _controller(<String, Object?>{
        'question': 'Q ?',
        'type': ZFlashcardType.multipleChoice,
        'choices': <ZChoice>[const ZChoice(content: 'A')],
      });
      await t.pumpWidget(
          _app(c, <ZFieldSpec>[ZFlashcardEditionFields.choices(name: 'choices')],
              registry: _registry()));

      var saveCount = 0;
      void submit() {
        if (ZFlashcardEditionValidator.validateAndReveal(c)) saveCount++;
      }

      // Soumission 1 : 1 choix (< 2) → bloquée + message révélé.
      submit();
      await t.pump();
      expect(saveCount, 0, reason: 'soumission bloquée');
      expect(find.byKey(const Key('z-flashcard-choices-error')), findsOneWidget);

      // Corrige : 2 choix + 1 correct.
      c.setValue('choices', <ZChoice>[
        const ZChoice(content: 'A', isCorrect: true),
        const ZChoice(content: 'B'),
      ]);
      await t.pump();
      submit();
      await t.pump();
      expect(saveCount, 1, reason: 'soumission passe après correction');
      expect(find.byKey(const Key('z-flashcard-choices-error')), findsNothing);
    });

    testWidgets(
        'MEDIUM-1 : carte NON-QCM → aucun message QCM parasite même après reveal',
        (t) async {
      final c = _controller(<String, Object?>{
        'question': '', // vide → déclenche reveal via l'erreur d'énoncé
        'type': ZFlashcardType.openQuestion, // PAS multipleChoice
        'choices': <ZChoice>[const ZChoice(content: 'A')], // invalide SI QCM
      });
      await t.pumpWidget(
          _app(c, <ZFieldSpec>[ZFlashcardEditionFields.choices(name: 'choices')],
              registry: _registry()));

      // Reveal déclenché (énoncé vide) mais type ≠ QCM → la surface QCM doit
      // rester masquée (pas de message parasite « ≥ 2 choix »).
      expect(ZFlashcardEditionValidator.validateAndReveal(c), isFalse);
      await t.pump();
      expect(find.byKey(const Key('z-flashcard-choices-error')), findsNothing,
          reason: 'aucun message QCM parasite sur une carte non-QCM');
    });

    testWidgets('avant toute soumission : aucun message (reveal == 0)', (t) async {
      final c = _controller(<String, Object?>{
        'choices': <ZChoice>[const ZChoice(content: 'A')],
      });
      await t.pumpWidget(
          _app(c, <ZFieldSpec>[ZFlashcardEditionFields.choices(name: 'choices')],
              registry: _registry()));
      expect(find.byKey(const Key('z-flashcard-choices-error')), findsNothing);
    });

    test('validateur pur : ≥2 choix + ≥1 correct (AC2)', () {
      expect(
          ZFlashcardEditionValidator.validateChoices(
              <ZChoice>[const ZChoice(content: 'A', isCorrect: true)]),
          isNotNull,
          reason: '< 2 choix invalide');
      expect(
          ZFlashcardEditionValidator.validateChoices(<ZChoice>[
            const ZChoice(content: 'A'),
            const ZChoice(content: 'B'),
          ]),
          isNotNull,
          reason: '0 correct invalide');
      expect(
          ZFlashcardEditionValidator.validateChoices(<ZChoice>[
            const ZChoice(content: 'A', isCorrect: true),
            const ZChoice(content: 'B'),
          ]),
          isNull,
          reason: '2 choix + 1 correct valide');
    });
  });

  group('AC3 — SM-1 : rebuild ciblé + focus + contrôleur stable', () {
    Widget sliced(
      ZFormController c,
      String name,
      Key key, {
      VoidCallback? onInit,
      VoidCallback? onBuild,
    }) =>
        KeyedSubtree(
          key: key,
          child: ValueListenableBuilder<Object?>(
            valueListenable: c.fieldListenable(name),
            builder: (context, value, _) => ZChoicesFieldWidget(
              ctx: ZFieldWidgetContext(
                field: ZFlashcardEditionFields.choices(name: name),
                value: value,
                onChanged: (v) => c.setValue(name, v),
              ),
              onInit: onInit,
              onBuild: onBuild,
            ),
          ),
        );

    testWidgets('frappe QCM (100 car.) → voisin non reconstruit ; focus ; init==1',
        (t) async {
      final c = ZFormController(
        initialValues: <String, Object?>{
          'a': <ZChoice>[const ZChoice(content: '')],
          'b': <ZChoice>[const ZChoice(content: '')],
        },
        visibleFields: <String>['a', 'b'],
      );
      var initA = 0;
      var buildB = 0;
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(children: <Widget>[
            sliced(c, 'a', const Key('hostA'), onInit: () => initA++),
            sliced(c, 'b', const Key('hostB'), onBuild: () => buildB++),
          ]),
        ),
      ));

      final contentA = find
          .descendant(
              of: find.byKey(const Key('hostA')),
              matching:
                  find.byKey(const ValueKey<String>('z-flashcard-choice-content-0')))
          .first;
      final controllerBefore = t.widget<TextField>(contentA).controller;
      final buildBBefore = buildB;

      await t.tap(contentA);
      await t.pump();
      await t.enterText(contentA, 'x' * 100);
      await t.pump();

      expect(initA, 1, reason: 'State non recréé (contrôleur stable)');
      expect(buildB, buildBBefore, reason: 'le voisin QCM n\'est PAS reconstruit');
      expect(t.widget<TextField>(contentA).focusNode!.hasFocus, isTrue,
          reason: 'focus préservé pendant la frappe');
      expect(identical(t.widget<TextField>(contentA).controller, controllerBefore),
          isTrue,
          reason: 'identité TextEditingController stable entre frappes');
      expect((c.valueOf('a')! as List).cast<ZChoice>().first.content,
          'x' * 100);
    });

    testWidgets('ajouter un choix ne reconstruit que l\'éditeur QCM courant',
        (t) async {
      final c = ZFormController(
        initialValues: <String, Object?>{'a': <ZChoice>[], 'b': <ZChoice>[]},
        visibleFields: <String>['a', 'b'],
      );
      var buildB = 0;
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(children: <Widget>[
            sliced(c, 'a', const Key('hostA')),
            sliced(c, 'b', const Key('hostB'), onBuild: () => buildB++),
          ]),
        ),
      ));
      final buildBBefore = buildB;
      await t.tap(find
          .descendant(
              of: find.byKey(const Key('hostA')),
              matching: find.byKey(const Key('z-flashcard-choice-add')))
          .first);
      await t.pump();
      expect(buildB, buildBBefore, reason: 'ajout local n\'affecte pas le voisin');
      expect((c.valueOf('a')! as List), hasLength(1));
    });
  });

  group('AC4 — a11y : action opérable + ≥48dp + RTL', () {
    testWidgets('sélecteur de type : chaque option opérable + ≥48dp', (t) async {
      final handle = t.ensureSemantics();
      final c = _controller(<String, Object?>{'type': null});
      await t.pumpWidget(
          _app(c, <ZFieldSpec>[ZFlashcardEditionFields.type(name: 'type')],
              registry: _registry()));
      for (final type in ZFlashcardType.values) {
        final finder =
            find.byKey(ValueKey<String>('z-flashcard-type-${type.name}'));
        assertMinTapTarget(t, finder, 48);
        await assertSemanticActionTap(t, finder);
      }
      expect(c.valueOf('type'), ZFlashcardType.shortAnswer,
          reason: 'la dernière action tap a sélectionné le dernier type');
      handle.dispose();
    });

    testWidgets('QCM : chaque cible (add/correct/up/down/remove/champ) opérable+48dp',
        (t) async {
      final handle = t.ensureSemantics();
      final c = _controller(<String, Object?>{
        'choices': <ZChoice>[
          const ZChoice(content: 'A'),
          const ZChoice(content: 'B'),
        ],
      });
      await t.pumpWidget(
          _app(c, <ZFieldSpec>[ZFlashcardEditionFields.choices(name: 'choices')],
              registry: _registry()));

      for (final key in <Key>[
        const Key('z-flashcard-choice-add'),
        const ValueKey<String>('z-flashcard-choice-correct-0'),
        const ValueKey<String>('z-flashcard-choice-down-0'),
        const ValueKey<String>('z-flashcard-choice-remove-0'),
        const ValueKey<String>('z-flashcard-choice-content-0'),
      ]) {
        final finder = find.byKey(key);
        expect(finder, findsOneWidget, reason: 'cible $key présente');
        assertMinTapTarget(t, finder, 48);
      }
      // Action sémantique opérable : toggle correct via lecteur d'écran.
      await assertSemanticActionTap(
        t,
        find.byKey(const ValueKey<String>('z-flashcard-choice-correct-0')),
      );
      expect((c.valueOf('choices')! as List).cast<ZChoice>()[0].isCorrect,
          isTrue);
      handle.dispose();
    });

    testWidgets('vrai/faux : deux options opérables + ≥48dp', (t) async {
      final handle = t.ensureSemantics();
      final c = _controller(<String, Object?>{'is_true': null});
      await t.pumpWidget(
          _app(c, <ZFieldSpec>[ZFlashcardEditionFields.trueFalse(name: 'is_true')],
              registry: _registry()));
      assertMinTapTarget(t, find.byKey(const Key('z-flashcard-true')), 48);
      assertMinTapTarget(t, find.byKey(const Key('z-flashcard-false')), 48);
      await assertSemanticActionTap(t, find.byKey(const Key('z-flashcard-true')));
      expect(c.valueOf('is_true'), true);
      handle.dispose();
    });

    testWidgets('rendu RTL des 3 éditeurs sans exception', (t) async {
      for (final field in <ZFieldSpec>[
        ZFlashcardEditionFields.type(name: 'type'),
        ZFlashcardEditionFields.choices(name: 'choices'),
        ZFlashcardEditionFields.trueFalse(name: 'is_true'),
      ]) {
        final c = _controller(<String, Object?>{field.name: null});
        await t.pumpWidget(_app(c, <ZFieldSpec>[field],
            registry: _registry(), dir: TextDirection.rtl));
        expect(t.takeException(), isNull);
      }
    });
  });

  group('AC6 — intégration dépôt : SRS piloté par l\'app, aucune avancée SRS',
      () {
    testWidgets('édition → save délègue au dépôt ; aucun put SRS pendant l\'édition',
        (t) async {
      final cards = FakeCardRepository();
      final reps = FakeRepetitionStore();
      final repo = ZFlashcardRepository(cards: cards, repetitions: reps);

      final c = _controller(<String, Object?>{
        'question': 'Q ?',
        'choices': <ZChoice>[],
      });
      await t.pumpWidget(
          _app(c, <ZFieldSpec>[ZFlashcardEditionFields.choices(name: 'choices')],
              registry: _registry()));
      // Édite les choix via le widget.
      await t.tap(find.byKey(const Key('z-flashcard-choice-add')));
      await t.pump();
      await t.enterText(
          find.byKey(const ValueKey<String>('z-flashcard-choice-content-0')), 'A');
      await t.pump();

      // L'app compose la carte depuis la tranche et délègue à ZFlashcardRepository.
      final choices = (c.valueOf('choices')! as List).cast<ZChoice>();
      final saved = await repo.save(ZFlashcard(
        folderId: 'folder-1',
        question: c.valueOf('question')! as String,
        type: ZFlashcardType.multipleChoice,
        choices: choices,
      ));
      expect(saved.isRight(), isTrue);
      expect(cards.saveCount, 1, reason: 'save délègue au dépôt injecté');
      expect(reps.putCount, 0,
          reason: 'aucune avancée SRS pendant l\'édition (SRS piloté par l\'app)');
    });
  });
}
