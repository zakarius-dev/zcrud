// Mode « cellule = Markdown », chemin HYBRIDE.
//
// Deux invariants, et le second compte autant que le premier :
//   1. une cellule porte du Markdown COMPLET — listes imbriquées, cases à
//      cocher, blocs de code, citations, titres, formules inline ET bloc ;
//   2. le coût de rendu est proportionnel à la RICHESSE RÉELLE, pas à la taille
//      du tableau — sans quoi un tableau 10×5 monterait 50 `QuillEditor`.
//
// Le format persisté ne change pas d'un octet : ce mode change la LECTURE d'une
// cellule, pas son stockage. La bascule est donc réversible dans les deux sens.
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

/// Monte un tableau dont les cellules sont [cells], sous le mode [content].
Future<void> _pump(
  WidgetTester tester,
  List<List<String>> cells, {
  ZTableCellContent content = ZTableCellContent.markdown,
  ZCodec? codec,
}) async {
  // L'op est passée TELLE QUELLE — charge gelée comprise. C'est le chemin réel
  // d'un hôte, et c'est lui qui a révélé qu'une op gelée vidait le lecteur.
  final Map<String, dynamic> op = zTableEmbedOp(cells: cells);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: FlutterQuillLocalizations.localizationsDelegates,
      supportedLocales: const <Locale>[Locale('fr'), Locale('en')],
      home: Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(
          body: ZTableCellScope(
            content: content,
            codec: codec,
            child: SingleChildScrollView(
              child: ZMarkdownReader(
                value: <Map<String, dynamic>>[
                  op,
                  <String, dynamic>{'insert': '\n'},
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Nombre d'éditeurs Quill montés SOUS le tableau (le lecteur extérieur en
/// monte un lui-même : on ne compte que les surnuméraires).
int _cellEditors(WidgetTester tester) =>
    tester.widgetList(find.byType(QuillEditor)).length - 1;

void main() {
  group('🔴 SM-1 — le coût suit la RICHESSE, pas la taille du tableau', () {
    testWidgets('un tableau 10×5 de texte NU ne monte AUCUN éditeur de cellule',
        (tester) async {
      final cells = <List<String>>[
        for (var r = 0; r < 10; r++)
          <String>[for (var c = 0; c < 5; c++) 'cellule $r-$c'],
      ];
      await _pump(tester, cells);
      expect(_cellEditors(tester), 0,
          reason: '50 cellules nues ne doivent monter aucun QuillEditor');
      expect(find.text('cellule 0-0'), findsOneWidget);
      expect(find.text('cellule 9-4'), findsOneWidget);
    });

    testWidgets('SEULE la cellule riche paie le rendu riche', (tester) async {
      await _pump(tester, <List<String>>[
        <String>['- alpha\n- beta', 'texte nu'],
        <String>['autre texte', 'encore'],
      ]);
      expect(_cellEditors(tester), 1,
          reason: 'une seule des quatre cellules porte de la structure');
    });

    testWidgets('en mode plainText, AUCUN éditeur — le défaut est intact',
        (tester) async {
      await _pump(
        tester,
        <List<String>>[
          <String>['- alpha\n- beta', 'x'],
        ],
        content: ZTableCellContent.plainText,
      );
      expect(_cellEditors(tester), 0);
      expect(find.textContaining('- alpha'), findsOneWidget,
          reason: 'le texte doit rester LITTÉRAL sans opt-in');
    });
  });

  group('Une cellule est un document Markdown COMPLET', () {
    for (final MapEntry<String, String> cas in <String, String>{
      'liste à puces': '- alpha\n- beta',
      'liste imbriquée': '- a\n  - a1\n- b',
      'liste ordonnée': '1. un\n2. deux',
      'cases à cocher': '- [x] fait\n- [ ] à faire',
      'bloc de code': '```dart\nvar x = 1;\n```',
      'citation': '> citation',
      'titre puis liste': '### Titre\n\n- a\n- b',
    }.entries) {
      testWidgets('${cas.key} — rendu riche, sans exception', (tester) async {
        await _pump(tester, <List<String>>[
          <String>[cas.value, 'x'],
        ]);
        expect(tester.takeException(), isNull);
        expect(_cellEditors(tester), 1,
            reason: '« ${cas.key} » porte de la structure');
      });
    }

    testWidgets('une cellule de texte NU reste un `Text` (pas un éditeur)',
        (tester) async {
      await _pump(tester, <List<String>>[
        <String>['juste du texte', 'et encore'],
      ]);
      expect(_cellEditors(tester), 0);
      expect(find.text('juste du texte'), findsOneWidget);
    });

    testWidgets('🔴 une puce n\'est JAMAIS rendue comme son texte nu',
        (tester) async {
      // Piège central du chemin rapide : `- a` décode en un insert `a` SANS
      // attribut — l'attribut de liste est porté par le saut de ligne. Un
      // aiguillage naïf sur « aucun attribut » afficherait donc « a », c'est-à-
      // dire un contenu FAUX plutôt qu'un contenu brut. D'où la comparaison au
      // texte SOURCE.
      await _pump(tester, <List<String>>[
        <String>['- alpha', 'x'],
      ]);
      expect(find.text('alpha'), findsNothing,
          reason: 'le texte nu de la puce ne doit pas remplacer la puce');
      expect(_cellEditors(tester), 1);
    });
  });

  group('Le chemin rapide ne doit pas afficher une SOURCE non résolue', () {
    // Ces cas décodent SANS aucun attribut ni embed : seul l'écart au texte
    // source distingue « du texte nu » de « du Markdown à résoudre ». Sans la
    // comparaison à la source, la cellule afficherait la syntaxe brute.
    for (final MapEntry<String, String> cas in <String, String>{
      'entité HTML': 'a &amp; b',
      'échappement': r'a\_b',
      'entité et texte': 'Bénin &lt; Togo',
    }.entries) {
      testWidgets('${cas.key} — la forme RÉSOLUE est affichée', (tester) async {
        await _pump(tester, <List<String>>[
          <String>[cas.value, 'x'],
        ]);
        expect(find.text(cas.value), findsNothing,
            reason: 'la source « ${cas.value} » ne doit pas rester visible');
        expect(_cellEditors(tester), 1);
      });
    }
  });

  group('Les ponts déclarés s\'appliquent DANS la cellule', () {
    testWidgets('une formule inline est rendue, pas affichée en source',
        (tester) async {
      await _pump(
        tester,
        <List<String>>[
          <String>[r'soit $E=mc^2$ donc', 'x'],
        ],
        codec: ZMarkdownCodec(bridges: ZMarkdownBridges.latex),
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining(r'$E=mc^2$'), findsNothing,
          reason: 'la source LaTeX ne doit plus être visible');
    });

    testWidgets('un bloc LaTeX en cellule est rendu', (tester) async {
      await _pump(
        tester,
        <List<String>>[
          <String>[r'$$E=mc^2$$', 'x'],
        ],
        codec: ZMarkdownCodec(bridges: ZMarkdownBridges.latex),
      );
      expect(tester.takeException(), isNull);
      expect(_cellEditors(tester), 1);
    });

    testWidgets('SANS pont déclaré, la source LaTeX reste visible',
        (tester) async {
      // Contrat AD-57 : un pont ne s'active jamais tout seul.
      await _pump(tester, <List<String>>[
        <String>[r'soit $E=mc^2$ donc', 'x'],
      ]);
      expect(find.textContaining(r'$E=mc^2$'), findsOneWidget);
    });
  });

  group('🔴 Défaut PRÉEXISTANT révélé par ce câblage', () {
    testWidgets('une op au contenu GELÉ ne vide plus le lecteur',
        (tester) async {
      // `zTableEmbedOp` gèle sa charge en profondeur ; `Document.fromJson` la
      // castait et LEVAIT ; le filet AD-10 attrapait et rendait un document
      // VIDE. Une op de tableau parfaitement valide faisait donc DISPARAÎTRE
      // tout le contenu, sans erreur visible — y compris hors de tout tableau,
      // dans `ZMarkdownField` et `ZMarkdownReader`. Sans rapport avec les CR :
      // trouvé en câblant le rendu de cellule.
      await _pump(
        tester,
        <List<String>>[
          <String>['contenu qui disparaissait', 'x'],
        ],
        content: ZTableCellContent.plainText,
      );
      expect(find.text('contenu qui disparaissait'), findsOneWidget,
          reason: 'le tableau ne doit pas être avalé par le décodage défensif');
    });
  });

  group('AD-10 — jamais de cellule vidée', () {
    testWidgets('un contenu illisible retombe sur le texte brut',
        (tester) async {
      await _pump(tester, <List<String>>[
        <String>['<<< pas du Markdown valide ??? ***', 'x'],
      ]);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('pas du Markdown'), findsOneWidget);
    });

    testWidgets('une cellule VIDE ne casse pas le tableau', (tester) async {
      await _pump(tester, <List<String>>[
        <String>['', 'x'],
        <String>['a', ''],
      ]);
      expect(tester.takeException(), isNull);
      expect(_cellEditors(tester), 0);
    });
  });
}
