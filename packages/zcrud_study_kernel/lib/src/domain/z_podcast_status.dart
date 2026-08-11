/// Cycle de vie d'un podcast généré.
///
/// **L'ordre de déclaration est normatif** : le générateur zcrud décode un
/// enum par nom et, pour un champ non-nullable sans valeur par défaut, son
/// repli défensif (invariant AD-10) est **la première constante déclarée**
/// — pour une valeur absente, `null`, non-`String` ou inconnue.
///
/// ## [ready] en tête, par choix délibéré
///
/// Seul un podcast [ready] est persisté durablement ([failed]/[stale]/
/// [pending]/[processing] sont transitoires) : toute valeur inconnue ou
/// corrompue lue depuis le store est donc, par construction, plus
/// probablement une référence à un podcast prêt. Replier sur [pending]/
/// [processing] afficherait un indicateur de chargement perpétuel ; sur
/// [failed] masquerait un podcast valide ; sur [stale] déclencherait une
/// régénération inutile ; [ready] ne ment ni ne détruit rien. Réordonner
/// cet enum change silencieusement le comportement défensif.
///
/// Pur Dart — aucune dépendance Flutter/Firebase/crypto.
library;

/// État du cycle de vie d'un [ZStudyPodcast] (généré → prêt / échec /
/// obsolète).
enum ZPodcastStatus {
  /// Podcast prêt et écoutable — valeur de repli défensive (première
  /// constante déclarée).
  ready,

  /// Génération demandée, en attente de traitement.
  pending,

  /// Génération en cours (synthèse audio).
  processing,

  /// Échec de génération.
  failed,

  /// La source a changé depuis la génération ⇒ podcast obsolète (à
  /// régénérer).
  stale,
}
