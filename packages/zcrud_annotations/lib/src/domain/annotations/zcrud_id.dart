/// Annotation **marqueur** désignant le champ identifiant (`id`) d'un modèle
/// `@ZcrudModel`.
///
/// Consommée par le générateur E2-5 pour repérer la clé d'identité (`String`
/// opaque, nullable pour l'éphémère — canonique §5). Sans paramètre.
///
/// Classe `const` pur-données (AC1).
///
/// ```dart
/// @ZcrudModel()
/// class Article {
///   @ZcrudId()
///   final String? id;
/// }
/// ```
class ZcrudId {
  /// Construit le marqueur `const`.
  const ZcrudId();
}
