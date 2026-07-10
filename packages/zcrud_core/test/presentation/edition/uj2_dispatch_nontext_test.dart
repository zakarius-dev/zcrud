// AC9 — UJ-2 à travers le dispatcher : un rebuild d'ancêtre (nouvelle instance
// DynamicEdition) NE recrée PAS l'état des champs (KeyedSubtree/ValueKey) —
// saisie partielle préservée + focus conservé, pour AU MOINS un champ texte ET
// un champ non-texte (booléen + select), tous montés via le dispatcher.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _fields = <ZFieldSpec>[
  ZFieldSpec(name: 't', type: EditionFieldType.text, label: 'Texte'),
  ZFieldSpec(name: 'b', type: EditionFieldType.boolean, label: 'Actif'),
  ZFieldSpec(
    name: 's',
    type: EditionFieldType.select,
    label: 'Choix',
    choices: <ZFieldChoice>[
      ZFieldChoice(value: 'a', label: 'A'),
      ZFieldChoice(value: 'x', label: 'X'),
    ],
  ),
];

void main() {
  testWidgets('rebuild ancêtre → état texte + non-texte préservé (AC9)',
      (tester) async {
    final controller = ZFormController(
      initialValues: const <String, Object?>{'t': '', 'b': false, 's': null},
      visibleFields: const <String>['t', 'b', 's'],
    );
    addTearDown(controller.dispose);

    final banner = ValueNotifier<bool>(true);
    addTearDown(banner.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: banner,
            builder: (context, online, _) => Column(
              children: <Widget>[
                Text(online ? 'ON' : 'OFF'),
                // Nouvelle instance de DynamicEdition à chaque bascule.
                Expanded(
                  child: DynamicEdition(controller: controller, fields: _fields),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Saisie partielle dans le champ texte (focus actif).
    final tEditable = find.descendant(
      of: find.byKey(const ValueKey<String>('t')),
      matching: find.byType(EditableText),
    );
    await tester.tap(tEditable);
    await tester.pump();
    await tester.enterText(tEditable, 'PARTIEL');
    await tester.pump();
    expect(tester.widget<EditableText>(tEditable).focusNode.hasFocus, isTrue);

    // Édition non-texte : toggle booléen + sélection.
    controller.setValue('b', true);
    controller.setValue('s', 'a');
    await tester.pump();
    expect(find.byType(ZBooleanFieldWidget), findsOneWidget);

    // ── BASCULE EXTERNE : nouvelle instance DynamicEdition ────────────────────
    banner.value = false;
    await tester.pump();
    expect(find.text('OFF'), findsOneWidget);

    // Texte : saisie + focus préservés (State réutilisé).
    final tCtrl = tester.widget<EditableText>(tEditable).controller;
    expect(tCtrl.text, 'PARTIEL');
    expect(tester.widget<EditableText>(tEditable).focusNode.hasFocus, isTrue);

    // Non-texte : valeurs préservées (tranche stable, lues par le widget).
    expect(controller.valueOf('b'), true);
    expect(controller.valueOf('s'), 'a');
    final switchTile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(switchTile.value, true, reason: 'le booléen reflète toujours true');
  });
}
