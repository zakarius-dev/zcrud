/// CR-LEX-73 (volet `ZFolderCard`) — la marge du `CardTheme` de l'hôte est
/// restituée, au lieu d'être écrasée par un `EdgeInsets.zero` figé.
///
/// lex demandait la correction sur les **deux** widgets porteurs du défaut
/// (`ZStudyToolsItemCard` et `ZFolderCard`), « pour ne pas la voir réapparaître
/// au troisième ». Ce fichier couvre le second.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_study/zcrud_study.dart';

Future<void> _pump(
  WidgetTester tester, {
  EdgeInsetsGeometry? themeMargin,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        cardTheme: themeMargin == null
            ? const CardThemeData()
            : CardThemeData(margin: themeMargin),
      ),
      home: const Scaffold(
        body: ZFolderCard(title: 'Valeur en douane', colorKey: 'primary'),
      ),
    ),
  );
}

EdgeInsetsGeometry? _margin(WidgetTester tester) =>
    tester.widget<Card>(find.byType(Card)).margin;

void main() {
  group('CR-LEX-73 — marge de ZFolderCard', () {
    testWidgets('sans CardTheme.margin, la marge reste NULLE (défaut inchangé)', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      expect(
        _margin(tester),
        EdgeInsets.zero,
        reason:
            'le défaut ne doit pas bouger : un hôte qui ne déclare rien garde '
            'exactement le rendu v0.21.0',
      );
    });

    testWidgets('la marge du CardTheme de l\'hôte est RESTITUÉE', (
      WidgetTester tester,
    ) async {
      await _pump(tester, themeMargin: const EdgeInsets.all(4));
      // 🔴 GARDE CR-73. Avant correction, `margin: EdgeInsets.zero` était figé :
      // la marge 4 d'IFFD passait donc par un `Padding` externe que lex ajoutait
      // dans son adaptateur — et que tout autre hôte aurait dû réécrire.
      // Régression à ré-injecter pour prouver que cette garde mord : remettre
      // `margin: EdgeInsets.zero` au site de construction du `Card`.
      expect(
        _margin(tester),
        const EdgeInsets.all(4),
        reason:
            'la décision de l\'hôte fait foi : le widget ne doit pas la '
            'recouvrir par une valeur figée',
      );
    });

    testWidgets('une marge directionnelle survit telle quelle (AD-13)', (
      WidgetTester tester,
    ) async {
      const EdgeInsetsDirectional directionnelle = EdgeInsetsDirectional.only(
        start: 8,
        end: 2,
      );
      await _pump(tester, themeMargin: directionnelle);
      // Le widget ne doit pas « normaliser » la marge en coordonnées physiques :
      // ce serait perdre l'inversion RTL que l'hôte a explicitement demandée.
      expect(_margin(tester), directionnelle);
    });
  });
}
