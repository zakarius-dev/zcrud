// La pastille de compte ne RÉTRÉCIT plus la tuile qu'elle décore.
//
// Défaut mesuré : `_ZItemActionGridTile` empile la pastille et la tuile dans un
// `Stack` dont le `fit` par défaut (`StackFit.loose`) donne à ses enfants NON
// positionnés une contrainte LÂCHE. La tuile se rend alors à sa taille
// intrinsèque au lieu de remplir la cellule que la grille lui a réservée :
//
// | tuile d'action (libellé long) | dimensions mesurées |
// |---|---|
// | **avec** compte | `93,3 × 48` |
// | **sans** compte | `93,3 × 96` |
//
// La moitié BASSE de la cellule est donc morte pour toute action portant un
// compte — bien plus de surface perdue que le rectangle de la pastille
// lui-même (CR-IFFD-83). Avec un libellé COURT le rétrécissement est aussi
// horizontal (`48 × 48`) et la pastille, ancrée sur la CELLULE, se pose
// entièrement HORS de la tuile.
//
// Ces gardes mesurent la GÉOMÉTRIE (hauteur, largeur, position du glyphe et
// déclenchement réel), jamais une apparence. Le plancher asserté est la
// contrainte DÉCLARÉE par le socle (`mainAxisExtent: kZMenuMinTapTarget * 2`),
// pas le plancher de 48 dp que le SDK imposerait de toute façon.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study/zcrud_study.dart';

/// Libellé assez long pour que la tuile SANS compte remplisse la largeur de sa
/// cellule : c'est la référence à laquelle la tuile AVEC compte est comparée.
const String kLongLabel = 'UN-LIBELLE-VRAIMENT-TRES-LONG-QUI-REMPLIT';

/// Libellé COURT : il rend visible le rétrécissement HORIZONTAL, invisible
/// avec un libellé long (la tuile y est déjà bornée par la cellule).
const String kShortLabel = 'AB';

const int kCount = 12;

/// Extension de cellule DÉCLARÉE par `_ZDefaultItemActionGrid`
/// (`mainAxisExtent: kZMenuMinTapTarget * 2`). C'est ce contrat-là que les
/// gardes assertent — pas le plancher de 48 dp du SDK.
const double kDeclaredCellExtent = kZMenuMinTapTarget * 2;

