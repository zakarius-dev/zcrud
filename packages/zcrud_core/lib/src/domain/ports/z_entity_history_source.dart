/// Port de lecture d'un journal d'entité, neutre vis-à-vis du stockage.
///
/// Le journal est écrit, ordonné et désérialisé par l'application hôte : le
/// cœur ne connaît ni Firestore ni une forme de journal métier. Comme tous les
/// flux du domaine, [watchHistory] reste nu (AD-5).
library;

import '../contracts/z_entity.dart';
import 'z_acl.dart';

/// Source optionnelle de l'historique d'une entité.
abstract class ZEntityHistorySource<T extends ZEntity> {
  /// Observe le journal de [entity], dans l'ordre choisi par l'hôte.
  Stream<List<ZHistoryEntry>> watchHistory(T entity);
}

/// Une version antérieure fournie par l'hôte.
///
/// [action] est le cas nominal : le socle le traduit avec ses clés l10n.
/// [operationLabel] est l'échappatoire explicitement hôte pour une opération
/// métier absente de [ZCrudAction]. Au moins l'un des deux doit être présent
/// pour qu'une entrée soit rendable ; les entrées incomplètes sont ignorées par
/// la présentation (AD-10).
class ZHistoryEntry {
  /// Construit une entrée de journal tolérante : la présentation ignore les
  /// entrées sans date ou opération rendable.
  const ZHistoryEntry({
    this.at,
    this.action,
    this.operationLabel,
    this.authorLabel,
    this.previousValue,
  });

  /// Instant fourni par l'hôte ; `null` reste une donnée invalide, jamais
  /// remplacée par l'heure courante.
  final DateTime? at;

  /// Opération CRUD standard, localisable par le socle.
  final ZCrudAction? action;

  /// Libellé métier déjà résolu par l'hôte, seulement hors [action].
  final String? operationLabel;

  /// Auteur déjà résolu par l'hôte.
  final String? authorLabel;

  /// État immédiatement **avant** cette mutation, si l'hôte le conserve.
  final Map<String, Object?>? previousValue;
}
