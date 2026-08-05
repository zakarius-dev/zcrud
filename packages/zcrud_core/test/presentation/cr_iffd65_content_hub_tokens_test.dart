/// **CR-IFFD-65** — les quatorze jetons `ZcrudTheme.contentHub*` du hub
/// d'ajout de contenu.
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
/// * les jetons **DISCRETS** (densité, palette, nombre de colonnes, plancher de
///   contraste) ne s'interpolent PAS — une demi-densité, une demi-colonne ou un
///   plancher intermédiaire seraient des valeurs que personne n'a choisies.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  group('🔴 CR-IFFD-65 — défaut `null` (rien n\'est imposé)', () {
    test('les quatorze jetons valent `null` sur un thème nu', () {
      const ZcrudTheme t = ZcrudTheme();
      expect(t.contentHubDensity, isNull);
      expect(t.contentHubItemExtent, isNull);
      expect(t.contentHubItemRadius, isNull);
      expect(t.contentHubItemPadding, isNull);
      expect(t.contentHubItemTintAlpha, isNull);
      expect(t.contentHubAvatarSize, isNull);
      expect(t.contentHubAvatarTintAlpha, isNull);
      expect(t.contentHubGlyphSize, isNull);
      expect(t.contentHubAccents, isNull);
      expect(t.contentHubBadgeColor, isNull);
      expect(t.contentHubGridBreakpoint, isNull);
      expect(t.contentHubGridCrossAxisCount, isNull);
      expect(t.contentHubMinContrast, isNull);
      expect(t.contentHubSectionTitleStyle, isNull);
    });

    test('le repli dérivé du thème Material ne les invente pas non plus', () {
      final ZcrudTheme t = ZcrudTheme.fallback(
        ThemeData.light(useMaterial3: true),
      );
      expect(t.contentHubDensity, isNull);
      expect(t.contentHubAccents, isNull);
      expect(t.contentHubMinContrast, isNull);
      expect(t.contentHubGridCrossAxisCount, isNull);
    });
  });

  group('🔴 CR-IFFD-65 — `copyWith` transporte chaque jeton', () {
    test('les quatorze valeurs survivent à un `copyWith`', () {
      const ZcrudTheme t = ZcrudTheme();
      final ZcrudTheme out = t.copyWith(
        contentHubDensity: ZContentHubDensity.compact,
        contentHubItemExtent: 96,
        contentHubItemRadius: const Radius.circular(7),
        contentHubItemPadding: const EdgeInsetsDirectional.all(17),
        contentHubItemTintAlpha: 0.42,
        contentHubAvatarSize: 44,
        contentHubAvatarTintAlpha: 0.33,
        contentHubGlyphSize: 26,
        contentHubAccents: const <Color>[Color(0xFF010203)],
        contentHubBadgeColor: const Color(0xFF040506),
        contentHubGridBreakpoint: 720,
        contentHubGridCrossAxisCount: 3,
        contentHubMinContrast: 4.5,
        contentHubSectionTitleStyle: const TextStyle(letterSpacing: 3),
      );
      expect(out.contentHubDensity, ZContentHubDensity.compact);
      expect(out.contentHubItemExtent, 96);
      expect(out.contentHubItemRadius, const Radius.circular(7));
      expect(out.contentHubItemPadding, const EdgeInsetsDirectional.all(17));
      expect(out.contentHubItemTintAlpha, 0.42);
      expect(out.contentHubAvatarSize, 44);
      expect(out.contentHubAvatarTintAlpha, 0.33);
      expect(out.contentHubGlyphSize, 26);
      expect(out.contentHubAccents, const <Color>[Color(0xFF010203)]);
      expect(out.contentHubBadgeColor, const Color(0xFF040506));
      expect(out.contentHubGridBreakpoint, 720);
      expect(out.contentHubGridCrossAxisCount, 3);
      expect(out.contentHubMinContrast, 4.5);
      expect(out.contentHubSectionTitleStyle?.letterSpacing, 3);
    });

    test('un `copyWith` VIDE ne perd aucune valeur déjà posée', () {
      const ZcrudTheme t = ZcrudTheme(
        contentHubDensity: ZContentHubDensity.compact,
        contentHubGridCrossAxisCount: 3,
        contentHubAccents: <Color>[Color(0xFF010203)],
      );
      final ZcrudTheme out = t.copyWith();
      expect(out.contentHubDensity, ZContentHubDensity.compact);
      expect(out.contentHubGridCrossAxisCount, 3);
      expect(out.contentHubAccents, const <Color>[Color(0xFF010203)]);
    });
  });

  group('🔴 CR-IFFD-65 — `lerp` null-PRÉSERVANT', () {
    test('`null` ↔ `null` reste `null` à t = 0.5 (référence intacte)', () {
      const ZcrudTheme a = ZcrudTheme();
      const ZcrudTheme b = ZcrudTheme();
      final ZcrudTheme mid = a.lerp(b, 0.5);
      expect(mid.contentHubDensity, isNull);
      expect(mid.contentHubItemExtent, isNull);
      expect(mid.contentHubItemRadius, isNull);
      expect(mid.contentHubItemPadding, isNull);
      expect(mid.contentHubItemTintAlpha, isNull);
      expect(mid.contentHubAvatarSize, isNull);
      expect(mid.contentHubAvatarTintAlpha, isNull);
      expect(mid.contentHubGlyphSize, isNull);
      expect(mid.contentHubAccents, isNull);
      expect(mid.contentHubBadgeColor, isNull);
      expect(mid.contentHubGridBreakpoint, isNull);
      expect(mid.contentHubGridCrossAxisCount, isNull);
      expect(
        mid.contentHubMinContrast,
        isNull,
        reason:
            '🔴 un plancher matérialisé par une transition de thème est un '
            'plancher que personne n\'a choisi.',
      );
      expect(mid.contentHubSectionTitleStyle, isNull);
    });

    test('deux valeurs POSÉES s\'interpolent réellement', () {
      const ZcrudTheme a = ZcrudTheme(
        contentHubItemExtent: 100,
        contentHubAvatarSize: 40,
        contentHubItemRadius: Radius.circular(12),
        contentHubGridBreakpoint: 600,
      );
      const ZcrudTheme b = ZcrudTheme(
        contentHubItemExtent: 200,
        contentHubAvatarSize: 60,
        contentHubItemRadius: Radius.circular(20),
        contentHubGridBreakpoint: 800,
      );
      final ZcrudTheme mid = a.lerp(b, 0.5);
      expect(mid.contentHubItemExtent, 150);
      expect(mid.contentHubAvatarSize, 50);
      expect(mid.contentHubItemRadius, const Radius.circular(16));
      expect(mid.contentHubGridBreakpoint, 700);
    });

    test('🔴 les jetons DISCRETS basculent, ils ne s\'interpolent PAS', () {
      const ZcrudTheme a = ZcrudTheme(
        contentHubDensity: ZContentHubDensity.comfortable,
        contentHubGridCrossAxisCount: 2,
        contentHubMinContrast: 3,
        contentHubAccents: <Color>[Color(0xFF010203)],
      );
      const ZcrudTheme b = ZcrudTheme(
        contentHubDensity: ZContentHubDensity.compact,
        contentHubGridCrossAxisCount: 4,
        contentHubMinContrast: 7,
        contentHubAccents: <Color>[Color(0xFF040506)],
      );

      final ZcrudTheme early = a.lerp(b, 0.25);
      expect(early.contentHubDensity, ZContentHubDensity.comfortable);
      expect(early.contentHubGridCrossAxisCount, 2);
      expect(early.contentHubMinContrast, 3);
      expect(early.contentHubAccents, const <Color>[Color(0xFF010203)]);

      final ZcrudTheme late = a.lerp(b, 0.75);
      expect(late.contentHubDensity, ZContentHubDensity.compact);
      expect(
        late.contentHubGridCrossAxisCount,
        4,
        reason: '🔴 une demi-colonne n\'existe pas.',
      );
      expect(late.contentHubMinContrast, 7);
      expect(late.contentHubAccents, const <Color>[Color(0xFF040506)]);
    });

    test('un seul côté POSÉ ne matérialise pas de valeur fantôme discrète', () {
      const ZcrudTheme a = ZcrudTheme();
      const ZcrudTheme b = ZcrudTheme(
        contentHubDensity: ZContentHubDensity.compact,
      );
      // Au début de la transition, l'absence est PRÉSERVÉE : le consommateur
      // continue d'appliquer sa référence.
      expect(a.lerp(b, 0.25).contentHubDensity, isNull);
      expect(a.lerp(b, 0.75).contentHubDensity, ZContentHubDensity.compact);
    });
  });

  group('🔴 CR-IFFD-65 — l\'énumération de densité est un CONTRAT', () {
    test('deux valeurs, et la référence est `comfortable`', () {
      expect(ZContentHubDensity.values, hasLength(2));
      expect(
        ZContentHubDensity.values.first,
        ZContentHubDensity.comfortable,
        reason:
            '🔴 `comfortable` est le rendu de RÉFÉRENCE depuis CR-IFFD-65 ; '
            '`compact` restitue la densité d\'AVANT — elle n\'a pas disparu.',
      );
      expect(ZContentHubDensity.values, contains(ZContentHubDensity.compact));
    });
  });
}
