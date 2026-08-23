// Emboîtement d'un `subItems` dans les `itemFields` d'un `subItems` : une
// sous-liste dans l'item d'une sous-liste (niveau 2), et par construction un
// niveau 3. Couvre : persistance `List<Map>` imbriquée, scope re-posé dans la
// route du formulaire d'item, lecture seule propagée, compte rendu par
// `summaryFields`, AD-2 (éditer au niveau 2 ne reconstruit ni le formulaire
// de niveau 1 ni la racine), AD-10 (sous-liste absente/corrompue ⇒ vide).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _modelRefFields = <ZFieldSpec>[
  ZFieldSpec(name: 'provider_id', type: EditionFieldType.text, label: 'Provider'),
  ZFieldSpec(name: 'model_id', type: EditionFieldType.text, label: 'Model'),
];

const _fallbacksField = ZFieldSpec(
  name: 'fallbacks',
  type: EditionFieldType.subItems,
  label: 'Fallbacks',
  config: ZSubListConfig(
    itemFields: _modelRefFields,
    summaryFields: <String>['provider_id'],
  ),
);

const _routeFields = <ZFieldSpec>[
  ZFieldSpec(name: 'name', type: EditionFieldType.text, label: 'Name'),
  _fallbacksField,
];

const _routesField = ZFieldSpec(
  name: 'routes',
  type: EditionFieldType.subItems,
  label: 'Routes',
  config: ZSubListConfig(
    itemFields: _routeFields,
    summaryFields: <String>['name', 'fallbacks'],
  ),
);

/// Niveau 3 : `groups` → `routes` → `fallbacks`.
const _groupsField = ZFieldSpec(
  name: 'groups',
  type: EditionFieldType.subItems,
  label: 'Groups',
  config: ZSubListConfig(
    itemFields: <ZFieldSpec>[
      ZFieldSpec(name: 'title', type: EditionFieldType.text, label: 'Title'),
      _routesField,
    ],
    summaryFields: <String>['title'],
  ),
);

