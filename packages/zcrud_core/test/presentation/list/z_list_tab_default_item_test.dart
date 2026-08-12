// CR-LIST (onglets segmentés) : le contexte de création par onglet
// (`ZListTab.defaultItemBuilder`) est PORTÉ par le modèle et ATTEIGNABLE depuis
// le geste de création de l'app — motif « liste segmentée par statut, la
// création hérite du segment courant ».
//
// Gardes :
// 1. le constructeur et la fabrique `.category` transportent le builder tel
//    quel (aucune perte, aucun défaut fabriqué) ;
// 2. câblage réel avec `ZTabbedList` : après un changement d'onglet, le geste
//    de création (simulé) obtient le contexte de l'onglet ACTIF — chaque appel
//    produit une instance fraîche.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  test('ZListTab transporte defaultItemBuilder (défaut null, additive)', () {
    // Sans builder : null (non-régression stricte pour l'existant).
    const bare = ZListTab(labelKey: 'a', builder: _emptyBuilder);
    expect(bare.defaultItemBuilder, isNull);

    // Avec builder : restitué tel quel, valeur produite intacte.
    final tab = ZListTab(
      labelKey: 'b',
      builder: _emptyBuilder,
      defaultItemBuilder: () => {'type': 'importation'},
    );
    expect(tab.defaultItemBuilder, isNotNull);
    expect(tab.defaultItemBuilder!(), equals({'type': 'importation'}));
  });

  test('ZListTab.category transporte defaultItemBuilder', () {
    final tab = ZListTab.category(
      labelKey: 'enCours',
      filters: const [ZFilter('status', ZFilterOp.eq, 'open')],
      buildList: (context, filters) => const SizedBox(),
      defaultItemBuilder: () => {'status': 'open'},
    );
    expect(tab.defaultItemBuilder, isNotNull);
    expect(tab.defaultItemBuilder!(), equals({'status': 'open'}));

    // Chaque appel produit une instance FRAÎCHE (fabrique, pas valeur figée).
    expect(
      identical(tab.defaultItemBuilder!(), tab.defaultItemBuilder!()),
      isFalse,
    );
  });

  testWidgets(
      'câblage ZTabbedList : le geste de création lit le contexte de '
      "l'onglet ACTIF (héritage du segment courant)", (tester) async {
    final tabs = <ZListTab>[
      ZListTab(
        labelKey: 'tabA',
        builder: (_) => const Text('vueA'),
        defaultItemBuilder: () => 'seedA',
      ),
      ZListTab(
        labelKey: 'tabB',
        builder: (_) => const Text('vueB'),
        defaultItemBuilder: () => 'seedB',
      ),
    ];
    var activeTab = tabs[0];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ZTabbedList(
            tabs: tabs,
            onTabChanged: (index) => activeTab = tabs[index],
          ),
        ),
      ),
    );

    // Onglet initial : la création hérite du segment A.
    expect(activeTab.defaultItemBuilder?.call(), 'seedA');

    // Changement d'onglet → le MÊME geste de création hérite du segment B.
    await tester.tap(find.text('tabB'));
    await tester.pumpAndSettle();
    expect(activeTab.defaultItemBuilder?.call(), 'seedB');
  });
}

Widget _emptyBuilder(BuildContext context) => const SizedBox();
