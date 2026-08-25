// Contrat de POIGNÉE du port `ZReorderRenderer.buildDragHandle`, honoré par
// `ZDefaultReorderRenderer` (chassis maison `ZReorderableAdaptiveGrid`).
//
// Le défaut mesuré avant ce lot : le renderer laissait le défaut IDENTITÉ du
// port. Une poignée rendue en tête d'item était donc une affordance INERTE
// sous ce renderer, et le glissement n'était atteignable que par un appui long
// sur la cellule entière — geste déjà disputé quand la cellule porte des
// sous-champs éditables.
//
// Gardes (discipline R3 — chacune prouvée MORDANTE par injection de la
// régression exacte, cf. r3.txt du lot) :
//   Ga  : un glissement IMMÉDIAT parti de la poignée réordonne, et réordonne
//         la BONNE ligne. 🔴 Discriminante sur la grandeur : la donnée du
//         glissement doit être la POSITION AFFICHÉE, pas l'`index` (SOURCE)
//         que le port passe à `buildDragHandle`. La garde fait DIVERGER les
//         deux avant de glisser.
//         Injection : `data: scope.position` → `data: index` ⇒ ROUGE.
//   Gb  : l'appui long sur la cellule reste disponible quand une poignée est
//         soumise (garantie 3 du port : ne pas confisquer le reste).
//         Injection : `child: handle` → `child: AbsorbPointer(child: handle)`
//         puis suppression du chemin appui long ⇒ ROUGE.
//   Gc  : la poignée est rendue INCHANGÉE — taille, origine et sémantique
//         mesurées sur le rendu, jamais un nom de classe.
//         Injections : contrainte 40 dp, puis marge, puis `ExcludeSemantics`.
//   Gf  : TOUTE la boîte soumise est sensible — un glissement parti d'un COIN
//         de la cible tactile réordonne (au défaut `deferToChild`, la part de
//         la cible qui ne peint rien serait transparente au geste).
//         Injection : `hitTestBehavior: opaque` retiré ⇒ ROUGE.
//   Gd  : sans poignée soumise, la géométrie rendue est celle relevée AVANT le
//         lot, au pixel — et aucun déclencheur immédiat n'est posé.
//   Ge  : un `onReorder` qui lève restaure l'ordre affiché, par les DEUX
//         chemins (AD-10).
//
// S'y ajoutent deux gardes de mécanisme : le canal est atteignable depuis le
// `context` que reçoit `itemBuilder` ET depuis celui d'un widget descendant
// (le patron réel d'un appelant) ; hors d'une cellule, le port retrouve son
// défaut identité sans rien lever.

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_responsive/zcrud_responsive.dart';

const String kMoveBefore = 'MOVE-BEFORE-XYZ';
const String kMoveAfter = 'MOVE-AFTER-XYZ';

const ZDefaultReorderRenderer _renderer = ZDefaultReorderRenderer();

/// Enveloppe minimale (aucun Material : la primitive est widgets-only).
/// L'`Overlay` est l'unique échafaudage — tout `Draggable` en exige un.
Widget _wrap(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(size: Size(800, 600)),
      child: Overlay(
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

/// Poignée SOUMISE au port : cible tactile 48 dp + libellé sémantique, comme
/// celle qu'un appelant rend en tête d'item. La clé porte l'ID, pas la
/// position : elle survit à un réordonnancement.
Widget _handleOf(String id) => Semantics(
      label: 'POIGNEE-$id',
      child: SizedBox(
        key: ValueKey<String>('handle-$id'),
        width: 48,
        height: 48,
        // Glyphe CENTRÉ dans la cible tactile, comme une vraie poignée : le
        // centre est donc sensible même au défaut `deferToChild`. C'est ce qui
        // rend Ga (immédiateté, grandeur) et Gf (surface de la cible)
        // ORTHOGONALES — sans quoi une seule injection les ferait rougir
        // toutes les deux.
        child: const Center(child: Text('=', textDirection: TextDirection.ltr)),
      ),
    );

/// Ligne d'item : poignée soumise au renderer + libellé. `crossAxisAlignment:
/// start` colle la poignée à l'origine de la cellule — c'est ce qui rend une
/// marge injectée MESURABLE (Gc).
Widget _rowWithHandle(BuildContext context, String id, int index) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _renderer.buildDragHandle(context, index, _handleOf(id)),
        Expanded(child: Center(child: Text(id, textDirection: TextDirection.ltr))),
      ],
    );

