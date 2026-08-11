/// Mode de **présentation d'édition** — enum PUR de domaine.
///
/// [ZEditionPresentation] modélise **comment** un formulaire d'édition est
/// présenté à l'écran, en **trois** modes exclusifs (`page` / `sheet` /
/// `dialog`, valeurs **camelCase**). C'est un **enum** — l'UNIQUE type de mode
/// exposé : il **remplace** les booléens multi-états d'une intégration ad hoc
/// (`fullscreenDialog`, `dialog`, `isWebOrDesktop`) par un domaine borné.
///
/// **Domaine pur (invariants AD-5/AD-14)** : aucun `import 'package:flutter/...'`,
/// aucun `BuildContext`. Le *choix* du mode est calculé par
/// [ZPresentationPolicy] à partir d'un `ZWindowSizeClass` ; l'*exécution* du
/// mode (`Navigator.push` / `showModalBottomSheet` / `showDialog`) relève du
/// présentateur `ZFormPresenter` / `ZAdaptivePresenter`.
///
/// **Non sérialisé** : c'est un choix runtime d'UI ⇒ **aucun** `@JsonKey`.
/// Si l'enum devenait un jour persisté (p. ex. une préférence utilisateur), il
/// devrait alors porter `@JsonKey(unknownEnumValue:)` pour la désérialisation
/// défensive (invariant AD-10) — hors périmètre.
library;

/// Mode de présentation d'un formulaire d'édition (valeurs **camelCase**).
enum ZEditionPresentation {
  /// **Page pleine** (typiquement `fullscreenDialog: true` / route poussée) —
  /// pour un formulaire lourd sur grand écran (voir [ZFormWeight.heavy]).
  page,

  /// **Bottom-sheet** modale — ergonomie tactile des petits écrans
  /// (`compact`).
  sheet,

  /// **Dialog** modale centrée — écrans moyens (`medium`) et grands écrans pour
  /// un formulaire léger (voir [ZFormWeight.light]).
  dialog,
}
