// Deux défauts de rendu, tous deux internes au socle (aucun hôte ne peut
// compenser) :
//   ① une cellule de tableau RICHE recevait le chrome `bordered` du lecteur
//     (cadre + padding) DANS un tableau qui dessine déjà sa grille — deux
//     bordures concentriques, lignes désalignées, et une asymétrie avec les
//     cellules en texte pur (rendues `Text` nu) ;
//   ② une formule LaTeX BLOC plus large que la place débordait
//     (`RIGHT OVERFLOWED`) au lieu de défiler — la fin de la formule perdue.
//
// Les gardes mesurent le RENDU (géométrie, exceptions du harnais), jamais la
// seule valeur d'un paramètre : le harnais de test capte les overflows par
// `FlutterError.onError` → `tester.takeException()`.
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

/// Hôte minimal — délégués Quill requis par le lecteur, LTR explicite.
Widget _host(Widget child) => MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: FlutterQuillLocalizations.localizationsDelegates,
      supportedLocales: const <Locale>[Locale('fr'), Locale('en')],
      home: Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(body: child),
      ),
    );

/// Formule volontairement PLUS LARGE que tout viewport de test raisonnable.
final String _wideFormula =
    List<String>.generate(40, (i) => 'x_{$i}').join(' + ');

/// Ops d'un document réduit à UNE formule bloc.
List<Map<String, dynamic>> _blockOps(String source) => <Map<String, dynamic>>[
      <String, dynamic>{
        'insert': <String, dynamic>{'latexBlock': source},
      },
      <String, dynamic>{'insert': '\n'},
    ];

/// Le `SingleChildScrollView` HORIZONTAL le plus proche de la formule.
ScrollableState _horizontalScrollableOf(WidgetTester tester) {
  final Finder scsv = find.byWidgetPredicate(
    (Widget w) =>
        w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
  );
  expect(scsv, findsOneWidget,
      reason: 'le rendu bloc doit porter UN viewport horizontal');
  return tester.state<ScrollableState>(
    find.descendant(of: scsv, matching: find.byType(Scrollable)),
  );
}

