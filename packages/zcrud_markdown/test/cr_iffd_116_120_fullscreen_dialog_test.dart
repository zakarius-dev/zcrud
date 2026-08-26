// CR-IFFD-116 (sous-titre) et CR-IFFD-120 (forçage de la présentation) du
// dialogue d'édition plein écran.
//
// Deux propriétés OBSERVABLES, mesurées au rectangle :
//   - 116 : le bloc d'en-tête gagne EXACTEMENT la hauteur d'une ligne de
//     sous-titre, et pas un pixel de plus quand le créneau est vide ;
//   - 120 : la surface du dialogue vaut le cadre entier ou 80 %×70 %.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

const String _kTitre = 'Notes de la tâche';
const String _kSousTitre = 'Préparer la revue trimestrielle';

Future<void> _pumpWidget(
  WidgetTester tester, {
  String? subtitle,
  bool fullscreen = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ZRichTextFullscreenDialog(
        initialValue: null,
        title: _kTitre,
        subtitle: subtitle,
        fullscreen: fullscreen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Bas du bloc d'en-tête du dialogue dimensionné : l'écarteur de 12 dp posé
/// entre l'en-tête et le corps. Mesuré, pas supposé.
double _headerBottom(WidgetTester tester) => tester
    .getRect(
      find
          .byWidgetPredicate((Widget w) => w is SizedBox && w.height == 12)
          .first,
    )
    .top;

void main() {
  group('CR-116 INERTIE — `subtitle` absent ⇒ pas un pixel de plus', () {
    testWidgets('l\'en-tête ne mesure QUE la hauteur du titre', (
      WidgetTester tester,
    ) async {
      await _pumpWidget(tester);
      final Rect titre = tester.getRect(find.text(_kTitre));
      expect(_headerBottom(tester) - titre.top, closeTo(titre.height, 0.5),
          reason: 'aucune Column ni boîte vide interposée');
    });

    testWidgets('aucun second texte n\'est peint dans l\'en-tête', (
      WidgetTester tester,
    ) async {
      await _pumpWidget(tester);
      final Rect titre = tester.getRect(find.text(_kTitre));
      for (final Text t in tester.widgetList<Text>(find.byType(Text))) {
        final String? d = t.data;
        if (d == null || d == _kTitre) continue;
        final Rect r = tester.getRect(find.text(d).first);
        expect(r.top, greaterThanOrEqualTo(titre.bottom),
            reason: 'rien ne s\'est glissé au niveau du titre : « $d »');
      }
    });

    testWidgets('barre plein cadre : la hauteur d\'app-bar est inchangée', (
      WidgetTester tester,
    ) async {
      await _pumpWidget(tester, fullscreen: true);
      final double sans = tester.getSize(find.byType(AppBar)).height;
      expect(sans, kToolbarHeight);
    });
  });

  group('CR-116 EFFET — le sous-titre, SOUS le titre et sur UNE ligne', () {
    testWidgets('dialogue dimensionné : +1 ligne exactement, et en dessous', (
      WidgetTester tester,
    ) async {
      await _pumpWidget(tester);
      final Rect titreSeul = tester.getRect(find.text(_kTitre));
      final double enteteSeul = _headerBottom(tester) - titreSeul.top;

      await _pumpWidget(tester, subtitle: _kSousTitre);
      final Rect titre = tester.getRect(find.text(_kTitre));
      // Le sous-titre doit être PEINT : sans cette assertion, son absence
      // ferait échouer le finder (erreur d'état) au lieu de faire mordre la
      // garde — un rouge qui ne DIT rien.
      expect(find.text(_kSousTitre), findsOneWidget);
      final Rect sous = tester.getRect(find.text(_kSousTitre));
      // SOUS le titre — pas à côté, pas fondu dedans.
      expect(sous.top, greaterThanOrEqualTo(titre.bottom - 0.5));
      expect(sous.left, closeTo(titre.left, 0.5));
      // QUANTITÉ : l'en-tête grandit de la hauteur du sous-titre, ni plus.
      final double entete = _headerBottom(tester) - titre.top;
      expect(entete - enteteSeul, closeTo(sous.height, 0.5));
      // Plus petit que le titre (hiérarchie typographique réellement rendue).
      expect(sous.height, lessThan(titre.height));
    });

    testWidgets('barre plein cadre : rendu sous le titre, app-bar intacte', (
      WidgetTester tester,
    ) async {
      await _pumpWidget(tester, subtitle: _kSousTitre, fullscreen: true);
      final Rect titre = tester.getRect(find.text(_kTitre));
      // Le sous-titre doit être PEINT : sans cette assertion, son absence
      // ferait échouer le finder (erreur d'état) au lieu de faire mordre la
      // garde — un rouge qui ne DIT rien.
      expect(find.text(_kSousTitre), findsOneWidget);
      final Rect sous = tester.getRect(find.text(_kSousTitre));
      expect(sous.top, greaterThanOrEqualTo(titre.bottom - 0.5));
      expect(tester.getSize(find.byType(AppBar)).height, kToolbarHeight);
    });

    testWidgets('tronqué à UNE ligne : 300 caractères ne poussent rien', (
      WidgetTester tester,
    ) async {
      await _pumpWidget(tester, subtitle: _kSousTitre);
      expect(find.text(_kSousTitre), findsOneWidget);
      final double court = tester.getRect(find.text(_kSousTitre)).height;
      final String long = 'a' * 300;
      await _pumpWidget(tester, subtitle: long);
      expect(find.text(long), findsOneWidget);
      expect(tester.getRect(find.text(long)).height, closeTo(court, 0.5),
          reason: 'maxLines: 1 + ellipsis — la hauteur ne bouge pas');
    });
  });

  group('CR-120 — forcer la présentation depuis le helper', () {
    /// Surface RÉELLE du dialogue : la boîte du `Material` que pose sa
    /// présentation. Plein cadre ⇒ l'écran entier ; centré ⇒ 80 %×70 %.
    Future<Size> ouvrir(WidgetTester tester, Size ecran, bool? forcage) async {
      tester.view.physicalSize = ecran;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext c) => TextButton(
                onPressed: () => showZRichTextFullscreenDialog(
                  c,
                  initialValue: null,
                  title: _kTitre,
                  fullscreen: forcage,
                ),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
      expect(find.byType(ZRichTextFullscreenDialog), findsOneWidget);
      return tester.getSize(
        find
            .descendant(
              of: find.byType(ZRichTextFullscreenDialog),
              matching: find.byType(Material),
            )
            .first,
      );
    }

    testWidgets('INERTIE — grand écran sans forçage : centré 80 %×70 %', (
      WidgetTester tester,
    ) async {
      expect(await ouvrir(tester, const Size(1000, 800), null),
          const Size(800, 560));
    });

    testWidgets('INERTIE — petit écran sans forçage : plein cadre', (
      WidgetTester tester,
    ) async {
      expect(await ouvrir(tester, const Size(400, 800), null),
          const Size(400, 800));
    });

    testWidgets('EFFET — `true` prend le cadre entier sur un GRAND écran', (
      WidgetTester tester,
    ) async {
      expect(await ouvrir(tester, const Size(1000, 800), true),
          const Size(1000, 800));
    });

    // 590 dp : sous le seuil de 600, l'arbitrage automatique bascule en plein
    // cadre. Les deux tests suivants opposent ce défaut au forçage sur le MÊME
    // écran — un seul dialogue par test, la route précédente survivrait à un
    // second montage et la garde mesurerait deux fois le même arbre (mesuré).
    testWidgets('INERTIE — 590 dp sans forçage : plein cadre', (
      WidgetTester tester,
    ) async {
      expect(await ouvrir(tester, const Size(590, 900), null),
          const Size(590, 900));
    });

    testWidgets('EFFET — `false` garde le dialogue centré SOUS le seuil', (
      WidgetTester tester,
    ) async {
      expect(await ouvrir(tester, const Size(590, 900), false),
          const Size(472, 630));
    });
  });
}
