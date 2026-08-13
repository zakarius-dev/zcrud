// E3-5 AC12 — Navigation accessible & directionnelle (AD-13).
//   - `Semantics` explicites sur Précédent/Suivant + indicateur ;
//   - cibles tactiles ≥ 48 dp ;
//   - bascule LTR↔RTL sans overflow/exception (Row respecte la Directionality :
//     l'ordre visuel Précédent/Suivant suit le sens de lecture).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

class _NavForm {
  final List<ZFieldSpec> fields = const <ZFieldSpec>[
    ZFieldSpec(name: 'a', type: EditionFieldType.text, label: 'A'),
    ZFieldSpec(name: 'b', type: EditionFieldType.text, label: 'B'),
  ];
  final List<ZEditionStep> steps = const <ZEditionStep>[
    ZEditionStep(title: 'Étape A', fields: <String>['a']),
    ZEditionStep(title: 'Étape B', fields: <String>['b']),
  ];

  late final ZFormController controller = ZFormController(
    initialValues: const <String, Object?>{'a': '', 'b': ''},
    visibleFields: const <String>['a', 'b'],
  );

  Widget build(TextDirection dir) => MaterialApp(
        home: Directionality(
          textDirection: dir,
          child: Scaffold(
            body: ZStepperEdition(
              controller: controller,
              fields: fields,
              steps: steps,
              onComplete: () {},
            ),
          ),
        ),
      );

  void dispose() => controller.dispose();
}

void main() {
  testWidgets('AC12 — Semantics explicites + cibles ≥ 48 dp sur la navigation',
      (tester) async {
    final form = _NavForm();
    addTearDown(form.dispose);
    await tester.pumpWidget(form.build(TextDirection.ltr));
    await tester.pumpAndSettle();

    // Semantics de bouton labellés Précédent/Suivant + indicateur d'étape.
    expect(find.bySemanticsLabel('Previous'), findsOneWidget);
    expect(find.bySemanticsLabel('Next'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Étape 1 sur 2')), findsOneWidget);

    // Cibles tactiles ≥ 48 dp (contrainte de hauteur minimale).
    final nextSize = tester.getSize(find.widgetWithText(FilledButton, 'Next'));
    final prevSize =
        tester.getSize(find.widgetWithText(OutlinedButton, 'Previous'));
    expect(nextSize.height, greaterThanOrEqualTo(48));
    expect(prevSize.height, greaterThanOrEqualTo(48));
  });

  testWidgets('AC12 — Précédent désactivé à l\'étape 0, activé après avance',
      (tester) async {
    final form = _NavForm();
    addTearDown(form.dispose);
    await tester.pumpWidget(form.build(TextDirection.ltr));
    await tester.pumpAndSettle();

    // Étape 0 : Précédent désactivé (onPressed == null).
    expect(
        tester.widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Previous')).onPressed,
        isNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();

    // Étape 1 : Précédent activé.
    expect(
        tester.widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Previous')).onPressed,
        isNotNull);
  });

  testWidgets('AC12 — bascule LTR↔RTL sans overflow ni exception ; ordre visuel '
      'suit le sens de lecture', (tester) async {
    final form = _NavForm();
    addTearDown(form.dispose);

    // LTR : Précédent à gauche de Suivant.
    await tester.pumpWidget(form.build(TextDirection.ltr));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final prevLtr =
        tester.getCenter(find.widgetWithText(OutlinedButton, 'Previous')).dx;
    final nextLtr =
        tester.getCenter(find.widgetWithText(FilledButton, 'Next')).dx;
    expect(prevLtr < nextLtr, isTrue, reason: 'LTR : Précédent avant Suivant');

    // RTL : l'ordre visuel s'inverse (Row respecte la Directionality).
    await tester.pumpWidget(form.build(TextDirection.rtl));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final prevRtl =
        tester.getCenter(find.widgetWithText(OutlinedButton, 'Previous')).dx;
    final nextRtl =
        tester.getCenter(find.widgetWithText(FilledButton, 'Next')).dx;
    expect(prevRtl > nextRtl, isTrue, reason: 'RTL : Précédent après Suivant');
  });
}
