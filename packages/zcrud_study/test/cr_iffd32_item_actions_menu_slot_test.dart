// CR-IFFD-32 — `ZItemActionsMenu` imposait une COLONNE UNIQUE (`PopupMenuItem`
// empilés), sans aucune couture de disposition. Au-delà de six ou sept entrées,
// une colonne impose un balayage vertical long sur une surface flottante.
//
// Forme retenue (arbitrée, cf. doc de `menuBuilder`) : un **SLOT** de
// présentation, pas une option de grille — le socle n'a pas à figer l'ergonomie
// d'un menu flottant. Ce qui reste sa propriété, et que ces gardes verrouillent :
//   1. `menuBuilder == null` ⇒ colonne par défaut STRICTEMENT inchangée ;
//   2. la liste transmise au slot est DÉJÀ filtrée par « `onSelected == null` ⇒
//      action ABSENTE » (AD-4) — la règle est INOPPOSABLE à l'hôte ;
//   3. `select` invoque l'action EXACTEMENT une fois ET ferme la surface, par le
//      MÊME chemin que le rendu par défaut (aucune divergence possible).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study/zcrud_study.dart';

const String kOpen = 'OUVRIR-XYZ';
const String kRename = 'RENOMMER-XYZ';
const String kAbsent = 'SUPPRIMER-ABSENTE';

/// Clé de la cellule rendue par l'HÔTE (jamais un `PopupMenuItem` du socle).
ValueKey<String> _cellKey(String label) => ValueKey<String>('host-cell-$label');

Widget _wrap(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ZcrudScope(child: Scaffold(body: Center(child: child))),
    );

/// Présentation d'hôte en GRILLE bornée (le cas d'usage de la CR) : elle prouve
/// qu'une disposition non-colonne est atteignable SANS que le socle la fige.
Widget _hostGrid(
  BuildContext context,
  List<ZItemAction> actions,
  void Function(ZItemAction) select,
) =>
    SizedBox(
      width: 260,
      child: Wrap(
        children: <Widget>[
          for (final ZItemAction action in actions)
            SizedBox(
              key: _cellKey(action.label),
              width: 120,
              height: 56,
              child: InkWell(
                onTap: () => select(action),
                child: Center(child: Text(action.label)),
              ),
            ),
        ],
      ),
    );

