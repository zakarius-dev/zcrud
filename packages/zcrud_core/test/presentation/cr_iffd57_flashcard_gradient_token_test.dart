/// **CR-IFFD-57** — jeton `ZcrudTheme.flashcardTypeGradients` : transport
/// (`copyWith`) et interpolation (`lerp`) null-préservante.
///
/// L'invariant critique est celui de `studyCardBadgeRadius` (leçon mesurée,
/// CR-IFFD-56) : `null` des DEUX côtés doit RESTER `null` — matérialiser une
/// valeur au `lerp` GÈLERAIT le défaut-référence du consommateur à la première
/// transition de thème, et le rendu par défaut cesserait ensuite de suivre.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const ZGradientSpec _spec = ZGradientSpec(
  gradient: LinearGradient(
    colors: <Color>[Color(0xFF112233), Color(0xFF445566)],
  ),
  onGradient: Color(0xFFFFFFFF),
);

const Map<String, ZGradientSpec> _map = <String, ZGradientSpec>{
  'openQuestion': _spec,
};

void main() {
  group('CR-IFFD-57 — jeton flashcardTypeGradients', () {
    test('défaut : nul (le consommateur applique la RÉFÉRENCE)', () {
      expect(const ZcrudTheme().flashcardTypeGradients, isNull);
    });

    test('constructeur : transporté tel quel', () {
      const ZcrudTheme theme = ZcrudTheme(flashcardTypeGradients: _map);
      expect(theme.flashcardTypeGradients, same(_map));
    });

    test('copyWith transporte le jeton — et n\'efface rien sans demande', () {
      final ZcrudTheme copied =
          const ZcrudTheme().copyWith(flashcardTypeGradients: _map);
      expect(copied.flashcardTypeGradients?['openQuestion'], _spec);
      // Sans argument : la valeur EXISTANTE reste.
      const ZcrudTheme filled = ZcrudTheme(flashcardTypeGradients: _map);
      expect(filled.copyWith().flashcardTypeGradients, same(_map));
      // …et les autres jetons ne sont pas effacés au passage.
      final ZcrudTheme other = const ZcrudTheme(studyCardIconTileSize: 56)
          .copyWith(flashcardTypeGradients: _map);
      expect(other.studyCardIconTileSize, 56);
    });

    test('🔴 lerp null-null RESTE null (jamais matérialisé)', () {
      final ZcrudTheme mid =
          const ZcrudTheme().lerp(const ZcrudTheme(), 0.5);
      expect(mid.flashcardTypeGradients, isNull,
          reason: 'matérialiser une map au lerp gèlerait le défaut-référence '
              'du consommateur à la première transition de thème');
    });

    test('lerp discret : bascule à t=0.5, valeurs jamais fabriquées', () {
      const ZcrudTheme a = ZcrudTheme(flashcardTypeGradients: _map);
      const ZcrudTheme b = ZcrudTheme();
      expect(a.lerp(b, 0.25).flashcardTypeGradients, same(_map));
      expect(a.lerp(b, 0.75).flashcardTypeGradients, isNull);
      expect(b.lerp(a, 0.75).flashcardTypeGradients, same(_map));
    });
  });
}
