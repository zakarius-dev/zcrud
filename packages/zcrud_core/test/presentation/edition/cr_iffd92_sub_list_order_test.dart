// CR-IFFD-92 ② — l'ORDRE d'une sous-liste compacte, relevé au contrat actuel :
// le contrôle d'ordre est le GLISSER-DÉPOSER à poignée + les actions
// sémantiques de déplacement (port ZReorderRenderer) — plus AUCUNE flèche
// monter/descendre, dans aucun mode.
//
// Couvre :
//  - étalon hôte passif : sans déclaration (`reorderable` non déclaré, donc
//    `null`), le mode compact ne rend AUCUN contrôle d'ordre (ni poignée, ni
//    flèche) — rendu inchangé ;
//  - `reorderable: true` explicite en compact : une poignée par ligne, et
//    l'action sémantique « descendre » DÉPLACE réellement la valeur (ordre
//    agrégé persisté) ;
//  - bornes : la première ligne n'expose pas « monter », la dernière pas
//    « descendre » (actions sémantiques) ;
//  - lecture seule : ni poignée ni action sémantique, même déclaré ;
//  - `reorderable: false` explicite : le mode inline perd son contrôle
//    d'ordre ;
//  - tags + `reorderable: true` : l'option n'est PAS silencieusement inerte —
//    assertion de debug ;
//  - seam : `ZSubListViewData.onReorder` est servi au `listViewBuilder`
//    (non nul quand l'ordre est éditable, nul en lecture seule), déplace la
//    valeur, et reste défensif hors bornes.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _itemFields = <ZFieldSpec>[
  ZFieldSpec(name: 'f1', type: EditionFieldType.text, label: 'F1'),
];

ZFieldSpec _field({bool? reorderable, bool readOnly = false}) => ZFieldSpec(
      name: 'items',
      type: EditionFieldType.subItems,
      label: 'Items',
      readOnly: readOnly,
      config: ZSubListConfig(
        itemFields: _itemFields,
        reorderable: reorderable,
        summaryFields: const <String>['f1'],
      ),
    );

const _seed = <Map<String, dynamic>>[
  <String, dynamic>{'f1': 'A'},
  <String, dynamic>{'f1': 'B'},
  <String, dynamic>{'f1': 'C'},
];

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

