/// Les 4 jetons du **CADRE** du composer (`chatComposerFill`,
/// `chatComposerBorderColor`, `chatComposerBorderWidth`, `chatComposerRadius`)
/// et leurs règles de transition.
///
/// Le câblage aux 4 sites (déclaration / constructeur / `copyWith` / `lerp`)
/// est tenu STRUCTURELLEMENT par `z_theme_four_sites_guard_test.dart` ; ici on
/// mesure les PROPRIÉTÉS que la structure ne dit pas :
///
/// * **F-L1** — l'ÉPAISSEUR du filet est un PLANCHER : `null ↔ v` rend `v`,
///   jamais un intermédiaire descendu vers `0`. Le générique
///   `_lerpNullableDouble` rendrait `0` — soit un CONTOUR PERDU le temps de la
///   transition, pas un trait qui s'affine.
/// * **F-L2** — les deux COULEURS s'interpolent comme leurs voisines
///   nullables, et un côté `null` ne fait pas lever.
/// * **F-L3** — le RAYON suit le patron commun des rayons nullables.
/// * **F-N** — `null` des deux côtés RESTE `null` : la référence du
///   consommateur n'est jamais matérialisée par une transition de thème.
/// * **F-D** — NON-RÉGRESSION DU DÉFAUT : les 4 jetons sont ABSENTS de la
///   palette de repli et d'un thème par défaut. Un hôte passif ne voit rien
///   changer — c'est ce volet qui le prouve, pas le handoff.
/// * **F-C** — `copyWith` transporte chaque jeton (valeur, omission, et
///   argument réellement PASSÉ).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  const ZcrudTheme empty = ZcrudTheme();

  group('F-L1 — épaisseur du filet : PLANCHER, jamais 0 en transition', () {
    test('null ↔ 1.5 rend 1.5 à tout t, dans les deux sens', () {
      const ZcrudTheme b = ZcrudTheme(chatComposerBorderWidth: 1.5);
      for (final double t in <double>[0, .25, .5, .75, 1]) {
        expect(
          empty.lerp(b, t).chatComposerBorderWidth,
          1.5,
          reason: '🔴 t=$t : un côté null doit rendre l\'AUTRE côté — un lerp '
              'depuis 0 efface le filet le temps de la transition',
        );
        expect(b.lerp(empty, t).chatComposerBorderWidth, 1.5,
            reason: '🔴 t=$t : sens inverse');
      }
    });

    test('deux épaisseurs CONNUES s\'interpolent réellement', () {
      const ZcrudTheme a = ZcrudTheme(chatComposerBorderWidth: 1);
      const ZcrudTheme b = ZcrudTheme(chatComposerBorderWidth: 3);
      expect(a.lerp(b, .5).chatComposerBorderWidth, 2,
          reason: '🔴 le repli « rendre l\'autre côté » ne doit pas avoir '
              'remplacé l\'interpolation des cas pleins');
    });
  });

  group('F-L2 — couleurs du cadre : interpolées comme leurs voisines', () {
    test('fill et borderColor s\'interpolent entre deux valeurs connues', () {
      const ZcrudTheme a = ZcrudTheme(
        chatComposerFill: Color(0xFF000000),
        chatComposerBorderColor: Color(0xFF000000),
      );
      const ZcrudTheme b = ZcrudTheme(
        chatComposerFill: Color(0xFFFFFFFF),
        chatComposerBorderColor: Color(0xFFFFFFFF),
      );
      final ZcrudTheme mid = a.lerp(b, .5);
      expect(mid.chatComposerFill,
          Color.lerp(const Color(0xFF000000), const Color(0xFFFFFFFF), .5),
          reason: '🔴 le fond du cadre doit s\'interpoler comme '
              '`chatComposerActiveAccent`, sa voisine de même type');
      expect(mid.chatComposerBorderColor,
          Color.lerp(const Color(0xFF000000), const Color(0xFFFFFFFF), .5));
    });

    test('un côté null ne fait pas lever et rend une couleur atténuée', () {
      const ZcrudTheme b = ZcrudTheme(
        chatComposerFill: Color(0xFF123456),
        chatComposerBorderColor: Color(0xFF654321),
      );
      final ZcrudTheme mid = empty.lerp(b, .5);
      expect(mid.chatComposerFill,
          Color.lerp(null, const Color(0xFF123456), .5),
          reason: '🔴 même régime que les autres teintes nullables du thème');
      expect(mid.chatComposerBorderColor,
          Color.lerp(null, const Color(0xFF654321), .5));
      // Et le sens inverse ne lève pas davantage.
      expect(b.lerp(empty, .5).chatComposerFill, isNotNull);
    });
  });

  group('F-L3 — rayon du cadre : patron des rayons nullables', () {
    test('deux rayons connus s\'interpolent', () {
      const ZcrudTheme a = ZcrudTheme(
        chatComposerRadius: Radius.circular(8),
      );
      const ZcrudTheme b = ZcrudTheme(
        chatComposerRadius: Radius.circular(24),
      );
      expect(a.lerp(b, .5).chatComposerRadius, const Radius.circular(16));
    });

    test('un côté null rend le rayon atténué, sans lever', () {
      const ZcrudTheme b = ZcrudTheme(
        chatComposerRadius: Radius.circular(24),
      );
      expect(empty.lerp(b, .5).chatComposerRadius,
          Radius.lerp(Radius.zero, const Radius.circular(24), .5),
          reason: '🔴 le rayon doit suivre le patron commun '
              '`_lerpNullableRadius` des autres rayons du thème');
    });
  });

  group('F-N — null des deux côtés RESTE null', () {
    test('la référence du consommateur n\'est jamais matérialisée', () {
      for (final double t in <double>[0, .5, 1]) {
        final ZcrudTheme mid = empty.lerp(const ZcrudTheme(), t);
        expect(mid.chatComposerFill, isNull, reason: '🔴 t=$t');
        expect(mid.chatComposerBorderColor, isNull, reason: '🔴 t=$t');
        expect(mid.chatComposerBorderWidth, isNull, reason: '🔴 t=$t');
        expect(mid.chatComposerRadius, isNull, reason: '🔴 t=$t');
      }
    });
  });

  group('F-D — NON-RÉGRESSION : le cadre est ABSENT du défaut', () {
    // Le défaut visé : un jeton neuf qui, posé dans la palette de repli ou
    // dérivé du `ColorScheme`, ferait bouger un hôte PASSIF — celui qui n'a
    // rien déclaré. C'est ce volet, pas le handoff, qui autorise à écrire
    // « rendu strictement inchangé ».
    for (final Brightness b in Brightness.values) {
      test('la palette de repli ($b) ne pose AUCUN des 4 jetons', () {
        final ZcrudTheme fb = ZcrudTheme.fallback(
          ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF3355AA),
              brightness: b,
            ),
          ),
        );
        expect(fb.chatComposerFill, isNull,
            reason: '🔴 un fond de cadre dérivé du `ColorScheme` repeindrait '
                'le composer d\'un hôte qui n\'a rien demandé');
        expect(fb.chatComposerBorderColor, isNull,
            reason: '🔴 un filet posé par le repli DESSINE un contour neuf');
        expect(fb.chatComposerBorderWidth, isNull);
        expect(fb.chatComposerRadius, isNull);
      });
    }

    test('un `ZcrudTheme()` par défaut les rend nuls', () {
      expect(empty.chatComposerFill, isNull);
      expect(empty.chatComposerBorderColor, isNull);
      expect(empty.chatComposerBorderWidth, isNull);
      expect(empty.chatComposerRadius, isNull);
    });

    testWidgets('hôte PASSIF : `ZcrudTheme.of` ne matérialise rien', (
      WidgetTester tester,
    ) async {
      late ZcrudTheme resolved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              resolved = ZcrudTheme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolved.chatComposerFill, isNull,
          reason: '🔴 c\'est l\'API que le consommateur appelle réellement : '
              'un hôte sans extension déclarée doit lire `null` partout');
      expect(resolved.chatComposerBorderColor, isNull);
      expect(resolved.chatComposerBorderWidth, isNull);
      expect(resolved.chatComposerRadius, isNull);
    });
  });

  group('F-C — copyWith transporte les 4 jetons du cadre', () {
    const ZcrudTheme full = ZcrudTheme(
      chatComposerFill: Color(0xFF101112),
      chatComposerBorderColor: Color(0xFF131415),
      chatComposerBorderWidth: 1.5,
      chatComposerRadius: Radius.circular(28),
    );

    test('une copie SANS argument conserve chaque valeur', () {
      final ZcrudTheme copy = full.copyWith();
      expect(copy.chatComposerFill, const Color(0xFF101112));
      expect(copy.chatComposerBorderColor, const Color(0xFF131415));
      expect(copy.chatComposerBorderWidth, 1.5);
      expect(copy.chatComposerRadius, const Radius.circular(28));
    });

    test('une copie par ARGUMENTS pose chaque jeton', () {
      // 🔴 Sans ce volet, un `copyWith` qui écrirait `this.x` en IGNORANT
      // l'argument `x` resterait vert : la copie sans argument conserve, et la
      // garde structurelle des 4 sites voit bien `x:` présent.
      final ZcrudTheme copy = empty.copyWith(
        chatComposerFill: const Color(0xFF101112),
        chatComposerBorderColor: const Color(0xFF131415),
        chatComposerBorderWidth: 1.5,
        chatComposerRadius: const Radius.circular(28),
      );
      expect(copy.chatComposerFill, const Color(0xFF101112));
      expect(copy.chatComposerBorderColor, const Color(0xFF131415));
      expect(copy.chatComposerBorderWidth, 1.5);
      expect(copy.chatComposerRadius, const Radius.circular(28));
    });

    test('une copie CIBLÉE ne touche que son jeton', () {
      final ZcrudTheme copy = empty.copyWith(chatComposerBorderWidth: 2);
      expect(copy.chatComposerBorderWidth, 2);
      expect(copy.chatComposerFill, isNull);
      expect(copy.chatComposerBorderColor, isNull);
      expect(copy.chatComposerRadius, isNull);
    });
  });
}
