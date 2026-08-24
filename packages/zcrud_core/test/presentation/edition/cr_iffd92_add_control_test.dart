// CR-IFFD-92 ⑤ — habillage déclaré du contrôle d'AJOUT d'une sous-liste
// (jetons `subListAddControl*` de `ZcrudTheme`).
//
// Couvre :
//  - étalon hôte passif : aucun jeton ⇒ aucun conteneur ajouté, icône nue ;
//  - jetons déclarés : dégradé, rayon, taille, couleur d'icône appliqués —
//    et le geste d'ajout (dialog) reste intact ;
//  - fond uni : appliqué quand aucun dégradé ne prime.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _itemFields = <ZFieldSpec>[
  ZFieldSpec(name: 'f1', type: EditionFieldType.text, label: 'F1'),
];

const _field = ZFieldSpec(
  name: 'items',
  type: EditionFieldType.subItems,
  label: 'Items',
  config: ZSubListConfig(
    itemFields: _itemFields,
    summaryFields: <String>['f1'],
  ),
);

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

Finder _conteneurDecore() => find.byWidgetPredicate((w) =>
    w is Container &&
    w.decoration is BoxDecoration &&
    ((w.decoration as BoxDecoration).gradient != null ||
        (w.decoration as BoxDecoration).color != null ||
        (w.decoration as BoxDecoration).borderRadius != null));

void main() {
  testWidgets('⑤ étalon hôte passif : bouton nu, aucun conteneur ajouté',
      (tester) async {
    await tester.pumpWidget(_host(ZSubListFieldWidget(
      field: _field,
      initialValue: null,
      acl: const ZAllowAllAcl(),
      onChanged: (_) {},
    )));
    await tester.pump();
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(tester.widget<Icon>(find.byIcon(Icons.add)).color, isNull);
    expect(
      find.ancestor(
        of: find.byIcon(Icons.add),
        matching: _conteneurDecore(),
      ),
      findsNothing,
    );
    // Plus strict : AUCUN `Container` n'enveloppe le bouton nu — pas même un
    // conteneur sans décoration (l'arbre d'un hôte passif est celui d'avant).
    expect(
      find.ancestor(
        of: find.byIcon(Icons.add),
        matching: find.byType(Container),
      ),
      findsNothing,
    );
  });

  testWidgets('⑤ jetons : dégradé + rayon + taille + couleur d\'icône, geste '
      'd\'ajout intact', (tester) async {
    const gradient = LinearGradient(colors: <Color>[Colors.red, Colors.blue]);
    await tester.pumpWidget(_host(ZcrudScope(
      acl: const ZAllowAllAcl(),
      theme: const ZcrudTheme(
        subListAddControlGradient: gradient,
        subListAddControlRadius: Radius.circular(16),
        subListAddControlSize: 56,
        subListAddControlIconColor: Colors.white,
      ),
      child: ZSubListFieldWidget(
        field: _field,
        initialValue: null,
        onChanged: (_) {},
      ),
    )));
    await tester.pump();

    final conteneur = tester.widget<Container>(
      find
          .ancestor(of: find.byIcon(Icons.add), matching: _conteneurDecore())
          .first,
    );
    final deco = conteneur.decoration! as BoxDecoration;
    expect(deco.gradient, gradient);
    expect(
      deco.borderRadius,
      const BorderRadius.all(Radius.circular(16)),
    );
    expect(conteneur.constraints?.maxWidth, 56);
    expect(tester.widget<Icon>(find.byIcon(Icons.add)).color, Colors.white);

    // Le geste d'ajout reste la machinerie native : le dialog s'ouvre.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('⑤ fond uni appliqué quand aucun dégradé ne prime',
      (tester) async {
    await tester.pumpWidget(_host(ZcrudScope(
      acl: const ZAllowAllAcl(),
      theme: const ZcrudTheme(subListAddControlColor: Colors.orange),
      child: ZSubListFieldWidget(
        field: _field,
        initialValue: null,
        onChanged: (_) {},
      ),
    )));
    await tester.pump();
    final conteneur = tester.widget<Container>(
      find
          .ancestor(of: find.byIcon(Icons.add), matching: _conteneurDecore())
          .first,
    );
    expect((conteneur.decoration! as BoxDecoration).color, Colors.orange);
  });
}
