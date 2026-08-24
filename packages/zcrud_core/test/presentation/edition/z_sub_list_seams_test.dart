// Canal déclaratif des **seams de présentation** des sous-listes (`subItems`)
// et des items dynamiques (`dynamicItem`).
//
// 🔴 MOTIF — le défaut visé est réel et mesuré : `ZSubListFieldWidget`
// acceptait déjà `itemTitleBuilder` et `acl`, `ZDynamicItemFieldWidget` un
// `fieldsResolver`, mais `ZFieldWidget` ne transmettait que
// `field`/`initialValue`/`collectionId`/`onChanged`. Ces seams étaient donc
// **inatteignables par le chemin nominal d'édition** : il fallait un
// `fieldBuilder` de remplacement — c'est-à-dire renoncer à l'agrégation vers la
// tranche parente, à la granularité (invariant AD-2), aux dialogues, à l'ACL et
// au soft-delete — pour les toucher. « Le socle sait faire, le présentateur ne
// relaie pas ».
//
// 🔴 LA GARDE PRINCIPALE est donc celle du groupe A : un hôte qui déclare un
// seam par le chemin **NOMINAL** (`DynamicEdition` SANS `fieldBuilder`) le voit
// **effectivement appliqué**. Une garde qui construirait `ZSubListFieldWidget`
// à la main passerait en n'observant pas le défaut — c'est exactement ainsi
// qu'il a survécu.
//
// 🔴 LE CONTRE-TÉMOIN (groupe B) n'assère pas « pas d'erreur » mais la
// **structure** : compte et types de widgets, à l'identique, quand rien n'est
// déclaré. Sans lui, un canal qui ajouterait silencieusement un nœud à chaque
// ligne resterait vert.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _itemFields = <ZFieldSpec>[
  ZFieldSpec(name: 'f1', type: EditionFieldType.text, label: 'F1'),
  ZFieldSpec(name: 'f2', type: EditionFieldType.text, label: 'F2'),
];

const _compactField = ZFieldSpec(
  name: 'items',
  type: EditionFieldType.subItems,
  label: 'Items',
  config: ZSubListConfig(
    itemFields: _itemFields,
    displayMode: ZSubListDisplayMode.compact,
    summaryFields: <String>['f1'],
  ),
);

const _tagsField = ZFieldSpec(
  name: 'items',
  type: EditionFieldType.subItems,
  label: 'Items',
  config: ZSubListConfig(
    itemFields: _itemFields,
    displayMode: ZSubListDisplayMode.tags,
    summaryFields: <String>['f1'],
  ),
);

// `displayMode` DÉCLARÉ : `compact` étant devenu le défaut, l'omettre ferait
// de ce champ « inline » un champ compact — et le contre-témoin de structure
// mesurerait alors le mauvais rendu.
const _inlineField = ZFieldSpec(
  name: 'items',
  type: EditionFieldType.subItems,
  label: 'Items',
  config: ZSubListConfig(
    itemFields: _itemFields,
    displayMode: ZSubListDisplayMode.inline,
  ),
);

const _dynamicField = ZFieldSpec(
  name: 'item',
  type: EditionFieldType.dynamicItem,
  label: 'Item',
  config: ZSubListConfig(itemFields: _itemFields),
);

const _seed = <Map<String, dynamic>>[
  <String, dynamic>{'id': 'ID-1', 'f1': 'Alpha', 'f2': 'a'},
  <String, dynamic>{'id': 'ID-2', 'f1': 'Beta', 'f2': 'b'},
];

