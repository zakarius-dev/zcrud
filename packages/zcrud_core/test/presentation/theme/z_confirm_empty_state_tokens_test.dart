// GARDE de TRANSPORT des jetons `confirmDialog*` / `emptyState*`.
//
// Ce que la garde ferme, et que la garde STRUCTURELLE des 4 sites
// (`z_theme_four_sites_guard_test.dart`) ne peut pas voir : celle-ci lit la
// SOURCE et vérifie que le nom du jeton apparaît aux quatre endroits. Un jeton
// câblé au mauvais champ (`emptyStateIconSize: other.emptyStateSpacing`), ou
// interpolé par un helper qui MATÉRIALISE une valeur là où les deux thèmes
// délèguent (`Color.lerp(null, c, t)` rend une teinte transparente au lieu de
// `null`), passe la garde textuelle sans broncher. Il faut donc mesurer le
// COMPORTEMENT, jeton par jeton.
//
// Trois propriétés, dans cet ordre :
//   1. INERTIE — un thème qui ne pose aucun de ces jetons les laisse `null`,
//      y compris à travers `fallback`, `copyWith` et `lerp`. C'est ce qui rend
//      le lot sans effet pour un hôte passif.
//   2. TRANSPORT — `copyWith` rend exactement la valeur passée, sur le bon
//      champ (chaque jeton reçoit une valeur DISCRIMINANTE : deux jetons
//      croisés seraient détectés).
//   3. EXTRÊMES — `lerp` rend exactement `this` à t=0 et exactement `other` à
//      t=1 quand les deux côtés portent une valeur.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Thème de base sans aucun des dix jetons du lot.
ZcrudTheme _vide() => ZcrudTheme.fallback(ThemeData.light());

/// Thème « A » : dix valeurs toutes distinctes les unes des autres, pour qu'un
/// croisement de champs (jeton X câblé sur le champ Y) soit détectable.
ZcrudTheme _pleinA() => _vide().copyWith(
  confirmDialogShape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(4)),
  ),
  confirmDialogTitleStyle: const TextStyle(fontSize: 11),
  confirmDialogContentStyle: const TextStyle(fontSize: 12),
  confirmDialogActionsPadding: const EdgeInsetsDirectional.all(13),
  confirmDialogDestructiveColor: const Color(0xFF102030),
  emptyStateIconSize: 14,
  emptyStateIconColor: const Color(0xFF405060),
  emptyStateTitleStyle: const TextStyle(fontSize: 15),
  emptyStateMessageStyle: const TextStyle(fontSize: 16),
  emptyStateSpacing: 17,
);

/// Thème « B » : mêmes jetons, valeurs toutes différentes de celles de A.
ZcrudTheme _pleinB() => _vide().copyWith(
  confirmDialogShape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(24)),
  ),
  confirmDialogTitleStyle: const TextStyle(fontSize: 31),
  confirmDialogContentStyle: const TextStyle(fontSize: 32),
  confirmDialogActionsPadding: const EdgeInsetsDirectional.all(33),
  confirmDialogDestructiveColor: const Color(0xFF708090),
  emptyStateIconSize: 34,
  emptyStateIconColor: const Color(0xFFA0B0C0),
  emptyStateTitleStyle: const TextStyle(fontSize: 35),
  emptyStateMessageStyle: const TextStyle(fontSize: 36),
  emptyStateSpacing: 37,
);

/// Les dix jetons du lot, lus sur [t], sous forme de couples nom → valeur.
/// Une seule liste, consommée par les trois propriétés : un jeton oublié ici
/// serait oublié partout, d'où le compteur assertif dans chaque test.
Map<String, Object?> _jetons(ZcrudTheme t) => <String, Object?>{
  'confirmDialogShape': t.confirmDialogShape,
  'confirmDialogTitleStyle': t.confirmDialogTitleStyle,
  'confirmDialogContentStyle': t.confirmDialogContentStyle,
  'confirmDialogActionsPadding': t.confirmDialogActionsPadding,
  'confirmDialogDestructiveColor': t.confirmDialogDestructiveColor,
  'emptyStateIconSize': t.emptyStateIconSize,
  'emptyStateIconColor': t.emptyStateIconColor,
  'emptyStateTitleStyle': t.emptyStateTitleStyle,
  'emptyStateMessageStyle': t.emptyStateMessageStyle,
  'emptyStateSpacing': t.emptyStateSpacing,
};