/// Nœuds sémantiques portant [action], en ordre de parcours (= ordre des
/// lignes).
List<SemanticsNode> _nodesWithAction(
  WidgetTester tester,
  CustomSemanticsAction action,
) {
  final id = CustomSemanticsAction.getIdentifier(action);
  final result = <SemanticsNode>[];
  void visit(SemanticsNode node) {
    final ids = node.getSemanticsData().customSemanticsActionIds;
    if (ids != null && ids.contains(id)) result.add(node);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  // ignore: deprecated_member_use
  visit(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
  return result;
}

void _performAction(
  WidgetTester tester,
  SemanticsNode node,
  CustomSemanticsAction action,
) {
  // ignore: deprecated_member_use
  tester.binding.pipelineOwner.semanticsOwner!.performAction(
    node.id,
    SemanticsAction.customAction,
    CustomSemanticsAction.getIdentifier(action),
  );
}

// Libellés servis par la requête du socle (l10n 'moveItemUp'/'moveItemDown',
// locale par défaut des tests).
const _moveUp = CustomSemanticsAction(label: 'Move item up');
const _moveDown = CustomSemanticsAction(label: 'Move item down');

void main() {
  group('② étalon hôte passif', () {
    testWidgets('compact sans déclaration → AUCUN contrôle d\'ordre',
        (tester) async {
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: _field(),
        initialValue: _seed,
        acl: const ZAllowAllAcl(),
        onChanged: (_) {},
      )));
      await tester.pump();
      expect(find.byIcon(Icons.drag_indicator_rounded), findsNothing);
      expect(find.byIcon(Icons.arrow_upward), findsNothing);
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'inline sans déclaration → poignées de glissement (historique : '
        'l\'ordre y est éditable par défaut), aucune flèche', (tester) async {
      const field = ZFieldSpec(
        name: 'items',
        type: EditionFieldType.subItems,
        label: 'Items',
        config: ZSubListConfig(
          itemFields: _itemFields,
          displayMode: ZSubListDisplayMode.inline,
        ),
      );
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: field,
        initialValue: _seed,
        onChanged: (_) {},
      )));
      await tester.pump();
      expect(find.byIcon(Icons.drag_indicator_rounded), findsNWidgets(3));
      expect(find.byIcon(Icons.arrow_upward), findsNothing);
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
    });
  });

  group('② reorderable: true en compact', () {
    testWidgets(
        'une poignée par ligne, et l\'action sémantique « descendre » DÉPLACE '
        'la valeur (ordre agrégé persisté)', (tester) async {
      final semantics = tester.ensureSemantics();
      List<Map<String, dynamic>>? captured;
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: _field(reorderable: true),
        initialValue: _seed,
        acl: const ZAllowAllAcl(),
        onChanged: (list) => captured = list,
      )));
      await tester.pump();
      expect(find.byIcon(Icons.drag_indicator_rounded), findsNWidgets(3));
      expect(find.byIcon(Icons.arrow_upward), findsNothing);
      expect(find.byIcon(Icons.arrow_downward), findsNothing);

      // Descendre la PREMIÈRE ligne : A passe sous B — ordre agrégé persisté.
      final rows = _nodesWithAction(tester, _moveDown);
      expect(rows, isNotEmpty);
      _performAction(tester, rows.first, _moveDown);
      await tester.pump();
      expect(captured, isNotNull);
      expect(
        <String>[for (final it in captured!) it['f1'] as String],
        <String>['B', 'A', 'C'],
      );
      semantics.dispose();
    });

    testWidgets(
        'bornes : la première ligne n\'expose pas « monter », la dernière pas '
        '« descendre »', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: _field(reorderable: true),
        initialValue: _seed,
        acl: const ZAllowAllAcl(),
        onChanged: (_) {},
      )));
      await tester.pump();
      // 3 lignes : « monter » n'existe que sur les 2 dernières, « descendre »
      // que sur les 2 premières.
      expect(_nodesWithAction(tester, _moveUp), hasLength(2));
      expect(_nodesWithAction(tester, _moveDown), hasLength(2));
      semantics.dispose();
    });

    testWidgets('lecture seule → ni poignée ni action sémantique, même déclaré',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: _field(reorderable: true, readOnly: true),
        initialValue: _seed,
        acl: const ZAllowAllAcl(),
        onChanged: (_) {},
      )));
      await tester.pump();
      expect(find.byIcon(Icons.drag_indicator_rounded), findsNothing);
      expect(find.byIcon(Icons.arrow_upward), findsNothing);
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
      expect(_nodesWithAction(tester, _moveUp), isEmpty);
      expect(_nodesWithAction(tester, _moveDown), isEmpty);
      semantics.dispose();
    });
  });

  testWidgets(
      '② reorderable: false → le mode inline perd son contrôle d\'ordre',
      (tester) async {
    const field = ZFieldSpec(
      name: 'items',
      type: EditionFieldType.subItems,
      label: 'Items',
      config: ZSubListConfig(
        itemFields: _itemFields,
        reorderable: false,
        displayMode: ZSubListDisplayMode.inline,
      ),
    );
    await tester.pumpWidget(_host(ZSubListFieldWidget(
      field: field,
      initialValue: _seed,
      onChanged: (_) {},
    )));
    await tester.pump();
    expect(find.byIcon(Icons.drag_indicator_rounded), findsNothing);
    expect(find.byIcon(Icons.arrow_upward), findsNothing);
    expect(find.byIcon(Icons.arrow_downward), findsNothing);
  });

  testWidgets(
      '② tags + reorderable: true → BRUYANT (assertion de debug), '
      'jamais silencieusement inerte', (tester) async {
    const field = ZFieldSpec(
      name: 'items',
      type: EditionFieldType.subItems,
      label: 'Items',
      config: ZSubListConfig(
        itemFields: _itemFields,
        reorderable: true,
        displayMode: ZSubListDisplayMode.tags,
      ),
    );
    await tester.pumpWidget(_host(ZSubListFieldWidget(
      field: field,
      initialValue: _seed,
      onChanged: (_) {},
    )));
    expect(tester.takeException(), isA<AssertionError>());
  });

  group('② seam : ZSubListViewData.onReorder', () {
    testWidgets('servi au listViewBuilder, il déplace réellement la valeur',
        (tester) async {
      ZSubListViewData? vue;
      List<Map<String, dynamic>>? captured;
      final seams = ZSubListSeamRegistry()
        ..register(
          'items',
          ZSubListSeams(
            listViewBuilder: (context, view) {
              vue = view;
              return Column(children: view.children);
            },
          ),
        );
      await tester.pumpWidget(_host(ZcrudScope(
        acl: const ZAllowAllAcl(),
        subListSeamRegistry: seams,
        child: ZSubListFieldWidget(
          field: _field(),
          initialValue: _seed,
          onChanged: (list) => captured = list,
        ),
      )));
      await tester.pump();
      expect(vue, isNotNull);
      expect(vue!.onReorder, isNotNull);

      vue!.onReorder!(0, 2);
      await tester.pump();
      expect(
        <String>[for (final it in captured!) it['f1'] as String],
        <String>['B', 'C', 'A'],
      );

      // Défensif (AD-10) : hors bornes = no-op, jamais une exception.
      vue!.onReorder!(-1, 99);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        <String>[for (final it in captured!) it['f1'] as String],
        <String>['B', 'C', 'A'],
      );
    });

    testWidgets('nul en lecture seule et sur reorderable: false',
        (tester) async {
      ZSubListViewData? vue;
      final seams = ZSubListSeamRegistry()
        ..register(
          'items',
          ZSubListSeams(
            listViewBuilder: (context, view) {
              vue = view;
              return Column(children: view.children);
            },
          ),
        );
      await tester.pumpWidget(_host(ZcrudScope(
        acl: const ZAllowAllAcl(),
        subListSeamRegistry: seams,
        child: ZSubListFieldWidget(
          field: _field(readOnly: true),
          initialValue: _seed,
          onChanged: (_) {},
        ),
      )));
      await tester.pump();
      expect(vue, isNotNull);
      expect(vue!.onReorder, isNull);

      vue = null;
      await tester.pumpWidget(_host(ZcrudScope(
        acl: const ZAllowAllAcl(),
        subListSeamRegistry: seams,
        child: ZSubListFieldWidget(
          field: _field(reorderable: false),
          initialValue: _seed,
          onChanged: (_) {},
        ),
      )));
      await tester.pump();
      expect(vue, isNotNull);
      expect(vue!.onReorder, isNull);
    });

    testWidgets(
        'les lignes servies à un conteneur hôte n\'emportent PAS de poignée '
        '(le conteneur rend son propre contrôle d\'ordre)', (tester) async {
      final seams = ZSubListSeamRegistry()
        ..register(
          'items',
          ZSubListSeams(
            listViewBuilder: (context, view) =>
                Column(children: view.children),
          ),
        );
      await tester.pumpWidget(_host(ZcrudScope(
        acl: const ZAllowAllAcl(),
        subListSeamRegistry: seams,
        child: ZSubListFieldWidget(
          field: _field(reorderable: true),
          initialValue: _seed,
          onChanged: (_) {},
        ),
      )));
      await tester.pump();
      expect(find.byIcon(Icons.drag_indicator_rounded), findsNothing);
    });
  });
}
