// HABILLAGE de l'aperçu flottant — canal `dragPreviewWrapper`.
//
// Le défaut mesuré : l'aperçu d'un glissement est monté dans l'`Overlay`, donc
// SIBLING de la route et jamais dessous. Une cellule qui portait un `TextField`
// — lequel compte sur la feuille `Material` du `Scaffold` — y lève
// « No Material widget found » : écran rouge en debug, silence en release.
// Reproduit sur les DEUX déclencheurs (appui long sur la cellule, glissement
// parti d'une poignée), qui servent le même aperçu.
//
// Ce satellite ne peut pas poser la feuille lui-même : il est bâti sur
// `package:flutter/widgets.dart` seul, et le reste. Il expose donc un canal —
// `null` par défaut, donc identité — que l'appelant remplit.
//
// Ce fichier mesure TROIS propriétés :
//  (a) canal rempli ⇒ les deux chemins glissent SANS lever ; canal vide ⇒ ils
//      lèvent (contrôle négatif, sans lequel le vert ne dirait rien) ;
//  (b) INERTIE — canal vide ⇒ aucun nœud interposé et géométrie de l'aperçu
//      inchangée ; canal rempli ⇒ EXACTEMENT un nœud de plus, même géométrie ;
//  (c) l'habillage ne touche que l'APERÇU — jamais la cellule rendue en place,
//      ni avant, ni pendant, ni après le glissement.
//
// L'import `material` est celui du TEST : il fournit le `TextField` qui a levé
// et l'hôte qui lui manquait. Le paquet mesuré, lui, n'en importe rien.
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_responsive/zcrud_responsive.dart';

const List<String> _ids = <String>['A', 'B', 'C'];

/// Marqueur INERTE : ne peint rien, n'impose aucune contrainte, n'ajoute aucune
/// sémantique. Il sert à COMPTER et à LOCALISER ce que le canal interpose —
/// pas à fournir quoi que ce soit.
class _Marqueur extends StatelessWidget {
  const _Marqueur({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// Cellule qui dépend d'un ancêtre absent de l'`Overlay` : le `TextField` exige
/// une feuille `Material`, que seul le `Scaffold` de l'hôte fournit.
Widget _cellule(BuildContext context, int index) => Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(_ids[index]),
        const SizedBox(height: 40, width: 100, child: TextField()),
      ],
    );

/// Monte [child] dans un arbre NEUF.
///
/// Un `pumpWidget` successif réutilise le `State` de la grille — même type,
/// même position, pas de clé — et `didUpdateWidget` ne réaligne l'ordre local
/// que si `itemIds` a changé. Sans cette purge, un scénario hériterait de
/// l'ordre optimiste laissé par le précédent, et deux mesures censées être
/// comparables porteraient sur des dispositions différentes.
Future<void> _monte(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pumpWidget(_hote(child));
  await tester.pump();
}

Widget _hote(Widget child) => MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 600, height: 600, child: child),
      ),
    );

/// Surface de transparence — l'habillage réel qu'un appelant Material fournit.
Widget _surface(Widget preview) =>
    Material(type: MaterialType.transparency, child: preview);

/// Cellule SANS aucune exigence d'ancêtre : elle rend le même arbre partout.
///
/// C'est la cellule de la mesure d'inertie : avec un `TextField`, le rendu
/// « canal vide » substitue un widget d'erreur au champ qui lève, et comparer
/// deux arbres dont l'un est dégradé ne dirait rien de l'habillage.
Widget _celluleSimple(BuildContext context, int index) => Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(_ids[index]),
        const SizedBox(height: 40, width: 100),
      ],
    );

/// Grille NUE (usage direct de la primitive publique).
Widget _grille({
  ZReorderDragPreviewWrapper? wrapper,
  Widget Function(BuildContext, int) itemBuilder = _cellule,
}) =>
    ZReorderableAdaptiveGrid(
      itemIds: _ids,
      itemBuilder: itemBuilder,
      onReorder: (_, _) {},
      minItemWidth: 200,
      itemHeight: 100,
      spacing: 0,
      moveBeforeSemanticLabel: 'avant',
      moveAfterSemanticLabel: 'apres',
      dragPreviewWrapper: wrapper,
    );

