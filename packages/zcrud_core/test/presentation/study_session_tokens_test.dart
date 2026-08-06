/// **Lot 1 « étude » — maillon JETON** de l'écran de session de révision.
///
/// Les sept jetons `studySession*` sont le maillon du milieu de la chaîne
/// `paramètre > jeton > référence` de `zStudySessionChromeOf` (`zcrud_study`).
/// Avant ce lot, ils n'existaient pas (MESURÉ : `grep -n "studySession"` sur
/// `z_theme.dart` → vide) et la chaîne n'avait que deux maillons.
///
/// Cette suite vérifie ce que la garde structurelle des « 4 sites »
/// (`z_theme_four_sites_guard_test.dart`) ne PEUT PAS voir : elle lit la
/// SOURCE (le jeton est-il cité aux quatre endroits ?), jamais le
/// COMPORTEMENT. Un `copyWith` qui citerait le jeton en écrivant
/// `x: this.x` — donc en ignorant l'argument — la laisserait verte.
///
/// Trois propriétés y sont donc assertées :
/// * **transport** — `copyWith` porte l'argument reçu ET ne perd pas
///   l'existant quand aucun argument n'est donné ;
/// * **nature discrète des `flex`** — un `flex` est un entier de contrainte :
///   `lerp` le fait BASCULER, il ne fabrique jamais d'entier intermédiaire
///   (une pile 3/2 ne doit pas passer par 2/2, répartition qu'aucun des deux
///   thèmes ne décrit) ;
/// * **null-préservation** — `null` ↔ `null` reste `null`, sans quoi la
///   première transition de thème GÈLERAIT la valeur de référence du
///   consommateur ; et, pour le PLANCHER de cible, `null` ↔ `48` ne passe
///   JAMAIS par `0` (une fenêtre sans plancher = AD-13 violé en pleine
///   transition — la leçon `celebrationDuration`).
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Thème PLEIN : les sept jetons posés, valeurs distinctes des références.
const ZcrudTheme _plein = ZcrudTheme(
  studySessionStackFlex: 7,
  studySessionInputFlex: 5,
  studySessionContentPadding: EdgeInsetsDirectional.all(20),
  studySessionDividerThickness: 3,
  studySessionSectionGap: 21,
  studySessionMinTarget: 56,
  studySessionCounterStyle: TextStyle(fontSize: 31),
);

