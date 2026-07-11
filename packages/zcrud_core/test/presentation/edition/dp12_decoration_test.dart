// DP-12 (M1/M5/M6) : résolveur d'ornement défensif, `ZFieldLabel` enrichi,
// consommation de la décoration par les familles, slots Card `large`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Pompe un champ unique via le dispatcher, lié à une tranche `name`.
Future<InputDecoration> _pumpFieldDecoration(
  WidgetTester tester,
  ZFieldSpec field, {
  Object? value,
}) async {
  final controller = ZFormController(
    initialValues: <String, Object?>{field.name: value},
    visibleFields: <String>[field.name],
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    _host(ZFieldWidget(controller: controller, field: field)),
  );
  await tester.pumpAndSettle();
  return tester.widget<TextField>(find.byType(TextField)).decoration!;
}

void main() {
  group('resolveAdornment — défensif (AD-10)', () {
    testWidgets('null → null ; text → Text ; icon connu → Icon', (tester) async {
      late Widget? textW;
      late Widget? iconW;
      late Widget? nullW;
      await tester.pumpWidget(_host(Builder(builder: (context) {
        const field = ZFieldSpec(name: 'x', type: EditionFieldType.text);
        nullW = resolveAdornment(context, null, field: field);
        textW = resolveAdornment(
            context, const ZFieldAdornment.text('EUR'), field: field);
        iconW = resolveAdornment(
            context, const ZFieldAdornment.icon('search'), field: field);
        return const SizedBox();
      })));
      expect(nullW, isNull);
      expect(textW, isA<Text>());
      expect(iconW, isA<Icon>());
      expect((iconW! as Icon).icon, Icons.search);
    });

    testWidgets('icône INCONNUE → null (jamais de throw)', (tester) async {
      late Widget? w;
      await tester.pumpWidget(_host(Builder(builder: (context) {
        const field = ZFieldSpec(name: 'x', type: EditionFieldType.text);
        w = resolveAdornment(
            context, const ZFieldAdornment.icon('__inconnu__'), field: field);
        return const SizedBox();
      })));
      expect(w, isNull);
    });

    testWidgets('widget kind non enregistré → null (dégradation propre)',
        (tester) async {
      late Widget? w;
      await tester.pumpWidget(_host(Builder(builder: (context) {
        const field = ZFieldSpec(name: 'x', type: EditionFieldType.text);
        w = resolveAdornment(
            context, const ZFieldAdornment.widget('__none__'), field: field);
        return const SizedBox();
      })));
      expect(w, isNull);
    });

    testWidgets('iconResolver host prioritaire sur la table par défaut',
        (tester) async {
      late Widget? w;
      await tester.pumpWidget(_host(ZcrudScope(
        iconResolver: (key) => key == 'custom' ? Icons.star : null,
        child: Builder(builder: (context) {
          const field = ZFieldSpec(name: 'x', type: EditionFieldType.text);
          w = resolveAdornment(
              context, const ZFieldAdornment.icon('custom'), field: field);
          return const SizedBox();
        }),
      )));
      expect((w! as Icon).icon, Icons.star);
    });
  });

  group('ZFieldLabel — astérisque requis (M5)', () {
    testWidgets('champ requis + éditable → astérisque " *" présent',
        (tester) async {
      await tester.pumpWidget(_host(const ZFieldLabel(
        field: ZFieldSpec(
          name: 'x',
          type: EditionFieldType.text,
          label: 'Nom',
          validators: <ZValidatorSpec>[ZValidatorSpec.required()],
        ),
      )));
      expect(find.text(' *'), findsOneWidget);
    });

    testWidgets('champ NON requis → aucun astérisque', (tester) async {
      await tester.pumpWidget(_host(const ZFieldLabel(
        field: ZFieldSpec(name: 'x', type: EditionFieldType.text, label: 'Nom'),
      )));
      expect(find.text(' *'), findsNothing);
    });

    testWidgets('champ requis mais readOnly → aucun astérisque', (tester) async {
      await tester.pumpWidget(_host(const ZFieldLabel(
        field: ZFieldSpec(
          name: 'x',
          type: EditionFieldType.text,
          label: 'Nom',
          readOnly: true,
          validators: <ZValidatorSpec>[ZValidatorSpec.required()],
        ),
      )));
      expect(find.text(' *'), findsNothing);
    });

    testWidgets('astérisque coloré ERREUR thémé (aucune couleur en dur)',
        (tester) async {
      late Color errorColor;
      await tester.pumpWidget(_host(Builder(builder: (context) {
        errorColor = Theme.of(context).colorScheme.error;
        return const ZFieldLabel(
          field: ZFieldSpec(
            name: 'x',
            type: EditionFieldType.text,
            label: 'Nom',
            validators: <ZValidatorSpec>[ZValidatorSpec.required()],
          ),
        );
      })));
      final star = tester.widget<Text>(find.text(' *'));
      expect(star.style!.color, errorColor);
    });
  });

  group('Familles — consommation de la décoration (M1/M6)', () {
    testWidgets('texte : leading→icon, prefix→prefix, hint/helper injectés',
        (tester) async {
      final deco = await _pumpFieldDecoration(
        tester,
        const ZFieldSpec(
          name: 'x',
          type: EditionFieldType.text,
          label: 'L',
          leading: ZFieldAdornment.icon('search'),
          prefix: ZFieldAdornment.text('EUR'),
          suffix: ZFieldAdornment.icon('clear'),
          hintText: 'saisir',
          helperText: 'aide',
        ),
        value: '',
      );
      expect(deco.icon, isA<Icon>()); // leading
      expect(deco.prefix, isA<Text>()); // prefix .text
      expect(deco.suffixIcon, isA<Icon>()); // suffix .icon → suffixIcon
      expect(deco.hintText, 'saisir');
      expect(deco.helperText, 'aide');
      // Label enrichi (Widget) et pas de labelText nu.
      expect(deco.label, isA<ZFieldLabel>());
      expect(deco.labelText, isNull);
    });

    testWidgets('nombre : hint/helper + prefix icône', (tester) async {
      final deco = await _pumpFieldDecoration(
        tester,
        const ZFieldSpec(
          name: 'n',
          type: EditionFieldType.integer,
          label: 'N',
          prefix: ZFieldAdornment.icon('money'),
          helperText: 'aide',
        ),
        value: 3,
      );
      expect(deco.prefixIcon, isA<Icon>());
      expect(deco.helperText, 'aide');
    });

    testWidgets('champ sans ornement : décoration inchangée (rétro-compat)',
        (tester) async {
      final deco = await _pumpFieldDecoration(
        tester,
        const ZFieldSpec(name: 'x', type: EditionFieldType.text, label: 'L'),
        value: '',
      );
      expect(deco.icon, isNull);
      expect(deco.prefix, isNull);
      expect(deco.suffix, isNull);
      expect(deco.hintText, isNull);
      expect(deco.helperText, isNull);
    });
  });

  group('Card large — slots leading/suffix branchés (M1)', () {
    testWidgets('leading/suffix résolus alimentent la Card + label enrichi',
        (tester) async {
      const field = ZFieldSpec(
        name: 'x',
        type: EditionFieldType.text,
        label: 'Nom',
        fieldSize: ZFieldSize.large,
        leading: ZFieldAdornment.icon('person'),
        suffix: ZFieldAdornment.icon('clear'),
        validators: <ZValidatorSpec>[ZValidatorSpec.required()],
      );
      final controller = ZFormController(
        initialValues: const <String, Object?>{'x': 'Ada'},
        visibleFields: const <String>['x'],
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(ZFieldWidget(controller: controller, field: field)),
      );
      await tester.pumpAndSettle();

      final card = tester.widget<ZLargeFieldCard>(find.byType(ZLargeFieldCard));
      expect(card.leading, isNotNull);
      expect(card.suffix, isNotNull);
      expect(card.labelWidget, isA<ZFieldLabel>());
      // Astérisque requis visible dans la Card (large).
      expect(find.text(' *'), findsOneWidget);
    });
  });
}
