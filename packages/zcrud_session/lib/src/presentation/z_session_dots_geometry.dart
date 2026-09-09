/// `ZSessionDotsGeometry` — géométrie des points de progression.
///
/// Value-object immuable décrivant **comment** le style « points » de
/// `ZSessionProgressIndicator` occupe l'espace : taille d'un point non
/// courant, élongation du point courant, écart entre deux points, alignement
/// de la file et comportement de débordement.
///
/// Chaque champ est **nullable**, et `null` signifie partout la même chose :
/// « je ne pose rien, garde le rendu par défaut ». Un indicateur construit
/// sans géométrie et un indicateur portant `const ZSessionDotsGeometry()`
/// rendent donc exactement le même arbre — la géométrie n'est jamais une
/// opinion imposée, seulement une opinion **disponible**.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;

/// Géométrie du style « points » de la progression de session.
///
/// ## Ce que chaque champ décrit
///
/// | Champ | Ce qu'il règle | Sans lui |
/// |---|---|---|
/// | [inactiveSize] | largeur × hauteur d'un point non courant | carré de `ZcrudTheme.gapM` |
/// | [activeScale] | rapport largeur/hauteur du point **courant** | [defaultActiveScale] |
/// | [gap] | écart entre deux points voisins | `ZcrudTheme.gapS` |
/// | [alignment] | placement de la file dans la largeur offerte | [defaultAlignment] |
/// | [scrollable] | débordement : défiler, ou passer à la ligne | [defaultScrollable] |
///
/// ## Pourquoi une échelle, et pas une seconde `Size`
///
/// [activeScale] multiplie la **hauteur** du point inactif, jamais sa largeur.
/// C'est ce qui rend la valeur lisible telle quelle : « 2,4 » se lit « le
/// point courant est 2,4 fois plus long que haut », quelle que soit la largeur
/// des autres points. Multiplier la largeur donnerait au même nombre deux
/// significations opposées selon que les points inactifs sont des cercles ou
/// des pilules — et un rendu qui change de forme quand on change seulement
/// [inactiveSize].
///
/// La **hauteur** du point courant n'est jamais modifiée : une file de points
/// reste alignée sur une seule ligne de base.
///
/// ## Bornes (invariant AD-10)
///
/// Aucune valeur reçue ne peut faire lever ni produire un rendu invisible :
/// une dimension non finie, nulle ou négative est **ignorée** au profit du
/// défaut. Un `gap` de `0` est en revanche parfaitement valide — des points
/// jointifs sont un choix de design, pas une donnée corrompue.
@immutable
class ZSessionDotsGeometry {
  /// Construit une géométrie. Tout champ omis garde le rendu par défaut.
  const ZSessionDotsGeometry({
    this.inactiveSize,
    this.activeScale,
    this.gap,
    this.alignment,
    this.scrollable,
  });

  /// Taille d'un point **non courant**. `null` ⇒ carré de `ZcrudTheme.gapM`.
  ///
  /// Une largeur supérieure à la hauteur donne une pilule ; une largeur égale
  /// à la hauteur, un cercle (le rayon des coins suit la hauteur, la forme est
  /// donc toujours pleinement arrondie).
  final Size? inactiveSize;

  /// Rapport largeur/hauteur du point **courant**. `null` ⇒
  /// [defaultActiveScale].
  ///
  /// La largeur peinte vaut `inactiveSize.height * activeScale` ; la hauteur
  /// ne change pas.
  final double? activeScale;

  /// Écart entre deux points voisins. `null` ⇒ `ZcrudTheme.gapS`.
  final double? gap;

  /// Placement de la file dans la largeur offerte. `null` ⇒
  /// [defaultAlignment].
  ///
  /// L'alignement est **directionnel** : `WrapAlignment.start` désigne la
  /// gauche en LTR et la droite en RTL (invariant AD-13).
  final WrapAlignment? alignment;

  /// Comportement quand la file dépasse la largeur offerte. `null` ⇒
  /// [defaultScrollable].
  ///
  /// - `false` : les points **passent à la ligne**, toute la file reste
  ///   visible et l'indicateur grandit en hauteur ;
  /// - `true` : les points restent sur **une seule ligne** et la file
  ///   **défile** horizontalement, l'indicateur garde une hauteur constante.
  ///
  /// Le choix n'est pas cosmétique : sur une file longue, la mise en page
  /// « retour à la ligne » peut occuper plusieurs rangées et repousser le
  /// contenu, là où le défilement garde une hauteur stable au prix d'une
  /// partie de la file hors champ.
  final bool? scrollable;

  /// Rapport largeur/hauteur du point courant quand [activeScale] n'est pas
  /// posé.
  static const double defaultActiveScale = 1.5;

  /// Alignement de la file quand [alignment] n'est pas posé.
  static const WrapAlignment defaultAlignment = WrapAlignment.start;

  /// Comportement de débordement quand [scrollable] n'est pas posé.
  static const bool defaultScrollable = false;

  /// `true` si la dimension est utilisable (finie et strictement positive).
  static bool _isPositive(double value) => value.isFinite && value > 0;

  /// Taille résolue d'un point non courant.
  ///
  /// Défensif (invariant AD-10) : une taille dont la largeur **ou** la hauteur
  /// n'est pas utilisable est ignorée en entier — mélanger une moitié reçue et
  /// une moitié dérivée produirait une forme que personne n'a demandée.
  Size resolvedInactiveSize(ZcrudTheme theme) {
    final size = inactiveSize;
    if (size == null || !_isPositive(size.width) || !_isPositive(size.height)) {
      return Size.square(theme.gapM);
    }
    return size;
  }

  /// Rapport largeur/hauteur résolu du point courant.
  ///
  /// Une valeur non finie ou `<= 0` est ignorée (invariant AD-10) : elle ferait
  /// disparaître le point courant, c'est-à-dire la seule information que ce
  /// style porte.
  double get resolvedActiveScale {
    final scale = activeScale;
    if (scale == null || !_isPositive(scale)) return defaultActiveScale;
    return scale;
  }

  /// Largeur peinte du point courant.
  double resolvedActiveWidth(ZcrudTheme theme) =>
      resolvedInactiveSize(theme).height * resolvedActiveScale;

  /// Écart résolu entre deux points voisins.
  ///
  /// `0` est accepté (points jointifs) ; une valeur négative ou non finie est
  /// ignorée (invariant AD-10).
  double resolvedGap(ZcrudTheme theme) {
    final value = gap;
    if (value == null || !value.isFinite || value < 0) return theme.gapS;
    return value;
  }

  /// Alignement résolu de la file.
  WrapAlignment get resolvedAlignment => alignment ?? defaultAlignment;

  /// Comportement de débordement résolu.
  bool get resolvedScrollable => scrollable ?? defaultScrollable;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZSessionDotsGeometry &&
          other.inactiveSize == inactiveSize &&
          other.activeScale == activeScale &&
          other.gap == gap &&
          other.alignment == alignment &&
          other.scrollable == scrollable;

  @override
  int get hashCode =>
      Object.hash(inactiveSize, activeScale, gap, alignment, scrollable);

  @override
  String toString() =>
      'ZSessionDotsGeometry(inactiveSize: $inactiveSize, '
      'activeScale: $activeScale, gap: $gap, alignment: $alignment, '
      'scrollable: $scrollable)';
}
