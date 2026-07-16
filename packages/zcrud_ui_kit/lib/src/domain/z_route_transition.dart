/// Type de transition de route en **enum** (AD-32 / NFR-U7).
///
/// Remplace un `bool isSlide`/`bool fade` (ou deux fonctions libres implicites)
/// par un **enum** exhaustif et extensible à froid : un nouveau palier casserait
/// tout `switch` sans `default`, garantissant un traitement explicite.
///
/// ⚠️ **Valeur d'UI runtime, jamais persistée** : `ZRouteTransition` n'est ni
/// sérialisé ni stocké — c'est un paramètre passé à [zPageRoute] au moment de la
/// navigation. Il n'est donc **pas** annoté `@JsonKey(unknownEnumValue:)` (aucun
/// codegen — NFR-U11).
library;

/// Type de transition appliqué par [zPageRoute].
///
/// * [slide] : glissement horizontal **RTL-aware** — le sens dépend de la
///   direction de lecture (`Directionality.of(context)`) via `zSlideBeginOffset`
///   (LTR entre par la fin/droite, RTL par la fin/gauche — AD-13).
/// * [fade] : fondu d'opacité **insensible à la direction** (pas de composante
///   horizontale, donc identique en LTR et en RTL).
enum ZRouteTransition {
  /// Glissement horizontal dont le sens s'inverse en RTL (AD-13).
  slide,

  /// Fondu d'opacité, insensible à la direction de lecture.
  fade,
}
