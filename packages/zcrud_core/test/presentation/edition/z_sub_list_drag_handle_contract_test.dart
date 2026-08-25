// Contrat de POIGNÉE du port `ZReorderRenderer.buildDragHandle`.
//
// Le défaut mesuré : le cœur enveloppait la poignée de la sous-liste dans un
// `ReorderableDragStartListener` du SDK, dont le `onPointerDown` est un no-op
// silencieux hors d'un `SliverReorderableList` (`list?.startItemDragReorder`,
// `flutter/lib/src/widgets/reorderable_list.dart:1454`). Aucun de nos rendus
// injectés n'emploie ce chassis : la poignée y était une affordance MORTE, et
// le glissement retombait sur l'appui long de la ligne — ligne qui porte les
// sous-champs éditables.
//
// Ce fichier mesure QUATRE propriétés :
//  (a) inertie — sans renderer injecté, le glissement part IMMÉDIATEMENT de la
//      poignée (mouvement engagé avant le seuil d'appui long) ;
//  (b) un renderer qui HONORE le contrat voit sa machinerie atteinte depuis le
//      `BuildContext` de la poignée, et le geste part de la POIGNÉE, pas de la
//      ligne ;
//  (c) un renderer qui ne l'honore PAS (défaut identité) laisse la poignée
//      rendue, la voie non gestuelle intacte, et rien ne lève ;
//  (d) le rendu par défaut est inchangé, et le cœur ne présume plus d'un
//      chassis (plus de listener réordonnable SDK posé à l'aveugle).
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _itemFields = <ZFieldSpec>[
  ZFieldSpec(name: 'f1', type: EditionFieldType.text, label: 'F1'),
];

ZFieldSpec _compactField() => const ZFieldSpec(
      name: 'items',
      type: EditionFieldType.subItems,
      label: 'Items',
      config: ZSubListConfig(
        itemFields: _itemFields,
        reorderable: true,
        summaryFields: <String>['f1'],
      ),
    );

const _seed = <Map<String, dynamic>>[
  <String, dynamic>{'f1': 'A'},
  <String, dynamic>{'f1': 'B'},
  <String, dynamic>{'f1': 'C'},
];

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

List<String> _values(List<Map<String, dynamic>> list) =>
    <String>[for (final it in list) it['f1'] as String];

Finder get _handles => find.byIcon(Icons.drag_indicator_rounded);

/// Taille de la cible tactile de la poignée [n] — propriété d'AD-13, mesurée
/// sur la géométrie rendue, jamais sur un nom de classe.
Size _handleTarget(WidgetTester tester, int n) => tester.getSize(
      find
          .ancestor(of: _handles.at(n), matching: find.byType(SizedBox))
          .first,
    );

/// Libellé sémantique porté par la poignée [n] (le `Semantics` le plus proche
/// du glyphe qui porte un libellé).
String? _handleSemanticLabel(WidgetTester tester, int n) {
  final semantics = tester.widgetList<Semantics>(
    find.ancestor(of: _handles.at(n), matching: find.byType(Semantics)),
  );
  for (final s in semantics) {
    final label = s.properties.label;
    if (label != null && label.isNotEmpty) return label;
  }
  return null;
}

/// Nombre de nœuds portant des actions sémantiques de déplacement — la voie
/// NON GESTUELLE du contrat (AD-13), seule atteignable au lecteur d'écran.
int _rowsWithMoveActions(WidgetTester tester) => tester
    .widgetList<Semantics>(find.byType(Semantics))
    .where((s) => (s.properties.customSemanticsActions ?? const {}).isNotEmpty)
    .length;

/// Canal privé d'un renderer de test vers ses poignées — le mécanisme même
/// qu'un satellite emploiera : `itemBuilder` étant appelé par le renderer, la
/// poignée naît DANS son sous-arbre, donc cet `InheritedWidget` y est
/// atteignable sans qu'aucun type du renderer n'entre dans le port.
class _TestDragScope extends InheritedWidget {
  const _TestDragScope({required this.onDragStart, required super.child});

  final void Function(int index) onDragStart;

  static _TestDragScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_TestDragScope>();

  @override
  bool updateShouldNotify(_TestDragScope oldWidget) => false;
}

/// Renderer de test qui **honore** le contrat de poignée.
class _HandleHonoringRenderer extends ZReorderRenderer {
  _HandleHonoringRenderer();

  final List<int> handleIndices = <int>[];
  int? gestureStartedOnHandleIndex;
  bool scopeReachedFromHandleContext = false;
  ZReorderRenderRequest? lastRequest;

