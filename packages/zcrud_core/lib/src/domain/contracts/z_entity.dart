/// Contrat d'entité canonique du domaine `zcrud_core`.
///
/// origine: lex_core (module « Étude ») `.../flashcard.dart` — `Flashcard.isEphemeral`
/// (identité `String?` opaque, matérialisation par le repository). Canonique §2.1.
library;

/// Contrat abstrait d'une entité canonique persistable.
///
/// L'identité est un `String` **opaque** : aucune sémantique de position, de
/// tri ni de structure n'y est attachée (AD-14). Elle est **nullable** pour
/// représenter une entité **éphémère** — créée en mémoire mais pas encore
/// matérialisée (aucun `id` attribué). L'invariant de matérialisation
/// (attribution d'un `id` avant écriture) est porté par le **repository**
/// (E2-2/E5), jamais par l'entité elle-même.
///
/// `ZEntity` est un **contrat pur** : aucune (dé)sérialisation n'est déclarée
/// sur cette base (AD-4 — base abstraite fine sans sérialisation ; l'héritage de
/// classes sérialisées est rejeté au profit de la composition).
abstract class ZEntity {
  /// Constructeur `const` pour permettre des sous-classes immuables.
  const ZEntity();

  /// Identité opaque de l'entité, ou `null` si l'entité est éphémère
  /// (non encore matérialisée par le repository).
  String? get id;

  /// `true` tant que l'entité n'a pas reçu d'identité (éphémère).
  ///
  /// Dérivé de [id] : porté de `Flashcard.isEphemeral` (canonique §2.1).
  bool get isEphemeral => id == null;
}
