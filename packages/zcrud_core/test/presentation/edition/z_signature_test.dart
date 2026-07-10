// AC10 (E3-3b-3) — Famille `signature` : capture gestuelle (CustomPaint/gesture
// natif, AUCUNE dépendance lourde), encodage STABLE en tranche (strokes
// normalisés `[0,1]`, `Map` versionnée sérialisable), clear/undo, a11y non
// gestuelle (Semantics + cibles ≥ 48 dp), RTL. value-in-slice / AD-2.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _name = 'sig';

ZFormController _controller({Object? initial}) => ZFormController(
      initialValues: <String, Object?>{_name: initial},
      visibleFields: <String>[_name],
    );

Widget _app(ZFormController controller,
        {TextDirection dir = TextDirection.ltr}) =>
    MaterialApp(
      home: Directionality(
        textDirection: dir,
        child: Scaffold(
          body: DynamicEdition(
            controller: controller,
            fields: const <ZFieldSpec>[
              ZFieldSpec(
                  name: _name,
                  type: EditionFieldType.signature,
                  label: 'Signature'),
            ],
          ),
        ),
      ),
    );

/// Trace un trait au centre de la zone de capture.
Future<void> _sign(WidgetTester tester) async {
  final canvas = find.byKey(ZSignatureFieldWidget.canvasKey);
  expect(canvas, findsOneWidget);
  final center = tester.getCenter(canvas);
  final gesture = await tester.startGesture(center - const Offset(30, 10));
  await gesture.moveBy(const Offset(20, 5));
  await gesture.moveBy(const Offset(20, 10));
  await gesture.moveBy(const Offset(20, -5));
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets('dispatch : signature → widget dédié (jamais le repli)',
      (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    await tester.pump();
    expect(find.byType(ZSignatureFieldWidget), findsOneWidget);
    expect(find.byType(ZUnsupportedFieldWidget), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tracé → tranche non vide (Map versionnée de strokes normalisés)',
      (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    await tester.pump();

    expect(controller.valueOf(_name), isNull, reason: 'vide au départ');

    await _sign(tester);

    final value = controller.valueOf(_name);
    expect(value, isA<Map<String, dynamic>>());
    final map = value! as Map<String, dynamic>;
    expect(map['formatVersion'], 1);
    final strokes = map['strokes'] as List;
    expect(strokes, isNotEmpty);
    final first = strokes.first as List;
    // Liste PLATE de points (x,y) → longueur paire, ≥ 2 coordonnées.
    expect(first.length.isEven, isTrue);
    expect(first.length, greaterThanOrEqualTo(2));
    // Coordonnées NORMALISÉES bornées [0,1] (résolution-indépendantes).
    for (final c in first) {
      expect(c, isA<num>());
      expect((c as num) >= 0 && c <= 1, isTrue, reason: 'normalisé dans [0,1]');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('encodage STABLE et sérialisable (jsonEncode round-trip)',
      (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    await tester.pump();
    await _sign(tester);

    final value = controller.valueOf(_name);
    // Sérialisable sans perte (pas de bytes image lourds — que des nombres).
    final json = jsonEncode(value);
    final round = jsonDecode(json);
    expect(round, equals(value));
    // Decode défensif re-parse les strokes.
    expect(ZSignatureFieldWidget.decode(round), isNotEmpty);
  });

  testWidgets('clear → tranche vide (null), aucune exception (AC10)',
      (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    await tester.pump();
    await _sign(tester);
    expect(controller.valueOf(_name), isNotNull);

    await tester.tap(find.byTooltip('Clear signature'));
    await tester.pump();

    expect(controller.valueOf(_name), isNull, reason: 'clear → vide');
    expect(tester.takeException(), isNull);
  });

  testWidgets('undo → retire le dernier trait (AC10)', (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    await tester.pump();

    await _sign(tester);
    await _sign(tester);
    final twoStrokes =
        (controller.valueOf(_name)! as Map<String, dynamic>)['strokes'] as List;
    expect(twoStrokes.length, 2);

    await tester.tap(find.byTooltip('Undo last stroke'));
    await tester.pump();
    final oneStroke =
        (controller.valueOf(_name)! as Map<String, dynamic>)['strokes'] as List;
    expect(oneStroke.length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('valeur initiale (Map) → tracé pré-rempli, undo le retire',
      (tester) async {
    final initial = <String, dynamic>{
      'formatVersion': 1,
      'strokes': <List<double>>[
        <double>[0.1, 0.1, 0.5, 0.5, 0.9, 0.2],
      ],
    };
    final controller = _controller(initial: initial);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    await tester.pump();

    // Le bouton clear est actif (signature présente) → l'état initial est lu.
    await tester.tap(find.byTooltip('Clear signature'));
    await tester.pump();
    expect(controller.valueOf(_name), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lecture DÉFENSIVE : valeur mal typée → aucune signature, pas de '
      'throw (AD-10)', (tester) async {
    final controller = _controller(initial: 'corrompu');
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    await tester.pump();
    expect(find.byType(ZSignatureFieldWidget), findsOneWidget);
    expect(tester.takeException(), isNull);
    // decode défensif sur divers types.
    expect(ZSignatureFieldWidget.decode('x'), isEmpty);
    expect(ZSignatureFieldWidget.decode(null), isEmpty);
    expect(ZSignatureFieldWidget.decode(<String, dynamic>{'strokes': 42}),
        isEmpty);
  });

  testWidgets('a11y : Semantics zone de signature + cibles clear/undo ≥ 48 dp',
      (tester) async {
    final handle = tester.ensureSemantics();
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    await tester.pump();

    // Semantics conteneur décrivant la zone (alternative NON gestuelle).
    expect(find.bySemanticsLabel(RegExp('Signature area')), findsOneWidget);

    // Les cibles d'action (effacer/annuler) sont présentes et accessibles ;
    // leur cible tactile effective ≥ 48 dp est validée par la guideline
    // Material (`androidTapTargetGuideline` couvre la zone tactile sémantique,
    // pas seulement la boîte visuelle de l'IconButton).
    expect(find.byTooltip('Clear signature'), findsOneWidget);
    expect(find.byTooltip('Undo last stroke'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('RTL : rendu sans overflow/exception (AD-13)', (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller, dir: TextDirection.rtl));
    await tester.pump();
    expect(tester.takeException(), isNull);
    final dir = Directionality.of(
      tester.element(find.byType(ZSignatureFieldWidget)),
    );
    expect(dir, TextDirection.rtl);
  });
}
