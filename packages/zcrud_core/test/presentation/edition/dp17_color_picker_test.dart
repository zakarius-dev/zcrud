// DP-17 (M14) — couleur : picker enrichi NEUTRE (built-in) + seam injectable.
//
// Couvre :
//  - palette historique préservée (tap swatch → onChanged ARGB) ;
//  - bouton « couleur personnalisée » → seam injecté (ZcrudScope.colorPicker)
//    prioritaire ;
//  - repli built-in NEUTRE : saisie hex → Apply → onChanged ARGB exact ;
//  - couleurs récentes (recentColors) rendues + sélectionnables ;
//  - défensif : hex invalide ignoré (aucun throw, aucune écriture avant Apply) ;
//  - config showPalette=false masque la palette (rétro-compat additive).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

Widget _host(Widget child, {ZColorPicker? colorPicker}) => MaterialApp(
      home: Scaffold(
        body: ZcrudScope(
          colorPicker: colorPicker,
          child: SingleChildScrollView(child: child),
        ),
      ),
    );

void main() {
  testWidgets('palette : tap swatch → onChanged reçoit un ARGB', (tester) async {
    int? captured;
    await tester.pumpWidget(_host(ZColorFieldWidget(
      field: const ZFieldSpec(name: 'c', type: EditionFieldType.color, label: 'C'),
      value: null,
      onChanged: (v) => captured = v,
    )));
    await tester.pump();
    // Bouton personnalisé présent.
    expect(find.text('Custom color…'), findsOneWidget);
    // Un swatch de palette porte un Semantics « Select a color #… ».
    final swatch = find.bySemanticsLabel(RegExp('Select a color #')).first;
    await tester.tap(swatch);
    await tester.pump();
    expect(captured, isNotNull);
    expect(captured! >> 24 & 0xFF, 0xFF); // alpha plein.
  });

  testWidgets('seam injecté prioritaire → onChanged reçoit sa valeur',
      (tester) async {
    int? captured;
    await tester.pumpWidget(_host(
      ZColorFieldWidget(
        field:
            const ZFieldSpec(name: 'c', type: EditionFieldType.color, label: 'C'),
        value: null,
        onChanged: (v) => captured = v,
      ),
      colorPicker: (context,
              {required initialArgb,
              required enableAlpha,
              required recentColors}) async =>
          0xFF123456,
    ));
    await tester.pump();
    await tester.tap(find.text('Custom color…'));
    await tester.pumpAndSettle();
    expect(captured, 0xFF123456);
  });

  testWidgets('built-in : hex → Apply → onChanged ARGB exact', (tester) async {
    int? captured;
    await tester.pumpWidget(_host(ZColorFieldWidget(
      field: const ZFieldSpec(name: 'c', type: EditionFieldType.color, label: 'C'),
      value: null,
      onChanged: (v) => captured = v,
    )));
    await tester.pump();
    await tester.tap(find.text('Custom color…'));
    await tester.pumpAndSettle();
    expect(find.text('Apply'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '#00FF00');
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(captured, 0xFF00FF00);
  });

  testWidgets('built-in : hex INVALIDE ignoré (aucun throw)', (tester) async {
    int? captured;
    await tester.pumpWidget(_host(ZColorFieldWidget(
      field: const ZFieldSpec(name: 'c', type: EditionFieldType.color, label: 'C'),
      value: null,
      onChanged: (v) => captured = v,
    )));
    await tester.pump();
    await tester.tap(find.text('Custom color…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'zzz-not-a-color');
    await tester.pump();
    expect(tester.takeException(), isNull);
    // Rien n'est écrit tant qu'Apply n'est pas pressé.
    expect(captured, isNull);
  });

  testWidgets('couleurs récentes rendues + sélectionnables', (tester) async {
    int? captured;
    await tester.pumpWidget(_host(ZColorFieldWidget(
      field: const ZFieldSpec(
        name: 'c',
        type: EditionFieldType.color,
        label: 'C',
        config: ZColorConfig(recentColors: <int>[0xFFFF0000]),
      ),
      value: null,
      onChanged: (v) => captured = v,
    )));
    await tester.pump();
    await tester.tap(find.text('Custom color…'));
    await tester.pumpAndSettle();
    expect(find.text('Recent'), findsOneWidget);
    // La récente (#FFFF0000) est un swatch dans le dialog ; la sélectionner puis
    // Apply → onChanged reçoit exactement le rouge opaque.
    await tester.tap(find.bySemanticsLabel('#FFFF0000').first);
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(captured, 0xFFFF0000);
  });

  testWidgets('showPalette=false masque la palette', (tester) async {
    await tester.pumpWidget(_host(ZColorFieldWidget(
      field: const ZFieldSpec(
        name: 'c',
        type: EditionFieldType.color,
        label: 'C',
        config: ZColorConfig(showPalette: false),
      ),
      value: null,
      onChanged: (_) {},
    )));
    await tester.pump();
    // Aucun swatch de palette (Semantics « Select a color #… ») ; seul le bouton
    // personnalisé subsiste.
    expect(find.bySemanticsLabel(RegExp('Select a color #')), findsNothing);
    expect(find.text('Custom color…'), findsOneWidget);
  });
}
