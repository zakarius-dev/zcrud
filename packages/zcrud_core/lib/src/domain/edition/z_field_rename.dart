/// Stratégie de renommage de la clé persistée d'un champ (authoring →
/// persistance), portée par `@ZcrudModel.fieldRename` et appliquée par le
/// générateur E2-5.
///
/// origine: aligne AD-3 (« `fieldRename: snake` en persistance ») et le
/// `FieldRename` de `json_annotation` — mais type-valeur **propre** au domaine
/// `zcrud` (pur-Dart, aucune dépendance codegen tirée dans le cœur).
library;

/// Renommage de la clé persistée dérivé du nom Dart du champ.
///
/// Défaut `zcrud` : [snake] (AD-3, persistance snake_case ; les valeurs d'enum
/// restent en camelCase — canonique §5). Un `@ZcrudField.name` explicite
/// **prime** sur cette dérivation.
enum ZFieldRename {
  /// Aucune transformation : la clé persistée = le nom Dart tel quel.
  none,

  /// `maClé` → `ma_clé` (défaut AD-3).
  snake,

  /// `maClé` → `ma-clé`.
  kebab,

  /// `maClé` → `MaClé`.
  pascal,
}
