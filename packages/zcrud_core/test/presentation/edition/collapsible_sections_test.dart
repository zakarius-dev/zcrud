// AC7..AC9 — Sections repliables accessibles. En-tête `Semantics(button,
// expanded, label)`, cible ≥ 48 dp, insets directionnels ; repli = masquage
// visuel SANS destruction de tranche ; orthogonal à `visibleFields`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _fields = <ZFieldSpec>[
  ZFieldSpec(name: 'a0', type: EditionFieldType.text, label: 'A0'),
  ZFieldSpec(name: 'a1', type: EditionFieldType.text, label: 'A1'),
  ZFieldSpec(name: 'b0', type: EditionFieldType.text, label: 'B0'),
];

ZFormController _controller() => ZFormController(
      initialValues: const <String, Object?>{'a0': '', 'a1': '', 'b0': ''},
      visibleFields: const <String>['a0', 'a1', 'b0'],
    );

Widget _app(
  ZFormController controller, {
  bool initiallyExpanded = true,
  TextDirection textDirection = TextDirection.ltr,
}) =>
    MaterialApp(
      home: Directionality(
        textDirection: textDirection,
        child: Scaffold(
          body: DynamicEdition(
            controller: controller,
            fields: _fields,
            sections: <ZEditionSection>[
              ZEditionSection(
                title: 'Section A',
                fields: const <String>['a0', 'a1'],
                collapsible: true,
                initiallyExpanded: initiallyExpanded,
              ),
              const ZEditionSection(
                title: 'Section B',
                fields: <String>['b0'],
              ),
            ],
          ),
        ),
      ),
    );

Finder _fieldKey(String n) => find.byKey(ValueKey<String>(n));

/// Le widget `Semantics` de l'en-tête de la section [title] (propriétés
/// explicites vérifiables : button/expanded/label).
Semantics _headerSemantics(WidgetTester tester, String title) {
  return tester.widgetList<Semantics>(find.byType(Semantics)).firstWhere(
        (s) =>
            s.properties.button == true &&
            s.properties.label == title &&
            s.properties.expanded != null,
        orElse: () => throw StateError('en-tête Semantics introuvable: $title'),
      );
}

void main() {
  testWidgets('AC7 — en-tête accessible : Semantics(button, expanded, label) + '
      'cible ≥ 48 dp', (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    final sem = _headerSemantics(tester, 'Section A');
    expect(sem.properties.button, isTrue);
    expect(sem.properties.expanded, isTrue, reason: 'déplié au départ');
    expect(sem.properties.label, 'Section A');

    // Cible tactile ≥ 48 dp (hauteur de la zone tapable de l'en-tête).
    final headerKey = find.byKey(const ValueKey<String>('section:Section A'));
    expect(headerKey, findsOneWidget);
    expect(tester.getSize(headerKey).height, greaterThanOrEqualTo(48.0));
  });

  testWidgets('AC8 — tap replie/déplie ; tranche PRÉSERVÉE au repli',
      (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    controller.setValue('a0', 'valeur-a0');
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    // Déplié : membres montés.
    expect(_fieldKey('a0'), findsOneWidget);
    expect(_fieldKey('a1'), findsOneWidget);

    // Tap ⇒ repli : membres masqués, mais tranche NON détruite.
    await tester.tap(find.byKey(const ValueKey<String>('section:Section A')));
    await tester.pumpAndSettle();
    expect(_fieldKey('a0'), findsNothing);
    expect(_fieldKey('a1'), findsNothing);
    expect(controller.valueOf('a0'), 'valeur-a0',
        reason: 'repli = masquage visuel, slice conservé (AC8)');
    expect(_headerSemantics(tester, 'Section A').properties.expanded, isFalse);

    // Re-tap ⇒ déplié : membres réaffichés avec valeur.
    await tester.tap(find.byKey(const ValueKey<String>('section:Section A')));
    await tester.pumpAndSettle();
    expect(_fieldKey('a0'), findsOneWidget);
    expect(controller.valueOf('a0'), 'valeur-a0');
  });

  testWidgets('AC8 — état d\'expansion SURVIT à un rebuild structurel',
      (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    // Replie Section A.
    await tester.tap(find.byKey(const ValueKey<String>('section:Section A')));
    await tester.pumpAndSettle();
    expect(_fieldKey('a0'), findsNothing);

    // Déclenche un rebuild STRUCTUREL (change visibleFields côté controller).
    controller.setVisibleFields(const <String>['a0', 'a1', 'b0', 'a0']);
    controller.setVisibleFields(const <String>['a0', 'a1', 'b0']);
    await tester.pumpAndSettle();

    // L'état de repli est conservé (dans le State du parent, pas dans l'en-tête).
    expect(_fieldKey('a0'), findsNothing,
        reason: 'expansion survit au rebuild structurel (AC8)');
    expect(_headerSemantics(tester, 'Section A').properties.expanded, isFalse);
  });

  testWidgets('AC9 — repli n\'altère PAS controller.visibleFields (orthogonal)',
      (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    final before = List<String>.of(controller.visibleFields.value);
    await tester.tap(find.byKey(const ValueKey<String>('section:Section A')));
    await tester.pumpAndSettle();

    expect(controller.visibleFields.value, before,
        reason: 'le repli est un canal de présentation, jamais visibleFields');
    // La section B (non repliable) reste montée indépendamment.
    expect(_fieldKey('b0'), findsOneWidget);
  });

  testWidgets('initiallyExpanded:false ⇒ section repliée au montage',
      (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller, initiallyExpanded: false));
    await tester.pumpAndSettle();

    expect(_fieldKey('a0'), findsNothing);
    expect(_headerSemantics(tester, 'Section A').properties.expanded, isFalse);
  });

  testWidgets('bascule LTR→RTL de l\'accordéon sans exception (AD-13)',
      (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller, textDirection: TextDirection.rtl));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey<String>('section:Section A')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_fieldKey('a0'), findsNothing);
  });
}
