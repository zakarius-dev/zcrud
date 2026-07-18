// FP-4.4 (AD-52) — champ `color` en mode **multiple** (`ZColorConfig.multiple`).
//
// Couvre :
//  (a) ajout de 2 couleurs (palette) → la tranche vaut la List<int> ARGB ;
//  (b) entrée corrompue mêlée → EXACTEMENT les pastilles ARGB valides + no throw ;
//  (c) parent multi-champ à valeur corrompue survit (autres champs rendus) ;
//  (d) non-régression : le mode par défaut (mono) émet un `int`, pas une List ;
//  (e) a11y ≥ 48 dp + Semantics sur les swatches.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

ZFormController _controller(
  Map<String, Object?> values,
  List<String> visible,
) =>
    ZFormController(initialValues: values, visibleFields: visible);

Widget _app(
  ZFormController controller,
  List<ZFieldSpec> fields, {
  TextDirection dir = TextDirection.ltr,
  ThemeData? theme,
  ZColorPicker? colorPicker,
}) =>
    MaterialApp(
      theme: theme,
      home: Directionality(
        textDirection: dir,
        child: ZcrudScope(
          colorPicker: colorPicker,
          child: Scaffold(
            body: DynamicEdition(controller: controller, fields: fields),
          ),
        ),
      ),
    );

const _multiField = ZFieldSpec(
  name: 'colors',
  type: EditionFieldType.color,
  label: 'Colors',
  config: ZColorConfig.multiple(),
);

const _monoField = ZFieldSpec(
  name: 'c',
  type: EditionFieldType.color,
  label: 'C',
);

