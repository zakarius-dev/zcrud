// TRIPWIRE du contrat de POIGNÉE (`ZReorderRenderer.buildDragHandle`) sous le
// renderer adossé à `reorderable_grid_view`.
//
// Le port `zcrud_core` offre une capacité FACULTATIVE : ancrer le geste de
// réorganisation sur une poignée. Son défaut est l'IDENTITÉ, et sa dartdoc
// déclare légitime de ne pas l'honorer quand le châssis n'expose aucun
// déclencheur par poignée. `ZPackageReorderRenderer` est dans ce cas — et ce
// fichier est là pour que ce constat reste MESURÉ, jamais présumé.
//
// POURQUOI le défaut est conservé (mesuré sur `reorderable_grid_view` 2.2.8) :
//
//   1. Le déclencheur du paquet est un `Listener(onPointerDown:)` posé autour de
//      la CELLULE ENTIÈRE, à l'intérieur du `ReorderableItemView` que le paquet
//      fabrique lui-même autour de notre `itemBuilder`. Notre sous-arbre est
//      donc toujours un DESCENDANT de ce déclencheur : on ne peut pas se placer
//      en amont de lui.
//   2. Le recognizer est choisi GLOBALEMENT par la grille (le délai vient d'une
//      propriété du widget-grille, pas de l'item) : aucune variante par item ni
//      par sous-arbre n'existe.
//   3. Un `PointerDownEvent` est distribué du plus PROFOND vers la racine. Un
//      déclencheur que nous poserions autour de la poignée serait servi AVANT
//      celui de la cellule, qui rappellerait ensuite le sien — et cette
//      installation commence par réinitialiser le drag en cours, donc par jeter
//      le nôtre. Mesuré : l'ancrage sur la poignée reste SANS EFFET, que
//      l'appel soit synchrone ou différé dans une microtâche.
//   4. Le seul symbole capable d'amorcer un drag (`startDragRecognizer`) vit
//      dans un fichier `src/` NON exporté par le barrel du paquet. L'atteindre
//      demande soit un import d'implémentation — refusé par le lint
//      `implementation_imports` de la baseline du monorepo — soit un appel
//      `dynamic` qui blanchit ce même lint : une dépendance à une API privée
//      que plus AUCUN outil ne vérifierait, et qui deviendrait un
//      `NoSuchMethodError` silencieux au premier renommage amont.
//
// CE QU'IL FAUDRAIT POUR EN SORTIR — l'un de ces trois, aucun autre :
//   (a) le paquet amont expose un déclencheur par sous-arbre (un équivalent de
//       `ReorderableDragStartListener`) dans son API PUBLIQUE ;
//   (b) le paquet amont rend le délai d'amorce réglable PAR ITEM ;
//   (c) ce satellite change de châssis pour un paquet qui offre (a).
//
// ⚠️ La seule configuration où un ancrage sur la poignée FONCTIONNE a été
// mesurée : désactiver le déclencheur d'item du paquet (`dragEnabled: false`)
// puis amorcer soi-même depuis la poignée. Elle est REFUSÉE : elle CONFISQUE le
// geste propre à l'item — que le point 3 du contrat de `buildDragHandle` exige
// de laisser tel quel — et elle repose sur l'appel `dynamic` du §4.
// ⚠️ `dragStartDelay: Duration.zero` est REFUSÉ pour la raison inverse : le
// délai étant global à la grille, il rendrait la CELLULE ENTIÈRE glissable au
// premier contact — le conflit de gestes qu'on cherche à éviter, aggravé par
// les sous-champs éditables des lignes.
//
// Gardes (discipline R3 — chacune prouvée MORDANTE, journal `r3.txt`) :
//   H1 : le sous-arbre rendu pour la poignée est l'ENFANT LUI-MÊME — rien
//        d'intercalé entre la poignée et la cellule. Comparaison à un TÉMOIN
//        rendu sans passer par `buildDragHandle`, pas à une liste figée.
//        Régression injectée : `buildDragHandle` redéfini pour envelopper la
//        poignée dans un `Listener` ⇒ ROUGE par assertion.
//   H2 : TRIPWIRE D'HÉRITAGE DU DÉFAUT — un glissement amorcé sur la poignée
//        SANS appui long ne réorganise RIEN ; le même geste APRÈS appui long
//        réorganise. La garde AFFIRME LA PERTE : le jour où l'amont expose un
//        déclencheur et où quelqu'un l'honore ici, H2 rougit et désigne
//        elle-même son obsolescence.
//        Régression injectée : renderer forçant `dragEnabled: false` + amorce
//        `dynamic` sur la poignée ⇒ ROUGE par assertion.
//   H3 : NON-CONFISCATION — le geste propre à la cellule (appui long) continue
//        de réorganiser. C'est ce que casserait toute « solution » passant par
//        `dragEnabled: false`.
//        Même régression injectée que H2 ⇒ ROUGE par assertion.

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_reorder/zcrud_reorder.dart';

