// CR DODLP « CRUD inline de relation sans ACL » (2026-08-17) — gardes de RENDU
// des trois droits du port `ZRelationCrudHandler` : chaque geste refusé
// **disparaît** de la feuille de sélection, les deux autres restent. Un geste
// refusé n'est jamais un bouton inerte : il est ABSENT, donc inatteignable —
// ni bouton, ni icône, ni action sémantique (garde adversariale ci-dessous).
// Aucun backend : sources et handlers DANS le test.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Source dynamique de test : émet une liste fixe de DEUX options — le compte
/// d'icônes attendu est donc **absolu** (2 Modifier + 2 Copier), pas relatif à
/// un autre rendu.
class _ListSource extends ZRelationSource {
  const _ListSource(this.data);

  final List<ZFieldChoice> data;

  @override
  Stream<List<ZFieldChoice>> options(Map<String, Object?> filterContext) =>
      Stream<List<ZFieldChoice>>.value(data);
}

/// Handler CRUD de test : droits déclarés (ou **levés**) + compteurs d'appels.
///
/// `throwOn*` simule une ACL hôte défaillante (session nulle, droit pas encore
/// chargé) : le socle doit **fermer** le geste, jamais l'ouvrir (AD-10).
class _AclCrud extends ZRelationCrudHandler {
  _AclCrud({
    this.allowCreate = true,
    this.allowEdit = true,
    this.allowCopy = true,
    this.throwOnCreate = false,
    this.throwOnEdit = false,
    this.throwOnCopy = false,
  });

  final bool allowCreate;
  final bool allowEdit;
  final bool allowCopy;
  final bool throwOnCreate;
  final bool throwOnEdit;
  final bool throwOnCopy;

  int createCalls = 0;
  int editCalls = 0;
  int copyCalls = 0;

  @override
  bool get canCreate => throwOnCreate ? throw StateError('acl') : allowCreate;

  @override
  bool get canEdit => throwOnEdit ? throw StateError('acl') : allowEdit;

  @override
  bool get canCopy => throwOnCopy ? throw StateError('acl') : allowCopy;

  @override
  Future<ZFieldChoice?> create(Map<String, Object?> context) async {
    createCalls++;
    return const ZFieldChoice(value: 'new', label: 'Nouveau');
  }

  @override
  Future<ZFieldChoice?> edit(Object? value) async {
    editCalls++;
    return ZFieldChoice(value: value, label: 'Édité');
  }

  @override
  Future<ZFieldChoice?> copy(Object? value) async {
    copyCalls++;
    return ZFieldChoice(value: '$value-copy', label: 'Copie');
  }
}

/// Handler qui **ne déclare aucun droit** — la seule forme qui existait avant
/// la CR. Il n'hérite d'aucun override : c'est le défaut du port lui-même qui
/// est mesuré, pas une déclaration du test.
class _SilentCrud extends ZRelationCrudHandler {
  const _SilentCrud();

  @override
  Future<ZFieldChoice?> create(Map<String, Object?> context) async => null;

  @override
  Future<ZFieldChoice?> edit(Object? value) async => null;