void main() {
  group('① la cellule de tableau rend NU — le tableau habille, lui seul', () {
    Future<void> pumpTable(WidgetTester tester) async {
      final Map<String, dynamic> op = zTableEmbedOp(cells: <List<String>>[
        <String>['**riche**'],
        <String>['nu'],
      ]);
      await tester.pumpWidget(_host(
        ZTableCellScope(
          content: ZTableCellContent.markdown,
          child: SingleChildScrollView(
            child: ZMarkdownReader(
              value: <Map<String, dynamic>>[
                op,
                <String, dynamic>{'insert': '\n'},
              ],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('AUCUN cadre propre sous le tableau (pas de 2e bordure)',
        (tester) async {
      await pumpTable(tester);
      // La cellule riche a bien pris le chemin riche (sinon la garde ne
      // mesurerait rien) : un QuillEditor de cellule est monté sous le Table.
      final Finder cellEditor = find.descendant(
          of: find.byType(Table), matching: find.byType(QuillEditor));
      expect(cellEditor, findsOneWidget);
      // Le chrome `bordered` du lecteur pose un DecoratedBox avec `border`.
      // Sous le tableau (qui dessine déjà sa grille), il ne doit y en avoir
      // AUCUN : c'est la double bordure concentrique constatée.
      final Finder framed = find.descendant(
        of: find.byType(Table),
        matching: find.byWidgetPredicate((Widget w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).border != null),
      );
      expect(framed, findsNothing,
          reason: 'une cellule riche ne doit porter AUCUN cadre propre');
    });

    testWidgets(
        'COHÉRENCE riche/texte pur : mêmes retraits dans une même colonne',
        (tester) async {
      await pumpTable(tester);
      final Finder cellEditor = find.descendant(
          of: find.byType(Table), matching: find.byType(QuillEditor));
      final double richStart = tester.getTopLeft(cellEditor).dx;
      final double plainStart = tester.getTopLeft(find.text('nu')).dx;
      // Le padding du chrome `bordered` décalait la cellule riche vers la
      // droite par rapport à sa voisine en texte pur : les retraits doivent
      // être IDENTIQUES (le tableau pose le même habillage aux deux chemins).
      expect(richStart, moreOrLessEquals(plainStart, epsilon: 0.01),
          reason: 'cellule riche et cellule texte pur : même retrait de début');
    });
  });

  group('② une formule bloc plus large que la place DÉFILE', () {
    testWidgets('formule large : AUCUN overflow, fin atteignable par défilement',
        (tester) async {
      await tester.pumpWidget(_host(
        Align(
          alignment: AlignmentDirectional.topStart,
          child: SizedBox(
            width: 240,
            child: ZMarkdownReader(value: _blockOps(_wideFormula)),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      // Le harnais capte tout `RIGHT OVERFLOWED` (FlutterError.onError).
      expect(tester.takeException(), isNull,
          reason: 'une formule large ne doit JAMAIS produire un overflow');
      expect(find.byType(Math), findsOneWidget);
      final ScrollableState scrollable = _horizontalScrollableOf(tester);
      final ScrollPosition position = scrollable.position;
      expect(position.maxScrollExtent, greaterThan(0),
          reason: 'la formule dépasse le viewport : il doit y avoir à défiler');
      // La FIN de la formule est atteignable — c'est elle qui était perdue.
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(position.pixels, position.maxScrollExtent);
      expect(tester.takeException(), isNull);
    });

    testWidgets('formule étroite (étalon) : rendu centré INCHANGÉ, rien à défiler',
        (tester) async {
      await tester.pumpWidget(_host(
        ZMarkdownReader(
          value: _blockOps('E = mc^2'),
          chrome: ZMarkdownReaderChrome.none,
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final Finder math = find.byType(Math);
      expect(math, findsOneWidget);
      // Étalon : une formule qui tient reste CENTRÉE sur la largeur du
      // lecteur (parité du rendu historique).
      final double readerCenter =
          tester.getCenter(find.byType(ZMarkdownReader)).dx;
      expect(tester.getCenter(math).dx,
          moreOrLessEquals(readerCenter, epsilon: 1.0),
          reason: 'une formule bloc qui tient reste centrée');
      // Et il n'y a RIEN à défiler.
      final ScrollableState scrollable = _horizontalScrollableOf(tester);
      expect(scrollable.position.maxScrollExtent, 0);
    });
  });

  group('①×② ensemble — une formule BLOC dans une CELLULE de tableau', () {
    testWidgets(
        'colonne à largeur intrinsèque + viewport horizontal : AUCUNE exception',
        (tester) async {
      // Le tableau dimensionne ses colonnes en `IntrinsicColumnWidth` : le
      // viewport horizontal du bloc y est mesuré sous contrainte NON bornée.
      // Il doit se dimensionner à la formule — jamais d'exception de layout.
      final Map<String, dynamic> op = zTableEmbedOp(cells: <List<String>>[
        <String>['\$\$$_wideFormula\$\$', 'voisine'],
      ]);
      // Surface élargie : le tableau (IntrinsicColumnWidth) se dimensionne à
      // son contenu — un tableau plus large que l'écran est un sujet distinct
      // (défilement du TABLEAU), hors du périmètre de cette garde. Ici on
      // mesure la MESURE INTRINSÈQUE du viewport horizontal dans la cellule.
      tester.view.physicalSize = const Size(4000, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_host(
        ZTableCellScope(
          content: ZTableCellContent.markdown,
          codec: ZMarkdownCodec(bridges: ZMarkdownBridges.latexBlock),
          child: SingleChildScrollView(
            child: ZMarkdownReader(
              value: <Map<String, dynamic>>[
                op,
                <String, dynamic>{'insert': '\n'},
              ],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
          reason: 'un bloc dans une cellule intrinsèque ne doit pas casser');
      // La formule est bien rendue comme formule (le pont a mordu), et la
      // cellule reste NUE (① tient aussi dans ce composé).
      expect(
          find.descendant(
              of: find.byType(Table), matching: find.byType(Math)),
          findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Table),
          matching: find.byWidgetPredicate((Widget w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).border != null),
        ),
        findsNothing,
      );
    });
  });
}
