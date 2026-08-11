/// Nature d'une annotation de document d'étude `ZDocumentAnnotationKind`.
///
/// - [highlight] : surlignage d'un passage de texte (une ou plusieurs
///   lignes), rendu avec une couleur ;
/// - [stickyNote] : note ancrée à un point de la page (marqueur tapable +
///   texte).
///
/// Sérialisation JSON stable (nom d'enum camelCase, invariant AD-3), repli
/// défensif sur [highlight] pour toute valeur inconnue / `null` /
/// non-`String` (robustesse à un document altéré, invariant AD-10).
///
/// **L'ordre de déclaration est normatif** : le générateur zcrud décode un
/// enum par nom et, pour un champ non-nullable sans valeur par défaut, son
/// repli défensif est la première constante déclarée. [highlight] est donc
/// le défaut d'une valeur absente / `null` / non-`String` / inconnue.
/// Réordonner cet enum changerait silencieusement le comportement défensif
/// de `ZDocumentAnnotation.kind`.
///
/// Pur Dart — aucune dépendance Flutter/Firebase/Hive.
library;

/// Nature d'une [ZDocumentAnnotation] : surlignage ou note ancrée.
enum ZDocumentAnnotationKind {
  /// Surlignage d'un passage de texte — valeur de repli défensive (première
  /// constante déclarée).
  highlight,

  /// Note ancrée à un point de la page (marqueur tapable + texte).
  stickyNote;
}
