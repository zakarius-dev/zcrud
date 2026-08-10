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

  // AC5 — un numéro international valide est normalisé en forme E.164 (String) ;
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

    // 🔴 v0.75.0 — la tranche du champ téléphone porte désormais une CHAÎNE en
    // forme internationale, plus un objet typé (rupture assumée par le
    // propriétaire ; mesuré : aucun des quatre dépôts hôtes ne lisait l'objet).
    // Cette garde asserte donc l'invariant de la NOUVELLE valeur — et elle le
    // fait sur la forme, pas sur le type seul : une chaîne qui ne commencerait
    // pas par un indicatif serait ininterprétable en persistance.
    await tester.enterText(find.byKey(const Key('z-phone-number')), '+33612345678');
    await tester.pump();
    final valid = controller.valueOf('phone');
    expect(valid, isA<String>());
    expect(valid! as String, matches(RegExp(r'^\+[0-9]+$')),
        reason: 'la valeur persistée doit être une forme internationale close');
    expect(valid as String, contains('+33'));

    // Saisie trop courte : la valeur reste interprétable ou nulle, JAMAIS une
    // chaîne à moitié formée (le paquet rendait `+33` accolé à des caractères
    // non numériques — c'est ce que la canonisation du socle écarte).
    await tester.enterText(find.byKey(const Key('z-phone-number')), '+331');
    await tester.pump();
    final partial = controller.valueOf('phone');
    expect(partial == null || RegExp(r'^\+[0-9]+$').hasMatch(partial as String),
        isTrue,
        reason: 'une saisie partielle ne doit jamais produire une chaîne '
            'ininterprétable');
  });
}
