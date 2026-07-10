// AC2..AC6 — Champs conditionnels par sélecteur dérivé, PLACE STABLE, sans
// rebuild global. Un champ `dependent` porteur d'une `condition` truthy('trig')
// apparaît/disparaît selon `trig`, garde sa position ordinale canonique, et une
// frappe sur un champ NON-garde ne déclenche AUCUN recalcul de visibilité.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Harnais : `trig` (garde) · `dependent` (conditionnel) · `other` (non-garde),
/// dans CET ordre canonique.
class _CondForm {
  final Map<String, int> fieldBuilds = <String, int>{};
  final Map<String, int> fieldInits = <String, int>{};
  int formBuilds = 0;

  final List<ZFieldSpec> fields = const <ZFieldSpec>[
    ZFieldSpec(name: 'trig', type: EditionFieldType.text, label: 'Trig'),
    ZFieldSpec(
      name: 'dependent',
      type: EditionFieldType.text,
      label: 'Dependent',
      condition: ZCondition.truthy('trig'),
    ),
    ZFieldSpec(name: 'other', type: EditionFieldType.text, label: 'Other'),
  ];

  late final ZFormController controller = ZFormController(
    initialValues: const <String, Object?>{
      'trig': '',
      'dependent': '',
      'other': '',
    },
    // Ensemble initial délibérément « tout visible » : le binder doit le
    // corriger au montage (dependent masqué car trig vide).
    visibleFields: const <String>['trig', 'dependent', 'other'],
  );

  Widget build() => MaterialApp(
        home: Scaffold(
          body: DynamicEdition(
            controller: controller,
            fields: fields,
            onStructuralBuild: () => formBuilds++,
            fieldBuilder: (context, ctrl, field) => ZFieldWidget(
              controller: ctrl,
              field: field,
              onInit: () =>
                  fieldInits[field.name] = (fieldInits[field.name] ?? 0) + 1,
              onBuild: () =>
                  fieldBuilds[field.name] = (fieldBuilds[field.name] ?? 0) + 1,
            ),
          ),
        ),
      );

  void dispose() => controller.dispose();
}

Finder _key(String name) => find.byKey(ValueKey<String>(name));

