// fp-5-1 (AD-52) — sous-liste mode `tags` : rendu natif MINIMAL `InputChip`.
//
// Couvre :
//  - AC-B1/B2 : `ZSubListDisplayMode.tags` rend une rangée de puces `InputChip`
//    (résumé par item) + bouton d'ajout ≥ 48 dp réutilisant le dialog ;
//  - AC-B2 : branche EXPLICITE — `tags` ne retombe JAMAIS silencieusement en
//    `inline` (aucun sous-champ éditable inline) ni en `compact` ;
//  - AC-B3 : `inline` (défaut) strictement préservé (config sans displayMode) ;
//  - a11y/RTL : rendu directionnel sans overflow, cible d'ajout ≥ 48 dp.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _itemFields = <ZFieldSpec>[
  ZFieldSpec(name: 'f1', type: EditionFieldType.text, label: 'F1'),
  ZFieldSpec(name: 'f2', type: EditionFieldType.text, label: 'F2'),
];

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

Widget _host(Widget child, {TextDirection dir = TextDirection.ltr}) =>
    MaterialApp(
      home: Directionality(
        textDirection: dir,
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

/// Host paramétrable par thème (fp-5-1 MED-2 : force `shrinkWrap` pour prouver
/// que la puce épingle sa cible tactile INDÉPENDAMMENT du thème ambiant).
Widget _themedHost(Widget child, {required ThemeData theme}) => MaterialApp(
      theme: theme,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  group('tags : rendu minimal InputChip (AC-B1/B2)', () {
    testWidgets('N items → N InputChip avec résumé, aucun sous-champ inline',
        (tester) async {
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: _tagsField,
        initialValue: const <Map<String, dynamic>>[
          <String, dynamic>{'f1': 'Alpha', 'f2': 'a'},
          <String, dynamic>{'f1': 'Beta', 'f2': 'b'},
        ],
        onChanged: (_) {},
      )));
      await tester.pump();

      // Rendu tags : une puce par item, portant le résumé (summaryField f1).
      expect(find.byType(InputChip), findsNWidgets(2));
      expect(find.widgetWithText(InputChip, 'Alpha'), findsOneWidget);
      expect(find.widgetWithText(InputChip, 'Beta'), findsOneWidget);
      // JAMAIS un repli silencieux vers `inline` : aucun sous-champ éditable.
      expect(find.byType(TextFormField), findsNothing);
      // Bouton d'ajout présent (réutilise la machinerie de dialog).
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('liste vide → aucune puce, bouton add présent', (tester) async {
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: _tagsField,
        initialValue: null,
        onChanged: (_) {},
      )));
      await tester.pump();
      expect(find.byType(InputChip), findsNothing);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sans summaryFields → repli titre dérivé (puce non vide)',
        (tester) async {
      const field = ZFieldSpec(
        name: 'items',
        type: EditionFieldType.subItems,
        label: 'Items',
        config: ZSubListConfig(
          itemFields: _itemFields,
          displayMode: ZSubListDisplayMode.tags,
        ),
      );
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: field,
        initialValue: const <Map<String, dynamic>>[
          <String, dynamic>{'f1': 'Alpha', 'f2': 'a'},
        ],
        onChanged: (_) {},
      )));
      await tester.pump();
      // Titre dérivé = concat des valeurs non nulles → « Alpha — a ».
      expect(find.widgetWithText(InputChip, 'Alpha — a'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('tags : ajout / suppression via machinerie existante (AC-B2)', () {
    testWidgets('ajout via dialog → nouvelle puce + onChanged allongé',
        (tester) async {
      List<Map<String, dynamic>>? captured;
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: _tagsField,
        initialValue: null,
        onChanged: (list) => captured = list,
      )));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(2));
      await tester.enterText(find.byType(EditableText).at(0), 'Neuf');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(captured, hasLength(1));
      expect(captured!.single['f1'], 'Neuf');
      expect(find.widgetWithText(InputChip, 'Neuf'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('suppression de puce (onDeleted) → confirmation puis retrait',
        (tester) async {
      List<Map<String, dynamic>>? captured;
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: _tagsField,
        initialValue: const <Map<String, dynamic>>[
          <String, dynamic>{'f1': 'Alpha', 'f2': 'a'},
        ],
        onChanged: (list) => captured = list,
      )));
      await tester.pump();

      // Le bouton de suppression de la puce (tooltip l10n) ouvre la confirmation.
      await tester.tap(find.byTooltip('Remove item').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured, isEmpty);
      expect(find.byType(InputChip), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('tags : a11y / RTL (AD-13)', () {
    testWidgets('bouton d\'ajout ≥ 48 dp, aucun overflow en RTL', (tester) async {
      await tester.pumpWidget(_host(
        ZSubListFieldWidget(
          field: _tagsField,
          initialValue: const <Map<String, dynamic>>[
            <String, dynamic>{'f1': 'Alpha', 'f2': 'a'},
          ],
          onChanged: (_) {},
        ),
        dir: TextDirection.rtl,
      ));
      await tester.pump();
      // Cible tactile = l'IconButton d'ajout (l'Icon seule fait 24 dp).
      final addSize = tester.getSize(
        find.widgetWithIcon(IconButton, Icons.add),
      );
      expect(addSize.width >= 48.0 && addSize.height >= 48.0, isTrue,
          reason: 'cible tactile ≥ 48 dp (AD-13)');
      expect(tester.takeException(), isNull);
    });
  });

  group('tags : a11y libellé de section — pas de double annonce (MED-1)', () {
    testWidgets(
        'le libellé de section apparaît UNE seule fois dans l\'arbre sémantique',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: _tagsField,
        initialValue: const <Map<String, dynamic>>[
          <String, dynamic>{'f1': 'Alpha', 'f2': 'a'},
          <String, dynamic>{'f1': 'Beta', 'f2': 'b'},
        ],
        onChanged: (_) {},
      )));
      await tester.pump();

      // CANAL sémantique (pas le rendu) : un `Semantics(container:, label:)`
      // englobant le `Text` visible fusionne le libellé en « Items\nItems »
      // (double annonce du lecteur d'écran) → AUCUN nœud portant exactement
      // « Items » ⇒ `findsNothing` (ROUGE). Le libellé de section ne doit
      // exister qu'une fois, porté par le seul `Text` visible ⇒ `findsOneWidget`.
      expect(find.bySemanticsLabel('Items'), findsOneWidget,
          reason: 'libellé de section annoncé une seule fois (pas de doublon)');
      handle.dispose();
    });
  });

  group('tags : cible tactile de la puce ≥ 48 dp sous shrinkWrap (MED-2)', () {
    testWidgets(
        'InputChip ≥ 48 dp même sous ThemeData(materialTapTargetSize: shrinkWrap)',
        (tester) async {
      await tester.pumpWidget(_themedHost(
        ZSubListFieldWidget(
          field: _tagsField,
          initialValue: const <Map<String, dynamic>>[
            <String, dynamic>{'f1': 'Alpha', 'f2': 'a'},
          ],
          onChanged: (_) {},
        ),
        theme: ThemeData(materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
      ));
      await tester.pump();

      // La puce épingle `MaterialTapTargetSize.padded` → sa hauteur reste ≥ 48
      // dp malgré le thème `shrinkWrap` (couvre aussi la mesure de la puce
      // elle-même, pas seulement le bouton d'ajout).
      final chipSize = tester.getSize(find.byType(InputChip));
      expect(chipSize.height >= 48.0, isTrue,
          reason: 'cible tactile de la puce ≥ 48 dp indépendante du thème');
      expect(tester.takeException(), isNull);
    });
  });

  group('tags : rétro-compat modes existants (AC-B3)', () {
    testWidgets('config SANS displayMode → inline (déballage éditable inchangé)',
        (tester) async {
      const inlineField = ZFieldSpec(
        name: 'items',
        type: EditionFieldType.subItems,
        label: 'Items',
        config: ZSubListConfig(itemFields: _itemFields),
      );
      await tester.pumpWidget(_host(ZSubListFieldWidget(
        field: inlineField,
        initialValue: const <Map<String, dynamic>>[
          <String, dynamic>{'f1': 'Alpha', 'f2': 'a'},
        ],
        onChanged: (_) {},
      )));
      await tester.pump();
      // Mode inline : sous-champs éditables déballés, aucune puce.
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.byType(InputChip), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
