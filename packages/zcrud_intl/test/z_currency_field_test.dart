// AC4/AC7/AC8/AC9/AC10 — ZCurrencyField : sélection → tranche (code / ZMoney),
// catalogue injecté, défensif, SM-1 (contrôleur non recréé + focus), anti-fuite,
// thème/RTL/a11y opérable (helpers AI-E10-1).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_intl/zcrud_intl.dart';

import 'support/a11y_asserts.dart';

ZCurrencyCatalog _fake() => ZCurrencyCatalog.fromList(const <ZCurrencyInfo>[
      ZCurrencyInfo(code: 'XOF', name: 'Franc CFA', symbol: 'CFA', decimalDigits: 0),
      ZCurrencyInfo(code: 'EUR', name: 'Euro', symbol: '€', decimalDigits: 2),
    ]);

ZFieldSpec _field({ZFieldConfig? config}) =>
    ZFieldSpec(name: 'cur', type: EditionFieldType.text, label: 'Devise', config: config);

Widget _host(
  ZCurrencyCatalog cat, {
  Object? value,
  bool showAmount = false,
  ZFieldConfig? config,
  required ValueChanged<Object?> onChanged,
  TextDirection dir = TextDirection.ltr,
  VoidCallback? onInit,
  VoidCallback? onBuild,
}) =>
    MaterialApp(
      home: Directionality(
        textDirection: dir,
        child: ZcrudScope(
          child: Scaffold(
            body: ZCurrencyField(
              ctx: ZFieldWidgetContext(
                field: _field(config: config),
                value: value,
                onChanged: onChanged,
              ),
              catalog: cat,
              showAmount: showAmount,
              onInit: onInit,
              onBuild: onBuild,
            ),
          ),
        ),
      ),
    );

Future<void> _open(WidgetTester t) async {
  await t.tap(find.byKey(const Key('z-currency-trigger')));
  await t.pump();
}

void main() {
  group('AC4 — sélection écrit la tranche', () {
    testWidgets('mode code : sélection → tranche = code ISO 4217 String',
        (t) async {
      Object? slice;
      await t.pumpWidget(_host(_fake(), onChanged: (v) => slice = v));
      await t.pump();
      await _open(t);
      expect(find.byKey(const Key('z-currency-item-XOF')), findsOneWidget);
      await t.tap(find.byKey(const Key('z-currency-item-EUR')));
      await t.pump();
      expect(slice, 'EUR');
    });

    testWidgets('mode montant : sélection + montant → tranche = ZMoney',
        (t) async {
      Object? slice;
      await t.pumpWidget(
          _host(_fake(), showAmount: true, onChanged: (v) => slice = v));
      await t.pump();
      await _open(t);
      await t.tap(find.byKey(const Key('z-currency-item-XOF')));
      await t.pump();
      await t.enterText(find.byKey(const Key('z-currency-amount')), '1500');
      await t.pump();
      expect(slice, isA<ZMoney>());
      expect((slice! as ZMoney).currencyCode, 'XOF');
      expect((slice! as ZMoney).amount, 1500);
    });

    testWidgets('builder() renvoie un ZFieldWidgetBuilder', (t) async {
      final b = ZCurrencyField.builder(catalog: _fake());
      expect(b, isA<ZFieldWidgetBuilder>());
    });

    testWidgets('recherche filtre la liste', (t) async {
      await t.pumpWidget(_host(_fake(), onChanged: (_) {}));
      await t.pump();
      await _open(t);
      await t.enterText(find.byKey(const Key('z-currency-search')), 'euro');
      await t.pump();
      expect(find.byKey(const Key('z-currency-item-EUR')), findsOneWidget);
      expect(find.byKey(const Key('z-currency-item-XOF')), findsNothing);
    });
  });

  group('AC1/AC4 — amorçage depuis config + valeur', () {
    testWidgets('defaultCurrencyCode de config amorce le trigger', (t) async {
      await t.pumpWidget(_host(_fake(),
          config: const ZIntlFieldConfig(defaultCurrencyCode: 'EUR'),
          onChanged: (_) {}));
      await t.pump();
      expect(find.text('Euro'), findsWidgets);
    });

    testWidgets('valeur ZMoney existante affichée + code lu', (t) async {
      await t.pumpWidget(_host(_fake(),
          value: const ZMoney(currencyCode: 'XOF', amount: 200),
          showAmount: true,
          onChanged: (_) {}));
      await t.pump();
      expect(find.text('Franc CFA'), findsWidgets);
    });
  });

  group('AC7 — défensif : valeur corrompue → pas de throw', () {
    testWidgets('valeur absurde → neutre, pas de crash', (t) async {
      await t.pumpWidget(_host(_fake(),
          value: <String, Object?>{'amount': <int>[1]}, onChanged: (_) {}));
      await t.pump();
      expect(t.takeException(), isNull);
      expect(find.byType(ZCurrencyField), findsOneWidget);
    });
  });

  group('AC8 — SM-1 : contrôleur montant non recréé + focus préservé', () {
    testWidgets('frappe montant → initState==1, focus conservé', (t) async {
      var init = 0;
      await t.pumpWidget(_host(_fake(),
          showAmount: true, onChanged: (_) {}, onInit: () => init++));
      await t.pump();
      final amt = find.byKey(const Key('z-currency-amount'));
      await t.tap(amt);
      await t.pump();
      await t.enterText(amt, '1');
      await t.pump();
      await t.enterText(amt, '15');
      await t.pump();
      expect(init, 1);
      expect(t.widget<TextField>(amt).focusNode!.hasFocus, isTrue);
    });
  });

  group('AC9 — anti-fuite : dispose propre', () {
    testWidgets('démontage après frappe → aucune exception', (t) async {
      await t.pumpWidget(
          _host(_fake(), showAmount: true, onChanged: (_) {}));
      await t.pump();
      await t.enterText(find.byKey(const Key('z-currency-amount')), '9');
      await t.pump();
      await t.pumpWidget(const SizedBox());
      expect(t.takeException(), isNull);
    });
  });

  group('AC10 — thème/RTL/a11y opérable', () {
    testWidgets('rendu RTL sans exception', (t) async {
      await t.pumpWidget(
          _host(_fake(), onChanged: (_) {}, dir: TextDirection.rtl));
      await t.pump();
      expect(t.takeException(), isNull);
    });

    testWidgets('trigger : ≥48dp + action tap OPÉRABLE ouvre le picker',
        (t) async {
      final handle = t.ensureSemantics();
      await t.pumpWidget(_host(_fake(), onChanged: (_) {}));
      await t.pump();
      final trigger = find.byKey(const Key('z-currency-trigger'));
      assertMinTapTarget(t, trigger);
      await assertSemanticActionTap(t, trigger, expectAfterTap: () async {
        expect(find.byKey(const Key('z-currency-search')), findsOneWidget);
      });
      handle.dispose();
    });

    testWidgets('item : action tap sélectionne → tranche = code', (t) async {
      final handle = t.ensureSemantics();
      Object? slice;
      await t.pumpWidget(_host(_fake(), onChanged: (v) => slice = v));
      await t.pump();
      await _open(t);
      final item = find.byKey(const Key('z-currency-item-EUR'));
      assertMinTapTarget(t, item);
      await assertSemanticActionTap(t, item);
      expect(slice, 'EUR');
      handle.dispose();
    });
  });
}
