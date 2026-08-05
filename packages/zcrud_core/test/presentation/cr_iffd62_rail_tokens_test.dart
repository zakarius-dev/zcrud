/// **CR-IFFD-62** — jetons de RAIL (`railItemHeight`, `railItemGap`,
/// `railPadding`) et alignement vertical du contenu de carte
/// (`studyCardContentAlignment`).
///
/// Ce que ces gardes MESURENT :
/// - le **défaut `null`** de chaque jeton (le consommateur garde son repli
///   documenté — aucun rendu d'hôte ne bouge) ;
/// - la **survie à `copyWith`** (le piège des 4 sites) ;
/// - 🔴 l'invariant **`null` ↔ `null` reste `null` dans `lerp`** : matérialiser
///   une valeur à la première transition de thème GÈLERAIT le repli du
///   consommateur — défaut déjà rencontré sur `studyCardBadgeRadius` ;
/// - l'interpolation RÉELLE des jetons continus, et le caractère DISCRET de
///   l'énumération.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  group('CR-IFFD-62 ① — `railItemHeight`', () {
    test('défaut `null` : aucune contrainte imposée par le thème', () {
      expect(const ZcrudTheme().railItemHeight, isNull);
    });

    test('survit à `copyWith`', () {
      expect(const ZcrudTheme().copyWith(railItemHeight: 200).railItemHeight,
          200);
    });

    test('🔴 lerp `null` ↔ `null` RESTE `null` (à tous les t)', () {
      for (final double t in <double>[0, 0.25, 0.5, 0.75, 1]) {
        expect(const ZcrudTheme().lerp(const ZcrudTheme(), t).railItemHeight,
            isNull,
            reason: '🔴 t=$t : une hauteur matérialisée ici s\'imposerait à '
                'TOUS les items de rail dès la première transition de thème.');
      }
    });

    test('lerp interpole RÉELLEMENT entre deux valeurs', () {
      const ZcrudTheme a = ZcrudTheme(railItemHeight: 100);
      const ZcrudTheme b = ZcrudTheme(railItemHeight: 300);
      expect(a.lerp(b, 0.5).railItemHeight, 200);
    });
  });

  group('CR-IFFD-62 ④ — `railItemGap`', () {
    test('défaut `null` (le consommateur garde `gapS`)', () {
      expect(const ZcrudTheme().railItemGap, isNull);
    });

    test('survit à `copyWith`', () {
      expect(const ZcrudTheme().copyWith(railItemGap: 12).railItemGap, 12);
    });

    test('🔴 lerp `null` ↔ `null` RESTE `null`', () {
      expect(const ZcrudTheme().lerp(const ZcrudTheme(), 0.5).railItemGap,
          isNull);
    });

    test('lerp interpole', () {
      expect(
        const ZcrudTheme(railItemGap: 4)
            .lerp(const ZcrudTheme(railItemGap: 12), 0.5)
            .railItemGap,
        8,
      );
    });
  });

  group('CR-IFFD-62 ④ — `railPadding`', () {
    test('défaut `null` (le rail hérite du padding de section)', () {
      expect(const ZcrudTheme().railPadding, isNull);
    });

    test('survit à `copyWith`', () {
      expect(
        const ZcrudTheme()
            .copyWith(railPadding: const EdgeInsetsDirectional.all(8))
            .railPadding,
        const EdgeInsetsDirectional.all(8),
      );
    });

    test('🔴 lerp `null` ↔ `null` RESTE `null`', () {
      expect(
          const ZcrudTheme().lerp(const ZcrudTheme(), 0.5).railPadding, isNull);
    });

    test('lerp PRÉSERVE la nature DIRECTIONNELLE (AD-13)', () {
      const ZcrudTheme a = ZcrudTheme(
        railPadding: EdgeInsetsDirectional.only(start: 0),
      );
      const ZcrudTheme b = ZcrudTheme(
        railPadding: EdgeInsetsDirectional.only(start: 20),
      );
      final EdgeInsetsGeometry? mid = a.lerp(b, 0.5).railPadding;
      expect(mid, isA<EdgeInsetsDirectional>(),
          reason: '🔴 une interpolation qui retomberait en `EdgeInsets` '
              'physique casserait le RTL à mi-transition.');
      expect((mid! as EdgeInsetsDirectional).start, 10);
    });
  });

  group('CR-IFFD-62 ④ — `studyCardContentAlignment`', () {
    test('défaut `null` (le consommateur applique sa référence)', () {
      expect(const ZcrudTheme().studyCardContentAlignment, isNull);
    });

    test('survit à `copyWith`', () {
      expect(
        const ZcrudTheme()
            .copyWith(
              studyCardContentAlignment: ZStudyCardContentAlignment.bottom,
            )
            .studyCardContentAlignment,
        ZStudyCardContentAlignment.bottom,
      );
    });

    test('🔴 lerp `null` ↔ `null` RESTE `null` (jeton DISCRET)', () {
      for (final double t in <double>[0, 0.49, 0.5, 1]) {
        expect(
          const ZcrudTheme()
              .lerp(const ZcrudTheme(), t)
              .studyCardContentAlignment,
          isNull,
        );
      }
    });

    test('lerp est DISCRET (bascule à t = 0.5), jamais une valeur inventée',
        () {
      const ZcrudTheme a = ZcrudTheme(
        studyCardContentAlignment: ZStudyCardContentAlignment.top,
      );
      const ZcrudTheme b = ZcrudTheme(
        studyCardContentAlignment: ZStudyCardContentAlignment.bottom,
      );
      expect(a.lerp(b, 0.25).studyCardContentAlignment,
          ZStudyCardContentAlignment.top);
      expect(a.lerp(b, 0.75).studyCardContentAlignment,
          ZStudyCardContentAlignment.bottom);
    });

    test('les trois valeurs existent, et `spread` est celle de la référence',
        () {
      expect(ZStudyCardContentAlignment.values, hasLength(3));
      expect(
        ZStudyCardContentAlignment.values,
        containsAll(<ZStudyCardContentAlignment>[
          ZStudyCardContentAlignment.top,
          ZStudyCardContentAlignment.spread,
          ZStudyCardContentAlignment.bottom,
        ]),
      );
    });
  });
}
