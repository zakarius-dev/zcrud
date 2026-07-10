// MEDIUM-1 (code-review E3-4) — Place stable des BLOCS du chemin GROUPÉ quand
// leur composition se DÉCALE.
//
// Régression corrigée : le `ListView.builder` externe du chemin groupé montait
// des blocs (bloc « loose » de tête, `Column` de section) NON keyés et SANS
// `findChildIndexCallback`. Quand un bloc de tête bascule (loose qui
// apparaît/disparaît) OU qu'une section AMONT se vide (`if (members.isEmpty)
// continue`), les `Column` aval se décalent PAR POSITION ⇒ un `Column` est
// réutilisé pour une AUTRE section ⇒ `State`/focus des champs aval perdus.
//
// Après correctif : chaque bloc est keyé (`ValueKey('block:__loose__' | 'block:
// section:<title>')`) et le `ListView.builder` groupé reçoit un
// `findChildIndexCallback` ⇒ les blocs décalés sont RETROUVÉS par clé ⇒ focus +
// texte + `State` des blocs aval préservés. Ces tests ÉCHOUENT avec l'ancien
// code (blocs non keyés) et PASSENT après.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Harnais groupé (sections, sans grille) :
/// - `head` : champ LOOSE de tête, conditionnel (truthy `showHead`) ⇒ bascule le
///   bloc de tête.
/// - Section A : `a1` conditionnel (truthy `keepA`) — quand `a1` disparaît, la
///   section A devient VIDE et est sautée ⇒ décale la section B aval.
/// - Section B : `b1` (champ AVAL focalisé, jamais conditionnel).
/// - Gardes `showHead`, `keepA` placées en LOOSE de tête (toujours visibles).
class _GroupedForm {
  final Map<String, int> fieldInits = <String, int>{};

  final List<ZFieldSpec> fields = const <ZFieldSpec>[
    ZFieldSpec(name: 'showHead', type: EditionFieldType.boolean, label: 'SH'),
    ZFieldSpec(name: 'keepA', type: EditionFieldType.boolean, label: 'KA'),
    ZFieldSpec(
      name: 'head',
      type: EditionFieldType.text,
      label: 'Head',
      condition: ZCondition.truthy('showHead'),
    ),
    ZFieldSpec(
      name: 'a1',
      type: EditionFieldType.text,
      label: 'A1',
      condition: ZCondition.truthy('keepA'),
    ),
    ZFieldSpec(name: 'b1', type: EditionFieldType.text, label: 'B1'),
  ];

  final List<ZEditionSection> sections = const <ZEditionSection>[
    // Repliable ⇒ chemin GROUPÉ (même sans grille).
    ZEditionSection(title: 'A', fields: <String>['a1'], collapsible: true),
    ZEditionSection(title: 'B', fields: <String>['b1'], collapsible: true),
  ];

  late final ZFormController controller = ZFormController(
    initialValues: const <String, Object?>{
      'showHead': false,
      'keepA': true,
      'head': '',
      'a1': '',
      'b1': '',
    },
    visibleFields: const <String>['showHead', 'keepA', 'head', 'a1', 'b1'],
  );

  Widget build() => MaterialApp(
        home: Scaffold(
          body: DynamicEdition(
            controller: controller,
            fields: fields,
            sections: sections,
            fieldBuilder: (context, ctrl, field) => ZFieldWidget(
              controller: ctrl,
              field: field,
              onInit: () =>
                  fieldInits[field.name] = (fieldInits[field.name] ?? 0) + 1,
            ),
          ),
        ),
      );

  void dispose() => controller.dispose();
}

Finder _editableOf(String name) => find.descendant(
      of: find.byKey(ValueKey<String>(name)),
      matching: find.byType(EditableText),
    );

void main() {
  testWidgets(
      'MEDIUM-1 — bloc loose de tête qui apparaît : focus + texte + State du '
      'champ aval `b1` préservés', (tester) async {
    final form = _GroupedForm();
    addTearDown(form.dispose);
    await tester.pumpWidget(form.build());
    await tester.pumpAndSettle();

    // Au départ : pas de bloc loose (`showHead` false ⇒ `head` masqué).
    expect(find.byKey(const ValueKey<String>('head')), findsNothing);
    expect(form.fieldInits['b1'], 1, reason: 'b1 monté une seule fois');

    TextEditingController ctrl() =>
        tester.widget<EditableText>(_editableOf('b1')).controller;
    FocusNode focus() =>
        tester.widget<EditableText>(_editableOf('b1')).focusNode;

    // Focaliser `b1` (section B, aval) et poser un texte + caret médian.
    await tester.tap(_editableOf('b1'));
    await tester.pump();
    expect(focus().hasFocus, isTrue);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'HELLO',
        selection: TextSelection.collapsed(offset: 2),
      ),
    );
    await tester.pump();
    expect(ctrl().text, 'HELLO');

    // Le bloc LOOSE de tête APPARAÎT (`head` devient visible) ⇒ INSÈRE un bloc
    // AVANT les sections A et B ⇒ décale tous les blocs aval.
    form.controller.setValue('showHead', true);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('head')), findsOneWidget);

    // `b1` (bloc aval décalé) : State non recréé, focus + texte + caret gardés.
    expect(form.fieldInits['b1'], 1,
        reason: 'bloc B keyé ⇒ Column réutilisée malgré le décalage');
    expect(focus().hasFocus, isTrue);
    expect(ctrl().text, 'HELLO');
    expect(ctrl().selection.baseOffset, 2);
  });

  testWidgets(
      'MEDIUM-1 — section AMONT qui se vide : focus + texte + State du champ '
      'd\'une section AVAL préservés', (tester) async {
    final form = _GroupedForm();
    addTearDown(form.dispose);
    await tester.pumpWidget(form.build());
    await tester.pumpAndSettle();

    // Au départ : section A a un membre (`a1` visible car `keepA` true).
    expect(find.byKey(const ValueKey<String>('a1')), findsOneWidget);
    expect(form.fieldInits['b1'], 1);

    TextEditingController ctrl() =>
        tester.widget<EditableText>(_editableOf('b1')).controller;
    FocusNode focus() =>
        tester.widget<EditableText>(_editableOf('b1')).focusNode;

    await tester.tap(_editableOf('b1'));
    await tester.pump();
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'WORLD',
        selection: TextSelection.collapsed(offset: 3),
      ),
    );
    await tester.pump();
    expect(focus().hasFocus, isTrue);
    expect(ctrl().text, 'WORLD');

    // `keepA` false ⇒ `a1` disparaît ⇒ section A DEVIENT VIDE et est sautée
    // (`if (members.isEmpty) continue`) ⇒ la section B remonte d'un cran.
    form.controller.setValue('keepA', false);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('a1')), findsNothing);
    // La section A a disparu (plus d'en-tête A) mais B subsiste.
    expect(find.byKey(const ValueKey<String>('section:A')), findsNothing);
    expect(find.byKey(const ValueKey<String>('b1')), findsOneWidget);

    // `b1` (section B, désormais remontée) : State/focus/texte préservés.
    expect(form.fieldInits['b1'], 1,
        reason: 'bloc B retrouvé par clé malgré la section A vidée en amont');
    expect(focus().hasFocus, isTrue);
    expect(ctrl().text, 'WORLD');
    expect(ctrl().selection.baseOffset, 3);
  });
}
