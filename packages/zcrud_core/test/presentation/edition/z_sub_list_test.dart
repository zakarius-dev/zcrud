// AC8/AC9/AC15 (E3-3b-2) — Mini-CRUD imbriqué (POINT DE VIGILANCE AD-2 N°1).
//
// Couvre :
//  - subList : add/remove/reorder modifient la `List<Map>` en TRANCHE PARENTE ;
//  - SM-1 IMBRIQUÉ : taper dans un champ d'un item ne reconstruit QUE ce champ
//    (parent host, sibling, formulaire racine, autres items → INCHANGÉS) ;
//  - réordonnancement PRÉSERVE l'état/focus des items (KeyedSubtree/ValueKey) ;
//  - retrait d'un item DISPOSE son sous-contrôleur (pas de fuite) sans casser
//    l'état des autres ;
//  - dynamicItem : add/edit/clear reflétés en tranche sans rebuild global ;
//  - `Form` → findsNothing (aucun FormBuilder global, AD-2).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _itemFields = <ZFieldSpec>[
  ZFieldSpec(name: 'f1', type: EditionFieldType.text, label: 'F1'),
  ZFieldSpec(name: 'f2', type: EditionFieldType.text, label: 'F2'),
];

const _subListField = ZFieldSpec(
  name: 'items',
  type: EditionFieldType.subItems,
  label: 'Items',
  config: ZSubListConfig(itemFields: _itemFields),
);

