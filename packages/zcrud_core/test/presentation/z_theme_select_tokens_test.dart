/// 🔴 Gardes des **huit jetons de sélection** `ZcrudTheme.select*`
/// (CR-SELECT-SEAM, 2026-08-09).
///
/// Ils forment le **maillon 2** de la chaîne `paramètre (ZSelectTileSpec) >
/// jeton > référence (ZSelectTileReference)` que `zcrud_select` réalise dans
/// `zSelectTileMetricsOf`. Ce que `zcrud_core` doit tenir **seul** :
///
/// 1. **aucun hôte passif ne bouge** — les huit sont absents de
///    [ZcrudTheme.fallback] ;
/// 2. **`lerp` correct par FAMILLE** — discret pour les trois paliers nommés,
///    plancher pour les quatre dimensions, `_lerpNullableColor` pour la couleur ;
/// 3. **`copyWith` propage** réellement les huit valeurs.
///
/// ⚠️ **Anti-vacuité** systématique : chaque garde de `lerp` affirme d'abord que
/// la valeur attendue n'est **pas** celle qu'un helper naïf produirait, sans quoi
/// elle passerait aussi avec le mauvais.
///
/// 🔴 **Anti-tautologie** : les valeurs attendues sont des **littéraux** posés
/// par le test lui-même, jamais une constante du code sous test.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  group('CR-SELECT-SEAM — jetons `ZcrudTheme.select*`', () {
    // ══════════════════════════════════════════════════════════════════════
    // 1. HÔTE PASSIF INCHANGÉ — les huit jetons sont ABSENTS du repli
    // ══════════════════════════════════════════════════════════════════════

    test(
      'ST-1 — les 8 jetons sont ABSENTS de `fallback()` (clair ET sombre) : '
      'un hôte passif ne bouge pas d\'un pixel',
      () {
        for (final ThemeData base in <ThemeData>[
          ThemeData.light(),
          ThemeData.dark(),
        ]) {
          final ZcrudTheme f = ZcrudTheme.fallback(base);
          expect(
            f.selectTileBorderColor,
            isNull,
            reason:
                '🔴 le repli POSE une teinte de bordure : tout hôte passif voit '
                'ses déclencheurs de sélection changer de couleur sans l\'avoir '
                'demandé, et le rôle `outlineVariant` de `zcrud_select` devient '
                'inatteignable.',
          );
          expect(f.selectTileBorderWidth, isNull);
          expect(f.selectTileRadius, isNull);
          expect(f.selectTileMinHeight, isNull);
          expect(f.selectDialogBreakpoint, isNull);
          expect(f.selectMonoChoiceStyle, isNull);
          expect(f.selectMultiChoiceStyle, isNull);
          expect(f.selectModalShape, isNull);
        }
        // Anti-vacuité : le repli pose BIEN d'autres jetons — la garde ne
        // mesure donc pas un `fallback()` vide.
        expect(
          ZcrudTheme.fallback(ThemeData.light()).fieldBorderColor,
          isNotNull,
        );
      },
    );

    test('ST-2 — un `ZcrudTheme()` nu laisse les 8 jetons `null`', () {
      const ZcrudTheme t = ZcrudTheme();
      expect(t.selectTileBorderColor, isNull);
      expect(t.selectTileBorderWidth, isNull);
      expect(t.selectTileRadius, isNull);
      expect(t.selectTileMinHeight, isNull);
      expect(t.selectDialogBreakpoint, isNull);
      expect(t.selectMonoChoiceStyle, isNull);
      expect(t.selectMultiChoiceStyle, isNull);
      expect(t.selectModalShape, isNull);
    });

    // ══════════════════════════════════════════════════════════════════════
    // 2. copyWith PROPAGE
    // ══════════════════════════════════════════════════════════════════════

    test('ST-3 — `copyWith` propage les 8 jetons', () {
      final ZcrudTheme t = const ZcrudTheme().copyWith(
        selectTileBorderColor: const Color(0xFF102030),
        selectTileBorderWidth: 3,
        selectTileRadius: 24,
        selectTileMinHeight: 64,
        selectDialogBreakpoint: 900,
        selectMonoChoiceStyle: 'chips',
        selectMultiChoiceStyle: 'checkboxes',
        selectModalShape: 'fullPage',
      );
      expect(t.selectTileBorderColor, const Color(0xFF102030));
      expect(t.selectTileBorderWidth, 3);
      expect(t.selectTileRadius, 24);
      expect(t.selectTileMinHeight, 64);
      expect(t.selectDialogBreakpoint, 900);
      expect(t.selectMonoChoiceStyle, 'chips');
      expect(t.selectMultiChoiceStyle, 'checkboxes');
      expect(t.selectModalShape, 'fullPage');
      // Anti-vacuité : un `copyWith` qui ne propagerait RIEN rendrait `null`
      // partout ; on affirme aussi que la source, elle, était bien vide.
      expect(const ZcrudTheme().selectTileRadius, isNull);
    });

    // ══════════════════════════════════════════════════════════════════════
    // 3. lerp — PAR FAMILLE, chacune avec son anti-vacuité
    // ══════════════════════════════════════════════════════════════════════

    test('ST-4 — `lerp` de deux `null` reste `null` : le repli n\'est pas GELÉ',
        () {
      const ZcrudTheme a = ZcrudTheme();
      for (final double t in <double>[0, 0.25, 0.5, 0.75, 1]) {
        final ZcrudTheme l = a.lerp(const ZcrudTheme(), t);
        expect(l.selectTileBorderColor, isNull, reason: 't=$t');
        expect(l.selectTileBorderWidth, isNull, reason: 't=$t');
        expect(l.selectTileRadius, isNull, reason: 't=$t');
        expect(l.selectTileMinHeight, isNull, reason: 't=$t');
        expect(l.selectDialogBreakpoint, isNull, reason: 't=$t');
        expect(l.selectMonoChoiceStyle, isNull, reason: 't=$t');
        expect(l.selectMultiChoiceStyle, isNull, reason: 't=$t');
        expect(l.selectModalShape, isNull, reason: 't=$t');
      }
    });

    test(
      'ST-5 — les 3 PALIERS NOMMÉS sont DISCRETS : bascule à t = 0,5, jamais '
      'de mélange',
      () {
        const ZcrudTheme a = ZcrudTheme(
          selectMonoChoiceStyle: 'radios',
          selectMultiChoiceStyle: 'switches',
          selectModalShape: 'bottomSheet',
        );
        const ZcrudTheme b = ZcrudTheme(
          selectMonoChoiceStyle: 'chips',
          selectMultiChoiceStyle: 'checkboxes',
          selectModalShape: 'popupDialog',
        );
        expect(a.lerp(b, 0).selectMonoChoiceStyle, 'radios');
        expect(a.lerp(b, 0.25).selectMonoChoiceStyle, 'radios');
        expect(a.lerp(b, 0.75).selectMonoChoiceStyle, 'chips');
        expect(a.lerp(b, 1).selectMonoChoiceStyle, 'chips');
        expect(a.lerp(b, 0.25).selectMultiChoiceStyle, 'switches');
        expect(a.lerp(b, 0.75).selectMultiChoiceStyle, 'checkboxes');
        expect(a.lerp(b, 0.25).selectModalShape, 'bottomSheet');
        expect(a.lerp(b, 0.75).selectModalShape, 'popupDialog');
        // 🔴 Anti-vacuité : les deux bornes DIFFÈRENT pour les trois. Sans
        // cela, la garde passerait même si `lerp` rendait toujours `a`.
        expect(a.selectMonoChoiceStyle, isNot(b.selectMonoChoiceStyle));
        expect(a.selectMultiChoiceStyle, isNot(b.selectMultiChoiceStyle));
        expect(a.selectModalShape, isNot(b.selectModalShape));
      },
    );

    test(
      'ST-6 — les 4 DIMENSIONS : `lerp` de PLANCHER — un côté `null` ne '
      'matérialise JAMAIS `0`',
      () {
        const ZcrudTheme vide = ZcrudTheme();
        // Littéraux du test, PAS les constantes de `ZSelectTileReference` (qui
        // vit dans un autre paquet) : une garde tautologique suivrait la
        // référence au lieu de la mesurer.
        const ZcrudTheme plein = ZcrudTheme(
          selectTileBorderWidth: 1,
          selectTileRadius: 12,
          selectTileMinHeight: 48,
          selectDialogBreakpoint: 600,
        );
        // 🔴 t = 0 est le point où `_lerpNullableDouble` rendrait `0` pour les
        // quatre : bordure absente, coins carrés, PLUS AUCUN plancher de cible
        // accessible (AD-13), et toute la sélection basculée en dialogue.
        final ZcrudTheme l = vide.lerp(plein, 0);
        expect(l.selectTileBorderWidth, 1,
            reason: '🔴 `0` matérialisé : bordure ABSENTE en transition.');
        expect(l.selectTileRadius, 12,
            reason: '🔴 `0` matérialisé : coins CARRÉS en transition.');
        expect(l.selectTileMinHeight, 48,
            reason: '🔴 plancher de cible tombé à 0 pendant la transition '
                '(AD-13).');
        expect(l.selectDialogBreakpoint, 600,
            reason: '🔴 seuil à 0 : TOUT bascule en boîte de dialogue.');
        // Anti-vacuité : la valeur attendue n'est PAS `0`.
        expect(l.selectTileMinHeight, isNot(0));
        // Sens inverse (le `null` est du côté `other`, à t = 1).
        final ZcrudTheme r = plein.lerp(vide, 1);
        expect(r.selectTileMinHeight, 48);
        expect(r.selectDialogBreakpoint, 600);
      },
    );

    test('ST-7 — DIMENSIONS : quand les DEUX côtés sont posés, ça interpole',
        () {
      const ZcrudTheme a = ZcrudTheme(
        selectTileRadius: 8,
        selectTileMinHeight: 48,
      );
      const ZcrudTheme b = ZcrudTheme(
        selectTileRadius: 16,
        selectTileMinHeight: 68,
      );
      expect(a.lerp(b, 0.5).selectTileRadius, 12);
      expect(a.lerp(b, 0.5).selectTileMinHeight, 58);
    });

    test(
      'ST-8 — COULEUR : `_lerpNullableColor`, jamais `Color.lerp` — pas de '
      'bordure FANTÔME transparente',
      () {
        const Color c = Color(0xFF778899);
        const ZcrudTheme vide = ZcrudTheme();
        const ZcrudTheme plein = ZcrudTheme(selectTileBorderColor: c);
        final Color? l = vide.lerp(plein, 0).selectTileBorderColor;
        expect(
          l,
          c,
          reason: '🔴 `Color.lerp(null, c, 0)` rendrait `c` à alpha 0 : une '
              'couleur fantôme substituée au rôle `outlineVariant` que '
              '`zcrud_select` applique en repli.',
        );
        // Anti-vacuité : la valeur attendue N'EST PAS la version transparente.
        expect(l, isNot(c.withValues(alpha: 0)));
        // Les deux côtés posés ⇒ interpolation réelle.
        final Color? m = const ZcrudTheme(
          selectTileBorderColor: Color(0xFF000000),
        )
            .lerp(
              const ZcrudTheme(selectTileBorderColor: Color(0xFFFFFFFF)),
              0.5,
            )
            .selectTileBorderColor;
        expect(m, isNotNull);
        expect(m, isNot(const Color(0xFF000000)));
        expect(m, isNot(const Color(0xFFFFFFFF)));
      },
    );
  });
}
