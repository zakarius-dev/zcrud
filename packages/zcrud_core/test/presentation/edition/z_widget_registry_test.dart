// AC1/AC2 (E3-3b-1) — `ZWidgetRegistry` : seam de registre de widgets injecté.
// (a) API register/lookup/duplicate ; (b) le dispatcher rend le repli SANS
// registre / avec un `kind` non enregistré ; (c) un widget de DÉMO (faux `kind`,
// défini DANS le test — le cœur ne le connaît pas) est rendu par le dispatcher,
// lit `value` et écrit la tranche via `onChanged`, sans aucune exception.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Widget de DÉMO servi via le registre (prouve le seam) — le cœur `zcrud_core`
/// n'importe AUCUN package satellite ; ce widget vit côté hôte (ici : le test).
class _DemoFieldWidget extends StatelessWidget {
  const _DemoFieldWidget(this.ctx);

  final ZFieldWidgetContext ctx;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'demo:${ctx.field.name}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('val=${ctx.value}'),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () => ctx.onChanged('written'),
              child: const Text('write'),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _mount(
  ZFormController controller,
  ZFieldSpec field, {
  ZWidgetRegistry? registry,
}) {
  final form = DynamicEdition(controller: controller, fields: <ZFieldSpec>[field]);
  return MaterialApp(
    home: ZcrudScope(
      widgetRegistry: registry,
      child: Scaffold(body: form),
    ),
  );
}

ZFormController _controller(String name, {Object? value}) => ZFormController(
      initialValues: <String, Object?>{name: value},
      visibleFields: <String>[name],
    );

void main() {
  group('ZWidgetRegistry — API (AC1)', () {
    test('register / isRegistered / kinds / tryBuilderFor / builderFor', () {
      final registry = ZWidgetRegistry();
      expect(registry.isRegistered('markdown'), isFalse);
      expect(registry.tryBuilderFor('markdown'), isNull);
      expect(() => registry.builderFor('markdown'), throwsA(isA<Error>()));

      Widget builder(BuildContext c, ZFieldWidgetContext ctx) =>
          const SizedBox.shrink();
      registry.register('markdown', builder);

      expect(registry.isRegistered('markdown'), isTrue);
      expect(registry.kinds, contains('markdown'));
      expect(registry.tryBuilderFor('markdown'), same(builder));
      expect(registry.builderFor('markdown'), same(builder));
    });

    test('ré-enregistrer le même kind → throw (jamais last-wins)', () {
      final registry = ZWidgetRegistry()
        ..register('custom', (c, ctx) => const SizedBox.shrink());
      expect(
        () => registry.register('custom', (c, ctx) => const SizedBox.shrink()),
        throwsA(isA<Error>()),
      );
    });

    test('instanciable / non-singleton : deux instances sont indépendantes '
        '(AD-4)', () {
      final a = ZWidgetRegistry()..register('k', (c, ctx) => const SizedBox());
      final b = ZWidgetRegistry();
      expect(a.isRegistered('k'), isTrue);
      expect(b.isRegistered('k'), isFalse,
          reason: 'aucun état statique partagé entre instances');
    });
  });

  testWidgets('registre vide (aucun kind) → dispatcher rend le repli (AC1)',
      (tester) async {
    final controller = _controller('md');
    addTearDown(controller.dispose);
    const field = ZFieldSpec(name: 'md', type: EditionFieldType.markdown);

    await tester.pumpWidget(
        _mount(controller, field, registry: ZWidgetRegistry()));
    await tester.pump();

    expect(find.byType(ZUnsupportedFieldWidget), findsOneWidget);
    expect(find.byType(_DemoFieldWidget), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('aucun ZcrudScope.widgetRegistry (null) → repli (AC1)',
      (tester) async {
    final controller = _controller('md');
    addTearDown(controller.dispose);
    const field = ZFieldSpec(name: 'md', type: EditionFieldType.markdown);

    // registry: null (défaut ZcrudScope).
    await tester.pumpWidget(_mount(controller, field));
    await tester.pump();

    expect(find.byType(ZUnsupportedFieldWidget), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kind externe enregistré → widget hôte rendu, lit/écrit la '
      'tranche, aucune exception (AC2)', (tester) async {
    final controller = _controller('md', value: 'initial');
    addTearDown(controller.dispose);
    const field =
        ZFieldSpec(name: 'md', type: EditionFieldType.markdown, label: 'MD');
    final registry = ZWidgetRegistry()
      ..register('markdown', (c, ctx) => _DemoFieldWidget(ctx));

    await tester.pumpWidget(_mount(controller, field, registry: registry));
    await tester.pump();

    // (a) Le widget hôte est rendu, pas le repli.
    expect(find.byType(_DemoFieldWidget), findsOneWidget);
    expect(find.byType(ZUnsupportedFieldWidget), findsNothing);
    // (b) Il LIT la valeur de la tranche.
    expect(find.text('val=initial'), findsOneWidget);

    // (c) Il ÉCRIT la tranche via onChanged (value-in-slice).
    await tester.tap(find.text('write'));
    await tester.pump();
    expect(controller.valueOf('md'), 'written');
    expect(find.text('val=written'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('kind `custom` résolu par nom d\'enum (AD-4)', (tester) async {
    final controller = _controller('c');
    addTearDown(controller.dispose);
    const field = ZFieldSpec(name: 'c', type: EditionFieldType.custom);
    final registry = ZWidgetRegistry()
      ..register('custom', (c, ctx) => _DemoFieldWidget(ctx));

    await tester.pumpWidget(_mount(controller, field, registry: registry));
    await tester.pump();

    expect(find.byType(_DemoFieldWidget), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('registre peuplé pour un AUTRE kind → repli pour le type demandé',
      (tester) async {
    final controller = _controller('md');
    addTearDown(controller.dispose);
    const field = ZFieldSpec(name: 'md', type: EditionFieldType.markdown);
    // Enregistre 'location', pas 'markdown'.
    final registry = ZWidgetRegistry()
      ..register('location', (c, ctx) => _DemoFieldWidget(ctx));

    await tester.pumpWidget(_mount(controller, field, registry: registry));
    await tester.pump();

    expect(find.byType(ZUnsupportedFieldWidget), findsOneWidget);
    expect(find.byType(_DemoFieldWidget), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
