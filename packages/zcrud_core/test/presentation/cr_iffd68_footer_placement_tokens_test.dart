/// **CR-IFFD-68** — les deux jetons de DISPOSITION du bas de carte de dossier
/// (`folderCardFooterPlacement`, `folderCardFooterBesideMinWidth`).
///
/// La garde structurelle des **4 sites** (`z_theme_four_sites_guard_test.dart`)
/// vérifie le CÂBLAGE. Celle-ci vérifie le CONTRAT que le câblage ne dit pas :
/// * `null` par défaut — sans quoi le consommateur ne pourrait plus distinguer
///   « l'hôte n'a rien dit » de « l'hôte a choisi la disposition de
///   référence », et la primitive `ZFolderCard` perdrait son défaut historique ;
/// * `copyWith` **transporte** chaque valeur (un oubli compile en silence) ;
/// * `lerp` est **null-préservant** et **DISCRET** : ni demi-empilement, ni
///   point de rupture intermédiaire — une transition de thème ne doit pas
///   faire basculer la mise en page à mi-animation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  group('🔴 CR-IFFD-68 — défaut `null` (rien n\'est imposé)', () {
    test('les deux jetons valent `null` sur un thème nu', () {
      const ZcrudTheme t = ZcrudTheme();
      expect(t.folderCardFooterPlacement, isNull);
      expect(t.folderCardFooterBesideMinWidth, isNull);
    });

    test('le repli dérivé du thème Material ne les invente pas non plus', () {
      final ZcrudTheme t = ZcrudTheme.fallback(
        ThemeData.light(useMaterial3: true),
      );
      expect(
        t.folderCardFooterPlacement,
        isNull,
        reason:
            '🔴 un repli qui matérialise une disposition ôterait à la primitive '
            '`ZFolderCard` son défaut HISTORIQUE (`beside`), donc ferait bouger '
            'tout hôte passif sans qu\'il ait rien déclaré.',
      );
      expect(t.folderCardFooterBesideMinWidth, isNull);
    });

    test('les trois dispositions existent, et `beside` reste la première', () {
      // L'ordre porte du sens : `beside` est le rendu historique de la
      // primitive. Un `values.first` qui changerait signalerait une
      // renumérotation silencieuse.
      expect(ZFolderCardFooterPlacement.values, hasLength(3));
      expect(
        ZFolderCardFooterPlacement.values.first,
        ZFolderCardFooterPlacement.beside,
      );
    });
  });

  group('🔴 CR-IFFD-68 — `copyWith` transporte chaque jeton', () {
    test('les deux valeurs survivent à un `copyWith`', () {
      const ZcrudTheme t = ZcrudTheme();
      final ZcrudTheme out = t.copyWith(
        folderCardFooterPlacement: ZFolderCardFooterPlacement.below,
        folderCardFooterBesideMinWidth: 640,
      );
      expect(
        out.folderCardFooterPlacement,
        ZFolderCardFooterPlacement.below,
      );
      expect(out.folderCardFooterBesideMinWidth, 640);
    });

    test('un `copyWith` VIDE ne perd aucune valeur déjà posée', () {
      const ZcrudTheme t = ZcrudTheme(
        folderCardFooterPlacement: ZFolderCardFooterPlacement.adaptive,
        folderCardFooterBesideMinWidth: 400,
      );
      final ZcrudTheme out = t.copyWith();
      expect(
        out.folderCardFooterPlacement,
        ZFolderCardFooterPlacement.adaptive,
      );
      expect(out.folderCardFooterBesideMinWidth, 400);
    });
  });

  group('🔴 CR-IFFD-68 — `lerp` null-PRÉSERVANT et DISCRET', () {
    test('`null` ↔ `null` reste `null` à t = 0.5', () {
      const ZcrudTheme a = ZcrudTheme();
      const ZcrudTheme b = ZcrudTheme();
      final ZcrudTheme mid = a.lerp(b, 0.5);
      expect(mid.folderCardFooterPlacement, isNull);
      expect(mid.folderCardFooterBesideMinWidth, isNull);
    });

    test('la DISPOSITION bascule, elle n\'interpole pas', () {
      const ZcrudTheme a = ZcrudTheme(
        folderCardFooterPlacement: ZFolderCardFooterPlacement.beside,
      );
      const ZcrudTheme b = ZcrudTheme(
        folderCardFooterPlacement: ZFolderCardFooterPlacement.below,
      );
      expect(
        a.lerp(b, 0.25).folderCardFooterPlacement,
        ZFolderCardFooterPlacement.beside,
      );
      expect(
        a.lerp(b, 0.75).folderCardFooterPlacement,
        ZFolderCardFooterPlacement.below,
      );
    });

    test('le POINT DE RUPTURE bascule aussi — il ne s\'interpole pas', () {
      const ZcrudTheme a = ZcrudTheme(folderCardFooterBesideMinWidth: 300);
      const ZcrudTheme b = ZcrudTheme(folderCardFooterBesideMinWidth: 900);
      expect(
        a.lerp(b, 0.25).folderCardFooterBesideMinWidth,
        300,
        reason:
            '🔴 un seuil intermédiaire ferait basculer la mise en page AU '
            'MILIEU d\'une transition de thème — un point de rupture que '
            'personne n\'a choisi.',
      );
      expect(a.lerp(b, 0.75).folderCardFooterBesideMinWidth, 900);
    });
  });
}