/// Scope posé AU-DESSUS du `MaterialApp` : les routes de dialogue en héritent
/// directement.
Widget _hostScopeAbove(Widget child) => ZcrudScope(
      acl: const ZAllowAllAcl(),
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

/// Scope posé SOUS `home` — le cas courant des hôtes : une route de dialogue
/// ne l'hérite PAS par l'arbre.
Widget _hostScopeUnderHome(Widget child) => MaterialApp(
      home: ZcrudScope(
        acl: const ZAllowAllAcl(),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

Finder _inDialog(Finder f) =>
    find.descendant(of: find.byType(AlertDialog), matching: f);

/// Dans le dialogue le plus récemment ouvert (le dernier de la pile).
Finder _inLastDialog(Finder f) =>
    find.descendant(of: find.byType(AlertDialog).last, matching: f);

/// Ouvre l'édition de l'unique item de niveau 1, ajoute un item de niveau 2
/// (`provider_id`/`model_id`), enregistre le niveau 2 puis le niveau 1.
Future<void> _addFallbackThroughDialogs(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Edit item'));
  await tester.pumpAndSettle();
  expect(find.byType(AlertDialog), findsOneWidget);
  expect(_inDialog(find.byType(ZSubListFieldWidget)), findsOneWidget);
  expect(_inDialog(find.byIcon(Icons.add)), findsOneWidget);

  await tester.tap(_inDialog(find.byIcon(Icons.add)));
  await tester.pumpAndSettle();
  expect(find.byType(AlertDialog), findsNWidgets(2));
  await tester.enterText(
      _inLastDialog(find.byType(EditableText)).at(0), 'openai');
  await tester.enterText(_inLastDialog(find.byType(EditableText)).at(1), 'gpt');
  await tester.pump();
  await tester.tap(_inLastDialog(find.text('Save')));
  await tester.pumpAndSettle();
  expect(find.byType(AlertDialog), findsOneWidget);
  expect(_inDialog(find.text('openai')), findsOneWidget);

  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
  expect(find.byType(AlertDialog), findsNothing);
}

void main() {
  group('niveau 2 : sous-liste dans un item de sous-liste', () {
    testWidgets(
        'ajouter un item de niveau 2 et enregistrer → List<Map> imbriquée dans '
        'la tranche racine (scope au-dessus du Navigator)', (tester) async {
      final controller = ZFormController(initialValues: <String, Object?>{
        'routes': <Map<String, dynamic>>[
          <String, dynamic>{'name': 'r1', 'fallbacks': <Map<String, dynamic>>[]},
        ],
      });
      addTearDown(controller.dispose);
      await tester.pumpWidget(_hostScopeAbove(DynamicEdition(
        controller: controller,
        fields: const <ZFieldSpec>[_routesField],
        shrinkWrap: true,
      )));
      await tester.pump();

      await _addFallbackThroughDialogs(tester);

      expect(controller.valueOf('routes'), <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'r1',
          'fallbacks': <Map<String, dynamic>>[
            <String, dynamic>{'provider_id': 'openai', 'model_id': 'gpt'},
          ],
        },
      ]);
      // Le résumé de niveau 1 rend le COMPTE de la sous-sous-liste.
      expect(find.text('1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'scope posé SOUS home : le formulaire d\'item re-pose le ZcrudScope → '
        'le niveau 2 garde ses actions (ACL) et la valeur est enregistrée',
        (tester) async {
      final controller = ZFormController(initialValues: <String, Object?>{
        'routes': <Map<String, dynamic>>[
          <String, dynamic>{'name': 'r1'},
        ],
      });
      addTearDown(controller.dispose);
      await tester.pumpWidget(_hostScopeUnderHome(DynamicEdition(
        controller: controller,
        fields: const <ZFieldSpec>[_routesField],
        shrinkWrap: true,
      )));
      await tester.pump();

      await _addFallbackThroughDialogs(tester);

      final routes = controller.valueOf('routes')! as List;
      expect((routes.single as Map)['fallbacks'], <Map<String, dynamic>>[
        <String, dynamic>{'provider_id': 'openai', 'model_id': 'gpt'},
      ]);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'AD-10 : sous-liste absente ou corrompue dans la map de l\'item ⇒ '
        'liste vide, aucune exception ; une mutation de niveau 2 la remplace',
        (tester) async {
      final controller = ZFormController(initialValues: <String, Object?>{
        'routes': <Map<String, dynamic>>[
          <String, dynamic>{'name': 'absent'},
          <String, dynamic>{'name': 'corrompu', 'fallbacks': 'oops'},
          <String, dynamic>{
            'name': 'mixte',
            'fallbacks': <Object?>[
              42,
              <String, dynamic>{'provider_id': 'ok', 'model_id': 'm'},
            ],
          },
        ],
      });
      addTearDown(controller.dispose);
      await tester.pumpWidget(_hostScopeAbove(DynamicEdition(
        controller: controller,
        fields: const <ZFieldSpec>[_routesField],
        shrinkWrap: true,
      )));
      await tester.pump();
      expect(tester.takeException(), isNull);
      // Le résumé ne sérialise jamais la valeur corrompue en texte.
      expect(find.text('oops'), findsNothing);

      await tester.tap(find.byTooltip('Edit item').at(1));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_inDialog(find.byType(ZSubListFieldWidget)), findsOneWidget);
      expect(_inDialog(find.byIcon(Icons.add)), findsOneWidget);
      expect(_inDialog(find.byTooltip('Edit item')), findsNothing);
      // Une mutation de niveau 2 remplace la valeur corrompue par une liste.
      await tester.tap(_inDialog(find.byIcon(Icons.add)));
      await tester.pumpAndSettle();
      await tester.enterText(
          _inLastDialog(find.byType(EditableText)).at(0), 'openai');
      await tester.pump();
      await tester.tap(_inLastDialog(find.text('Save')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final routes = controller.valueOf('routes')! as List<Object?>;
      expect((routes[1]! as Map<String, dynamic>)['fallbacks'], <Object?>[
        <String, dynamic>{'provider_id': 'openai', 'model_id': null},
      ]);
      // L'item « mixte » garde son seul élément valide, l'entrée 42 est
      // ignorée — sans exception.
      await tester.tap(find.byTooltip('Edit item').at(2));
      await tester.pumpAndSettle();
      expect(_inDialog(find.text('ok')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'lecture seule propagée : consulter un item de niveau 1 rend le '
        'niveau 2 sans ajout ni modification, et son item sans Enregistrer',
        (tester) async {
      final controller = ZFormController(initialValues: <String, Object?>{
        'routes': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'r1',
            'fallbacks': <Map<String, dynamic>>[
              <String, dynamic>{'provider_id': 'openai', 'model_id': 'gpt'},
            ],
          },
        ],
      });
      addTearDown(controller.dispose);
      await tester.pumpWidget(_hostScopeAbove(DynamicEdition(
        controller: controller,
        fields: const <ZFieldSpec>[_routesField],
        readOnly: true,
        shrinkWrap: true,
      )));
      await tester.pump();
      expect(find.byTooltip('Edit item'), findsNothing);

      await tester.tap(find.byTooltip('View item'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(_inDialog(find.byType(ZSubListFieldWidget)), findsOneWidget);
      expect(_inDialog(find.text('openai')), findsOneWidget);
      expect(_inDialog(find.byIcon(Icons.add)), findsNothing);
      expect(_inDialog(find.byTooltip('Edit item')), findsNothing);
      expect(_inDialog(find.byTooltip('Delete item')), findsNothing);
      expect(_inDialog(find.text('Save')), findsNothing);

      await tester.tap(_inDialog(find.byTooltip('View item')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNWidgets(2));
      expect(_inLastDialog(find.text('Save')), findsNothing);
      expect(_inLastDialog(find.byType(TextFormField)), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'AD-2 : éditer un item de niveau 2 ne reconstruit ni les champs du '
        'formulaire de niveau 1 ni la racine', (tester) async {
      var rootBuilds = 0;
      var level1FieldBuilds = 0;
      final controller = ZFormController(initialValues: <String, Object?>{
        'routes': <Map<String, dynamic>>[
          <String, dynamic>{'name': 'r1', 'fallbacks': <Map<String, dynamic>>[]},
        ],
      });
      addTearDown(controller.dispose);
      await tester.pumpWidget(_hostScopeAbove(DynamicEdition(
        controller: controller,
        fields: const <ZFieldSpec>[_routesField],
        shrinkWrap: true,
        onStructuralBuild: () => rootBuilds++,
        fieldBuilder: (context, ctrl, field) => ZSubListFieldWidget(
          field: field,
          initialValue: ctrl.valueOf(field.name),
          parentController: ctrl,
          onChanged: (list) => ctrl.setValue(field.name, list),
          itemFieldBuilder: (context, itemCtrl, spec, itemId) {
            level1FieldBuilds++;
            return ZFieldWidget(controller: itemCtrl, field: spec);
          },
        ),
      )));
      await tester.pump();
      final rootBefore = rootBuilds;

      await tester.tap(find.byTooltip('Edit item'));
      await tester.pumpAndSettle();
      final level1Before = level1FieldBuilds;
      expect(level1Before, greaterThan(0));

      await tester.tap(_inDialog(find.byIcon(Icons.add)));
      await tester.pumpAndSettle();
      for (final c in 'openai'.split('')) {
        await tester.enterText(
            _inLastDialog(find.byType(EditableText)).at(0), c);
        await tester.pump();
      }
      await tester.tap(_inLastDialog(find.text('Save')));
      await tester.pumpAndSettle();

      expect(level1FieldBuilds, level1Before,
          reason: 'les champs du formulaire de niveau 1 ne se reconstruisent '
              'pas pendant l\'édition du niveau 2');
      expect(rootBuilds, rootBefore,
          reason: 'la racine ne se reconstruit pas');
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
      'niveau 3 : groups → routes → fallbacks, ajout à chaque niveau, valeur '
      'imbriquée sur trois niveaux', (tester) async {
    final controller = ZFormController(initialValues: <String, Object?>{
      'groups': <Map<String, dynamic>>[
        <String, dynamic>{'title': 'g1', 'routes': <Map<String, dynamic>>[]},
      ],
    });
    addTearDown(controller.dispose);
    await tester.pumpWidget(_hostScopeUnderHome(DynamicEdition(
      controller: controller,
      fields: const <ZFieldSpec>[_groupsField],
      shrinkWrap: true,
    )));
    await tester.pump();

    // Niveau 1 : édite g1.
    await tester.tap(find.byTooltip('Edit item'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    // Niveau 2 : ajoute une route.
    await tester.tap(_inLastDialog(find.byIcon(Icons.add)));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNWidgets(2));
    await tester.enterText(_inLastDialog(find.byType(EditableText)).at(0), 'r1');
    await tester.pump();
    // Niveau 3 : ajoute un repli dans la route.
    await tester.tap(_inLastDialog(find.byIcon(Icons.add)));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNWidgets(3));
    await tester.enterText(
        _inLastDialog(find.byType(EditableText)).at(0), 'openai');
    await tester.enterText(_inLastDialog(find.byType(EditableText)).at(1), 'gpt');
    await tester.pump();
    await tester.tap(_inLastDialog(find.text('Save')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNWidgets(2));
    await tester.tap(_inLastDialog(find.text('Save')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    expect(controller.valueOf('groups'), <Map<String, dynamic>>[
      <String, dynamic>{
        'title': 'g1',
        'routes': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'r1',
            'fallbacks': <Map<String, dynamic>>[
              <String, dynamic>{'provider_id': 'openai', 'model_id': 'gpt'},
            ],
          },
        ],
      },
    ]);
    expect(tester.takeException(), isNull);
  });
}