  @override
  Widget build(BuildContext context, ZReorderRenderRequest request) {
    lastRequest = request;
    return _TestDragScope(
      onDragStart: (index) {
        gestureStartedOnHandleIndex = index;
        request.onReorder(index, index + 1);
      },
      child: Column(
        children: <Widget>[
          for (var i = 0; i < request.itemIds.length; i++)
            Semantics(
              container: true,
              customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
                if (request.moveBeforeSemanticLabel != null && i > 0)
                  CustomSemanticsAction(
                      label: request.moveBeforeSemanticLabel!): () =>
                      request.onReorder(i, i - 1),
                if (request.moveAfterSemanticLabel != null &&
                    i < request.itemIds.length - 1)
                  CustomSemanticsAction(
                      label: request.moveAfterSemanticLabel!): () =>
                      request.onReorder(i, i + 1),
              },
              child: request.itemBuilder(context, i),
            ),
        ],
      ),
    );
  }

  @override
  Widget buildDragHandle(BuildContext context, int index, Widget handle) {
    handleIndices.add(index);
    final scope = _TestDragScope.maybeOf(context);
    if (scope == null) return handle;
    scopeReachedFromHandleContext = true;
    // Glissement HORIZONTAL délibéré : aucun concurrent d'arène dans un hôte à
    // défilement vertical, donc la mesure porte sur l'ancrage, pas sur une
    // résolution d'arène.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => scope.onDragStart(index),
      child: handle,
    );
  }
}

/// Renderer de test qui **n'honore pas** le contrat de poignée : il ne
/// redéfinit PAS `buildDragHandle` (défaut identité du port). Il tient en
/// revanche la voie non gestuelle, qui n'est pas négociable.
class _InertReorderRenderer extends ZReorderRenderer {
  const _InertReorderRenderer();

  @override
  Widget build(BuildContext context, ZReorderRenderRequest request) => Column(
        children: <Widget>[
          for (var i = 0; i < request.itemIds.length; i++)
            Semantics(
              container: true,
              customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
                if (request.moveBeforeSemanticLabel != null && i > 0)
                  CustomSemanticsAction(
                      label: request.moveBeforeSemanticLabel!): () =>
                      request.onReorder(i, i - 1),
                if (request.moveAfterSemanticLabel != null &&
                    i < request.itemIds.length - 1)
                  CustomSemanticsAction(
                      label: request.moveAfterSemanticLabel!): () =>
                      request.onReorder(i, i + 1),
              },
              child: request.itemBuilder(context, i),
            ),
        ],
      );
}