void main() {
  test('INERTIE : un thème qui ne pose rien laisse les dix jetons `null`', () {
    final Map<String, Object?> vide = _jetons(_vide());
    expect(vide.length, 10, reason: 'la liste de jetons a dérivé');
    expect(
      vide,
      _jetons(_vide()).map((String k, Object? v) => MapEntry<String, Object?>(k, null)),
      reason:
          '🔴 un jeton du lot est MATÉRIALISÉ par `fallback` : un hôte passif '
          'verrait son style changer sans avoir rien demandé.',
    );

    // …et l'inertie survit aux deux transformations du thème.
    final ZcrudTheme copie = _vide().copyWith();
    final ZcrudTheme interpole = _vide().lerp(_vide(), 0.5);
    for (final MapEntry<String, Object?> e in _jetons(copie).entries) {
      expect(e.value, isNull, reason: '${e.key} matérialisé par `copyWith()`');
    }
    for (final MapEntry<String, Object?> e in _jetons(interpole).entries) {
      expect(e.value, isNull, reason: '${e.key} matérialisé par `lerp` — le '
          'jeton apparaîtrait à la PREMIÈRE transition de thème');
    }
  });

  test('TRANSPORT : `copyWith` rend exactement la valeur posée, champ par champ',
      () {
    final Map<String, Object?> attendu = _jetons(_pleinA());
    expect(attendu.length, 10);
    expect(attendu.values.where((Object? v) => v == null), isEmpty,
        reason: 'le thème « plein » doit poser les dix jetons');
    // Discrimination : les dix valeurs sont deux à deux distinctes, donc un
    // croisement de champs produirait une inégalité.
    expect(attendu.values.toSet().length, 10,
        reason: 'valeurs non discriminantes — un croisement passerait');

    // Le thème A est construit PAR `copyWith` : ses valeurs sont donc bien
    // celles que `copyWith` a transportées, sur les champs nommés.
    expect(attendu['confirmDialogShape'],
        const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4))));
    expect(attendu['confirmDialogTitleStyle'], const TextStyle(fontSize: 11));
    expect(attendu['confirmDialogContentStyle'], const TextStyle(fontSize: 12));
    expect(attendu['confirmDialogActionsPadding'],
        const EdgeInsetsDirectional.all(13));
    expect(attendu['confirmDialogDestructiveColor'], const Color(0xFF102030));
    expect(attendu['emptyStateIconSize'], 14.0);
    expect(attendu['emptyStateIconColor'], const Color(0xFF405060));
    expect(attendu['emptyStateTitleStyle'], const TextStyle(fontSize: 15));
    expect(attendu['emptyStateMessageStyle'], const TextStyle(fontSize: 16));
    expect(attendu['emptyStateSpacing'], 17.0);

    // …et un `copyWith()` sans argument CONSERVE les dix (perte silencieuse :
    // le défaut exact que la garde des 4 sites vise sur le corps de copyWith).
    expect(_jetons(_pleinA().copyWith()), attendu);
  });

  test('EXTRÊMES : `lerp` rend exactement A à t=0 et exactement B à t=1', () {
    final ZcrudTheme a = _pleinA();
    final ZcrudTheme b = _pleinB();
    expect(_jetons(a).values.toList(), isNot(_jetons(b).values.toList()),
        reason: 'A et B doivent différer sur les dix jetons');

    expect(_jetons(a.lerp(b, 0)), _jetons(a),
        reason: '🔴 t=0 ne rend pas exactement le thème de départ');
    expect(_jetons(a.lerp(b, 1)), _jetons(b),
        reason: '🔴 t=1 ne rend pas exactement le thème d\'arrivée');
  });

  test('`lerp` avec un autre non-`ZcrudTheme` rend l\'instance elle-même', () {
    final ZcrudTheme a = _pleinA();
    expect(identical(a.lerp(null, 0.5), a), isTrue);
  });
}