void main() {
  group('CR-IFFD-32 — défaut : colonne unique STRICTEMENT inchangée', () {
    testWidgets('menuBuilder null ⇒ un PopupMenuItem par action visible',
        (tester) async {
      await tester.pumpWidget(_wrap(ZItemActionsMenu(
        actions: <ZItemAction>[
          ZItemAction(
            kind: ZItemActionKind.open,
            label: kOpen,
            icon: Icons.open_in_new,
            onSelected: () {},
          ),
          ZItemAction(
            kind: ZItemActionKind.rename,
            label: kRename,
            icon: Icons.edit,
            onSelected: () {},
          ),
        ],
      )));
      await tester.tap(find.byType(ZItemActionsMenu));
      await tester.pumpAndSettle();

      expect(find.byType(PopupMenuItem<ZItemAction>), findsNWidgets(2),
          reason: 'le rendu par défaut reste la colonne de PopupMenuItem');
      expect(find.text(kOpen), findsOneWidget);
      expect(find.text(kRename), findsOneWidget);
    });
  });

  group('CR-IFFD-32 — slot de présentation', () {
    testWidgets('🔴 menuBuilder non-null ⇒ la présentation de l\'HÔTE est rendue '
        '(et AUCUN PopupMenuItem du socle)', (tester) async {
      await tester.pumpWidget(_wrap(ZItemActionsMenu(
        menuBuilder: _hostGrid,
        actions: <ZItemAction>[
          ZItemAction(
            kind: ZItemActionKind.open,
            label: kOpen,
            icon: Icons.open_in_new,
            onSelected: () {},
          ),
          ZItemAction(
            kind: ZItemActionKind.rename,
            label: kRename,
            icon: Icons.edit,
            onSelected: () {},
          ),
        ],
      )));
      await tester.tap(find.byType(ZItemActionsMenu));
      await tester.pumpAndSettle();

      expect(find.byKey(_cellKey(kOpen)), findsOneWidget);
      expect(find.byKey(_cellKey(kRename)), findsOneWidget);
      // 🔴 Le socle ne DOUBLE pas la présentation : si la colonne par défaut
      // était encore construite, la surface porterait les deux.
      expect(find.byType(PopupMenuItem<ZItemAction>), findsNothing,
          reason: 'le slot REMPLACE la colonne, il ne s\'y ajoute pas');
    });

    testWidgets('🔴 disposition NON-COLONNE effective : deux cellules sur la '
        'MÊME ordonnée', (tester) async {
      // Mesure par ORDONNÉES RÉELLES (jamais par présence) : c'est la seule
      // façon de prouver que l'hôte n'est pas re-empilé en colonne par le socle
      // (`PopupMenuItem` imposerait sa hauteur et son padding au sous-arbre).
      await tester.pumpWidget(_wrap(ZItemActionsMenu(
        menuBuilder: _hostGrid,
        actions: <ZItemAction>[
          ZItemAction(
            kind: ZItemActionKind.open,
            label: kOpen,
            icon: Icons.open_in_new,
            onSelected: () {},
          ),
          ZItemAction(
            kind: ZItemActionKind.rename,
            label: kRename,
            icon: Icons.edit,
            onSelected: () {},
          ),
        ],
      )));
      await tester.tap(find.byType(ZItemActionsMenu));
      await tester.pumpAndSettle();

      final double y1 = tester.getTopLeft(find.byKey(_cellKey(kOpen))).dy;
      final double y2 = tester.getTopLeft(find.byKey(_cellKey(kRename))).dy;
      expect((y1 - y2).abs(), lessThan(0.5),
          reason: 'les deux cellules partagent une ligne : la colonne unique '
              'n\'est plus imposée');
    });

    testWidgets('🔴 AD-4 non régressée : le slot ne REÇOIT PAS l\'action à '
        'onSelected null', (tester) async {
      late List<ZItemAction> received;
      await tester.pumpWidget(_wrap(ZItemActionsMenu(
        menuBuilder: (context, actions, select) {
          received = actions;
          return _hostGrid(context, actions, select);
        },
        actions: <ZItemAction>[
          ZItemAction(
            kind: ZItemActionKind.open,
            label: kOpen,
            icon: Icons.open_in_new,
            onSelected: () {},
          ),
          // Capacité ABSENTE : elle ne doit jamais parvenir à l'hôte, sans quoi
          // il pourrait la rendre grisée — ce que la CR demande de préserver.
          const ZItemAction(
            kind: ZItemActionKind.delete,
            label: kAbsent,
            icon: Icons.delete,
          ),
        ],
      )));
      await tester.tap(find.byType(ZItemActionsMenu));
      await tester.pumpAndSettle();

      expect(received.map((ZItemAction a) => a.label), <String>[kOpen]);
      expect(find.text(kAbsent), findsNothing);
      expect(find.byKey(_cellKey(kAbsent)), findsNothing);
    });

    testWidgets('🔴 select() invoque l\'action EXACTEMENT 1× ET ferme la surface',
        (tester) async {
      var opens = 0;
      var renames = 0;
      await tester.pumpWidget(_wrap(ZItemActionsMenu(
        menuBuilder: _hostGrid,
        actions: <ZItemAction>[
          ZItemAction(
            kind: ZItemActionKind.open,
            label: kOpen,
            icon: Icons.open_in_new,
            onSelected: () => opens++,
          ),
          ZItemAction(
            kind: ZItemActionKind.rename,
            label: kRename,
            icon: Icons.edit,
            onSelected: () => renames++,
          ),
        ],
      )));
      await tester.tap(find.byType(ZItemActionsMenu));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_cellKey(kOpen)));
      await tester.pumpAndSettle();

      expect(opens, 1, reason: 'ni zéro (chemin mort) ni deux (double appel)');
      expect(renames, 0, reason: 'seule l\'action tapée est invoquée');
      // Fermeture par le MÊME chemin que le défaut : la surface a disparu.
      expect(find.byKey(_cellKey(kOpen)), findsNothing,
          reason: 'select() doit fermer la surface flottante');
    });
  });
}