/// Grille passée par le PORT, avec une poignée par cellule — c'est le second
/// déclencheur, celui qui part de la poignée et non de l'appui long.
Widget _grillePoignee({ZReorderDragPreviewWrapper? wrapper}) {
  const ZReorderRenderer renderer = ZDefaultReorderRenderer();
  return Builder(
    builder: (context) => renderer.build(
      context,
      ZReorderRenderRequest(
        itemIds: _ids,
        itemBuilder: (context, index) => Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            renderer.buildDragHandle(
              context,
              index,
              SizedBox(width: 48, height: 20, child: Text('H${_ids[index]}')),
            ),
            const SizedBox(height: 30, width: 100, child: TextField()),
            Text(_ids[index]),
          ],
        ),
        onReorder: (_, _) {},
        minItemWidth: 200,
        itemHeight: 100,
        spacing: 0,
        dragPreviewWrapper: wrapper,
      ),
    ),
  );
}

/// Engage un glissement et retourne ce qui a levé pendant le rendu de l'aperçu.
///
/// Le geste n'est pas relâché : c'est PENDANT le glissement que l'aperçu est
/// monté, donc le seul moment où la mesure a un sens.
Future<Object?> _glisse(
  WidgetTester tester,
  Finder depuis, {
  required bool appuiLong,
}) async {
  final gesture = await tester.startGesture(tester.getCenter(depuis));
  await tester.pump(appuiLong
      ? kLongPressTimeout + const Duration(milliseconds: 100)
      : const Duration(milliseconds: 16));
  await gesture.moveTo(tester.getCenter(find.text('C').first));
  await tester.pump();
  final Object? leve = tester.takeException();
  await gesture.up();
  await tester.pumpAndSettle();
  // Purge des exceptions de fin de geste, sans rapport avec la mesure.
  tester.takeException();
  return leve;
}

/// Marqueurs actuellement montés, séparés selon qu'ils vivent dans la grille
/// ou dans l'`Overlay` (un aperçu n'a aucun `Scaffold` au-dessus de lui —
/// c'est le seul discriminant fiable, la position à l'écran se confondant avec
/// celle de la cellule d'origine).
({int enPlace, int dansOverlay}) _marqueurs(WidgetTester tester) {
  int enPlace = 0;
  int dansOverlay = 0;
  for (final element in find.byType(_Marqueur).evaluate()) {
    if (element.findAncestorWidgetOfExactType<Scaffold>() == null) {
      dansOverlay++;
    } else {
      enPlace++;
    }
  }
  return (enPlace: enPlace, dansOverlay: dansOverlay);
}

/// Chaîne des types d'ancêtres de l'aperçu, de son contenu jusqu'à la racine —
/// et sa géométrie. C'est la mesure d'INERTIE : deux rendus dont ces deux
/// grandeurs coïncident sont indiscernables pour un hôte.
({List<String> chaine, Rect boite, Rect boiteApercu}) _apercu(
    WidgetTester tester) {
  // Le `Text` de l'aperçu est celui qui n'a pas de `Scaffold` au-dessus.
  Element? contenu;
  for (final element in find.text('A').evaluate()) {
    if (element.findAncestorWidgetOfExactType<Scaffold>() == null) {
      contenu = element;
      break;
    }
  }
  expect(contenu, isNotNull, reason: 'aucun aperçu monté dans l\'overlay');
  final chaine = <String>[];
  contenu!.visitAncestorElements((ancestor) {
    chaine.add(ancestor.widget.runtimeType.toString());
    // On s'arrête à la frontière de l'entrée d'overlay : au-delà, l'arbre est
    // celui du harnais, identique par construction.
    return !chaine.last.startsWith('_OverlayEntryWidget');
  });
  // Boîte de l'aperçu : le `SizedBox` le plus externe du sous-arbre monté dans
  // l'overlay, celui que la grille dimensionne à la taille MESURÉE de la
  // cellule. C'est lui qu'une enveloppe qui contraindrait ferait bouger.
  Element? boite;
  for (final element in find.byType(Opacity).evaluate()) {
    if (element.findAncestorWidgetOfExactType<Scaffold>() == null) {
      boite = element;
      break;
    }
  }
  expect(boite, isNotNull, reason: 'aperçu introuvable dans l\'overlay');
  return (
    chaine: chaine,
    boite: tester.getRect(find.byElementPredicate((e) => e == contenu)),
    boiteApercu: tester.getRect(find.byElementPredicate((e) => e == boite)),
  );
}

