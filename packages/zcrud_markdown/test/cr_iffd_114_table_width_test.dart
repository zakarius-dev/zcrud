// CR-IFFD-114 — la géométrie du TABLEAU rendu : `ZTableWidthScope`.
//
// La propriété promise n'est pas « un widget de défilement est là » : c'est que
// la fin d'un tableau trop large DEVIENT ATTEIGNABLE. On mesure donc des
// RECTANGLES et un déplacement réel sous le doigt — pas la présence d'un nœud.
@TestOn('vm')
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

/// Cadre volontairement ÉTROIT : c'est la surface contrainte du relevé.
const double _kCadre = 300;

/// Cellules sans césure possible (aucune espace) ⇒ la largeur intrinsèque
/// MINIMALE d'une colonne vaut celle de son mot : le tableau ne peut pas se
/// rétracter sous le cadre, il déborde. C'est le cas du relevé.
const String _kTableau = '| entete_colonne_un | entete_colonne_deux | '
    'entete_colonne_trois |\n'
    '| --- | --- | --- |\n'
    '| valeur_alpha_1111 | valeur_beta_2222 | valeur_omega_3333 |';

/// Dernière cellule de la dernière colonne — celle que l'écrêtement mange.
const String _kDerniereCellule = 'valeur_omega_3333';

Future<void> _pump(WidgetTester tester, {ZTableWidth? width}) async {
  const Widget lecteur = ZMarkdownReader(
    value: _kTableau,
    codec: ZMarkdownCodec(),
    chrome: ZMarkdownReaderChrome.none,
    placeholder: '',
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: AlignmentDirectional.topStart,
          child: SizedBox(
            width: _kCadre,
            child: width == null
                ? lecteur
                : ZTableWidthScope(width: width, child: lecteur),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Rect _tableRect(WidgetTester tester) => tester.getRect(find.byType(Table));

void main() {
  group('INERTIE — scope absent ⇒ géométrie de l\'avant-lot', () {
    test('la politique héritée par défaut est `intrinsic`', () {
      expect(ZTableWidth.values.first, ZTableWidth.intrinsic);
    });

    testWidgets('le tableau est BORNÉ au cadre : sa boîte ne dépasse pas', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      // La boîte du `Table` est contrainte par le cadre — c'est précisément
      // ce qui écrête ses dernières colonnes.
      expect(_tableRect(tester).width, _kCadre);
    });

    testWidgets('rien ne défile : la dernière cellule ne bouge pas d\'un dp', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      final Rect avant = tester.getRect(find.text(_kDerniereCellule));
      // Le geste part d'un point DANS le cadre : hors du cadre, il ne
      // toucherait rien et la garde serait muette (mesuré).
      await tester.dragFrom(const Offset(150, 26), const Offset(-150, 0));
      await tester.pumpAndSettle();
      final Rect apres = tester.getRect(find.text(_kDerniereCellule));
      expect(apres.left, avant.left,
          reason: 'sans scope, aucun viewport : le geste est inerte');
    });
  });

  group('EFFET — `scrollable` ⇒ la fin redevient ATTEIGNABLE', () {
    testWidgets('le tableau reprend sa largeur au contenu (> cadre)', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      final double borne = _tableRect(tester).width;
      await _pump(tester, width: ZTableWidth.scrollable);
      final double libre = _tableRect(tester).width;
      expect(libre, greaterThan(borne),
          reason: 'le viewport rend la largeur au contenu');
      expect(libre, greaterThan(_kCadre));
    });

    testWidgets('la course offerte vaut EXACTEMENT ce qui dépassait', (
      WidgetTester tester,
    ) async {
      await _pump(tester, width: ZTableWidth.scrollable);
      final ScrollableState scroll = tester.state<ScrollableState>(
        find.byType(Scrollable),
      );
      expect(scroll.position.axis, Axis.horizontal);
      expect(
        scroll.position.maxScrollExtent,
        closeTo(_tableRect(tester).width - _kCadre, 0.5),
        reason: 'ni plus ni moins que le débordement',
      );
    });

    testWidgets('la dernière cellule, HORS cadre, entre par le défilement', (
      WidgetTester tester,
    ) async {
      await _pump(tester, width: ZTableWidth.scrollable);
      final Rect avant = tester.getRect(find.text(_kDerniereCellule));
      // Hors du cadre : c'est la donnée que l'utilisateur ne voyait pas.
      expect(avant.right, greaterThan(_kCadre));

      final ScrollableState scroll = tester.state<ScrollableState>(
        find.byType(Scrollable),
      );
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final Rect apres = tester.getRect(find.text(_kDerniereCellule));
      expect(apres.right, lessThanOrEqualTo(_kCadre + 0.5),
          reason: 'en bout de course, la dernière colonne est DANS le cadre');
    });

    testWidgets('le GESTE la ramène : glisser sur la zone visible défile', (
      WidgetTester tester,
    ) async {
      await _pump(tester, width: ZTableWidth.scrollable);
      final Rect avant = tester.getRect(find.text(_kDerniereCellule));
      await tester.dragFrom(const Offset(150, 26), const Offset(-150, 0));
      await tester.pumpAndSettle();
      final Rect apres = tester.getRect(find.text(_kDerniereCellule));
      // QUANTITÉ : la course parcourue vaut le glissement, moins le seuil de
      // reconnaissance du geste (`kTouchSlop`).
      expect(avant.left - apres.left, closeTo(150 - kTouchSlop, 2));
    });

    testWidgets('un tableau ÉTROIT cesse d\'être étiré : conséquence assumée', (
      WidgetTester tester,
    ) async {
      const String petit = '| a | b |\n| --- | --- |\n| 1 | 2 |';
      Future<void> pump(ZTableWidth? w) async {
        const Widget lecteur = ZMarkdownReader(
          value: petit,
          codec: ZMarkdownCodec(),
          chrome: ZMarkdownReaderChrome.none,
          placeholder: '',
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: AlignmentDirectional.topStart,
                child: SizedBox(
                  width: _kCadre,
                  child: w == null
                      ? lecteur
                      : ZTableWidthScope(width: w, child: lecteur),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pump(null);
      // Sans scope, un petit tableau est ÉTIRÉ jusqu'aux bords du cadre.
      expect(_tableRect(tester).width, _kCadre);
      await pump(ZTableWidth.scrollable);
      // Avec, il se dimensionne à son contenu — c'est le prix documenté du
      // viewport, et la garde le fige pour que personne ne le découvre.
      expect(_tableRect(tester).width, lessThan(_kCadre));
    });
  });
}
