// AC10/AC11 — Mode lecture global + showIfNull. `readOnly` global force la
// lecture de chaque champ (via spec effective) ; `showIfNull:false` masque les
// champs vides EN LECTURE uniquement (aucun effet en édition).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _fields = <ZFieldSpec>[
  ZFieldSpec(name: 'nom', type: EditionFieldType.text, label: 'Nom'),
  ZFieldSpec(name: 'note', type: EditionFieldType.text, label: 'Note'),
  // Champ masqué en lecture s'il est vide.
  ZFieldSpec(
    name: 'optionnel',
    type: EditionFieldType.text,
    label: 'Optionnel',
    showIfNull: false,
  ),
];

ZFormController _controller() => ZFormController(
      initialValues: const <String, Object?>{
        'nom': 'Ada',
        // DP-13 : `note` renseigné (sinon, défaut `showIfNull:false`, il serait
        // masqué en lecture comme un champ vide).
        'note': 'Note',
        'optionnel': '',
      },
      visibleFields: const <String>['nom', 'note', 'optionnel'],
    );

Widget _app(ZFormController controller, {required bool readOnly}) => MaterialApp(
      home: Scaffold(
        body: DynamicEdition(
          controller: controller,
          fields: _fields,
          readOnly: readOnly,
        ),
      ),
    );

Finder _editableOf(String name) => find.descendant(
      of: find.byKey(ValueKey<String>(name)),
      matching: find.byType(EditableText),
    );

void main() {
  testWidgets(
      'AC10/DP-13 — readOnly global rend CHAQUE champ fiche-able en fiche '
      '(non éditable, aucun EditableText)', (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller, readOnly: true));
    await tester.pumpAndSettle();

    // `nom` + `note` (renseignés) rendus en fiche de consultation ; `optionnel`
    // (vide, showIfNull:false) masqué. Aucun champ éditable en mode lecture.
    expect(find.byType(ZReadOnlyFieldCard), findsNWidgets(2));
    expect(find.byType(EditableText), findsNothing);
  });

  testWidgets('AC10 — hors mode global, un champ reste éditable', (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller, readOnly: false));
    await tester.pumpAndSettle();

    final ed = tester.widget<EditableText>(_editableOf('nom'));
    expect(ed.readOnly, isFalse);
  });

  testWidgets('AC11 — showIfNull:false masque le champ VIDE en lecture',
      (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller, readOnly: true));
    await tester.pumpAndSettle();

    // `optionnel` est vide + showIfNull:false ⇒ masqué en lecture.
    expect(find.byKey(const ValueKey<String>('optionnel')), findsNothing);
    // Les champs renseignés/`showIfNull:true` restent affichés.
    expect(find.byKey(const ValueKey<String>('nom')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('note')), findsOneWidget);
  });

  testWidgets('AC11 — showIfNull:false affiche le champ RENSEIGNÉ en lecture',
      (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    controller.setValue('optionnel', 'présent');
    await tester.pumpWidget(_app(controller, readOnly: true));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('optionnel')), findsOneWidget);
  });

  testWidgets('AC11 — showIfNull SANS effet hors mode lecture (édition)',
      (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller, readOnly: false));
    await tester.pumpAndSettle();

    // En édition, `optionnel` vide reste affiché (showIfNull ignoré).
    expect(find.byKey(const ValueKey<String>('optionnel')), findsOneWidget);
  });
}
