/// Annotation **marqueur** désignant le champ identifiant (`id`) d'un modèle
/// `@ZcrudModel`.
///
/// Consommée par `zcrud_generator` pour repérer la clé d'identité (`String`
/// opaque, nullable pour l'éphémère). Sans paramètre.
///
/// Classe `const` pur-données.
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
