// AC13 (E3-3b-1 + enrichi -2/-3) — Catalogue a11y de RÉFÉRENCE : un formulaire
// couvrant les familles-feuilles avancées (tags/rowChips/rating/slider/color) +
// les familles imbriquées (subItems/dynamicItem, -2) + le rendu custom
// (signature ; widget libre via registre, -3) +
// un type `registryOrFallback` servi par un widget de DÉMO enregistré, passe
// `androidTapTargetGuideline` (≥ 48 dp) ET `textContrastGuideline`, présente des
// `Semantics`/labels, et rend RTL sans overflow.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const List<ZFieldChoice> _choices = <ZFieldChoice>[
  ZFieldChoice(value: 'a', label: 'A'),
  ZFieldChoice(value: 'b', label: 'B'),
];

/// Widget de démo accessible servi par le registre (cible ≥ 48 dp + Semantics).
class _DemoFieldWidget extends StatelessWidget {
  const _DemoFieldWidget(this.ctx);

  final ZFieldWidgetContext ctx;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'demo:${ctx.field.name}',
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
        child: SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: () => ctx.onChanged('x'),
            child: const Text('Démo'),
          ),
        ),
      ),
    );
  }
}

final List<ZFieldSpec> _catalogue = <ZFieldSpec>[
  const ZFieldSpec(name: 'tg', type: EditionFieldType.tags, label: 'Tags'),
  const ZFieldSpec(
      name: 'rc', type: EditionFieldType.rowChips, label: 'Puces', choices: _choices),
  const ZFieldSpec(
      name: 'rt',
      type: EditionFieldType.rating,
      label: 'Note',
      config: ZRatingConfig(max: 5)),
  const ZFieldSpec(
      name: 'sl',
      type: EditionFieldType.slider,
      label: 'Curseur',
      config: ZSliderConfig(divisions: 10)),
  const ZFieldSpec(name: 'cl', type: EditionFieldType.color, label: 'Couleur'),
  const ZFieldSpec(name: 'md', type: EditionFieldType.markdown, label: 'Registre'),
  // Familles imbriquées (-2) : mini-CRUD subList + item dynamique.
  const ZFieldSpec(
    name: 'sub',
    type: EditionFieldType.subItems,
    label: 'Sous-liste',
    config: ZSubListConfig(itemFields: <ZFieldSpec>[
      ZFieldSpec(name: 'n', type: EditionFieldType.text, label: 'Nom'),
    ]),
  ),
  const ZFieldSpec(
    name: 'dyn',
    type: EditionFieldType.dynamicItem,
    label: 'Item dynamique',
    config: ZSubListConfig(itemFields: <ZFieldSpec>[
      ZFieldSpec(name: 'n', type: EditionFieldType.text, label: 'Nom'),
    ]),
  ),
  // Rendu custom (-3) : signature (capture gestuelle) + widget libre (registre).
  const ZFieldSpec(
      name: 'sig', type: EditionFieldType.signature, label: 'Signature'),
  const ZFieldSpec(
      name: 'free', type: EditionFieldType.widget, label: 'Widget libre'),
];

ZFormController _controller() => ZFormController(
      initialValues: <String, Object?>{
        'tg': const <String>['x', 'y'],
        'rc': 'a',
        'rt': 3,
        'sl': 5,
        'cl': null,
        'md': 'v',
        'sub': const <Map<String, dynamic>>[
          <String, dynamic>{'n': 'x'},
        ],
        'dyn': const <String, dynamic>{'n': 'y'},
        'sig': null,
        'free': 'fv',
      },
      visibleFields: <String>[for (final f in _catalogue) f.name],
    );

Widget _app(
  ZFormController controller,
  ZWidgetRegistry registry, {
  TextDirection dir = TextDirection.ltr,
}) =>
    MaterialApp(
      home: ZcrudScope(
        widgetRegistry: registry,
        child: Directionality(
          textDirection: dir,
          child: Scaffold(
            body: DynamicEdition(controller: controller, fields: _catalogue),
          ),
        ),
      ),
    );

void _useTallSurface(WidgetTester tester, {double height = 5000}) {
  tester.view.physicalSize = Size(1200, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

ZWidgetRegistry _registry() => ZWidgetRegistry()
  ..register('markdown', (c, ctx) => _DemoFieldWidget(ctx))
  // Le widget libre (`widget`) partage le même seam de registre (kind `widget`).
  ..register('widget', (c, ctx) => _DemoFieldWidget(ctx));

void main() {
  testWidgets('catalogue : cibles ≥ 48 dp + contraste + widget démo (AC13)',
      (tester) async {
    _useTallSurface(tester);
    final handle = tester.ensureSemantics();
    final controller = _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, _registry()));
    await tester.pumpAndSettle();

    // Toutes les feuilles avancées + le widget démo (registre) sont montés.
    expect(find.byType(ZTagsFieldWidget), findsOneWidget);
    expect(find.byType(ZRowChipsFieldWidget), findsOneWidget);
    expect(find.byType(ZRatingFieldWidget), findsOneWidget);
    expect(find.byType(ZSliderFieldWidget), findsOneWidget);
    expect(find.byType(ZColorFieldWidget), findsOneWidget);
    expect(find.byType(ZSubListFieldWidget), findsOneWidget);
    expect(find.byType(ZDynamicItemFieldWidget), findsOneWidget);
    expect(find.byType(ZSignatureFieldWidget), findsOneWidget);
    expect(find.byType(ZFreeWidgetFieldWidget), findsOneWidget);
    // 1 démo (markdown, registryOrFallback) + 1 démo (widget libre, freeWidget).
    expect(find.byType(_DemoFieldWidget), findsNWidgets(2));
    expect(find.byType(ZUnsupportedFieldWidget), findsNothing,
        reason: 'le registre sert les types externes (pas de repli)');

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    handle.dispose();
  });

  testWidgets('catalogue : rendu RTL sans overflow/exception (AC13)',
      (tester) async {
    _useTallSurface(tester);
    final controller = _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
        _app(controller, _registry(), dir: TextDirection.rtl));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // La direction ambiante est bien RTL au niveau des champs.
    final dir = Directionality.of(
      tester.element(find.byType(ZColorFieldWidget)),
    );
    expect(dir, TextDirection.rtl);
  });

  testWidgets('AUCUN Form/FormBuilder global sous le catalogue avancé (AC15)',
      (tester) async {
    _useTallSurface(tester);
    final controller = _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, _registry()));
    await tester.pumpAndSettle();

    // Frontière de rebuild = la tranche (AD-2) : aucune famille avancée
    // n'introduit un `Form` global (rebuild formulaire complet interdit).
    expect(find.byType(Form), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

