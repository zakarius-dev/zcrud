// AC11 (E3-3b-3) — Famille `freeWidget` (`widget` libre) : rendu d'un widget
// host-fourni via `ZWidgetRegistry` (kind `'widget'`), repli contrôlé
// `ZUnsupportedFieldWidget` si non enregistré. CONSOMME le registre d'E3-3b-1
// (jamais réimplémenté). Le cœur reste agnostique (aucun import satellite).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _name = 'w';

/// Widget de démo host-fourni (accessible) : lit `value`, écrit via `onChanged`.
class _HostWidget extends StatelessWidget {
  const _HostWidget(this.ctx);
  final ZFieldWidgetContext ctx;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'host:${ctx.field.name}',
      value: '${ctx.value}',
      child: SizedBox(
        height: 48,
        child: ElevatedButton(
          onPressed: () => ctx.onChanged('written'),
          child: Text('host ${ctx.value}'),
        ),
      ),
    );
  }
}

ZFormController _controller({Object? initial}) => ZFormController(
      initialValues: <String, Object?>{_name: initial},
      visibleFields: <String>[_name],
    );

Widget _app(ZFormController controller, ZWidgetRegistry? registry) {
  const fields = <ZFieldSpec>[
    ZFieldSpec(name: _name, type: EditionFieldType.widget, label: 'Libre'),
  ];
  final body = Scaffold(
    body: DynamicEdition(controller: controller, fields: fields),
  );
  return MaterialApp(
    home: registry == null
        ? body
        : ZcrudScope(widgetRegistry: registry, child: body),
  );
}

void main() {
  testWidgets('registre peuplé (kind `widget`) → widget hôte rendu (AC11)',
      (tester) async {
    final controller = _controller(initial: 'v0');
    addTearDown(controller.dispose);
    final registry = ZWidgetRegistry()
      ..register('widget', (c, ctx) => _HostWidget(ctx));

    await tester.pumpWidget(_app(controller, registry));
    await tester.pump();

    expect(find.byType(ZFreeWidgetFieldWidget), findsOneWidget);
    expect(find.byType(_HostWidget), findsOneWidget);
    expect(find.byType(ZUnsupportedFieldWidget), findsNothing,
        reason: 'kind enregistré → pas de repli');
    // Le widget hôte LIT la tranche.
    expect(find.text('host v0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('widget hôte ÉCRIT la tranche via onChanged (value-in-slice)',
      (tester) async {
    final controller = _controller(initial: 'v0');
    addTearDown(controller.dispose);
    final registry = ZWidgetRegistry()
      ..register('widget', (c, ctx) => _HostWidget(ctx));

    await tester.pumpWidget(_app(controller, registry));
    await tester.pump();

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    expect(controller.valueOf(_name), 'written');
    // Rebuild GRANULAIRE : seule cette tranche reflète la nouvelle valeur.
    expect(find.text('host written'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AUCUN registre → repli contrôlé, aucune exception (AC11)',
      (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, null));
    await tester.pump();

    expect(find.byType(ZFreeWidgetFieldWidget), findsOneWidget);
    expect(find.byType(ZUnsupportedFieldWidget), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.byType(ErrorWidget), findsNothing);
  });

  testWidgets('registre SANS le kind `widget` → repli contrôlé', (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    // Registre peuplé pour un AUTRE kind : `widget` doit retomber sur le repli.
    final registry = ZWidgetRegistry()
      ..register('markdown', (c, ctx) => _HostWidget(ctx));

    await tester.pumpWidget(_app(controller, registry));
    await tester.pump();

    expect(find.byType(ZUnsupportedFieldWidget), findsOneWidget);
    expect(find.byType(_HostWidget), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
