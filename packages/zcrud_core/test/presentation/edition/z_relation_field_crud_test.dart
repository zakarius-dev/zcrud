// DP-15 (AC9..AC11, AC13, AC17) — CRUD inline du champ `relation` via le seam
// neutre `ZRelationCrudHandler` (résolu par `ZcrudScope.relationCrudRegistry` +
// `ZRelationConfig.crudKey`). Boutons Créer/Modifier/Copier + auto-sélection +
// défensif (Future null/erreur → no-op). Aucun backend : sources DANS le test.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Source dynamique de test : émet une liste fixe.
class _ListSource extends ZRelationSource {
  const _ListSource(this.data);

  final List<ZFieldChoice> data;

  @override
  Stream<List<ZFieldChoice>> options(Map<String, Object?> filterContext) =>
      Stream<List<ZFieldChoice>>.value(data);
}

/// Handler CRUD de test : retours paramétrables + option d'exception.
class _FakeCrud extends ZRelationCrudHandler {
  _FakeCrud({
    this.createResult,
    this.editResult,
    this.copyResult,
    this.throwing = false,
  });

  final ZFieldChoice? createResult;
  final ZFieldChoice? editResult;
  final ZFieldChoice? copyResult;
  final bool throwing;

  int createCalls = 0;
  Map<String, Object?>? lastCreateContext;

  @override
  Future<ZFieldChoice?> create(Map<String, Object?> context) async {
    createCalls++;
    lastCreateContext = context;
    if (throwing) throw StateError('boom');
    return createResult;
  }

  @override
  Future<ZFieldChoice?> edit(Object? value) async {
    if (throwing) throw StateError('boom');
    return editResult;
  }

  @override
  Future<ZFieldChoice?> copy(Object? value) async {
    if (throwing) throw StateError('boom');
    return copyResult;
  }
}

Widget _mount({
  required ZFormController controller,
  required List<ZFieldSpec> fields,
  ZRelationSourceRegistry? sourceRegistry,
  ZRelationCrudRegistry? crudRegistry,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ZcrudScope(
        relationSourceRegistry: sourceRegistry,
        relationCrudRegistry: crudRegistry,
        child: DynamicEdition(controller: controller, fields: fields),
      ),
    ),
  );
}

ZFormController _ctrl() => ZFormController(
      initialValues: <String, Object?>{'rel': null},
      visibleFields: <String>['rel'],
    );

const _relCrudField = ZFieldSpec(
  name: 'rel',
  type: EditionFieldType.relation,
  label: 'Relation',
  config: ZRelationConfig(sourceKey: 'prov', crudKey: 'provCrud'),
);

ZRelationSourceRegistry _srcReg() => ZRelationSourceRegistry()
  ..register(
    'prov',
    const _ListSource(<ZFieldChoice>[
      ZFieldChoice(value: 'a', label: 'Alpha'),
      ZFieldChoice(value: 'b', label: 'Beta'),
    ]),
  );

void main() {
  testWidgets('create → option auto-sélectionnée + modal fermé (AC11)',
      (tester) async {
    final controller = _ctrl();
    addTearDown(controller.dispose);
    final crud = _FakeCrud(
        createResult: const ZFieldChoice(value: 'new', label: 'Nouveau'));
    await tester.pumpWidget(_mount(
      controller: controller,
      fields: const <ZFieldSpec>[_relCrudField],
      sourceRegistry: _srcReg(),
      crudRegistry: ZRelationCrudRegistry()..register('provCrud', crud),
    ));
    await tester.pumpAndSettle();

    // Ouvre le modal (chemin searchable forcé par le handler CRUD).
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    expect(find.text('Create'), findsOneWidget);

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(crud.createCalls, 1);
    expect(controller.valueOf('rel'), 'new', reason: 'auto-sélection mono');
    expect(find.text('Create'), findsNothing, reason: 'modal fermé (mono)');
  });

  testWidgets('edit → option mise à jour auto-sélectionnée (AC11)',
      (tester) async {
    final controller = _ctrl();
    addTearDown(controller.dispose);
    final crud = _FakeCrud(
        editResult: const ZFieldChoice(value: 'a', label: 'Alpha édité'));
    await tester.pumpWidget(_mount(
      controller: controller,
      fields: const <ZFieldSpec>[_relCrudField],
      sourceRegistry: _srcReg(),
      crudRegistry: ZRelationCrudRegistry()..register('provCrud', crud),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();

    // Icône Modifier de la 1ʳᵉ option.
    await tester.tap(find.byTooltip('Edit').first);
    await tester.pumpAndSettle();
    expect(controller.valueOf('rel'), 'a');
  });

  testWidgets('copy → option copiée auto-sélectionnée (AC11)', (tester) async {
    final controller = _ctrl();
    addTearDown(controller.dispose);
    final crud = _FakeCrud(
        copyResult: const ZFieldChoice(value: 'a-copy', label: 'Copie Alpha'));
    await tester.pumpWidget(_mount(
      controller: controller,
      fields: const <ZFieldSpec>[_relCrudField],
      sourceRegistry: _srcReg(),
      crudRegistry: ZRelationCrudRegistry()..register('provCrud', crud),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Copy').first);
    await tester.pumpAndSettle();
    expect(controller.valueOf('rel'), 'a-copy');
  });

  testWidgets('Future null → aucune écriture, aucun crash, modal ouvert (AD-10)',
      (tester) async {
    final controller = _ctrl();
    addTearDown(controller.dispose);
    final crud = _FakeCrud(); // createResult null.
    await tester.pumpWidget(_mount(
      controller: controller,
      fields: const <ZFieldSpec>[_relCrudField],
      sourceRegistry: _srcReg(),
      crudRegistry: ZRelationCrudRegistry()..register('provCrud', crud),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(crud.createCalls, 1);
    expect(controller.valueOf('rel'), isNull, reason: 'aucune écriture');
    expect(find.text('Create'), findsOneWidget, reason: 'modal reste ouvert');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Future en erreur → capturé, aucune écriture (AD-10)',
      (tester) async {
    final controller = _ctrl();
    addTearDown(controller.dispose);
    final crud = _FakeCrud(throwing: true);
    await tester.pumpWidget(_mount(
      controller: controller,
      fields: const <ZFieldSpec>[_relCrudField],
      sourceRegistry: _srcReg(),
      crudRegistry: ZRelationCrudRegistry()..register('provCrud', crud),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(controller.valueOf('rel'), isNull);
    expect(tester.takeException(), isNull, reason: 'erreur capturée');
  });

  testWidgets('crudHandler null → aucun bouton CRUD (modal DP-5 identique)',
      (tester) async {
    final controller = _ctrl();
    addTearDown(controller.dispose);
    // Config avec source SEARCHABLE mais SANS crudKey → aucun handler résolu.
    const field = ZFieldSpec(
      name: 'rel',
      type: EditionFieldType.relation,
      label: 'Relation',
      config: ZRelationConfig(sourceKey: 'prov', searchable: true),
    );
    await tester.pumpWidget(_mount(
      controller: controller,
      fields: const <ZFieldSpec>[field],
      sourceRegistry: _srcReg(),
      // Registre présent mais aucune clé 'provCrud' → trySourceFor null.
      crudRegistry: ZRelationCrudRegistry(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();

    expect(find.text('Create'), findsNothing);
    expect(find.byTooltip('Edit'), findsNothing);
    expect(find.byTooltip('Copy'), findsNothing);
  });
}
