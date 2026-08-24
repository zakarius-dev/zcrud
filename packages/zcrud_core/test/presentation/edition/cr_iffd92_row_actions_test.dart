// CR-IFFD-92 ④ — actions de ligne d'une sous-liste compacte : préférence
// d'affichage (indépendante de l'ACL) et habillage par jetons de thème.
//
// Couvre :
//  - étalon hôte passif : trois actions rendues avec les défauts (aucune
//    couleur matérialisée, taille native) ;
//  - préférence : `showViewAction: false` retire l'œil SANS mentir à l'ACL ;
//  - adversariale : montré = permis ET préféré — une préférence `true` ne
//    peut pas MONTRER une action que l'ACL refuse ;
//  - jetons : couleurs et taille des actions pilotées par `ZcrudTheme`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// ACL qui refuse UNIQUEMENT `update` — tout le reste est permis.
class _NoUpdateAcl implements ZAcl {
  const _NoUpdateAcl();
  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) =>
      action != ZCrudAction.update;
}

const _itemFields = <ZFieldSpec>[
  ZFieldSpec(name: 'f1', type: EditionFieldType.text, label: 'F1'),
];

ZFieldSpec _field({
  bool showView = true,
  bool showEdit = true,
  bool showDelete = true,
}) =>
    ZFieldSpec(
      name: 'items',
      type: EditionFieldType.subItems,
      label: 'Items',
      config: ZSubListConfig(
        itemFields: _itemFields,
        summaryFields: const <String>['f1'],
        showViewAction: showView,
        showEditAction: showEdit,
        showDeleteAction: showDelete,
      ),
    );

const _seed = <Map<String, dynamic>>[
  <String, dynamic>{'f1': 'A'},
];

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets('④ étalon hôte passif : trois actions, défauts intacts',
      (tester) async {
    await tester.pumpWidget(_host(ZSubListFieldWidget(
      field: _field(),
      initialValue: _seed,
      acl: const ZAllowAllAcl(),
      onChanged: (_) {},
    )));
    await tester.pump();
    expect(find.byIcon(Icons.visibility), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    // Aucun jeton déclaré ⇒ aucune couleur ni taille matérialisée.
    expect(
      tester.widget<Icon>(find.byIcon(Icons.visibility)).color,
      isNull,
    );
    final bouton = tester.widget<IconButton>(
      find
          .ancestor(
            of: find.byIcon(Icons.visibility),
            matching: find.byType(IconButton),
          )
          .first,
    );
    expect(bouton.iconSize, isNull);
  });

  testWidgets(
      '④ préférence : showViewAction: false retire l\'œil, les autres restent',
      (tester) async {
    await tester.pumpWidget(_host(ZSubListFieldWidget(
      field: _field(showView: false),
      initialValue: _seed,
      acl: const ZAllowAllAcl(),
      onChanged: (_) {},
    )));
    await tester.pump();
    expect(find.byIcon(Icons.visibility), findsNothing);
    expect(find.byIcon(Icons.edit), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets(
      '④ ADVERSARIALE : une préférence ne peut pas MONTRER ce que l\'ACL '
      'refuse (montré = permis ET préféré)', (tester) async {
    await tester.pumpWidget(_host(ZSubListFieldWidget(
      // `showEditAction: true` EXPLICITE — la préférence « veut » l'action.
      field: _field(showEdit: true),
      initialValue: _seed,
      acl: const _NoUpdateAcl(),
      onChanged: (_) {},
    )));
    await tester.pump();
    // L'ACL refuse update : l'action n'est PAS rendue, quoi que dise la
    // préférence.
    expect(find.byIcon(Icons.edit), findsNothing);
    // Les actions permises ET préférées restent rendues.
    expect(find.byIcon(Icons.visibility), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('④ jetons de thème : couleurs par action + taille d\'icône',
      (tester) async {
    await tester.pumpWidget(_host(ZcrudScope(
      acl: const ZAllowAllAcl(),
      theme: const ZcrudTheme(
        subListActionIconSize: 30,
        subListViewActionColor: Colors.teal,
        subListEditActionColor: Colors.blue,
        subListDeleteActionColor: Colors.red,
      ),
      child: ZSubListFieldWidget(
        field: _field(),
        initialValue: _seed,
        onChanged: (_) {},
      ),
    )));
    await tester.pump();
    expect(
      tester.widget<Icon>(find.byIcon(Icons.visibility)).color,
      Colors.teal,
    );
    expect(tester.widget<Icon>(find.byIcon(Icons.edit)).color, Colors.blue);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.delete_outline)).color,
      Colors.red,
    );
    final bouton = tester.widget<IconButton>(
      find
          .ancestor(
            of: find.byIcon(Icons.edit),
            matching: find.byType(IconButton),
          )
          .first,
    );
    expect(bouton.iconSize, 30);
  });
}
