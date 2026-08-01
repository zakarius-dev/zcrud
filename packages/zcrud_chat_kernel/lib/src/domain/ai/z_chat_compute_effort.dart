/// **Effort de calcul** — `ZChatComputeEffort` (CHAT-1).
///
/// ## 🔴 Le faux-ami `WorkflowEffort` est RÉSOLU : ce sont DEUX AXES
///
/// CHAT-0 avait constaté que `WorkflowEffort` désigne deux choses
/// incompatibles, et **réservé** le nom `ZChatComputeEffort` pour le concept
/// d'IFFD (`z_chat_enums.dart`, dartdoc de `ZChatResponseLength`). La
/// vérification des DEUX backends tranche : il n'y a pas un enum ambigu, il y a
/// **deux axes orthogonaux**, dont l'un est **commun aux deux backends**.
///
/// | Axe | lex | IFFD | Type zcrud |
/// |---|---|---|---|
/// | **Verbosité** (longueur de la réponse) | `workflowEffort` = `concis/standard/detaille` | — | `ZChatResponseLength` (EXISTANT, CHAT-0) |
/// | **Calcul** (budget de raisonnement) | `thinkingEffort` **1..5** (`backend/app/models/chat.py:261`) | `thinkingEffort` **1..5** (`shared/schemas/base_request.py:104`) **+** `workflowEffort` = `low/medium/high`, qui choisit une topologie de pipeline | **`ZChatComputeEffort`** (ce fichier) |
///
/// ⛔ **Les deux axes ne sont JAMAIS fusionnés** : `standard` (verbosité) n'a
/// aucune correspondance dans un budget de calcul, et un hôte qui migrerait de
/// l'un vers l'autre écrirait des requêtes que l'autre lirait de travers, sans
/// aucun signal. La garde **G16** (`z_chat_naming_guard_test.dart`) interdit
/// toujours `WorkflowEffort` et n'autorise, pour `Effort`, que le nom
/// **explicite** `ZChatComputeEffort`.
///
/// ## Pourquoi un **entier 1..5** et pas un enum
///
/// Parce que c'est la forme **réellement commune aux deux backends**. Un enum
/// `low/medium/high` perdrait deux paliers sur cinq à l'aller-retour ; l'entier
/// les porte tous, et l'enum d'IFFD s'y **projette** ([low]/[medium]/[high]).
/// L'inverse — porter l'enum et deviner l'entier — ne serait pas réversible.
///
/// ⚠️ **Ce n'est pas un `int` nu** : l'intervalle est le contrat. Un `int`
/// laisserait passer `0` ou `42`, qu'un backend rejetterait à l'exécution.
library;

/// Budget de calcul demandé au fournisseur, **borné à 1..5** (AD-10 : une
/// valeur hors bornes est **ramenée** dans l'intervalle, jamais rejetée par une
/// exception — un champ corrompu ne fait pas échouer le parent).
class ZChatComputeEffort {
  /// Construit un effort de calcul, [level] **écrêté** à `1..5`.
  ZChatComputeEffort(int level)
    : level = level < min ? min : (level > max ? max : level);

  /// Borne basse de l'intervalle commun aux deux backends.
  static const int min = 1;

  /// Borne haute de l'intervalle commun aux deux backends.
  static const int max = 5;

  /// Palier effectif, garanti dans `1..5`.
  final int level;

  /// Projection du palier `low` d'IFFD (`ai_models.dart:119-122`).
  static ZChatComputeEffort get low => ZChatComputeEffort(1);

  /// Projection du palier `medium` d'IFFD.
  static ZChatComputeEffort get medium => ZChatComputeEffort(3);

  /// Projection du palier `high` d'IFFD.
  static ZChatComputeEffort get high => ZChatComputeEffort(5);

  /// Lecture **défensive** (AD-10) : `null` si la valeur est absente ou
  /// illisible — **jamais** un palier inventé. L'absence d'un budget de calcul
  /// n'est pas « le minimum » : c'est « l'hôte décide ».
  static ZChatComputeEffort? fromJson(Object? raw) {
    if (raw is int) return ZChatComputeEffort(raw);
    if (raw is num) return ZChatComputeEffort(raw.toInt());
    if (raw is String) {
      final int? parsed = int.tryParse(raw);
      return parsed == null ? null : ZChatComputeEffort(parsed);
    }
    return null;
  }

  /// Valeur persistée : l'entier, tel que les deux backends l'attendent.
  int toJson() => level;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatComputeEffort && level == other.level;

  @override
  int get hashCode => Object.hash(runtimeType, level);

  @override
  String toString() => 'ZChatComputeEffort(level: $level)';
}
