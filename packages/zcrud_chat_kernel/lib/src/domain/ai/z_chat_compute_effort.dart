/// **Effort de calcul** — `ZChatComputeEffort`.
///
/// ## Deux axes distincts, jamais fusionnés
///
/// « Effort » désigne deux concepts orthogonaux dans les intégrations chat,
/// dont un seul est commun aux fournisseurs :
///
/// | Axe | Forme habituelle | Type zcrud |
/// |---|---|---|
/// | **Verbosité** (longueur de la réponse) | valeurs du type `concis/standard/detaille` | `ZChatResponseLength` |
/// | **Calcul** (budget de raisonnement) | un entier `1..5`, parfois doublé d'un préréglage `low/medium/high` qui choisit une topologie de pipeline | **`ZChatComputeEffort`** (ce fichier) |
///
/// **Les deux axes ne sont jamais fusionnés** : `standard` (verbosité) n'a
/// aucune correspondance dans un budget de calcul, et un hôte qui migrerait de
/// l'un vers l'autre écrirait des requêtes que l'autre lirait de travers, sans
/// aucun signal. Tout symbole `*Effort*` ambigu (notamment un `WorkflowEffort`
/// qui mélangerait les deux axes) est donc évité dans ce paquet, au profit du
/// nom explicite `ZChatComputeEffort`.
///
/// ## Pourquoi un **entier 1..5** et pas un enum
///
/// Parce que c'est la forme **réellement commune aux fournisseurs
/// rencontrés** : un entier `1..5` de part et d'autre — le même axe, sous le
/// même intervalle. Un enum `low/medium/high` perdrait deux paliers
/// sur cinq à l'aller-retour ; l'entier les porte tous, et un préréglage à
/// trois valeurs s'y **projette** ([low]/[medium]/[high]). L'inverse — porter
/// l'enum et deviner l'entier — ne serait pas réversible.
///
/// **Ce n'est pas un `int` nu** : l'intervalle est le contrat. Un `int`
/// laisserait passer `0` ou `42`, qu'un backend rejetterait à l'exécution.
library;

/// Budget de calcul demandé au fournisseur, **borné à 1..5** (invariant
/// AD-10 : une valeur hors bornes est **ramenée** dans l'intervalle, jamais
/// rejetée par une exception — un champ corrompu ne fait pas échouer le
/// parent).
class ZChatComputeEffort {
  // Provenance de l'intervalle, conservée : `backend/app/models/chat.py:261`
  // d'un côté, `shared/schemas/base_request.py:104` de l'autre — les deux
  // backends rencontrés portent le MÊME entier 1..5.

  /// Construit un effort de calcul, [level] **écrêté** à `1..5`.
  ZChatComputeEffort(int level)
    : level = level < min ? min : (level > max ? max : level);

  /// Borne basse de l'intervalle commun aux deux backends.
  static const int min = 1;

  /// Borne haute de l'intervalle commun aux deux backends.
  static const int max = 5;

  /// Palier effectif, garanti dans `1..5`.
  final int level;

  /// Projection du préréglage `low` à trois paliers.
  static ZChatComputeEffort get low => ZChatComputeEffort(1);

  /// Projection du préréglage `medium` à trois paliers.
  static ZChatComputeEffort get medium => ZChatComputeEffort(3);

  /// Projection du préréglage `high` à trois paliers.
  static ZChatComputeEffort get high => ZChatComputeEffort(5);

  /// Lecture **défensive** (invariant AD-10) : `null` si la valeur est
  /// absente ou illisible — **jamais** un palier inventé. L'absence d'un
  /// budget de calcul n'est pas « le minimum » : c'est « l'hôte décide ».
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
