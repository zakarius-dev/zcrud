/// **CR-IFFD-64** — les dix jetons `ZcrudTheme.folderCard*` de la carte de
/// dossier d'étude par défaut.
///
/// La garde structurelle des **4 sites** (`z_theme_four_sites_guard_test.dart`)
/// vérifie déjà le CÂBLAGE. Celle-ci vérifie le CONTRAT que le câblage ne dit
/// pas :
/// * `null` par défaut — sans quoi le consommateur ne pourrait plus distinguer
///   « l'hôte n'a rien dit » de « l'hôte a choisi la valeur de référence » ;
/// * `copyWith` **transporte** chaque valeur (un oubli compile en silence) ;
/// * `lerp` est **null-préservant** : `null`↔`null` reste `null`, sinon la
///   valeur de référence du consommateur serait matérialisée par une simple
///   transition de thème (leçon `studyCardBadgeRadius`) ;
/// * un **plancher de contraste** ne s'interpole PAS : une valeur intermédiaire
///   serait un plancher que personne n'a choisi.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  group('🔴 CR-IFFD-64 — défaut `null` (rien n\'est imposé)', () {
    test('les dix jetons valent `null` sur un thème nu', () {
      const ZcrudTheme t = ZcrudTheme();
      expect(t.folderCardRadius, isNull);
      expect(t.folderCardBorderSide, isNull);
      expect(t.folderCardContentPadding, isNull);
      expect(t.folderCardAccentHeight, isNull);
      expect(t.folderCardTintAlpha, isNull);
      expect(t.folderCardIconTileSize, isNull);
      expect(t.folderCardIconTileRadius, isNull);
      expect(t.folderCardIconTileTintAlpha, isNull);
      expect(t.folderCardGlyphSize, isNull);
      expect(t.folderCardMinContrast, isNull);
    });

    test('le repli dérivé du thème Material ne les invente pas non plus', () {
      final ZcrudTheme t = ZcrudTheme.fallback(
        ThemeData.light(useMaterial3: true),
      );
      expect(t.folderCardBorderSide, isNull);
      expect(t.folderCardMinContrast, isNull);
      expect(t.folderCardAccentHeight, isNull);
    });
  });

  group('🔴 CR-IFFD-64 — `copyWith` transporte chaque jeton', () {
    test('les dix valeurs survivent à un `copyWith`', () {
      const ZcrudTheme t = ZcrudTheme();
      final ZcrudTheme out = t.copyWith(
        folderCardRadius: const Radius.circular(7),
        folderCardBorderSide: const BorderSide(width: 3),
        folderCardContentPadding: const EdgeInsetsDirectional.all(17),
        folderCardAccentHeight: 9,
        folderCardTintAlpha: 0.42,
        folderCardIconTileSize: 44,
        folderCardIconTileRadius: const Radius.circular(5),
        folderCardIconTileTintAlpha: 0.33,
        folderCardGlyphSize: 26,
        folderCardMinContrast: 4.5,
      );
      expect(out.folderCardRadius, const Radius.circular(7));
      expect(out.folderCardBorderSide?.width, 3);
      expect(out.folderCardContentPadding, const EdgeInsetsDirectional.all(17));
      expect(out.folderCardAccentHeight, 9);
      expect(out.folderCardTintAlpha, 0.42);
      expect(out.folderCardIconTileSize, 44);
      expect(out.folderCardIconTileRadius, const Radius.circular(5));
      expect(out.folderCardIconTileTintAlpha, 0.33);
      expect(out.folderCardGlyphSize, 26);
      expect(out.folderCardMinContrast, 4.5);
    });

    test('un `copyWith` VIDE ne perd aucune valeur déjà posée', () {
      const ZcrudTheme t = ZcrudTheme(
        folderCardAccentHeight: 9,
        folderCardMinContrast: 4.5,
        folderCardBorderSide: BorderSide(width: 3),
      );
      final ZcrudTheme out = t.copyWith();
      expect(out.folderCardAccentHeight, 9);
      expect(out.folderCardMinContrast, 4.5);
      expect(out.folderCardBorderSide?.width, 3);
    });
  });

  group('🔴 CR-IFFD-64 — `lerp` null-PRÉSERVANT', () {
    test('`null` ↔ `null` reste `null` à t = 0.5 (référence intacte)', () {
      const ZcrudTheme a = ZcrudTheme();
      const ZcrudTheme b = ZcrudTheme();
      final ZcrudTheme mid = a.lerp(b, 0.5);
      expect(mid.folderCardRadius, isNull);
      expect(mid.folderCardBorderSide, isNull);
      expect(mid.folderCardContentPadding, isNull);
      expect(mid.folderCardAccentHeight, isNull);
      expect(mid.folderCardTintAlpha, isNull);
      expect(mid.folderCardIconTileSize, isNull);
      expect(mid.folderCardIconTileRadius, isNull);
      expect(mid.folderCardIconTileTintAlpha, isNull);
      expect(mid.folderCardGlyphSize, isNull);
      expect(
        mid.folderCardMinContrast,
        isNull,
        reason:
            '🔴 un plancher matérialisé par une transition de thème est un '
            'plancher que personne n\'a choisi.',
      );
    });

    test('deux valeurs POSÉES s\'interpolent réellement', () {
      const ZcrudTheme a = ZcrudTheme(
        folderCardAccentHeight: 4,
        folderCardIconTileSize: 36,
        folderCardRadius: Radius.circular(12),
      );
      const ZcrudTheme b = ZcrudTheme(
        folderCardAccentHeight: 8,
        folderCardIconTileSize: 48,
        folderCardRadius: Radius.circular(20),
      );
      final ZcrudTheme mid = a.lerp(b, 0.5);
      expect(mid.folderCardAccentHeight, 6);
      expect(mid.folderCardIconTileSize, 42);
      expect(mid.folderCardRadius, const Radius.circular(16));
    });

    test('le PLANCHER est DISCRET : il bascule, il n\'interpole pas', () {
      const ZcrudTheme a = ZcrudTheme(folderCardMinContrast: 3);
      const ZcrudTheme b = ZcrudTheme(folderCardMinContrast: 7);
      expect(a.lerp(b, 0.25).folderCardMinContrast, 3);
      expect(a.lerp(b, 0.75).folderCardMinContrast, 7);
    });

    test('un liseré POSÉ d\'un seul côté s\'interpole depuis `BorderSide.none`',
        () {
      const ZcrudTheme a = ZcrudTheme();
      const ZcrudTheme b = ZcrudTheme(
        folderCardBorderSide: BorderSide(width: 4),
      );
      final ZcrudTheme mid = a.lerp(b, 0.5);
      expect(mid.folderCardBorderSide, isNotNull);
      expect(mid.folderCardBorderSide!.width, 2);
    });
  });
}