Future<int Function()> _openMenu(
  WidgetTester tester, {
  required String label,
  int? count = kCount,
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

/// Ouvre un menu portant DEUX actions dans la MÊME grille : la première avec un
/// compte, la seconde sans. Comparer deux cellules d'une même rangée est plus
/// fort que comparer deux rendus successifs : la disposition, le thème et les
/// contraintes y sont rigoureusement identiques.
Future<List<int> Function()> _openPair(
  WidgetTester tester, {
  required String label,
}) async {
  final List<int> taps = <int>[0, 0];
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
                  id: 'with-count',
                  label: label,
                  icon: Icons.auto_awesome,
                  count: kCount,
                  onSelected: () => taps[0]++,
                ),
                ZItemAction(
                  kind: ZItemActionKind.custom,
                  id: 'without-count',
                  label: label,
                  icon: Icons.bolt,
                  onSelected: () => taps[1]++,
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

/// Tuile de l'action PORTANT le compte (première cellule de la rangée).
Rect _tileWithCount(WidgetTester tester) => tester.getRect(
  find.ancestor(
    of: find.byIcon(Icons.auto_awesome),
    matching: find.byType(ZMenuEntryTile),
  ),
);

/// Tuile de RÉFÉRENCE, sans compte (seconde cellule de la même rangée).
Rect _tileWithoutCount(WidgetTester tester) => tester.getRect(
  find.ancestor(
    of: find.byIcon(Icons.bolt),
    matching: find.byType(ZMenuEntryTile),
  ),
);

Rect _tileRect(WidgetTester tester) =>
    tester.getRect(find.byType(ZMenuEntryTile));

/// Rectangle de la CELLULE de grille : `Badge` est posé en `Positioned.fill`,
/// il épouse donc la boîte que la grille a réservée à l'action — la surface
/// que la tuile DEVRAIT occuper entièrement.
Rect _cellRect(WidgetTester tester) => tester.getRect(find.byType(Badge));

Rect _pillRect(WidgetTester tester) => tester.getRect(
  find
      .descendant(of: find.byType(Badge), matching: find.byType(DecoratedBox))
      .first,
);

void main() {
  group('tuile d’action — la pastille décore, elle ne RÉTRÉCIT pas', () {
    testWidgets(
      '🔴 la tuile AVEC compte occupe toute la hauteur DÉCLARÉE de sa cellule',
      (tester) async {
        await _openMenu(tester, label: kLongLabel);

        final Rect tile = _tileRect(tester);
        final Rect cell = _cellRect(tester);

        expect(
          tile.height,
          closeTo(kDeclaredCellExtent, 0.01),
          reason:
              'Expected: hauteur de tuile = $kDeclaredCellExtent dp '
              '(mainAxisExtent DÉCLARÉ par _ZDefaultItemActionGrid)\n'
              'Actual: ${tile.height} — le Stack de la pastille donne une '
              'contrainte LÂCHE à la tuile, qui se replie sur sa taille '
              'intrinsèque et laisse morte la moitié basse de la cellule',
        );
        expect(
          tile.height,
          closeTo(cell.height, 0.01),
          reason:
              'Expected: la tuile épouse la cellule $cell\n'
              'Actual: tuile=$tile — surface tactile perdue de '
              '${(cell.height - tile.height).toStringAsFixed(1)} dp',
        );
        expect(tile.topLeft, cell.topLeft);
      },
    );

    testWidgets(
      '🔴 la tuile AVEC compte a la MÊME géométrie que sa voisine SANS compte',
      (tester) async {
        await _openPair(tester, label: kLongLabel);

        final Rect avecCompte = _tileWithCount(tester);
        final Rect sansCompte = _tileWithoutCount(tester);

        expect(
          avecCompte.size,
          sansCompte.size,
          reason:
              'Expected: même taille que la cellule voisine sans compte '
              '(${sansCompte.size})\n'
              'Actual: ${avecCompte.size} — la pastille change la géométrie '
              'de la cible tactile',
        );
      },
    );

    testWidgets(
      '🔴 libellé COURT : la tuile ne rétrécit pas non plus en LARGEUR '
      '(sinon la pastille se pose HORS d’elle)',
      (tester) async {
        await _openPair(tester, label: kShortLabel);

        final Rect avecCompte = _tileWithCount(tester);
        final Rect sansCompte = _tileWithoutCount(tester);
        final Rect pill = _pillRect(tester);

        expect(
          avecCompte.width,
          closeTo(sansCompte.width, 0.01),
          reason:
              'Expected: largeur ${sansCompte.width} (celle de la cellule)\n'
              'Actual: ${avecCompte.width} — la tuile se replie sur le '
              'libellé court, et la pastille $pill se pose alors hors d’elle, '
              'à cheval sur la cellule voisine',
        );
        expect(
          avecCompte.right,
          greaterThan(pill.left),
          reason:
              'Expected: la pastille $pill surplombe la tuile $avecCompte\n'
              'Actual: pastille entièrement à l’extérieur — elle décore une '
              'cellule voisine',
        );
      },
    );

    testWidgets(
      '🔴 dans la MÊME grille, le glyphe est à la même hauteur avec et sans '
      'compte',
      (tester) async {
        await _openPair(tester, label: kLongLabel);

        final Rect avecCompte = tester.getRect(find.byIcon(Icons.auto_awesome));
        final Rect sansCompte = tester.getRect(find.byIcon(Icons.bolt));

        expect(
          avecCompte.center.dy,
          closeTo(sansCompte.center.dy, 0.01),
          reason:
              'Expected: deux glyphes ALIGNÉS dans la même rangée '
              '(dy=${sansCompte.center.dy})\n'
              'Actual: le glyphe de l’action AVEC compte est à '
              '${avecCompte.center.dy}, soit '
              '${(sansCompte.center.dy - avecCompte.center.dy).toStringAsFixed(1)} dp '
              'plus haut — sa tuile est rétrécie',
        );
      },
    );

    testWidgets(
      '🔴 un tap dans la MOITIÉ BASSE de la cellule déclenche l’action',
      (tester) async {
        final int Function() taps = await _openMenu(tester, label: kLongLabel);

        final Rect cell = _cellRect(tester);
        final Rect pill = _pillRect(tester);
        final Offset point = Offset(cell.center.dx, cell.bottom - 12);

        // Le point visé est bien dans la moitié basse, et il n'a RIEN à voir
        // avec la pastille (défaut distinct de CR-IFFD-83).
        expect(point.dy, greaterThan(cell.center.dy));
        expect(
          pill.contains(point),
          isFalse,
          reason: 'ce point ne doit pas retomber sur le défaut CR-IFFD-83',
        );

        await tester.tapAt(point);
        await tester.pumpAndSettle();

        expect(
          taps(),
          1,
          reason:
              'Expected: 1 déclenchement pour un tap à $point, dans la cellule '
              '$cell\n'
              'Actual: ${taps()} — la moitié basse de la cellule est morte, '
              'la tuile ne s’y étend pas',
        );
      },
    );

    testWidgets('la pastille reste au PIXEL de Material, compte ANNONCÉ', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _openMenu(tester, label: kLongLabel);

      final Rect cell = _cellRect(tester);
      final Rect pill = _pillRect(tester);
      final Rect tile = _tileRect(tester);

      // La boîte du décor coïncide avec la tuile — donc avec la cellule. Sans
      // cette assertion ABSOLUE, les suivantes seraient purement RELATIVES à
      // une boîte qui aurait pu se déplacer en bloc (mesuré : une injection
      // `Positioned.fill(right: 20)` les laissait toutes vertes).
      expect(
        cell,
        tile,
        reason:
            'Expected: le décor de la pastille épouse la tuile $tile\n'
            'Actual: $cell — la pastille est ancrée sur une autre boîte que '
            'la cellule, son rendu se déplace en bloc',
      );

      // Ancrage Material inchangé : stade à `cell.right - 12` / `cell.top - 4`.
      expect(pill.left, closeTo(cell.right - 12, 0.01));
      expect(pill.top, closeTo(cell.top - 4, 0.01));
      expect(pill.height, closeTo(16, 0.01));
      expect(find.text('$kCount'), findsOneWidget);

      final data = tester
          .getSemantics(
            find
                .ancestor(
                  of: find.text(kLongLabel),
                  matching: find.byType(MergeSemantics),
                )
                .first,
          )
          .getSemanticsData();
      expect('${data.label} ${data.value}', contains('$kCount'));
      handle.dispose();
    });
  });
}