void main() {
  testWidgets('AC2 — dependent apparaît/disparaît selon trig (visibleFields)',
      (tester) async {
    final form = _CondForm();
    addTearDown(form.dispose);
    await tester.pumpWidget(form.build());
    await tester.pumpAndSettle();

    // Amorçage : trig vide ⇒ dependent masqué.
    expect(form.controller.visibleFields.value, <String>['trig', 'other']);
    expect(_key('dependent'), findsNothing);

    // trig devient truthy ⇒ dependent apparaît, à sa place canonique.
    form.controller.setValue('trig', 'x');
    await tester.pumpAndSettle();
    expect(form.controller.visibleFields.value,
        <String>['trig', 'dependent', 'other']);
    expect(_key('dependent'), findsOneWidget);

    // trig redevient vide ⇒ dependent disparaît.
    form.controller.setValue('trig', '');
    await tester.pumpAndSettle();
    expect(_key('dependent'), findsNothing);
    expect(form.controller.visibleFields.value, <String>['trig', 'other']);
  });

  testWidgets('AC5 — place ordinale canonique + valeur de tranche préservée',
      (tester) async {
    final form = _CondForm();
    addTearDown(form.dispose);
    await tester.pumpWidget(form.build());
    await tester.pumpAndSettle();

    // Révèle dependent et saisis une valeur.
    form.controller.setValue('trig', 'x');
    await tester.pumpAndSettle();
    form.controller.setValue('dependent', 'saisie');
    await tester.pumpAndSettle();

    // Position ordinale : dependent est ENTRE trig et other (jamais en fin).
    final yTrig = tester.getTopLeft(_key('trig')).dy;
    final yDep = tester.getTopLeft(_key('dependent')).dy;
    final yOther = tester.getTopLeft(_key('other')).dy;
    expect(yTrig < yDep && yDep < yOther, isTrue,
        reason: 'dependent réinséré à son index canonique (1)');

    // Masque puis réaffiche : la valeur de tranche est PRÉSERVÉE (slice intact).
    form.controller.setValue('trig', '');
    await tester.pumpAndSettle();
    expect(form.controller.valueOf('dependent'), 'saisie',
        reason: 'le slice masqué n\'est JAMAIS détruit');
    form.controller.setValue('trig', 'y');
    await tester.pumpAndSettle();
    expect(form.controller.valueOf('dependent'), 'saisie');
    // Réapparu à sa place canonique.
    final yDep2 = tester.getTopLeft(_key('dependent')).dy;
    expect(tester.getTopLeft(_key('trig')).dy < yDep2, isTrue);
    expect(yDep2 < tester.getTopLeft(_key('other')).dy, isTrue);
  });

  testWidgets(
      'AC3 — frappe sur un champ NON-garde ⇒ ZÉRO recalcul de visibilité / '
      'build structurel (SM-1)', (tester) async {
    final form = _CondForm();
    addTearDown(form.dispose);
    await tester.pumpWidget(form.build());
    await tester.pumpAndSettle();

    final baseForm = form.formBuilds;
    final baseTrig = form.fieldBuilds['trig']!;

    // Frappe sur `other` (référencé par AUCUNE condition) : setValue direct.
    for (var i = 0; i < 20; i++) {
      form.controller.setValue('other', 'v$i');
      await tester.pump();
    }

    // Le champ `other` reconstruit SA PROPRE tranche (réactivité granulaire
    // attendue), mais AUCUN rebuild structurel n'a lieu et AUCUN voisin (trig)
    // ne reconstruit — le sélecteur de visibilité n'est même pas sollicité
    // (visibleFields inchangé), car `other` n'est référencé par aucune garde.
    expect(form.formBuilds, baseForm,
        reason: 'un champ non-garde ne déclenche aucun rebuild structurel');
    expect(form.fieldBuilds['trig'], baseTrig,
        reason: 'aucun voisin ne reconstruit sur une frappe non-garde');
    expect(form.controller.visibleFields.value, <String>['trig', 'other']);
  });

  testWidgets(
      'AC4 — garde changeant SANS changer la visibilité ⇒ no-op structurel',
      (tester) async {
    final form = _CondForm();
    addTearDown(form.dispose);
    await tester.pumpWidget(form.build());
    await tester.pumpAndSettle();

    // Rends dependent visible (une transition structurelle).
    form.controller.setValue('trig', 'a');
    await tester.pumpAndSettle();
    final baseForm = form.formBuilds;

    // trig reste truthy (a→b→c) : la visibilité NE CHANGE PAS ⇒ setVisibleFields
    // no-op ⇒ aucun build structurel supplémentaire.
    form.controller.setValue('trig', 'b');
    await tester.pump();
    form.controller.setValue('trig', 'c');
    await tester.pump();
    expect(form.formBuilds, baseForm,
        reason: 'visibilité inchangée ⇒ listEquals no-op (AC4)');
  });

  testWidgets('AC6 — focus non déplacé quand un champ conditionnel ailleurs '
      'apparaît', (tester) async {
    final form = _CondForm();
    addTearDown(form.dispose);
    await tester.pumpWidget(form.build());
    await tester.pumpAndSettle();

    // Focus sur `other`.
    final otherEditable = find.descendant(
      of: _key('other'),
      matching: find.byType(EditableText),
    );
    await tester.tap(otherEditable);
    await tester.pump();
    expect(tester.widget<EditableText>(otherEditable).focusNode.hasFocus,
        isTrue);

    // Un champ conditionnel APPARAÎT ailleurs (trig change par une autre voie).
    form.controller.setValue('trig', 'x');
    await tester.pumpAndSettle();

    // `other` conserve le focus (place stable ValueKey ⇒ Element réutilisé).
    expect(tester.widget<EditableText>(otherEditable).focusNode.hasFocus,
        isTrue);
    expect(_key('dependent'), findsOneWidget);
  });
}
