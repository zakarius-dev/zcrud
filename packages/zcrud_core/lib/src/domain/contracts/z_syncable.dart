/// Contrat exposant la clé de merge Last-Write-Wins (LWW) du domaine.
library;

/// Contrat abstrait exposant la **clé Last-Write-Wins** d'un agrégat synchronisé.
///
/// ## La clé LWW vit **HORS-ENTITÉ** (invariant AD-9) — ce contrat n'y déroge pas
///
/// La valeur d'autorité du merge offline-first est **TOUJOURS**
/// `ZSyncMeta.updatedAt` (métadonnée **hors-entité**, clé persistée `updated_at`,
/// propriété du **store**). Le moteur de merge (`ZLwwResolver`) compare des
/// `ZSyncEntry.updatedAt`, qui est **dérivé de `ZSyncEntry.meta`** — il ne lit
/// **JAMAIS** un `T.updatedAt` interne.
///
/// > **NE PAS déclarer un champ `updatedAt` sur une nouvelle entité pour « porter
/// > la clé LWW ».** L'emplacement de la métadonnée n'est **pas** un choix
/// > libre : l'invariant AD-9 le tranche (`ZSyncMeta`, hors-entité). Un
/// > `T.updatedAt` résiduel sur une entité applicative n'est qu'un **miroir
/// > de compatibilité sans aucune autorité** : l'adaptateur l'écrase à chaque
/// > écriture et le merge l'ignore.
///
/// Ce contrat exprime seulement *qu'une* valeur LWW **est lisible et comparable**
/// sur un agrégat (utile aux vues/tri d'affichage, à la journalisation, aux
/// adaptateurs d'entités préexistantes). L'implémenter **n'autorise pas** à
/// faire du champ implémentant [updatedAt] la source d'autorité du merge :
/// cette autorité reste `ZSyncMeta` (invariant AD-9).
///
/// [updatedAt] est **nullable** : une entité jamais synchronisée peut ne pas
/// encore porter d'horodatage. Aucune logique de merge n'est portée ici — elle
/// relève du repository/orchestrateur de sync, qui l'applique sur la méta.
///
/// Voir aussi : `ZSyncMeta` (`kUpdatedAt`/`kIsDeleted`/`reservedKeys`),
/// `ZSyncEntry`, `ZLwwResolver`.
abstract class ZSyncable {
  /// Horodatage de dernière écriture **lisible** sur l'agrégat, ou `null` si
  /// jamais synchronisé.
  ///
  /// **N'est PAS l'autorité de merge** (invariant AD-9) : le merge LWW compare
  /// `ZSyncMeta.updatedAt` (hors-entité). Ne jamais lire ce membre pour décider
  /// d'un merge, d'un tri de synchronisation ou d'une résolution de conflit.
  DateTime? get updatedAt;
}
