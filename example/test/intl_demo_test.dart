import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_example/demos/demo_registry.dart';
import 'package:zcrud_example/demos/intl_demo_screen.dart';
import 'package:zcrud_intl/zcrud_intl.dart';

import 'support/pump_helpers.dart';

void main() {
  // AC5 — l'écran Intl monte téléphone/pays/adresse servis par le registre.
  testWidgets('AC5 — Intl : phone/country/address servis par le registre',
      (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      wrapForTestWithRegistry(
        const IntlDemoScreen(),
        registry: buildDemoWidgetRegistry(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(IntlDemoScreen), findsOneWidget);
    expect(find.byType(ZPhoneFieldWidget), findsOneWidget);
    expect(find.byType(ZCountryFieldWidget), findsOneWidget);
    expect(find.byType(ZAddressFieldWidget), findsOneWidget);
    expect(find.byType(ZUnsupportedFieldWidget), findsNothing);
  });

  // AC5 — un numéro international valide est normalisé en E.164 (ZPhoneNumber) ;
  // un numéro invalide n'a PAS d'E.164.
  testWidgets('AC5 — téléphone : valide → E.164 ; invalide → sans E.164',
      (tester) async {
    useTallSurface(tester);
    final controller =
        ZFormController(initialValues: const <String, Object?>{'phone': null});
    addTearDown(controller.dispose);
    const fields = <ZFieldSpec>[
      ZFieldSpec(
        name: 'phone',
        type: EditionFieldType.phoneNumber,
        label: 'Téléphone',
      ),
    ];

    await tester.pumpWidget(
      wrapForTestWithRegistry(
        DynamicEdition(controller: controller, fields: fields),
        registry: buildDemoWidgetRegistry(),
      ),
    );
    await tester.pumpAndSettle();

    // Numéro international complet et VALIDE (France mobile) → E.164 renseigné.
    await tester.enterText(find.byKey(const Key('z-phone-number')), '+33612345678');
    await tester.pump();
    final valid = controller.valueOf('phone');
    expect(valid, isA<ZPhoneNumber>());
    expect((valid! as ZPhoneNumber).e164, isNotNull);
    expect((valid as ZPhoneNumber).e164, contains('+33'));

    // Numéro trop court → INVALIDE → pas d'E.164 (modèle « brut »).
    await tester.enterText(find.byKey(const Key('z-phone-number')), '+331');
    await tester.pump();
    final invalid = controller.valueOf('phone');
    expect((invalid! as ZPhoneNumber).e164, isNull);
  });
}