/// Même ligne, mais dont la poignée est soumise depuis le `BuildContext` d'un
/// widget DESCENDANT — le patron réel d'un appelant, dont la poignée est un
/// widget à elle seule.
class _NestedHandleRow extends StatelessWidget {
  const _NestedHandleRow({required this.id, required this.index});

  final String id;
  final int index;

  @override
  Widget build(BuildContext context) => _rowWithHandle(context, id, index);
}

/// Construit la grille via le PORT (`ZReorderRenderer.build`), comme le fait
/// un consommateur : c'est le chemin qui doit honorer le contrat.
Widget _grid({
  required List<String> ids,
  required void Function(int oldIndex, int newIndex) onReorder,
  bool withHandle = true,
  bool nested = false,
  int? maxColumns = 1,
  double minItemWidth = 200,
  double itemHeight = 100,
}) {
  return Builder(
    builder: (context) => _renderer.build(
      context,
      ZReorderRenderRequest(
        itemIds: ids,
        itemBuilder: (itemContext, index) {
          final String id = ids[index];
          if (!withHandle) {
            return Center(child: Text(id, textDirection: TextDirection.ltr));
          }
          return nested
              ? _NestedHandleRow(id: id, index: index)
              : _rowWithHandle(itemContext, id, index);
        },
        onReorder: onReorder,
        minItemWidth: minItemWidth,
        spacing: 0,
        itemHeight: itemHeight,
        maxColumns: maxColumns,
        moveBeforeSemanticLabel: kMoveBefore,
        moveAfterSemanticLabel: kMoveAfter,
      ),
    ),
  );
}

/// Ordre VISUEL courant, lu sur les positions réelles — jamais sur l'ordre
/// d'entrée. Ignore l'aperçu flottant éventuel (premier match seulement).
List<String> _visualOrder(WidgetTester tester, List<String> ids) {
  final entries = <MapEntry<String, Offset>>[];
  for (final id in ids) {
    final finder = find.text(id);
    if (finder.evaluate().isEmpty) continue;
    entries.add(MapEntry(id, tester.getTopLeft(finder.first)));
  }
  entries.sort((a, b) {
    final dy = a.value.dy.compareTo(b.value.dy);
    if (dy != 0) return dy;
    return a.value.dx.compareTo(b.value.dx);
  });
  return entries.map((e) => e.key).toList();
}