void main() {
  testWidgets(
      '(a) inertie — sans renderer injecté, le glissement part IMMÉDIATEMENT '
      'de la poignée (mouvement engagé avant le seuil d\'appui long)',
      (tester) async {
    List<Map<String, dynamic>>? captured;
    await tester.pumpWidget(_host(ZSubListFieldWidget(
      field: _compactField(),
      initialValue: _seed,
      acl: const ZAllowAllAcl(),
      onChanged: (list) => captured = list,
    )));
    await tester.pump();

    const hold = Duration(milliseconds: 16);
    const step = Duration(milliseconds: 16);
    const steps = 4;
    // Budget du geste AVANT relâchement, strictement sous le seuil d'appui
    // long du SDK : un déclencheur à appui long aurait rejeté ce mouvement.
    // C'est ce qui fait de cette garde une mesure d'IMMÉDIATETÉ et pas un
    // simple « ça réordonne ».
    expect(hold + step * steps, lessThan(kLongPressTimeout));

    final start = tester.getCenter(_handles.at(0));
    final end = tester.getCenter(_handles.at(1)) + const Offset(0, 24);
    final gesture = await tester.startGesture(start);
    await tester.pump(hold);
    final delta = Offset(0, (end.dy - start.dy) / steps);
    for (var i = 0; i < steps; i++) {
      await gesture.moveBy(delta);
      await tester.pump(step);
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(captured, isNotNull,
        reason: 'la poignée du repli interne n\'a rien amorcé');
    expect(_values(captured!), <String>['B', 'A', 'C']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      '(b) renderer qui HONORE le contrat : sa machinerie est atteinte depuis '
      'le contexte de la poignée, et le geste part de la POIGNÉE',
      (tester) async {
    final renderer = _HandleHonoringRenderer();
    List<Map<String, dynamic>>? captured;
    await tester.pumpWidget(_host(ZcrudScope(
      acl: const ZAllowAllAcl(),
      reorderRenderer: renderer,
      child: ZSubListFieldWidget(
        field: _compactField(),
        initialValue: _seed,
        onChanged: (list) => captured = list,
      ),
    )));
    await tester.pump();

    // Le port a bien soumis CHAQUE poignée au renderer, avec son index.
    expect(renderer.handleIndices.toSet(), <int>{0, 1, 2});
    expect(renderer.scopeReachedFromHandleContext, isTrue,
        reason: 'le contexte de la poignée n\'est pas dans le sous-arbre du '
            'renderer — le mécanisme du contrat serait inatteignable');

    // La poignée est rendue INCHANGÉE au travers de l'enveloppe : glyphe,
    // cible tactile ≥ 48 dp et libellé sémantique survivent.
    expect(_handles, findsNWidgets(3));
    final target = _handleTarget(tester, 0);
    expect(target.width, greaterThanOrEqualTo(48));
    expect(target.height, greaterThanOrEqualTo(48));
    expect(_handleSemanticLabel(tester, 0), isNotNull);

    // Un geste amorcé AILLEURS sur la ligne n'est PAS l'ancrage.
    final onRow = await tester.startGesture(tester.getCenter(find.text('A')));
    await tester.pump(const Duration(milliseconds: 16));
    await onRow.moveBy(const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await onRow.up();
    await tester.pumpAndSettle();
    expect(renderer.gestureStartedOnHandleIndex, isNull,
        reason: 'le geste de la ligne ne doit pas passer pour celui de la '
            'poignée');
    expect(captured, isNull);

    // Le même geste, amorcé SUR la poignée, atteint la machinerie du renderer.
    final onHandle = await tester.startGesture(tester.getCenter(_handles.at(1)));
    await tester.pump(const Duration(milliseconds: 16));
    await onHandle.moveBy(const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await onHandle.up();
    await tester.pumpAndSettle();
    expect(renderer.gestureStartedOnHandleIndex, 1);
    expect(captured, isNotNull);
    expect(_values(captured!), <String>['A', 'C', 'B']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      '(c) renderer qui NE L\'HONORE PAS : poignée rendue, voie non gestuelle '
      'intacte, rien ne lève', (tester) async {
    List<Map<String, dynamic>>? captured;
    await tester.pumpWidget(_host(ZcrudScope(
      acl: const ZAllowAllAcl(),
      reorderRenderer: const _InertReorderRenderer(),
      child: ZSubListFieldWidget(
        field: _compactField(),
        initialValue: _seed,
        onChanged: (list) => captured = list,
      ),
    )));
    await tester.pump();

    // La poignée reste une affordance VISIBLE et conforme.
    expect(_handles, findsNWidgets(3));
    final target = _handleTarget(tester, 0);
    expect(target.width, greaterThanOrEqualTo(48));
    expect(target.height, greaterThanOrEqualTo(48));
    expect(_handleSemanticLabel(tester, 0), isNotNull);

    // La voie NON GESTUELLE reste le chemin atteignable (AD-13) : trois lignes
    // portent des actions de déplacement.
    expect(_rowsWithMoveActions(tester), greaterThanOrEqualTo(3));

    // Un geste sur la poignée est honnêtement inerte — et ne lève RIEN.
    final gesture = await tester.startGesture(tester.getCenter(_handles.at(0)));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(0, 60));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(captured, isNull);
    expect(tester.takeException(), isNull);

    // Et le défaut du port est bien l'IDENTITÉ : le sous-arbre soumis est
    // rendu tel quel, à l'instance près.
    const submitted = SizedBox(key: ValueKey<String>('poignée'));
    final returned = const _InertReorderRenderer().buildDragHandle(
      tester.element(_handles.at(0)),
      0,
      submitted,
    );
    expect(identical(returned, submitted), isTrue,
        reason: 'le défaut de `buildDragHandle` n\'est plus l\'identité');
  });

  testWidgets(
      '(d) rendu par défaut inchangé, et le cœur ne présume plus d\'un chassis',
      (tester) async {
    // Sans renderer injecté : la poignée, sa cible et la voie non gestuelle
    // sont exactement ce qu'elles étaient.
    await tester.pumpWidget(_host(ZSubListFieldWidget(
      field: _compactField(),
      initialValue: _seed,
      acl: const ZAllowAllAcl(),
      onChanged: (_) {},
    )));
    await tester.pump();
    expect(_handles, findsNWidgets(3));
    for (var i = 0; i < 3; i++) {
      final target = _handleTarget(tester, i);
      expect(target.width, greaterThanOrEqualTo(48));
      expect(target.height, greaterThanOrEqualTo(48));
      expect(_handleSemanticLabel(tester, i), isNotNull);
    }
    expect(_rowsWithMoveActions(tester), greaterThanOrEqualTo(3));
    expect(find.byType(ReorderableDragStartListener), findsNothing);
    expect(tester.takeException(), isNull);

    // Sous un renderer injecté : le cœur ne pose plus de déclencheur du
    // chassis réordonnable du SDK « au cas où » — il DEMANDE au renderer.
    // Ce déclencheur est un no-op silencieux hors `SliverReorderableList` :
    // le poser à l'aveugle fabriquait une poignée morte.
    await tester.pumpWidget(_host(ZcrudScope(
      acl: const ZAllowAllAcl(),
      reorderRenderer: const _InertReorderRenderer(),
      child: ZSubListFieldWidget(
        field: _compactField(),
        initialValue: _seed,
        onChanged: (_) {},
      ),
    )));
    await tester.pump();
    expect(_handles, findsNWidgets(3));
    expect(find.byType(ReorderableDragStartListener), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
