// Tests DISCRIMINANTS CR-IFFD-15 — grille adaptative RÉORDONNABLE.
//
// Gardes structurantes (discipline R3 — chacune a été prouvée MORDANTE en
// injectant la régression qu'elle prétend attraper) :
//   G1 : index de dépôt LINÉAIRE inter-lignes — déposer sur la position k donne
//        l'index k, même si k est sur une AUTRE ligne de la grille.
//        Régression injectée : `onAcceptWithDetails` contraint à la même ligne
//        (`position - position % columns`) ⇒ ROUGE.
//   G2 : ordre optimiste LOCAL — le retour visuel vient de l'état local, et
//        réordonner ne reconstruit PAS le parent/page.
//        Régression injectée : `_move` n'écrit plus `_order` et se contente
//        d'appeler `onReorder` (hôte passif) ⇒ ROUGE.
//   G3 : repli AD-10 — un `onReorder` qui lève RESTAURE l'ordre affiché.
//        Régression injectée : `catch` retiré (propagation) ⇒ ROUGE.
//
// Gardes complémentaires : réutilisation de `computeCrossAxisCount` (mêmes
// colonnes que ZAdaptiveGrid), alternative a11y (actions sémantiques),
// autoscroll de bord, RTL, resync `didUpdateWidget`, garde vide AD-10.

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_responsive/zcrud_responsive.dart';

const String kMoveBefore = 'MOVE-BEFORE-XYZ';
const String kMoveAfter = 'MOVE-AFTER-XYZ';

