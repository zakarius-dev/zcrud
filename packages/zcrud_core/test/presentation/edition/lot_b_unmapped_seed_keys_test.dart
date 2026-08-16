// LOT B — **les clés hors schéma de la graine survivent à l'édition.**
//
// Défaut corrigé : `ZSubListFieldWidget._syncToParent` et
// `ZDynamicItemFieldWidget._syncToParent` RECOMPOSAIENT l'item à partir des
// SEULS `itemFields` déclarés. Toute clé portée par la graine mais absente du
// sous-schéma — `id` en premier — était **détruite dès la première frappe**
// dans n'importe quel sous-champ. Ce n'était pas un affichage faux : la donnée
// disparaissait de la valeur réémise vers le parent.
//
// Impact mesuré chez les hôtes (lecture seule) :
// - IFFD `flashcardChoiceItemFields()` déclare `isCorrect`/`content` alors que
//   `QcmChoice.toMap()` porte `id` → l'`id` de chaque proposition de QCM était
//   perdu, et `QcmChoice.fromMap` en **regénérait un aléatoire** (`randomString()`)
//   à la relecture : churn d'identité silencieux ;
// - DODLP `mobilites` déclare `date`/`type` alors que `MobiliteAgent.toMap()`
//   porte 8 clés → **6 clés perdues** (`id`, `agentsIds`, `description`,
//   `canBeDeleted`, `deleted`, `lastCrudOperation`).
//
// Ces gardes couvrent les trois pièges du correctif :
// 1. conservation (la clé hors schéma survit) ;
// 2. **non-résurrection** (un champ déclaré effacé par l'utilisateur reste
//    effacé — le correctif ne doit PAS réémettre la graine entière) ;
// 3. **appariement par IDENTITÉ** (réordonnancement/retrait au milieu : chaque
//    item garde SON résidu, jamais celui d'un voisin).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _itemFields = <ZFieldSpec>[
  ZFieldSpec(name: 'f1', type: EditionFieldType.text, label: 'F1'),
  ZFieldSpec(name: 'f2', type: EditionFieldType.text, label: 'F2'),
];

// `displayMode` DÉCLARÉ : son nom dit le mode qu'il teste, et depuis que
// `compact` est le défaut, ne rien déclarer en rendrait un autre.
const _inlineField = ZFieldSpec(
  name: 'items',
  type: EditionFieldType.subItems,
  label: 'Items',
  config: ZSubListConfig(
    itemFields: _itemFields,
    displayMode: ZSubListDisplayMode.inline,
  ),
);

const _dynField = ZFieldSpec(
  name: 'item',
  type: EditionFieldType.dynamicItem,
  label: 'Item',
  config: ZSubListConfig(itemFields: _itemFields),
);

