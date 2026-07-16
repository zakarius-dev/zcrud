/// Valeur générique **dépendante du breakpoint fin** (EX-UI.1, D2) — primitive de
/// mesure PURE, bâtie **sur** l'échelle `ZBreakpoint` de `zcrud_core`.
///
/// [ZBreakpointValue] est la **généralisation générique `T`** du `ZResponsiveSpan`
/// de `zcrud_core` (lui-même un `ZBreakpointValue<int>` spécialisé et borné
/// `[1,12]`) : mêmes **5 paliers Bootstrap** (`ZBreakpoint` — RÉUTILISÉ, jamais
/// redéclaré), même **cascade mobile-first** (repli vers le palier renseigné le
/// plus proche en dessous), **sans** le bornage `int`. Sert à porter une valeur
/// d'authoring par palier (span, padding, nombre de colonnes, gouttière…).
///
/// **Réutilisation du cœur (Amendement E3-4, Option A)** : l'axe de paliers est
/// l'enum `ZBreakpoint` **défini dans `zcrud_core`** et la résolution largeur
/// délègue à `ZResponsiveBreakpoints.of` — **aucun seuil n'est recopié** ici, et
/// ni `ZBreakpoint`, ni `ZResponsiveBreakpoints`, ni `ZResponsiveSpan` ne sont
/// redéclarés.
///
/// **Découplage 5 ↔ 3 paliers (D2)** : cette échelle **fine à 5 paliers** est
/// **délibérément découplée** de `ZWindowSizeClass` (**3 paliers M3**, 600/840).
/// Deux notions orthogonales : l'une porte une *valeur par palier fin* (Bootstrap,
/// réutilisée du cœur), l'autre *classe la fenêtre* pour un choix de présentation
/// (M3). Les fusionner forcerait soit une perte de granularité, soit une politique
/// à 5 branches — elles coexistent.
library;

import 'package:flutter/foundation.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Valeur de type [T] déclinée **par breakpoint** avec cascade mobile-first.
///
/// Palier de base [xs] **requis** ; `sm`/`md`/`lg`/`xl` **optionnels** — un palier
/// non fourni **hérite** du palier renseigné le plus proche en dessous (cascade
/// `xl→lg→md→sm→xs`). `@immutable`, `==`/`hashCode` **par valeur** (patron
/// `ZResponsiveSpan` du cœur, sans le clamp `[1,12]`).
@immutable
class ZBreakpointValue<T> {
  /// Construit une valeur par breakpoint. [xs] (base) est **requis** ; chaque cran
  /// supérieur non fourni hérite du cran inférieur (cascade mobile-first — voir
  /// [valueAt]).
  const ZBreakpointValue({
    required this.xs,
    this.sm,
    this.md,
    this.lg,
    this.xl,
  });

  /// Raccourci : une valeur **uniforme** [value] sur tous les breakpoints.
  const ZBreakpointValue.all(T value)
      : xs = value,
        sm = value,
        md = value,
        lg = value,
        xl = value;

  /// Valeur au breakpoint `xs` (base — toujours définie).
  final T xs;

  /// Valeur au breakpoint `sm` (`null` ⇒ hérite de [xs]).
  final T? sm;

  /// Valeur au breakpoint `md` (`null` ⇒ hérite du cran inférieur).
  final T? md;

  /// Valeur au breakpoint `lg` (`null` ⇒ hérite du cran inférieur).
  final T? lg;

  /// Valeur au breakpoint `xl` (`null` ⇒ hérite du cran inférieur).
  final T? xl;

  /// Valeur effective au breakpoint [bp], avec **cascade mobile-first** (repli
  /// vers le palier renseigné le plus proche en dessous). Pure, déterministe,
  /// **ne lève jamais**. L'enum [ZBreakpoint] **provient de `zcrud_core`**
  /// (non redéclaré).
  T valueAt(ZBreakpoint bp) {
    switch (bp) {
      case ZBreakpoint.xs:
        return xs;
      case ZBreakpoint.sm:
        return sm ?? xs;
      case ZBreakpoint.md:
        return md ?? sm ?? xs;
      case ZBreakpoint.lg:
        return lg ?? md ?? sm ?? xs;
      case ZBreakpoint.xl:
        return xl ?? lg ?? md ?? sm ?? xs;
    }
  }

  /// Valeur effective pour une largeur [width] (dp) : délègue à
  /// **`ZResponsiveBreakpoints.of(width)`** (de `zcrud_core`) puis [valueAt] —
  /// **réutilise** la table de seuils Bootstrap du cœur (576/768/992/1200),
  /// **jamais** de seuils recopiés. Pure, **ne lève jamais** : `NaN`/négatif
  /// retombent sur `xs` via le cœur (défaut sûr — AD-10/D4).
  T resolve(double width) => valueAt(ZResponsiveBreakpoints.of(width));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZBreakpointValue<T> &&
          runtimeType == other.runtimeType &&
          xs == other.xs &&
          sm == other.sm &&
          md == other.md &&
          lg == other.lg &&
          xl == other.xl;

  @override
  int get hashCode => Object.hash(runtimeType, xs, sm, md, lg, xl);
}
