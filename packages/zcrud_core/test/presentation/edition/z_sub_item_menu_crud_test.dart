// **Menu d'option par item** (`ZSubItemMenuOption`) et **crochet CRUD**
// (`ZSubItemCrudHook`) des sous-listes `subItems`, portés par le canal de seams
// (`ZSubListSeamRegistry`).
//
// 🔴 MOTIF — le moteur legacy portait `onCrud(item, crud, {option})` et un
// `DynamicSubItemMenuOption` dont le prédicat `filter(item)` n'était **jamais
// invoqué** (grep négatif sur `dodlp-otr` et `iffd`), dont le libellé était
// **codé en dur**, et qui prétendait se **sérialiser** avec sa closure. Le port
// rend le prédicat vivant, le libellé localisable, et ne porte aucune
// (dé)sérialisation. Reste à prouver que ce qui est vivant l'est **par le
// chemin nominal** et que rien de tout cela n'ouvre un droit.
//
// 🔴 LA GARDE PRINCIPALE (groupe A) : une option déclarée au registre est
// **rendue et cliquable** depuis `DynamicEdition` SANS `fieldBuilder` de
// remplacement. Une garde qui construirait `ZSubListFieldWidget` à la main
// passerait sans observer le relais — c'est exactement ainsi que les seams de
// la passe 1 étaient restés inatteignables.
//
// 🔴 LA GARDE ADVERSARIALE (groupe C) : une option **permissive** ne peut pas
// élargir un droit refusé par l'ACL, et son prédicat n'est même pas **consulté**
// dans ce cas (compteur asserté à zéro) — sans quoi un filtrage fusionné en
// `||` resterait vert.
//
// 🔴 LE CONTRE-TÉMOIN (groupe F) assère des **comptes ABSOLUS** de widgets, pas
// une comparaison entre deux rendus passifs : un canal qui ajouterait un nœud à
// TOUT LE MONDE ferait bouger les deux mesures ensemble et resterait invisible.
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

const _compactReadOnlyField = ZFieldSpec(
  name: 'items',
  type: EditionFieldType.subItems,
  label: 'Items',
  readOnly: true,
  config: ZSubListConfig(
    itemFields: _itemFields,
    displayMode: ZSubListDisplayMode.compact,
    summaryFields: <String>['f1'],
  ),
);

const _seed = <Map<String, dynamic>>[
  <String, dynamic>{'id': 'ID-1', 'f1': 'Alpha', 'f2': 'a'},
  <String, dynamic>{'id': 'ID-2', 'f1': 'Beta', 'f2': 'b'},
];

/// ACL **sélective** — le seul moyen de prouver que la porte est ouverte par
/// action, et non par un blanc-seing.
class _AclFor implements ZAcl {
  const _AclFor(this.allowed);
  final Set<ZCrudAction> allowed;
  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) =>
      allowed.contains(action);
}

/// Surface haute : `DynamicEdition` monte ses champs par `ListView.builder`
/// (montage PARESSEUX). Sans elle, la sous-liste testée peut n'être jamais
/// montée — la garde serait alors verte pour la mauvaise raison.
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// **Chemin NOMINAL** : le champ traverse `DynamicEdition` → `ZFieldWidget` →
/// famille. AUCUN `fieldBuilder` — c'est tout l'enjeu.
Widget _nominal(
  ZFieldSpec field, {
  required ZFormController controller,
  ZSubListSeamRegistry? registry,
  ZAcl acl = const ZAllowAllAcl(),
}) =>
    MaterialApp(
      home: ZcrudScope(
        acl: acl,
        subListSeamRegistry: registry,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Scaffold(
            body: DynamicEdition(
              controller: controller,
              fields: <ZFieldSpec>[field],
            ),
          ),
        ),
      ),
    );

ZFormController _controllerWith(Object? value) => ZFormController(
      initialValues: <String, Object?>{'items': value},
      visibleFields: const <String>['items'],
    );