/// Hôte de test. L'ACL permissive est **DÉCLARÉE** au scope : le socle refuse
/// par défaut, et déclarer l'ouverture totale est le geste qu'une application
/// de développement doit poser.
Widget _host(Widget child) => MaterialApp(
      home: ZcrudScope(
        acl: const ZAllowAllAcl(),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

void main() {
  group('LOT B — sous-liste : conservation des clés hors schéma', () {
    testWidgets('une frappe dans un sous-champ ne détruit PAS `id` ni les '
        'autres clés hors schéma', (tester) async {
      List<Map<String, dynamic>>? captured;
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: _inlineField,
        initialValue: const <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'choice-1',
            'f1': 'Alpha',
            'f2': 'a',
            'agentsIds': <String>['ag-1', 'ag-2'],
            'canBeDeleted': false,
          },
        ],
        onChanged: (list) => captured = list,
      )));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'Alpha!');
      await tester.pump();

      expect(captured, isNotNull);
      expect(captured!.length, 1);
      final item = captured!.single;
      // La frappe est bien prise en compte…
      expect(item['f1'], 'Alpha!');
      // …et les clés hors schéma sont TOUJOURS là.
      expect(item['id'], 'choice-1',
          reason: "l'id de la graine a été détruit par la réémission");
      expect(item['agentsIds'], <String>['ag-1', 'ag-2']);
      expect(item['canBeDeleted'], false);
    });

    testWidgets('NON-RÉSURRECTION : un champ déclaré EFFACÉ par '
        "l'utilisateur reste effacé", (tester) async {
      List<Map<String, dynamic>>? captured;
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: _inlineField,
        initialValue: const <Map<String, dynamic>>[
          <String, dynamic>{'id': 'c1', 'f1': 'Alpha', 'f2': 'a'},
        ],
        onChanged: (list) => captured = list,
      )));
      await tester.pump();

      // L'utilisateur vide le champ `f1`.
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump();

      expect(captured, isNotNull);
      final item = captured!.single;
      expect(item['f1'], isNot('Alpha'),
          reason: 'la graine a ressuscité une valeur volontairement effacée');
      expect(item['f1'], anyOf(isNull, ''));
      // Le résidu hors schéma, lui, est bien conservé.
      expect(item['id'], 'c1');
    });

    testWidgets('APPARIEMENT PAR IDENTITÉ : après un réordonnancement, chaque '
        'item garde SON résidu', (tester) async {
      List<Map<String, dynamic>>? captured;
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: _inlineField,
        initialValue: const <Map<String, dynamic>>[
          <String, dynamic>{'id': 'A', 'f1': 'Alpha', 'f2': 'a'},
          <String, dynamic>{'id': 'B', 'f1': 'Beta', 'f2': 'b'},
          <String, dynamic>{'id': 'C', 'f1': 'Gamma', 'f2': 'c'},
        ],
        onChanged: (list) => captured = list,
      )));
      await tester.pump();

      // Descend le PREMIER item : ordre attendu B, A, C.
      await tester.tap(find.byIcon(Icons.arrow_downward).first);
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.map((m) => m['f1']).toList(), <String>[
        'Beta',
        'Alpha',
        'Gamma',
      ]);
      // 🔴 Le cœur du lot : un appariement par INDEX recollerait `A` sur Beta.
      expect(captured!.map((m) => m['id']).toList(), <String>['B', 'A', 'C'],
          reason: 'le résidu de graine a été recollé sur le mauvais item');
    });

    testWidgets('APPARIEMENT PAR IDENTITÉ : après un retrait AU MILIEU, les '
        'items restants gardent LEUR résidu', (tester) async {
      List<Map<String, dynamic>>? captured;
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: _inlineField,
        initialValue: const <Map<String, dynamic>>[
          <String, dynamic>{'id': 'A', 'f1': 'Alpha'},
          <String, dynamic>{'id': 'B', 'f1': 'Beta'},
          <String, dynamic>{'id': 'C', 'f1': 'Gamma'},
        ],
        onChanged: (list) => captured = list,
      )));
      await tester.pump();

      // Retire l'item du MILIEU (Beta).
      await tester.tap(find.byIcon(Icons.delete_outline).at(1));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.map((m) => m['f1']).toList(), <String>['Alpha', 'Gamma']);
      expect(captured!.map((m) => m['id']).toList(), <String>['A', 'C'],
          reason: 'un appariement par index aurait décalé les résidus');

      // Et une frappe ultérieure ne les décale pas non plus. Deux items restants
      // × deux sous-champs (`f1`, `f2`) ⇒ le `f1` de Gamma est à l'index 2.
      await tester.enterText(find.byType(TextField).at(2), 'Gamma!');
      await tester.pump();
      expect(captured!.map((m) => m['id']).toList(), <String>['A', 'C']);
      expect(captured!.last['f1'], 'Gamma!');
    });

    testWidgets("ITEM AJOUTÉ : pas de graine ⇒ aucun résidu emprunté à un "
        'voisin', (tester) async {
      List<Map<String, dynamic>>? captured;
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: _inlineField,
        initialValue: const <Map<String, dynamic>>[
          <String, dynamic>{'id': 'A', 'f1': 'Alpha', 'secret': 'x'},
        ],
        onChanged: (list) => captured = list,
      )));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.length, 2);
      // L'item d'origine conserve son résidu…
      expect(captured!.first['id'], 'A');
      expect(captured!.first['secret'], 'x');
      // …l'item AJOUTÉ n'en porte aucun (comportement inchangé : seules les
      // clés déclarées).
      expect(captured!.last.keys.toSet(), <String>{'f1', 'f2'});
    });

    testWidgets('DP-19 intact : un item soft-deleted reste EXCLU, résidu '
        'compris', (tester) async {
      List<Map<String, dynamic>>? captured;
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: const ZFieldSpec(
          name: 'items',
          type: EditionFieldType.subItems,
          label: 'Items',
          config: ZSubListConfig(
            itemFields: _itemFields,
            displayMode: ZSubListDisplayMode.compact,
            summaryFields: <String>['f1'],
            softDelete: true,
          ),
        ),
        initialValue: const <Map<String, dynamic>>[
          <String, dynamic>{'id': 'A', 'f1': 'Alpha'},
          <String, dynamic>{'id': 'B', 'f1': 'Beta'},
        ],
        onChanged: (list) => captured = list,
      )));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.length, 1);
      expect(captured!.single['id'], 'B');

      // Restauration → l'item réintègre l'agrégation AVEC son résidu.
      await tester.tap(find.byIcon(Icons.restore_from_trash));
      await tester.pumpAndSettle();
      expect(captured!.map((m) => m['id']).toList(), <String>['A', 'B']);
    });

    testWidgets("mode compact : l'édition par dialog préserve le résidu",
        (tester) async {
      List<Map<String, dynamic>>? captured;
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: const ZFieldSpec(
          name: 'items',
          type: EditionFieldType.subItems,
          label: 'Items',
          config: ZSubListConfig(
            itemFields: _itemFields,
            displayMode: ZSubListDisplayMode.compact,
            summaryFields: <String>['f1'],
          ),
        ),
        initialValue: const <Map<String, dynamic>>[
          <String, dynamic>{'id': 'A', 'f1': 'Alpha', 'f2': 'a'},
        ],
        onChanged: (list) => captured = list,
      )));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Alpha!');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.single['f1'], 'Alpha!');
      expect(captured!.single['id'], 'A');
    });
  });

  group('LOT B — item dynamique : conservation des clés hors schéma', () {
    testWidgets('une frappe ne détruit PAS `id` ni les autres clés hors schéma',
        (tester) async {
      Map<String, dynamic>? captured;
      await tester.pumpWidget(_host(ZDynamicItemFieldWidget(
        field: _dynField,
        initialValue: const <String, dynamic>{
          'id': 'dyn-1',
          'f1': 'Alpha',
          'f2': 'a',
          'lastCrudOperation': <String, dynamic>{'by': 'u1'},
        },
        onChanged: (map) => captured = map,
      )));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'Alpha!');
      await tester.pump();

      expect(captured, isNotNull);
      expect(captured!['f1'], 'Alpha!');
      expect(captured!['id'], 'dyn-1',
          reason: "l'id de la graine a été détruit par la réémission");
      expect(captured!['lastCrudOperation'], <String, dynamic>{'by': 'u1'});
    });

    testWidgets('NON-RÉSURRECTION : un champ déclaré effacé reste effacé',
        (tester) async {
      Map<String, dynamic>? captured;
      await tester.pumpWidget(_host(ZDynamicItemFieldWidget(
        field: _dynField,
        initialValue: const <String, dynamic>{
          'id': 'dyn-1',
          'f1': 'Alpha',
          'f2': 'a',
        },
        onChanged: (map) => captured = map,
      )));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump();

      expect(captured, isNotNull);
      expect(captured!['f1'], isNot('Alpha'),
          reason: 'la graine a ressuscité une valeur volontairement effacée');
      expect(captured!['id'], 'dyn-1');
    });

    testWidgets('EFFACER puis AJOUTER : le résidu de l\'item effacé ne '
        'ressuscite pas sur l\'item neuf', (tester) async {
      Map<String, dynamic>? captured;
      var called = false;
      await tester.pumpWidget(_host(ZDynamicItemFieldWidget(
        field: _dynField,
        initialValue: const <String, dynamic>{
          'id': 'dyn-1',
          'f1': 'Alpha',
          'secret': 'x',
        },
        onChanged: (map) {
          captured = map;
          called = true;
        },
      )));
      await tester.pump();

      // Effacer l'item entier.
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();
      expect(called, isTrue);
      expect(captured, isNull);

      // Puis en ajouter un neuf : aucune clé de l'ancienne graine.
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(captured, isNotNull);
      expect(captured!.keys.toSet(), <String>{'f1', 'f2'},
          reason: "le résidu de l'item effacé a ressuscité sur un item neuf");
    });
  });
}
