/// Nature d'une annotation de document d'étude `ZDocumentAnnotationKind`
/// (ES-2.5, FR-S8, AC9).
///
/// origine: lex_core (module « Étude ») —
/// `enums/education/document_annotation_kind.dart` (`DocumentAnnotationKind`) :
///
/// - [highlight] : surlignage d'un passage de texte (une ou plusieurs lignes),
///   rendu avec une couleur ;
/// - [stickyNote] : note ancrée à un point de la page (marqueur tapable + texte).
///
/// **Sérialisation JSON stable (nom d'enum camelCase — AD-3)**, repli
/// **défensif** sur [highlight] pour toute valeur inconnue / `null` /
/// non-`String` (robustesse pull cloud / doc altéré — AD-10).
///
/// 🔴 **L'ORDRE DE DÉCLARATION EST NORMATIF** (D5) : le générateur `zcrud`
/// décode un enum **par NOM** (`_$enumFromName`) et, pour un champ non-nullable
/// sans `defaultValue`, son repli défensif est **`T.values.first`**. **[highlight]
/// EST donc le défaut** d'une valeur absente / `null` / non-`String` / inconnue —
/// aligné sur le repli documenté par lex (`DocumentAnnotationKind.fromJson`).
/// Réordonner cet enum changerait **silencieusement** le comportement défensif de
/// `ZDocumentAnnotation.kind`.
///
/// Pur Dart — aucune dépendance Flutter/Firebase/Hive (NFR-S3/SM-S5).
library;

/// Nature d'une [ZDocumentAnnotation] : surlignage ou note ancrée.
enum ZDocumentAnnotationKind {
  /// Surlignage d'un passage de texte (**défaut défensif** — 1ʳᵉ constante, D5).
  highlight,

  /// Note ancrée à un point de la page (marqueur tapable + texte).
  stickyNote;
}
