/// **Lot 4 « étude » — maillon JETON** de la vue des tâches du jour.
///
/// Les sept jetons `dailyTasks*` sont le maillon du milieu de la chaîne
/// `paramètre > jeton > référence` de `zDailyTasksChromeOf` (`zcrud_study`).
/// Avant ce lot ils n'existaient pas (MESURÉ : `grep -n "dailyTasks"` sur
/// `z_theme.dart` → sortie vide) et la chaîne n'avait que DEUX maillons.
///
/// Cette suite vérifie ce que la garde structurelle des « 4 sites »
/// (`z_theme_four_sites_guard_test.dart`) ne PEUT PAS voir : celle-ci lit la
/// SOURCE (le jeton est-il cité aux quatre endroits ?), jamais le
/// COMPORTEMENT. Un `copyWith` qui écrirait `x: this.x` cite bien le jeton —
/// la garde de source reste verte — mais ignore l'argument reçu.
///
/// Quatre propriétés y sont assertées :
/// * **défaut `null`** — ni le constructeur ni `fallback` ne matérialisent une
///   valeur qui primerait sur la référence du consommateur sans demande ;
/// * **transport** — `copyWith` porte l'argument reçu et ne perd pas
///   l'existant ;
/// * **PLANCHER** — `dailyTasksMinTapTarget` ne passe JAMAIS par `0` pendant
///   une transition : une fenêtre sans plancher, c'est AD-13 violé le temps de
///   l'animation (leçon `celebrationDuration` / `studySessionMinTarget`) ;
/// * **SEUIL DISCRET** — `dailyTasksMonthBreakpoint` ne s'interpole pas : un
///   point de rupture intermédiaire ferait basculer la mise en page à une
///   largeur qu'AUCUN des deux thèmes ne décrit.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Thème PLEIN : les sept jetons posés, valeurs distinctes des références du
/// consommateur (8/4, 2, 8, 12, 48, 600, 12/6) — sans quoi les assertions
/// seraient vraies avant même la mesure.
const ZcrudTheme _plein = ZcrudTheme(
  dailyTasksBandPadding: EdgeInsetsDirectional.symmetric(
    horizontal: 33,
    vertical: 17,
  ),
  dailyTasksDayCellMargin: EdgeInsetsDirectional.symmetric(horizontal: 9),
  dailyTasksDayCellPadding: EdgeInsetsDirectional.symmetric(vertical: 21),
  dailyTasksDayCellRadius: Radius.circular(3),
  dailyTasksMinTapTarget: 61,
  dailyTasksMonthBreakpoint: 777,
  dailyTasksItemPadding: EdgeInsetsDirectional.symmetric(
    horizontal: 5,
    vertical: 29,
  ),
);

