// TRIPWIRE — surface de l'aperçu flottant du renderer adossé au paquet tiers.
//
// Contexte mesuré. L'aperçu d'un glissement vit dans l'`Overlay`, hors de la
// route : un contenu de cellule qui comptait sur la feuille `Material` de
// l'écran ne l'y trouve plus et lève « No Material widget found ». Le repli
// zéro-dépendance de `zcrud_responsive` avait ce défaut ; il consomme désormais
// le canal `ZReorderRenderRequest.dragPreviewWrapper`.
//
// Ce renderer-ci, LUI, ne consomme PAS ce canal — décision mesurée, pas un
// oubli :
//
//  1. le défaut n'y existe pas : le châssis tiers construit lui-même son proxy
//     de glissement et l'enveloppe déjà dans une feuille `Material` ;
//  2. le seul point d'extension qui permettrait d'y injecter un habillage
//     (`dragWidgetBuilderV2`) REMPLACE ce proxy par défaut au lieu de
//     l'envelopper — mesuré : le passer, fût-ce en identité stricte, retire la
//     feuille du châssis et changerait le rendu de tous les hôtes.
//
// Ce fichier AFFIRME donc la propriété dont ce choix dépend, plutôt que de la
// supposer : le jour où le châssis cessera d'offrir une feuille à son aperçu,
// ce test rougira et désignera le canal à consommer.
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_reorder/zcrud_reorder.dart';

const List<String> _ids = <String>['A', 'B', 'C'];

/// Cellule qui dépend d'un ancêtre absent de l'`Overlay` : le `TextField` exige
/// une feuille `Material`, que seul le `Scaffold` de l'hôte fournit.
Widget _cellule(BuildContext context, int index) => Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(_ids[index]),
        const SizedBox(height: 40, width: 100, child: TextField()),
      ],
    );

Widget _hote(Widget child) => MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 600, height: 600, child: child),
      ),
    );

Widget _grille({ZReorderDragPreviewWrapper? wrapper}) {
  const ZReorderRenderer renderer = ZPackageReorderRenderer();
  return Builder(
    builder: (context) => renderer.build(
      context,
      ZReorderRenderRequest(
        itemIds: _ids,
        itemBuilder: _cellule,
        onReorder: (_, _) {},
        minItemWidth: 200,
        itemHeight: 100,
        spacing: 0,
        dragPreviewWrapper: wrapper,
      ),
    ),
  );
}

/// Éléments montés HORS de la route — c'est-à-dire dans l'`Overlay`, donc
/// appartenant à l'aperçu et à lui seul. La position à l'écran ne discrimine
/// rien : l'aperçu naît superposé à la cellule d'origine.
List<Element> _dansOverlay(Finder finder) => finder
    .evaluate()
    .where((e) => e.findAncestorWidgetOfExactType<Scaffold>() == null)
    .toList();

/// Engage un glissement, laisse l'aperçu monté, et rend ce qui a levé.
Future<({Object? leve, TestGesture geste})> _engage(WidgetTester tester) async {
  final gesture = await tester.startGesture(tester.getCenter(find.text('A')));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
  await gesture.moveTo(tester.getCenter(find.text('C').first));
  await tester.pump();
  return (leve: tester.takeException(), geste: gesture);
}

Future<void> _relache(WidgetTester tester, TestGesture gesture) async {
  await gesture.up();
  await tester.pumpAndSettle();
  tester.takeException();
}

void main() {
  testWidgets(
      'l\'aperçu du châssis tiers offre bien la feuille que l\'overlay a '
      'perdue — une cellule à sous-champ Material s\'y glisse sans lever',
      (tester) async {
    await tester.pumpWidget(_hote(_grille()));
    await tester.pump();

    final engagement = await _engage(tester);
    expect(engagement.leve, isNull,
        reason: 'le châssis tiers ne protège plus son aperçu : ce renderer '
            'doit désormais consommer request.dragPreviewWrapper');

    // Le sous-champ de l'aperçu est bien monté HORS de la route — sans quoi le
    // vert ci-dessus ne dirait rien (il n'y aurait tout simplement pas
    // d'aperçu à protéger).
    final apercus = _dansOverlay(find.byType(TextField));
    expect(apercus, hasLength(1),
        reason: 'aucun aperçu monté dans l\'overlay : la mesure est vide');
    expect(
      apercus.single.findAncestorWidgetOfExactType<Material>(),
      isNotNull,
      reason: 'c\'est cette feuille, posée par le châssis tiers, qui rend le '
          'canal inutile ici',
    );

    await _relache(tester, engagement.geste);
  });

  testWidgets(
      'le canal est délibérément IGNORÉ : le remplir ne change ni l\'arbre de '
      'l\'aperçu, ni ce qu\'il rend possible', (tester) async {
    Widget marque(Widget preview) => Padding(
          padding: const EdgeInsets.all(7),
          child: preview,
        );

    // Un arbre NEUF pour chaque scénario : la grille tient un ordre optimiste
    // local que `didUpdateWidget` ne réaligne pas tant que `itemIds` est
    // inchangé, et deux mesures comparables doivent partir de la même
    // disposition.
    final rects = <Rect>[];
    for (final wrapper in <ZReorderDragPreviewWrapper?>[null, marque]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(_hote(_grille(wrapper: wrapper)));
      await tester.pump();

      final engagement = await _engage(tester);
      expect(engagement.leve, isNull);

      final apercus = _dansOverlay(find.byType(TextField));
      expect(apercus, hasLength(1));
      // Une enveloppe de 7 dp de marge déplacerait le sous-champ de l'aperçu :
      // si le canal était consommé, les deux rectangles différeraient.
      rects.add(tester.getRect(find.byElementPredicate((e) => e == apercus.single)));

      await _relache(tester, engagement.geste);
    }

    expect(
      rects[1],
      rects[0],
      reason: 'le canal n\'est pas censé être consommé par ce renderer — s\'il '
          'l\'est devenu, vérifier d\'abord que la feuille du châssis n\'a pas '
          'été perdue au passage',
    );
  });
}
