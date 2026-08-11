/// Fraîcheur *content-addressed* d'un podcast — cœur de l'invalidation pure.
///
/// ## Le kernel compare, il ne calcule jamais le hash
///
/// [podcastFreshness] ne hashe rien : elle reçoit deux empreintes opaques
/// déjà calculées (par le seam de génération / le binding de l'hôte) et se
/// contente d'une comparaison pure, totale, déterministe. Aucune horloge,
/// aucun `DateTime.now()` : l'invalidation *content-addressed* est
/// atemporelle.
///
/// Pur Dart — aucune dépendance Flutter/Firebase/crypto.
library;

/// Fraîcheur du cache d'un podcast au regard de sa source courante.
enum ZPodcastFreshness {
  /// Aucune empreinte mémorisée (podcast jamais généré / hash absent).
  absent,

  /// L'empreinte mémorisée == l'empreinte de la source courante (à jour).
  fresh,

  /// Les empreintes diffèrent ⇒ la source a changé (podcast obsolète).
  stale,
}

/// Dérive purement la [ZPodcastFreshness] de la comparaison de deux
/// empreintes opaques — aucun calcul de hash, aucune horloge.
///
/// Contrat total — jamais de `throw`, jamais de `null!` :
/// - [storedHash] `null` ou vide ⇒ [ZPodcastFreshness.absent] (rien de
///   mémorisé — aucune comparaison possible) ;
/// - sinon [ZPodcastFreshness.fresh] ssi `storedHash == currentSourceHash`,
///   sinon [ZPodcastFreshness.stale].
///
/// Politique documentée et déterministe aux bords :
/// - `(storedHash: 'h', currentSourceHash: null)` ⇒ `stale` (empreintes
///   différentes : une source présente vs une source inconnue) ;
/// - `(storedHash: null, currentSourceHash: 'h')` ⇒ `absent` (rien de
///   mémorisé) ;
/// - `(storedHash: '', currentSourceHash: '')` ⇒ `absent` (`storedHash`
///   vide) ;
/// - `(storedHash: 'h', currentSourceHash: 'h')` ⇒ `fresh`.
///
/// La sortie dépend réellement des deux empreintes (aucune n'est ignorée).
ZPodcastFreshness podcastFreshness({
  String? storedHash,
  String? currentSourceHash,
}) {
  if (storedHash == null || storedHash.isEmpty) {
    return ZPodcastFreshness.absent;
  }
  return storedHash == currentSourceHash
      ? ZPodcastFreshness.fresh
      : ZPodcastFreshness.stale;
}