/// Surface haute : `DynamicEdition` monte ses champs par `ListView.builder`
/// (montage PARESSEUX). Sur la surface par défaut, la sous-liste testée peut
/// n'être jamais montée — la garde serait alors verte pour la mauvaise raison.
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Hôte de test — ACL permissive **déclarée** au scope (le socle refuse par
/// défaut). [registry] est le canal sous test ; `null` ⇒ hôte passif.
Widget _host(
  Widget child, {
  ZSubListSeamRegistry? registry,
  ZAcl acl = const ZAllowAllAcl(),
  TextDirection dir = TextDirection.ltr,
}) =>
    MaterialApp(
      home: ZcrudScope(
        acl: acl,
        subListSeamRegistry: registry,
        child: Directionality(
          textDirection: dir,
          child: Scaffold(body: child),
        ),
      ),
    );

/// La liste INTERNE de la sous-liste — jamais celle de `DynamicEdition`, qui
/// est aussi un `ListView` : compter les `ListView` de tout l'arbre mesurerait
/// le mauvais objet.
Finder _subListView() => find.descendant(
      of: find.byType(ZSubListFieldWidget),
      matching: find.byType(ListView),
    );

/// La **table de résumé** native du mode compact (rendu par défaut).
Finder _subListTable() => find.descendant(
      of: find.byType(ZSubListFieldWidget),
      matching: find.byType(Table),
    );

/// **Chemin NOMINAL** : le champ traverse `DynamicEdition` → `ZFieldWidget` →
/// famille. AUCUN `fieldBuilder` n'est fourni — c'est tout l'enjeu.
Widget _nominal(
  ZFieldSpec field, {
  required ZFormController controller,
  ZSubListSeamRegistry? registry,
  ZAcl acl = const ZAllowAllAcl(),
}) =>
    _host(
      DynamicEdition(controller: controller, fields: <ZFieldSpec>[field]),
      registry: registry,
      acl: acl,
    );

ZFormController _controllerWith(String name, Object? value) => ZFormController(
      initialValues: <String, Object?>{name: value},
      visibleFields: <String>[name],
    );

void main() {
  // ── A. CHEMIN NOMINAL — le critère d'acceptation de la passe ───────────────
  group('A. Chemin NOMINAL (DynamicEdition sans fieldBuilder)', () {
    testWidgets(
        '🔴 PRINCIPAL : itemBuilder déclaré au registre est APPLIQUÉ sans '
        'fieldBuilder de remplacement', (tester) async {
      _useTallSurface(tester);
      final registry = ZSubListSeamRegistry()
        ..register(
          'items',
          ZSubListSeams(
            itemBuilder: (context, item) => Text('LIBRE:${item.data['f1']}'),
          ),
        );
      final controller = _controllerWith('items', _seed);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_nominal(
        _compactField,
        controller: controller,
        registry: registry,
      ));
      await tester.pump();

      expect(find.text('LIBRE:Alpha'), findsOneWidget);
      expect(find.text('LIBRE:Beta'), findsOneWidget);
      // La cellule native est bien REMPLACÉE, pas doublée.
      expect(find.text('Alpha'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '🔴 PRINCIPAL : l\'ACL du seam est atteinte par le chemin nominal et '
        'prime sur le scope', (tester) async {
      _useTallSurface(tester);
      final registry = ZSubListSeamRegistry()
        ..register('items', const ZSubListSeams(acl: ZDenyAllAcl()));
      final controller = _controllerWith('items', _seed);
      addTearDown(controller.dispose);

      // Scope PERMISSIF : si le seam n'était pas relayé, les actions
      // resteraient offertes — c'est précisément le trou historique.
      await tester.pumpWidget(_nominal(
        _compactField,
        controller: controller,
        registry: registry,
      ));
      await tester.pump();

      expect(find.byIcon(Icons.visibility), findsNothing);
      expect(find.byIcon(Icons.edit), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '🔴 PRINCIPAL : itemTitleBuilder est atteint par le chemin nominal',
        (tester) async {
      _useTallSurface(tester);
      final registry = ZSubListSeamRegistry()
        ..register(
          'items',
          ZSubListSeams(itemTitleBuilder: (item) => 'T:${item['id']}'),
        );
      const sansSummary = ZFieldSpec(
        name: 'items',
        type: EditionFieldType.subItems,
        label: 'Items',
        config: ZSubListConfig(
          itemFields: _itemFields,
          displayMode: ZSubListDisplayMode.compact,
        ),
      );
      final controller = _controllerWith('items', _seed);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_nominal(
        sansSummary,
        controller: controller,
        registry: registry,
      ));
      await tester.pump();

      // Le titre voit `id`, clé HORS sous-schéma conservée depuis la graine.
      expect(find.text('T:ID-1'), findsOneWidget);
      expect(find.text('T:ID-2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '🔴 PRINCIPAL : itemFieldsResolver (dynamicItem) est atteint par le '
        'chemin nominal', (tester) async {
      _useTallSurface(tester);
      final registry = ZSubListSeamRegistry()
        ..register(
          'item',
          ZSubListSeams(
            itemFieldsResolver: (state) => const <ZFieldSpec>[
              ZFieldSpec(name: 'f1', type: EditionFieldType.text, label: 'F1'),
            ],
          ),
        );
      final controller = _controllerWith(
        'item',
        const <String, dynamic>{'f1': 'x', 'f2': 'y'},
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_nominal(
        _dynamicField,
        controller: controller,
        registry: registry,
      ));
      await tester.pump();

      // Seul `f1` est rendu : le resolver a filtré `f2`.
      expect(find.widgetWithText(TextFormField, 'x'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'y'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  // ── B. CONTRE-TÉMOIN — structure IDENTIQUE sans seam ──────────────────────
  group('B. Contre-témoin : sans seam, la STRUCTURE est inchangée', () {
    /// Compte les widgets structurants d'une sous-liste compacte de 2 items.
    Map<String, int> structure() => <String, int>{
          // Le mode compact rend une vraie `Table` (une seule, en-têtes +
          // lignes) : c'est ELLE le conteneur natif dont on mesure l'unicité.
          'Table': _subListTable().evaluate().length,
          'ConstrainedBox': find.byType(ConstrainedBox).evaluate().length,
          'IconButton': find.byType(IconButton).evaluate().length,
          'visibility': find.byIcon(Icons.visibility).evaluate().length,
          'edit': find.byIcon(Icons.edit).evaluate().length,
          'delete': find.byIcon(Icons.delete_outline).evaluate().length,
          'add': find.byIcon(Icons.add).evaluate().length,
          'Text': find.byType(Text).evaluate().length,
        };

    testWidgets(
        '🔴 compact : aucun registre vs registre à clé étrangère ⇒ MÊME '
        'structure (compte ET types)', (tester) async {
      _useTallSurface(tester);
      final c1 = _controllerWith('items', _seed);
      addTearDown(c1.dispose);
      await tester.pumpWidget(_nominal(_compactField, controller: c1));
      await tester.pump();
      final sansCanal = structure();

      // Anti-vacuité : la mesure doit observer quelque chose.
      expect(sansCanal['Table'], 1);
      expect(sansCanal['visibility'], 2);
      expect(sansCanal['edit'], 2);
      expect(sansCanal['delete'], 2);
      // 1 bouton d'ajout + 2 lignes × 3 actions = 7, pas un de plus : c'est
      // l'assertion ABSOLUE qui fait rougir un canal qui ajouterait un contrôle
      // à tout le monde (une comparaison entre deux rendus passifs ne le
      // verrait pas — les deux bougeraient ensemble).
      expect(sansCanal['IconButton'], 7);
      expect(sansCanal['Text']! > 0, isTrue);

      final registry = ZSubListSeamRegistry()
        ..register(
          'unAutreChamp',
          ZSubListSeams(
            itemBuilder: (context, item) => const Text('NE DOIT PAS PARAÎTRE'),
            captionBuilder: (context, add) => const Text('NON PLUS'),
            itemActionsBuilder: (context, item) =>
                <Widget>[const Icon(Icons.star)],
          ),
        );
      final c2 = _controllerWith('items', _seed);
      addTearDown(c2.dispose);
      await tester.pumpWidget(_nominal(
        _compactField,
        controller: c2,
        registry: registry,
      ));
      await tester.pump();

      expect(structure(), sansCanal);
      expect(find.text('NE DOIT PAS PARAÎTRE'), findsNothing);
      expect(find.text('NON PLUS'), findsNothing);
      expect(find.byIcon(Icons.star), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('🔴 inline : aucun seam ⇒ aucun widget ajouté', (tester) async {
      _useTallSurface(tester);
      final controller = _controllerWith('items', _seed);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_nominal(_inlineField, controller: controller));
      await tester.pump();

      // Garde relevée au contrat courant : les flèches monter/descendre ont
      // été SUPPRIMÉES des deux modes (décision du propriétaire), remplacées
      // par le glisser-déposer à poignée + les actions sémantiques de
      // déplacement. Le contrôle natif restant est donc « retirer ».
      // 2 items × retirer = 2 IconButton, pas un de plus…
      expect(find.byType(IconButton), findsNWidgets(2));
      // …et l'ordre s'édite par une poignée par item (pas un `IconButton`).
      expect(find.byIcon(Icons.drag_indicator_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.arrow_upward), findsNothing);
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
      expect(find.byType(TextFormField), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    });
  });

  // ── C. AD-10 — un seam qui LÈVE ne casse jamais le rendu ───────────────────
  group('C. AD-10 : un seam qui lève retombe sur le rendu natif', () {
    Future<void> pumpCompact(
      WidgetTester tester,
      ZSubListSeams seams, {
      ZFieldSpec field = _compactField,
      String slice = 'items',
      Object? value = _seed,
    }) async {
      final registry = ZSubListSeamRegistry()..register(slice, seams);
      final controller = _controllerWith(slice, value);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _nominal(field, controller: controller, registry: registry),
      );
      await tester.pump();
    }

    testWidgets('itemBuilder qui lève → cellule native', (tester) async {
      _useTallSurface(tester);
      await pumpCompact(
        tester,
        ZSubListSeams(
          itemBuilder: (context, item) => throw StateError('boom'),
        ),
      );
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('listViewBuilder qui lève → ListView natif', (tester) async {
      _useTallSurface(tester);
      await pumpCompact(
        tester,
        ZSubListSeams(
          listViewBuilder: (context, view) => throw StateError('boom'),
        ),
      );
      expect(_subListView(), findsOneWidget);
      expect(find.text('Alpha'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('captionBuilder qui lève → en-tête natif', (tester) async {
      _useTallSurface(tester);
      await pumpCompact(
        tester,
        ZSubListSeams(
          captionBuilder: (context, add) => throw StateError('boom'),
        ),
      );
      expect(find.text('Items'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('itemActionsBuilder qui lève → actions natives intactes, '
        'aucune action ajoutée', (tester) async {
      _useTallSurface(tester);
      await pumpCompact(
        tester,
        ZSubListSeams(
          itemActionsBuilder: (context, item) => throw StateError('boom'),
        ),
      );
      expect(find.byIcon(Icons.visibility), findsNWidgets(2));
      expect(find.byIcon(Icons.edit), findsNWidgets(2));
      expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('itemTransformer qui lève → valeurs brutes', (tester) async {
      _useTallSurface(tester);
      await pumpCompact(
        tester,
        ZSubListSeams(
          itemTransformer: (context, item) => throw StateError('boom'),
        ),
      );
      expect(find.text('Alpha'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('itemFieldsResolver qui lève → tous les itemFields',
        (tester) async {
      _useTallSurface(tester);
      await pumpCompact(
        tester,
        ZSubListSeams(
          itemFieldsResolver: (state) => throw StateError('boom'),
        ),
        field: _dynamicField,
        slice: 'item',
        value: const <String, dynamic>{'f1': 'x', 'f2': 'y'},
      );
      expect(find.widgetWithText(TextFormField, 'x'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'y'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // ── D. Registre : cascade de clés, chaînage, ombrage, collision ────────────
  group('D. Registre — cascade, chaînage, ombrage', () {
    test('cascade : widgetKind > name > type.name', () {
      final registry = ZSubListSeamRegistry()
        ..register('parKind', const ZSubListSeams(acl: ZAllowAllAcl()))
        ..register('parNom', const ZSubListSeams(acl: ZDenyAllAcl()))
        ..register('subItems', const ZSubListSeams());

      const parKind = ZFieldSpec(
        name: 'parNom',
        type: EditionFieldType.subItems,
        widgetKind: 'parKind',
      );
      const parNom = ZFieldSpec(
        name: 'parNom',
        type: EditionFieldType.subItems,
      );
      const parType = ZFieldSpec(
        name: 'inconnu',
        type: EditionFieldType.subItems,
      );

      expect(registry.resolve(parKind)!.acl, isA<ZAllowAllAcl>());
      expect(registry.resolve(parNom)!.acl, isA<ZDenyAllAcl>());
      expect(registry.resolve(parType)!.acl, isNull);
    });

    test('widgetKind non enregistré → repli sur le nom (AD-10)', () {
      final registry = ZSubListSeamRegistry()
        ..register('parNom', const ZSubListSeams(acl: ZDenyAllAcl()));
      const field = ZFieldSpec(
        name: 'parNom',
        type: EditionFieldType.subItems,
        widgetKind: 'jamaisEnregistre',
      );
      expect(registry.resolve(field)!.acl, isA<ZDenyAllAcl>());
    });

    test('aucune clé connue → null, jamais un throw (AD-10)', () {
      final registry = ZSubListSeamRegistry();
      const field = ZFieldSpec(
        name: 'inconnu',
        type: EditionFieldType.subItems,
      );
      expect(registry.resolve(field), isNull);
      expect(registry.trySeamsFor('inconnu'), isNull);
    });

    test('collision LOCALE → ZDuplicateRegistrationError', () {
      final registry = ZSubListSeamRegistry()
        ..register('a', const ZSubListSeams());
      expect(
        () => registry.register('a', const ZSubListSeams()),
        throwsA(isA<ZDuplicateRegistrationError>()),
      );
    });

    test('lookup strict inconnu → ZUnregisteredTypeError', () {
      expect(
        () => ZSubListSeamRegistry().seamsFor('a'),
        throwsA(isA<ZUnregisteredTypeError>()),
      );
    });

    test('chaînage : l\'enfant hérite du parent, et l\'OMBRE', () {
      final parent = ZSubListSeamRegistry()
        ..register('herite', const ZSubListSeams(acl: ZAllowAllAcl()))
        ..register('ombre', const ZSubListSeams(acl: ZAllowAllAcl()));
      final enfant = ZSubListSeamRegistry(parent: parent)
        ..register('ombre', const ZSubListSeams(acl: ZDenyAllAcl()));

      expect(enfant.trySeamsFor('herite')!.acl, isA<ZAllowAllAcl>());
      expect(enfant.trySeamsFor('ombre')!.acl, isA<ZDenyAllAcl>());
      expect(parent.trySeamsFor('ombre')!.acl, isA<ZAllowAllAcl>());
      expect(enfant.isRegistered('herite'), isTrue);
      expect(enfant.keys.toSet(), <String>{'herite', 'ombre'});
    });

    test('chaîne VIVANTE : un enregistrement ultérieur du parent est vu',
        () {
      final parent = ZSubListSeamRegistry();
      final enfant = ZSubListSeamRegistry(parent: parent);
      expect(enfant.trySeamsFor('tard'), isNull);
      parent.register('tard', const ZSubListSeams(acl: ZDenyAllAcl()));
      expect(enfant.trySeamsFor('tard')!.acl, isA<ZDenyAllAcl>());
    });

    testWidgets('ombrage effectif au RENDU (scope dérivé)', (tester) async {
      _useTallSurface(tester);
      final parent = ZSubListSeamRegistry()
        ..register(
          'items',
          ZSubListSeams(
            itemBuilder: (context, item) => const Text('PARENT'),
          ),
        );
      final enfant = ZSubListSeamRegistry(parent: parent)
        ..register(
          'items',
          ZSubListSeams(
            itemBuilder: (context, item) => const Text('ENFANT'),
          ),
        );
      final controller = _controllerWith('items', _seed);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_nominal(
        _compactField,
        controller: controller,
        registry: enfant,
      ));
      await tester.pump();

      expect(find.text('ENFANT'), findsNWidgets(2));
      expect(find.text('PARENT'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  // ── E. Applicabilité par mode d'affichage ─────────────────────────────────
  group('E. Un seam par mode', () {
    testWidgets('compact : listViewBuilder remplace le conteneur et reçoit '
        'items + children + itemBuilder', (tester) async {
      _useTallSurface(tester);
      late int recuItems;
      late int recuChildren;
      final registry = ZSubListSeamRegistry()
        ..register(
          'items',
          ZSubListSeams(
            listViewBuilder: (context, view) {
              recuItems = view.items.length;
              recuChildren = view.children.length;
              return Column(
                key: const ValueKey<String>('conteneur-hote'),
                children: <Widget>[
                  view.itemBuilder(context, 0),
                  const Text('SÉPARATEUR'),
                  view.itemBuilder(context, 1),
                ],
              );
            },
          ),
        );
      final controller = _controllerWith('items', _seed);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_nominal(
        _compactField,
        controller: controller,
        registry: registry,
      ));
      await tester.pump();

      expect(recuItems, 2);
      expect(recuChildren, 2);
      expect(find.byKey(const ValueKey<String>('conteneur-hote')),
          findsOneWidget);
      expect(find.text('SÉPARATEUR'), findsOneWidget);
      // Le conteneur natif a bien cédé la place.
      expect(_subListView(), findsNothing);
      // Les lignes bâties par le socle restent complètes (résumé + actions).
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('compact : captionBuilder reçoit le bouton d\'ajout NATIF',
        (tester) async {
      _useTallSurface(tester);
      final registry = ZSubListSeamRegistry()
        ..register(
          'items',
          ZSubListSeams(
            captionBuilder: (context, add) => Row(
              children: <Widget>[const Text('MON EN-TÊTE'), add],
            ),
          ),
        );
      final controller = _controllerWith('items', _seed);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_nominal(
        _compactField,
        controller: controller,
        registry: registry,
      ));
      await tester.pump();

      expect(find.text('MON EN-TÊTE'), findsOneWidget);
      // Le libellé natif a cédé la place, mais le bouton natif est bien passé.
      expect(find.text('Items'), findsNothing);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '🔴 captionBuilder ne CONTOURNE PAS l\'ACL : création refusée ⇒ le '
        'seam reçoit un widget vide', (tester) async {
      _useTallSurface(tester);
      final registry = ZSubListSeamRegistry()
        ..register(
          'items',
          ZSubListSeams(
            captionBuilder: (context, add) => Row(
              children: <Widget>[const Text('MON EN-TÊTE'), add],
            ),
          ),
        );
      final controller = _controllerWith('items', _seed);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_nominal(
        _compactField,
        controller: controller,
        registry: registry,
        acl: const ZDenyAllAcl(),
      ));
      await tester.pump();

      expect(find.text('MON EN-TÊTE'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('compact : itemActionsBuilder AJOUTE aux actions natives',
        (tester) async {
      _useTallSurface(tester);
      final registry = ZSubListSeamRegistry()
        ..register(
          'items',
          ZSubListSeams(
            itemActionsBuilder: (context, item) => <Widget>[
              IconButton(
                key: ValueKey<String>('extra-${item.data['id']}'),
                icon: const Icon(Icons.star),
                onPressed: () {},
              ),
            ],
          ),
        );
      final controller = _controllerWith('items', _seed);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_nominal(
        _compactField,
        controller: controller,
        registry: registry,
      ));
      await tester.pump();

      // Les actions natives restent TOUTES là — « en plus », pas « à la place ».
      expect(find.byIcon(Icons.visibility), findsNWidgets(2));
      expect(find.byIcon(Icons.edit), findsNWidgets(2));
      expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
      expect(find.byIcon(Icons.star), findsNWidgets(2));
      expect(find.byKey(const ValueKey<String>('extra-ID-1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '🔴 en-têtes de colonnes : un conteneur hôte les EFFACE (ils ne '
        'coiffent plus rien)', (tester) async {
      _useTallSurface(tester);
      const avecEntetes = ZFieldSpec(
        name: 'items',
        type: EditionFieldType.subItems,
        label: 'Items',
        config: ZSubListConfig(
          itemFields: _itemFields,
          displayMode: ZSubListDisplayMode.compact,
          summaryFields: <String>['f1', 'f2'],
          showSummaryHeaders: true,
        ),
      );

      // Sans conteneur hôte : les en-têtes sont bien là (anti-vacuité).
      final c1 = _controllerWith('items', _seed);
      addTearDown(c1.dispose);
      await tester.pumpWidget(_nominal(avecEntetes, controller: c1));
      await tester.pump();
      expect(find.text('F1'), findsOneWidget);
      expect(find.text('F2'), findsOneWidget);

      final registry = ZSubListSeamRegistry()
        ..register(
          'items',
          ZSubListSeams(
            listViewBuilder: (context, view) =>
                Column(children: view.children),
          ),
        );
      final c2 = _controllerWith('items', _seed);
      addTearDown(c2.dispose);
      await tester.pumpWidget(
        _nominal(avecEntetes, controller: c2, registry: registry),
      );
      await tester.pump();
      expect(find.text('F1'), findsNothing);
      expect(find.text('F2'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '🔴 les actions AJOUTÉES entrent dans le calcul de repli du résumé '
        '(elles prennent la largeur aux colonnes)', (tester) async {
      tester.view.physicalSize = const Size(540, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      const avecEntetes = ZFieldSpec(
        name: 'items',
        type: EditionFieldType.subItems,
        label: 'Items',
        config: ZSubListConfig(
          itemFields: _itemFields,
          displayMode: ZSubListDisplayMode.compact,
          summaryFields: <String>['f1', 'f2'],
          showSummaryHeaders: true,
        ),
      );

      // Sans action ajoutée : la table tient, les en-têtes sont rendus.
      final c1 = _controllerWith('items', _seed);
      addTearDown(c1.dispose);
      await tester.pumpWidget(_nominal(avecEntetes, controller: c1));
      await tester.pump();
      expect(find.text('F1'), findsOneWidget,
          reason: 'anti-vacuité : la table doit tenir à cette largeur');

      // Deux actions ajoutées de plus : la place manque, la ligne s'empile et
      // la ligne d'en-têtes s'efface. Le libellé descend DANS la ligne — il y
      // en a donc un par item, plus aucun en-tête unique.
      final registry = ZSubListSeamRegistry()
        ..register(
          'items',
          ZSubListSeams(
            itemActionsBuilder: (context, item) => <Widget>[
              const SizedBox(width: 8, height: 8),
              const SizedBox(width: 8, height: 8),
            ],
          ),
        );
      final c2 = _controllerWith('items', _seed);
      addTearDown(c2.dispose);
      await tester.pumpWidget(
        _nominal(avecEntetes, controller: c2, registry: registry),
      );
      await tester.pump();
      expect(find.text('F1'), findsNWidgets(2),
          reason: 'empilé : un libellé F1 par ligne, plus d\'en-tête unique');
      expect(tester.takeException(), isNull);
    });

    testWidgets('tags : captionBuilder + transformateur sur le libellé de puce',
        (tester) async {
      _useTallSurface(tester);
      final registry = ZSubListSeamRegistry()
        ..register(
          'items',
          ZSubListSeams(
            captionBuilder: (context, add) =>
                Row(children: <Widget>[const Text('TAGS'), add]),
            itemTransformer: (context, item) => <String, dynamic>{
              ...item,
              'f1': '«${item['f1']}»',
            },
          ),
        );
      final controller = _controllerWith('items', _seed);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_nominal(
        _tagsField,
        controller: controller,
        registry: registry,
      ));
      await tester.pump();

      expect(find.text('TAGS'), findsOneWidget);
      expect(find.text('«Alpha»'), findsOneWidget);
      expect(find.text('«Beta»'), findsOneWidget);
      expect(find.text('Alpha'), findsNothing);
      expect(find.byType(InputChip), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('inline : itemActionsBuilder s\'ajoute, itemBuilder et '
        'listViewBuilder sont IGNORÉS', (tester) async {
      _useTallSurface(tester);
      final registry = ZSubListSeamRegistry()
        ..register(
          'items',
          ZSubListSeams(
            itemBuilder: (context, item) => const Text('IGNORÉ'),
            listViewBuilder: (context, view) => const Text('IGNORÉ AUSSI'),
            captionBuilder: (context, add) => const Text('IGNORÉ ENCORE'),
            itemActionsBuilder: (context, item) => <Widget>[
              IconButton(
                icon: const Icon(Icons.star),
                onPressed: () {},
              ),
            ],
          ),
        );
      final controller = _controllerWith('items', _seed);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_nominal(
        _inlineField,
        controller: controller,
        registry: registry,
      ));
      await tester.pump();

      expect(find.text('IGNORÉ'), findsNothing);
      expect(find.text('IGNORÉ AUSSI'), findsNothing);
      expect(find.text('IGNORÉ ENCORE'), findsNothing);
      // Les sous-champs éditables restent intacts…
      expect(find.byType(TextFormField), findsNWidgets(4));
      // …et les contrôles natifs + les 2 actions ajoutées. Compte relevé au
      // contrat courant : les flèches d'ordre ont été supprimées (décision du
      // propriétaire — remplacées par poignée + actions sémantiques), le
      // natif se réduit donc à « retirer » par item.
      expect(find.byIcon(Icons.star), findsNWidgets(2));
      expect(find.byType(IconButton), findsNWidgets(4));
      // Ce que le seam N'A PAS déplacé : la poignée d'ordre reste native, et
      // les actions de l'hôte s'ajoutent APRÈS elle.
      expect(find.byIcon(Icons.drag_indicator_rounded), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('dynamicItem : itemActionsBuilder s\'ajoute après « effacer »',
        (tester) async {
      _useTallSurface(tester);
      final registry = ZSubListSeamRegistry()
        ..register(
          'item',
          ZSubListSeams(
            itemActionsBuilder: (context, item) => <Widget>[
              IconButton(
                key: ValueKey<String>('extra-${item.data['id']}'),
                icon: const Icon(Icons.star),
                onPressed: () {},
              ),
            ],
          ),
        );
      final controller = _controllerWith(
        'item',
        const <String, dynamic>{'id': 'ID-9', 'f1': 'x', 'f2': 'y'},
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_nominal(
        _dynamicField,
        controller: controller,
        registry: registry,
      ));
      await tester.pump();

      expect(find.byIcon(Icons.clear), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('extra-ID-9')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // ── F. Transformateur : AFFICHAGE seulement ───────────────────────────────
  group('F. itemTransformer — habillage, jamais donnée', () {
    testWidgets(
        '🔴 le résumé est transformé mais l\'agrégation parente reste BRUTE',
        (tester) async {
      _useTallSurface(tester);
      final registry = ZSubListSeamRegistry()
        ..register(
          'items',
          ZSubListSeams(
            itemTransformer: (context, item) => <String, dynamic>{
              ...item,
              'f1': 'VU:${item['f1']}',
            },
          ),
        );
      final controller = _controllerWith('items', _seed);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_nominal(
        _compactField,
        controller: controller,
        registry: registry,
      ));
      await tester.pump();

      expect(find.text('VU:Alpha'), findsOneWidget);
      expect(find.text('Alpha'), findsNothing);

      // La tranche parente n'a pas bougé : le transformateur n'écrit rien.
      final aggregated = controller.valueOf('items') as List<dynamic>;
      expect(aggregated.length, 2);
      expect((aggregated.first as Map)['f1'], 'Alpha');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '🔴 itemTitleBuilder reçoit la donnée BRUTE, jamais la transformée',
        (tester) async {
      _useTallSurface(tester);
      const sansSummary = ZFieldSpec(
        name: 'items',
        type: EditionFieldType.subItems,
        label: 'Items',
        config: ZSubListConfig(
          itemFields: _itemFields,
          displayMode: ZSubListDisplayMode.compact,
        ),
      );
      final registry = ZSubListSeamRegistry()
        ..register(
          'items',
          ZSubListSeams(
            itemTitleBuilder: (item) => 'TITRE:${item['f1']}',
            itemTransformer: (context, item) => <String, dynamic>{
              ...item,
              'f1': 'HABILLÉ',
            },
          ),
        );
      final controller = _controllerWith('items', _seed);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_nominal(
        sansSummary,
        controller: controller,
        registry: registry,
      ));
      await tester.pump();

      expect(find.text('TITRE:Alpha'), findsOneWidget);
      expect(find.text('TITRE:HABILLÉ'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  // ── G. a11y (invariant AD-13) ─────────────────────────────────────────────
  group('G. a11y', () {
    testWidgets('🔴 une action ajoutée est contrainte à ≥ 48 dp même si '
        'l\'hôte en fournit une minuscule', (tester) async {
      _useTallSurface(tester);
      final registry = ZSubListSeamRegistry()
        ..register(
          'items',
          ZSubListSeams(
            itemActionsBuilder: (context, item) => <Widget>[
              const SizedBox(
                key: ValueKey<String>('minuscule'),
                width: 8,
                height: 8,
              ),
            ],
          ),
        );
      final controller = _controllerWith('items', _seed);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_nominal(
        _compactField,
        controller: controller,
        registry: registry,
      ));
      await tester.pump();

      final size =
          tester.getSize(find.byKey(const ValueKey<String>('minuscule')).first);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    });

    testWidgets('un rendu libre reste ANNONCÉ (sémantique préservée)',
        (tester) async {
      _useTallSurface(tester);
      final handle = tester.ensureSemantics();
      final registry = ZSubListSeamRegistry()
        ..register(
          'items',
          ZSubListSeams(
            itemBuilder: (context, item) => Semantics(
              label: 'Ligne ${item.data['f1']}',
              child: const SizedBox(width: 40, height: 40),
            ),
          ),
        );
      final controller = _controllerWith('items', _seed);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_nominal(
        _compactField,
        controller: controller,
        registry: registry,
      ));
      await tester.pump();

      expect(find.bySemanticsLabel('Ligne Alpha'), findsOneWidget);
      expect(find.bySemanticsLabel('Ligne Beta'), findsOneWidget);
      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    testWidgets('RTL : un rendu libre + actions ajoutées ne débordent pas',
        (tester) async {
      _useTallSurface(tester);
      final registry = ZSubListSeamRegistry()
        ..register(
          'items',
          ZSubListSeams(
            itemBuilder: (context, item) => Text('L:${item.data['f1']}'),
            itemActionsBuilder: (context, item) => <Widget>[
              IconButton(icon: const Icon(Icons.star), onPressed: () {}),
            ],
          ),
        );
      final controller = _controllerWith('items', _seed);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(
        DynamicEdition(
          controller: controller,
          fields: const <ZFieldSpec>[_compactField],
        ),
        registry: registry,
        dir: TextDirection.rtl,
      ));
      await tester.pump();

      expect(find.text('L:Alpha'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
