// CR-LEX-94 — dans une cellule de 250 dp (la dimension de référence de la
// grille de dossiers, cf. `ZFolderGridReference.cellHeight`), la carte laissait
// un vide vertical ENTRE la pastille de tête et le titre : le patron
// anti-overflow ancre le bloc titre EN BAS de la hauteur résiduelle
// (`Expanded(Align(bottomStart))`, `z_folder_card.dart`).
//
// Le rendu de référence de l'hôte répartit autrement : pastille, titre et
// sous-titre solidaires EN HAUT, le vide au milieu, pied en bas.
//
// ⚠️ Le nouveau régime est OPT-IN (`bodyPlacement`) : l'ancrage bas reste le
// défaut, donc le rendu d'un hôte passif est INCHANGÉ — c'est ce que les
// gardes d'inertie ci-dessous mesurent, à hauteur libre COMME en cellule
// bornée.
//
// Bornes mesurées sur disque avant modification (cellule de 250 dp, thème nu,
// carte à pastille + titre + sous-titre + pied) : cf. les constantes locales.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_study/zcrud_study.dart';

const Key _kPastille = Key('cr94-pastille');
const Key _kSubtitle = Key('cr94-subtitle');
const Key _kFooter = Key('cr94-footer');

Widget _host({
  required double? height,
  ZFolderCardBodyPlacement? bodyPlacement,
  bool tallSubtitle = false,
}) {
  final Widget card = ZFolderCard(
    title: 'Dossier',
    colorKey: 'blue',
    headerDecoration: const SizedBox(
      key: _kPastille,
      width: 28,
      height: 28,
    ),
    belowSubtitle: SizedBox(
      key: _kSubtitle,
      height: tallSubtitle ? 60 : 14,
      width: 80,
    ),
    footer: const SizedBox(key: _kFooter, height: 16, width: 60),
    bodyPlacement: bodyPlacement,
  );
  return MaterialApp(
    home: Scaffold(
      // `height == null` ⇒ hauteur NON BORNÉE (le `SingleChildScrollView`
      // passe une contrainte verticale infinie) : c'est le seul moyen
      // d'atteindre le régime `MainAxisSize.min` de la carte. Un `Center` nu
      // passe une hauteur FINIE (celle de la fenêtre de test) — donc le régime
      // BORNÉ, où la carte s'étire sur 600 dp. Mesuré : `p→titre` y vaut 494.
      body: Center(
        child: height == null
            ? SingleChildScrollView(child: SizedBox(width: 300, child: card))
            : SizedBox(width: 300, height: height, child: card),
      ),
    ),
  );
}

Rect _rectOfKey(WidgetTester tester, Key key) =>
    tester.getRect(find.byKey(key));

Rect _titleRect(WidgetTester tester) => tester.getRect(
      find.descendant(
        of: find.byType(ZFolderCard),
        matching: find.text('Dossier'),
      ),
    );

