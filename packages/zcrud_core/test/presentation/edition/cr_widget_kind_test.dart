// Discriminant `ZFieldSpec.widgetKind` (CR DODLP 2026-08-13) : deux champs
// `widget` du même formulaire portent DEUX builders distincts ; sans
// discriminant le repli `type.name` est bit-à-bit inchangé (contre-témoin) ;
// la MÊME mécanique sert la famille `custom` (registryOrFallback) ; un
// discriminant non enregistré retombe sur `type.name` (défensif AD-10).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

class _Host extends StatelessWidget {
  const _Host(this.tag, this.ctx);
  final String tag;
  final ZFieldWidgetContext ctx;

  @override
  Widget build(BuildContext context) =>
      Text('$tag:${ctx.field.name}', textAlign: TextAlign.start);
}

ZFieldWidgetBuilder _host(String tag) => (context, ctx) => _Host(tag, ctx);

Widget _app({
  required List<ZFieldSpec> fields,
  required ZFormController controller,
  required ZWidgetRegistry registry,
}) =>
    MaterialApp(
      home: ZcrudScope(
        widgetRegistry: registry,
        child: Scaffold(
          body: DynamicEdition(controller: controller, fields: fields),
        ),
      ),
    );

void main() {
  testWidgets(
      'deux champs `widget` du MÊME formulaire → deux builders distincts '
      'via widgetKind', (tester) async {
    const fields = <ZFieldSpec>[
      ZFieldSpec(
        name: 'acl',
        type: EditionFieldType.widget,
        widgetKind: 'aclMatrix',
      ),
      ZFieldSpec(
        name: 'planning',
        type: EditionFieldType.widget,
        widgetKind: 'planning',
      ),
    ];
    final controller = ZFormController(
      initialValues: const <String, Object?>{},
      visibleFields: const <String>['acl', 'planning'],
    );
    addTearDown(controller.dispose);
    final registry = ZWidgetRegistry()
      ..register('aclMatrix', _host('matrix'))
      ..register('planning', _host('plan'));

    await tester.pumpWidget(
        _app(fields: fields, controller: controller, registry: registry));
    await tester.pump();

    expect(find.text('matrix:acl'), findsOneWidget);
    expect(find.text('plan:planning'), findsOneWidget);
    expect(find.byType(ZUnsupportedFieldWidget), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'CONTRE-TÉMOIN : sans widgetKind, repli `type.name` inchangé '
      '(kind `widget`)', (tester) async {
    const fields = <ZFieldSpec>[
      ZFieldSpec(name: 'libre', type: EditionFieldType.widget),
    ];
    final controller = ZFormController(
      initialValues: const <String, Object?>{},
      visibleFields: const <String>['libre'],
    );
    addTearDown(controller.dispose);
    final registry = ZWidgetRegistry()
      ..register('widget', _host('fallback'))
      ..register('aclMatrix', _host('matrix'));

    await tester.pumpWidget(
        _app(fields: fields, controller: controller, registry: registry));
    await tester.pump();

    expect(find.text('fallback:libre'), findsOneWidget,
        reason: 'sans discriminant, le kind résolu reste type.name');
    expect(find.textContaining('matrix'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'la famille `custom` consulte le MÊME discriminant (une seule '
      'mécanique pour widget ET custom)', (tester) async {
    const fields = <ZFieldSpec>[
      ZFieldSpec(
        name: 'c1',
        type: EditionFieldType.custom,
        widgetKind: 'permissions',
      ),
      ZFieldSpec(name: 'c2', type: EditionFieldType.custom),
    ];
    final controller = ZFormController(
      initialValues: const <String, Object?>{},
      visibleFields: const <String>['c1', 'c2'],
    );
    addTearDown(controller.dispose);
    final registry = ZWidgetRegistry()
      ..register('permissions', _host('perm'))
      ..register('custom', _host('shared'));

    await tester.pumpWidget(
        _app(fields: fields, controller: controller, registry: registry));
    await tester.pump();

    expect(find.text('perm:c1'), findsOneWidget,
        reason: 'widgetKind discrimine le champ custom');
    expect(find.text('shared:c2'), findsOneWidget,
        reason: 'sans discriminant, le kind partagé `custom` sert toujours');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'widgetKind NON enregistré → repli défensif sur type.name '
      '(invariant AD-10), puis repli contrôlé', (tester) async {
    const fields = <ZFieldSpec>[
      ZFieldSpec(
        name: 'w1',
        type: EditionFieldType.widget,
        widgetKind: 'inconnu',
      ),
      ZFieldSpec(
        name: 'w2',
        type: EditionFieldType.custom,
        widgetKind: 'inconnuAussi',
      ),
    ];
    final controller = ZFormController(
      initialValues: const <String, Object?>{},
      visibleFields: const <String>['w1', 'w2'],
    );
    addTearDown(controller.dispose);
    // `widget` est enregistré (repli type.name servi) ; `custom` ne l'est pas
    // (repli contrôlé ZUnsupportedFieldWidget, jamais une exception).
    final registry = ZWidgetRegistry()..register('widget', _host('type'));

    await tester.pumpWidget(
        _app(fields: fields, controller: controller, registry: registry));
    await tester.pump();

    expect(find.text('type:w1'), findsOneWidget);
    expect(find.byType(ZUnsupportedFieldWidget), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