void main() {
  group('jetons `studySession*` — défauts', () {
    test('les sept jetons sont `null` par défaut', () {
      const ZcrudTheme t = ZcrudTheme();
      expect(t.studySessionStackFlex, isNull);
      expect(t.studySessionInputFlex, isNull);
      expect(t.studySessionContentPadding, isNull);
      expect(t.studySessionDividerThickness, isNull);
      expect(t.studySessionSectionGap, isNull);
      expect(t.studySessionMinTarget, isNull);
      expect(t.studySessionCounterStyle, isNull);
    });

    test('le repli dérivé (`fallback`) ne les matérialise pas', () {
      // Un défaut matérialisé ici PRIMERAIT sur la référence du consommateur
      // sans que personne ne l'ait demandé.
      final ZcrudTheme t = ZcrudTheme.fallback(ThemeData());
      expect(t.studySessionStackFlex, isNull);
      expect(t.studySessionInputFlex, isNull);
      expect(t.studySessionContentPadding, isNull);
      expect(t.studySessionDividerThickness, isNull);
      expect(t.studySessionSectionGap, isNull);
      expect(t.studySessionMinTarget, isNull);
      expect(t.studySessionCounterStyle, isNull);
    });
  });

  group('`copyWith` — transport, jeton par jeton', () {
    test('un `copyWith()` SANS argument ne perd aucun des sept', () {
      final ZcrudTheme copie = _plein.copyWith();
      expect(copie.studySessionStackFlex, 7);
      expect(copie.studySessionInputFlex, 5);
      expect(copie.studySessionContentPadding,
          const EdgeInsetsDirectional.all(20));
      expect(copie.studySessionDividerThickness, 3);
      expect(copie.studySessionSectionGap, 21);
      expect(copie.studySessionMinTarget, 56);
      expect(copie.studySessionCounterStyle?.fontSize, 31);
    });

    test('chaque argument reçu est effectivement PORTÉ (pas `this.x`)', () {
      // 🔴 Le piège exact : `x: this.x` dans le corps cite bien le jeton — la
      // garde de source reste verte — mais l'argument est ignoré.
      const ZcrudTheme vide = ZcrudTheme();
      expect(vide.copyWith(studySessionStackFlex: 9).studySessionStackFlex, 9);
      expect(vide.copyWith(studySessionInputFlex: 4).studySessionInputFlex, 4);
      expect(
        vide
            .copyWith(
                studySessionContentPadding:
                    const EdgeInsetsDirectional.all(33))
            .studySessionContentPadding,
        const EdgeInsetsDirectional.all(33),
      );
      expect(
        vide
            .copyWith(studySessionDividerThickness: 2.5)
            .studySessionDividerThickness,
        2.5,
      );
      expect(vide.copyWith(studySessionSectionGap: 17).studySessionSectionGap,
          17);
      expect(vide.copyWith(studySessionMinTarget: 64).studySessionMinTarget, 64);
      expect(
        vide
            .copyWith(
                studySessionCounterStyle: const TextStyle(fontSize: 13))
            .studySessionCounterStyle
            ?.fontSize,
        13,
      );
    });

    test('un `copyWith` ciblé ne touche PAS les six autres jetons', () {
      final ZcrudTheme copie = _plein.copyWith(studySessionSectionGap: 99);
      expect(copie.studySessionSectionGap, 99);
      expect(copie.studySessionStackFlex, 7);
      expect(copie.studySessionInputFlex, 5);
      expect(copie.studySessionContentPadding,
          const EdgeInsetsDirectional.all(20));
      expect(copie.studySessionDividerThickness, 3);
      expect(copie.studySessionMinTarget, 56);
      expect(copie.studySessionCounterStyle?.fontSize, 31);
    });
  });

  group('`lerp` — les `flex` sont DISCRETS', () {
    test('3→2 bascule à mi-course, sans entier intermédiaire', () {
      const ZcrudTheme a =
          ZcrudTheme(studySessionStackFlex: 3, studySessionInputFlex: 2);
      const ZcrudTheme b =
          ZcrudTheme(studySessionStackFlex: 9, studySessionInputFlex: 8);
      for (final double t in <double>[0, .1, .25, .49]) {
        final ZcrudTheme m = a.lerp(b, t);
        expect(m.studySessionStackFlex, 3, reason: 't=$t');
        expect(m.studySessionInputFlex, 2, reason: 't=$t');
      }
      for (final double t in <double>[.5, .75, 1]) {
        final ZcrudTheme m = a.lerp(b, t);
        expect(m.studySessionStackFlex, 9, reason: 't=$t');
        expect(m.studySessionInputFlex, 8, reason: 't=$t');
      }
      // Aucune valeur rendue n'est étrangère aux deux bornes : c'est CELA que
      // « discret » veut dire (une interpolation arrondie rendrait 4, 5, 6…).
      final Set<int?> rendus = <int?>{
        for (int i = 0; i <= 20; i++)
          (a.lerp(b, i / 20)).studySessionStackFlex,
      };
      expect(rendus, <int?>{3, 9});
    });
  });

  group('`lerp` — null-préservation', () {
    test('`null` ↔ `null` reste `null` pour les sept jetons', () {
      const ZcrudTheme vide = ZcrudTheme();
      for (final double t in <double>[0, .3, .5, .7, 1]) {
        final ZcrudTheme m = vide.lerp(const ZcrudTheme(), t);
        expect(m.studySessionStackFlex, isNull, reason: 't=$t');
        expect(m.studySessionInputFlex, isNull, reason: 't=$t');
        expect(m.studySessionContentPadding, isNull, reason: 't=$t');
        expect(m.studySessionDividerThickness, isNull, reason: 't=$t');
        expect(m.studySessionSectionGap, isNull, reason: 't=$t');
        expect(m.studySessionMinTarget, isNull, reason: 't=$t');
        expect(m.studySessionCounterStyle, isNull, reason: 't=$t');
      }
    });

    test('🔴 le PLANCHER de cible ne passe JAMAIS par 0 (AD-13)', () {
      // `_lerpNullableDouble(null, 48, t)` rendrait `0` à t=0 : une fenêtre —
      // courte mais réelle — sans aucun plancher de cible tapable.
      const ZcrudTheme sans = ZcrudTheme();
      const ZcrudTheme avec = ZcrudTheme(studySessionMinTarget: 48);
      for (int i = 0; i <= 20; i++) {
        final double t = i / 20;
        final double? aller = (sans.lerp(avec, t))
            .studySessionMinTarget;
        final double? retour = (avec.lerp(sans, t))
            .studySessionMinTarget;
        expect(aller, 48, reason: 'null→48 à t=$t');
        expect(retour, 48, reason: '48→null à t=$t');
      }
      // Deux planchers CONNUS, eux, s'interpolent : ce sont deux longueurs.
      const ZcrudTheme haut = ZcrudTheme(studySessionMinTarget: 64);
      expect((avec.lerp(haut, .5)).studySessionMinTarget, 56);
    });

    test('un côté absent ne matérialise pas non plus un `flex` à 0', () {
      // Un `Expanded(flex: 0)` s'effondre : la pile DISPARAÎTRAIT le temps de
      // la transition.
      const ZcrudTheme sans = ZcrudTheme();
      const ZcrudTheme avec = ZcrudTheme(studySessionStackFlex: 3);
      for (int i = 0; i <= 10; i++) {
        final double t = i / 10;
        expect((sans.lerp(avec, t)).studySessionStackFlex,
            isNot(0),
            reason: 't=$t');
        expect((avec.lerp(sans, t)).studySessionStackFlex,
            isNot(0),
            reason: 't=$t');
      }
    });

    test('le padding interpolé reste DIRECTIONNEL (AD-13)', () {
      const ZcrudTheme a =
          ZcrudTheme(studySessionContentPadding: EdgeInsetsDirectional.all(12));
      const ZcrudTheme b =
          ZcrudTheme(studySessionContentPadding: EdgeInsetsDirectional.all(24));
      final EdgeInsetsGeometry? m =
          (a.lerp(b, .5)).studySessionContentPadding;
      expect(m, isA<EdgeInsetsDirectional>());
      expect(m, const EdgeInsetsDirectional.all(18));
      // Un seul côté posé : la nature directionnelle survit quand même.
      const ZcrudTheme sans = ZcrudTheme();
      expect((sans.lerp(a, 1)).studySessionContentPadding,
          const EdgeInsetsDirectional.all(12));
    });

    test('épaisseur et écart s\'interpolent (ce sont des dimensions)', () {
      const ZcrudTheme a = ZcrudTheme(
          studySessionDividerThickness: 1, studySessionSectionGap: 12);
      const ZcrudTheme b = ZcrudTheme(
          studySessionDividerThickness: 3, studySessionSectionGap: 20);
      final ZcrudTheme m = a.lerp(b, .5);
      expect(m.studySessionDividerThickness, 2);
      expect(m.studySessionSectionGap, 16);
    });

    test('le style de compteur s\'interpole et reste null-préservant', () {
      const ZcrudTheme a =
          ZcrudTheme(studySessionCounterStyle: TextStyle(fontSize: 10));
      const ZcrudTheme b =
          ZcrudTheme(studySessionCounterStyle: TextStyle(fontSize: 20));
      expect((a.lerp(b, .5)).studySessionCounterStyle?.fontSize,
          15);
    });
  });

  group('aucun jeton GÉNÉRIQUE n\'est ridé', () {
    test('poser les sept jetons de session ne touche ni `gapM` ni `radiusM`',
        () {
      // CR-IFFD-61 : un jeton générique portant trois valeurs de référence
      // différentes ne peut satisfaire aucune. Chaque jeton de session est
      // SPÉCIFIQUE — le vérifier interdit la régression inverse (câbler la
      // session sur un jeton partagé « parce qu'il vaut déjà 12 »).
      const ZcrudTheme t = ZcrudTheme();
      expect(_plein.gapM, t.gapM);
      expect(_plein.radiusM, t.radiusM);
    });
  });
}
