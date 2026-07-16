import 'dart:math' as math;

/// Nombre de colonnes d'une grille d'items pour une [availableWidth] donnée,
/// borné à **au moins** [minColumns] (**≥ 1 garanti**) et **au plus**
/// [maxColumns] (illimité si `null`).
///
/// **Fonction PURE de domaine** (top-level, aucun `BuildContext`, aucun import
/// Flutter — au plus `dart:math`) : testable en `test/` **sans surface widget**
/// (NFR-U6), déterministe (AD-14).
///
/// **Formule (AC9)** : `n = ⌊(effectiveWidth + spacingEff) / (minItemWidth +
/// spacingEff)⌋`, borné par `clamp(lo, hi)` où `lo = max(1, minColumns)`,
/// `hi = maxColumns ?? +∞`, `effectiveWidth = availableWidth − horizontalPadding`
/// et `spacingEff` = [spacing] retenu s'il est fini et `> 0`, sinon `0`. Ainsi
/// chaque item fait **au moins** [minItemWidth] **une fois les `n − 1` gouttières
/// de largeur [spacing] et le [horizontalPadding] déduits** (fini la
/// surestimation qui écrasait les items sous [minItemWidth]).
///
/// **Rétro-compatibilité** : avec `spacing == 0` **et** `horizontalPadding == 0`
/// (valeurs par défaut), la formule se réduit **exactement** à
/// `(availableWidth / minItemWidth).floor()` — résultats **identiques** à
/// l'ancienne signature.
///
/// **Garantie `≥ 1` — corrige le bug iffd** (`min(3, Get.width ~/ itemMinWidth)`
/// **sans clamp bas** → `crossAxisCount == 0` possible sur écran étroit / panneau
/// réduit → division par zéro au calcul de la largeur d'item + `GridView` vide).
/// Ici le plancher `lo ≥ 1` est **toujours** appliqué : pour
/// `availableWidth < minItemWidth`, le résultat est `1` (jamais `0`).
///
/// **Défauts sûrs (AD-10 / NFR-U10) — jamais de `throw`, jamais de division par
/// zéro** :
/// * `minItemWidth <= 0` ou `NaN` → `lo` (aucune division n'est tentée) ;
/// * `availableWidth <= 0` ou `NaN` → `lo` ;
/// * `availableWidth` **infini** → `maxColumns` (remonté à `lo` si `< lo`) s'il
///   est fourni, sinon `lo` (jamais de grille non bornée) ;
/// * `spacing` négatif / `NaN` / infini → traité comme `0` ;
/// * `horizontalPadding` négatif / `NaN` / infini → traité comme `0` ;
/// * `effectiveWidth <= 0` ou `NaN` (padding ≥ largeur) → `lo` ;
/// * `minItemWidth + spacingEff <= 0` → `lo` ;
/// * `minColumns < 1` → plancher **remonté à 1** ;
/// * `maxColumns` fourni `< lo` → **remonté** à `lo` (le `clamp` reste toujours
///   valide, `lo <= hi` — jamais de `RangeError`/`ArgumentError`).
int computeCrossAxisCount({
  required double availableWidth,
  required double minItemWidth,
  int minColumns = 1,
  int? maxColumns,
  double spacing = 0,
  double horizontalPadding = 0,
}) {
  // Plancher garanti : jamais moins de 1 colonne (cœur de l'anti-bug iffd).
  final int lo = minColumns < 1 ? 1 : minColumns;

  // Plafond effectif : si fourni, jamais sous le plancher (clamp toujours valide).
  final int? hi = maxColumns == null ? null : math.max(lo, maxColumns);

  // Gouttière & padding assainis (AC9) : négatif / NaN / infini → 0.
  final double spacingEff =
      (spacing.isFinite && spacing > 0) ? spacing : 0;
  final double paddingEff =
      (horizontalPadding.isFinite && horizontalPadding > 0)
          ? horizontalPadding
          : 0;

  // Gardes numériques AVANT toute division : jamais x/0, jamais NaN propagé.
  if (minItemWidth.isNaN || minItemWidth <= 0) {
    return lo;
  }
  if (availableWidth.isNaN || availableWidth <= 0) {
    return lo;
  }
  if (availableWidth.isInfinite) {
    // Largeur non bornée : plafond si fourni, sinon plancher (jamais « infini »).
    return hi ?? lo;
  }

  // Largeur utile après retrait du padding horizontal (AC9).
  final double effectiveWidth = availableWidth - paddingEff;
  if (effectiveWidth.isNaN || effectiveWidth <= 0) {
    return lo;
  }

  // Dénominateur = largeur d'un item + sa gouttière. Garde AD-10.
  final double denominator = minItemWidth + spacingEff;
  if (denominator <= 0) {
    return lo;
  }

  // Cas nominal : floor de `(effectiveWidth + spacingEff) / denominator`,
  // borné par [lo, hi]. Se réduit à `floor(availableWidth / minItemWidth)`
  // quand spacing == 0 et horizontalPadding == 0 (rétro-compat).
  final int raw = ((effectiveWidth + spacingEff) / denominator).floor();
  if (raw < lo) {
    return lo;
  }
  if (hi != null && raw > hi) {
    return hi;
  }
  return raw;
}
