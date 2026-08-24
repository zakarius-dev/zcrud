// CR-IFFD-92 ② — l'ORDRE d'une sous-liste compacte.
//
// Couvre :
//  - étalon hôte passif : sans déclaration (`reorderable` non déclaré, donc
//    `null`), le mode compact ne rend AUCUNE flèche d'ordre — rendu inchangé ;
//  - `reorderable: true` explicite en compact : les mêmes flèches qu'en
//    inline, et le tap DÉPLACE réellement la valeur (ordre agrégé persisté) ;
//  - bornes : première ligne « monter » désactivé, dernière « descendre » ;
//  - lecture seule : aucune flèche même déclaré ;
//  - `reorderable: false` explicite : le mode inline perd ses flèches ;
//  - tags + `reorderable: true` : l'option n'est PLUS silencieusement inerte —
//    assertion de debug ;
//  - seam : `ZSubListViewData.onReorder` est servi au `listViewBuilder`
//    (non nul quand l'ordre est éditable, nul en lecture seule), déplace la
//    valeur, et reste défensif hors bornes.
import 'package:flutter/material.dart';
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

void main() {
  group('② étalon hôte passif', () {
    testWidgets('compact sans déclaration → AUCUNE flèche d\'ordre',
        (tester) async {
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: _field(),
        initialValue: _seed,
        acl: const ZAllowAllAcl(),
        onChanged: (_) {},
      )));
      await tester.pump();
      expect(find.byIcon(Icons.arrow_upward), findsNothing);
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('inline sans déclaration → flèches conservées (historique)',
        (tester) async {
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
      expect(find.byIcon(Icons.arrow_upward), findsNWidgets(3));
      expect(find.byIcon(Icons.arrow_downward), findsNWidgets(3));
    });
  });

  group('② reorderable: true en compact', () {
    testWidgets('les flèches sont rendues, et « descendre » DÉPLACE la valeur',
        (tester) async {
      List<Map<String, dynamic>>? captured;
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: _field(reorderable: true),
        initialValue: _seed,
        acl: const ZAllowAllAcl(),
        onChanged: (list) => captured = list,
      )));
      await tester.pump();
      expect(find.byIcon(Icons.arrow_upward), findsNWidgets(3));
      expect(find.byIcon(Icons.arrow_downward), findsNWidgets(3));

      // Descendre la PREMIÈRE ligne : A passe sous B — ordre agrégé persisté.
      await tester.tap(find.byIcon(Icons.arrow_downward).first);
      await tester.pump();
      expect(captured, isNotNull);
      expect(
        <String>[for (final it in captured!) it['f1'] as String],
        <String>['B', 'A', 'C'],
      );
    });

    testWidgets('bornes : première ligne « monter » désactivé, dernière '
        '« descendre » désactivé', (tester) async {
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: _field(reorderable: true),
        initialValue: _seed,
        acl: const ZAllowAllAcl(),
        onChanged: (_) {},
      )));
      await tester.pump();
      IconButton bouton(Finder icone) => tester.widget<IconButton>(
            find.ancestor(of: icone, matching: find.byType(IconButton)).first,
          );
      expect(bouton(find.byIcon(Icons.arrow_upward).first).onPressed, isNull);
      expect(
        tester
            .widget<IconButton>(find
                .ancestor(
                  of: find.byIcon(Icons.arrow_downward).last,
                  matching: find.byType(IconButton),
                )
                .first)
            .onPressed,
        isNull,
      );
    });

    testWidgets('lecture seule → aucune flèche, même déclaré', (tester) async {
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: _field(reorderable: true, readOnly: true),
        initialValue: _seed,
        acl: const ZAllowAllAcl(),
        onChanged: (_) {},
      )));
      await tester.pump();
      expect(find.byIcon(Icons.arrow_upward), findsNothing);
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
    });
  });

  testWidgets('② reorderable: false → le mode inline perd ses flèches',
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
  });
}
