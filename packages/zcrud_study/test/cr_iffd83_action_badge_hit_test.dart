// CR-IFFD-83 — la pastille de compte ne VOLE plus le tap qu'elle surmonte.
//
// Défaut LIVRÉ en v3.0.0 : `Badge.count(child: tile)` empile son décor dans le
// MÊME `Stack` que la tuile, et ce décor est hit-testable — le
// `RenderDecoratedBox` du stade renvoie `hitTestSelf == true`. Le `Stack`
// s'arrête au premier enfant touché : le geste n'atteint jamais la tuile, et
// il n'émet RIEN (ni erreur, ni retour visuel).
//
// Ces gardes mesurent la GÉOMÉTRIE RÉELLE avant de taper : le point de tap est
// calculé comme le centre de l'intersection « tuile ∩ nombre », et son
// appartenance à la pastille est ASSERTÉE, jamais supposée. Une garde qui
// taperait à côté de la pastille serait verte pour la mauvaise raison.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study/zcrud_study.dart';

/// Libellé assez long pour que la tuile REMPLISSE la largeur de sa cellule :
/// sans cela la pastille — ancrée sur la cellule, pas sur la tuile — ne
/// recouvrirait aucun pixel tappable et la garde serait inerte.
const String kLongLabel = 'UN-LIBELLE-VRAIMENT-TRES-LONG-QUI-REMPLIT';
const String kShortLabel = 'SANS-COMPTE';
const int kCount = 12;

