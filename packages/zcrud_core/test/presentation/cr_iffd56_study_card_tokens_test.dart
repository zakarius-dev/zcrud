/// **CR-IFFD-56** — jetons `studyCard*` de `ZcrudTheme` : transport
/// (`copyWith`) et interpolation (`lerp`) null-préservante.
///
/// L'invariant critique est celui de `badgeRadius` (leçon mesurée) : `null`
/// des DEUX côtés doit RESTER `null` — matérialiser une valeur au `lerp`
/// GÈLERAIT le défaut-référence du consommateur à la première transition de
/// thème, et le rendu par défaut cesserait ensuite de suivre.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  const ZcrudTheme filled = ZcrudTheme(
    studyCardHierarchy: ZStudyCardHierarchy.tintedTile,
    studyCardRadius: Radius.circular(24),
    studyCardContentPadding: EdgeInsetsDirectional.all(20),
    studyCardMargin: EdgeInsetsDirectional.all(6),
    studyCardIconTileSize: 56,
    studyCardIconTileRadius: Radius.circular(18),
    studyCardTitleStyle: TextStyle(fontSize: 21),
    studyCardSubtitleStyle: TextStyle(fontSize: 9),
    studyCardBorderSide: BorderSide(color: Color(0xFF123456), width: 3),
    studyCardBadgeRadius: Radius.circular(2),
  );

  group('CR-IFFD-56 — jetons studyCard*', () {
    test('défaut : TOUS nuls (le consommateur applique la RÉFÉRENCE)', () {
      const ZcrudTheme theme = ZcrudTheme();
      expect(theme.studyCardHierarchy, isNull);
      expect(theme.studyCardRadius, isNull);
      expect(theme.studyCardContentPadding, isNull);
      expect(theme.studyCardMargin, isNull);
      expect(theme.studyCardIconTileSize, isNull);
      expect(theme.studyCardIconTileRadius, isNull);
      expect(theme.studyCardTitleStyle, isNull);
      expect(theme.studyCardSubtitleStyle, isNull);
      expect(theme.studyCardBorderSide, isNull);
      expect(theme.studyCardBadgeRadius, isNull);
    });

    test('copyWith transporte chaque jeton — et n\'efface rien sans demande',
        () {
      final ZcrudTheme copied = const ZcrudTheme().copyWith(
        studyCardHierarchy: ZStudyCardHierarchy.tintedTile,
        studyCardRadius: const Radius.circular(24),
        studyCardIconTileSize: 56,
        studyCardBorderSide:
            const BorderSide(color: Color(0xFF123456), width: 3),
      );
      expect(copied.studyCardHierarchy, ZStudyCardHierarchy.tintedTile);
      expect(copied.studyCardRadius, const Radius.circular(24));
      expect(copied.studyCardIconTileSize, 56);
      expect(copied.studyCardBorderSide?.width, 3);
      // Sans argument : les valeurs EXISTANTES restent.
      final ZcrudTheme kept = filled.copyWith();
      expect(kept.studyCardHierarchy, ZStudyCardHierarchy.tintedTile);
      expect(kept.studyCardBadgeRadius, const Radius.circular(2));
      expect(kept.studyCardMargin, const EdgeInsetsDirectional.all(6));
    });

    test('lerp : `null` des DEUX côtés RESTE `null` (défaut jamais GELÉ)', () {
      const ZcrudTheme a = ZcrudTheme();
      const ZcrudTheme b = ZcrudTheme();
      for (final double t in <double>[0, 0.25, 0.5, 1]) {
        final ZcrudTheme l = a.lerp(b, t);
        expect(l.studyCardHierarchy, isNull, reason: 't=$t');
        expect(l.studyCardRadius, isNull, reason: 't=$t');
        expect(l.studyCardContentPadding, isNull, reason: 't=$t');
        expect(l.studyCardMargin, isNull, reason: 't=$t');
        expect(l.studyCardIconTileSize, isNull, reason: 't=$t');
        expect(l.studyCardIconTileRadius, isNull, reason: 't=$t');
        expect(l.studyCardTitleStyle, isNull, reason: 't=$t');
        expect(l.studyCardSubtitleStyle, isNull, reason: 't=$t');
        expect(l.studyCardBorderSide, isNull, reason: 't=$t');
        expect(l.studyCardBadgeRadius, isNull, reason: 't=$t');
      }
    });

    test('lerp : continus interpolés, discrets basculés au point milieu', () {
      const ZcrudTheme empty = ZcrudTheme();
      final ZcrudTheme mid = empty.lerp(filled, 0.5);
      // Continus : valeur intermédiaire (null traité comme zéro, patron des
      // autres helpers nullables).
      expect(mid.studyCardIconTileSize, 28);
      expect(mid.studyCardRadius, const Radius.circular(12));
      // Discret : avant le point milieu, côté `a` (null) ; après, côté `b`.
      expect(empty.lerp(filled, 0.49).studyCardHierarchy, isNull);
      expect(empty.lerp(filled, 0.51).studyCardHierarchy,
          ZStudyCardHierarchy.tintedTile);
      // Aller-retour complet : t=1 rend exactement le côté `b`.
      final ZcrudTheme end = empty.lerp(filled, 1);
      expect(end.studyCardMargin, const EdgeInsetsDirectional.all(6));
      expect(end.studyCardBorderSide?.color, const Color(0xFF123456));
      expect(end.studyCardBadgeRadius, const Radius.circular(2));
    });
  });
}
