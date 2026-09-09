/// 🔴 La PILE de session : la carte de devant remplit sa cellule, et il ne
/// reste de la suivante qu'un liseré de profondeur.
///
/// Le défaut MESURÉ que cette suite ferme : le paquet tiers impose à chaque
/// carte la hauteur exacte de sa cellule, mais le `Stack` que la pile bâtit
/// autour de chaque carte la DESSERRAIT (`StackFit.loose`). Une carte qui se
/// dimensionne sur son contenu restait donc collée en haut, laissant le reste
/// de la cellule vide — et la carte SUIVANTE s'y voyait en entier.
///
/// Ce que la garde mesure : des RECTANGLES (`getRect`) et l'ordre de peinture.
/// Aucune capture de pixels (`toImage` pend sous ce harnais).
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_session/zcrud_session.dart';

import 'z_swiper_harness.dart';

const double _hauteurHote = 600;
const double _largeurHote = 400;

List<ZSessionItem> _queue(int n) => <ZSessionItem>[
  for (var i = 0; i < n; i++) ZSessionItem(flashcardId: 'f$i', folderId: 'd1'),
];

/// Carte qui se dimensionne sur SON CONTENU — le cas du défaut.
Widget _carteContenu(BuildContext context, ZSessionItem item, double hauteur) =>
    ColoredBox(
      key: ValueKey<String>('card_${item.flashcardId}'),
      color: const Color(0xFF112233),
      child: SizedBox(height: hauteur, width: 300),
    );

Future<void> _monte(WidgetTester tester, ZSessionCardBuilder builder) async {
  await tester.pumpWidget(
    wrapApp(
      SizedBox(
        height: _hauteurHote,
        width: _largeurHote,
        child: ZSessionCardSwiper(
          queue: _queue(2),
          passThreshold: 3,
          cardBuilder: builder,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Rect _rect(WidgetTester tester, String id) =>
    tester.getRect(find.byKey(ValueKey<String>('card_$id')));

void main() {
  group('🔴 la carte de devant REMPLIT sa cellule', () {
    testWidgets(
      'carte de devant COURTE, carte suivante LONGUE : la suivante ne déborde '
      'que du liseré de profondeur',
      (tester) async {
        await _monte(
          tester,
          (context, item) => _carteContenu(
            context,
            item,
            item.flashcardId == 'f0' ? 100 : 500,
          ),
        );

        final Rect devant = _rect(tester, 'f0');
        final Rect dessous = _rect(tester, 'f1');

        // 1. La carte de devant occupe TOUTE la hauteur de sa cellule.
        //    (Avant le correctif : 100 dp mesurés dans une cellule de 528.)
        final double cellule = tester
            .getSize(find.byType(ZSessionCardSwiper))
            .height;
        expect(
          devant.height,
          greaterThan(_hauteurHote * 0.7),
          reason:
              '🔴 la carte de devant se dimensionne sur son contenu : le bas '
              'de sa cellule est VIDE, et la carte suivante s\'y voit en '
              'entier (cellule mesurée : $cellule)',
        );

        // 2. Ce qui dépasse de la carte suivante SOUS la carte de devant est
        //    un liseré, pas une carte. Le décalage du paquet vaut 40 dp :
        //    au-delà, c'est du contenu qui se montre.
        final double debord = dessous.bottom - devant.bottom;
        expect(
          debord,
          lessThanOrEqualTo(40),
          reason:
              '🔴 $debord dp de la carte SUIVANTE sont peints sous la carte '
              'de devant — ce n\'est plus une profondeur, c\'est une seconde '
              'carte à l\'écran',
        );
        expect(
          debord,
          greaterThan(0),
          reason:
              'la profondeur EXISTE : une pile dont on ne voit aucun bord ne '
              'se lit plus comme une pile',
        );
      },
    );

    testWidgets(
      '🔴 la carte de devant est peinte APRÈS la suivante (elle la couvre)',
      (tester) async {
        await _monte(
          tester,
          (context, item) => _carteContenu(
            context,
            item,
            item.flashcardId == 'f0' ? 100 : 500,
          ),
        );

        // L'ordre de parcours de l'arbre est l'ordre de peinture des enfants
        // d'un `Stack` : la carte de devant doit venir en DERNIER.
        final List<Widget> tous = tester.allWidgets.toList();
        final int devant = tous.indexWhere(
          (Widget w) => w.key == const ValueKey<String>('card_f0'),
        );
        final int dessous = tous.indexWhere(
          (Widget w) => w.key == const ValueKey<String>('card_f1'),
        );
        expect(devant, isNot(-1));
        expect(dessous, isNot(-1));
        expect(
          devant,
          greaterThan(dessous),
          reason:
              '🔴 la carte SUIVANTE est peinte par-dessus la carte de devant : '
              'son contenu recouvrirait celui qu\'on est en train de lire',
        );
      },
    );
  });

  group('🧊 inertie STRICTE : cartes de même hauteur', () {
    testWidgets(
      'deux cartes qui remplissaient déjà leur cellule ne bougent pas d\'un dp',
      (tester) async {
        // `SizedBox.expand` remplit la cellule : c'est exactement le cas où
        // le desserrage n'avait aucun effet. La géométrie doit donc être
        // INCHANGÉE par le correctif.
        await _monte(
          tester,
          (context, item) => SizedBox.expand(
            key: ValueKey<String>('card_${item.flashcardId}'),
            child: const ColoredBox(color: Color(0xFF112233)),
          ),
        );

        // Comparaison composante par composante : `Rect ==` est une égalité
        // de flottants, qui échoue sur une différence invisible à
        // l'affichage — la garde rougirait alors sans qu'aucun dp n'ait bougé.
        void memeRect(Rect obtenu, Rect attendu, String quoi) {
          expect(obtenu.left, closeTo(attendu.left, 1e-6), reason: quoi);
          expect(obtenu.top, closeTo(attendu.top, 1e-6), reason: quoi);
          expect(obtenu.right, closeTo(attendu.right, 1e-6), reason: quoi);
          expect(obtenu.bottom, closeTo(attendu.bottom, 1e-6), reason: quoi);
        }

        memeRect(
          _rect(tester, 'f0'),
          const Rect.fromLTRB(8, 8, 392, 536),
          "🔴 la carte de devant a bougé alors qu'elle remplissait déjà sa "
          'cellule',
        );
        memeRect(
          _rect(tester, 'f1'),
          const Rect.fromLTRB(27.2, 74.4, 372.8, 549.6),
          "🔴 la carte de fond a bougé alors que rien ne l'exigeait",
        );
      },
    );
  });
}
