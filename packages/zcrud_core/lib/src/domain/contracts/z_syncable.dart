/// Contrat exposant la clé de merge Last-Write-Wins (LWW) du domaine.
///
/// origine: lex_core (module « Étude ») — `updatedAt` de `StudyFolder`
/// (in-entité) et `Mindmap` (via métadonnées hors-entité). Divergence **tranchée
/// par AD-19** (ES-1.3) en faveur du **hors-entité universel**. Canonique §2.2 ;
/// AD-9/AD-16/AD-19.
library;

/// Contrat abstrait exposant la **clé Last-Write-Wins** d'un agrégat synchronisé.
///
/// ## ⚠️ La clé LWW vit **HORS-ENTITÉ** (AD-19) — ce contrat n'y déroge pas
///
/// La valeur d'autorité du merge offline-first est **TOUJOURS**
/// `ZSyncMeta.updatedAt` (métadonnée **hors-entité**, clé persistée `updated_at`,
/// propriété du **store**). Le moteur de merge (`ZLwwResolver`) compare des
/// `ZSyncEntry.updatedAt`, qui est **dérivé de `ZSyncEntry.meta`** — il ne lit
/// **JAMAIS** un `T.updatedAt` interne.
///
/// > **NE PAS déclarer un champ `updatedAt` sur une nouvelle entité pour « porter
/// > la clé LWW ».** L'emplacement de la métadonnée n'est **pas** un choix libre :
/// > AD-19.1 le tranche (`ZSyncMeta`, hors-entité). Un `T.updatedAt` résiduel
/// > (`ZStudyFolder.updatedAt`, déprécié ; `ZFlashcard.updatedAt`) n'est qu'un
/// > **miroir de compatibilité legacy sans aucune autorité** : l'adapter l'écrase
/// > à chaque écriture et le merge l'ignore.
///
/// Ce contrat exprime seulement *qu'une* valeur LWW **est lisible et comparable**
/// sur un agrégat (utile aux vues/tri d'affichage, à la journalisation, aux
/// adaptateurs legacy). L'implémenter **n'autorise pas** à faire du champ
/// implémentant [updatedAt] la source d'autorité du merge : cette autorité reste
/// `ZSyncMeta` (AD-19).
///
/// [updatedAt] est **nullable** : une entité jamais synchronisée peut ne pas
/// encore porter d'horodatage. Aucune logique de merge n'est portée ici — elle
/// relève du repository/orchestrateur de sync (E5), qui l'applique sur la méta.
///
/// Voir : `ZSyncMeta` (`kUpdatedAt`/`kIsDeleted`/`reservedKeys` = définition
/// **machine** d'AD-19), `ZSyncEntry`, `ZLwwResolver`, et
/// `architecture-zcrud-study-2026-07-12/architecture.md` § **AD-19 / AD-19.1**.
abstract class ZSyncable {
  /// Horodatage de dernière écriture **lisible** sur l'agrégat, ou `null` si
  /// jamais synchronisé.
  ///
  /// **N'est PAS l'autorité de merge** (AD-19) : le merge LWW compare
  /// `ZSyncMeta.updatedAt` (hors-entité). Ne jamais lire ce membre pour décider
  /// d'un merge, d'un tri de synchronisation ou d'une résolution de conflit.
  DateTime? get updatedAt;
}
