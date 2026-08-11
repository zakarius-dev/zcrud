/// Contrat d'entité canonique du domaine `zcrud_core`.
library;

/// Contrat abstrait d'une entité canonique persistable.
///
/// L'identité est un `String` **opaque** : aucune sémantique de position, de
/// tri ni de structure n'y est attachée (invariant AD-14). Elle est
/// **nullable** pour représenter une entité **éphémère** — créée en mémoire
/// mais pas encore matérialisée (aucun `id` attribué). L'invariant de
/// matérialisation (attribution d'un `id` avant écriture) est porté par le
/// **repository**, jamais par l'entité elle-même.
///
/// `ZEntity` est un **contrat pur** : aucune (dé)sérialisation n'est déclarée
/// sur cette base (invariant AD-4 — base abstraite fine sans sérialisation ;
/// l'héritage de classes sérialisées est rejeté au profit de la
/// composition).
abstract class ZEntity {
  /// Constructeur `const` pour permettre des sous-classes immuables.
  const ZEntity();

  /// Identité opaque de l'entité, ou `null` si l'entité est éphémère
  /// (non encore matérialisée par le repository).
  String? get id;

  /// `true` tant que l'entité n'a pas reçu d'identité (éphémère).
  bool get isEphemeral => id == null;
}
