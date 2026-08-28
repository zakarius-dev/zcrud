/// CR-IFFD-127 ❷ — l'élévation de la carte d'un message.
///
/// * **E1 (inertie, mesure ABSOLUE)** — `elevation` nul ⇒ la carte est
///   peinte par un seul `DecoratedBox` dont la décoration est, à l'objet
///   près, celle d'avant ce lot (aucune ombre, aucun `Material`, aucun
///   `PhysicalModel`), et sa géométrie est celle de la référence : les
///   chiffres ci-dessous ont été mesurés sur le code d'AVANT le lot, et ce
///   fichier a été vert contre lui avant que l'élévation n'existe.
/// * **E2 (effet)** — `elevation: 2` ⇒ la décoration porte des ombres dont
///   la couleur dérive de `shadowColor` ; l'arbre reste le même
///   `DecoratedBox` (pas de nœud ajouté), la géométrie ne bouge pas.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import 'support/z_chat_render_harness.dart';

Widget _tile(ZChatTileShell shell) => harness(
  Align(
    alignment: AlignmentDirectional.topStart,
    child: SizedBox(
      width: 400,
      child: ZChatMessageTile(
        message: assistant(const <ZContentBlock>[ZTextBlock(text: 'corps')]),
        shell: shell,
      ),
    ),
  ),
);

/// Le `DecoratedBox` de la carte : celui qui porte un `BoxDecoration` à
/// `borderRadius` — il n'y en a qu'un sous la tuile.
Finder get _card => find.descendant(
  of: find.byType(ZChatMessageTile),
  matching: find.byWidgetPredicate(
    (Widget w) =>
        w is DecoratedBox &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).borderRadius != null,
  ),
);

BoxDecoration _decorationOf(WidgetTester tester) =>
    tester.widget<DecoratedBox>(_card).decoration as BoxDecoration;

void main() {
  group('CR127-E1 — inertie : `elevation` nul ⇒ rendu d\'avant, absolu', () {
    testWidgets('un seul DecoratedBox, sans ombre, géométrie de référence', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_tile(const ZChatTileShell()));
      expect(_card, findsOneWidget);
      final BoxDecoration decoration = _decorationOf(tester);
      // La décoration, champ par champ : rien d'autre que ce qui existait.
      expect(decoration.boxShadow, isNull);
      expect(decoration.color, isNull);
      expect(decoration.gradient, isNull);
      expect(decoration.image, isNull);
      expect(decoration.shape, BoxShape.rectangle);
      expect(decoration.border, isNotNull);
      expect(
        decoration.borderRadius,
        BorderRadius.all(ZChatNotebookReference.tileRadius),
      );
      // Aucune surface ajoutée pour porter une ombre absente.
      final Finder tile = find.byType(ZChatMessageTile);
      expect(
        find.descendant(of: tile, matching: find.byType(Material)),
        findsNothing,
      );
      expect(
        find.descendant(of: tile, matching: find.byType(PhysicalModel)),
        findsNothing,
      );
      expect(
        find.descendant(of: tile, matching: find.byType(PhysicalShape)),
        findsNothing,
      );
      // Géométrie ABSOLUE : la carte commence à la marge de référence, sur
      // toute la largeur restante — chiffres pris sur le code d'avant.
      final Rect card = tester.getRect(_card);
      expect(card.left, moreOrLessEquals(0, epsilon: 0.01));
      expect(card.top, moreOrLessEquals(4, epsilon: 0.01));
      expect(card.right, moreOrLessEquals(400, epsilon: 0.01));
      expect(card.height, greaterThan(16));
    });
  });

  group('CR127-E2 — effet : une élévation posée peint une ombre', () {
    const Color shadow = Color(0xFF123456);

    testWidgets('`elevation: 2` ⇒ ombres dans la MÊME décoration, teintées de '
        '`shadowColor`, géométrie inchangée', (WidgetTester tester) async {
      await tester.pumpWidget(
        _tile(const ZChatTileShell(elevation: 2, shadowColor: shadow)),
      );
      expect(_card, findsOneWidget);
      final BoxDecoration decoration = _decorationOf(tester);
      final List<BoxShadow>? shadows = decoration.boxShadow;
      expect(shadows, isNotNull, reason: '🔴 aucune ombre peinte');
      expect(shadows!, isNotEmpty);
      for (final BoxShadow s in shadows) {
        // La teinte de l'hôte, à l'opacité près — jamais la référence.
        expect(s.color.withValues(alpha: 1), shadow);
        expect(s.color.a, lessThan(1));
        expect(s.color.a, greaterThan(0));
        expect(s.blurRadius, greaterThan(0));
      }
      // L'ombre est PORTÉE : au moins une ombre décalée vers le bas d'au
      // moins l'élévation (lumière de dessus, comme Material).
      expect(
        shadows
            .map((BoxShadow s) => s.offset.dy)
            .reduce((double a, double b) => a > b ? a : b),
        greaterThanOrEqualTo(2),
      );
      // Toujours un seul DecoratedBox, aucune surface ajoutée.
      final Finder tile = find.byType(ZChatMessageTile);
      expect(
        find.descendant(of: tile, matching: find.byType(PhysicalModel)),
        findsNothing,
      );
      expect(
        find.descendant(of: tile, matching: find.byType(Material)),
        findsNothing,
      );
      final Rect card = tester.getRect(_card);
      expect(card.left, moreOrLessEquals(0, epsilon: 0.01));
      expect(card.top, moreOrLessEquals(4, epsilon: 0.01));
      expect(card.right, moreOrLessEquals(400, epsilon: 0.01));
    });

    testWidgets('sans `shadowColor`, la teinte est la référence ; '
        '`elevation: 0` et une valeur négative ne peignent rien', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_tile(const ZChatTileShell(elevation: 1)));
      final List<BoxShadow> shadows = _decorationOf(tester).boxShadow!;
      expect(shadows, isNotEmpty);
      expect(
        shadows.first.color.withValues(alpha: 1),
        ZChatNotebookReference.tileShadowColor,
      );
      await tester.pumpWidget(_tile(const ZChatTileShell(elevation: 0)));
      expect(_decorationOf(tester).boxShadow, isNull);
      await tester.pumpWidget(_tile(const ZChatTileShell(elevation: -3)));
      expect(_decorationOf(tester).boxShadow, isNull);
    });

    test('la table d\'ombres croît avec l\'élévation', () {
      const Color c = Color(0xFF000000);
      expect(zChatTileElevationShadows(0, c), isEmpty);
      final List<BoxShadow> one = zChatTileElevationShadows(1, c);
      final List<BoxShadow> four = zChatTileElevationShadows(4, c);
      expect(one.length, four.length);
      for (int i = 0; i < one.length; i++) {
        expect(four[i].blurRadius, greaterThan(one[i].blurRadius));
        expect(four[i].offset.dy, greaterThan(one[i].offset.dy));
      }
    });
  });
}
