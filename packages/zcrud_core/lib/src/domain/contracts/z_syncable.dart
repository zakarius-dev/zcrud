/// Contrat exposant la clé de merge Last-Write-Wins (LWW) du domaine.
///
/// origine: lex_core (module « Étude ») — `updatedAt` de `StudyFolder`
/// (in-entité) et `Mindmap` (via métadonnées hors-entité). Canonique §2.2 ; AD-9.
library;

/// Contrat abstrait exposant la **clé Last-Write-Wins** d'un agrégat synchronisé.
///
/// Le merge offline-first se résout en comparant [updatedAt] (AD-9). Ce contrat
/// est **agnostique** quant à l'emplacement de la métadonnée : la valeur peut
/// vivre **dans** l'entité (comme `StudyFolder.updatedAt`) ou **hors-entité**
/// via `ZSyncMeta` (comme `Mindmap`). Il exprime seulement *qu'une* valeur LWW
/// existe et est comparable.
///
/// [updatedAt] est **nullable** : une entité jamais synchronisée peut ne pas
/// encore porter d'horodatage. Aucune logique de merge n'est portée ici — elle
/// relève du repository/orchestrateur de sync (E5).
abstract class ZSyncable {
  /// Horodatage de dernière écriture (clé LWW), ou `null` si jamais synchronisé.
  DateTime? get updatedAt;
}
