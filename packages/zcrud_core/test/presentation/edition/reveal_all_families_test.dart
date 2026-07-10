// E3-6 — Révélation d'erreur pour TOUTES les familles (AC2 / report a, MEDIUM-1
// E3-5) : à l'échec de validation agrégée, les familles NON-texte (select/date/
// tags) affichent aussi leur message, sans Form global.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const List<ZFieldChoice> _choices = <ZFieldChoice>[
  ZFieldChoice(value: 'a', label: 'A'),
  ZFieldChoice(value: 'b', label: 'B'),
];

void main() {
  testWidgets('AC2 — select/date/tags requis vides ⇒ messages révélés + Form findsNothing',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const fields = <ZFieldSpec>[
      ZFieldSpec(
        name: 'sel',
        type: EditionFieldType.select,
        choices: _choices,
        validators: <ZValidatorSpec>[ZValidatorSpec.required(errorText: 'err-sel')],
      ),
      ZFieldSpec(
        name: 'dt',
        type: EditionFieldType.dateTime,
        validators: <ZValidatorSpec>[ZValidatorSpec.required(errorText: 'err-dt')],
      ),
      ZFieldSpec(
        name: 'tg',
        type: EditionFieldType.tags,
        validators: <ZValidatorSpec>[ZValidatorSpec.required(errorText: 'err-tg')],
      ),
    ];
    final c = ZFormController(
      initialValues: <String, Object?>{'sel': null, 'dt': null, 'tg': null},
      visibleFields: const <String>['sel', 'dt', 'tg'],
    );
    addTearDown(c.dispose);

    var calls = 0;
    final submit = ZEditionSubmitController<Unit>(
      controller: c,
      fields: fields,
      onSubmit: (values) async {
        calls++;
        return Right<ZFailure, Unit>(unit);
      },
    );
    addTearDown(submit.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: DynamicEdition(controller: c, fields: fields)),
    ));
    await tester.pumpAndSettle();

    // Avant soumission : aucun message révélé.
    expect(find.text('err-sel'), findsNothing);

    final outcome = await submit.submit();
    await tester.pump();

    expect(calls, 0);
    expect(outcome.isValidationFailure, isTrue);
    // TOUTES les familles non-texte révèlent leur message.
    expect(find.text('err-sel'), findsOneWidget);
    expect(find.text('err-dt'), findsOneWidget);
    expect(find.text('err-tg'), findsOneWidget);
    // Aucun Form/FormBuilder global (AD-2).
    expect(find.byType(Form), findsNothing);
    // Les messages révélés sont exposés en liveRegion (accessibilité).
    final liveRegions = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .where((s) => s.properties.liveRegion ?? false);
    expect(liveRegions.length, greaterThanOrEqualTo(3));
  });
}
