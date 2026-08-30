/// Composition des jetons de géométrie de dégradé.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

// Porteur des défauts du constructeur `LinearGradient` : ils sont LUS sur le
// constructeur au lieu d'être recopiés en toutes lettres, parce que ce sont des
// alignements non directionnels, que la garde de source du paquet interdit
// d'écrire (AD-13) — et parce qu'un défaut recopié dériverait le jour où
// Flutter changerait le sien.
const LinearGradient _defautsLineaires = LinearGradient(colors: <Color>[]);

/// Complète la géométrie d'un dégradé avec les jetons `ZcrudTheme.gradientBegin`
/// / `ZcrudTheme.gradientEnd`, et rend le dégradé **inchangé** partout ailleurs.
///
/// Un `LinearGradient` porte toujours un `begin` et un `end` : construit sans
/// eux, il vaut `Alignment.centerLeft` / `Alignment.centerRight`, qui sont
/// **non directionnels** — le dégradé ne se miroite pas en RTL. Cette fonction
/// traite cette paire de défauts comme « géométrie non déclarée » et y
/// substitue les jetons, qui peuvent être directionnels.
///
/// Précédence, du plus fort au plus faible :
/// 1. la géométrie **explicite** du dégradé (tout `begin`/`end` autre que la
///    paire de défauts Flutter) — jamais écrasée ;
/// 2. les jetons de thème, appliqués seulement à la place des défauts ;
/// 3. les défauts Flutter, conservés quand aucun jeton n'est posé.
///
/// Conséquence pour l'appelant qui veut réellement un dégradé figé de gauche à
/// droite dans les deux sens de lecture : le déclarer en toutes lettres
/// (`begin: Alignment.centerLeft, end: Alignment.centerRight` est indistinguable
/// de « non déclaré », il faut donc passer par une autre géométrie explicite,
/// ou ne pas poser les jetons).
///
/// Les dégradés non linéaires (`RadialGradient`, `SweepGradient`) sont rendus
/// tels quels : leur géométrie est un centre et un rayon, que ces deux jetons
/// ne décrivent pas.
Gradient zApplyGradientGeometry(
  Gradient gradient, {
  required AlignmentGeometry? begin,
  required AlignmentGeometry? end,
}) {
  if (begin == null && end == null) return gradient;
  if (gradient is! LinearGradient) return gradient;
  // `ZGradientSpec` ne porte PAS de `begin`/`end` propres : la seule
  // information disponible est celle du `Gradient` lui-même. « Non déclaré »
  // n'est donc distinguable de « déclaré » que par comparaison aux défauts du
  // constructeur Flutter — borne assumée, documentée ci-dessus.
  final bool geometrieExplicite =
      gradient.begin != _defautsLineaires.begin ||
      gradient.end != _defautsLineaires.end;
  if (geometrieExplicite) return gradient;

  return LinearGradient(
    colors: gradient.colors,
    stops: gradient.stops,
    begin: begin ?? gradient.begin,
    end: end ?? gradient.end,
    tileMode: gradient.tileMode,
    transform: gradient.transform,
  );
}

/// `true` quand le thème pose les **deux** jetons de géométrie.
///
/// Une paire incomplète n'est pas une géométrie : les surfaces qui n'existent
/// qu'en présence d'une configuration complète s'en servent pour rester
/// absentes de l'arbre plutôt que de rendre à moitié.
bool zHasGradientGeometryTokens(ZcrudTheme theme) =>
    theme.gradientBegin != null && theme.gradientEnd != null;

/// Variante lisant les jetons dans le [ZcrudTheme] déjà résolu du contexte.
Gradient zApplyThemedGradientGeometry(Gradient gradient, ZcrudTheme theme) =>
    zApplyGradientGeometry(
      gradient,
      begin: theme.gradientBegin,
      end: theme.gradientEnd,
    );