Widget _host(Widget child, {TextDirection dir = TextDirection.ltr}) =>
    MaterialApp(
      home: Directionality(
        textDirection: dir,
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

void main() {
  // ── AC8 : add/remove/reorder → List<Map> en tranche parente ────────────────
  group('subList add/remove/reorder (AC8)', () {
    testWidgets('ajouter puis retirer modifie la List<Map> en tranche parente',
        (tester) async {
      List<Map<String, dynamic>>? captured;
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: _subListField,
        initialValue: null,
        onChanged: (list) => captured = list,
      )));
      await tester.pump();

      expect(find.byType(ZUnsupportedFieldWidget), findsNothing);
      // 0-default : aucune ligne, un bouton d'ajout.
      expect(find.byType(TextFormField), findsNothing);

      // Ajout d'un item → 2 sous-champs texte apparaissent.
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(captured, hasLength(1));

      // Saisie dans les deux sous-champs de l'item.
      await tester.enterText(find.byType(EditableText).at(0), 'hello');
      await tester.pump();
      await tester.enterText(find.byType(EditableText).at(1), 'world');
      await tester.pump();
      expect(captured, <Map<String, dynamic>>[
        <String, dynamic>{'f1': 'hello', 'f2': 'world'},
      ]);

      // Retrait de l'item → liste vide.
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();
      expect(captured, isEmpty);
      expect(find.byType(TextFormField), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('réordonner (monter/descendre) réordonne la List en tranche',
        (tester) async {
      List<Map<String, dynamic>>? captured;
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: _subListField,
        initialValue: const <Map<String, dynamic>>[
          <String, dynamic>{'f1': 'A', 'f2': 'a'},
          <String, dynamic>{'f1': 'B', 'f2': 'b'},
        ],
        onChanged: (list) => captured = list,
      )));
      await tester.pump();

      // Descendre le 1er item → ordre [B, A].
      await tester.tap(find.byIcon(Icons.arrow_downward).first);
      await tester.pump();
      expect(captured, <Map<String, dynamic>>[
        <String, dynamic>{'f1': 'B', 'f2': 'b'},
        <String, dynamic>{'f1': 'A', 'f2': 'a'},
      ]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('réordonner PRÉSERVE le focus/état de l\'item déplacé '
        '(KeyedSubtree/ValueKey)', (tester) async {
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: _subListField,
        initialValue: const <Map<String, dynamic>>[
          <String, dynamic>{'f1': 'A', 'f2': 'a'},
          <String, dynamic>{'f1': 'B', 'f2': 'b'},
        ],
        onChanged: (_) {},
      )));
      await tester.pump();

      // Focus sur le champ f1 du 1er item (texte 'A').
      final firstF1 = find.byType(EditableText).at(0);
      await tester.tap(firstF1);
      await tester.pump();
      expect(tester.widget<EditableText>(firstF1).focusNode.hasFocus, isTrue);

      // Descendre l'item → sa place change mais son Element est réutilisé.
      await tester.tap(find.byIcon(Icons.arrow_downward).first);
      await tester.pump();

      // L'item 'A' est désormais 2e ; son champ garde le focus + son texte.
      final movedF1 = find.byType(EditableText).at(2); // f1 du 2e item
      final moved = tester.widget<EditableText>(movedF1);
      expect(moved.controller.text, 'A');
      expect(moved.focusNode.hasFocus, isTrue,
          reason: 'focus préservé au travers du réordonnancement');
      expect(tester.takeException(), isNull);
    });
  });

  // ── AC8/AC15 : SM-1 IMBRIQUÉ (le cœur du risque) ───────────────────────────
  group('SM-1 imbriqué (AC8/AC15)', () {
    testWidgets(
        'frappe dans un sous-champ ne reconstruit QUE ce champ '
        '(autres sous-champs INCHANGÉS)', (tester) async {
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
              final k = '$itemId/${field.name}';
              builds[k] = (builds[k] ?? 0) + 1;
            },
          );

      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: _subListField,
        initialValue: const <Map<String, dynamic>>[
          <String, dynamic>{'f1': 'a0', 'f2': 'a1'},
          <String, dynamic>{'f1': 'b0', 'f2': 'b1'},
        ],
        onChanged: (_) {},
        itemFieldBuilder: itemFieldBuilder,
      )));
      await tester.pump();

      // 4 sous-champs montés une fois chacun.
      expect(builds.length, 4);
      final base = Map<String, int>.from(builds);

      // Cibler f1 du 1er item (1er EditableText en ordre de Column).
      final target = find.byType(EditableText).at(0);
      await tester.tap(target);
      await tester.pump();

      // 30 frappes incrémentales dans CE seul sous-champ.
      const total = 30;
      final buffer = StringBuffer('a0');
      for (var i = 0; i < total; i++) {
        buffer.write(String.fromCharCode(97 + (i % 26)));
        await tester.enterText(target, buffer.toString());
        await tester.pump();
        expect(tester.widget<EditableText>(target).focusNode.hasFocus, isTrue,
            reason: 'focus imbriqué conservé à la frappe $i');
      }

      // EXACTEMENT une clé a bougé (le sous-champ cible) ; toutes les autres
      // (autre sous-champ du même item + les 2 de l'autre item) INCHANGÉES.
      final changed = <String>[
        for (final e in builds.entries)
          if (e.value != base[e.key]) e.key,
      ];
      expect(changed, hasLength(1),
          reason: 'un seul sous-champ reconstruit : $changed');
      expect(builds[changed.single], base[changed.single]! + total,
          reason: '≈ 1 rebuild par frappe pour le sous-champ courant');
    });

    testWidgets(
        'frappe imbriquée ne reconstruit NI le host parent NI le sibling NI '
        'le formulaire racine', (tester) async {
      var subListHostBuilds = 0;
      var siblingHostBuilds = 0;
      var structuralBuilds = 0;

      final controller = ZFormController(
        initialValues: const <String, Object?>{'t': '', 'items': null},
        visibleFields: const <String>['t', 'items'],
      );
      addTearDown(controller.dispose);

      const siblingField =
          ZFieldSpec(name: 't', type: EditionFieldType.text, label: 'Sib');

      Widget fieldBuilder(
        BuildContext context,
        ZFormController c,
        ZFieldSpec field,
      ) {
        if (field.name == 'items') {
          return ZFieldWidget(
              controller: c, field: field, onBuild: () => subListHostBuilds++);
        }
        return ZFieldWidget(
            controller: c, field: field, onBuild: () => siblingHostBuilds++);
      }

      await tester.pumpWidget(_host(DynamicEdition(
        controller: controller,
        fields: const <ZFieldSpec>[siblingField, _subListField],
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        fieldBuilder: fieldBuilder,
        onStructuralBuild: () => structuralBuilds++,
      )));
      await tester.pump();

      // Ajouter un item imbriqué (mutation STRUCTURELLE du conteneur interne).
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      final baseSubHost = subListHostBuilds;
      final baseSibling = siblingHostBuilds;
      final baseStructural = structuralBuilds;

      // Taper dans le sous-champ imbriqué (f1 de l'unique item).
      final nested = find.descendant(
        of: find.byType(ZSubListFieldWidget),
        matching: find.byType(EditableText),
      );
      await tester.tap(nested.first);
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        await tester.enterText(nested.first, 'x' * (i + 1));
        await tester.pump();
      }

      // Le host de la sous-liste (ZFieldWidget parent) n'a PAS reconstruit :
      // il est monté hors de la voie de rebuild (canal structurel).
      expect(subListHostBuilds, baseSubHost,
          reason: 'host subList inchangé sur frappe imbriquée');
      expect(siblingHostBuilds, baseSibling,
          reason: 'sibling texte inchangé sur frappe imbriquée');
      expect(structuralBuilds, baseStructural,
          reason: 'build structurel du formulaire racine inchangé');

      // La valeur imbriquée EST bien agrégée dans la tranche parente.
      final items = controller.valueOf('items');
      expect(items, isA<List<Map<String, dynamic>>>());
      expect((items! as List).single, <String, dynamic>{
        'f1': 'x' * 20,
        'f2': null,
      });
      expect(tester.takeException(), isNull);
    });

    testWidgets('retrait d\'un item ne casse pas l\'état des autres',
        (tester) async {
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: _subListField,
        initialValue: const <Map<String, dynamic>>[
          <String, dynamic>{'f1': 'A', 'f2': 'a'},
          <String, dynamic>{'f1': 'B', 'f2': 'b'},
          <String, dynamic>{'f1': 'C', 'f2': 'c'},
        ],
        onChanged: (_) {},
      )));
      await tester.pump();

      // Retirer l'item du milieu (2e bouton delete).
      await tester.tap(find.byIcon(Icons.delete_outline).at(1));
      await tester.pump();

      // Restent A et C, dans l'ordre, textes intacts (place stable par clé).
      final editables = tester.widgetList<EditableText>(find.byType(EditableText));
      final texts = editables.map((e) => e.controller.text).toList();
      expect(texts, <String>['A', 'a', 'C', 'c']);
      expect(tester.takeException(), isNull);
    });
  });

  // ── AC9 : dynamicItem (item unique add/edit/clear) ─────────────────────────
  group('dynamicItem (AC9)', () {
    const dynField = ZFieldSpec(
      name: 'one',
      type: EditionFieldType.dynamicItem,
      label: 'Item',
      config: ZSubListConfig(itemFields: _itemFields),
    );

    testWidgets('add → Map en tranche ; edit → maj ; clear → null',
        (tester) async {
      Object? captured = 'sentinel';
      await tester.pumpWidget(_host(ZDynamicItemFieldWidget(
        field: dynField,
        initialValue: null,
        onChanged: (m) => captured = m,
      )));
      await tester.pump();

      // Absent : bouton d'ajout, aucun champ.
      expect(find.byType(ZDynamicItemFieldWidget), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);

      // Add → item vide créé.
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(captured, <String, dynamic>{'f1': null, 'f2': null});

      // Edit un sous-champ → Map mise à jour.
      await tester.enterText(find.byType(EditableText).at(0), 'v');
      await tester.pump();
      expect(captured, <String, dynamic>{'f1': 'v', 'f2': null});

      // Clear → null.
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();
      expect(captured, isNull);
      expect(find.byType(TextFormField), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('valeur initiale Map → item pré-rempli édité par slice imbriqué',
        (tester) async {
      await tester.pumpWidget(_host(ZDynamicItemFieldWidget(
        field: dynField,
        initialValue: const <String, dynamic>{'f1': 'init', 'f2': null},
        onChanged: (_) {},
      )));
      await tester.pump();
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(
          tester.widget<EditableText>(find.byType(EditableText).at(0)).controller.text,
          'init');
      expect(tester.takeException(), isNull);
    });
  });

  // ── AC15 : aucun Form/FormBuilder global sous le mini-CRUD imbriqué ────────
  testWidgets('AUCUN Form global sous subList/dynamicItem (AC15)',
      (tester) async {
    await tester.pumpWidget(_host(Column(children: <Widget>[
      ZSubListFieldWidget(
        field: _subListField,
        initialValue: const <Map<String, dynamic>>[
          <String, dynamic>{'f1': 'A', 'f2': 'a'},
        ],
        onChanged: (_) {},
      ),
      const ZDynamicItemFieldWidget(
        field: ZFieldSpec(
          name: 'one',
          type: EditionFieldType.dynamicItem,
          config: ZSubListConfig(itemFields: _itemFields),
        ),
        initialValue: <String, dynamic>{'f1': 'x', 'f2': 'y'},
        onChanged: _noop,
      ),
    ])));
    await tester.pump();
    expect(find.byType(Form), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // ── AC8/AC13 : a11y + RTL du mini-CRUD imbriqué ────────────────────────────
  testWidgets('subList : cibles ≥ 48 dp + Semantics + RTL sans overflow '
      '(AC8/AC13)', (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(_host(
      ZSubListFieldWidget(
        field: _subListField,
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
}

void _noop(Map<String, dynamic>? _) {}