/// Appui LONG sur la cellule, puis glissement jusqu'à [to] — le geste
/// historique de la grille.
Future<void> _longPressDrag(WidgetTester tester, String from, String to) async {
  final gesture =
      await tester.startGesture(tester.getCenter(find.text(from).first));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
  await gesture.moveTo(tester.getCenter(find.text(to).first));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

/// Glissement IMMÉDIAT parti de la poignée de [fromId], relâché sur la cellule
/// qui affiche [toId].
///
/// Le budget de temps du geste, relâchement compris, est tenu STRICTEMENT sous
/// le seuil d'appui long du SDK : un déclencheur à appui long aurait rejeté ce
/// mouvement. C'est ce qui fait de la mesure une mesure d'IMMÉDIATETÉ, et pas
/// un simple « ça réordonne ».
Future<void> _handleDrag(WidgetTester tester, String fromId, String toId) async {
  const hold = Duration(milliseconds: 16);
  const step = Duration(milliseconds: 16);
  const steps = 4;
  expect(hold + step * steps, lessThan(kLongPressTimeout),
      reason: 'le budget du geste doit rester sous le seuil d\'appui long');

  final start =
      tester.getCenter(find.byKey(ValueKey<String>('handle-$fromId')).first);
  final end = tester.getCenter(find.text(toId).first);
  final gesture = await tester.startGesture(start);
  await tester.pump(hold);
  final delta = Offset((end.dx - start.dx) / steps, (end.dy - start.dy) / steps);
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(delta);
    await tester.pump(step);
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  // ---------------------------------------------------------------------------
  // Ga [CENTRALE] — glissement IMMÉDIAT depuis la poignée, sur la BONNE ligne.
  // ---------------------------------------------------------------------------
  testWidgets(
      'Ga : un glissement IMMEDIAT parti de la poignee reordonne, et reordonne '
      'la ligne de la POSITION AFFICHEE (jamais celle de l\'index SOURCE)',
      (tester) async {
    final ids = ['a', 'b', 'c', 'd'];
    final calls = <List<int>>[];
    // Hôte PASSIF : il ne repousse JAMAIS d'`itemIds`. C'est ce qui laisse
    // l'ordre optimiste local DIVERGER de la liste source — et c'est cette
    // divergence qui sépare la position affichée de l'index source.
    await tester.pumpWidget(_wrap(_grid(
      ids: ids,
      onReorder: (o, n) => calls.add(<int>[o, n]),
    )));

    expect(_visualOrder(tester, ids), ['a', 'b', 'c', 'd']);

    // 1) Divergence : on permute l'affichage sans que l'hôte n'en sache rien.
    await _longPressDrag(tester, 'a', 'c');
    expect(calls, [
      [0, 2]
    ]);
    expect(_visualOrder(tester, ids), ['b', 'c', 'a', 'd'],
        reason: 'pré-condition : l\'affichage a divergé de la liste source');
    // Désormais 'b' est en POSITION 0 alors que son index SOURCE vaut 1 —
    // les deux grandeurs ne coïncident plus.

    // 2) Le glissement immédiat parti de la poignée de 'b', relâché sur la
    //    cellule qui affiche 'a' (position 2).
    await _handleDrag(tester, 'b', 'a');

    expect(calls.length, 2, reason: 'la poignée n\'a rien amorcé');
    expect(calls.last, [0, 2],
        reason: 'la donnée du glissement doit être la POSITION affichée (0), '
            'jamais l\'index SOURCE de \'b\' (1)');
    expect(_visualOrder(tester, ids), ['c', 'a', 'b', 'd'],
        reason: 'confondre index et position aurait donné [b, a, c, d]');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Ga bis : le canal est atteignable depuis le contexte d\'un widget '
      'DESCENDANT de itemBuilder (le patron reel d\'un appelant)',
      (tester) async {
    final ids = ['a', 'b', 'c', 'd'];
    final calls = <List<int>>[];
    await tester.pumpWidget(_wrap(_grid(
      ids: ids,
      nested: true,
      onReorder: (o, n) => calls.add(<int>[o, n]),
    )));

    await _handleDrag(tester, 'a', 'c');
    expect(calls, [
      [0, 2]
    ]);
    expect(_visualOrder(tester, ids), ['b', 'c', 'a', 'd']);
    expect(tester.takeException(), isNull);
  });

  // ---------------------------------------------------------------------------
  // Gb — l'appui long sur la cellule N'EST PAS confisqué (garantie 3).
  // ---------------------------------------------------------------------------
  testWidgets(
      'Gb : avec une poignee soumise, l\'appui long sur la CELLULE reordonne '
      'toujours, et la voie non gestuelle reste en place', (tester) async {
    final handle = tester.ensureSemantics();
    final ids = ['a', 'b', 'c', 'd'];
    final calls = <List<int>>[];
    await tester.pumpWidget(_wrap(_grid(
      ids: ids,
      onReorder: (o, n) => calls.add(<int>[o, n]),
    )));

    // (1) Le geste de la cellule est intact.
    await _longPressDrag(tester, 'a', 'c');
    expect(calls, [
      [0, 2]
    ]);
    expect(_visualOrder(tester, ids), ['b', 'c', 'a', 'd']);

    // (2) La voie NON GESTUELLE l'est aussi : chaque cellule porte encore ses
    //     actions de déplacement injectées (AD-13).
    final withActions = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .where((s) =>
            (s.properties.customSemanticsActions ?? const {}).isNotEmpty)
        .length;
    expect(withActions, greaterThanOrEqualTo(4));
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  // ---------------------------------------------------------------------------
  // Gc — la poignée est rendue INCHANGÉE (garantie 2), mesurée sur le rendu.
  // ---------------------------------------------------------------------------
  testWidgets(
      'Gc : la poignee soumise est rendue INCHANGEE — taille, origine et '
      'semantique mesurees sur le rendu', (tester) async {
    final semantics = tester.ensureSemantics();
    final ids = ['a', 'b', 'c'];
    await tester.pumpWidget(_wrap(_grid(ids: ids, onReorder: (_, _) {})));

    final cells = find.byType(DragTarget<int>);
    expect(cells, findsNWidgets(3));

    for (var i = 0; i < ids.length; i++) {
      final key = find.byKey(ValueKey<String>('handle-${ids[i]}'));
      // (1) Taille : la cible tactile soumise par l'appelant, intacte.
      expect(tester.getSize(key), const Size(48, 48),
          reason: 'la poignée a été contrainte ou redimensionnée');
      // (2) Origine : aucune marge ni décoration insérée devant elle — elle
      //     reste collée à l'origine de sa cellule.
      expect(tester.getTopLeft(key), tester.getTopLeft(cells.at(i)),
          reason: 'une marge a été insérée autour de la poignée');
      // (3) Sémantique : le libellé de l'appelant survit dans le nœud rendu.
      //     (Il y est FUSIONNÉ avec celui de l'item — c'est le rendu réel de
      //     la cellule, qui est un conteneur sémantique ; ce qui se mesure ici
      //     est que la poignée n'a rien perdu ni rien gagné en propre.)
      expect(tester.getSemantics(key).label, contains('POIGNEE-${ids[i]}'),
          reason: 'la sémantique de la poignée a été modifiée');
    }
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets(
      'Gc bis : hors d\'une cellule du chassis, le port retrouve son defaut '
      'IDENTITE et rien ne leve (AD-10)', (tester) async {
    late BuildContext outside;
    await tester.pumpWidget(_wrap(Builder(builder: (context) {
      outside = context;
      return const SizedBox.shrink();
    })));

    const submitted = SizedBox(key: ValueKey<String>('poignee-orpheline'));
    final returned = _renderer.buildDragHandle(outside, 0, submitted);
    expect(identical(returned, submitted), isTrue,
        reason: 'hors du chassis, la poignée doit être rendue telle quelle');
    expect(tester.takeException(), isNull);
  });

  // ---------------------------------------------------------------------------
  // Gf — la cible tactile ENTIÈRE est le déclencheur, pas le seul glyphe.
  // ---------------------------------------------------------------------------
  testWidgets(
      'Gf : un glissement parti d\'un COIN de la cible tactile de la poignee '
      'reordonne (toute la boite soumise est sensible, pas son seul contenu)',
      (tester) async {
    final ids = ['a', 'b', 'c', 'd'];
    final calls = <List<int>>[];
    await tester.pumpWidget(_wrap(_grid(
      ids: ids,
      onReorder: (o, n) => calls.add(<int>[o, n]),
    )));

    final Rect box = tester.getRect(find.byKey(const ValueKey<String>('handle-a')));
    expect(box.size, const Size(48, 48));
    // Coin haut-début de la cible, à 2 dp du bord : hors de tout contenu que
    // la poignée peindrait, mais bien DANS la cible que l'appelant déclare.
    final Offset corner = box.topLeft + const Offset(2, 2);
    final Offset end = tester.getCenter(find.text('c').first);

    const step = Duration(milliseconds: 16);
    const steps = 4;
    expect(step * (steps + 1), lessThan(kLongPressTimeout));
    final gesture = await tester.startGesture(corner);
    await tester.pump(step);
    final delta =
        Offset((end.dx - corner.dx) / steps, (end.dy - corner.dy) / steps);
    for (var i = 0; i < steps; i++) {
      await gesture.moveBy(delta);
      await tester.pump(step);
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(calls, [
      [0, 2]
    ], reason: 'le coin de la cible tactile n\'a rien amorcé');
    expect(_visualOrder(tester, ids), ['b', 'c', 'a', 'd']);
    expect(tester.takeException(), isNull);
  });

  // ---------------------------------------------------------------------------
  // Gd — sans poignée soumise, le rendu est celui relevé AVANT le lot.
  // ---------------------------------------------------------------------------
  testWidgets(
      'Gd : sans poignee soumise, la geometrie rendue est celle relevee AVANT '
      'le lot, au pixel — et aucun declencheur immediat n\'est pose',
      (tester) async {
    final ids = ['a', 'b', 'c', 'd', 'e'];
    await tester.pumpWidget(_wrap(ZReorderableAdaptiveGrid(
      itemIds: ids,
      // Sonde qui OCCUPE la cellule : une marge insérée entre la cellule et
      // l'item la rétrécirait. Le seul repère du texte ne suffit PAS — un
      // encart symétrique autour d'un enfant centré laisse le texte au même
      // pixel (mesuré : une marge de 4 dp ne déplace pas un `Center`).
      itemBuilder: (c, i) => SizedBox.expand(
        key: ValueKey<String>('item-${ids[i]}'),
        child: Center(child: Text(ids[i], textDirection: TextDirection.ltr)),
      ),
      onReorder: (_, _) {},
      minItemWidth: 200,
      spacing: 0,
      itemHeight: 100,
      moveBeforeSemanticLabel: kMoveBefore,
      moveAfterSemanticLabel: kMoveAfter,
    )));

    // Relevé effectué sur le code d'AVANT le lot (sonde jetable, 600×600,
    // 3 colonnes de 200×100) et recopié ici tel quel.
    const cellGeometry = <Rect>[
      Rect.fromLTWH(0, 0, 200, 100),
      Rect.fromLTWH(200, 0, 200, 100),
      Rect.fromLTWH(400, 0, 200, 100),
      Rect.fromLTWH(0, 100, 200, 100),
      Rect.fromLTWH(200, 100, 200, 100),
    ];
    const textTopLeft = <Offset>[
      Offset(93, 43),
      Offset(293, 43),
      Offset(493, 43),
      Offset(93, 143),
      Offset(293, 143),
    ];

    final cells = find.byType(DragTarget<int>);
    expect(cells, findsNWidgets(5));
    for (var i = 0; i < 5; i++) {
      expect(tester.getTopLeft(cells.at(i)), cellGeometry[i].topLeft);
      expect(tester.getSize(cells.at(i)), cellGeometry[i].size);
      expect(tester.getTopLeft(find.text(ids[i])), textTopLeft[i]);
      expect(tester.getSize(find.text(ids[i])), const Size(14, 14));
      // L'item occupe la cellule ENTIÈRE : rien n'a été inséré entre les deux.
      expect(tester.getRect(find.byKey(ValueKey<String>('item-${ids[i]}'))),
          cellGeometry[i],
          reason: 'un encart a été inséré entre la cellule et son item');
    }

    // Aucune poignée soumise ⇒ aucun déclencheur immédiat n'existe : seul le
    // déclencheur à appui long de la cellule est posé.
    expect(find.byType(Draggable<int>), findsNothing);
    expect(find.byType(LongPressDraggable<int>), findsNWidgets(5));

    // …et le geste historique donne toujours le même résultat.
    await _longPressDrag(tester, 'a', 'c');
    expect(_visualOrder(tester, ids), ['b', 'c', 'a', 'd', 'e']);
    expect(tester.takeException(), isNull);
  });

  // ---------------------------------------------------------------------------
  // Ge [AD-10] — restauration sur échec, par les DEUX chemins.
  // ---------------------------------------------------------------------------
  testWidgets(
      'Ge : un onReorder qui leve RESTAURE l\'ordre affiche — par la poignee '
      'comme par l\'appui long (AD-10)', (tester) async {
    final ids = ['a', 'b', 'c', 'd'];
    var calls = 0;
    await tester.pumpWidget(_wrap(_grid(
      ids: ids,
      onReorder: (_, _) {
        calls++;
        throw StateError('persistance HS');
      },
    )));

    expect(_visualOrder(tester, ids), ['a', 'b', 'c', 'd']);

    // (1) Chemin APPUI LONG.
    await _longPressDrag(tester, 'a', 'c');
    expect(calls, 1, reason: 'le geste de cellule n\'a pas atteint l\'hôte');
    expect(_visualOrder(tester, ids), ['a', 'b', 'c', 'd'],
        reason: 'repli AD-10 : l\'ordre optimiste est annulé (appui long)');
    expect(tester.takeException(), isNull);

    // (2) Chemin POIGNÉE.
    await _handleDrag(tester, 'a', 'c');
    expect(calls, 2, reason: 'la poignée n\'a pas atteint l\'hôte');
    expect(_visualOrder(tester, ids), ['a', 'b', 'c', 'd'],
        reason: 'repli AD-10 : l\'ordre optimiste est annulé (poignée)');
    expect(tester.takeException(), isNull);
  });
}
