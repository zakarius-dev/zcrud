import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_example/binding/binding_selector.dart';
import 'package:zcrud_example/demos/demo_registry.dart';
import 'package:zcrud_example/demos/geo_demo_screen.dart';
import 'package:zcrud_geo/zcrud_geo.dart';

import 'support/pump_helpers.dart';

void main() {
  // AC4 — les champs location/geoArea sont résolus par le registre racine (pas
  // de ZUnsupportedFieldWidget) ; carte OSM rendue via l'adaptateur.
  testWidgets('AC4 — Geo : location + geoArea servis par le registre',
      (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      wrapForTestWithRegistry(
        const GeoDemoScreen(),
        registry: buildDemoWidgetRegistry(),
      ),
    );
    // FlutterMap charge des tuiles réseau : on `pump` sans `settle` (les tuiles
    // ne se résolvent jamais en test → `pumpAndSettle` boucle).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(GeoDemoScreen), findsOneWidget);
    // location + geoArea → 2 ZGeoFieldWidget, aucun champ non supporté.
    expect(find.byType(ZGeoFieldWidget), findsNWidgets(2));
    expect(find.byType(ZUnsupportedFieldWidget), findsNothing);
  });

  // AC4 — fixer un point via le champ registre-servi met à jour la valeur NEUTRE
  // de tranche (ZGeoPoint), sans type SDK carte.
  testWidgets('AC4 — location : saisir lat/lng produit un ZGeoPoint neutre',
      (tester) async {
    useTallSurface(tester);
    final controller =
        ZFormController(initialValues: const <String, Object?>{'position': null});
    addTearDown(controller.dispose);
    const fields = <ZFieldSpec>[
      ZFieldSpec(
        name: 'position',
        type: EditionFieldType.location,
        label: 'Position',
      ),
    ];

    await tester.pumpWidget(
      wrapForTestWithRegistry(
        DynamicEdition(controller: controller, fields: fields),
        registry: buildDemoWidgetRegistry(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(2)); // lat + lng
    await tester.enterText(textFields.first, '5.5');
    await tester.enterText(textFields.at(1), '6.6');
    await tester.pump();

    final value = controller.valueOf('position');
    expect(value, isA<ZGeoPoint>());
    expect((value! as ZGeoPoint).lat, 5.5);
    expect((value as ZGeoPoint).lng, 6.6);
  });

  // AC10 (Finding LOW-3) — parité multi-binding OBSERVÉE sur l'écran Geo (en plus
  // d'Intl) : les champs location/geoArea sont servis À L'IDENTIQUE sous ≥ 2 wraps
  // (défaut + un binding) grâce à la re-propagation de `root.widgetRegistry` par
  // `_BindingSeamForwarder`. Aucun ZUnsupportedFieldWidget sous aucun wrap.
  for (final binding in <DemoBinding>[DemoBinding.scope, DemoBinding.riverpod]) {
    testWidgets('AC10 — Geo : parité de rendu sous ${binding.label}',
        (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        wrapForTestWithRegistry(
          GeoDemoScreen(initialBinding: binding),
          registry: buildDemoWidgetRegistry(),
        ),
      );
      // FlutterMap charge des tuiles réseau : `pump` sans `settle`.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(ZGeoFieldWidget), findsNWidgets(2));
      expect(find.byType(ZUnsupportedFieldWidget), findsNothing);
    });
  }
}
