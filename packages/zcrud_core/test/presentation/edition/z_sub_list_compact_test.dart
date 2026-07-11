// DP-6 (parité DODLP, gap B8) — sous-liste mode COMPACT + dialog par item.
//
// Couvre :
//  - AC20 : compact rend une LISTE RÉSUMÉ (N lignes, summaryFields visibles) et
//    NON les sous-champs éditables inline (TextFormField absents hors dialog) ;
//  - AC9/AC10/AC13 : add/edit/delete via dialog reflétés dans onChanged ;
//  - AC11 : consultation = dialog readOnly sans bouton Enregistrer ;
//  - AC21 : ACL par action (create/view/update/delete) masque le contrôle ;
//    collectionId transmis à can(...) ;
//  - AC22 : SM-1 dans le dialog (frappe → seul ce champ reconstruit ; Form
//    findsNothing) ;
//  - AC8 : repli summaryFields vide → titre dérivé ;
//  - AC18 : défensif (item corrompu → sûr) ;
//  - AC17 : a11y ≥ 48 dp + RTL sans overflow ;
//  - AC19 : mode inline strictement préservé (config sans displayMode).
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

Widget _host(Widget child, {TextDirection dir = TextDirection.ltr}) =>
    MaterialApp(
      home: Directionality(
        textDirection: dir,
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

/// Fausse ACL refusant une action ciblée (mode `hide`) ; capture le dernier
/// `collectionId` demandé pour asserter sa transmission.
class _DenyAcl implements ZAcl {
  _DenyAcl(this.denied);
  final Set<ZCrudAction> denied;
  String? lastCollectionId;
  var canCalled = false;

  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) {
    canCalled = true;
    lastCollectionId = collectionId;
    return !denied.contains(action);
  }
}

void main() {
  // ── AC20 : liste résumé (pas de déballage inline) ──────────────────────────
  group('compact : liste résumé (AC20)', () {
    testWidgets('N items → N lignes résumé, summaryFields visibles, aucun '
        'TextFormField hors dialog', (tester) async {
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: _compactField,
        initialValue: const <Map<String, dynamic>>[
          <String, dynamic>{'f1': 'Alpha', 'f2': 'a'},
          <String, dynamic>{'f1': 'Beta', 'f2': 'b'},
        ],
        onChanged: (_) {},
      )));
      await tester.pump();

      // Résumé lisible : la valeur du summaryField f1 est rendue en TEXTE.
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      // f2 n'est PAS un summaryField → non affiché en résumé.
      expect(find.text('a'), findsNothing);
      // Aucun sous-champ éditable inline hors dialog.
      expect(find.byType(TextFormField), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('liste vide → message noItems, bouton add présent',
        (tester) async {
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: _compactField,
        initialValue: null,
        onChanged: (_) {},
      )));
      await tester.pump();
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  // ── AC9/AC10/AC13 : CRUD via dialog ────────────────────────────────────────
  group('compact : CRUD via dialog (AC9/AC10/AC13)', () {
    testWidgets('ajout via dialog → append + onChanged reçoit la List allongée',
        (tester) async {
      List<Map<String, dynamic>>? captured;
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: _compactField,
        initialValue: null,
        onChanged: (list) => captured = list,
      )));
      await tester.pump();

      // Ouvre le dialog d'ajout.
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(2));

      // Saisit f1, enregistre.
      await tester.enterText(find.byType(EditableText).at(0), 'Nouveau');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(captured, hasLength(1));
      expect(captured!.single['f1'], 'Nouveau');
      // La ligne résumé apparaît, plus de TextFormField hors dialog.
      expect(find.text('Nouveau'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('annulation de l\'ajout → aucun item, aucun effet de bord',
        (tester) async {
      List<Map<String, dynamic>>? captured;
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: _compactField,
        initialValue: null,
        onChanged: (list) => captured = list,
      )));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).at(0), 'Jeté');
      await tester.pump();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(captured, isNull);
      expect(find.text('Jeté'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('édition via dialog → item modifié À SA PLACE', (tester) async {
      List<Map<String, dynamic>>? captured;
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: _compactField,
        initialValue: const <Map<String, dynamic>>[
          <String, dynamic>{'f1': 'X', 'f2': 'x'},
          <String, dynamic>{'f1': 'Y', 'f2': 'y'},
        ],
        onChanged: (list) => captured = list,
      )));
      await tester.pump();

      // Édite le 1er item (1er bouton edit).
      await tester.tap(find.byIcon(Icons.edit).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).at(0), 'Xbis');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(captured, hasLength(2));
      expect(captured![0]['f1'], 'Xbis');
      expect(captured![0]['f2'], 'x');
      expect(captured![1]['f1'], 'Y'); // voisin intact
      expect(find.text('Xbis'), findsOneWidget);
      expect(find.text('Y'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('suppression → confirmation ; confirmer retire, annuler garde',
        (tester) async {
      List<Map<String, dynamic>>? captured;
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: _compactField,
        initialValue: const <Map<String, dynamic>>[
          <String, dynamic>{'f1': 'ToKeep', 'f2': 'k'},
          <String, dynamic>{'f1': 'ToDrop', 'f2': 'd'},
        ],
        onChanged: (list) => captured = list,
      )));
      await tester.pump();

      // Annuler d'abord (2e item).
      await tester.tap(find.byIcon(Icons.delete_outline).at(1));
      await tester.pumpAndSettle();
      expect(find.text('Delete this item?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('ToDrop'), findsOneWidget);
      expect(captured, isNull); // aucun retrait

      // Confirmer.
      await tester.tap(find.byIcon(Icons.delete_outline).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('ToDrop'), findsNothing);
      expect(find.text('ToKeep'), findsOneWidget);
      expect(captured, hasLength(1));
      expect(captured!.single['f1'], 'ToKeep');
      expect(tester.takeException(), isNull);
    });
  });

  // ── AC11 : consultation lecture seule ──────────────────────────────────────
  testWidgets('consultation = dialog readOnly sans bouton Enregistrer (AC11)',
      (tester) async {
    await tester.pumpWidget(_host(ZSubListFieldWidget(
      field: _compactField,
      initialValue: const <Map<String, dynamic>>[
        <String, dynamic>{'f1': 'Voir', 'f2': 'v'},
      ],
      onChanged: (_) {},
    )));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.visibility).first);
    await tester.pumpAndSettle();

    // Dialog ouvert, pas de bouton Enregistrer, un bouton Fermer.
    expect(find.text('Save'), findsNothing);
    expect(find.text('Close'), findsOneWidget);
    // Champs en lecture seule : le sous-champ texte est monté mais readOnly
    // (spec copyWith(readOnly: true)) → aucune mutation possible.
    final editables =
        tester.widgetList<EditableText>(find.byType(EditableText));
    expect(editables, isNotEmpty);
    expect(editables.every((e) => e.readOnly), isTrue);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  // ── AC21 : ACL par action ──────────────────────────────────────────────────
  group('compact : ACL par action (AC21)', () {
    testWidgets('ACL permissive (défaut) affiche add/view/edit/delete',
        (tester) async {
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: _compactField,
        initialValue: const <Map<String, dynamic>>[
          <String, dynamic>{'f1': 'A', 'f2': 'a'},
        ],
        onChanged: (_) {},
      )));
      await tester.pump();
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('refus create → aucun bouton add', (tester) async {
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: _compactField,
        initialValue: null,
        onChanged: (_) {},
        acl: _DenyAcl(<ZCrudAction>{ZCrudAction.create}),
      )));
      await tester.pump();
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('refus view/update/delete → contrôles masqués', (tester) async {
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: _compactField,
        initialValue: const <Map<String, dynamic>>[
          <String, dynamic>{'f1': 'A', 'f2': 'a'},
        ],
        onChanged: (_) {},
        acl: _DenyAcl(<ZCrudAction>{
          ZCrudAction.view,
          ZCrudAction.update,
          ZCrudAction.delete,
        }),
      )));
      await tester.pump();
      expect(find.byIcon(Icons.visibility), findsNothing);
      expect(find.byIcon(Icons.edit), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('collectionId transmis à can(...)', (tester) async {
      final acl = _DenyAcl(const <ZCrudAction>{});
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: _compactField,
        initialValue: null,
        onChanged: (_) {},
        acl: acl,
        collectionId: 'coll-42',
      )));
      await tester.pump();
      expect(acl.canCalled, isTrue);
      expect(acl.lastCollectionId, 'coll-42');
    });
  });

  // ── AC22 : SM-1 dans le dialog ──────────────────────────────────────────────
  testWidgets('SM-1 dialog : frappe → seul ce champ reconstruit ; Form absent '
      '(AC22)', (tester) async {
    final builds = <String, int>{};
    Widget itemFieldBuilder(
      BuildContext context,
      ZFormController controller,
      ZFieldSpec field,
      String itemId,
    ) =>
        ZFieldWidget(
          controller: controller,
          field: field,
          onBuild: () {
            final k = field.name;
            builds[k] = (builds[k] ?? 0) + 1;
          },
        );

    await tester.pumpWidget(_host(ZSubListFieldWidget(
      field: _compactField,
      initialValue: const <Map<String, dynamic>>[
        <String, dynamic>{'f1': 'A', 'f2': 'a'},
      ],
      onChanged: (_) {},
      itemFieldBuilder: itemFieldBuilder,
    )));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.edit).first);
    await tester.pumpAndSettle();

    // Aucun Form global dans le dialog (AD-2).
    expect(find.byType(Form), findsNothing);

    // Deux sous-champs montés une fois chacun.
    expect(builds.keys.toSet(), <String>{'f1', 'f2'});
    final base = Map<String, int>.from(builds);

    // 20 frappes dans f1 uniquement.
    final target = find.byType(EditableText).at(0);
    await tester.tap(target);
    await tester.pump();
    const total = 20;
    final buffer = StringBuffer('A');
    for (var i = 0; i < total; i++) {
      buffer.write('x');
      await tester.enterText(target, buffer.toString());
      await tester.pump();
    }

    // f2 INCHANGÉ ; f1 ≈ +total.
    expect(builds['f2'], base['f2'], reason: 'sibling non reconstruit');
    expect(builds['f1']! - base['f1']!, greaterThanOrEqualTo(total - 1),
        reason: 'seul le champ courant reconstruit à la frappe');
    expect(tester.takeException(), isNull);
  });

  // ── AC8 : repli summaryFields vide → titre dérivé ──────────────────────────
  testWidgets('summaryFields vide → titre dérivé (concat itemFields) (AC8)',
      (tester) async {
    const field = ZFieldSpec(
      name: 'items',
      type: EditionFieldType.subItems,
      label: 'Items',
      config: ZSubListConfig(
        itemFields: _itemFields,
        displayMode: ZSubListDisplayMode.compact,
      ),
    );
    await tester.pumpWidget(_host(ZSubListFieldWidget(
      field: field,
      initialValue: const <Map<String, dynamic>>[
        <String, dynamic>{'f1': 'Hello', 'f2': 'World'},
      ],
      onChanged: (_) {},
    )));
    await tester.pump();
    expect(find.text('Hello — World'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('itemTitleBuilder → titre de résumé et de dialog', (tester) async {
    const field = ZFieldSpec(
      name: 'items',
      type: EditionFieldType.subItems,
      config: ZSubListConfig(
        itemFields: _itemFields,
        displayMode: ZSubListDisplayMode.compact,
      ),
    );
    await tester.pumpWidget(_host(ZSubListFieldWidget(
      field: field,
      initialValue: const <Map<String, dynamic>>[
        <String, dynamic>{'f1': 'Bob', 'f2': '42'},
      ],
      onChanged: (_) {},
      itemTitleBuilder: (item) => 'Titre:${item['f1']}',
    )));
    await tester.pump();
    expect(find.text('Titre:Bob'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ── AC18 : défensif (item corrompu) ────────────────────────────────────────
  testWidgets('item corrompu (non-Map) → repli sûr, aucun throw (AC18)',
      (tester) async {
    await tester.pumpWidget(_host(ZSubListFieldWidget(
      field: _compactField,
      initialValue: const <Object>['pas-une-map', 42],
      onChanged: (_) {},
    )));
    await tester.pump();
    // Les entrées non-Map sont ignorées (aucune ligne), aucun crash.
    expect(tester.takeException(), isNull);
  });

  testWidgets('itemTitleBuilder qui throw → repli sûr (AD-10)', (tester) async {
    const field = ZFieldSpec(
      name: 'items',
      type: EditionFieldType.subItems,
      config: ZSubListConfig(
        itemFields: _itemFields,
        displayMode: ZSubListDisplayMode.compact,
      ),
    );
    await tester.pumpWidget(_host(ZSubListFieldWidget(
      field: field,
      initialValue: const <Map<String, dynamic>>[
        <String, dynamic>{'f1': 'Zed', 'f2': null},
      ],
      onChanged: (_) {},
      itemTitleBuilder: (item) => throw StateError('boom'),
    )));
    await tester.pump();
    // Repli sur la concaténation des itemFields (f1 seul non nul).
    expect(find.text('Zed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ── AC17 : a11y ≥ 48 dp + RTL ──────────────────────────────────────────────
  testWidgets('compact : cibles ≥ 48 dp + RTL sans overflow (AC17)',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(_host(
      ZSubListFieldWidget(
        field: _compactField,
        initialValue: const <Map<String, dynamic>>[
          <String, dynamic>{'f1': 'A', 'f2': 'a'},
          <String, dynamic>{'f1': 'B', 'f2': 'b'},
        ],
        onChanged: (_) {},
      ),
      dir: TextDirection.rtl,
    ));
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  // ── AC19 : mode inline strictement préservé ────────────────────────────────
  testWidgets('config sans displayMode → mode inline (sous-champs inline) '
      '(AC19)', (tester) async {
    const inlineField = ZFieldSpec(
      name: 'items',
      type: EditionFieldType.subItems,
      label: 'Items',
      config: ZSubListConfig(itemFields: _itemFields),
    );
    await tester.pumpWidget(_host(ZSubListFieldWidget(
      field: inlineField,
      initialValue: const <Map<String, dynamic>>[
        <String, dynamic>{'f1': 'A', 'f2': 'a'},
      ],
      onChanged: (_) {},
    )));
    await tester.pump();
    // Mode inline : les 2 sous-champs sont éditables inline (TextFormField).
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