/// Enveloppe minimale (aucun Material : la primitive est widgets-only).
Widget _wrap(Widget child, {TextDirection dir = TextDirection.ltr}) {
  return Directionality(
    textDirection: dir,
    child: MediaQuery(
      data: const MediaQueryData(size: Size(800, 600)),
      child: Overlay(
        // `LongPressDraggable` exige un `Overlay` ancetre (l'apercu de drag y
        // est monte). C'est le SEUL echafaudage du test : aucun MaterialApp,
        // la primitive reste widgets-only.
        initialEntries: <OverlayEntry>[
          OverlayEntry(
            builder: (context) => Align(
              alignment: AlignmentDirectional.topStart,
              child: SizedBox(width: 600, height: 600, child: child),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Cellule de test : un carré étiqueté, identifiable par `find.text`.
Widget _tile(BuildContext context, int index, List<String> ids) {
  return Center(child: Text(ids[index], textDirection: TextDirection.ltr));
}

/// Ordre VISUEL courant, lu sur les positions réelles (ligne d'abord, puis
/// colonne selon la direction du texte) — jamais sur l'ordre d'entrée.
List<String> _visualOrder(WidgetTester tester, List<String> ids,
    {bool rtl = false}) {
  final entries = <MapEntry<String, Offset>>[];
  for (final id in ids) {
    final finder = find.text(id);
    if (finder.evaluate().isEmpty) continue;
    entries.add(MapEntry(id, tester.getTopLeft(finder.first)));
  }
  entries.sort((a, b) {
    final dy = a.value.dy.compareTo(b.value.dy);
    if (dy != 0) return dy;
    return rtl
        ? b.value.dx.compareTo(a.value.dx)
        : a.value.dx.compareTo(b.value.dx);
  });
  return entries.map((e) => e.key).toList();
}

/// Exécute un vrai geste : appui long sur [from], glissement jusqu'à [to],
/// relâchement.
Future<void> _dragCell(
  WidgetTester tester,
  String from,
  String to,
) async {
  final gesture =
      await tester.startGesture(tester.getCenter(find.text(from).first));
  // Franchit le seuil d'appui long du SDK.
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
  await gesture.moveTo(tester.getCenter(find.text(to).first));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  // ---------------------------------------------------------------------------
  // G1 [CENTRAL] — index de dépôt LINÉAIRE, inter-lignes.
  // ---------------------------------------------------------------------------
  testWidgets(
      'G1 : deposer sur une cellule d\'une AUTRE ligne donne l\'index LINEAIRE '
      'de cette cellule (la grille n\'est qu\'une projection)', (tester) async {
    final ids = ['a', 'b', 'c', 'd', 'e', 'f'];
    final calls = <List<int>>[];
    await tester.pumpWidget(_wrap(ZReorderableAdaptiveGrid(
      itemIds: ids,
      itemBuilder: (c, i) => _tile(c, i, ids),
      onReorder: (o, n) => calls.add([o, n]),
      // 600 / 200 = 3 colonnes ⇒ ligne 0 = [a,b,c], ligne 1 = [d,e,f].
      minItemWidth: 200,
      spacing: 0,
      itemHeight: 100,
      moveBeforeSemanticLabel: kMoveBefore,
      moveAfterSemanticLabel: kMoveAfter,
    )));

    // Pré-condition : la grille est bien MULTI-COLONNES (3 colonnes).
    expect(tester.getTopLeft(find.text('a')).dy,
        equals(tester.getTopLeft(find.text('c')).dy),
        reason: 'a et c sont sur la MEME ligne (3 colonnes)');
    expect(tester.getTopLeft(find.text('d')).dy,
        greaterThan(tester.getTopLeft(find.text('a')).dy),
        reason: 'd est sur la ligne SUIVANTE');

    // Dépôt de `a` (position 0, ligne 0) sur `e` (position 4, ligne 1).
    await _dragCell(tester, 'a', 'e');

    // Index linéaire : 0 → 4 (et NON un index recalé sur la ligne).
    expect(calls, [
      [0, 4]
    ]);
    // removeAt(0)/insert(4) ⇒ [b,c,d,e,a,f].
    expect(_visualOrder(tester, ids), ['b', 'c', 'd', 'e', 'a', 'f']);
  });

  testWidgets('G1bis : dépôt vers le HAUT inter-lignes (5 → 1)',
      (tester) async {
    final ids = ['a', 'b', 'c', 'd', 'e', 'f'];
    final calls = <List<int>>[];
    await tester.pumpWidget(_wrap(ZReorderableAdaptiveGrid(
      itemIds: ids,
      itemBuilder: (c, i) => _tile(c, i, ids),
      onReorder: (o, n) => calls.add([o, n]),
      minItemWidth: 200,
      spacing: 0,
      itemHeight: 100,
      moveBeforeSemanticLabel: kMoveBefore,
      moveAfterSemanticLabel: kMoveAfter,
    )));

    await _dragCell(tester, 'f', 'b');

    expect(calls, [
      [5, 1]
    ]);
    expect(_visualOrder(tester, ids), ['a', 'f', 'b', 'c', 'd', 'e']);
  });

  // ---------------------------------------------------------------------------
  // G2 [CENTRAL / SM-1 / AD-2] — ordre optimiste LOCAL, zéro rebuild parent.
  // ---------------------------------------------------------------------------
  testWidgets(
      'G2 : le retour visuel vient de l\'etat LOCAL et ne reconstruit NI le '
      'parent NI la page (onReorder passif, aucun setState hote)',
      (tester) async {
    final ids = ['a', 'b', 'c', 'd'];
    var parentBuilds = 0;
    var siblingBuilds = 0;

    await tester.pumpWidget(_wrap(_CountingParent(
      onBuild: () => parentBuilds++,
      child: Column(
        children: [
          _CountingLeaf(onBuild: () => siblingBuilds++),
          SizedBox(
            height: 300,
            child: ZReorderableAdaptiveGrid(
              itemIds: ids,
              itemBuilder: (c, i) => _tile(c, i, ids),
              // Hôte PASSIF : ne persiste rien, ne rebuild rien. Le SEUL moteur
              // possible du réordonnancement visuel est l'état optimiste local.
              onReorder: (_, _) {},
              minItemWidth: 200,
              spacing: 0,
              itemHeight: 100,
              moveBeforeSemanticLabel: kMoveBefore,
              moveAfterSemanticLabel: kMoveAfter,
            ),
          ),
        ],
      ),
    )));

    expect(_visualOrder(tester, ids), ['a', 'b', 'c', 'd']);
    final parentBefore = parentBuilds;
    final siblingBefore = siblingBuilds;

    await _dragCell(tester, 'a', 'c');

    // (a) L'ordre a VISUELLEMENT changé — sans aucune aide de l'hôte.
    expect(_visualOrder(tester, ids), ['b', 'c', 'a', 'd']);
    // (b) …et ni le parent ni la fratrie n'ont été reconstruits (SM-1).
    expect(parentBuilds, parentBefore, reason: 'aucun rebuild du parent');
    expect(siblingBuilds, siblingBefore, reason: 'aucun rebuild de la fratrie');
  });

  // ---------------------------------------------------------------------------
  // G3 [CENTRAL / AD-10] — onReorder qui lève ⇒ ordre affiché RESTAURÉ.
  // ---------------------------------------------------------------------------
  testWidgets(
      'G3 : un onReorder qui leve RESTAURE l\'ordre affiche (AD-10, jamais '
      'd\'etat incoherent, jamais de crash de rendu)', (tester) async {
    final ids = ['a', 'b', 'c', 'd'];
    await tester.pumpWidget(_wrap(ZReorderableAdaptiveGrid(
      itemIds: ids,
      itemBuilder: (c, i) => _tile(c, i, ids),
      onReorder: (_, _) => throw StateError('persistance HS'),
      minItemWidth: 200,
      spacing: 0,
      itemHeight: 100,
      moveBeforeSemanticLabel: kMoveBefore,
      moveAfterSemanticLabel: kMoveAfter,
    )));

    expect(_visualOrder(tester, ids), ['a', 'b', 'c', 'd']);
    await _dragCell(tester, 'a', 'c');

    // Ordre AFFICHÉ restauré à l'identique…
    expect(_visualOrder(tester, ids), ['a', 'b', 'c', 'd'],
        reason: 'repli AD-10 : l\'ordre optimiste est annulé');
    // …et aucune exception n'a fui vers le framework (pas de rendu cassé).
    expect(tester.takeException(), isNull);
  });

  // ---------------------------------------------------------------------------
  // Alternative accessible OBLIGATOIRE (AD-13) : actions sémantiques.
  // ---------------------------------------------------------------------------
  testWidgets(
      'a11y : chaque cellule expose les actions semantiques INJECTEES '
      '« avant »/« apres » (l\'appui long seul est inatteignable au lecteur '
      'd\'ecran)', (tester) async {
    final handle = tester.ensureSemantics();
    final ids = ['a', 'b', 'c'];
    final calls = <List<int>>[];
    await tester.pumpWidget(_wrap(ZReorderableAdaptiveGrid(
      itemIds: ids,
      itemBuilder: (c, i) => _tile(c, i, ids),
      onReorder: (o, n) => calls.add([o, n]),
      minItemWidth: 200,
      spacing: 0,
      itemHeight: 100,
      moveBeforeSemanticLabel: kMoveBefore,
      moveAfterSemanticLabel: kMoveAfter,
    )));

    // Les libellés sont ceux INJECTÉS (jamais un littéral du package).
    final before = CustomSemanticsAction(label: kMoveBefore);
    final after = CustomSemanticsAction(label: kMoveAfter);
    expect(CustomSemanticsAction.getIdentifier(before), isNonNegative);

    // La 1re cellule n'a PAS « avant » ; la dernière n'a PAS « après ».
    final firstNode = tester.getSemantics(find.text('a'));
    final lastNode = tester.getSemantics(find.text('c'));
    expect(firstNode.getSemanticsData().customSemanticsActionIds,
        isNot(contains(CustomSemanticsAction.getIdentifier(before))));
    expect(lastNode.getSemanticsData().customSemanticsActionIds,
        isNot(contains(CustomSemanticsAction.getIdentifier(after))));

    // Déclencher « déplacer avant » sur la cellule du milieu réordonne
    // réellement — sans le moindre appui long.
    final middleId = tester.getSemantics(find.text('b')).id;
    tester.binding.pipelineOwner.semanticsOwner!.performAction(
      middleId,
      SemanticsAction.customAction,
      CustomSemanticsAction.getIdentifier(before),
    );
    await tester.pumpAndSettle();

    expect(calls, [
      [1, 0]
    ]);
    expect(_visualOrder(tester, ids), ['b', 'a', 'c']);
    handle.dispose();
  });

  // ---------------------------------------------------------------------------
  // Réutilisation de la primitive de colonnes (AUCUN second calcul).
  // ---------------------------------------------------------------------------
  testWidgets(
      'colonnes : la grille reordonnable donne EXACTEMENT le meme nombre de '
      'colonnes que ZAdaptiveGrid (meme computeCrossAxisCount)', (tester) async {
    final ids = ['a', 'b', 'c', 'd', 'e', 'f'];
    await tester.pumpWidget(_wrap(ZReorderableAdaptiveGrid(
      itemIds: ids,
      itemBuilder: (c, i) => _tile(c, i, ids),
      onReorder: (_, _) {},
      minItemWidth: 250,
      spacing: 0,
      itemHeight: 100,
      moveBeforeSemanticLabel: kMoveBefore,
      moveAfterSemanticLabel: kMoveAfter,
    )));

    // Nombre de lignes distinctes observé.
    final ys = <double>{for (final id in ids) tester.getTopLeft(find.text(id)).dy};
    final expectedColumns = computeCrossAxisCount(
      availableWidth: 600,
      minItemWidth: 250,
      spacing: 0,
    );
    expect(expectedColumns, 2);
    expect(ys.length, (ids.length / expectedColumns).ceil());
    // …et la grille réordonnable EST une ZAdaptiveGrid (délégation, pas copie).
    expect(find.byType(ZAdaptiveGrid), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // Autoscroll de bord.
  // ---------------------------------------------------------------------------
  testWidgets(
      'autoscroll : glisser pres du bord BAS du Scrollable englobant fait '
      'defiler la vue pendant le glissement', (tester) async {
    final ids = <String>[for (var i = 0; i < 24; i++) 'i$i'];
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_wrap(SingleChildScrollView(
      controller: controller,
      child: ZReorderableAdaptiveGrid(
        itemIds: ids,
        itemBuilder: (c, i) => _tile(c, i, ids),
        onReorder: (_, _) {},
        minItemWidth: 200,
        spacing: 0,
        itemHeight: 200,
        moveBeforeSemanticLabel: kMoveBefore,
        moveAfterSemanticLabel: kMoveAfter,
      ),
    )));

    expect(controller.position.maxScrollExtent, greaterThan(0));
    expect(controller.offset, 0);

    final gesture = await tester.startGesture(tester.getCenter(find.text('i0')));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    // Vers le bord BAS du viewport (600 de haut) — dans la zone d'autoscroll.
    await gesture.moveTo(const Offset(300, 590));
    await tester.pump();
    // Laisse la minuterie d'autoscroll battre quelques frames.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    final scrolledDuringDrag = controller.offset;
    expect(scrolledDuringDrag, greaterThan(0),
        reason: 'l\'autoscroll a fait defiler pendant le glissement');

    await gesture.up();
    await tester.pumpAndSettle();
    // La minuterie est bien arrêtée au relâchement (sinon pumpAndSettle
    // n'aurait pas pu converger et l'offset continuerait de croître).
    final afterDrop = controller.offset;
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.offset, afterDrop,
        reason: 'l\'autoscroll s\'arrete au relachement');
  });

  // ---------------------------------------------------------------------------
  // Resync `didUpdateWidget` + garde vide + RTL.
  // ---------------------------------------------------------------------------
  testWidgets('resync : un nouvel itemIds pousse par l\'hote realigne l\'ordre',
      (tester) async {
    final key = GlobalKey<_ResyncHarnessState>();
    await tester.pumpWidget(_wrap(_ResyncHarness(key: key)));
    expect(_visualOrder(tester, ['a', 'b', 'c']), ['a', 'b', 'c']);

    // L'hote persiste puis REPOUSSE un nouvel ordre : la grille se realigne
    // (didUpdateWidget), elle ne reste pas sur son ordre optimiste.
    key.currentState!.push(['c', 'a', 'b']);
    await tester.pumpAndSettle();
    expect(_visualOrder(tester, ['a', 'b', 'c']), ['c', 'a', 'b']);
  });

  testWidgets('garde vide AD-10 : itemIds vide ⇒ SizedBox.shrink, jamais de throw',
      (tester) async {
    await tester.pumpWidget(_wrap(ZReorderableAdaptiveGrid(
      itemIds: const <String>[],
      itemBuilder: (c, i) => const SizedBox(),
      onReorder: (_, _) {},
      minItemWidth: 200,
      moveBeforeSemanticLabel: kMoveBefore,
      moveAfterSemanticLabel: kMoveAfter,
    )));
    expect(tester.takeException(), isNull);
    expect(find.byType(ZAdaptiveGrid), findsNothing);
  });

  testWidgets('RTL : le nombre de colonnes est identique, l\'ordre suit le sens '
      'du texte', (tester) async {
    final ids = ['a', 'b', 'c', 'd', 'e', 'f'];
    await tester.pumpWidget(_wrap(
      ZReorderableAdaptiveGrid(
        itemIds: ids,
        itemBuilder: (c, i) => _tile(c, i, ids),
        onReorder: (_, _) {},
        minItemWidth: 200,
        spacing: 0,
        itemHeight: 100,
        moveBeforeSemanticLabel: kMoveBefore,
        moveAfterSemanticLabel: kMoveAfter,
      ),
      dir: TextDirection.rtl,
    ));

    // En RTL, `a` est la cellule la plus à DROITE de la 1re ligne.
    expect(tester.getTopLeft(find.text('a')).dx,
        greaterThan(tester.getTopLeft(find.text('c')).dx));
    expect(_visualOrder(tester, ids, rtl: true),
        ['a', 'b', 'c', 'd', 'e', 'f']);
  });
}

/// Parent qui compte ses builds (sonde SM-1).
class _CountingParent extends StatelessWidget {
  const _CountingParent({required this.onBuild, required this.child});

  final VoidCallback onBuild;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    onBuild();
    return child;
  }
}

/// Fratrie qui compte ses builds (sonde SM-1).
class _CountingLeaf extends StatelessWidget {
  const _CountingLeaf({required this.onBuild});

  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild();
    return const SizedBox(height: 10);
  }
}

/// Hote qui repousse un nouvel `itemIds` (sonde de resync `didUpdateWidget`).
class _ResyncHarness extends StatefulWidget {
  const _ResyncHarness({super.key});

  @override
  State<_ResyncHarness> createState() => _ResyncHarnessState();
}

class _ResyncHarnessState extends State<_ResyncHarness> {
  List<String> _ids = const ['a', 'b', 'c'];

  void push(List<String> ids) => setState(() => _ids = ids);

  @override
  Widget build(BuildContext context) {
    final ids = _ids;
    return ZReorderableAdaptiveGrid(
      itemIds: ids,
      itemBuilder: (c, i) => _tile(c, i, ids),
      onReorder: (_, _) {},
      minItemWidth: 200,
      spacing: 0,
      itemHeight: 100,
      moveBeforeSemanticLabel: kMoveBefore,
      moveAfterSemanticLabel: kMoveAfter,
    );
  }
}
