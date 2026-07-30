// CR-IFFD-36 — la barre d'actions de lot DÉBORDAIT à 800 dp de large.
//
// Symptôme MESURÉ par IFFD en montant `ZMultiFlashcardEditor` à la taille par
// défaut de `flutter_test` (800 × 600) :
//
//     A RenderFlex overflowed by 50 pixels on the right.
//       Row → zcrud_core/lib/src/presentation/list/z_batch_action.dart:147
//
// Un `RenderFlex overflowed` ne dégrade pas : il COUPE le contenu. Les gardes
// ci-dessous sont PORTEUSES — elles assèrent le symptôme réel (absence
// d'exception de layout via `tester.takeException()`), pas une propriété
// cosmétique. La surface de test vaut EXACTEMENT 800 × 600 : c'est la largeur
// du défaut rapporté, on ne l'élargit donc SURTOUT pas.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Construit [count] actions de lot distinctes, toutes actionnables.
List<ZBatchAction> _actions(int count, {List<String>? fired}) => <ZBatchAction>[
      for (var i = 0; i < count; i++)
        ZBatchAction(
          kind: ZBatchActionKind.custom,
          label: 'Action $i',
          icon: Icons.star,
          onSelected: () => fired?.add('Action $i'),
        ),
    ];

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Parcourt l'arbre sémantique et applique [visit] à chaque nœud.
void _walkSemantics(WidgetTester tester, void Function(SemanticsNode) visit) {
  void rec(SemanticsNode node) {
    visit(node);
    node.visitChildren((child) {
      rec(child);
      return true;
    });
  }

  rec(tester.binding.rootElement!
      .findRenderObject()!
      .debugSemantics!
      .owner!
      .rootSemanticsNode!);
}

