/// Nature de la source d'étude à partir de laquelle un podcast est généré.
///
/// **L'ordre de déclaration est normatif** : le générateur zcrud décode un
/// enum par nom et, pour un champ non-nullable sans valeur par défaut, son
/// repli défensif (invariant AD-10) est **la première constante déclarée**
/// — pour une valeur absente, `null`, non-`String` ou inconnue. Réordonner
/// cet enum changerait silencieusement le comportement défensif de
/// `ZStudyPodcast.sourceKind`.
///
/// Pur Dart — aucune dépendance Flutter/Firebase/crypto.
library;

/// Type de source à partir de laquelle un podcast est synthétisé.
enum ZPodcastSourceKind {
  /// Note intelligente — valeur de repli défensive (première constante
  /// déclarée).
  note,

  /// Dossier d'étude entier.
  folder,

  /// Document (PDF / support).
  document,
}