void main() {
  testWidgets(
      '(a) canal rempli ⇒ les DEUX chemins glissent sans lever ; canal vide ⇒ '
      'les deux lèvent « No Material widget found » (contrôle négatif)',
      (tester) async {
    for (final cas in <({String nom, Widget Function({ZReorderDragPreviewWrapper? wrapper}) grille, Finder depuis, bool appuiLong})>[
      (
        nom: 'appui long sur la cellule',
        grille: _grille,
        depuis: find.text('A'),
        appuiLong: true,
      ),
      (
        nom: 'glissement parti de la poignée',
        grille: _grillePoignee,
        depuis: find.text('HA'),
        appuiLong: false,
      ),
    ]) {
      // Contrôle NÉGATIF d'abord : sans lui, un vert plus bas ne prouverait
      // pas que le canal fait quoi que ce soit.
      await _monte(tester, cas.grille());
      expect(
        await _glisse(tester, cas.depuis, appuiLong: cas.appuiLong),
        isA<FlutterError>().having(
          (e) => e.message,
          'message',
          contains('No Material widget found'),
        ),
        reason: '${cas.nom} : le défaut doit être reproductible, sinon la '
            'mesure suivante ne dit rien',
      );

      await _monte(tester, cas.grille(wrapper: _surface));
      expect(
        await _glisse(tester, cas.depuis, appuiLong: cas.appuiLong),
        isNull,
        reason: '${cas.nom} : l\'aperçu lève encore malgré le canal rempli',
      );
    }
  });

  testWidgets(
      '(b) inertie — canal vide ⇒ aucun nœud interposé ; canal rempli ⇒ '
      'EXACTEMENT un nœud de plus, et la même géométrie d\'aperçu',
      (tester) async {
    // Habillage strictement inerte : toute différence observée vient donc de
    // l'interposition elle-même, jamais de ce que l'habillage ferait.
    await _monte(tester, _grille(itemBuilder: _celluleSimple));
    final gestureVide = await tester.startGesture(
        tester.getCenter(find.text('A')));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gestureVide.moveTo(tester.getCenter(find.text('C').first));
    await tester.pump();
    tester.takeException(); // le défaut du contrôle négatif, hors sujet ici
    final vide = _apercu(tester);
    await gestureVide.up();
    await tester.pumpAndSettle();
    tester.takeException();

    await _monte(
      tester,
      _grille(
        itemBuilder: _celluleSimple,
        wrapper: (p) => _Marqueur(child: p),
      ),
    );
    final gestureRempli = await tester.startGesture(
        tester.getCenter(find.text('A')));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gestureRempli.moveTo(tester.getCenter(find.text('C').first));
    await tester.pump();
    tester.takeException();
    final rempli = _apercu(tester);
    await gestureRempli.up();
    await tester.pumpAndSettle();
    tester.takeException();

    expect(
      vide.chaine.contains('_Marqueur'),
      isFalse,
      reason: 'canal vide : rien ne doit être interposé',
    );
    expect(
      rempli.chaine.length,
      vide.chaine.length + 1,
      reason: 'le canal doit interposer UN nœud, pas deux, pas zéro\n'
          'vide   : ${vide.chaine}\n'
          'rempli : ${rempli.chaine}',
    );
    expect(
      rempli.chaine.where((t) => t == '_Marqueur').length,
      1,
      reason: 'et ce nœud doit être celui de l\'habillage',
    );
    expect(
      <String>[...rempli.chaine]..remove('_Marqueur'),
      vide.chaine,
      reason: 'le nœud retiré, les deux chaînes doivent coïncider EXACTEMENT',
    );
    expect(
      rempli.boite,
      vide.boite,
      reason: 'l\'habillage ne doit rien changer à la place du CONTENU',
    );
    expect(
      rempli.boiteApercu,
      vide.boiteApercu,
      reason: 'ni à la boîte de l\'aperçu, dimensionnée sur la cellule',
    );
  });

  testWidgets(
      '(c) l\'habillage ne touche QUE l\'aperçu — la cellule en place n\'en '
      'porte jamais, avant, pendant, ni après le glissement', (tester) async {
    await _monte(tester, _grille(wrapper: (p) => _Marqueur(child: p)));
    expect(_marqueurs(tester), (enPlace: 0, dansOverlay: 0),
        reason: 'au repos, l\'habillage ne doit exister nulle part');

    final gesture = await tester.startGesture(tester.getCenter(find.text('A')));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(find.text('C').first));
    await tester.pump();
    tester.takeException();
    expect(
      _marqueurs(tester),
      (enPlace: 0, dansOverlay: 1),
      reason: 'pendant le glissement : un habillage, sur le seul aperçu — '
          'trois cellules habillées en place en donneraient trois de plus',
    );

    await gesture.up();
    await tester.pumpAndSettle();
    tester.takeException();
    expect(_marqueurs(tester), (enPlace: 0, dansOverlay: 0),
        reason: 'le glissement fini, l\'habillage disparaît avec l\'aperçu');
  });
}
