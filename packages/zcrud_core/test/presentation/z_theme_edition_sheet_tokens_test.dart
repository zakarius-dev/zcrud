/// 🔴 Gardes des jetons **feuille d'édition** et **chrome d'édition**
/// (CR-TOKENS, 2026-08-09).
///
/// Ces neuf jetons sont le **maillon 2** de la chaîne `paramètre > jeton >
/// référence` que `zcrud_navigation` réalise (`zSheetFrameMetricsOf`,
/// `zEditionChromeMetricsOf`). Les gardes ci-dessous affirment ce que
/// `zcrud_core` doit tenir **seul** :
///
/// 1. **aucun hôte passif ne bouge** — les neuf sont absents de
///    [ZcrudTheme.fallback] ; c'est la leçon mesurée du lot précédent
///    (`surfaceColor` posé au repli aurait changé le fond de tout hôte) ;
/// 2. **`lerp` correct par FAMILLE** — discret pour le mode, plancher pour les
///    dimensions, `_lerpNullableColor` pour la couleur, directionnel pour les
///    marges ;
/// 3. **`copyWith` propage** réellement les neuf valeurs.
///
/// ⚠️ **Anti-vacuité** : chaque garde de `lerp` de plancher affirme d'abord que
/// la valeur mesurée n'est **pas** celle qu'un `lerp` naïf produirait (`0`),
/// sans quoi elle passerait aussi avec le mauvais helper.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  group('CR-TOKENS — jetons `editionSheet*` / `editionChrome*`', () {
    // ══════════════════════════════════════════════════════════════════════
    // 1. HÔTE PASSIF INCHANGÉ — les neuf jetons sont ABSENTS du repli
    // ══════════════════════════════════════════════════════════════════════

    test(
      'ET-1 — les 9 jetons sont ABSENTS de `fallback()` (clair ET sombre) : '
      'un hôte passif ne bouge pas',
      () {
        for (final ThemeData base in <ThemeData>[
          ThemeData.light(),
          ThemeData.dark(),
        ]) {
          final ZcrudTheme f = ZcrudTheme.fallback(base);
          expect(
            f.editionSheetFrameMode,
            isNull,
            reason:
                '🔴 le repli POSE un mode de cadre : tout hôte passif se met à '
                'encadrer (ou à ne plus encadrer) sans l\'avoir demandé, et la '
                'référence de `zcrud_navigation` devient inatteignable.',
          );
          expect(f.editionSheetWidthRatio, isNull);
          expect(f.editionSheetMaxWidth, isNull);
          expect(f.editionSheetBorderColor, isNull);
          expect(f.editionSheetBorderWidth, isNull);
          expect(f.editionChromeMinTouchTarget, isNull);
          expect(f.editionChromeHeaderPadding, isNull);
          expect(f.editionChromeActionBarPadding, isNull);
          expect(f.editionChromePageHeaderExpandedHeight, isNull);
        }
        // Anti-vacuité : le repli pose BIEN d'autres jetons — la garde ne
        // mesure donc pas un `fallback()` vide.
        expect(ZcrudTheme.fallback(ThemeData.light()).fieldBorderColor, isNotNull);
      },
    );

    test('ET-2 — un `ZcrudTheme()` nu laisse les 9 jetons `null`', () {
      const ZcrudTheme t = ZcrudTheme();
      expect(t.editionSheetFrameMode, isNull);
      expect(t.editionSheetWidthRatio, isNull);
      expect(t.editionSheetMaxWidth, isNull);
      expect(t.editionSheetBorderColor, isNull);
      expect(t.editionSheetBorderWidth, isNull);
      expect(t.editionChromeMinTouchTarget, isNull);
      expect(t.editionChromeHeaderPadding, isNull);
      expect(t.editionChromeActionBarPadding, isNull);
      expect(t.editionChromePageHeaderExpandedHeight, isNull);
    });

    // ══════════════════════════════════════════════════════════════════════
    // 2. copyWith PROPAGE
    // ══════════════════════════════════════════════════════════════════════

    test('ET-3 — `copyWith` propage les 9 jetons', () {
      final ZcrudTheme t = const ZcrudTheme().copyWith(
        editionSheetFrameMode: 'never',
        editionSheetWidthRatio: 0.5,
        editionSheetMaxWidth: 900,
        editionSheetBorderColor: const Color(0xFF112233),
        editionSheetBorderWidth: 3,
        editionChromeMinTouchTarget: 56,
        editionChromeHeaderPadding:
            const EdgeInsetsDirectional.fromSTEB(1, 2, 3, 4),
        editionChromeActionBarPadding:
            const EdgeInsetsDirectional.fromSTEB(5, 6, 7, 8),
        editionChromePageHeaderExpandedHeight: 200,
      );
      expect(t.editionSheetFrameMode, 'never');
      expect(t.editionSheetWidthRatio, 0.5);
      expect(t.editionSheetMaxWidth, 900);
      expect(t.editionSheetBorderColor, const Color(0xFF112233));
      expect(t.editionSheetBorderWidth, 3);
      expect(t.editionChromeMinTouchTarget, 56);
      expect(
        t.editionChromeHeaderPadding,
        const EdgeInsetsDirectional.fromSTEB(1, 2, 3, 4),
      );
      expect(
        t.editionChromeActionBarPadding,
        const EdgeInsetsDirectional.fromSTEB(5, 6, 7, 8),
      );
      expect(t.editionChromePageHeaderExpandedHeight, 200);
    });

    // ══════════════════════════════════════════════════════════════════════
    // 3. lerp — PAR FAMILLE, chacune avec son anti-vacuité
    // ══════════════════════════════════════════════════════════════════════

    test('ET-4 — `lerp` de deux `null` reste `null` : le repli n\'est pas GELÉ',
        () {
      const ZcrudTheme a = ZcrudTheme();
      for (final double t in <double>[0, 0.25, 0.5, 0.75, 1]) {
        final ZcrudTheme l = a.lerp(const ZcrudTheme(), t);
        expect(l.editionSheetFrameMode, isNull, reason: 't=$t');
        expect(l.editionSheetWidthRatio, isNull, reason: 't=$t');
        expect(l.editionSheetMaxWidth, isNull, reason: 't=$t');
        expect(l.editionSheetBorderColor, isNull, reason: 't=$t');
        expect(l.editionSheetBorderWidth, isNull, reason: 't=$t');
        expect(l.editionChromeMinTouchTarget, isNull, reason: 't=$t');
        expect(l.editionChromeHeaderPadding, isNull, reason: 't=$t');
        expect(l.editionChromeActionBarPadding, isNull, reason: 't=$t');
        expect(
          l.editionChromePageHeaderExpandedHeight,
          isNull,
          reason: 't=$t',
        );
      }
    });

    test('ET-5 — le MODE est DISCRET : bascule à t = 0,5, jamais de mélange',
        () {
      const ZcrudTheme a = ZcrudTheme(editionSheetFrameMode: 'always');
      const ZcrudTheme b = ZcrudTheme(editionSheetFrameMode: 'never');
      expect(a.lerp(b, 0).editionSheetFrameMode, 'always');
      expect(a.lerp(b, 0.25).editionSheetFrameMode, 'always');
      expect(a.lerp(b, 0.75).editionSheetFrameMode, 'never');
      expect(a.lerp(b, 1).editionSheetFrameMode, 'never');
      // Anti-vacuité : les deux bornes DIFFÈRENT.
      expect(a.editionSheetFrameMode, isNot(b.editionSheetFrameMode));
    });

    test(
      'ET-6 — DIMENSIONS : `lerp` de PLANCHER — un côté `null` ne matérialise '
      'JAMAIS `0`',
      () {
        const ZcrudTheme vide = ZcrudTheme();
        const ZcrudTheme plein = ZcrudTheme(
          editionSheetWidthRatio: 0.9,
          editionSheetMaxWidth: 640,
          editionSheetBorderWidth: 1,
          editionChromeMinTouchTarget: 48,
          editionChromePageHeaderExpandedHeight: 112,
        );
        // 🔴 t = 0 est le point où un `_lerpNullableDouble` rendrait `0` pour
        // les cinq. C'est exactement la fenêtre où la feuille aurait une
        // largeur nulle et le chrome plus aucun plancher de cible (AD-13).
        final ZcrudTheme l = vide.lerp(plein, 0);
        expect(l.editionSheetWidthRatio, 0.9,
            reason: '🔴 `0` matérialisé : feuille de largeur NULLE.');
        expect(l.editionSheetMaxWidth, 640);
        expect(l.editionSheetBorderWidth, 1);
        expect(l.editionChromeMinTouchTarget, 48,
            reason: '🔴 plancher de cible tombé à 0 pendant la transition.');
        expect(l.editionChromePageHeaderExpandedHeight, 112);
        // Sens inverse (le `null` est du côté `other`, à t = 1).
        final ZcrudTheme r = plein.lerp(vide, 1);
        expect(r.editionSheetWidthRatio, 0.9);
        expect(r.editionChromeMinTouchTarget, 48);
      },
    );

    test('ET-7 — DIMENSIONS : quand les DEUX côtés sont posés, ça interpole',
        () {
      const ZcrudTheme a = ZcrudTheme(
        editionSheetWidthRatio: 0.5,
        editionChromeMinTouchTarget: 40,
      );
      const ZcrudTheme b = ZcrudTheme(
        editionSheetWidthRatio: 1,
        editionChromeMinTouchTarget: 60,
      );
      expect(a.lerp(b, 0.5).editionSheetWidthRatio, 0.75);
      expect(a.lerp(b, 0.5).editionChromeMinTouchTarget, 50);
    });

    test(
      'ET-8 — COULEUR : `_lerpNullableColor`, jamais `Color.lerp` — pas de '
      'cadre FANTÔME transparent',
      () {
        const Color c = Color(0xFF445566);
        const ZcrudTheme vide = ZcrudTheme();
        const ZcrudTheme plein = ZcrudTheme(editionSheetBorderColor: c);
        final Color? l = vide.lerp(plein, 0).editionSheetBorderColor;
        expect(l, c,
            reason: '🔴 `Color.lerp(null, c, 0)` rendrait `c` à alpha 0 : une '
                'couleur fantôme substituée au rôle `outlineVariant` du '
                'consommateur.');
        // Anti-vacuité : la valeur attendue N'EST PAS la version transparente.
        expect(l, isNot(c.withValues(alpha: 0)));
        // Les deux côtés posés ⇒ interpolation réelle.
        final Color? m = const ZcrudTheme(
          editionSheetBorderColor: Color(0xFF000000),
        ).lerp(const ZcrudTheme(editionSheetBorderColor: Color(0xFFFFFFFF)), 0.5)
            .editionSheetBorderColor;
        expect(m, isNotNull);
        expect(m, isNot(const Color(0xFF000000)));
        expect(m, isNot(const Color(0xFFFFFFFF)));
      },
    );

    test(
      'ET-9 — MARGES : interpolation DIRECTIONNELLE préservée (AD-13, RTL)',
      () {
        const ZcrudTheme a = ZcrudTheme(
          editionChromeHeaderPadding:
              EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
          editionChromeActionBarPadding:
              EdgeInsetsDirectional.fromSTEB(8, 8, 8, 8),
        );
        const ZcrudTheme b = ZcrudTheme(
          editionChromeHeaderPadding:
              EdgeInsetsDirectional.fromSTEB(32, 16, 16, 16),
          editionChromeActionBarPadding:
              EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
        );
        final ZcrudTheme l = a.lerp(b, 0.5);
        expect(
          l.editionChromeHeaderPadding,
          isA<EdgeInsetsDirectional>(),
          reason: '🔴 la nature DIRECTIONNELLE de la marge a été perdue : en '
              'RTL le chrome se dégagerait du mauvais côté.',
        );
        expect(
          l.editionChromeHeaderPadding,
          const EdgeInsetsDirectional.fromSTEB(24, 12, 12, 12),
        );
        expect(
          l.editionChromeActionBarPadding,
          const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 12),
        );
      },
    );
  });
}
