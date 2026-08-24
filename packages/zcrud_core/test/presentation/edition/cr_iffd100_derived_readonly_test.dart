// CR-IFFD-100 — lecture seule CONDITIONNELLE : cinquième cible `readOnly` de
// `ZDerivation` (cohérente avec `visible`), propagée comme le `readOnly`
// statique — toutes familles, champs servis par le registre compris.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

ZFieldSpec _derived(String name, EditionFieldType type, {bool statik = false}) =>
    ZFieldSpec(
      name: name,
      type: type,
      readOnly: statik,
      derivedFrom: ZDerivation(
        sources: const ['mode'],
        overwrite: ZDerivationOverwrite.always,
        readOnly: (v) => v['mode'] == 'locked',
      ),
    );

void main() {
  testWidgets('🔴 la cible `readOnly` bascule le champ TEXTE au changement de '
      'la source — et lui seul', (tester) async {
    final c = ZFormController();
    final fields = <ZFieldSpec>[
      const ZFieldSpec(name: 'mode', type: EditionFieldType.text),
      _derived('nom', EditionFieldType.text),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: DynamicEdition(controller: c, fields: fields)),
    ));
    await tester.pump();
    TextField nameField() => tester.widgetList<TextField>(find.byType(TextField)).last;
    expect(nameField().readOnly, isFalse);

    c.setValue('mode', 'locked');
    await tester.pump();
    expect(nameField().readOnly, isTrue,
        reason: 'mode == locked ⇒ le champ dérivé passe en lecture seule');
    expect(tester.widgetList<TextField>(find.byType(TextField)).first.readOnly,
        isFalse, reason: 'le champ source, lui, reste éditable');

    c.setValue('mode', 'libre');
    await tester.pump();
    expect(nameField().readOnly, isFalse,
        reason: 'la condition retombée, le champ redevient éditable');
    c.dispose();
  });

  testWidgets('🔴 propagation au champ WIDGET (registre) : le builder reçoit '
      'la spec effective `readOnly: true`', (tester) async {
    final c = ZFormController();
    bool? seenReadOnly;
    final registry = ZWidgetRegistry()
      ..register('widget', (context, ctx) {
        seenReadOnly = ctx.field.readOnly;
        return const SizedBox(height: 10);
      });
    final fields = <ZFieldSpec>[
      const ZFieldSpec(name: 'mode', type: EditionFieldType.text),
      _derived('gadget', EditionFieldType.widget),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ZcrudScope(
          widgetRegistry: registry,
          child: DynamicEdition(controller: c, fields: fields),
        ),
      ),
    ));
    await tester.pump();
    expect(seenReadOnly, isFalse);
    c.setValue('mode', 'locked');
    await tester.pump();
    expect(seenReadOnly, isTrue,
        reason: 'le champ servi par le registre doit recevoir la spec '
            'effective, comme pour le readOnly statique');
    c.dispose();
  });

  testWidgets('le `readOnly` STATIQUE prime : un dérivé à false ne rend pas '
      'éditable un champ déclaré readOnly', (tester) async {
    final c = ZFormController();
    final fields = <ZFieldSpec>[
      const ZFieldSpec(name: 'mode', type: EditionFieldType.text),
      _derived('fige', EditionFieldType.text, statik: true),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: DynamicEdition(controller: c, fields: fields)),
    ));
    await tester.pump();
    expect(
      tester.widgetList<TextField>(find.byType(TextField)).last.readOnly,
      isTrue,
      reason: 'readOnly statique jamais annulé par la dérivation',
    );
    c.dispose();
  });
}