  @override
  Future<ZFieldChoice?> copy(Object? value) async => null;
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

/// Même champ, mais `searchable` DÉCLARÉ : la feuille s'ouvre même quand le
/// handler n'offre plus rien (indispensable pour prouver l'absence des trois
/// gestes DANS la feuille).
const _relCrudSearchableField = ZFieldSpec(
  name: 'rel',
  type: EditionFieldType.relation,
  label: 'Relation',
  config: ZRelationConfig(
    sourceKey: 'prov',
    crudKey: 'provCrud',
    searchable: true,
  ),
);

ZRelationSourceRegistry _srcReg() => ZRelationSourceRegistry()
  ..register(
    'prov',
    const _ListSource(<ZFieldChoice>[
      ZFieldChoice(value: 'a', label: 'Alpha'),
      ZFieldChoice(value: 'b', label: 'Beta'),
    ]),
  );

/// Monte le champ, ouvre la feuille de sélection, et rend le contrôleur (pour
/// vérifier qu'aucune écriture n'a eu lieu).
Future<ZFormController> _openSheet(
  WidgetTester tester,
  _AclCrud crud, {
  ZFieldSpec field = _relCrudField,
}) async {
  final controller = _ctrl();
  addTearDown(controller.dispose);
  await tester.pumpWidget(_mount(
    controller: controller,
    fields: <ZFieldSpec>[field],
    sourceRegistry: _srcReg(),
    crudRegistry: ZRelationCrudRegistry()..register('provCrud', crud),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Select'));
  await tester.pumpAndSettle();
  return controller;
}

/// L'`IconButton` (cible tactile réelle, ≥ 48 dp) portant ce [tooltip] —
/// `find.byTooltip` ne rend que le `Tooltip` interne (40 dp de visuel).
Finder _iconButtonWithTooltip(String tooltip) => find
    .ancestor(
      of: find.byTooltip(tooltip).first,
      matching: find.byType(IconButton),
    )
    .first;

void main() {
  group('Gestes refusés isolément (CR DODLP 2026-08-17)', () {
    testWidgets('créer refusé ⇒ bouton Créer ABSENT, Modifier/Copier restent',
        (tester) async {
      await _openSheet(tester, _AclCrud(allowCreate: false));

      expect(find.text('Create'), findsNothing,
          reason: 'geste refusé ⇒ absent, pas inerte');
      expect(find.byTooltip('Edit'), findsNWidgets(2),
          reason: 'un droit refusé n\'emporte pas les autres');
      expect(find.byTooltip('Copy'), findsNWidgets(2));
    });

    testWidgets('modifier refusé ⇒ icône Modifier ABSENTE, Créer/Copier restent',
        (tester) async {
      await _openSheet(tester, _AclCrud(allowEdit: false));

      expect(find.byTooltip('Edit'), findsNothing);
      expect(find.text('Create'), findsOneWidget);
      expect(find.byTooltip('Copy'), findsNWidgets(2));
    });

    testWidgets('copier refusé ⇒ icône Copier ABSENTE, Créer/Modifier restent',
        (tester) async {
      await _openSheet(tester, _AclCrud(allowCopy: false));

      expect(find.byTooltip('Copy'), findsNothing);
      expect(find.text('Create'), findsOneWidget);
      expect(find.byTooltip('Edit'), findsNWidgets(2));
    });
  });

  group('Contre-témoin — handler qui ne déclare rien (rétro-compat stricte)',
      () {
    testWidgets('les TROIS gestes, en comptes ABSOLUS de widgets',
        (tester) async {
      // Handler SANS aucune déclaration : ce qui est mesuré est le défaut du
      // port (`canCreate/canEdit/canCopy => true`), pas un droit que le test
      // se serait donné lui-même.
      final controller = _ctrl();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_mount(
        controller: controller,
        fields: const <ZFieldSpec>[_relCrudField],
        sourceRegistry: _srcReg(),
        crudRegistry: ZRelationCrudRegistry()
          ..register('provCrud', const _SilentCrud()),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      // Comptes absolus : un contre-témoin qui comparerait deux rendus
      // passifs ne verrait pas un nœud ajouté à TOUT LE MONDE.
      expect(find.text('Create'), findsOneWidget);
      expect(find.byTooltip('Edit'), findsNWidgets(2));
      expect(find.byTooltip('Copy'), findsNWidgets(2));
      expect(find.byIcon(Icons.edit), findsNWidgets(2));
      expect(find.byIcon(Icons.copy), findsNWidgets(2));
      // 2 options × (Modifier + Copier) = 4 IconButton, et RIEN d'autre.
      expect(find.byType(IconButton), findsNWidgets(4));
    });
  });

  group('Adversariale — un geste refusé n\'est atteignable par AUCUN chemin',
      () {
    testWidgets('les trois refusés ⇒ zéro affordance et zéro appel du handler',
        (tester) async {
      final crud =
          _AclCrud(allowCreate: false, allowEdit: false, allowCopy: false);
      final ZFormController controller = await _openSheet(
        tester,
        crud,
        field: _relCrudSearchableField,
      );

      // 1. Aucun bouton, aucune icône, aucun tooltip.
      expect(find.text('Create'), findsNothing);
      expect(find.byTooltip('Edit'), findsNothing);
      expect(find.byTooltip('Copy'), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.byIcon(Icons.edit), findsNothing);
      expect(find.byIcon(Icons.copy), findsNothing);
      expect(find.byType(IconButton), findsNothing,
          reason: 'aucune colonne d\'actions n\'est même construite');

      // 2. Aucune action sémantique : ce que ne voit pas l'œil ne doit pas non
      // plus exister pour un lecteur d'écran ni pour un focus clavier.
      expect(find.bySemanticsLabel('Create'), findsNothing);
      expect(find.bySemanticsLabel('Edit'), findsNothing);
      expect(find.bySemanticsLabel('Copy'), findsNothing);

      // 3. Porte dérobée : on actionne TOUT ce qui reste actionnable dans la
      // feuille — la recherche, puis une option (en mono, choisir ferme et
      // confirme). Le handler ne doit être appelé par AUCUN de ces chemins,
      // alors que la sélection normale, elle, reste intacte.
      final Finder rows = find.byType(CheckboxListTile);
      expect(rows, findsNWidgets(2), reason: 'les options restent offertes');
      await tester.enterText(find.byType(TextField), 'Al');
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsOneWidget);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();

      expect(crud.createCalls, 0);
      expect(crud.editCalls, 0);
      expect(crud.copyCalls, 0);
      expect(controller.valueOf('rel'), 'a',
          reason: 'la sélection ordinaire n\'est pas emportée par le refus');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'handler sans aucun geste ⇒ ne force plus la feuille (dropdown rendu)',
        (tester) async {
      final controller = _ctrl();
      addTearDown(controller.dispose);
      final crud =
          _AclCrud(allowCreate: false, allowEdit: false, allowCopy: false);
      await tester.pumpWidget(_mount(
        controller: controller,
        fields: const <ZFieldSpec>[_relCrudField], // `searchable` NON déclaré.
        sourceRegistry: _srcReg(),
        crudRegistry: ZRelationCrudRegistry()..register('provCrud', crud),
      ));
      await tester.pumpAndSettle();

      // Rien à montrer ⇒ rien à imposer : le champ retombe sur le dropdown.
      expect(find.byType(DropdownButtonFormField<Object?>), findsOneWidget);
      expect(find.text('Create'), findsNothing);
    });

    testWidgets('contre-témoin : handler complet ⇒ la feuille reste imposée',
        (tester) async {
      final controller = _ctrl();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_mount(
        controller: controller,
        fields: const <ZFieldSpec>[_relCrudField], // `searchable` NON déclaré.
        sourceRegistry: _srcReg(),
        crudRegistry: ZRelationCrudRegistry()..register('provCrud', _AclCrud()),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(DropdownButtonFormField<Object?>), findsNothing);
      expect(find.text('Select'), findsOneWidget);
    });
  });

  group('AD-10 — un droit qui LÈVE ferme le geste, sans casser le rendu', () {
    testWidgets('canCreate lève ⇒ Créer absent, les deux autres rendus',
        (tester) async {
      await _openSheet(tester, _AclCrud(throwOnCreate: true));

      expect(find.text('Create'), findsNothing,
          reason: 'repli FERMANT : jamais ouvrant');
      expect(find.byTooltip('Edit'), findsNWidgets(2));
      expect(find.byTooltip('Copy'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('canEdit lève ⇒ Modifier absent, Créer/Copier rendus',
        (tester) async {
      await _openSheet(tester, _AclCrud(throwOnEdit: true));

      expect(find.byTooltip('Edit'), findsNothing);
      expect(find.text('Create'), findsOneWidget);
      expect(find.byTooltip('Copy'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('canCopy lève ⇒ Copier absent, Créer/Modifier rendus',
        (tester) async {
      await _openSheet(tester, _AclCrud(throwOnCopy: true));

      expect(find.byTooltip('Copy'), findsNothing);
      expect(find.text('Create'), findsOneWidget);
      expect(find.byTooltip('Edit'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });

  group('A11y — ce qui reste garde sa cible et son annotation (AD-13)', () {
    testWidgets('copier refusé ⇒ Modifier reste ≥ 48 dp et annoté',
        (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _openSheet(tester, _AclCrud(allowCopy: false));

      final Finder editButton = _iconButtonWithTooltip('Edit');
      final Size edit = tester.getSize(editButton);
      expect(edit.width, greaterThanOrEqualTo(48.0));
      expect(edit.height, greaterThanOrEqualTo(48.0));
      // L'annotation survit à la disparition de la voisine.
      expect(tester.widget<IconButton>(editButton).tooltip, 'Edit');
      // Et la feuille entière reste conforme aux cibles tactiles.
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('modifier refusé ⇒ Créer reste ≥ 48 dp de haut',
        (tester) async {
      await _openSheet(tester, _AclCrud(allowEdit: false));

      final Finder createButton = find.widgetWithText(TextButton, 'Create');
      // La cible DÉCLARÉE par le socle (et pas seulement le plancher que le
      // SDK accorde de toute façon à un `TextButton`) : sans cette assertion,
      // la garde resterait verte si la contrainte disparaissait du code.
      final ConstrainedBox box = tester.widget<ConstrainedBox>(
        find
            .ancestor(of: createButton, matching: find.byType(ConstrainedBox))
            .first,
      );
      expect(box.constraints.minHeight, greaterThanOrEqualTo(48.0));
      expect(box.constraints.minWidth, greaterThanOrEqualTo(48.0));
      // Et la cible RENDUE.
      final Size create = tester.getSize(createButton);
      expect(create.height, greaterThanOrEqualTo(48.0));
      expect(create.width, greaterThanOrEqualTo(48.0));
    });

    testWidgets('créer refusé ⇒ Copier reste ≥ 48 dp et annoté',
        (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _openSheet(tester, _AclCrud(allowCreate: false));

      final Finder copyButton = _iconButtonWithTooltip('Copy');
      final Size copy = tester.getSize(copyButton);
      expect(copy.width, greaterThanOrEqualTo(48.0));
      expect(copy.height, greaterThanOrEqualTo(48.0));
      expect(tester.widget<IconButton>(copyButton).tooltip, 'Copy');
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });

  group('Les gestes offerts fonctionnent encore (aucune régression)', () {
    testWidgets('créer refusé, modifier offert ⇒ modifier écrit toujours',
        (tester) async {
      final controller = _ctrl();
      addTearDown(controller.dispose);
      final crud = _AclCrud(allowCreate: false);
      await tester.pumpWidget(_mount(
        controller: controller,
        fields: const <ZFieldSpec>[_relCrudField],
        sourceRegistry: _srcReg(),
        crudRegistry: ZRelationCrudRegistry()..register('provCrud', crud),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Edit').first);
      await tester.pumpAndSettle();

      expect(crud.editCalls, 1);
      expect(crud.createCalls, 0);
      expect(controller.valueOf('rel'), 'a');
    });
  });
}
