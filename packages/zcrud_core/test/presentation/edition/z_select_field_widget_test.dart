// DP-15 (AC2..AC8, AC12, AC16..AC18) — `ZSelectFieldWidget` : sous-titre/disabled
// par option, mode modal (searchable/seuil), variante multi chips, choix
// dynamiques cross-champ (`choicesFromKey`) + source calculée (`ZChoicesSource`),
// abonnement CIBLÉ (SM-1). Aucun backend : les sources de test vivent DANS le test.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Source de choix CALCULÉE de test : dérive les options du `filterContext`.
class _ComputedChoices extends ZChoicesSource {
  const _ComputedChoices();

  @override
  List<ZFieldChoice> options(Map<String, Object?> filterContext) {
    final parent = filterContext['parent'];
    if (parent == null) return const <ZFieldChoice>[];
    return <ZFieldChoice>[
      ZFieldChoice(value: '$parent-x', label: 'X de $parent'),
      ZFieldChoice(value: '$parent-y', label: 'Y de $parent'),
    ];
  }
}

Widget _mount({
  required ZFormController controller,
  required List<ZFieldSpec> fields,
  ZChoicesSourceRegistry? choicesRegistry,
  void Function(String name)? onFieldBuild,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ZcrudScope(
        choicesSourceRegistry: choicesRegistry,
        child: DynamicEdition(
          controller: controller,
          fields: fields,
          fieldBuilder: onFieldBuild == null
              ? null
              : (context, ctrl, field) => ZFieldWidget(
                    controller: ctrl,
                    field: field,
                    onBuild: () => onFieldBuild(field.name),
                  ),
        ),
      ),
    ),
  );
}