void main() {
  group('CR-LEX-94 — répartition verticale de la carte de dossier', () {
    testWidgets(
        'INERTIE — hauteur LIBRE : rendu strictement identique avec et sans '
        'le nouveau paramètre à son défaut', (WidgetTester tester) async {
      await tester.pumpWidget(_host(height: null));
      await tester.pumpAndSettle();
      final Rect pastille = _rectOfKey(tester, _kPastille);
      final Rect title = _titleRect(tester);
      final Rect subtitle = _rectOfKey(tester, _kSubtitle);
      final Rect footer = _rectOfKey(tester, _kFooter);
      final Rect card = tester.getRect(find.byType(ZFolderCard));

      await tester.pumpWidget(
        _host(height: null, bodyPlacement: ZFolderCardBodyPlacement.bottom),
      );
      await tester.pumpAndSettle();
      // Égalité STRICTE : le défaut explicite doit rendre le pixel du défaut
      // implicite, sinon le paramètre n'est pas opt-in.
      expect(_rectOfKey(tester, _kPastille), pastille);
      expect(_titleRect(tester), title);
      expect(_rectOfKey(tester, _kSubtitle), subtitle);
      expect(_rectOfKey(tester, _kFooter), footer);
      expect(tester.getRect(find.byType(ZFolderCard)), card);
    });

    testWidgets(
        'INERTIE — cellule de 250 dp : le défaut rend EXACTEMENT l\'ancrage '
        'bas historique', (WidgetTester tester) async {
      await tester.pumpWidget(_host(height: ZFolderGridReference.cellHeight));
      await tester.pumpAndSettle();
      final Rect pastille = _rectOfKey(tester, _kPastille);
      final Rect title = _titleRect(tester);
      final Rect subtitle = _rectOfKey(tester, _kSubtitle);
      final Rect footer = _rectOfKey(tester, _kFooter);

      await tester.pumpWidget(
        _host(
          height: ZFolderGridReference.cellHeight,
          bodyPlacement: ZFolderCardBodyPlacement.bottom,
        ),
      );
      await tester.pumpAndSettle();
      expect(_rectOfKey(tester, _kPastille), pastille);
      expect(_titleRect(tester), title);
      expect(_rectOfKey(tester, _kSubtitle), subtitle);
      expect(_rectOfKey(tester, _kFooter), footer);

      // …et le SYMPTÔME de l'hôte est bien là au défaut : un vide franc entre
      // la pastille et le titre. Borne mesurée sur disque AVANT modification
      // (cellule 250 dp, thème nu) : l'écart valait 144.0 dp — pastille en
      // bas à y=211, titre en haut à y=355.
      expect(
        title.top - pastille.bottom,
        greaterThan(60),
        reason: 'le défaut historique ancre le bloc titre EN BAS — si cet '
            'écart se referme, le défaut a changé sous les hôtes passifs',
      );
    });

    testWidgets(
        'CR-94 — en cellule de 250 dp, `top` rend la tête SOLIDAIRE en haut',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          height: ZFolderGridReference.cellHeight,
          bodyPlacement: ZFolderCardBodyPlacement.top,
        ),
      );
      await tester.pumpAndSettle();

      final Rect pastille = _rectOfKey(tester, _kPastille);
      final Rect title = _titleRect(tester);
      final Rect subtitle = _rectOfKey(tester, _kSubtitle);
      final Rect footer = _rectOfKey(tester, _kFooter);
      final Rect card = tester.getRect(find.byType(ZFolderCard));

      // ① Pastille → titre CONTIGUS : l'écart ne dépasse pas l'espacement
      // nominal du thème nu (`gapS` = 4, `gapM` = 8) avec la marge de
      // l'interligne du titre. C'est la garde qui reproduit le symptôme hôte.
      expect(
        title.top - pastille.bottom,
        lessThanOrEqualTo(12),
        reason: 'tuile et titre doivent rester solidaires en haut',
      );
      // ② Titre → sous-titre également contigus.
      expect(
        subtitle.top - title.bottom,
        lessThanOrEqualTo(12),
        reason: 'titre et sous-titre doivent rester solidaires',
      );
      // ③ Le vide est ENTRE la tête et le pied, pas dans la tête.
      expect(
        footer.top - subtitle.bottom,
        greaterThan(40),
        reason: 'le vide doit se trouver au milieu, sous le bloc de tête',
      );
      // ④ La tête est bien EN HAUT de la carte.
      expect(pastille.top - card.top, lessThanOrEqualTo(24));
      // ⑤ Le pied reste EN BAS.
      expect(card.bottom - footer.bottom, lessThanOrEqualTo(24));
      // ⑥ Aucun débordement (le patron anti-overflow reste tenu).
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'CR-94 — `top` à hauteur LIBRE ne change rien : sans hauteur '
        'résiduelle, il n\'y a rien à répartir', (WidgetTester tester) async {
      await tester.pumpWidget(_host(height: null));
      await tester.pumpAndSettle();
      final Rect pastille = _rectOfKey(tester, _kPastille);
      final Rect title = _titleRect(tester);
      final Rect subtitle = _rectOfKey(tester, _kSubtitle);
      final Rect footer = _rectOfKey(tester, _kFooter);

      await tester.pumpWidget(
        _host(height: null, bodyPlacement: ZFolderCardBodyPlacement.top),
      );
      await tester.pumpAndSettle();
      expect(_rectOfKey(tester, _kPastille), pastille);
      expect(_titleRect(tester), title);
      expect(_rectOfKey(tester, _kSubtitle), subtitle);
      expect(_rectOfKey(tester, _kFooter), footer);
    });

    testWidgets(
        'CR-94 — cellule SERRÉE : `top` tient le patron anti-overflow',
        (WidgetTester tester) async {
      // Contenu naturel volontairement PLUS HAUT que la cellule : padding
      // 8+8 + pastille 28 + gapS 4 + titre 24 + gapS 4 + sous-titre 60 +
      // gapS 4 + pied 16 ≈ 156 dp pour une cellule de 100 dp. Sans le régime
      // borné (titre plafonné, sous-titre `Flexible`), la colonne déborde.
      await tester.pumpWidget(
        _host(
          height: 100,
          tallSubtitle: true,
          bodyPlacement: ZFolderCardBodyPlacement.top,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'ancré en haut, la carte doit rester bornée — jamais un '
            'RenderFlex overflowed',
      );

      // Le défaut, lui, tient déjà : `top` ne doit rien lui retirer.
      await tester.pumpWidget(_host(height: 100, tallSubtitle: true));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
