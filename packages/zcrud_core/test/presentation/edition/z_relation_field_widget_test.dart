// DP-5 (AC6..AC17) — `ZRelationFieldWidget` : source dynamique NEUTRE (flux
// injecté via `ZcrudScope.relationSourceRegistry`), filtre cross-champ ciblé
// (SM-1), multi-sélection (chips), modal de recherche, repli statique strict,
// états défensifs (AD-10). Aucun backend : la source de test vit DANS le test.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Source de test : émet ce que lui envoie [controller] et ENREGISTRE chaque
/// `filterContext` reçu (preuve du filtre cross-champ + du nombre d'abonnements).
class _StreamSource extends ZRelationSource {
  _StreamSource(this.stream);

  final Stream<List<ZFieldChoice>> stream;
  final List<Map<String, Object?>> received = <Map<String, Object?>>[];

  @override
  Stream<List<ZFieldChoice>> options(Map<String, Object?> filterContext) {
    received.add(Map<String, Object?>.from(filterContext));
    return stream;
  }
}

/// Source dont le flux DÉPEND du `filterContext` (émission synchrone `Stream.value`).
class _FilteringSource extends ZRelationSource {
  _FilteringSource();

  final List<Map<String, Object?>> received = <Map<String, Object?>>[];

  @override
  Stream<List<ZFieldChoice>> options(Map<String, Object?> filterContext) {
    received.add(Map<String, Object?>.from(filterContext));
    final parent = filterContext['parent'];
    return Stream<List<ZFieldChoice>>.value(<ZFieldChoice>[
      ZFieldChoice(value: 'child_of_$parent', label: 'Enfant de $parent'),
    ]);
  }
}

