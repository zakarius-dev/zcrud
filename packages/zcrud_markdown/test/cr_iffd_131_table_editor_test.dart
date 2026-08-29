// CR-IFFD-131 — dialogue tableau : borne de dimension paramétrable et cellule
// dont l'appelant fournit l'éditeur.
//
// Quatre angles :
//   1. INERTIE — sans réglage, le dialogue est celui d'avant : cellules =
//      champs de texte, dimensions bornées à 12 (défaut historique).
//   2. EFFET, borne — une borne de 20 déclarée laisse effectivement monter à 20.
//   3. EFFET, cellule — un éditeur de cellule déclaré est monté PAR CELLULE, et
//      ce qu'il remonte est ce que le dialogue valide.
//   4. ANCRAGE — les réglages voyagent par le CONTEXTE : le dialogue ouvert par
//      la barre d'outils les honore.
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
// Import CIBLÉ de l'impl (même package) : le dialogue n'est pas public
// (isolation AD-1) — un test interne a le droit de l'ouvrir directement.
import 'package:zcrud_markdown/src/presentation/z_table_embed.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

/// Ouvre le dialogue depuis un bouton et retourne la BOÎTE qui recevra la
/// structure validée (remplie quand le dialogue se ferme, pas avant).
Future<List<Map<String, dynamic>?>> _open(
  WidgetTester tester, {
  int? maxDim,
  double? cellWidth,
  ZTableCellEditorBuilder? cellBuilder,
}) async {
  final List<Map<String, dynamic>?> boite = <Map<String, dynamic>?>[null];
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (BuildContext context) => TextButton(
          key: const Key('cr131-ouvrir'),
          onPressed: () async {
            boite[0] = await showZTableDialog(
              context,
              maxDim: maxDim,
              cellWidth: cellWidth,
              cellBuilder: cellBuilder,
            );
          },
          child: const Text('ouvrir'),
        ),
      ),
    ),
  ));
  await tester.tap(find.byKey(const Key('cr131-ouvrir')));
  await tester.pumpAndSettle();
  return boite;
}

/// Appuie [coups] fois sur « + » du stepper « Lignes », en s'arrêtant dès que
/// le bouton est désactivé (borne atteinte).
Future<void> _monterLignes(WidgetTester tester, int coups) async {
  for (var i = 0; i < coups; i++) {
    final Finder plus = find.byKey(const ValueKey<String>('ztable-rows-inc'));
    if (tester.widget<IconButton>(plus).onPressed == null) break;
    await tester.tap(plus);
    await tester.pump();
  }
}

int _valeurAffichee(WidgetTester tester) {
  final Row stepper = tester.widget<Row>(
    find.ancestor(
      of: find.byKey(const ValueKey<String>('ztable-rows-inc')),
      matching: find.byType(Row),
    ).first,
  );
  final Text compteur = stepper.children.whereType<Text>().elementAt(1);
  return int.parse(compteur.data!);
}

void main() {
  group('CR-IFFD-131 — inertie : sans réglage, dialogue historique', () {
    testWidgets('les cellules sont des champs de TEXTE', (tester) async {
      await _open(tester);
      expect(find.byKey(const ValueKey<String>('ztable-cell-0-0')),
          findsOneWidget);
      expect(
        tester.widget(find.byKey(const ValueKey<String>('ztable-cell-0-0'))),
        isA<TextField>(),
      );
    });

    testWidgets('les dimensions restent bornées au défaut historique (12)',
        (tester) async {
      await _open(tester);
      await _monterLignes(tester, 30);
      expect(_valeurAffichee(tester), kZTableDefaultMaxDim);
      expect(kZTableDefaultMaxDim, 12,
          reason: 'le défaut historique ne doit pas bouger');
    });
  });

  group('CR-IFFD-131 — effet : la borne est paramétrable', () {
    testWidgets('borne 20 ⇒ le compteur monte jusqu\'à 20', (tester) async {
      await _open(tester, maxDim: 20);
      await _monterLignes(tester, 40);
      expect(_valeurAffichee(tester), 20);
    });

    testWidgets('une borne absurde ne rend pas la grille inutilisable',
        (tester) async {
      await _open(tester, maxDim: 0);
      expect(_valeurAffichee(tester), greaterThanOrEqualTo(1));
      expect(tester.takeException(), isNull);
    });
  });

  group('CR-IFFD-131 — effet : l\'éditeur de cellule est fourni', () {
    testWidgets('monté PAR CELLULE, avec ses coordonnées et sa valeur',
        (tester) async {
      final List<String> vus = <String>[];
      await _open(
        tester,
        cellBuilder: (BuildContext c, int r, int col, String v,
            ValueChanged<String> onChanged) {
          vus.add('$r:$col');
          return Text('C$r$col', key: ValueKey<String>('cr131-doc-$r-$col'));
        },
      );
      // Grille par défaut 2×2 ⇒ quatre montages, aucun champ de texte.
      expect(vus, containsAll(<String>['0:0', '0:1', '1:0', '1:1']));
      expect(find.byKey(const ValueKey<String>('cr131-doc-1-1')), findsOneWidget);
      expect(find.byType(TextField), findsNothing,
          reason: 'le champ de texte du socle doit céder la place');
    });

    testWidgets('ce que l\'éditeur remonte est ce que le dialogue valide',
        (tester) async {
      final List<Map<String, dynamic>?> boite = await _open(
        tester,
        cellBuilder: (BuildContext c, int r, int col, String v,
                ValueChanged<String> onChanged) =>
            TextButton(
          key: ValueKey<String>('cr131-ecrire-$r-$col'),
          onPressed: () => onChanged('L${r}C$col'),
          child: const Text('ecrire'),
        ),
      );
      await tester.tap(find.byKey(const ValueKey<String>('cr131-ecrire-0-1')));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      final Map<String, dynamic>? structure = boite[0];
      expect(structure, isNotNull);
      final List<dynamic> cells = structure!['cells'] as List<dynamic>;
      expect((cells[0] as List<dynamic>)[1], 'L0C1');
      expect((cells[0] as List<dynamic>)[0], '',
          reason: 'les cellules non touchées restent vides');
    });
  });

  group('CR-IFFD-131 — ancrage : les réglages voyagent par le CONTEXTE', () {
    testWidgets('le dialogue ouvert par la barre d\'outils les honore',
        (tester) async {
      final controller = ZFormController();
      addTearDown(controller.dispose);
      const field = ZFieldSpec(name: 'notes', type: EditionFieldType.text);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ZTableEditorScope(
            maxDim: 20,
            child: ZMarkdownField(
              key: const ValueKey<String>('notes'),
              controller: controller,
              field: field,
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));

      // Voie de production exacte : le callback RÉEL du bouton « Tableau ».
      final bouton = tester
          .widgetList<QuillToolbarCustomButton>(
              find.byType(QuillToolbarCustomButton))
          .firstWhere((b) => b.options.tooltip == 'Insérer un tableau');
      bouton.options.onPressed!.call();
      await tester.pumpAndSettle();

      await _monterLignes(tester, 40);
      expect(_valeurAffichee(tester), 20,
          reason: 'le scope déclaré au-dessus du champ doit atteindre le '
              'dialogue ouvert par la barre d\'outils');

      // Libellé fourni par `MaterialLocalizations` : on cible le BOUTON, pas
      // son texte (qui dépend de la locale du harnais).
      await tester.tap(find.byType(TextButton).last);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
