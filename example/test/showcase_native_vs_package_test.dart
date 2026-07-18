import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_example/demos/showcase/showcase_native_vs_package.dart';
import 'package:zcrud_select/zcrud_select.dart';

import 'support/pump_helpers.dart';

void main() {
  // AC3 — les DEUX voies (natif vs package) coexistent, rendues par leur
  // adaptateur RÉEL ; la seule différence est le SEAM injecté (présentateur /
  // picker), jamais un faux-rendu.
  testWidgets('AC3 — select natif vs modal + color built-in vs roue, côte à côte',
      (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(wrapForTest(const NativeVsPackageSection()));
    await tester.pumpAndSettle();

    // Les 4 emplacements existent.
    for (final k in <String>[
      'nvp-select-native',
      'nvp-select-modal',
      'nvp-color-builtin',
      'nvp-color-wheel',
    ]) {
      expect(find.byKey(ValueKey<String>(k)), findsOneWidget, reason: '$k absent');
    }

    // select : les deux voies rendues par le MÊME adaptateur réel ZSelectFieldWidget.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('nvp-select-native')),
        matching: find.byType(ZSelectFieldWidget),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('nvp-select-modal')),
        matching: find.byType(ZSelectFieldWidget),
      ),
      findsOneWidget,
    );

    // color : les deux voies rendues par le MÊME adaptateur réel ZColorFieldWidget.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('nvp-color-builtin')),
        matching: find.byType(ZColorFieldWidget),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('nvp-color-wheel')),
        matching: find.byType(ZColorFieldWidget),
      ),
      findsOneWidget,
    );

    // Preuve de la BASCULE par seam (falsifiable) : le scope MODAL porte un
    // ZSmartSelectPresenter ; le scope NATIF n'en porte AUCUN.
    ZcrudScope scopeUnder(String key) => tester.widget<ZcrudScope>(
          find
              .descendant(
                of: find.byKey(ValueKey<String>(key)),
                matching: find.byType(ZcrudScope),
              )
              .first,
        );
    expect(scopeUnder('nvp-select-modal').selectPresenter,
        isA<ZSmartSelectPresenter>());
    expect(scopeUnder('nvp-select-native').selectPresenter, isNull);

    // Idem couleur : le scope ROUE porte un colorPicker seam ; le built-in non.
    expect(scopeUnder('nvp-color-wheel').colorPicker, isNotNull);
    expect(scopeUnder('nvp-color-builtin').colorPicker, isNull);
  });
}