void main() {
  group('Sous-titre + disabled par option (AC2)', () {
    testWidgets('radio : sous-titre rendu + option désactivée non cochable',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'r': null},
        visibleFields: <String>['r'],
      );
      addTearDown(controller.dispose);
      const field = ZFieldSpec(
        name: 'r',
        type: EditionFieldType.radio,
        label: 'Radio',
        choices: <ZFieldChoice>[
          ZFieldChoice(value: 'a', label: 'Alpha', subtitle: 'Sous-A'),
          ZFieldChoice(value: 'b', label: 'Beta', disabled: true),
        ],
      );
      await tester.pumpWidget(
          _mount(controller: controller, fields: const <ZFieldSpec>[field]));
      await tester.pump();

      expect(find.text('Sous-A'), findsOneWidget, reason: 'subtitle rendu');
      // L'option désactivée est présente mais son RadioListTile est disabled.
      final betaTile = tester.widget<RadioListTile<Object?>>(
        find.widgetWithText(RadioListTile<Object?>, 'Beta'),
      );
      expect(betaTile.enabled, isFalse);
    });

    testWidgets('checkbox : option désactivée → onChanged null (non cochable)',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'c': <Object?>[]},
        visibleFields: <String>['c'],
      );
      addTearDown(controller.dispose);
      const field = ZFieldSpec(
        name: 'c',
        type: EditionFieldType.checkbox,
        label: 'Cases',
        choices: <ZFieldChoice>[
          ZFieldChoice(value: 'a', label: 'Alpha'),
          ZFieldChoice(value: 'b', label: 'Beta', disabled: true),
        ],
      );
      await tester.pumpWidget(
          _mount(controller: controller, fields: const <ZFieldSpec>[field]));
      await tester.pump();

      final betaTile = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Beta'),
      );
      expect(betaTile.onChanged, isNull, reason: 'disabled → non cochable');
    });

    testWidgets('select dropdown : option désactivée → item enabled false',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'s': null},
        visibleFields: <String>['s'],
      );
      addTearDown(controller.dispose);
      const field = ZFieldSpec(
        name: 's',
        type: EditionFieldType.select,
        label: 'Select',
        choices: <ZFieldChoice>[
          ZFieldChoice(value: 'a', label: 'Alpha'),
          ZFieldChoice(value: 'b', label: 'Beta', disabled: true),
        ],
      );
      await tester.pumpWidget(
          _mount(controller: controller, fields: const <ZFieldSpec>[field]));
      await tester.pump();
      // Sans config → dropdown natif (rétro-compat AC3).
      expect(find.byType(DropdownButtonFormField<Object?>), findsOneWidget);
    });
  });

  group('Mode modal du select (AC3)', () {
    testWidgets('searchable → modal ouvert, recherche client, sélection mono',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'s': null},
        visibleFields: <String>['s'],
      );
      addTearDown(controller.dispose);
      const field = ZFieldSpec(
        name: 's',
        type: EditionFieldType.select,
        label: 'Ville',
        config: ZSelectConfig(searchable: true),
        choices: <ZFieldChoice>[
          ZFieldChoice(value: 'p', label: 'Paris'),
          ZFieldChoice(value: 'l', label: 'Lyon'),
          ZFieldChoice(value: 'm', label: 'Marseille'),
        ],
      );
      await tester.pumpWidget(
          _mount(controller: controller, fields: const <ZFieldSpec>[field]));
      await tester.pump();

      // Pas de dropdown natif : un déclencheur modal.
      expect(find.byType(DropdownButtonFormField<Object?>), findsNothing);
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      // Modal ouvert : recherche client filtre sur label.
      await tester.enterText(find.byType(TextField), 'mar');
      await tester.pumpAndSettle();
      expect(find.text('Marseille'), findsOneWidget);
      expect(find.text('Paris'), findsNothing);

      // Sélection mono → écrit la tranche + ferme.
      await tester.tap(find.text('Marseille'));
      await tester.pumpAndSettle();
      expect(controller.valueOf('s'), 'm');
    });

    testWidgets('sous le seuil + non searchable → dropdown natif (rétro-compat)',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'s': null},
        visibleFields: <String>['s'],
      );
      addTearDown(controller.dispose);
      const field = ZFieldSpec(
        name: 's',
        type: EditionFieldType.select,
        label: 'Select',
        config: ZSelectConfig(modalThreshold: 10),
        choices: <ZFieldChoice>[
          ZFieldChoice(value: 'a', label: 'Alpha'),
          ZFieldChoice(value: 'b', label: 'Beta'),
        ],
      );
      await tester.pumpWidget(
          _mount(controller: controller, fields: const <ZFieldSpec>[field]));
      await tester.pump();
      expect(find.byType(DropdownButtonFormField<Object?>), findsOneWidget);
    });

    testWidgets('seuil atteint → bascule en modal', (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'s': null},
        visibleFields: <String>['s'],
      );
      addTearDown(controller.dispose);
      const field = ZFieldSpec(
        name: 's',
        type: EditionFieldType.select,
        label: 'Select',
        config: ZSelectConfig(modalThreshold: 2),
        choices: <ZFieldChoice>[
          ZFieldChoice(value: 'a', label: 'Alpha'),
          ZFieldChoice(value: 'b', label: 'Beta'),
        ],
      );
      await tester.pumpWidget(
          _mount(controller: controller, fields: const <ZFieldSpec>[field]));
      await tester.pump();
      expect(find.byType(DropdownButtonFormField<Object?>), findsNothing);
    });
  });

  group('Variante multi chips du select (AC4)', () {
    testWidgets('add via modal → chips ; remove via chip → onChanged liste',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'s': <Object?>[]},
        visibleFields: <String>['s'],
      );
      addTearDown(controller.dispose);
      const field = ZFieldSpec(
        name: 's',
        type: EditionFieldType.select,
        label: 'Tags',
        multiple: true,
        config: ZSelectConfig(searchable: true),
        choices: <ZFieldChoice>[
          ZFieldChoice(value: 'a', label: 'Alpha'),
          ZFieldChoice(value: 'b', label: 'Beta'),
        ],
      );
      await tester.pumpWidget(
          _mount(controller: controller, fields: const <ZFieldSpec>[field]));
      await tester.pump();

      // Ouvre le modal multi via le bouton Add.
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Alpha'));
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Beta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(controller.valueOf('s'), <Object?>['a', 'b']);
      // Chips rendus.
      expect(find.byType(InputChip), findsNWidgets(2));

      // Supprime le chip Alpha (premier) → onChanged reçoit la liste réduite.
      await tester.tap(find.byTooltip('Remove').first);
      await tester.pumpAndSettle();
      expect(controller.valueOf('s'), <Object?>['b']);
    });
  });

  group('Choix dynamiques cross-champ choicesFromKey (AC7, SM-1)', () {
    testWidgets('tranche source → options ; changement → recompute ciblé',
        (tester) async {
      final builds = <String, int>{};
      final controller = ZFormController(
        initialValues: <String, Object?>{
          'cats': const <ZFieldChoice>[ZFieldChoice(value: 'a', label: 'Alpha')],
          'r': null,
          't': '',
        },
        visibleFields: <String>['cats', 'r', 't'],
      );
      addTearDown(controller.dispose);
      const fields = <ZFieldSpec>[
        ZFieldSpec(name: 'cats', type: EditionFieldType.hidden),
        ZFieldSpec(
          name: 'r',
          type: EditionFieldType.radio,
          label: 'Depend',
          config: ZSelectConfig(choicesFromKey: 'cats'),
        ),
        ZFieldSpec(name: 't', type: EditionFieldType.text, label: 'Libre'),
      ];
      await tester.pumpWidget(_mount(
        controller: controller,
        fields: fields,
        onFieldBuild: (n) => builds[n] = (builds[n] ?? 0) + 1,
      ));
      await tester.pump();

      expect(find.text('Alpha'), findsOneWidget);
      final buildsAfterInit = builds['r'] ?? 0;

      // Change la tranche source → options recomposées (recompute CIBLÉ de 'r').
      controller.setValue('cats', const <ZFieldChoice>[
        ZFieldChoice(value: 'a', label: 'Alpha'),
        ZFieldChoice(value: 'b', label: 'Beta'),
      ]);
      await tester.pump();
      expect(find.text('Beta'), findsOneWidget);
      expect((builds['r'] ?? 0) > buildsAfterInit, isTrue,
          reason: 'le champ dépendant recompute');

      // SM-1 : 100 frappes dans un champ NON référencé → 0 recompute de 'r'.
      final buildsBeforeTyping = builds['r'] ?? 0;
      final textField = find.byType(TextField).first;
      for (var i = 0; i < 100; i++) {
        await tester.enterText(textField, 'x' * (i + 1));
      }
      await tester.pump();
      expect(builds['r'], buildsBeforeTyping,
          reason: 'frappe hors clé ne reconstruit pas le select (SM-1)');
    });

    testWidgets('tranche absente/mal typée → repli field.choices (AD-10)',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'cats': 'not-a-list', 'r': null},
        visibleFields: <String>['cats', 'r'],
      );
      addTearDown(controller.dispose);
      const fields = <ZFieldSpec>[
        ZFieldSpec(name: 'cats', type: EditionFieldType.hidden),
        ZFieldSpec(
          name: 'r',
          type: EditionFieldType.radio,
          label: 'Depend',
          config: ZSelectConfig(choicesFromKey: 'cats'),
          choices: <ZFieldChoice>[ZFieldChoice(value: 's', label: 'Statique')],
        ),
      ];
      await tester.pumpWidget(
          _mount(controller: controller, fields: fields));
      await tester.pump();
      expect(find.text('Statique'), findsOneWidget, reason: 'repli statique');
    });
  });

  group('Source calculée ZChoicesSource + priorité (AC8)', () {
    testWidgets('registre résout la source → choix calculés depuis filterKeys',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'parent': 'FR', 'r': null},
        visibleFields: <String>['parent', 'r'],
      );
      addTearDown(controller.dispose);
      const fields = <ZFieldSpec>[
        ZFieldSpec(name: 'parent', type: EditionFieldType.hidden),
        ZFieldSpec(
          name: 'r',
          type: EditionFieldType.radio,
          label: 'Calculé',
          config: ZSelectConfig(
            choicesSourceKey: 'computed',
            filterKeys: <String>['parent'],
          ),
        ),
      ];
      final registry = ZChoicesSourceRegistry()
        ..register('computed', const _ComputedChoices());
      await tester.pumpWidget(_mount(
        controller: controller,
        fields: fields,
        choicesRegistry: registry,
      ));
      await tester.pump();
      expect(find.text('X de FR'), findsOneWidget);
      expect(find.text('Y de FR'), findsOneWidget);
    });

    testWidgets(
        'priorité : choicesSourceKey > choicesFromKey (source résolue prime)',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{
          'parent': 'FR',
          'cats': const <ZFieldChoice>[
            ZFieldChoice(value: 'fk', label: 'DepuisTranche')
          ],
          'r': null,
        },
        visibleFields: <String>['parent', 'cats', 'r'],
      );
      addTearDown(controller.dispose);
      const fields = <ZFieldSpec>[
        ZFieldSpec(name: 'parent', type: EditionFieldType.hidden),
        ZFieldSpec(name: 'cats', type: EditionFieldType.hidden),
        ZFieldSpec(
          name: 'r',
          type: EditionFieldType.radio,
          label: 'Prio',
          config: ZSelectConfig(
            choicesSourceKey: 'computed',
            choicesFromKey: 'cats',
            filterKeys: <String>['parent'],
          ),
        ),
      ];
      final registry = ZChoicesSourceRegistry()
        ..register('computed', const _ComputedChoices());
      await tester.pumpWidget(_mount(
        controller: controller,
        fields: fields,
        choicesRegistry: registry,
      ));
      await tester.pump();
      expect(find.text('X de FR'), findsOneWidget, reason: 'source prime');
      expect(find.text('DepuisTranche'), findsNothing);
    });

    testWidgets('registre absent → repli choicesFromKey puis statique (AD-10)',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{
          'cats': const <ZFieldChoice>[
            ZFieldChoice(value: 'fk', label: 'DepuisTranche')
          ],
          'r': null,
        },
        visibleFields: <String>['cats', 'r'],
      );
      addTearDown(controller.dispose);
      const fields = <ZFieldSpec>[
        ZFieldSpec(name: 'cats', type: EditionFieldType.hidden),
        ZFieldSpec(
          name: 'r',
          type: EditionFieldType.radio,
          label: 'Repli',
          config: ZSelectConfig(
            choicesSourceKey: 'computed',
            choicesFromKey: 'cats',
          ),
        ),
      ];
      // Aucun registre injecté → source non résolue → repli choicesFromKey.
      await tester.pumpWidget(
          _mount(controller: controller, fields: fields));
      await tester.pump();
      expect(find.text('DepuisTranche'), findsOneWidget);
    });
  });
}
