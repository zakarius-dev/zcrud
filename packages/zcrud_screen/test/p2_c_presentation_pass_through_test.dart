/// Gardes des **passe-plats de présentation** de `presentFormEdition` :
/// bornes (`maxWidth`/`maxHeight`), décor de la voie feuille (`sheetFrame`) et
/// bouton flottant de la voie page (`floatingActionButton`).
///
/// Ordre de construction (discipline du lot) : la garde d'INERTIE (a) a été
/// écrite et rendue verte **avant** toute modification de `lib/` — les étalons
/// `test/support/p2_c_*_tree_reference.txt` sont donc le rendu du code
/// antérieur, relevé nœud pour nœud. Les gardes (b), (c) et (d) ne sont
/// arrivées qu'ensuite, une par une, chacune avec son injection R3.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_navigation/zcrud_navigation.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

import 'support/p2_c_tree.dart';

/// Catalogue minimal : deux champs à plat, aucun validateur — l'arbre figé ne
/// dépend d'aucune règle de validation.
const List<ZFieldSpec> _fields = <ZFieldSpec>[
  ZFieldSpec(name: 'nom', type: EditionFieldType.text, label: 'Nom'),
  ZFieldSpec(name: 'quai', type: EditionFieldType.text, label: 'Quai'),
];

/// Corps volontairement PLUS GRAND que toute borne mesurée : sans lui, une
/// borne pourrait passer pour honorée alors que c'est le contenu qui est
/// petit. La mesure porte donc sur la contrainte, jamais sur le contenu.
Widget _oversizedBody(BuildContext context, ZFormOnlyController controller) =>
    const SizedBox(width: 2000, height: 2000);

/// Écran hôte ouvrant la fenêtre avec les slots par voie déclarés.
Widget _slotHost(
  ZEditionPresentation mode, {
  double? maxWidth,
  double? maxHeight,
  ZFormSheetFrame? sheetFrame,
  Widget? floatingActionButton,
  ZFormBodyBuilder? bodyBuilder,
}) =>
    Scaffold(
      body: Builder(
        builder: (BuildContext context) => TextButton(
          onPressed: () => presentFormEdition(
            context,
            fields: _fields,
            title: 'Titre',
            forcedMode: mode,
            maxWidth: maxWidth,
            maxHeight: maxHeight,
            sheetFrame: sheetFrame,
            floatingActionButton: floatingActionButton,
            bodyBuilder: bodyBuilder,
          ),
          child: const Text('ouvrir'),
        ),
      ),
    );

/// Marqueur du décor de feuille : un `StatelessWidget` qui rend son enfant
/// **tel quel**, donc dont l'élément est l'ancêtre DIRECT du corps.
class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// Widget du parent immédiat de [finder] dans l'arbre d'éléments.
Widget _directParentOf(WidgetTester tester, Finder finder) {
  Element? parent;
  tester.element(finder).visitAncestorElements((Element e) {
    parent = e;
    return false;
  });
  return parent!.widget;
}

/// Écran hôte : un bouton qui ouvre la fenêtre d'édition sur [mode].
Widget _host(
  ZEditionPresentation mode, {
  Widget extra = const SizedBox.shrink(),
}) =>
    Scaffold(
      body: Builder(
        builder: (BuildContext context) => Column(
          children: <Widget>[
            TextButton(
              onPressed: () => presentFormEdition(
                context,
                fields: _fields,
                title: 'Titre',
                forcedMode: mode,
              ),
              child: const Text('ouvrir'),
            ),
            extra,
          ],
        ),
      ),
    );

Future<void> _pumpAndOpen(WidgetTester tester, Widget home) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.padding = FakeViewPadding.zero;
  tester.view.viewInsets = FakeViewPadding.zero;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: home));
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
}

