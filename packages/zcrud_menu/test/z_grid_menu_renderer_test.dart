// Gardes du rendu de menu en GRILLE et du geste CONTEXTUEL.
//
// Ce que ces gardes tiennent, et qui a déjà été manqué sur un rendu réel :
//   * un tap sur une cellule de grille invoque l'action UNE SEULE FOIS — deux
//     détecteurs superposés (un `InkWell` de disposition par-dessus celui de la
//     cellule) produisent deux invocations, et rien à l'écran ne le montre ;
//   * la cible tactile de 48 dp est tenue par la DISPOSITION, pas par la
//     cellule seule (un enfant ne peut pas se rendre plus grand que la place
//     reçue) ;
//   * le libellé d'une entrée est annoncé UNE fois, pas deux ;
//   * le renderer employé est celui du scope ambiant, y compris pour le geste
//     contextuel.
import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_menu/zcrud_menu.dart';

/// Monte [child] dans une app Material minimale.
Future<void> pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Center(child: child))),
  );
  await tester.pumpAndSettle();
}

/// Renderer OBSERVABLE : compte les deux voies (déclencheur et position) et
/// délègue au rendu par défaut, pour rester fonctionnel.
class SpyRenderer extends ZMenuRenderer {
  SpyRenderer();

  int builds = 0;
  int opens = 0;

  @override
  Widget build(BuildContext context, ZMenuRequest request) {
    builds++;
    return const ZDefaultMenuRenderer().build(context, request);
  }

  @override
  Future<void> openAt(
    BuildContext context,
    ZMenuRequest request,
    Offset globalPosition,
  ) {
    opens++;
    return zShowZMenuAt(context, request, globalPosition);
  }
}

void main() {
  const trigger = ZMenuTrigger(icon: Icons.more_vert, semanticLabel: 'Actions');

  testWidgets('grille : un tap sur une cellule invoque UNE SEULE fois',
      (tester) async {
    var invocations = 0;
    await pump(
      tester,
      ZActionMenu(
        renderer: const ZGridMenuRenderer(),
        trigger: trigger,
        entries: <ZMenuEntry>[
          ZMenuEntry(
            id: 'open',
            label: 'Ouvrir',
            icon: Icons.folder_open,
            onSelected: () => invocations++,
          ),
        ],
      ),
    );
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Ouvrir'), findsOneWidget);

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    expect(invocations, 1, reason: 'un tap = une invocation, jamais deux');
  });

  testWidgets('grille : colonnes déclarées, défaut à 3', (tester) async {
    List<ZMenuEntry> entries() => <ZMenuEntry>[
          for (var i = 0; i < 6; i++)
            ZMenuEntry(id: 'a$i', label: 'A$i', onSelected: () {}),
        ];
    await pump(
      tester,
      ZActionMenu(
        renderer: const ZGridMenuRenderer(),
        trigger: trigger,
        entries: entries(),
      ),
    );
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 3);
    expect(kZGridMenuColumns, 3);

    // Déclaration honorée : deux colonnes quand elles sont demandées.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await pump(
      tester,
      ZActionMenu(
        renderer: const ZGridMenuRenderer(columns: 2),
        trigger: trigger,
        entries: entries(),
      ),
    );
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    final grid2 = tester.widget<GridView>(find.byType(GridView));
    expect(
      (grid2.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      2,
    );
  });

  testWidgets('grille : cible ≥ 48 dp tenue par la DISPOSITION',
      (tester) async {
    await pump(
      tester,
      ZActionMenu(
        // Hauteur de cellule volontairement SOUS la cible : la disposition la
        // remonte, la cellule ne peut pas le faire seule.
        renderer: const ZGridMenuRenderer(tileExtent: 12),
        trigger: trigger,
        entries: <ZMenuEntry>[
          ZMenuEntry(id: 'open', label: 'Ouvrir', onSelected: () {}),
        ],
      ),
    );
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    final size = tester.getSize(find.byType(ZMenuEntryTile));
    expect(size.height, greaterThanOrEqualTo(48.0));
    expect(size.width, greaterThanOrEqualTo(48.0));
  });

  testWidgets('grille : le libellé est annoncé UNE fois', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      ZActionMenu(
        renderer: const ZGridMenuRenderer(),
        trigger: trigger,
        entries: <ZMenuEntry>[
          ZMenuEntry(id: 'open', label: 'Ouvrir', onSelected: () {}),
        ],
      ),
    );
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Ouvrir'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('geste contextuel : le clic droit ouvre et la sélection porte',
      (tester) async {
    var invocations = 0;
    await pump(
      tester,
      ZContextMenuRegion(
        trigger: trigger,
        entries: <ZMenuEntry>[
          ZMenuEntry(
            id: 'open',
            label: 'Ouvrir',
            onSelected: () => invocations++,
          ),
        ],
        child: const SizedBox(width: 200, height: 80, child: Text('Ligne')),
      ),
    );
    await tester.tapAt(
      tester.getCenter(find.text('Ligne')),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
    expect(find.text('Ouvrir'), findsOneWidget);
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    expect(invocations, 1);
  });

  testWidgets('geste contextuel : appui long désactivable par déclaration',
      (tester) async {
    Widget region({required bool longPress}) => ZContextMenuRegion(
          trigger: trigger,
          longPress: longPress,
          entries: <ZMenuEntry>[
            ZMenuEntry(id: 'open', label: 'Ouvrir', onSelected: () {}),
          ],
          child: const SizedBox(width: 200, height: 80, child: Text('Ligne')),
        );

    await pump(tester, region(longPress: true));
    await tester.longPress(find.text('Ligne'));
    await tester.pumpAndSettle();
    expect(find.text('Ouvrir'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    await pump(tester, region(longPress: false));
    await tester.longPress(find.text('Ligne'));
    await tester.pumpAndSettle();
    expect(find.text('Ouvrir'), findsNothing, reason: 'geste NON réclamé');
  });

  testWidgets('AD-10 : aucune entrée offerte ⇒ aucune surface au clic droit',
      (tester) async {
    await pump(
      tester,
      ZContextMenuRegion(
        trigger: trigger,
        // Ni actionnable ni désactivée ⇒ ABSENTE : rien à montrer.
        entries: const <ZMenuEntry>[ZMenuEntry(id: 'open', label: 'Ouvrir')],
        child: const SizedBox(width: 200, height: 80, child: Text('Ligne')),
      ),
    );
    await tester.tapAt(
      tester.getCenter(find.text('Ligne')),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
    expect(find.text('Ouvrir'), findsNothing);
  });

  testWidgets('le renderer AMBIANT sert les deux voies (déclencheur ET geste)',
      (tester) async {
    final spy = SpyRenderer();
    final entries = <ZMenuEntry>[
      ZMenuEntry(id: 'open', label: 'Ouvrir', onSelected: () {}),
    ];
    await pump(
      tester,
      ZMenuScope(
        renderer: spy,
        child: ZContextMenuRegion(
          trigger: trigger,
          entries: entries,
          child: ZActionMenu(trigger: trigger, entries: entries),
        ),
      ),
    );
    expect(spy.builds, greaterThan(0), reason: 'déclencheur : scope employé');

    await tester.tapAt(
      tester.getTopLeft(find.byType(ZContextMenuRegion)) + const Offset(2, 2),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
    expect(spy.opens, 1, reason: 'geste contextuel : scope employé');
  });
}