Future<int Function()> _openMenu(
  WidgetTester tester, {
  int? count = kCount,
  String label = kLongLabel,
}) async {
  int taps = 0;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ZcrudScope(
        child: Scaffold(
          body: Center(
            child: ZItemActionsMenu(
              actions: <ZItemAction>[
                ZItemAction(
                  kind: ZItemActionKind.custom,
                  id: 'with-artifact',
                  label: label,
                  icon: Icons.auto_awesome,
                  count: count,
                  onSelected: () => taps++,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byType(ZItemActionsMenu));
  await tester.pumpAndSettle();
  return () => taps;
}

Rect _tileRect(WidgetTester tester) =>
    tester.getRect(find.byType(ZMenuEntryTile));

/// Rectangle PEINT de la pastille : le stade décoré que Material empile.
Rect _pillRect(WidgetTester tester) => tester.getRect(
  find
      .descendant(of: find.byType(Badge), matching: find.byType(DecoratedBox))
      .first,
);

/// Rectangle de la CELLULE : `Badge` se dimensionne sur la contrainte de la
/// grille, jamais sur la tuile — c'est de cette boîte que Material dérive la
/// position du décor.
Rect _cellRect(WidgetTester tester) => tester.getRect(find.byType(Badge));

Rect _intersect(Rect a, Rect b) => Rect.fromLTRB(
  a.left > b.left ? a.left : b.left,
  a.top > b.top ? a.top : b.top,
  a.right < b.right ? a.right : b.right,
  a.bottom < b.bottom ? a.bottom : b.bottom,
);

void main() {
  group('CR-IFFD-83 — la pastille informe, elle ne capte pas', () {
    testWidgets(
      '🔴 un tap SOUS la pastille déclenche l’action (point prouvé, pas supposé)',
      (tester) async {
        final int Function() taps = await _openMenu(tester);

        final Rect tile = _tileRect(tester);
        final Rect pill = _pillRect(tester);
        final Rect number = tester.getRect(find.text('$kCount'));

        // 1. La pastille recouvre RÉELLEMENT des pixels tappables de la tuile.
        final Rect covered = _intersect(tile, pill);
        expect(
          covered.width > 0 && covered.height > 0,
          isTrue,
          reason:
              'Expected: la pastille recouvre une part de la tuile\n'
              'Actual: tuile=$tile pastille=$pill — aucun recouvrement, la '
              'garde taperait à côté et serait verte pour la mauvaise raison',
        );

        // 2. Le point visé est le centre de « tuile ∩ nombre » : à la fois dans
        //    la tuile, dans la pastille ET sous le glyphe — le sous-rectangle
        //    le plus absorbant de tous (`RenderParagraph.hitTestSelf`).
        final Rect target = _intersect(tile, number);
        expect(target.width > 0 && target.height > 0, isTrue);
        final Offset point = target.center;
        expect(
          tile.contains(point),
          isTrue,
          reason: 'le point doit tomber DANS la cible tactile de l’action',
        );
        expect(
          pill.contains(point),
          isTrue,
          reason:
              'Expected: point $point sous la pastille $pill\n'
              'Actual: hors pastille — la garde ne mesurerait pas le défaut',
        );
        // Distance au coin haut-fin : l’ordre de grandeur du geste réel décrit
        // par la CR (≈ 6 dp du coin).
        expect((tile.topRight - point).distance, lessThan(16));

        await tester.tapAt(point);
        await tester.pumpAndSettle();

        expect(
          taps(),
          1,
          reason:
              'Expected: 1 déclenchement pour un tap sous la pastille\n'
              'Actual: ${taps()} — la pastille absorbe encore le geste '
              '(CR-IFFD-83)',
        );
      },
    );

    testWidgets('contre-témoin — le tap au CENTRE déclenche toujours', (
      tester,
    ) async {
      final int Function() taps = await _openMenu(tester);
      final Rect tile = _tileRect(tester);
      await tester.tapAt(tile.center);
      await tester.pumpAndSettle();
      expect(
        taps(),
        1,
        reason:
            'Expected: 1 déclenchement au centre\n'
            'Actual: ${taps()} — le correctif a cassé la cible elle-même',
      );
    });

    testWidgets(
      'contre-témoin — sans compte : mêmes COMPTES ABSOLUS et tap intact',
      (tester) async {
        final int Function() taps = await _openMenu(
          tester,
          count: null,
          label: kShortLabel,
        );

        expect(find.byType(Badge), findsNothing);
        expect(
          find.descendant(
            of: find.byType(ZMenuEntryTile),
            matching: find.byType(IgnorePointer),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(GridView),
            matching: find.byType(Stack),
          ),
          findsNothing,
          reason:
              'une action sans compte ne reçoit AUCUN empilement additionnel',
        );

        final Rect tile = _tileRect(tester);
        await tester.tapAt(tile.topRight + const Offset(-6, 6));
        await tester.pumpAndSettle();
        expect(taps(), 1);
      },
    );

    testWidgets('🔴 le compte reste ANNONCÉ après neutralisation du pointeur', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _openMenu(tester);

      final Finder merged = find
          .ancestor(
            of: find.text(kLongLabel),
            matching: find.byType(MergeSemantics),
          )
          .first;
      final data = tester.getSemantics(merged).getSemanticsData();
      expect(
        '${data.label} ${data.value}',
        contains('$kCount'),
        reason:
            'Expected: le compte $kCount annoncé\n'
            'Actual: label="${data.label}" value="${data.value}" — un '
            'IgnorePointer mal posé retire aussi le nœud sémantique',
      );
      handle.dispose();
    });

    testWidgets('🔴 le RENDU est inchangé : pastille au pixel de Material', (
      tester,
    ) async {
      await _openMenu(tester);

      final Rect cell = _cellRect(tester);
      final Rect tile = _tileRect(tester);
      final Rect pill = _pillRect(tester);

      expect(find.text('$kCount'), findsOneWidget);
      // Ancrage Material : `AlignmentDirectional.topEnd`, décalage (4, -4) puis
      // (0, 8), moins la moitié de `largeSize` (16) ⇒ le stade se pose à
      // `cell.right - 12` et `cell.top - 4`. Tout déplacement d'un pixel du
      // montage rougit ici.
      expect(pill.left, closeTo(cell.right - 12, 0.01));
      expect(pill.top, closeTo(cell.top - 4, 0.01));
      expect(pill.height, closeTo(16, 0.01));
      // La tuile n'a pas bougé : même origine et même largeur que sa cellule.
      expect(tile.topLeft, cell.topLeft);
      expect(tile.width, closeTo(cell.width, 0.01));
    });
  });
}
