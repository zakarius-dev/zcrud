/// Fraîcheur *content-addressed* d'un podcast (ES-2.8, FR-S11) — **cœur de
/// l'invalidation PURE**.
///
/// origine: lex_core (module « Étude ») — `enums/podcast_status.dart`
/// `PodcastFreshness {absent, fresh, stale}` + `utils/podcast_audio_access.dart`
/// `podcastFreshness(...)` : fonction **PURE** dérivant la fraîcheur du hash.
///
/// ## 🔴 DÉCISION CENTRALE (D4) — le kernel COMPARE, ne CALCULE JAMAIS le hash
///
/// lex calcule `sourceHash` par **SHA-256** (backend `compute_source_hash`, miroir
/// app `computeAudioTextHash`) puis **COMPARE**. NFR-S10/SM-S7 **INTERDISENT
/// `package:crypto`/SHA-256 dans le kernel**. Ici [podcastFreshness] ne hashe
/// **RIEN** — ni `crypto`, ni `zFnv1a32` : elle reçoit **deux empreintes OPAQUES
/// déjà calculées** (par le seam de génération / le binding — SHA-256 côté lex) et
/// se contente d'une **COMPARAISON PURE, TOTALE, DÉTERMINISTE**. Aucune horloge,
/// aucun `DateTime.now()` : l'invalidation *content-addressed* est **atemporelle**
/// (c'est le point de FR-S11).
///
/// Pur Dart — aucune dépendance Flutter/Firebase/crypto (NFR-S3/NFR-S10/SM-S5).
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

/// Dérive **PUREMENT** la [ZPodcastFreshness] de la comparaison de deux empreintes
/// **OPAQUES** (D4) — **aucun calcul de hash, aucune horloge**.
///
/// Contrat (parité lex `podcastFreshness`), **TOTAL** — jamais de `throw`, jamais
/// de `null!` :
/// - [storedHash] `null` **ou vide** ⇒ [ZPodcastFreshness.absent] (rien de
///   mémorisé — aucune comparaison possible) ;
/// - sinon [ZPodcastFreshness.fresh] ssi `storedHash == currentSourceHash`, sinon
///   [ZPodcastFreshness.stale].
///
/// Politique **documentée et déterministe** aux bords :
/// - `(storedHash: 'h', currentSourceHash: null)` ⇒ `stale` (empreintes
///   différentes : une source présente vs une source inconnue) ;
/// - `(storedHash: null, currentSourceHash: 'h')` ⇒ `absent` (rien de mémorisé) ;
/// - `(storedHash: '', currentSourceHash: '')` ⇒ `absent` (`storedHash` vide) ;
/// - `(storedHash: 'h', currentSourceHash: 'h')` ⇒ `fresh`.
///
/// La sortie dépend **RÉELLEMENT des DEUX empreintes** (prouvé bidirectionnellement
/// — leçon ES-2.3 : un `storedHash` figé rendrait le test POWERLESS).
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
