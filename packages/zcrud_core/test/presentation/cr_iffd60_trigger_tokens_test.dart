/// **CR-IFFD-60** — jetons composables du déclencheur de fratrie
/// (`subfolderTriggerFill` / `subfolderTriggerBorder` /
/// `subfolderTriggerElevation`) : transport (`copyWith`) et interpolation
/// (`lerp`) null-préservante.
///
/// L'invariant critique est celui de `badgeRadius` (leçon mesurée) : `null`
/// des DEUX côtés doit RESTER `null` — matérialiser une valeur au `lerp`
/// GÈLERAIT « la variante décide » à la première transition de thème (Flutter
/// lerpe à chaque changement), et la précédence documentée cesserait ensuite
/// de s'appliquer. Le câblage aux 4 sites est, lui, tenu par la garde
/// structurelle `z_theme_four_sites_guard_test.dart`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  const ZcrudTheme filled = ZcrudTheme(
    subfolderTriggerFill: ZSubfolderTriggerFill.surfaceContainerLow,
    subfolderTriggerBorder: ZSubfolderTriggerBorder.outline,
    subfolderTriggerElevation: 3,
  );

  group('CR-IFFD-60 — jetons subfolderTrigger*', () {
    test('défaut : TOUS nuls (la variante décide, rendu inchangé)', () {
      const ZcrudTheme theme = ZcrudTheme();
      expect(theme.subfolderTriggerFill, isNull);
      expect(theme.subfolderTriggerBorder, isNull);
      expect(theme.subfolderTriggerElevation, isNull);
    });

    test('copyWith transporte chaque jeton — et n\'efface rien sans demande',
        () {
      final ZcrudTheme copied = const ZcrudTheme().copyWith(
        subfolderTriggerFill: ZSubfolderTriggerFill.surfaceContainerHighest,
        subfolderTriggerBorder: ZSubfolderTriggerBorder.outlineVariant,
        subfolderTriggerElevation: 1,
      );
      expect(
        copied.subfolderTriggerFill,
        ZSubfolderTriggerFill.surfaceContainerHighest,
      );
      expect(
        copied.subfolderTriggerBorder,
        ZSubfolderTriggerBorder.outlineVariant,
      );
      expect(copied.subfolderTriggerElevation, 1);
      // Sans argument : les valeurs EXISTANTES restent.
      final ZcrudTheme kept = filled.copyWith();
      expect(kept.subfolderTriggerFill, ZSubfolderTriggerFill.surfaceContainerLow);
      expect(kept.subfolderTriggerBorder, ZSubfolderTriggerBorder.outline);
      expect(kept.subfolderTriggerElevation, 3);
    });

    test('lerp : `null` des DEUX côtés RESTE `null` (précédence jamais GELÉE)',
        () {
      const ZcrudTheme a = ZcrudTheme();
      const ZcrudTheme b = ZcrudTheme();
      for (final double t in <double>[0, 0.25, 0.5, 1]) {
        final ZcrudTheme l = a.lerp(b, t);
        expect(l.subfolderTriggerFill, isNull, reason: 't=$t');
        expect(l.subfolderTriggerBorder, isNull, reason: 't=$t');
        expect(l.subfolderTriggerElevation, isNull, reason: 't=$t');
      }
    });

    test('lerp : discrets à bascule au point milieu, élévation CONTINUE', () {
      const ZcrudTheme a = ZcrudTheme();
      // Discrets : la valeur n'apparaît qu'à t >= 0.5.
      expect(a.lerp(filled, 0.25).subfolderTriggerFill, isNull);
      expect(
        a.lerp(filled, 0.75).subfolderTriggerFill,
        ZSubfolderTriggerFill.surfaceContainerLow,
      );
      expect(a.lerp(filled, 0.25).subfolderTriggerBorder, isNull);
      expect(
        a.lerp(filled, 0.75).subfolderTriggerBorder,
        ZSubfolderTriggerBorder.outline,
      );
      // Continue : interpolation réelle (0 -> 3).
      expect(a.lerp(filled, 0.5).subfolderTriggerElevation, closeTo(1.5, 1e-9));
      expect(filled.lerp(filled, 0.5).subfolderTriggerElevation, 3);
    });
  });
}