import 'reorder_test_harness.dart';

const ValueKey<String> _handleKey = ValueKey<String>('poignee-a');
const ValueKey<String> _cellKey = ValueKey<String>('cellule-a');

/// Poignée de référence : mêmes traits que celle du cœur (cible ≥ 48 dp,
/// libellé sémantique) — c'est bien une poignée qu'on soumet au renderer, pas
/// un `SizedBox` anonyme.
Widget _handle(String id) => Semantics(
      key: id == 'a' ? _handleKey : ValueKey<String>('poignee-$id'),
      label: 'Deplacer $id',
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(child: Text('H-$id', textDirection: TextDirection.ltr)),
      ),
    );

/// Requête dont chaque cellule porte une poignée en tête, comme la sous-liste
/// du cœur. [throughPort] à `false` construit le TÉMOIN : la même poignée,
/// posée SANS passer par `buildDragHandle`.
ZReorderRenderRequest _requestWithHandles({
  required List<String> ids,
  required ZReorderRenderer renderer,
  required void Function(int oldIndex, int newIndex) onReorder,
  bool throughPort = true,
}) {
  return ZReorderRenderRequest(
    itemIds: ids,
    itemBuilder: (context, index) {
      final String id = ids[index];
      final Widget handle = _handle(id);
      return Column(
        key: id == 'a' ? _cellKey : ValueKey<String>('cellule-$id'),
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          throughPort
              ? renderer.buildDragHandle(context, index, handle)
              : handle,
          Text(id, textDirection: TextDirection.ltr),
        ],
      );
    },
    onReorder: onReorder,
    minItemWidth: 200,
    spacing: 0,
    itemHeight: 200,
    minColumns: 1,
  );
}

/// Chaîne des widgets RÉELLEMENT interposés entre la poignée et la racine de
/// cellule, lue sur l'arbre monté. Propriété OBSERVABLE : c'est elle qui
/// grossit dès qu'un geste, une décoration ou une sémantique s'intercale.
List<String> _interposedBetweenHandleAndCell(WidgetTester tester) {
  // Pré-conditions ANTI-TAUTOLOGIE : sans elles, une poignée jamais montée
  // rendrait une chaîne vide, donc une garde verte pour la mauvaise raison.
  expect(find.byKey(_handleKey), findsOneWidget,
      reason: 'la poignee n\'est pas montee : la lecture d\'arbre ne mesure rien');
  expect(
    find.ancestor(of: find.byKey(_handleKey), matching: find.byKey(_cellKey)),
    findsOneWidget,
    reason: 'la racine de cellule n\'est pas un ancetre de la poignee : la '
        'chaine lue ne serait pas bornee',
  );
  final List<String> types = <String>[];
  final Finder ancestors = find.ancestor(
    of: find.byKey(_handleKey),
    matching: find.byWidgetPredicate((_) => true),
  );
  for (final Widget w in tester.widgetList(ancestors)) {
    if (w.key == _cellKey) break;
    types.add(w.runtimeType.toString());
  }
  return types;
}

Future<List<String>> _dragFromHandle(
  WidgetTester tester, {
  required bool longPress,
}) async {
  final List<String> calls = <String>[];
  const ZReorderRenderer renderer = ZPackageReorderRenderer();
  final List<String> ids = <String>['a', 'b', 'c'];
  await tester.pumpWidget(wrapRenderer(
    renderer,
    _requestWithHandles(
      ids: ids,
      renderer: renderer,
      onReorder: (o, n) => calls.add('$o->$n'),
    ),
  ));
  await tester.pump();
  final TestGesture gesture =
      await tester.startGesture(tester.getCenter(find.text('H-a')));
  await tester.pump(longPress
      ? kLongPressTimeout + const Duration(milliseconds: 100)
      : const Duration(milliseconds: 16));
  await gesture.moveTo(tester.getCenter(find.text('b')));
  await tester.pump(const Duration(milliseconds: 16));
  await gesture.moveTo(tester.getCenter(find.text('b')));
  await tester.pump(const Duration(milliseconds: 16));
  await gesture.up();
  await tester.pumpAndSettle();
  return calls;
}

