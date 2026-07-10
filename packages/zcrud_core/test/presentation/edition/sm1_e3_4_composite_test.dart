// AC15 — SM-1 re-prouvé AU NIVEAU FORMULAIRE avec les surfaces d'E3-4 actives :
// ≥ 30 champs / ≥ 3 sections, dont au moins un champ conditionnel, une section
// repliable et une ligne de grille multi-colonnes. Taper 100 caractères ne
// provoque AUCUN build structurel (compteur inchangé) ni perte de focus.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Formulaire composite : 3 sections × 12 champs = 36 (≥ 30). Section 0 est
/// repliable ; la section 1 pose une grille 2 colonnes ; un champ conditionnel
/// `cond` dépend de `f_0_0` (garde).
class _CompositeForm {
  final Map<String, int> fieldBuilds = <String, int>{};
  int formBuilds = 0;

  static const int perSection = 12;
  static const List<String> titles = <String>['S0', 'S1', 'S2'];

  static String fname(int s, int i) => 'f_${s}_$i';

  late final List<ZFieldSpec> fields = <ZFieldSpec>[
    for (var s = 0; s < titles.length; s++)
      for (var i = 0; i < perSection; i++)
        ZFieldSpec(
          name: fname(s, i),
          type: EditionFieldType.text,
          label: 'Champ $s.$i',
        ),
    // Champ conditionnel supplémentaire (garde = f_0_0).
    const ZFieldSpec(
      name: 'cond',
      type: EditionFieldType.text,
      label: 'Conditionnel',
      condition: ZCondition.truthy('f_0_0'),
    ),
  ];

  late final List<ZEditionSection> sections = <ZEditionSection>[
    ZEditionSection(
      title: titles[0],
      collapsible: true,
      fields: <String>[for (var i = 0; i < perSection; i++) fname(0, i)],
    ),
    ZEditionSection(
      title: titles[1],
      fields: <String>[
        for (var i = 0; i < perSection; i++) fname(1, i),
        'cond',
      ],
    ),
    ZEditionSection(
      title: titles[2],
      fields: <String>[for (var i = 0; i < perSection; i++) fname(2, i)],
    ),
  ];

  // Grille : les 2 premiers champs de S1 en demi-largeur (span 6).
  final Map<String, ZResponsiveSpan> layout = const <String, ZResponsiveSpan>{
    'f_1_0': ZResponsiveSpan.all(6),
    'f_1_1': ZResponsiveSpan.all(6),
  };

  late final ZFormController controller = ZFormController(
    initialValues: <String, Object?>{
      for (final f in fields) f.name: '',
    },
    visibleFields: <String>[for (final f in fields) f.name],
  );

  int get fieldCount => fields.length;

  Widget build() => MaterialApp(
        home: Scaffold(
          body: DynamicEdition(
            controller: controller,
            fields: fields,
            sections: sections,
            layout: layout,
            onStructuralBuild: () => formBuilds++,
            fieldBuilder: (context, ctrl, field) => ZFieldWidget(
              controller: ctrl,
              field: field,
              onBuild: () =>
                  fieldBuilds[field.name] = (fieldBuilds[field.name] ?? 0) + 1,
            ),
          ),
        ),
      );

  void dispose() => controller.dispose();
}

void main() {
  testWidgets(
      'AC15 — SM-1 composite (conditionnel + repliable + grille) : 100 frappes '
      '⇒ 0 build structurel, focus + curseur préservés', (tester) async {
    tester.view.physicalSize = const Size(1000, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final form = _CompositeForm();
    addTearDown(form.dispose);

    expect(form.fieldCount, greaterThanOrEqualTo(30));
    expect(form.sections.length, greaterThanOrEqualTo(3));

    await tester.pumpWidget(form.build());
    await tester.pumpAndSettle();

    // Cible : un champ de la section grille (S1), au milieu.
    const target = 'f_1_5';
    final targetEditable = find.descendant(
      of: find.byKey(const ValueKey<String>(target)),
      matching: find.byType(EditableText),
    );
    expect(targetEditable, findsOneWidget);

    final baseForm = form.formBuilds;
    final baseTarget = form.fieldBuilds[target]!;
    final base = Map<String, int>.from(form.fieldBuilds);

    await tester.tap(targetEditable);
    await tester.pump();
    expect(tester.widget<EditableText>(targetEditable).focusNode.hasFocus,
        isTrue);

    const total = 100;
    final buffer = StringBuffer();
    for (var i = 1; i <= total; i++) {
      buffer.write(String.fromCharCode(97 + (i % 26)));
      await tester.enterText(targetEditable, buffer.toString());
      await tester.pump();
      expect(tester.widget<EditableText>(targetEditable).focusNode.hasFocus,
          isTrue,
          reason: 'focus conservé à la frappe $i');
    }

    // (1) 0 build structurel pendant la saisie (SM-1).
    expect(form.formBuilds, baseForm,
        reason: 'aucun rebuild structurel sur une frappe (champ non-garde)');

    // (2) Le champ cible reconstruit ~1 par frappe ; les voisins montés, jamais.
    expect(form.fieldBuilds[target], baseTarget + total);
    for (final e in base.entries) {
      if (e.key == target) continue;
      expect(form.fieldBuilds[e.key], e.value,
          reason: 'voisin ${e.key} ne reconstruit pas');
    }

    // (3) Curseur en fin, valeur propagée.
    final ed = tester.widget<EditableText>(targetEditable);
    expect(ed.controller.text, buffer.toString());
    expect(ed.controller.selection.baseOffset, total);
    expect(form.controller.valueOf(target), buffer.toString());
  });
}
