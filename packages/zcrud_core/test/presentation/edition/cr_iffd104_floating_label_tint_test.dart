// CR-IFFD-104 — la teinte PAR TYPE DE CHAMP atteint le LIBELLÉ FLOTTANT,
// sur la même grammaire opt-in que la bordure de focus et les icônes
// (CR-IFFD-96) : sans résolveur, rendu inchangé au pixel ; avec résolveur,
// la couleur appliquée est NORMALISÉE (`zReadableTintOn`, plancher non-texte
// WCAG §1.4.11) contre la surface du champ.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const ZFieldSpec _field = ZFieldSpec(
  name: 'nom',
  type: EditionFieldType.text,
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
  testWidgets(
      '🔴 ÉTALON : sans résolveur (avec ou sans scope), le style du libellé '
      'flottant est celui d\'avant — poids seul, AUCUNE couleur posée', (
    tester,
  ) async {
    final c = ZFormController();
    final without = await _pumpDecoration(tester, c, withScope: false);
    final scoped = await _pumpDecoration(tester, c);
    for (final deco in [without, scoped]) {
      final style = deco.floatingLabelStyle!;
      expect(style.color, isNull,
          reason: 'sans déclaration, aucune couleur n\'entre dans le style '
              'flottant — pixel-identique à l\'antérieur');
      expect(style.fontWeight, FontWeight.bold,
          reason: 'le jeton de poids reste le seul canal appliqué');
    }
    c.dispose();
  });

  testWidgets(
      '🔴 avec résolveur, le libellé flottant porte la MÊME teinte que la '
      'bordure de focus — normalisée au plancher de contraste', (tester) async {
    final c = ZFormController();
    // Jaune pur : illisible sur la surface claire du champ — le cas que la
    // normalisation DOIT corriger avant toute application.
    const Color yellow = Color(0xFFFFFF00);
    final deco = await _pumpDecoration(
      tester,
      c,
      resolver: (scheme, key) => key == zFieldTypeTintKey(EditionFieldType.text)
          ? const ZGradientSpec(
              gradient: LinearGradient(colors: [yellow, yellow]),
              onGradient: Color(0xFF000000),
            )
          : null,
    );
    final applied =
        (deco.focusedBorder! as OutlineInputBorder).borderSide.color;
    final labelColor = deco.floatingLabelStyle!.color;
    expect(labelColor, isNotNull,
        reason: 'la teinte déclarée doit atteindre le libellé flottant');
    expect(labelColor, applied,
        reason: 'un seul canal de teinte : le libellé flottant porte '
            'EXACTEMENT la couleur de la bordure de focus');
    expect(labelColor, isNot(yellow),
        reason: 'une couleur illisible ne doit JAMAIS être appliquée brute');
    final surface = ThemeData().colorScheme.surfaceContainerHighest;
    expect(zContrastRatio(labelColor!, surface),
        greaterThanOrEqualTo(kZNonTextMinContrast),
        reason: 'plancher WCAG §1.4.11 mesuré contre la surface du champ');
    c.dispose();
  });

  testWidgets(
      'une teinte DÉJÀ lisible atteint le libellé flottant inchangée (le '
      'choix de l\'hôte n\'est pas réécrit sans nécessité)', (tester) async {
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
    expect(deco.floatingLabelStyle!.color, readable);
    expect(deco.floatingLabelStyle!.fontWeight, FontWeight.bold,
        reason: 'la teinte n\'évince pas le jeton de poids');
    c.dispose();
  });
}