void main() {
  group('CR-IFFD-36 — la barre de lot ne COUPE plus sur largeur réduite', () {
    // ── G1 : LE symptôme d'IFFD ────────────────────────────────────────────
    testWidgets(
        'G1 : 24 actions à 800 dp ⇒ AUCUNE exception de layout '
        '(RenderFlex overflowed)', (tester) async {
      // La surface par défaut fait EXACTEMENT 800 × 600 — largeur du défaut.
      expect(tester.view.physicalSize.width / tester.view.devicePixelRatio, 800);

      final controller = ZListSelectionController()..selectAll(['a', 'b', 'c']);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(ZBatchActionBar(
        controller: controller,
        actions: _actions(24),
        countLabelBuilder: (n) => '$n élément(s) sélectionné(s)',
        selectAllLabel: 'Tout sélectionner',
        onSelectAll: () {},
      )));
      await tester.pump();

      expect(tester.takeException(), isNull,
          reason: 'une largeur réduite ne doit plus COUPER le contenu '
              '(CR-IFFD-36) — un RenderFlex overflowed est le défaut mesuré');
      // Le contenu n'est pas coupé PARCE QU'il a été replié, pas parce qu'il a
      // disparu : le bouton de dépassement est là.
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    // ── G2 : rendu INCHANGÉ quand la largeur suffit ────────────────────────
    testWidgets(
        'G2 : 3 actions à 800 dp ⇒ tout reste EN LIGNE, aucun menu de '
        'dépassement', (tester) async {
      final controller = ZListSelectionController()..selectAll(['a']);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(ZBatchActionBar(
        controller: controller,
        actions: _actions(3),
        countLabelBuilder: (n) => '$n',
        selectAllLabel: 'Tout sélectionner',
        onSelectAll: () {},
      )));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.more_vert), findsNothing,
          reason: 'le repli ne doit JAMAIS s\'activer quand la largeur suffit '
              '(rendu inchangé pour les hôtes existants)');
      // 1 select-all + 3 actions, tous en ligne.
      expect(find.byIcon(Icons.select_all), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNWidgets(3));
      expect(find.text('1'), findsOneWidget);
    });

    // ── G3 : une action repliée reste ATTEIGNABLE ──────────────────────────
    testWidgets('G3 : la DERNIÈRE action repliée est atteignable et déclenche '
        'son callback', (tester) async {
      final fired = <String>[];
      final controller = ZListSelectionController()..selectAll(['a']);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(ZBatchActionBar(
        controller: controller,
        actions: _actions(24, fired: fired),
        countLabelBuilder: (n) => '$n',
      )));
      await tester.pump();

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Le libellé de l'action repliée est VISIBLE dans le menu (donc annoncé).
      final item = find.text('Action 23');
      expect(item, findsOneWidget,
          reason: 'une action repliée doit rester annoncée, jamais invisible');
      await tester.ensureVisible(item);
      await tester.pumpAndSettle();
      await tester.tap(item);
      await tester.pumpAndSettle();

      expect(fired, ['Action 23'],
          reason: 'une action repliée doit rester ACTIONNABLE');
    });

    // ── G4 : le bouton de dépassement n'est pas MUET (su-9) ────────────────
    testWidgets(
        'G4 : le bouton de dépassement porte un nom accessible LOCALISÉ '
        'même sans overflowLabel injecté', (tester) async {
      final handle = tester.ensureSemantics();
      final controller = ZListSelectionController()..selectAll(['a']);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(ZBatchActionBar(
        controller: controller,
        actions: _actions(24),
        countLabelBuilder: (n) => '$n',
        // overflowLabel OMIS ⇒ repli sur MaterialLocalizations.showMenuTooltip.
      )));
      await tester.pump();

      final expected = const DefaultMaterialLocalizations().showMenuTooltip;
      var named = false;
      _walkSemantics(tester, (node) {
        if ('${node.label} ${node.tooltip}'.contains(expected)) named = true;
      });
      expect(named, isTrue,
          reason: 'un bouton de dépassement actionnable ne doit jamais être '
              'MUET pour un lecteur d\'écran (récidive su-9)');
      handle.dispose();
    });

    testWidgets('G4bis : overflowLabel INJECTÉ prime sur le repli localisé',
        (tester) async {
      final handle = tester.ensureSemantics();
      final controller = ZListSelectionController()..selectAll(['a']);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(ZBatchActionBar(
        controller: controller,
        actions: _actions(24),
        countLabelBuilder: (n) => '$n',
        overflowLabel: 'Plus d\'actions de lot',
      )));
      await tester.pump();

      var named = false;
      _walkSemantics(tester, (node) {
        if ('${node.label} ${node.tooltip}'.contains('Plus d\'actions de lot')) {
          named = true;
        }
      });
      expect(named, isTrue);
      handle.dispose();
    });

    // ── G5 : non-régression du commentaire sémantique existant ─────────────
    testWidgets(
        'G5 : le compteur reste annoncé UNE seule fois MÊME avec repli '
        '(non-régression su-8)', (tester) async {
      final handle = tester.ensureSemantics();
      final controller = ZListSelectionController()..selectAll(['x', 'y', 'z']);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(ZBatchActionBar(
        controller: controller,
        actions: _actions(24),
        countLabelBuilder: (n) => '$n sélectionné(s)',
      )));
      await tester.pump();

      const needle = '3 sélectionné(s)';
      var occurrences = 0;
      _walkSemantics(tester, (node) {
        var i = 0;
        while ((i = node.label.indexOf(needle, i)) != -1) {
          occurrences++;
          i += needle.length;
        }
      });
      expect(occurrences, 1,
          reason: 'le conteneur `Semantics` de la barre ne porte PAS de label '
              'propre — sinon double annonce du compteur (su-8)');
      handle.dispose();
    });

    // ── G6 : un libellé de compteur LONG ne pousse plus les boutons dehors ──
    testWidgets(
        'G6 : un countLabel très long ne provoque AUCUNE exception de layout '
        '(le badge est Flexible)', (tester) async {
      final controller = ZListSelectionController()..selectAll(['a']);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(ZBatchActionBar(
        controller: controller,
        actions: _actions(3),
        countLabelBuilder: (n) =>
            '$n élément(s) sélectionné(s) dans le dossier courant de la '
            'bibliothèque partagée de révision',
        selectAllLabel: 'Tout sélectionner',
        onSelectAll: () {},
      )));
      await tester.pump();

      expect(tester.takeException(), isNull,
          reason: 'le badge compteur doit se rétrécir, jamais pousser les '
              'boutons hors du cadre');
      // Les boutons restent tous rendus (le texte a cédé, pas eux).
      expect(find.byIcon(Icons.star), findsNWidgets(3));
      expect(find.byIcon(Icons.select_all), findsOneWidget);
    });
  });
}