void main() {
  group('(a) INERTIE ABSOLUE — aucun paramètre nouveau, arbre identique', () {
    for (final (String name, ZEditionPresentation mode) in const <(
      String,
      ZEditionPresentation
    )>[
      ('page', ZEditionPresentation.page),
      ('sheet', ZEditionPresentation.sheet),
      ('dialog', ZEditionPresentation.dialog),
    ]) {
      testWidgets('voie $name : arbre strictement égal à l\'étalon',
          (WidgetTester tester) async {
        await _pumpAndOpen(tester, _host(mode));
        p2cExpectFrozenTree(
          'test/support/p2_c_present_form_edition_$name.txt',
          p2cSerializeTree(tester, find.byType(Navigator).first),
          what: 'presentFormEdition en voie $name',
        );
      });
    }

    testWidgets('NON-VACUITÉ : le sérialiseur DISTINGUE un nœud de plus',
        (WidgetTester tester) async {
      await _pumpAndOpen(
        tester,
        _host(
          ZEditionPresentation.dialog,
          extra: const SizedBox(width: 3, height: 3),
        ),
      );
      // Sans ce volet, la garde ci-dessus pourrait tout accepter : on prouve
      // qu'UN `SizedBox` de plus dans l'écran hôte suffit à faire diverger la
      // sérialisation de l'étalon.
      final String withExtra =
          p2cSerializeTree(tester, find.byType(Navigator).first);
      expect(withExtra, contains('SizedBox sz=3.0x3.0'));
      expect(
        withExtra,
        isNot(
          equals(
            File('test/support/p2_c_present_form_edition_dialog.txt')
                .readAsStringSync(),
          ),
        ),
      );
    });
  });

  group('(b) BORNES — égalité stricte, pas une majoration', () {
    testWidgets('dialogue : maxWidth 480 sur fenêtre de 1600 ⇒ largeur = 480',
        (WidgetTester tester) async {
      await _pumpAndOpen(
        tester,
        _slotHost(
          ZEditionPresentation.dialog,
          maxWidth: 480,
          bodyBuilder: _oversizedBody,
        ),
      );
      expect(
        tester.getRect(find.byType(ZEditionScaffold)).width,
        480.0,
      );
    });

    testWidgets('dialogue : maxHeight 300 sur fenêtre de 1200 ⇒ hauteur = 300',
        (WidgetTester tester) async {
      await _pumpAndOpen(
        tester,
        _slotHost(
          ZEditionPresentation.dialog,
          maxHeight: 300,
          bodyBuilder: _oversizedBody,
        ),
      );
      expect(
        tester.getRect(find.byType(ZEditionScaffold)).height,
        300.0,
      );
    });

    testWidgets('feuille : maxWidth 480 ⇒ largeur = 480',
        (WidgetTester tester) async {
      await _pumpAndOpen(
        tester,
        _slotHost(
          ZEditionPresentation.sheet,
          maxWidth: 480,
          bodyBuilder: _oversizedBody,
        ),
      );
      expect(
        tester.getRect(find.byType(ZEditionScaffold)).width,
        480.0,
      );
    });

    testWidgets(
        'page : INERTIE DÉCLARÉE — la borne ne rétrécit pas la route pleine',
        (WidgetTester tester) async {
      await _pumpAndOpen(
        tester,
        _slotHost(
          ZEditionPresentation.page,
          maxWidth: 480,
          bodyBuilder: _oversizedBody,
        ),
      );
      // La table du dartdoc annonce « inerte » en page : la garde le MESURE,
      // au lieu de le supposer.
      expect(tester.getRect(find.byType(ZEditionScaffold)).width, 1600.0);
    });
  });

  group('(c) DÉCOR DE FEUILLE — sur la feuille, et nulle part ailleurs', () {
    testWidgets('feuille : le décor est l\'ancêtre DIRECT du corps',
        (WidgetTester tester) async {
      await _pumpAndOpen(
        tester,
        _slotHost(
          ZEditionPresentation.sheet,
          sheetFrame: (BuildContext context, Widget child) =>
              _Frame(child: child),
        ),
      );
      expect(find.byType(_Frame), findsOneWidget);
      expect(_directParentOf(tester, find.byType(ZFormOnly)), isA<_Frame>());
    });

    for (final (String name, ZEditionPresentation mode) in const <(
      String,
      ZEditionPresentation
    )>[
      ('page', ZEditionPresentation.page),
      ('dialog', ZEditionPresentation.dialog),
    ]) {
      testWidgets('voie $name : le décor de feuille n\'entre PAS dans l\'arbre',
          (WidgetTester tester) async {
        await _pumpAndOpen(
          tester,
          _slotHost(
            mode,
            sheetFrame: (BuildContext context, Widget child) =>
                _Frame(child: child),
          ),
        );
        expect(find.byType(ZFormOnly), findsOneWidget);
        expect(find.byType(_Frame), findsNothing);
      });
    }
  });

  group('(d) BOUTON FLOTTANT — sur la page, et nulle part ailleurs', () {
    const Key fabKey = ValueKey<String>('p2cFab');
    const Widget fab = FloatingActionButton(
      key: fabKey,
      onPressed: null,
      child: Icon(Icons.add),
    );

    testWidgets('page : le bouton est porté par un `Scaffold`',
        (WidgetTester tester) async {
      await _pumpAndOpen(
        tester,
        _slotHost(ZEditionPresentation.page, floatingActionButton: fab),
      );
      expect(find.byKey(fabKey), findsOneWidget);
      // Ancrage : le bouton est le `floatingActionButton` d'un `Scaffold`,
      // pas un widget posé n'importe où dans l'arbre.
      final Iterable<Scaffold> porteurs = tester
          .widgetList<Scaffold>(find.byType(Scaffold))
          .where((Scaffold s) => s.floatingActionButton != null);
      expect(porteurs, hasLength(1));
      expect(porteurs.single.floatingActionButton, same(fab));
    });

    for (final (String name, ZEditionPresentation mode) in const <(
      String,
      ZEditionPresentation
    )>[
      ('sheet', ZEditionPresentation.sheet),
      ('dialog', ZEditionPresentation.dialog),
    ]) {
      testWidgets('voie $name : aucun bouton flottant',
          (WidgetTester tester) async {
        await _pumpAndOpen(
          tester,
          _slotHost(mode, floatingActionButton: fab),
        );
        expect(find.byType(ZFormOnly), findsOneWidget);
        expect(find.byKey(fabKey), findsNothing);
      });
    }
  });
}