void main() {
  group('jetons `dailyTasks*` — défauts', () {
    test('les sept jetons sont `null` par défaut', () {
      const ZcrudTheme t = ZcrudTheme();
      expect(t.dailyTasksBandPadding, isNull);
      expect(t.dailyTasksDayCellMargin, isNull);
      expect(t.dailyTasksDayCellPadding, isNull);
      expect(t.dailyTasksDayCellRadius, isNull);
      expect(t.dailyTasksMinTapTarget, isNull);
      expect(t.dailyTasksMonthBreakpoint, isNull);
      expect(t.dailyTasksItemPadding, isNull);
    });

    test('le repli dérivé (`fallback`) ne les matérialise pas', () {
      // Un défaut matérialisé ici PRIMERAIT sur la référence du consommateur
      // sans que personne ne l'ait demandé — le lot cesserait d'être additif.
      final ZcrudTheme t = ZcrudTheme.fallback(ThemeData());
      expect(t.dailyTasksBandPadding, isNull);
      expect(t.dailyTasksDayCellMargin, isNull);
      expect(t.dailyTasksDayCellPadding, isNull);
      expect(t.dailyTasksDayCellRadius, isNull);
      expect(t.dailyTasksMinTapTarget, isNull);
      expect(t.dailyTasksMonthBreakpoint, isNull);
      expect(t.dailyTasksItemPadding, isNull);
    });
  });

  group('`copyWith` — transport, jeton par jeton', () {
    test('un `copyWith()` SANS argument ne perd aucun des sept', () {
      final ZcrudTheme c = _plein.copyWith();
      expect(c.dailyTasksBandPadding, _plein.dailyTasksBandPadding);
      expect(c.dailyTasksDayCellMargin, _plein.dailyTasksDayCellMargin);
      expect(c.dailyTasksDayCellPadding, _plein.dailyTasksDayCellPadding);
      expect(c.dailyTasksDayCellRadius, _plein.dailyTasksDayCellRadius);
      expect(c.dailyTasksMinTapTarget, 61);
      expect(c.dailyTasksMonthBreakpoint, 777);
      expect(c.dailyTasksItemPadding, _plein.dailyTasksItemPadding);
    });

    test('chaque argument reçu est effectivement PORTÉ (pas `this.x`)', () {
      const ZcrudTheme vide = ZcrudTheme();
      expect(
        vide
            .copyWith(
              dailyTasksBandPadding: const EdgeInsetsDirectional.all(11),
            )
            .dailyTasksBandPadding,
        const EdgeInsetsDirectional.all(11),
      );
      expect(
        vide
            .copyWith(
              dailyTasksDayCellMargin: const EdgeInsetsDirectional.all(13),
            )
            .dailyTasksDayCellMargin,
        const EdgeInsetsDirectional.all(13),
      );
      expect(
        vide
            .copyWith(
              dailyTasksDayCellPadding: const EdgeInsetsDirectional.all(15),
            )
            .dailyTasksDayCellPadding,
        const EdgeInsetsDirectional.all(15),
      );
      expect(
        vide
            .copyWith(dailyTasksDayCellRadius: const Radius.circular(7))
            .dailyTasksDayCellRadius,
        const Radius.circular(7),
      );
      expect(
        vide.copyWith(dailyTasksMinTapTarget: 64).dailyTasksMinTapTarget,
        64,
      );
      expect(
        vide.copyWith(dailyTasksMonthBreakpoint: 480).dailyTasksMonthBreakpoint,
        480,
      );
      expect(
        vide
            .copyWith(
              dailyTasksItemPadding: const EdgeInsetsDirectional.all(19),
            )
            .dailyTasksItemPadding,
        const EdgeInsetsDirectional.all(19),
      );
    });

    test('un `copyWith` ciblé ne touche PAS les six autres jetons', () {
      final ZcrudTheme c = _plein.copyWith(dailyTasksMinTapTarget: 99);
      expect(c.dailyTasksMinTapTarget, 99);
      expect(c.dailyTasksBandPadding, _plein.dailyTasksBandPadding);
      expect(c.dailyTasksDayCellMargin, _plein.dailyTasksDayCellMargin);
      expect(c.dailyTasksDayCellPadding, _plein.dailyTasksDayCellPadding);
      expect(c.dailyTasksDayCellRadius, _plein.dailyTasksDayCellRadius);
      expect(c.dailyTasksMonthBreakpoint, 777);
      expect(c.dailyTasksItemPadding, _plein.dailyTasksItemPadding);
    });
  });

  group('`lerp` — null-préservation', () {
    test('`null` ↔ `null` reste `null` pour les sept jetons', () {
      const ZcrudTheme vide = ZcrudTheme();
      for (final double t in <double>[0, .3, .5, .7, 1]) {
        final ZcrudTheme m = vide.lerp(const ZcrudTheme(), t);
        expect(m.dailyTasksBandPadding, isNull, reason: 't=$t');
        expect(m.dailyTasksDayCellMargin, isNull, reason: 't=$t');
        expect(m.dailyTasksDayCellPadding, isNull, reason: 't=$t');
        expect(m.dailyTasksDayCellRadius, isNull, reason: 't=$t');
        expect(m.dailyTasksMinTapTarget, isNull, reason: 't=$t');
        expect(m.dailyTasksMonthBreakpoint, isNull, reason: 't=$t');
        expect(m.dailyTasksItemPadding, isNull, reason: 't=$t');
      }
    });

    test('les trois marges + le rayon s\'interpolent (dimensions CONTINUES)',
        () {
      const ZcrudTheme a = ZcrudTheme(
        dailyTasksBandPadding: EdgeInsetsDirectional.all(10),
        dailyTasksDayCellMargin: EdgeInsetsDirectional.all(2),
        dailyTasksDayCellPadding: EdgeInsetsDirectional.all(4),
        dailyTasksItemPadding: EdgeInsetsDirectional.all(6),
        dailyTasksDayCellRadius: Radius.circular(4),
      );
      const ZcrudTheme b = ZcrudTheme(
        dailyTasksBandPadding: EdgeInsetsDirectional.all(20),
        dailyTasksDayCellMargin: EdgeInsetsDirectional.all(6),
        dailyTasksDayCellPadding: EdgeInsetsDirectional.all(8),
        dailyTasksItemPadding: EdgeInsetsDirectional.all(10),
        dailyTasksDayCellRadius: Radius.circular(12),
      );
      final ZcrudTheme m = a.lerp(b, .5);
      expect(m.dailyTasksBandPadding, const EdgeInsetsDirectional.all(15));
      expect(m.dailyTasksDayCellMargin, const EdgeInsetsDirectional.all(4));
      expect(m.dailyTasksDayCellPadding, const EdgeInsetsDirectional.all(6));
      expect(m.dailyTasksItemPadding, const EdgeInsetsDirectional.all(8));
      expect(m.dailyTasksDayCellRadius, const Radius.circular(8));
    });

    test('les marges interpolées restent DIRECTIONNELLES (AD-13)', () {
      const ZcrudTheme a = ZcrudTheme(
        dailyTasksBandPadding: EdgeInsetsDirectional.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
      );
      const ZcrudTheme vide = ZcrudTheme();
      // Un seul côté posé : la nature directionnelle survit, et la valeur
      // connue n'est pas dénaturée en `EdgeInsets` (qui, en RTL, inverserait
      // start/end).
      expect(vide.lerp(a, 1).dailyTasksBandPadding,
          isA<EdgeInsetsDirectional>());
      expect(
        vide.lerp(a, 1).dailyTasksBandPadding,
        const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 4),
      );
    });

    test('🔴 le PLANCHER de cible ne passe JAMAIS par 0 (AD-13)', () {
      // `_lerpNullableDouble(null, 48, 0)` rendrait `0` : une fenêtre — courte
      // mais réelle — pendant laquelle les SEPT cibles du bandeau n'ont plus
      // aucun plancher. Pour une CONTRAINTE, `0` n'est pas une absence.
      const ZcrudTheme sans = ZcrudTheme();
      const ZcrudTheme avec = ZcrudTheme(dailyTasksMinTapTarget: 48);
      for (int i = 0; i <= 20; i++) {
        final double t = i / 20;
        expect(sans.lerp(avec, t).dailyTasksMinTapTarget, 48,
            reason: 'null→48 à t=$t');
        expect(avec.lerp(sans, t).dailyTasksMinTapTarget, 48,
            reason: '48→null à t=$t');
      }
      // Deux planchers CONNUS, eux, s'interpolent : ce sont deux longueurs, et
      // toute valeur entre elles est un plancher valide.
      const ZcrudTheme haut = ZcrudTheme(dailyTasksMinTapTarget: 64);
      expect(avec.lerp(haut, .5).dailyTasksMinTapTarget, 56);
    });

    test('🔴 le SEUIL de mois est DISCRET — il bascule, il ne glisse pas', () {
      // Interpolé, il ferait apparaître/disparaître le libellé de mois à une
      // largeur qu'AUCUN des deux thèmes ne décrit : une bascule de mise en
      // page au milieu de l'animation, que personne n'a choisie.
      const ZcrudTheme a = ZcrudTheme(dailyTasksMonthBreakpoint: 600);
      const ZcrudTheme b = ZcrudTheme(dailyTasksMonthBreakpoint: 900);
      for (final double t in <double>[0, .1, .25, .49]) {
        expect(a.lerp(b, t).dailyTasksMonthBreakpoint, 600, reason: 't=$t');
      }
      for (final double t in <double>[.5, .75, 1]) {
        expect(a.lerp(b, t).dailyTasksMonthBreakpoint, 900, reason: 't=$t');
      }
      // Aucune valeur rendue n'est étrangère aux deux bornes : c'est CELA que
      // « discret » veut dire (une interpolation rendrait 675, 750, 825…).
      final Set<double?> rendus = <double?>{
        for (int i = 0; i <= 20; i++) a.lerp(b, i / 20).dailyTasksMonthBreakpoint,
      };
      expect(rendus, <double?>{600, 900});
    });

    test('un côté absent ne matérialise pas non plus un SEUIL à 0', () {
      // Un seuil à `0` rendrait le mois à TOUTE largeur — l'inverse exact de
      // ce que le thème restant décrit.
      const ZcrudTheme sans = ZcrudTheme();
      const ZcrudTheme avec = ZcrudTheme(dailyTasksMonthBreakpoint: 600);
      for (int i = 0; i <= 10; i++) {
        final double t = i / 10;
        expect(sans.lerp(avec, t).dailyTasksMonthBreakpoint, isNot(0),
            reason: 't=$t');
        expect(avec.lerp(sans, t).dailyTasksMonthBreakpoint, isNot(0),
            reason: 't=$t');
      }
    });
  });

  group('aucun jeton GÉNÉRIQUE n\'est ridé', () {
    test('poser les sept jetons ne touche ni `gapM`, ni `radiusM`, ni les '
        'jetons de la SESSION', () {
      // CR-IFFD-61 : un jeton générique portant plusieurs valeurs de référence
      // ne peut en satisfaire aucune. Le vérifier interdit la régression
      // inverse — câbler la vue sur un jeton partagé « parce qu'il vaut déjà
      // 12 ». On contrôle aussi la famille voisine (`studySession*`), dont
      // trois jetons décrivent des propriétés de même NATURE mais d'un AUTRE
      // écran : les confondre serait le même défaut, d'un cran plus subtil.
      const ZcrudTheme t = ZcrudTheme();
      expect(_plein.gapM, t.gapM);
      expect(_plein.gapS, t.gapS);
      expect(_plein.gapL, t.gapL);
      expect(_plein.radiusM, t.radiusM);
      expect(_plein.radiusS, t.radiusS);
      expect(_plein.studySessionMinTarget, isNull);
      expect(_plein.studySessionContentPadding, isNull);
      expect(_plein.studySessionSectionGap, isNull);
    });
  });
}
