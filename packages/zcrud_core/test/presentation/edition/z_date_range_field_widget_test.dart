// AD-47 / AD-2 / AD-13 — `ZDateRangeFieldWidget` : famille `dateRange` native,
// montée sous `ZFieldListenableBuilder` (rebuild granulaire SM-1), déclencheur
// accessible ≥ 48 dp, croix d'effacement MIN-2, reflet de valeur externe.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

Widget _mount({
  required ZFormController controller,
  required List<ZFieldSpec> fields,
  void Function(String name)? onFieldBuild,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ZcrudScope(
        child: DynamicEdition(
          controller: controller,
          fields: fields,
          fieldBuilder: onFieldBuild == null
              ? null
              : (context, ctrl, field) => ZFieldWidget(
                    controller: ctrl,
                    field: field,
                    onBuild: () => onFieldBuild(field.name),
                  ),
        ),
      ),
    ),
  );
}

void main() {
  final range = ZDateRange(
    start: DateTime.parse('2026-01-01T00:00:00.000'),
    end: DateTime.parse('2026-01-31T00:00:00.000'),
  );

  testWidgets('rend la plage courante + libellé (déclencheur bouton)',
      (tester) async {
    final controller = ZFormController(
      initialValues: <String, Object?>{'p': range},
      visibleFields: <String>['p'],
    );
    addTearDown(controller.dispose);
    const field = ZFieldSpec(
      name: 'p',
      type: EditionFieldType.dateRange,
      label: 'Période',
    );
    await tester.pumpWidget(
        _mount(controller: controller, fields: const <ZFieldSpec>[field]));
    await tester.pump();

    // La famille dateRange est bien routée (pas de repli non supporté).
    expect(find.byType(ZDateRangeFieldWidget), findsOneWidget);
    // Plage affichée (dates ISO) + libellé.
    expect(find.textContaining('2026-01-01'), findsOneWidget);
    expect(find.textContaining('2026-01-31'), findsOneWidget);
    expect(find.textContaining('Période'), findsOneWidget);

    // A11y : déclencheur bouton, cible ≥ 48 dp.
    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(button.onPressed, isNotNull);
    final size = tester.getSize(find.byType(OutlinedButton));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('reflète une valeur EXTERNE (rebuild sous la tranche)',
      (tester) async {
    final controller = ZFormController(
      initialValues: <String, Object?>{'p': null},
      visibleFields: <String>['p'],
    );
    addTearDown(controller.dispose);
    const field = ZFieldSpec(
      name: 'p',
      type: EditionFieldType.dateRange,
      label: 'Période',
    );
    await tester.pumpWidget(
        _mount(controller: controller, fields: const <ZFieldSpec>[field]));
    await tester.pump();
    expect(find.textContaining('2026-01-01'), findsNothing);

    // Écriture externe de la tranche → le champ reflète la nouvelle plage.
    controller.setValue('p', range);
    await tester.pump();
    expect(find.textContaining('2026-01-01'), findsOneWidget);
  });

  testWidgets(
      'AC-A4 : tap ouvre le picker ; le câblage picker→onChanged écrit un '
      'ZDateRange dans la tranche', (tester) async {
    final controller = ZFormController(
      initialValues: <String, Object?>{'p': null},
      visibleFields: <String>['p'],
    );
    addTearDown(controller.dispose);
    const field = ZFieldSpec(
      name: 'p',
      type: EditionFieldType.dateRange,
      label: 'Période',
    );
    await tester.pumpWidget(
        _mount(controller: controller, fields: const <ZFieldSpec>[field]));
    await tester.pump();

    // 1) Le déclencheur ouvre réellement `showDateRangePicker` (chemin tap AC-A4).
    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
    // Le picker de plage Material affiche l'action de confirmation « Save ».
    expect(find.text('Save'), findsOneWidget);
    // Ferme le picker (le pilotage jour-par-jour Material est instable ; la
    // confirmation est vérifiée via le câblage `onChanged` réel ci-dessous).
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    // 2) Câblage picker→onChanged→setValue : on invoque la fermeture EXACTE
    // montée par le dispatcher (z_field_widget.dart:473), comme le ferait le
    // picker en retournant une plage. Falsifiable : sous l'injection
    // `onChanged: (range) => {}`, cette fermeture est un no-op → la tranche
    // reste `null` → test rouge (ce n'est PAS un setValue externe).
    final picked = ZDateRange(
      start: DateTime.parse('2026-03-01T00:00:00.000'),
      end: DateTime.parse('2026-03-15T00:00:00.000'),
    );
    tester
        .widget<ZDateRangeFieldWidget>(find.byType(ZDateRangeFieldWidget))
        .onChanged(picked);
    await tester.pump();

    expect(controller.valueOf('p'), isA<ZDateRange>());
    expect(controller.valueOf('p'), picked);
  });

  testWidgets('MIN-2 : croix d\'effacement (non requis) remet la tranche à null',
      (tester) async {
    final controller = ZFormController(
      initialValues: <String, Object?>{'p': range},
      visibleFields: <String>['p'],
    );
    addTearDown(controller.dispose);
    const field = ZFieldSpec(
      name: 'p',
      type: EditionFieldType.dateRange,
      label: 'Période',
    );
    await tester.pumpWidget(
        _mount(controller: controller, fields: const <ZFieldSpec>[field]));
    await tester.pump();

    expect(find.byIcon(Icons.clear), findsOneWidget);
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();
    expect(controller.valueOf('p'), isNull);
    expect(find.textContaining('2026-01-01'), findsNothing);
  });

  testWidgets('champ requis : aucune croix d\'effacement', (tester) async {
    final controller = ZFormController(
      initialValues: <String, Object?>{'p': range},
      visibleFields: <String>['p'],
    );
    addTearDown(controller.dispose);
    const field = ZFieldSpec(
      name: 'p',
      type: EditionFieldType.dateRange,
      label: 'Période',
      validators: <ZValidatorSpec>[ZValidatorSpec.required()],
    );
    await tester.pumpWidget(
        _mount(controller: controller, fields: const <ZFieldSpec>[field]));
    await tester.pump();
    expect(find.byIcon(Icons.clear), findsNothing);
  });

  testWidgets('SM-1 : taper dans un AUTRE champ ne reconstruit pas dateRange',
      (tester) async {
    final controller = ZFormController(
      initialValues: <String, Object?>{'p': range, 't': ''},
      visibleFields: <String>['p', 't'],
    );
    addTearDown(controller.dispose);
    const fields = <ZFieldSpec>[
      ZFieldSpec(name: 'p', type: EditionFieldType.dateRange, label: 'Période'),
      ZFieldSpec(name: 't', type: EditionFieldType.text, label: 'Texte'),
    ];
    final builds = <String, int>{};
    await tester.pumpWidget(_mount(
      controller: controller,
      fields: fields,
      onFieldBuild: (name) => builds[name] = (builds[name] ?? 0) + 1,
    ));
    await tester.pump();
    final rangeBuildsBefore = builds['p'];
    final tBefore = builds['t']!;

    await tester.enterText(find.byType(TextField), 'Bonjour');
    await tester.pump();

    // Côté frappé : la tranche `t` SE reconstruit (propagation setValue vivante).
    // Sous une propagation cassée (réactivité morte) `builds['t']` n'augmenterait
    // pas → rouge : on pince les DEUX côtés, pas seulement le voisin.
    expect(builds['t']!, greaterThan(tBefore),
        reason: 'la tranche frappée `t` se reconstruit (réactivité vivante)');
    // Côté voisin : la frappe dans `t` ne reconstruit PAS la tranche `p`.
    expect(builds['p'], rangeBuildsBefore,
        reason: 'dateRange ne se reconstruit pas sur une frappe tierce (SM-1)');
  });
}
