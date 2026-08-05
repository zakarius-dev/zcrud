/// **CR-IFFD-61** — les cinq jetons qui retirent à `gapM`/`gapS` les valeurs de
/// référence qu'ils ridaient, et qui rendent l'élévation de la carte par défaut
/// adressable :
///
/// * `studyCardLeadingGap` (① écart tuile→titre, référence 16) ;
/// * `studyCardElevation` (② élévation, référence 0 — pas d'ombre portée) ;
/// * `subfolderSheetContentPadding` (③ gouttière interne de la feuille) ;
/// * `studySectionCountPlacement` + `studySectionCountGap` (④ compteur
///   adjacent au titre, et son écart).
///
/// L'invariant critique reste celui de `badgeRadius` : `null` des DEUX côtés
/// doit RESTER `null` au `lerp`. Matérialiser une valeur GÈLERAIT la référence
/// du consommateur (16 / 0 / `gapM` / `gapS`) à la première transition de
/// thème, et la précédence documentée cesserait ensuite de s'appliquer.
/// Le câblage aux 4 sites est tenu par `z_theme_four_sites_guard_test.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  const ZcrudTheme filled = ZcrudTheme(
    studyCardLeadingGap: 16,
    studyCardElevation: 2,
    subfolderSheetContentPadding: EdgeInsetsDirectional.all(8),
    studySectionCountPlacement: ZStudySectionCountPlacement.adjacentToTitle,
    studySectionCountGap: 12,
  );

  group('CR-IFFD-61 — jetons', () {
    test('défaut : TOUS nuls (le consommateur applique sa référence)', () {
      const ZcrudTheme theme = ZcrudTheme();
      expect(theme.studyCardLeadingGap, isNull);
      expect(theme.studyCardElevation, isNull);
      expect(theme.subfolderSheetContentPadding, isNull);
      expect(theme.studySectionCountPlacement, isNull);
      expect(theme.studySectionCountGap, isNull);
    });

    test('copyWith transporte chaque jeton — et n\'efface rien sans demande',
        () {
      final ZcrudTheme copied = const ZcrudTheme().copyWith(
        studyCardLeadingGap: 24,
        studyCardElevation: 0,
        subfolderSheetContentPadding: const EdgeInsetsDirectional.all(6),
        studySectionCountPlacement: ZStudySectionCountPlacement.lineEnd,
        studySectionCountGap: 10,
      );
      expect(copied.studyCardLeadingGap, 24);
      expect(copied.studyCardElevation, 0);
      expect(
        copied.subfolderSheetContentPadding,
        const EdgeInsetsDirectional.all(6),
      );
      expect(
        copied.studySectionCountPlacement,
        ZStudySectionCountPlacement.lineEnd,
      );
      expect(copied.studySectionCountGap, 10);

      // Sans argument : les valeurs EXISTANTES restent.
      final ZcrudTheme kept = filled.copyWith();
      expect(kept.studyCardLeadingGap, 16);
      expect(kept.studyCardElevation, 2);
      expect(
        kept.subfolderSheetContentPadding,
        const EdgeInsetsDirectional.all(8),
      );
      expect(
        kept.studySectionCountPlacement,
        ZStudySectionCountPlacement.adjacentToTitle,
      );
      expect(kept.studySectionCountGap, 12);
    });

    test('lerp : `null` des DEUX côtés RESTE `null` (référence jamais GELÉE)',
        () {
      const ZcrudTheme a = ZcrudTheme();
      const ZcrudTheme b = ZcrudTheme();
      for (final double t in <double>[0, 0.25, 0.5, 0.75, 1]) {
        final ZcrudTheme l = a.lerp(b, t);
        expect(l.studyCardLeadingGap, isNull, reason: 't=$t');
        expect(l.studyCardElevation, isNull, reason: 't=$t');
        expect(l.subfolderSheetContentPadding, isNull, reason: 't=$t');
        expect(l.studySectionCountPlacement, isNull, reason: 't=$t');
        expect(l.studySectionCountGap, isNull, reason: 't=$t');
      }
    });

    test('lerp : les CONTINUS interpolent, les DISCRETS basculent au milieu',
        () {
      const ZcrudTheme a = ZcrudTheme(
        studyCardLeadingGap: 8,
        studyCardElevation: 0,
        studySectionCountGap: 4,
        studySectionCountPlacement: ZStudySectionCountPlacement.lineEnd,
      );
      const ZcrudTheme b = ZcrudTheme(
        studyCardLeadingGap: 16,
        studyCardElevation: 4,
        studySectionCountGap: 12,
        studySectionCountPlacement: ZStudySectionCountPlacement.adjacentToTitle,
      );
      final ZcrudTheme mid = a.lerp(b, 0.5);
      expect(mid.studyCardLeadingGap, 12);
      expect(mid.studyCardElevation, 2);
      expect(mid.studySectionCountGap, 8);
      // Discret : bascule au point milieu (t >= 0.5 ⇒ `other`).
      expect(
        mid.studySectionCountPlacement,
        ZStudySectionCountPlacement.adjacentToTitle,
      );
      expect(
        a.lerp(b, 0.49).studySectionCountPlacement,
        ZStudySectionCountPlacement.lineEnd,
      );
    });

    test('🔴 `studyCardElevation: 0` SURVIT au transport — 0 n\'est pas `null`',
        () {
      // Angle mort réel : un `?? `/`if (x != 0)` quelque part sur le chemin
      // ferait retomber la référence (0) sur le défaut Material (1.0). Le zéro
      // de la référence est une VALEUR, pas une absence.
      const ZcrudTheme zero = ZcrudTheme(studyCardElevation: 0);
      expect(zero.copyWith().studyCardElevation, 0);
      expect(zero.copyWith(studyCardLeadingGap: 16).studyCardElevation, 0);
      expect(zero.lerp(zero, 0.5).studyCardElevation, 0);
      expect(zero.lerp(const ZcrudTheme(), 0).studyCardElevation, 0);
    });
  });
}
