/// Nature d'une annotation de document d'étude `ZDocumentAnnotationKind`.
///
/// - [highlight] : surlignage d'un passage de texte (une ou plusieurs
///   lignes), rendu par un fond coloré ;
/// - [stickyNote] : note ancrée à un point de la page (marqueur tapable +
///   texte) ;
/// - [underline] : soulignage d'un passage — trait continu sous la ligne de
///   base, le texte reste sur fond neutre ;
/// - [strikethrough] : barrage d'un passage — trait continu au milieu du
///   texte ;
/// - [squiggly] : soulignage ondulé d'un passage — trait sinueux sous la
///   ligne de base.
///
/// Sérialisation JSON stable (nom d'enum camelCase, invariant AD-3), repli
/// défensif sur [highlight] pour toute valeur inconnue / `null` /
/// non-`String` (robustesse à un document altéré, invariant AD-10).
///
/// **L'ordre de déclaration est normatif** : le générateur zcrud décode un
/// enum par nom et, pour un champ non-nullable sans valeur par défaut, son
/// repli défensif est la première constante déclarée. [highlight] est donc
/// le défaut d'une valeur absente / `null` / non-`String` / inconnue.
/// Réordonner cet enum changerait silencieusement le comportement défensif
/// de `ZDocumentAnnotation.kind`.
///
/// **L'enrichissement est additif** (invariant AD-4) : une nature neuve
/// s'ajoute **en fin** de déclaration. Une donnée écrite par une version
/// antérieure — qui ne connaît que [highlight] et [stickyNote] — se relit
/// inchangée, et une donnée portant une nature qu'une version *plus
/// récente* aura ajoutée retombe sur [highlight] **sans lever**.
///
/// Pur Dart — aucune dépendance Flutter/Firebase/Hive.
library;

/// Nature d'une [ZDocumentAnnotation] : marquage de texte ou note ancrée.
enum ZDocumentAnnotationKind {
  /// Surlignage d'un passage de texte — valeur de repli défensive (première
  /// constante déclarée).
  highlight,

  /// Note ancrée à un point de la page (marqueur tapable + texte).
  stickyNote,

  /// Soulignage d'un passage : trait continu sous la ligne de base.
  underline,

  /// Barrage d'un passage : trait continu au milieu du texte.
  strikethrough,

  /// Soulignage ondulé d'un passage : trait sinueux sous la ligne de base.
  squiggly;
}
