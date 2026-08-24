// CR-IFFD-96 — la teinte PAR TYPE DE CHAMP atteint la décoration (bordure de
// focus, couleur des icônes d'ornement) SANS devenir l'UI par défaut.
//
// Cadrage propriétaire gardé à la lettre :
// - aucune déclaration ⇒ ÉTALON : décoration identique (aucune teinte, aucun
//   canal modifié) ;
// - la couleur passée est NORMALISÉE pour le contraste (`zReadableTintOn`,
//   plancher non-texte 3.0:1) — jamais appliquée telle quelle si illisible ;
// - les présets du socle sont des DONNÉES copiables, jamais lues par `lib/`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../../support/z_sources.dart' as sources;

const ZFieldSpec _field = ZFieldSpec(
  name: 'nom',
  type: EditionFieldType.text,
  prefix: ZFieldAdornment.icon('person'),
);

Future<InputDecoration> _pumpDecoration(
  WidgetTester tester,
  ZFormController c, {
  ZGradientResolver? resolver,
  bool withScope = true,
}) async {
  final child = ZFieldWidget(controller: c, field: _field);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: withScope
          ? ZcrudScope(gradientResolver: resolver, child: child)
          : child,
    ),
  ));
  return tester.widget<TextField>(find.byType(TextField)).decoration!;
}

void main() {
  testWidgets('🔴 ÉTALON : sans résolveur (avec ou sans scope), la décoration '
      'est celle d\'avant — focus au rôle du thème, icônes non teintées', (
    tester,
  ) async {
    final c = ZFormController();
    final without = await _pumpDecoration(tester, c, withScope: false);
    final scoped = await _pumpDecoration(tester, c);
    final primary = ThemeData().colorScheme.primary;
    for (final deco in [without, scoped]) {
      expect((deco.focusedBorder! as OutlineInputBorder).borderSide.color,
          primary,
          reason: 'sans déclaration, la bordure de focus reste `primary`');
      expect(deco.prefixIconColor, isNull);
      expect(deco.suffixIconColor, isNull);
      expect(deco.iconColor, isNull);
    }
    c.dispose();
  });

  testWidgets('🔴 avec résolveur, la teinte atteint bordure de focus ET '
      'icônes — NORMALISÉE au plancher de contraste 3.0:1', (tester) async {
    final c = ZFormController();
    // Jaune pur : illisible sur une surface claire (contraste ≈ 1.07 mesuré
    // contre `surfaceContainerHighest`) — le cas que la normalisation DOIT
    // corriger.
    const Color yellow = Color(0xFFFFFF00);
    final deco = await _pumpDecoration(
      tester,
      c,
      resolver: (scheme, key) =>
          key == zFieldTypeTintKey(EditionFieldType.text)
              ? const ZGradientSpec(
                  gradient: LinearGradient(colors: [yellow, yellow]),
                  onGradient: Color(0xFF000000),
                )
              : null,
    );
    final applied =
        (deco.focusedBorder! as OutlineInputBorder).borderSide.color;
    final surface = ThemeData().colorScheme.surfaceContainerHighest;
    expect(applied, isNot(ThemeData().colorScheme.primary),
        reason: 'la teinte déclarée doit atteindre la bordure de focus');
    expect(applied, isNot(yellow),
        reason: 'une couleur illisible ne doit JAMAIS être appliquée brute');
    expect(zContrastRatio(applied, surface),
        greaterThanOrEqualTo(kZNonTextMinContrast),
        reason: 'plancher WCAG §1.4.11 mesuré contre la surface du champ');
    expect(deco.prefixIconColor, applied,
        reason: 'la pastille d\'icône porte la même teinte');
    expect(deco.suffixIconColor, applied);
    c.dispose();
  });

  testWidgets('une teinte DÉJÀ lisible est appliquée inchangée (le choix de '
      'l\'hôte n\'est pas réécrit sans nécessité)', (tester) async {
    final c = ZFormController();
    const Color readable = Color(0xFF1732AB);
    final deco = await _pumpDecoration(
      tester,
      c,
      resolver: (scheme, key) => const ZGradientSpec(
        gradient: LinearGradient(colors: [readable, readable]),
        onGradient: Color(0xFFFFFFFF),
      ),
    );
    expect((deco.focusedBorder! as OutlineInputBorder).borderSide.color,
        readable);
    c.dispose();
  });

  test('🔴 les présets sont des DONNÉES : aucun site de `lib/` ne les lit '
      '(hors leur propre déclaration)', () {
    final offenders = <String>[
      for (final f in sources.libDartFiles())
        if (!f.path.endsWith('z_field_tint_presets.dart') &&
            sources.strippedSource(f).contains('ZFieldTintPresets'))
          f.path,
    ];
    expect(offenders, isEmpty,
        reason: 'un préset consommé par le socle serait un DÉFAUT ACTIF '
            '(FR-26) — les présets sont copiables par l\'hôte, jamais lus : '
            '$offenders');
  });
}
