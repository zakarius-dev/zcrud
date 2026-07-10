// AC5/AC7/AC8/AC9/AC10 — ZStateField : sélecteur dépendant du pays → tranche =
// code ISO 3166-2 ; repli texte libre si aucune subdivision ; défensif ; SM-1 ;
// anti-fuite ; thème/RTL/a11y opérable (helpers AI-E10-1).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_intl/zcrud_intl.dart';

import 'support/a11y_asserts.dart';

ZSubdivisionCatalog _fake() =>
    ZSubdivisionCatalog.fromMap(<String, List<ZSubdivision>>{
      'NE': const <ZSubdivision>[
        ZSubdivision(code: 'NE-2', countryIso: 'NE', name: 'Diffa'),
        ZSubdivision(code: 'NE-8', countryIso: 'NE', name: 'Niamey'),
      ],
      'US': const <ZSubdivision>[
        ZSubdivision(code: 'US-CA', countryIso: 'US', name: 'California'),
      ],
    });

ZFieldSpec _field({ZFieldConfig? config}) => ZFieldSpec(
    name: 'state', type: EditionFieldType.text, label: 'État', config: config);

Widget _host(
  ZSubdivisionCatalog cat, {
  String? countryIso,
  Object? value,
  ZFieldConfig? config,
  required ValueChanged<Object?> onChanged,
  TextDirection dir = TextDirection.ltr,
  VoidCallback? onInit,
}) =>
    MaterialApp(
      home: Directionality(
        textDirection: dir,
        child: ZcrudScope(
          child: Scaffold(
            body: ZStateField(
              ctx: ZFieldWidgetContext(
                field: _field(config: config),
                value: value,
                onChanged: onChanged,
              ),
              catalog: cat,
              countryIso: countryIso,
              onInit: onInit,
            ),
          ),
        ),
      ),
    );

void main() {
  group('AC5 — sélecteur dépendant du pays', () {
    testWidgets('pays avec subdivisions → sélection écrit le code ISO 3166-2',
        (t) async {
      Object? slice;
      await t.pumpWidget(_host(_fake(), countryIso: 'NE', onChanged: (v) => slice = v));
      await t.pump();
      await t.tap(find.byKey(const Key('z-state-trigger')));
      await t.pump();
      expect(find.byKey(const Key('z-state-item-NE-2')), findsOneWidget);
      expect(find.byKey(const Key('z-state-item-NE-8')), findsOneWidget);
      await t.tap(find.byKey(const Key('z-state-item-NE-2')));
      await t.pump();
      expect(slice, 'NE-2');
    });

    testWidgets('pays via config.defaultCountryIso', (t) async {
      await t.pumpWidget(_host(_fake(),
          config: const ZIntlFieldConfig(defaultCountryIso: 'US'),
          onChanged: (_) {}));
      await t.pump();
      await t.tap(find.byKey(const Key('z-state-trigger')));
      await t.pump();
      expect(find.byKey(const Key('z-state-item-US-CA')), findsOneWidget);
    });

    testWidgets('pays sans subdivision "ZZ" → repli texte libre', (t) async {
      Object? slice;
      await t.pumpWidget(
          _host(_fake(), countryIso: 'ZZ', onChanged: (v) => slice = v));
      await t.pump();
      expect(find.byKey(const Key('z-state-free')), findsOneWidget);
      expect(find.byKey(const Key('z-state-trigger')), findsNothing);
      await t.enterText(find.byKey(const Key('z-state-free')), 'Ma région');
      await t.pump();
      expect(slice, 'Ma région');
    });

    testWidgets('aucun pays → repli texte libre (returnsNormally)', (t) async {
      await t.pumpWidget(_host(_fake(), onChanged: (_) {}));
      await t.pump();
      expect(find.byKey(const Key('z-state-free')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('builder() renvoie un ZFieldWidgetBuilder', (t) async {
      expect(ZStateField.builder(catalog: _fake(), countryIso: 'NE'),
          isA<ZFieldWidgetBuilder>());
    });
  });

  group('AC7 — défensif', () {
    testWidgets('valeur non-String → pas de crash', (t) async {
      await t.pumpWidget(_host(_fake(),
          countryIso: 'NE', value: 42, onChanged: (_) {}));
      await t.pump();
      expect(t.takeException(), isNull);
      expect(find.byType(ZStateField), findsOneWidget);
    });

    testWidgets('code "ZZ-99" inconnu → pas de crash (aucune sélection)',
        (t) async {
      await t.pumpWidget(_host(_fake(),
          countryIso: 'NE', value: 'ZZ-99', onChanged: (_) {}));
      await t.pump();
      expect(t.takeException(), isNull);
    });
  });

  group('AC8 — SM-1 : repli texte, contrôleur non recréé + focus', () {
    testWidgets('frappe → initState==1, focus conservé', (t) async {
      var init = 0;
      await t.pumpWidget(_host(_fake(),
          countryIso: 'ZZ', onChanged: (_) {}, onInit: () => init++));
      await t.pump();
      final free = find.byKey(const Key('z-state-free'));
      await t.tap(free);
      await t.pump();
      await t.enterText(free, 'A');
      await t.pump();
      await t.enterText(free, 'Ab');
      await t.pump();
      expect(init, 1);
      expect(t.widget<TextField>(free).focusNode!.hasFocus, isTrue);
    });
  });

  group('AC9 — anti-fuite', () {
    testWidgets('démontage après frappe → aucune exception', (t) async {
      await t.pumpWidget(_host(_fake(), countryIso: 'ZZ', onChanged: (_) {}));
      await t.pump();
      await t.enterText(find.byKey(const Key('z-state-free')), 'X');
      await t.pump();
      await t.pumpWidget(const SizedBox());
      expect(t.takeException(), isNull);
    });
  });

  group('AC10 — thème/RTL/a11y opérable', () {
    testWidgets('rendu RTL (sélecteur + repli) sans exception', (t) async {
      await t.pumpWidget(_host(_fake(),
          countryIso: 'NE', onChanged: (_) {}, dir: TextDirection.rtl));
      await t.pump();
      expect(t.takeException(), isNull);
      await t.pumpWidget(_host(_fake(),
          countryIso: 'ZZ', onChanged: (_) {}, dir: TextDirection.rtl));
      await t.pump();
      expect(t.takeException(), isNull);
    });

    testWidgets('trigger : ≥48dp + action tap OPÉRABLE ouvre le picker',
        (t) async {
      final handle = t.ensureSemantics();
      await t.pumpWidget(_host(_fake(), countryIso: 'NE', onChanged: (_) {}));
      await t.pump();
      final trigger = find.byKey(const Key('z-state-trigger'));
      assertMinTapTarget(t, trigger);
      await assertSemanticActionTap(t, trigger, expectAfterTap: () async {
        expect(find.byKey(const Key('z-state-search')), findsOneWidget);
      });
      handle.dispose();
    });

    testWidgets('item : action tap sélectionne → tranche = code', (t) async {
      final handle = t.ensureSemantics();
      Object? slice;
      await t.pumpWidget(_host(_fake(), countryIso: 'NE', onChanged: (v) => slice = v));
      await t.pump();
      await t.tap(find.byKey(const Key('z-state-trigger')));
      await t.pump();
      final item = find.byKey(const Key('z-state-item-NE-8'));
      assertMinTapTarget(t, item);
      await assertSemanticActionTap(t, item);
      expect(slice, 'NE-8');
      handle.dispose();
    });
  });
}
