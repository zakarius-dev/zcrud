/// **CR-IFFD-63** — jetons de typographie de l'**en-tête de page**.
///
/// Quatre jetons NULLABLES (`pageHeaderTitleStyle`, `pageHeaderSubtitleStyle`,
/// `pageHeaderTabSelectedLabelStyle`, `pageHeaderTabUnselectedLabelStyle`).
///
/// Cette suite vérifie ce que la garde structurelle des « 4 sites »
/// (`z_theme_four_sites_guard_test.dart`) ne peut pas voir — elle lit la
/// SOURCE, pas le COMPORTEMENT :
/// * `null` par défaut (le consommateur garde son repli documenté) ;
/// * `copyWith` **transporte** chaque jeton et n'en efface aucun sans demande ;
/// * `lerp` est **null-préservant** : `null` ↔ `null` reste `null`, sans quoi la
///   première transition de thème GÈLERAIT le repli du consommateur en le
///   matérialisant (défaut déjà rencontré sur `badgeRadius`/`studyCardGlyphSize`
///   dans ce dépôt).
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  group('CR-IFFD-63 — jetons de typographie d\'en-tête de page', () {
    test('défaut : les quatre jetons sont `null`', () {
      const ZcrudTheme t = ZcrudTheme();
      expect(t.pageHeaderTitleStyle, isNull);
      expect(t.pageHeaderSubtitleStyle, isNull);
      expect(t.pageHeaderTabSelectedLabelStyle, isNull);
      expect(t.pageHeaderTabUnselectedLabelStyle, isNull);
    });

    test('le repli dérivé (`fallback`) ne les matérialise pas non plus', () {
      final ZcrudTheme t = ZcrudTheme.fallback(ThemeData());
      expect(t.pageHeaderTitleStyle, isNull);
      expect(t.pageHeaderSubtitleStyle, isNull);
      expect(t.pageHeaderTabSelectedLabelStyle, isNull);
      expect(t.pageHeaderTabUnselectedLabelStyle, isNull);
    });

    test('copyWith transporte chaque jeton — et n\'efface rien sans demande', () {
      const ZcrudTheme plein = ZcrudTheme(
        pageHeaderTitleStyle: TextStyle(fontSize: 26),
        pageHeaderSubtitleStyle: TextStyle(fontSize: 11),
        pageHeaderTabSelectedLabelStyle: TextStyle(fontWeight: FontWeight.w700),
        pageHeaderTabUnselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w300,
        ),
      );

      // (a) `copyWith` sans argument ne perd RIEN.
      final ZcrudTheme intact = plein.copyWith();
      expect(intact.pageHeaderTitleStyle, plein.pageHeaderTitleStyle);
      expect(intact.pageHeaderSubtitleStyle, plein.pageHeaderSubtitleStyle);
      expect(
        intact.pageHeaderTabSelectedLabelStyle,
        plein.pageHeaderTabSelectedLabelStyle,
      );
      expect(
        intact.pageHeaderTabUnselectedLabelStyle,
        plein.pageHeaderTabUnselectedLabelStyle,
      );

      // (b) chaque jeton est réellement RÉGLABLE par `copyWith`.
      const ZcrudTheme vide = ZcrudTheme();
      expect(
        vide
            .copyWith(pageHeaderTitleStyle: const TextStyle(fontSize: 30))
            .pageHeaderTitleStyle
            ?.fontSize,
        30.0,
      );
      expect(
        vide
            .copyWith(pageHeaderSubtitleStyle: const TextStyle(fontSize: 9))
            .pageHeaderSubtitleStyle
            ?.fontSize,
        9.0,
      );
      expect(
        vide
            .copyWith(
              pageHeaderTabSelectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w900,
              ),
            )
            .pageHeaderTabSelectedLabelStyle
            ?.fontWeight,
        FontWeight.w900,
      );
      expect(
        vide
            .copyWith(
              pageHeaderTabUnselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w100,
              ),
            )
            .pageHeaderTabUnselectedLabelStyle
            ?.fontWeight,
        FontWeight.w100,
      );
    });

    test('lerp : `null` ↔ `null` reste `null` (le repli n\'est pas gelé)', () {
      const ZcrudTheme a = ZcrudTheme();
      const ZcrudTheme b = ZcrudTheme();
      for (final double t in <double>[0.0, 0.25, 0.5, 0.75, 1.0]) {
        final ZcrudTheme mix = a.lerp(b, t);
        expect(mix.pageHeaderTitleStyle, isNull, reason: 't=$t');
        expect(mix.pageHeaderSubtitleStyle, isNull, reason: 't=$t');
        expect(mix.pageHeaderTabSelectedLabelStyle, isNull, reason: 't=$t');
        expect(mix.pageHeaderTabUnselectedLabelStyle, isNull, reason: 't=$t');
      }
    });

    test('lerp : deux valeurs déclarées sont bien INTERPOLÉES', () {
      const ZcrudTheme a = ZcrudTheme(
        pageHeaderTitleStyle: TextStyle(fontSize: 20),
        pageHeaderSubtitleStyle: TextStyle(fontSize: 10),
        pageHeaderTabSelectedLabelStyle: TextStyle(fontSize: 14),
        pageHeaderTabUnselectedLabelStyle: TextStyle(fontSize: 12),
      );
      const ZcrudTheme b = ZcrudTheme(
        pageHeaderTitleStyle: TextStyle(fontSize: 30),
        pageHeaderSubtitleStyle: TextStyle(fontSize: 20),
        pageHeaderTabSelectedLabelStyle: TextStyle(fontSize: 24),
        pageHeaderTabUnselectedLabelStyle: TextStyle(fontSize: 22),
      );
      final ZcrudTheme mix = a.lerp(b, 0.5);
      expect(mix.pageHeaderTitleStyle?.fontSize, 25.0);
      expect(mix.pageHeaderSubtitleStyle?.fontSize, 15.0);
      expect(mix.pageHeaderTabSelectedLabelStyle?.fontSize, 19.0);
      expect(mix.pageHeaderTabUnselectedLabelStyle?.fontSize, 17.0);
    });

    test('lerp vers `other` non-ZcrudTheme rend `this` inchangé', () {
      const ZcrudTheme a = ZcrudTheme(
        pageHeaderTitleStyle: TextStyle(fontSize: 26),
      );
      expect(a.lerp(null, 0.5).pageHeaderTitleStyle?.fontSize, 26.0);
    });
  });
}