Widget _mount({
  required ZFormController controller,
  required List<ZFieldSpec> fields,
  ZRelationSourceRegistry? registry,
  void Function(String name)? onFieldBuild,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ZcrudScope(
        relationSourceRegistry: registry,
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

ZRelationSourceRegistry _registryWith(String key, ZRelationSource source) =>
    ZRelationSourceRegistry()..register(key, source);

void main() {
  group('Source dynamique (AC6, AC10)', () {
    testWidgets('chargement → émission → options live rendues (1 abonnement)',
        (tester) async {
      final ctrl = StreamController<List<ZFieldChoice>>.broadcast();
      addTearDown(ctrl.close);
      final source = _StreamSource(ctrl.stream);
      final controller = ZFormController(
        initialValues: <String, Object?>{'rel': null},
        visibleFields: <String>['rel'],
      );
      addTearDown(controller.dispose);
      const field = ZFieldSpec(
        name: 'rel',
        type: EditionFieldType.relation,
        label: 'Relation',
        config: ZRelationConfig(sourceKey: 'prov'),
      );

      await tester.pumpWidget(_mount(
        controller: controller,
        fields: const <ZFieldSpec>[field],
        registry: _registryWith('prov', source),
      ));
      await tester.pump();

      // Avant émission : état chargement (indice 'Loading…'), aucune exception.
      expect(find.text('Loading…'), findsOneWidget);
      expect(source.received, hasLength(1), reason: 'un seul abonnement');

      // Émission live.
      ctrl.add(const <ZFieldChoice>[
        ZFieldChoice(value: 'a', label: 'Alpha'),
        ZFieldChoice(value: 'b', label: 'Beta'),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Loading…'), findsNothing);

      // Le dropdown propose les options live : sélection écrit la tranche.
      await tester.tap(find.byType(DropdownButtonFormField<Object?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beta').last);
      await tester.pumpAndSettle();
      expect(controller.valueOf('rel'), 'b');

      // Nouvelle émission → même abonnement (pas de ré-appel de options()).
      ctrl.add(const <ZFieldChoice>[
        ZFieldChoice(value: 'a', label: 'Alpha'),
        ZFieldChoice(value: 'b', label: 'Beta'),
        ZFieldChoice(value: 'c', label: 'Gamma'),
      ]);
      await tester.pump();
      expect(source.received, hasLength(1),
          reason: 'une nouvelle émission ne recrée pas l\'abonnement');
      expect(tester.takeException(), isNull);
    });

    testWidgets('émission vide → contrôle sans option, aucun crash (AD-10)',
        (tester) async {
      final source = _StreamSource(Stream<List<ZFieldChoice>>.value(const []));
      final controller = ZFormController(
        initialValues: <String, Object?>{'rel': null},
        visibleFields: <String>['rel'],
      );
      addTearDown(controller.dispose);
      const field = ZFieldSpec(
        name: 'rel',
        type: EditionFieldType.relation,
        config: ZRelationConfig(sourceKey: 'prov'),
      );
      await tester.pumpWidget(_mount(
        controller: controller,
        fields: const <ZFieldSpec>[field],
        registry: _registryWith('prov', source),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<Object?>), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('flux en erreur → aucune exception propagée (AD-10)',
        (tester) async {
      final ctrl = StreamController<List<ZFieldChoice>>.broadcast();
      addTearDown(ctrl.close);
      final source = _StreamSource(ctrl.stream);
      final controller = ZFormController(
        initialValues: <String, Object?>{'rel': null},
        visibleFields: <String>['rel'],
      );
      addTearDown(controller.dispose);
      const field = ZFieldSpec(
        name: 'rel',
        type: EditionFieldType.relation,
        config: ZRelationConfig(sourceKey: 'prov'),
      );
      await tester.pumpWidget(_mount(
        controller: controller,
        fields: const <ZFieldSpec>[field],
        registry: _registryWith('prov', source),
      ));
      await tester.pump();

      // Émission valide puis ERREUR : la dernière liste connue est conservée,
      // aucune exception ne remonte au build.
      ctrl.add(const <ZFieldChoice>[ZFieldChoice(value: 'a', label: 'Alpha')]);
      await tester.pump();
      ctrl.addError(StateError('boom'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(DropdownButtonFormField<Object?>), findsOneWidget);
    });
  });

  group('Filtre cross-champ ciblé (AC11, AC12, SM-1)', () {
    testWidgets('changer un filterKey re-interroge la source avec le nouveau '
        'contexte ; une frappe HORS filterKeys ne re-interroge pas',
        (tester) async {
      final source = _FilteringSource();
      final controller = ZFormController(
        initialValues: <String, Object?>{
          'parent': 'p1',
          'other': '',
          'rel': null,
        },
        visibleFields: <String>['parent', 'other', 'rel'],
      );
      addTearDown(controller.dispose);
      final fields = <ZFieldSpec>[
        const ZFieldSpec(name: 'parent', type: EditionFieldType.text),
        const ZFieldSpec(name: 'other', type: EditionFieldType.text),
        const ZFieldSpec(
          name: 'rel',
          type: EditionFieldType.relation,
          config: ZRelationConfig(
              sourceKey: 'prov', filterKeys: <String>['parent']),
        ),
      ];
      await tester.pumpWidget(_mount(
        controller: controller,
        fields: fields,
        registry: _registryWith('prov', source),
      ));
      await tester.pumpAndSettle();

      expect(source.received, hasLength(1));
      expect(source.received.first['parent'], 'p1');

      // Frappe dans 'other' (HORS filterKeys) → aucun ré-abonnement (SM-1).
      controller.setValue('other', 'zzz');
      await tester.pump();
      expect(source.received, hasLength(1),
          reason: 'un champ hors filterKeys ne déclenche aucune ré-interrogation');

      // Changement du filterKey 'parent' → ré-interrogation avec le nouveau ctx.
      controller.setValue('parent', 'p2');
      await tester.pump();
      expect(source.received, hasLength(2));
      expect(source.received.last['parent'], 'p2');
      expect(tester.takeException(), isNull);
    });

    testWidgets('SM-1 : 100 frappes hors filterKeys ne reconstruisent pas le '
        'champ relation (structurel == 1)', (tester) async {
      tester.view.physicalSize = const Size(1000, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = ZFormController(
        initialValues: <String, Object?>{'nom': '', 'rel': null},
        visibleFields: <String>['nom', 'rel'],
      );
      addTearDown(controller.dispose);
      final fields = <ZFieldSpec>[
        const ZFieldSpec(name: 'nom', type: EditionFieldType.text, label: 'Nom'),
        const ZFieldSpec(
            name: 'rel', type: EditionFieldType.relation, label: 'Relation'),
      ];
      final builds = <String, int>{};
      await tester.pumpWidget(_mount(
        controller: controller,
        fields: fields,
        onFieldBuild: (n) => builds[n] = (builds[n] ?? 0) + 1,
      ));
      await tester.pumpAndSettle();
      final relBase = builds['rel'];
      expect(relBase, isNotNull);

      final target = find.descendant(
        of: find.byKey(const ValueKey<String>('nom')),
        matching: find.byType(EditableText),
      );
      await tester.tap(target);
      await tester.pump();
      final buffer = StringBuffer();
      for (var i = 1; i <= 100; i++) {
        buffer.write(String.fromCharCode(97 + (i % 26)));
        await tester.enterText(target, buffer.toString());
        await tester.pump();
      }
      expect(builds['rel'], relBase,
          reason: 'le champ relation ne reconstruit jamais sur une frappe hors '
              'filterKeys');
      expect(controller.valueOf('nom'), buffer.toString());
    });
  });

  group('Multi-sélection chips (AC8)', () {
    testWidgets('chips affichées, ajout via modal, suppression via chip',
        (tester) async {
      final source =
          _StreamSource(Stream<List<ZFieldChoice>>.value(const <ZFieldChoice>[
        ZFieldChoice(value: 'a', label: 'Alpha'),
        ZFieldChoice(value: 'b', label: 'Beta'),
        ZFieldChoice(value: 'c', label: 'Gamma'),
      ]));
      final controller = ZFormController(
        initialValues: <String, Object?>{'rel': <Object?>['a']},
        visibleFields: <String>['rel'],
      );
      addTearDown(controller.dispose);
      const field = ZFieldSpec(
        name: 'rel',
        type: EditionFieldType.relation,
        label: 'Relations',
        multiple: true,
        config: ZRelationConfig(sourceKey: 'prov'),
      );
      await tester.pumpWidget(_mount(
        controller: controller,
        fields: const <ZFieldSpec>[field],
        registry: _registryWith('prov', source),
      ));
      await tester.pumpAndSettle();

      // Chip initial 'Alpha'.
      expect(find.widgetWithText(InputChip, 'Alpha'), findsOneWidget);

      // Ouvre le modal d'ajout, coche 'Beta', confirme.
      await tester.tap(find.widgetWithText(TextButton, 'Add'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Beta'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pumpAndSettle();

      final selected = controller.valueOf('rel');
      expect(selected, isA<List<Object?>>());
      expect(selected as List, containsAll(<Object?>['a', 'b']));

      // Supprime le chip 'Alpha' (bouton de suppression, tooltip 'Remove')
      // → la liste ne contient plus 'a'.
      await tester.tap(find.descendant(
        of: find.widgetWithText(InputChip, 'Alpha'),
        matching: find.byTooltip('Remove'),
      ));
      await tester.pumpAndSettle();
      expect(controller.valueOf('rel') as List, isNot(contains('a')));
      expect(tester.takeException(), isNull);
    });
  });

  group('Modal de recherche (AC9)', () {
    testWidgets('mono searchable : recherche client filtre puis sélectionne',
        (tester) async {
      final source =
          _StreamSource(Stream<List<ZFieldChoice>>.value(const <ZFieldChoice>[
        ZFieldChoice(value: 'a', label: 'Alpha'),
        ZFieldChoice(value: 'b', label: 'Beta'),
        ZFieldChoice(value: 'c', label: 'Gamma'),
      ]));
      final controller = ZFormController(
        initialValues: <String, Object?>{'rel': null},
        visibleFields: <String>['rel'],
      );
      addTearDown(controller.dispose);
      const field = ZFieldSpec(
        name: 'rel',
        type: EditionFieldType.relation,
        label: 'Relation',
        config: ZRelationConfig(sourceKey: 'prov', searchable: true),
      );
      await tester.pumpWidget(_mount(
        controller: controller,
        fields: const <ZFieldSpec>[field],
        registry: _registryWith('prov', source),
      ));
      await tester.pumpAndSettle();

      // Ouvre le modal (déclencheur).
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      // Recherche 'gam' → seule 'Gamma' reste.
      await tester.enterText(find.byType(TextField), 'gam');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(CheckboxListTile, 'Gamma'), findsOneWidget);
      expect(find.widgetWithText(CheckboxListTile, 'Alpha'), findsNothing);

      // Sélection mono → ferme et écrit la valeur scalaire.
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Gamma'));
      await tester.pumpAndSettle();
      expect(controller.valueOf('rel'), 'c');
      expect(tester.takeException(), isNull);
    });
  });

  group('Repli statique strict (AC7, rétro-compat)', () {
    testWidgets('registre absent (null) → dropdown statique sur choices',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'rel': null},
        visibleFields: <String>['rel'],
      );
      addTearDown(controller.dispose);
      const field = ZFieldSpec(
        name: 'rel',
        type: EditionFieldType.relation,
        label: 'Relation',
        choices: <ZFieldChoice>[
          ZFieldChoice(value: 'a', label: 'Alpha'),
          ZFieldChoice(value: 'b', label: 'Beta'),
        ],
      );
      // registry: null (aucun relationSourceRegistry).
      await tester.pumpWidget(_mount(
        controller: controller,
        fields: const <ZFieldSpec>[field],
      ));
      await tester.pumpAndSettle();

      expect(find.byType(DropdownButtonFormField<Object?>), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<Object?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alpha').last);
      await tester.pumpAndSettle();
      expect(controller.valueOf('rel'), 'a');
      expect(tester.takeException(), isNull);
    });

    testWidgets('sourceKey non enregistré → repli statique (pas de crash)',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'rel': null},
        visibleFields: <String>['rel'],
      );
      addTearDown(controller.dispose);
      const field = ZFieldSpec(
        name: 'rel',
        type: EditionFieldType.relation,
        choices: <ZFieldChoice>[ZFieldChoice(value: 'a', label: 'Alpha')],
        config: ZRelationConfig(sourceKey: 'absent'),
      );
      // Registre présent mais sans la clé 'absent'.
      await tester.pumpWidget(_mount(
        controller: controller,
        fields: const <ZFieldSpec>[field],
        registry: _registryWith(
          'autre',
          _StreamSource(Stream<List<ZFieldChoice>>.value(const [])),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<Object?>), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
