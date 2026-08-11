/// Mode de synthèse d'un podcast généré (voix unique ou dialogue).
///
/// **L'ordre de déclaration est normatif** : le générateur zcrud décode un
/// enum par nom et, pour un champ non-nullable sans valeur par défaut, son
/// repli défensif (invariant AD-10) est **la première constante déclarée**.
/// Réordonner cet enum changerait silencieusement le comportement défensif
/// de `ZStudyPodcast.mode` et le suffixe de `ZStudyPodcast.buildId`.
///
/// Pur Dart — aucune dépendance Flutter/Firebase/crypto.
library;

/// Mode de génération d'un podcast (voix unique vs dialogue).
enum ZPodcastMode {
  /// Narration à voix unique — valeur de repli défensive (première constante
  /// déclarée).
  simple,

  /// Dialogue à deux voix.
  dialogue,
}