void main() {
  testWidgets('(a) ajouter 2 couleurs (palette) → tranche = List<int> ARGB',
      (tester) async {
    final controller = _controller(<String, Object?>{'colors': null}, ['colors']);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, const <ZFieldSpec>[_multiField]));
    await tester.pumpAndSettle();

    // Le widget multi est monté (pas le mono).
    expect(find.byType(ZColorMultiFieldWidget), findsOneWidget);
    expect(find.byType(ZColorFieldWidget), findsNothing);

    // Tap deux swatches de palette distincts.
    final swatches = find.bySemanticsLabel(RegExp('Select a color #'));
    await tester.tap(swatches.at(0));
    await tester.pump();
    await tester.tap(swatches.at(1));
    await tester.pump();

    final slice = controller.valueOf('colors');
    expect(slice, isA<List<int>>());
    final list = slice! as List<int>;
    expect(list.length, 2);
    // Chaque entrée est un ARGB alpha plein (palette dérivée).
    for (final argb in list) {
      expect(argb >> 24 & 0xFF, 0xFF);
    }
    // Jamais un int seul.
    expect(slice, isNot(isA<int>()));
  });

  testWidgets(
      '(b) entrée corrompue mêlée → EXACTEMENT les pastilles ARGB valides + no throw',
      (tester) async {
    const corrupted = <Object?>['x', 0xFF112233, null, 2.5, 0xFF445566];
    final controller =
        _controller(<String, Object?>{'colors': corrupted}, ['colors']);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, const <ZFieldSpec>[_multiField]));
    await tester.pumpAndSettle();

    // Aucune exception (le cast direct `as List<int>` cracherait ici — R3).
    expect(tester.takeException(), isNull);

    // EXACTEMENT 2 pastilles retirables : les seuls int valides (assertion sur
    // le CONTENU filtré, pas seulement l'absence d'exception).
    expect(find.bySemanticsLabel('Remove color #FF112233'), findsOneWidget);
    expect(find.bySemanticsLabel('Remove color #FF445566'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Remove color #')), findsNWidgets(2));
  });

  testWidgets('(c) parent multi-champ à valeur corrompue survit', (tester) async {
    const corrupted = <Object?>['bad', 0xFFAA0000];
    final controller = _controller(
      <String, Object?>{'colors': corrupted, 'name': 'Alice'},
      ['colors', 'name'],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, const <ZFieldSpec>[
      _multiField,
      ZFieldSpec(name: 'name', type: EditionFieldType.text, label: 'Name'),
    ]));
    await tester.pumpAndSettle();

    // Le champ voisin est rendu malgré la valeur corrompue du color-multiple.
    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(TextField, 'Alice'), findsOneWidget);
    // La seule couleur valide est pastillée.
    expect(find.bySemanticsLabel('Remove color #FFAA0000'), findsOneWidget);
  });

  testWidgets('(d) non-régression : mode par défaut (mono) émet un int',
      (tester) async {
    final controller = _controller(<String, Object?>{'c': null}, ['c']);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, const <ZFieldSpec>[_monoField]));
    await tester.pumpAndSettle();

    // Le widget MONO est monté (dispatch par défaut inchangé).
    expect(find.byType(ZColorFieldWidget), findsOneWidget);
    expect(find.byType(ZColorMultiFieldWidget), findsNothing);

    await tester.tap(find.bySemanticsLabel(RegExp('Select a color #')).first);
    await tester.pump();

    final slice = controller.valueOf('c');
    expect(slice, isA<int>());
    expect(slice, isNot(isA<List<int>>()));
  });

  testWidgets('(e) a11y : swatches ≥ 48 dp + Semantics', (tester) async {
    final handle = tester.ensureSemantics();
    final controller = _controller(
      <String, Object?>{'colors': const <int>[0xFF00FF00]},
      ['colors'],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, const <ZFieldSpec>[_multiField]));
    await tester.pumpAndSettle();

    // Guideline de taille de cible tactile Android (≥ 48 dp).
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));

    // La pastille sélectionnée porte un Semantics avec son hex.
    expect(
        find.bySemanticsLabel('Remove color #FF00FF00'), findsOneWidget);

    handle.dispose();
  });

  // MED-1 — Contraste du glyphe (coche/croix) piloté par la luminosité de la
  // PASTILLE (la donnée), PAS du thème de l'app. Falsifiable : l'ancien
  // heuristique `onPrimary/onSurface` (couleurs du thème) rendrait un glyphe
  // sombre-sur-pastille-sombre en dark theme (onSurface clair devient... suit le
  // thème, pas la pastille) ⇒ ces assertions rougiraient.
  testWidgets(
      '(f) MED-1 : en dark theme, pastille SOMBRE → glyphe CLAIR (coche + croix)',
      (tester) async {
    // 0xFF262626 = neutre sombre de la palette (HSV value 0.15) ⇒ à la fois
    // pastille retirable (croix) ET case de palette sélectionnée (coche).
    const darkSwatch = 0xFF262626;
    final controller = _controller(
      <String, Object?>{'colors': const <int>[darkSwatch]},
      ['colors'],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, const <ZFieldSpec>[_multiField],
        theme: ThemeData.dark()));
    await tester.pumpAndSettle();

    final check = tester.widget<Icon>(find.byIcon(Icons.check));
    final close = tester.widget<Icon>(find.byIcon(Icons.close));
    // Glyphe CLAIR sur pastille sombre (indépendant du dark theme).
    expect(check.color, Colors.white);
    expect(close.color, Colors.white);
    // Contraste : la brightness du glyphe est l'OPPOSÉE de la pastille.
    expect(ThemeData.estimateBrightnessForColor(const Color(darkSwatch)),
        Brightness.dark);
    expect(ThemeData.estimateBrightnessForColor(check.color!),
        Brightness.light);
    expect(ThemeData.estimateBrightnessForColor(close.color!),
        Brightness.light);
  });

  testWidgets(
      '(g) MED-1 : en dark theme, pastille CLAIRE → glyphe SOMBRE (coche + croix)',
      (tester) async {
    // 0xFFE6E6E6 = neutre clair de la palette (HSV value 0.9).
    const lightSwatch = 0xFFE6E6E6;
    final controller = _controller(
      <String, Object?>{'colors': const <int>[lightSwatch]},
      ['colors'],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, const <ZFieldSpec>[_multiField],
        theme: ThemeData.dark()));
    await tester.pumpAndSettle();

    final check = tester.widget<Icon>(find.byIcon(Icons.check));
    final close = tester.widget<Icon>(find.byIcon(Icons.close));
    expect(check.color, Colors.black);
    expect(close.color, Colors.black);
    expect(ThemeData.estimateBrightnessForColor(const Color(lightSwatch)),
        Brightness.light);
    expect(ThemeData.estimateBrightnessForColor(check.color!), Brightness.dark);
    expect(ThemeData.estimateBrightnessForColor(close.color!), Brightness.dark);
  });

  // MED-2 — `_addColor` (bouton « ajouter une couleur ») : append+dédup + repli
  // défensif AD-10 (seam qui throw ⇒ AUCUNE écriture).
  testWidgets('(h) MED-2 : bouton ajouter + seam picker → couleur ajoutée',
      (tester) async {
    const initial = 0xFF010203;
    const picked = 0xFF0A0B0C;
    final controller =
        _controller(<String, Object?>{'colors': const <int>[initial]}, ['colors']);
    addTearDown(controller.dispose);

    Future<int?> seam(
      BuildContext context, {
      required int? initialArgb,
      required bool enableAlpha,
      required List<int> recentColors,
    }) async =>
        picked;

    await tester.pumpWidget(_app(controller, const <ZFieldSpec>[_multiField],
        colorPicker: seam));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Add a color'));
    await tester.pumpAndSettle();

    final slice = controller.valueOf('colors')! as List<int>;
    expect(slice, <int>[initial, picked]);
  });

  testWidgets(
      '(i) MED-2 : seam retourne une couleur DÉJÀ présente → dédup (pas de doublon)',
      (tester) async {
    const initial = 0xFF010203;
    final controller =
        _controller(<String, Object?>{'colors': const <int>[initial]}, ['colors']);
    addTearDown(controller.dispose);

    // Le picker rend la couleur DÉJÀ dans la tranche.
    Future<int?> seam(
      BuildContext context, {
      required int? initialArgb,
      required bool enableAlpha,
      required List<int> recentColors,
    }) async =>
        initial;

    await tester.pumpWidget(_app(controller, const <ZFieldSpec>[_multiField],
        colorPicker: seam));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Add a color'));
    await tester.pumpAndSettle();

    // Dédup : la tranche reste à 1 élément (retirer `!current.contains(picked)`
    // ferait passer la longueur à 2 ⇒ ce test rougirait).
    final slice = controller.valueOf('colors')! as List<int>;
    expect(slice, <int>[initial]);
  });

  testWidgets(
      '(j) MED-2/AD-10 : seam qui THROW → aucune écriture, aucun crash',
      (tester) async {
    const initial = 0xFF010203;
    final controller =
        _controller(<String, Object?>{'colors': const <int>[initial]}, ['colors']);
    addTearDown(controller.dispose);

    Future<int?> throwingSeam(
      BuildContext context, {
      required int? initialArgb,
      required bool enableAlpha,
      required List<int> recentColors,
    }) async =>
        throw StateError('picker boom');

    await tester.pumpWidget(_app(controller, const <ZFieldSpec>[_multiField],
        colorPicker: throwingSeam));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Add a color'));
    await tester.pumpAndSettle();

    // AD-10 : le seam défaillant est avalé ⇒ pas d'écriture, formulaire vivant.
    expect(tester.takeException(), isNull);
    final slice = controller.valueOf('colors')! as List<int>;
    expect(slice, <int>[initial]);
  });

  // LOW — Double annonce du libellé corrigée : le `Semantics(container:true)` ne
  // porte plus `label:` (le `Text` visible fournit le nom). Le libellé
  // n'apparaît qu'UNE fois dans l'arbre sémantique.
  testWidgets('(k) LOW : le libellé du champ apparaît UNE seule fois (a11y)',
      (tester) async {
    final handle = tester.ensureSemantics();
    final controller =
        _controller(<String, Object?>{'colors': null}, ['colors']);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, const <ZFieldSpec>[_multiField]));
    await tester.pumpAndSettle();

    // Falsifiable : réintroduire `label: resolvedLabel` sur le Semantics
    // conteneur ferait apparaître 'Colors' DEUX fois (findsNWidgets(2)).
    expect(find.bySemanticsLabel('Colors'), findsOneWidget);

    handle.dispose();
  });
}