/// La valeur **AGRÉGÉE** dans la tranche parente — la donnée, pas le rendu.
/// C'est sur elle que se jugent véto et remplacement.
List<Map<String, dynamic>> _aggregated(ZFormController c) {
  final raw = c.valueOf('items');
  if (raw is! List) return const <Map<String, dynamic>>[];
  return <Map<String, dynamic>>[
    for (final e in raw)
      if (e is Map) Map<String, dynamic>.from(e),
  ];
}

ZSubListSeamRegistry _registry({
  List<ZSubItemMenuOption> options = const <ZSubItemMenuOption>[],
  ZSubItemCrudHook? onCrud,
  String key = 'items',
}) =>
    ZSubListSeamRegistry()
      ..register(key, ZSubListSeams(itemMenuOptions: options, onCrud: onCrud));

void main() {
  // ── A. CHEMIN NOMINAL — le critère d'acceptation de la passe ───────────────
  group('A. Chemin NOMINAL (DynamicEdition sans fieldBuilder)', () {
    testWidgets(
        '🔴 PRINCIPAL : une option déclarée au registre est RENDUE et '
        'CLIQUABLE, et son choix atteint le crochet', (tester) async {
      _useTallSurface(tester);
      final vues = <ZSubItemCrudRequest>[];
      final registry = _registry(
        options: <ZSubItemMenuOption>[
          const ZSubItemMenuOption(
            id: 'dupliquer',
            labelKey: 'zz.dupliquer',
            labelFallback: 'Dupliquer',
            icon: Icons.copy,
            payload: <String, Object?>{'mode': 'plein'},
          ),
        ],
        onCrud: (request) async {
          vues.add(request);
          return ZSubItemCrudOutcome.replace(<String, dynamic>{
            ...request.data,
            'f1': 'PATCHÉ',
          });
        },
      );
      final controller = _controllerWith(_seed);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _nominal(_compactField, controller: controller, registry: registry),
      );
      await tester.pump();

      // RENDUE : un déclencheur par ligne, pas un de plus.
      expect(find.byIcon(Icons.more_vert), findsNWidgets(2));

      // CLIQUABLE : le menu s'ouvre, l'entrée porte son libellé de repli.
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      expect(find.text('Dupliquer'), findsOneWidget);
      expect(find.byIcon(Icons.copy), findsOneWidget);

      await tester.tap(find.text('Dupliquer'));
      await tester.pumpAndSettle();

      // Le crochet a reçu l'option, sa charge utile et l'item visé.
      expect(vues, hasLength(1));
      expect(vues.single.option?.id, 'dupliquer');
      expect(vues.single.option?.payload['mode'], 'plein');
      expect(vues.single.action, ZCrudAction.update);
      expect(vues.single.item?.index, 0);
      expect(vues.single.data['id'], 'ID-1');
      expect(vues.single.data['f1'], 'Alpha');

      // Et le remplacement a atteint la DONNÉE agrégée, pas le seul rendu.
      final agrege = _aggregated(controller);
      expect(agrege, hasLength(2));
      expect(agrege[0]['f1'], 'PATCHÉ');
      expect(agrege[0]['id'], 'ID-1', reason: 'résidu hors schéma préservé');
      expect(agrege[1]['f1'], 'Beta', reason: 'voisin intact');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'le crochet arbitre AUSSI les actions natives (create/update/delete)',
        (tester) async {
      _useTallSurface(tester);
      final actions = <ZCrudAction>[];
      final registry = _registry(
        onCrud: (request) async {
          actions.add(request.action);
          return const ZSubItemCrudOutcome.proceed();
        },
      );
      final controller = _controllerWith(_seed);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _nominal(_compactField, controller: controller, registry: registry),
      );
      await tester.pump();

      // create
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).at(0), 'Gamma');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // update
      await tester.tap(find.byIcon(Icons.edit).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // delete
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(actions, <ZCrudAction>[
        ZCrudAction.create,
        ZCrudAction.update,
        ZCrudAction.delete,
      ]);
      // `proceed` = comportement natif : l'ajout a eu lieu, la suppression aussi.
      final agrege = _aggregated(controller);
      expect(agrege.map((e) => e['f1']), <String>['Beta', 'Gamma']);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'création : `replace` conserve les clés HORS sous-schéma — un hôte peut '
        'attribuer un id', (tester) async {
      _useTallSurface(tester);
      final registry = _registry(
        onCrud: (request) async => ZSubItemCrudOutcome.replace(
          <String, dynamic>{...request.data, 'id': 'FORGÉ-7'},
        ),
      );
      final controller = _controllerWith(null);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _nominal(_compactField, controller: controller, registry: registry),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).at(0), 'Neuf');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final agrege = _aggregated(controller);
      expect(agrege, hasLength(1));
      expect(agrege.single['id'], 'FORGÉ-7');
      expect(agrege.single['f1'], 'Neuf');
      expect(tester.takeException(), isNull);
    });
  });

  // ── B. Le prédicat filtre PAR ITEM ─────────────────────────────────────────
  group('B. Prédicat de visibilité par item', () {
    testWidgets('🔴 deux items, une option visible sur UN SEUL', (tester) async {
      _useTallSurface(tester);
      final registry = _registry(
        options: <ZSubItemMenuOption>[
          ZSubItemMenuOption(
            id: 'seulAlpha',
            labelKey: 'zz.seulAlpha',
            labelFallback: 'Seul Alpha',
            isVisible: (item) => item.data['f1'] == 'Alpha',
          ),
        ],
        onCrud: (request) async => const ZSubItemCrudOutcome.proceed(),
      );
      final controller = _controllerWith(_seed);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _nominal(_compactField, controller: controller, registry: registry),
      );
      await tester.pump();

      // UN seul déclencheur : la ligne « Beta » n'en porte pas.
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      // Et c'est bien la ligne d'Alpha : le déclencheur est keyé sur l'item.
      expect(
        find.byKey(const ValueKey<String>('itemMenu_item_0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('itemMenu_item_1')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('un prédicat qui LÈVE masque l\'option (AD-10, repli fermant)',
        (tester) async {
      _useTallSurface(tester);
      final registry = _registry(
        options: <ZSubItemMenuOption>[
          ZSubItemMenuOption(
            id: 'boom',
            labelKey: 'zz.boom',
            labelFallback: 'Boum',
            isVisible: (item) => throw StateError('prédicat cassé'),
          ),
        ],
        onCrud: (request) async => const ZSubItemCrudOutcome.proceed(),
      );
      final controller = _controllerWith(_seed);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _nominal(_compactField, controller: controller, registry: registry),
      );
      await tester.pump();

      expect(find.byIcon(Icons.more_vert), findsNothing);
      // Le reste de la ligne est intact : 1 add + 2 × (voir/modifier/supprimer).
      expect(find.byType(IconButton), findsNWidgets(7));
      expect(tester.takeException(), isNull);
    });
  });

  // ── C. ADVERSARIALE : une option n'élargit JAMAIS un droit ─────────────────
  group('C. Adversariale — ACL d\'abord, prédicat ensuite', () {
    testWidgets(
        '🔴 une option PERMISSIVE ne s\'affiche pas quand l\'ACL refuse — et '
        'son prédicat n\'est même pas CONSULTÉ', (tester) async {
      _useTallSurface(tester);
      var predicatAppele = 0;
      final registry = _registry(
        options: <ZSubItemMenuOption>[
          ZSubItemMenuOption(
            id: 'permissive',
            labelKey: 'zz.permissive',
            labelFallback: 'Toujours visible',
            // Le prédicat le plus permissif possible.
            isVisible: (item) {
              predicatAppele++;
              return true;
            },
          ),
        ],
        onCrud: (request) async => const ZSubItemCrudOutcome.proceed(),
      );
      final controller = _controllerWith(_seed);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_nominal(
        _compactField,
        controller: controller,
        registry: registry,
        // Lecture autorisée, écriture refusée : l'option exige `update`.
        acl: const _AclFor(<ZCrudAction>{ZCrudAction.view}),
      ));
      await tester.pump();

      expect(find.byIcon(Icons.more_vert), findsNothing);
      expect(find.text('Toujours visible'), findsNothing);
      // 🔴 Le cœur de la garde : l'ACL a tranché AVANT, pas « en plus ». Un
      // filtrage fusionné (`acl || predicat`) laisserait ce compteur à 2.
      expect(predicatAppele, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'le droit exigé est celui de l\'option : `view` passe là où `update` '
        'est refusé', (tester) async {
      _useTallSurface(tester);
      final registry = _registry(
        options: <ZSubItemMenuOption>[
          const ZSubItemMenuOption(
            id: 'historique',
            labelKey: 'zz.historique',
            labelFallback: 'Historique',
            permission: ZCrudAction.view,
          ),
          const ZSubItemMenuOption(
            id: 'renommer',
            labelKey: 'zz.renommer',
            labelFallback: 'Renommer',
          ),
        ],
        onCrud: (request) async => const ZSubItemCrudOutcome.proceed(),
      );
      final controller = _controllerWith(_seed);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_nominal(
        _compactField,
        controller: controller,
        registry: registry,
        acl: const _AclFor(<ZCrudAction>{ZCrudAction.view}),
      ));
      await tester.pump();

      expect(find.byIcon(Icons.more_vert), findsNWidgets(2));
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      expect(find.text('Historique'), findsOneWidget);
      // L'option sans `permission` retombe sur `update` : refusée.
      expect(find.text('Renommer'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'une option DESTRUCTIVE exige `delete` par défaut (jamais `update`)',
        (tester) async {
      _useTallSurface(tester);
      final registry = _registry(
        options: <ZSubItemMenuOption>[
          const ZSubItemMenuOption(
            id: 'purger',
            labelKey: 'zz.purger',
            labelFallback: 'Purger',
            destructive: true,
          ),
        ],
        onCrud: (request) async => const ZSubItemCrudOutcome.proceed(),
      );
      final controller = _controllerWith(_seed);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_nominal(
        _compactField,
        controller: controller,
        registry: registry,
        // `update` autorisé, `delete` refusé : une option destructive ne doit
        // PAS se glisser par la porte de l'écriture ordinaire.
        acl: const _AclFor(<ZCrudAction>{ZCrudAction.view, ZCrudAction.update}),
      ));
      await tester.pump();

      expect(find.byIcon(Icons.more_vert), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'champ en LECTURE SEULE : une option écrivante est masquée même sous '
        'une ACL permissive', (tester) async {
      _useTallSurface(tester);
      final registry = _registry(
        options: <ZSubItemMenuOption>[
          const ZSubItemMenuOption(
            id: 'renommer',
            labelKey: 'zz.renommer',
            labelFallback: 'Renommer',
          ),
        ],
        onCrud: (request) async => const ZSubItemCrudOutcome.proceed(),
      );
      final controller = _controllerWith(_seed);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_nominal(
        _compactReadOnlyField,
        controller: controller,
        registry: registry,
      ));
      await tester.pump();

      expect(find.byIcon(Icons.more_vert), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  // ── D. Le VÉTO empêche réellement la mutation (assertion sur la DONNÉE) ────
  group('D. Véto — assertion sur la donnée agrégée', () {
    testWidgets('🔴 véto sur `delete` : l\'item RESTE dans l\'agrégat',
        (tester) async {
      _useTallSurface(tester);
      final registry = _registry(
        onCrud: (request) async => request.action == ZCrudAction.delete
            ? const ZSubItemCrudOutcome.veto()
            : const ZSubItemCrudOutcome.proceed(),
      );
      final controller = _controllerWith(_seed);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _nominal(_compactField, controller: controller, registry: registry),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // La DONNÉE, pas le rendu : la tranche parente porte toujours deux items.
      final agrege = _aggregated(controller);
      expect(agrege, hasLength(2));
      expect(agrege.map((e) => e['f1']), <String>['Alpha', 'Beta']);
      // Le rendu suit, évidemment.
      expect(find.text('Alpha'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('véto sur `create` : rien n\'est ajouté à l\'agrégat',
        (tester) async {
      _useTallSurface(tester);
      final registry = _registry(
        onCrud: (request) async => const ZSubItemCrudOutcome.veto(),
      );
      final controller = _controllerWith(_seed);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _nominal(_compactField, controller: controller, registry: registry),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).at(0), 'Refusé');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(_aggregated(controller), hasLength(2));
      expect(find.text('Refusé'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('véto sur `update` : la saisie du dialogue n\'est PAS écrite',
        (tester) async {
      _useTallSurface(tester);
      final registry = _registry(
        onCrud: (request) async => const ZSubItemCrudOutcome.veto(),
      );
      final controller = _controllerWith(_seed);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _nominal(_compactField, controller: controller, registry: registry),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.edit).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).at(0), 'Interdit');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final agrege = _aggregated(controller);
      expect(agrege[0]['f1'], 'Alpha');
      expect(find.text('Interdit'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  // ── E. AD-10 : un crochet qui LÈVE ────────────────────────────────────────
  group('E. Un crochet qui lève ne casse pas le rendu et n\'est PAS avalé', () {
    testWidgets(
        '🔴 le rendu survit, la mutation est REFUSÉE, l\'erreur est SIGNALÉE',
        (tester) async {
      _useTallSurface(tester);
      final registry = _registry(
        onCrud: (request) async => throw StateError('crochet cassé'),
      );
      final controller = _controllerWith(_seed);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _nominal(_compactField, controller: controller, registry: registry),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // 1. Le rendu est intact (invariant AD-10) : la sous-liste vit toujours.
      expect(find.byType(ZSubListFieldWidget), findsOneWidget);
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.byType(IconButton), findsNWidgets(7));

      // 2. La mutation est refusée — sur la DONNÉE, pas sur le rendu.
      expect(_aggregated(controller), hasLength(2));

      // 3. 🔴 L'erreur n'est PAS avalée : elle est partie à
      // `FlutterError.reportError`, donc `takeException` la rend ici. Un `catch`
      // muet dans le socle laisserait ce `takeException` à `null`.
      final signalee = tester.takeException();
      expect(signalee, isA<StateError>());
      expect((signalee as StateError).message, 'crochet cassé');
    });

    testWidgets('un crochet qui lève sur une OPTION refuse aussi la mutation',
        (tester) async {
      _useTallSurface(tester);
      final registry = _registry(
        options: <ZSubItemMenuOption>[
          const ZSubItemMenuOption(
            id: 'casse',
            labelKey: 'zz.casse',
            labelFallback: 'Casse',
          ),
        ],
        onCrud: (request) async => throw StateError('option cassée'),
      );
      final controller = _controllerWith(_seed);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _nominal(_compactField, controller: controller, registry: registry),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Casse'));
      await tester.pumpAndSettle();

      expect(_aggregated(controller), hasLength(2));
      expect(_aggregated(controller)[0]['f1'], 'Alpha');
      expect(find.byIcon(Icons.more_vert), findsNWidgets(2));
      expect(tester.takeException(), isA<StateError>());
    });
  });

  // ── F. CONTRE-TÉMOIN : comptes ABSOLUS de widgets ─────────────────────────
  group('F. Contre-témoin : rien de déclaré ⇒ rendu identique', () {
    /// Comptes **absolus** des widgets structurants d'une sous-liste compacte
    /// de 2 items. Comparer deux rendus passifs ne suffirait pas : un canal qui
    /// ajouterait un nœud à TOUT LE MONDE ferait bouger les deux mesures
    /// ensemble.
    Map<String, int> structure() => <String, int>{
          'IconButton': find.byType(IconButton).evaluate().length,
          'PopupMenuButton':
              find.byType(PopupMenuButton<ZSubItemMenuOption>).evaluate().length,
          'more_vert': find.byIcon(Icons.more_vert).evaluate().length,
          'ConstrainedBox': find.byType(ConstrainedBox).evaluate().length,
          'Text': find.byType(Text).evaluate().length,
        };

    testWidgets(
        '🔴 aucun registre : comptes absolus (7 IconButton, 0 menu) — et un '
        'registre à clé ÉTRANGÈRE ne les bouge pas', (tester) async {
      _useTallSurface(tester);
      final c1 = _controllerWith(_seed);
      addTearDown(c1.dispose);
      await tester.pumpWidget(_nominal(_compactField, controller: c1));
      await tester.pump();
      final sansCanal = structure();

      // Anti-vacuité + assertion ABSOLUE : 1 bouton d'ajout + 2 lignes × 3
      // actions natives = 7, pas un de plus, et AUCUN menu de débordement.
      expect(sansCanal['IconButton'], 7);
      expect(sansCanal['more_vert'], 0);
      expect(sansCanal['PopupMenuButton'], 0);
      expect(sansCanal['Text']! > 0, isTrue);

      final registry = _registry(
        key: 'unAutreChamp',
        options: <ZSubItemMenuOption>[
          const ZSubItemMenuOption(
            id: 'fantome',
            labelKey: 'zz.fantome',
            labelFallback: 'NE DOIT PAS PARAÎTRE',
          ),
        ],
        onCrud: (request) async => const ZSubItemCrudOutcome.proceed(),
      );
      final c2 = _controllerWith(_seed);
      addTearDown(c2.dispose);
      await tester.pumpWidget(
        _nominal(_compactField, controller: c2, registry: registry),
      );
      await tester.pump();

      expect(structure(), sansCanal);
      expect(find.text('NE DOIT PAS PARAÎTRE'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'un crochet SEUL (sans option) n\'ajoute aucun widget — il n\'agit '
        'qu\'au moment d\'une mutation', (tester) async {
      _useTallSurface(tester);
      final registry = _registry(
        onCrud: (request) async => const ZSubItemCrudOutcome.proceed(),
      );
      final controller = _controllerWith(_seed);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _nominal(_compactField, controller: controller, registry: registry),
      );
      await tester.pump();

      expect(find.byType(IconButton), findsNWidgets(7));
      expect(find.byIcon(Icons.more_vert), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'toutes les options masquées par leurs prédicats ⇒ AUCUN déclencheur '
        '(jamais un menu vide)', (tester) async {
      _useTallSurface(tester);
      final registry = _registry(
        options: <ZSubItemMenuOption>[
          ZSubItemMenuOption(
            id: 'jamais',
            labelKey: 'zz.jamais',
            labelFallback: 'Jamais',
            isVisible: (item) => false,
          ),
        ],
        onCrud: (request) async => const ZSubItemCrudOutcome.proceed(),
      );
      final controller = _controllerWith(_seed);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _nominal(_compactField, controller: controller, registry: registry),
      );
      await tester.pump();

      expect(find.byIcon(Icons.more_vert), findsNothing);
      expect(find.byType(IconButton), findsNWidgets(7));
      expect(tester.takeException(), isNull);
    });
  });

  // ── H. Applicabilité par mode + erreur de configuration ───────────────────
  group('H. Applicabilité par mode', () {
    testWidgets(
        'mode `tags` : le crochet arbitre AUSSI, et son véto retient l\'item',
        (tester) async {
      _useTallSurface(tester);
      final actions = <ZCrudAction>[];
      final registry = _registry(
        onCrud: (request) async {
          actions.add(request.action);
          return const ZSubItemCrudOutcome.veto();
        },
      );
      final controller = _controllerWith(_seed);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_nominal(
        const ZFieldSpec(
          name: 'items',
          type: EditionFieldType.subItems,
          label: 'Items',
          config: ZSubListConfig(
            itemFields: _itemFields,
            displayMode: ZSubListDisplayMode.tags,
            summaryFields: <String>['f1'],
          ),
        ),
        controller: controller,
        registry: registry,
      ));
      await tester.pump();

      expect(find.byType(InputChip), findsNWidgets(2));
      // Retire la 1re puce → confirmation → le crochet refuse.
      await tester.tap(find.byTooltip('Remove item').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(actions, <ZCrudAction>[ZCrudAction.delete]);
      expect(_aggregated(controller), hasLength(2));
      expect(find.byType(InputChip), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'des options SANS crochet sont une erreur de configuration SIGNALÉE — '
        'jamais une affordance inerte', (tester) async {
      _useTallSurface(tester);
      final registry = ZSubListSeamRegistry()
        ..register(
          'items',
          const ZSubListSeams(
            itemMenuOptions: <ZSubItemMenuOption>[
              ZSubItemMenuOption(
                id: 'orpheline',
                labelKey: 'zz.orpheline',
                labelFallback: 'Orpheline',
              ),
            ],
          ),
        );
      final controller = _controllerWith(_seed);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _nominal(_compactField, controller: controller, registry: registry),
      );
      await tester.pump();

      // L'assertion de configuration a parlé (debug/test) : elle n'est pas
      // silencieuse. Et rien d'inerte n'est rendu.
      expect(tester.takeException(), isAssertionError);
      expect(find.byIcon(Icons.more_vert), findsNothing);
      expect(find.text('Orpheline'), findsNothing);
    });
  });

  // ── G. a11y (invariant AD-13) ─────────────────────────────────────────────
  group('G. a11y — cible ≥ 48 dp et annonce', () {
    testWidgets(
        '🔴 le déclencheur de menu fait ≥ 48 dp et porte un nom accessible '
        'localisé', (tester) async {
      _useTallSurface(tester);
      final registry = _registry(
        options: <ZSubItemMenuOption>[
          const ZSubItemMenuOption(
            id: 'act',
            labelKey: 'zz.act',
            labelFallback: 'Agir',
          ),
        ],
        onCrud: (request) async => const ZSubItemCrudOutcome.proceed(),
      );
      final controller = _controllerWith(_seed);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _nominal(_compactField, controller: controller, registry: registry),
      );
      await tester.pump();

      final trigger = find.byKey(const ValueKey<String>('itemMenu_item_0'));
      expect(trigger, findsOneWidget);
      final size = tester.getSize(trigger);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));

      // Nom accessible : la clé l10n `moreActions` déjà servie par le socle
      // (jamais un libellé codé en dur).
      final button = tester.widget<PopupMenuButton<ZSubItemMenuOption>>(trigger);
      expect(button.tooltip, 'More actions');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'le menu s\'ajoute APRÈS les actions natives et après '
        '`itemActionsBuilder` — aucune affordance perdue ni doublée',
        (tester) async {
      _useTallSurface(tester);
      final registry = ZSubListSeamRegistry()
        ..register(
          'items',
          ZSubListSeams(
            itemActionsBuilder: (context, item) =>
                <Widget>[const Icon(Icons.star)],
            itemMenuOptions: const <ZSubItemMenuOption>[
              ZSubItemMenuOption(
                id: 'act',
                labelKey: 'zz.act',
                labelFallback: 'Agir',
              ),
            ],
            onCrud: (request) async => const ZSubItemCrudOutcome.proceed(),
          ),
        );
      final controller = _controllerWith(_seed);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _nominal(_compactField, controller: controller, registry: registry),
      );
      await tester.pump();

      // Les trois canaux coexistent : natif (3/ligne), ajouté (1/ligne), menu
      // (1/ligne). Rien n'a disparu.
      expect(find.byIcon(Icons.visibility), findsNWidgets(2));
      expect(find.byIcon(Icons.edit), findsNWidgets(2));
      expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
      expect(find.byIcon(Icons.star), findsNWidgets(2));
      expect(find.byIcon(Icons.more_vert), findsNWidgets(2));

      // ORDRE : sur la 1re ligne, l'étoile précède le menu (repère horizontal —
      // `Directionality.ltr`), et le menu ferme la marche.
      final xEtoile = tester.getCenter(find.byIcon(Icons.star).first).dx;
      final xMenu = tester.getCenter(find.byIcon(Icons.more_vert).first).dx;
      final xSuppr =
          tester.getCenter(find.byIcon(Icons.delete_outline).first).dx;
      expect(xSuppr, lessThan(xEtoile));
      expect(xEtoile, lessThan(xMenu));
      expect(tester.takeException(), isNull);
    });
  });
}
