import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_example/binding/binding_selector.dart';
import 'package:zcrud_example/demos/demo_registry.dart';
import 'package:zcrud_example/demos/intl_demo_screen.dart';
import 'package:zcrud_intl/zcrud_intl.dart';

import 'support/pump_helpers.dart';

void main() {
  // AC8 — le registre peuplé contient les 5 kinds géo/intl.
  test('AC8 — demoWidgetRegistry contient les 5 kinds', () {
    final registry = buildDemoWidgetRegistry();
    for (final kind in <String>[
      'location',
      'geoArea',
      'phoneNumber',
      'country',
      'address',
    ]) {
      expect(registry.isRegistered(kind), isTrue, reason: '$kind attendu');
    }
    expect(registry.kinds.length, 5);
  });

  // AC10 — parité multi-binding : un écran registre-servi (Intl) rend les champs
  // à l'identique sous ≥ 2 wraps (défaut + un binding) grâce à la re-propagation
  // de root.widgetRegistry par _BindingSeamForwarder. Aucun ZUnsupportedFieldWidget.
  for (final binding in <DemoBinding>[DemoBinding.scope, DemoBinding.riverpod]) {
    testWidgets('AC10 — Intl : parité de rendu sous ${binding.label}',
        (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        wrapForTestWithRegistry(
          IntlDemoScreen(initialBinding: binding),
          registry: buildDemoWidgetRegistry(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ZPhoneFieldWidget), findsOneWidget);
      expect(find.byType(ZCountryFieldWidget), findsOneWidget);
      expect(find.byType(ZAddressFieldWidget), findsOneWidget);
      expect(find.byType(ZUnsupportedFieldWidget), findsNothing);
    });
  }
}