void main() {
  // ---------------------------------------------------------------------------
  // H1 — le sous-arbre rendu pour la poignée est l'ENFANT LUI-MÊME.
  // ---------------------------------------------------------------------------
  testWidgets(
      'H1 : rien n\'est intercale entre la poignee et la cellule — l\'arbre '
      'monte est IDENTIQUE a celui du temoin sans buildDragHandle',
      (tester) async {
    const ZReorderRenderer renderer = ZPackageReorderRenderer();
    final List<String> ids = <String>['a', 'b', 'c'];

    // TÉMOIN : poignée posée directement, sans passer par le port.
    await tester.pumpWidget(wrapRenderer(
      renderer,
      _requestWithHandles(
        ids: ids,
        renderer: renderer,
        onReorder: (_, _) {},
        throughPort: false,
      ),
    ));
    await tester.pump();
    final List<String> control = _interposedBetweenHandleAndCell(tester);

    // SUJET : la même poignée, soumise au port.
    await tester.pumpWidget(wrapRenderer(
      renderer,
      _requestWithHandles(
        ids: ids,
        renderer: renderer,
        onReorder: (_, _) {},
      ),
    ));
    await tester.pump();
    final List<String> subject = _interposedBetweenHandleAndCell(tester);

    expect(subject, equals(control),
        reason: 'buildDragHandle a intercale ${subject.length - control.length} '
            'widget(s) entre la poignee et '
            'la cellule : le defaut identite du port n\'est plus herite. '
            'Verifier alors que H2 a change de verdict — sinon la poignee a '
            'ete habillee sans etre rendue vivante.');
  });

  testWidgets(
      'H1b : buildDragHandle rend l\'objet RECU, sans copie ni enveloppe',
      (tester) async {
    const Widget handle = SizedBox(width: 48, height: 48);
    Widget? returned;
    Object? thrown;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Builder(builder: (context) {
        // Contexte RÉEL et monté : une redéfinition qui consulterait le
        // contexte serait exercée pour de bon, et son échec deviendrait un
        // verdict d'assertion (ci-dessous) plutôt qu'une exception de test.
        try {
          returned =
              const ZPackageReorderRenderer().buildDragHandle(context, 0, handle);
        } catch (e) {
          thrown = e;
        }
        return const SizedBox.shrink();
      }),
    ));
    expect(thrown, isNull,
        reason: 'buildDragHandle a leve : le defaut identite ne peut pas lever');
    expect(identical(returned, handle), isTrue,
        reason: 'le renderer ne retourne plus la poignee telle quelle');
  });

  // ---------------------------------------------------------------------------
  // H2 [TRIPWIRE] — la poignée N'EST PAS vivante sous ce renderer.
  // ---------------------------------------------------------------------------
  testWidgets(
      'H2 : un glissement amorce sur la POIGNEE sans appui long ne reorganise '
      'RIEN (le defaut identite est herite)', (tester) async {
    final List<String> calls = await _dragFromHandle(tester, longPress: false);
    expect(calls, isEmpty,
        reason: 'la poignee est devenue VIVANTE sous ce renderer. Si c\'est '
            'voulu et prouve (le chassis expose enfin un declencheur par '
            'sous-arbre), cette garde a fait son office : la remplacer par la '
            'garde inverse et retirer la reserve de la doc du renderer. Sinon, '
            'un geste vient d\'etre ancre sans que le chassis le permette.');
  });

  testWidgets(
      'H2b : le meme geste APRES appui long reorganise — la poignee reste une '
      'affordance, jamais une zone morte', (tester) async {
    final List<String> calls = await _dragFromHandle(tester, longPress: true);
    expect(calls, equals(<String>['0->1']),
        reason: 'la poignee est devenue une zone MORTE : l\'appui long qui '
            'porte le geste de la cellule ne passe plus');
  });

  // ---------------------------------------------------------------------------
  // H3 — non-confiscation du geste propre à la cellule.
  // ---------------------------------------------------------------------------
  testWidgets(
      'H3 : le geste propre a la CELLULE (appui long hors poignee) reorganise '
      'toujours', (tester) async {
    final List<String> calls = <String>[];
    const ZReorderRenderer renderer = ZPackageReorderRenderer();
    final List<String> ids = <String>['a', 'b', 'c'];
    await tester.pumpWidget(wrapRenderer(
      renderer,
      _requestWithHandles(
        ids: ids,
        renderer: renderer,
        onReorder: (o, n) => calls.add('$o->$n'),
      ),
    ));
    await tester.pump();
    final TestGesture gesture =
        await tester.startGesture(tester.getCenter(find.text('a')));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(find.text('b')));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(calls, equals(<String>['0->1']),
        reason: 'le geste de la cellule a ete CONFISQUE — c\'est exactement ce '
            'que produit un ancrage obtenu en desactivant le declencheur '
            'd\'item du chassis (dragEnabled: false)');
  });
}
