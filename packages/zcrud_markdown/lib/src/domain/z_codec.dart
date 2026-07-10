/// `ZCodec` — abstraction **pluggable** de (dé)sérialisation du format PERSISTÉ
/// du contenu rich-text, choisie par l'app (AD-7).
///
/// L'éditeur ([ZMarkdownField], E6-1) travaille TOUJOURS en **Delta interne** et
/// porte sur sa tranche `ZFormController` une **valeur neutre** (Delta JSON =
/// `List<Map<String, dynamic>>`). Le `ZCodec` transforme cette valeur neutre
/// **à la couture de PERSISTANCE** (modèle `toMap`/`fromMap`) vers/depuis un
/// **format persisté** choisi par l'app (Delta JSON, Markdown, HTML…) — **hors**
/// de la tranche et **hors** du chemin chaud de frappe (AD-2 / SM-1 préservés).
library;

/// Codec pluggable Delta ↔ format persisté (AD-7).
///
/// SIGNATURE 100% NEUTRE (AD-1/AD-8) : ni `Document`, ni `Delta`, ni type d'une
/// lib de conversion (`markdown`/`html`) n'apparaît — uniquement `Object?`,
/// `String`, `List<Map<String, dynamic>>`, `Map<String, dynamic>`.
///
/// - [encode] : ops Delta neutres → représentation persistée (`Object?`,
///   typiquement une `String` Markdown/HTML, ou une `String`/`List` Delta JSON).
/// - [decode] : représentation persistée → ops Delta neutres. **DÉFENSIF**
///   (AD-10) : `null`/vide/corrompu/legacy → `[]`, **jamais** de throw.
///
/// ## Fidélité & pertes
/// - `ZDeltaCodec` : round-trip **IDENTITÉ** (Delta JSON, sans perte).
/// - `ZMarkdownCodec` : round-trip **borné** au sous-ensemble Markdown ; les
///   attributs non exprimables en Markdown (couleur, police, alignement, embeds
///   LaTeX/tableau) sont **perdus** — perte DOCUMENTÉE (table des pertes) et
///   assertée par test, jamais un throw.
abstract interface class ZCodec {
  /// Sérialise des **ops Delta neutres** vers le format persisté.
  ///
  /// Ne throw pas sur une entrée vide : `encode(const [])` → persisté vide
  /// (`''` pour Markdown/HTML, `'[]'` pour Delta JSON) (AD-10).
  Object? encode(List<Map<String, dynamic>> deltaOps);

  /// Désérialise une valeur persistée vers des **ops Delta neutres**.
  ///
  /// DÉFENSIF (AD-10) : `null`/vide/corrompu/legacy → `[]`, **jamais** de throw.
  List<Map<String, dynamic>> decode(Object? persisted);
}
